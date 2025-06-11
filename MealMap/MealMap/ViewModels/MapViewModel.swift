import SwiftUI
import MapKit
import CoreLocation
import Combine

@MainActor
final class MapViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published var restaurants: [Restaurant] = []
    @Published var currentAreaName = ""
    @Published var isLoadingRestaurants = false
    @Published var searchErrorMessage: String?
    @Published var showSearchError = false
    @Published var filteredRestaurants: [Restaurant] = []
    @Published var showSearchResults = false
    @Published var selectedRestaurant: Restaurant?
    @Published var showingRestaurantDetail = false
    
    // MARK: - New Properties for Non-Blocking Loading
    @Published var backgroundLoadingAreas: Set<String> = [] // Track which areas are loading
    @Published var loadingProgress: Double = 1.0 // 0.0 to 1.0, 1.0 means not loading
    
    // MARK: - Private Properties
    private let overpassService = OverpassAPIService()
    private let locationManager = LocationManager.shared
    private let searchManager = SearchManager()
    
    // Enhanced caching for immediate response
    private var regionUpdateTask: Task<Void, Never>?
    private var geocodeTask: Task<Void, Never>?
    private var dataFetchTasks: [String: Task<Void, Never>] = [:] // Multiple concurrent tasks
    private var restaurantCache: [String: CachedRestaurantData] = [:]
    
    // State tracking
    private var lastGeocodeTime = Date.distantPast
    private var lastGeocodeLocation: CLLocationCoordinate2D?
    private var pendingDataFetches: Set<String> = []
    
    // Configuration - Optimized for responsiveness
    private let maxCacheSize = 25 // Increased cache for more coverage
    private let cacheExpiryInterval: TimeInterval = 600 // 10 minutes - longer retention
    private let preloadRadius: Double = 2.0 // Preload nearby areas
    
    // MARK: - Computed Properties
    var hasValidLocation: Bool {
        locationManager.lastLocation != nil &&
        (locationManager.authorizationStatus == .authorizedWhenInUse ||
         locationManager.authorizationStatus == .authorizedAlways)
    }
    
    var shouldShowClusters: Bool {
        region.span.latitudeDelta > 0.02 && !showSearchResults
    }
    
    // NEW: Combined restaurants from cache and current area
    var allAvailableRestaurants: [Restaurant] {
        // Show cached restaurants immediately, then update with fresh data
        let currentCacheKey = createCacheKey(for: region.center)
        if let cached = restaurantCache[currentCacheKey] {
            return cached.restaurants
        }
        return restaurants
    }
    
    // MARK: - Initialization
    init() {
        setupLocationObserver()
    }
    
    // MARK: - Public Methods - Non-blocking approach
    func updateRegion(_ newRegion: MKCoordinateRegion) {
        // IMMEDIATELY update region - never block user interaction
        region = newRegion
        
        // Start background loading without blocking UI
        startBackgroundDataLoading(for: newRegion)
    }
    
    func performSearch(query: String, maxDistance: Double?) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let distanceFilter = (maxDistance ?? 20.0) < 20.0 ? maxDistance : nil
        
        // Search in all available restaurants (cached + current)
        let result = searchManager.search(
            query: query,
            in: allAvailableRestaurants,
            userLocation: locationManager.lastLocation,
            maxDistance: distanceFilter
        )
        
        handleSearchResult(result)
    }
    
    func clearSearch() {
        filteredRestaurants = []
        showSearchResults = false
        searchManager.hasActiveSearch = false
    }
    
    func refreshData(for coordinate: CLLocationCoordinate2D) {
        // Force refresh but still non-blocking
        startBackgroundDataLoading(for: MKCoordinateRegion(
            center: coordinate,
            span: region.span
        ), force: true)
    }
    
    func selectRestaurant(_ restaurant: Restaurant) {
        selectedRestaurant = restaurant
        zoomToRestaurant(restaurant)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // Reduced delay
            self.showingRestaurantDetail = true
        }
    }
    
    func cleanup() {
        cancelAllTasks()
    }
    
    // NEW: Method to get cached restaurants for a specific area
    func getCachedRestaurants(for coordinate: CLLocationCoordinate2D) -> [Restaurant]? {
        let cacheKey = createCacheKey(for: coordinate)
        return restaurantCache[cacheKey]?.restaurants
    }
    
    // NEW: Get best available restaurants (cached or current)
    func getBestAvailableRestaurants(for coordinate: CLLocationCoordinate2D) -> [Restaurant] {
        if let cached = getCachedRestaurants(for: coordinate) {
            return cached
        }
        return restaurants
    }
    
    // MARK: - NEW: Non-blocking Background Loading
    private func startBackgroundDataLoading(for newRegion: MKCoordinateRegion, force: Bool = false) {
        // Update area name immediately if cached, otherwise in background
        updateAreaNameIfNeeded(for: newRegion.center)
        
        // Start restaurant data loading in background
        loadRestaurantDataInBackground(for: newRegion.center, force: force)
        
        // Preload nearby areas for smooth panning
        preloadNearbyAreas(around: newRegion.center)
    }
    
    private func loadRestaurantDataInBackground(for center: CLLocationCoordinate2D, force: Bool = false) {
        let cacheKey = createCacheKey(for: center)
        
        // If we have cached data and not forcing, show it immediately
        if !force, let cached = restaurantCache[cacheKey], !cached.isExpired {
            restaurants = cached.restaurants
            return
        }
        
        // Cancel existing task for this area if any
        dataFetchTasks[cacheKey]?.cancel()
        
        // Mark area as loading
        backgroundLoadingAreas.insert(cacheKey)
        updateLoadingProgress()
        
        dataFetchTasks[cacheKey] = Task { @MainActor in
            await fetchRestaurantDataNonBlocking(for: center, cacheKey: cacheKey, force: force)
        }
    }
    
    private func fetchRestaurantDataNonBlocking(for center: CLLocationCoordinate2D, cacheKey: String, force: Bool) async {
        do {
            // Show loading indicator subtly
            if backgroundLoadingAreas.count == 1 {
                loadingProgress = 0.0
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingRestaurants = true
                }
            }
            
            let fetchedRestaurants = try await overpassService.fetchFastFoodRestaurants(near: center)
            
            // Cache the results
            restaurantCache[cacheKey] = CachedRestaurantData(
                restaurants: fetchedRestaurants,
                timestamp: Date()
            )
            
            // Clean old cache entries
            cleanCache()
            
            // Update restaurants if this is the current area
            let currentCacheKey = createCacheKey(for: region.center)
            if cacheKey == currentCacheKey {
                restaurants = fetchedRestaurants
            }
            
            // Update loading state
            backgroundLoadingAreas.remove(cacheKey)
            updateLoadingProgress()
            
            if backgroundLoadingAreas.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingRestaurants = false
                    loadingProgress = 1.0
                }
            }
            
        } catch {
            // Handle error gracefully - don't block UI
            backgroundLoadingAreas.remove(cacheKey)
            updateLoadingProgress()
            
            if backgroundLoadingAreas.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingRestaurants = false
                    loadingProgress = 1.0
                }
            }
            
            print("Background restaurant fetch error: \(error)")
        }
        
        // Clean up task
        dataFetchTasks.removeValue(forKey: cacheKey)
    }
    
    private func preloadNearbyAreas(around center: CLLocationCoordinate2D) {
        let offsets: [(lat: Double, lon: Double)] = [
            (0.01, 0), (-0.01, 0), (0, 0.01), (0, -0.01), // Adjacent areas
            (0.01, 0.01), (-0.01, -0.01), (0.01, -0.01), (-0.01, 0.01) // Diagonal areas
        ]
        
        for offset in offsets {
            let nearbyCenter = CLLocationCoordinate2D(
                latitude: center.latitude + offset.lat,
                longitude: center.longitude + offset.lon
            )
            
            let nearbyCacheKey = createCacheKey(for: nearbyCenter)
            
            // Only preload if not already cached and not currently loading
            if restaurantCache[nearbyCacheKey]?.isExpired != false && 
               !backgroundLoadingAreas.contains(nearbyCacheKey) {
                
                Task { @MainActor in
                    // Add small delay to not overwhelm the API
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                    
                    if !backgroundLoadingAreas.contains(nearbyCacheKey) {
                        loadRestaurantDataInBackground(for: nearbyCenter)
                    }
                }
            }
        }
    }
    
    private func updateLoadingProgress() {
        if backgroundLoadingAreas.isEmpty {
            loadingProgress = 1.0
        } else {
            // Calculate progress based on active loading tasks
            loadingProgress = max(0.2, 1.0 - (Double(backgroundLoadingAreas.count) * 0.2))
        }
    }
    
    private func updateAreaNameIfNeeded(for coordinate: CLLocationCoordinate2D) {
        // Check if we need to update area name
        let timeSinceLastGeocode = Date().timeIntervalSince(lastGeocodeTime)
        let shouldUpdate = timeSinceLastGeocode >= 3.0 || {
            if let lastLocation = lastGeocodeLocation {
                let distance = abs(coordinate.latitude - lastLocation.latitude) +
                              abs(coordinate.longitude - lastLocation.longitude)
                return distance >= 0.02
            }
            return true
        }()
        
        if shouldUpdate {
            updateAreaNameDebounced(for: coordinate)
        }
    }
    
    // MARK: - Existing Methods - Optimized
    private func setupLocationObserver() {
        if let location = locationManager.lastLocation {
            initializeWithLocation(location.coordinate)
        }
    }
    
    private func initializeWithLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 1.0)) {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        startBackgroundDataLoading(for: region)
    }
    
    private func updateAreaNameDebounced(for coordinate: CLLocationCoordinate2D) {
        geocodeTask?.cancel()
        geocodeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // Reduced debounce
            
            guard !Task.isCancelled else { return }
            
            await Task.detached {
                await self.updateAreaName(for: coordinate)
            }.value
        }
    }
    
    private func updateAreaName(for coordinate: CLLocationCoordinate2D) async {
        let currentSpanDelta = await MainActor.run { region.span.latitudeDelta }
        
        let result = await Task.detached {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            do {
                let placemarks = try await self.withTimeout(seconds: 2) {
                    try await geocoder.reverseGeocodeLocation(location)
                }
                
                guard let placemark = placemarks.first else { return nil as String? }
                
                let isZoomedOut = currentSpanDelta > 0.5
            
                if isZoomedOut {
                    return placemark.administrativeArea ?? placemark.country ?? "Unknown Area"
                } else {
                    return placemark.locality ?? placemark.subLocality ?? placemark.administrativeArea ?? "Unknown Area"
                }
            } catch {
                return nil as String?
            }
        }.value
        
        await MainActor.run {
            if let areaName = result {
                self.lastGeocodeTime = Date()
                self.lastGeocodeLocation = coordinate
                self.currentAreaName = areaName
            }
        }
    }
    
    // MARK: - Helper Methods
    private func handleSearchResult(_ result: SearchResult) {
        switch result {
        case .noQuery:
            break
            
        case .noResults(let query):
            searchErrorMessage = "No restaurants found for '\(query)'. Try searching for a restaurant name or cuisine type."
            showSearchError = true
            
        case .singleResult(let restaurant):
            zoomToRestaurant(restaurant)
            filteredRestaurants = [restaurant]
            showSearchResults = true
            
        case .chainResult(let restaurant, _):
            zoomToRestaurant(restaurant)
            filteredRestaurants = [restaurant]
            showSearchResults = true
            
        case .cuisineResults(let restaurants, _):
            showCuisineResults(restaurants)
            
        case .partialNameResult(let restaurant, _):
            zoomToRestaurant(restaurant)
            filteredRestaurants = [restaurant]
            showSearchResults = true
        }
    }
    
    private func zoomToRestaurant(_ restaurant: Restaurant) {
        let coordinate = CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
        withAnimation(.easeInOut(duration: 1.0)) {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
        }
    }
    
    private func showCuisineResults(_ restaurants: [Restaurant]) {
        filteredRestaurants = restaurants
        showSearchResults = true
        
        if let bounds = calculateBounds(for: restaurants) {
            withAnimation(.easeInOut(duration: 1.0)) {
                region = bounds
            }
        }
    }
    
    private func calculateBounds(for restaurants: [Restaurant]) -> MKCoordinateRegion? {
        guard !restaurants.isEmpty else { return nil }
        
        let latitudes = restaurants.map { $0.latitude }
        let longitudes = restaurants.map { $0.longitude }
        
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLon = longitudes.min()!
        let maxLon = longitudes.max()!
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let spanLat = max((maxLat - minLat) * 1.2, 0.01)
        let spanLon = max((maxLon - minLon) * 1.2, 0.01)
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }
    
    private func createCacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        let lat = round(coordinate.latitude * 100) / 100
        let lon = round(coordinate.longitude * 100) / 100
        return "\(lat)_\(lon)"
    }
    
    private func cleanCache() {
        // Remove expired entries
        restaurantCache = restaurantCache.filter { !$0.value.isExpired }
        
        // Remove oldest entries if cache is too large
        if restaurantCache.count > maxCacheSize {
            let sortedKeys = restaurantCache.keys.sorted { key1, key2 in
                let timestamp1 = restaurantCache[key1]?.timestamp ?? Date.distantPast
                let timestamp2 = restaurantCache[key2]?.timestamp ?? Date.distantPast
                return timestamp1 < timestamp2
            }
            
            let keysToRemove = Array(sortedKeys.prefix(restaurantCache.count - maxCacheSize))
            for key in keysToRemove {
                restaurantCache.removeValue(forKey: key)
            }
        }
    }
    
    private func cancelAllTasks() {
        regionUpdateTask?.cancel()
        geocodeTask?.cancel()
        dataFetchTasks.values.forEach { $0.cancel() }
        dataFetchTasks.removeAll()
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
    
    struct TimeoutError: Error {}
}

// MARK: - Supporting Models
private struct CachedRestaurantData {
    let restaurants: [Restaurant]
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 600 // 10 minutes - longer retention
    }
}
