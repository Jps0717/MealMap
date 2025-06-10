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
    
    // MARK: - Private Properties
    private let overpassService = OverpassAPIService()
    private let locationManager = LocationManager.shared
    private let searchManager = SearchManager()
    
    // Debouncing and throttling
    private var regionUpdateTask: Task<Void, Never>?
    private var geocodeTask: Task<Void, Never>?
    private var dataFetchTask: Task<Void, Never>?
    private var restaurantCache: [String: CachedRestaurantData] = [:]
    
    // State tracking
    private var lastGeocodeTime = Date.distantPast
    private var lastGeocodeLocation: CLLocationCoordinate2D?
    private var lastDataFetchTime = Date.distantPast
    private var lastDataFetchLocation: CLLocationCoordinate2D?
    
    // Configuration
    private let minimumGeocodeInterval: TimeInterval = 3.0
    private let minimumDistanceChange: CLLocationDegrees = 0.015
    private let minimumDataFetchInterval: TimeInterval = 2.0
    private let minimumDataFetchDistance: CLLocationDegrees = 0.08
    private let zoomedOutThreshold: CLLocationDegrees = 0.5
    private let maxCacheSize = 15
    private let cacheExpiryInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Computed Properties
    var hasValidLocation: Bool {
        locationManager.lastLocation != nil &&
        (locationManager.authorizationStatus == .authorizedWhenInUse ||
         locationManager.authorizationStatus == .authorizedAlways)
    }
    
    var shouldShowClusters: Bool {
        region.span.latitudeDelta > 0.02 && !showSearchResults
    }
    
    // MARK: - Initialization
    init() {
        setupLocationObserver()
    }
    
    // Tasks will be automatically cancelled when the object is deallocated
    
    // MARK: - Public Methods
    func updateRegion(_ newRegion: MKCoordinateRegion) {
        guard !isEqual(region, newRegion, threshold: 0.0001) else { return }
        
        region = newRegion
        debounceRegionUpdate(newRegion)
    }
    
    func performSearch(query: String, maxDistance: Double?) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let distanceFilter = (maxDistance ?? 20.0) < 20.0 ? maxDistance : nil
        
        let result = searchManager.search(
            query: query,
            in: restaurants,
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
        fetchRestaurantDataDebounced(for: coordinate, force: true)
    }
    
    func selectRestaurant(_ restaurant: Restaurant) {
        selectedRestaurant = restaurant
        zoomToRestaurant(restaurant)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showingRestaurantDetail = true
        }
    }
    
    func cleanup() {
        cancelAllTasks()
    }
    
    // MARK: - Private Methods
    private func setupLocationObserver() {
        // Setup initial location when available
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
        updateAreaNameDebounced(for: coordinate)
        fetchRestaurantDataDebounced(for: coordinate)
    }
    
    private func debounceRegionUpdate(_ newRegion: MKCoordinateRegion) {
        regionUpdateTask?.cancel()
        regionUpdateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            guard !Task.isCancelled else { return }
            
            let regionChange = abs(region.center.latitude - newRegion.center.latitude) +
                             abs(region.center.longitude - newRegion.center.longitude)
            
            if regionChange > 0.01 {
                updateAreaNameDebounced(for: newRegion.center)
            }
            
            fetchRestaurantDataDebounced(for: newRegion.center)
        }
    }
    
    private func updateAreaNameDebounced(for coordinate: CLLocationCoordinate2D) {
        geocodeTask?.cancel()
        geocodeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            guard !Task.isCancelled else { return }
            await updateAreaName(for: coordinate)
        }
    }
    
    private func updateAreaName(for coordinate: CLLocationCoordinate2D) async {
        guard shouldUpdateGeocode(coordinate) else { return }
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await withTimeout(seconds: 3) {
                try await geocoder.reverseGeocodeLocation(location)
            }
            
            guard let placemark = placemarks.first else { return }
            
            lastGeocodeTime = Date()
            lastGeocodeLocation = coordinate
            
            let isZoomedOut = region.span.latitudeDelta > zoomedOutThreshold
            
            if isZoomedOut {
                currentAreaName = placemark.administrativeArea ?? placemark.country ?? "Unknown Area"
            } else {
                currentAreaName = placemark.locality ?? placemark.subLocality ?? placemark.administrativeArea ?? "Unknown Area"
            }
        } catch {
            print("Geocoding error: \(error)")
        }
    }
    
    private func fetchRestaurantDataDebounced(for center: CLLocationCoordinate2D, force: Bool = false) {
        dataFetchTask?.cancel()
        
        dataFetchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000) // 800ms
            
            guard !Task.isCancelled else { return }
            await fetchRestaurantData(for: center, force: force)
        }
    }
    
    private func fetchRestaurantData(for center: CLLocationCoordinate2D, force: Bool = false) async {
        guard (force || shouldFetchNewData(for: center)) && !isLoadingRestaurants else { return }
        
        // Check cache first
        let cacheKey = createCacheKey(for: center)
        if let cached = restaurantCache[cacheKey], !cached.isExpired, !force {
            restaurants = cached.restaurants
            return
        }
        
        isLoadingRestaurants = true
        lastDataFetchLocation = center
        lastDataFetchTime = Date()
        
        do {
            let fetchedRestaurants = try await overpassService.fetchFastFoodRestaurants(near: center)
            
            // Cache the results
            restaurantCache[cacheKey] = CachedRestaurantData(
                restaurants: fetchedRestaurants,
                timestamp: Date()
            )
            
            // Clean old cache entries
            cleanCache()
            
            restaurants = fetchedRestaurants
            isLoadingRestaurants = false
        } catch {
            isLoadingRestaurants = false
            print("Error fetching restaurants: \(error)")
        }
    }
    
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
    
    // MARK: - Helper Methods
    private func shouldUpdateGeocode(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let timeSinceLastGeocode = Date().timeIntervalSince(lastGeocodeTime)
        guard timeSinceLastGeocode >= minimumGeocodeInterval else { return false }
        
        if let lastLocation = lastGeocodeLocation {
            let distance = abs(coordinate.latitude - lastLocation.latitude) +
                          abs(coordinate.longitude - lastLocation.longitude)
            return distance >= minimumDistanceChange
        }
        
        return true
    }
    
    private func shouldFetchNewData(for center: CLLocationCoordinate2D) -> Bool {
        let timeSinceLastFetch = Date().timeIntervalSince(lastDataFetchTime)
        guard timeSinceLastFetch >= minimumDataFetchInterval else { return false }
        
        if let lastLocation = lastDataFetchLocation {
            let distance = abs(center.latitude - lastLocation.latitude) +
                          abs(center.longitude - lastLocation.longitude)
            return distance >= minimumDataFetchDistance
        }
        
        return true
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
        dataFetchTask?.cancel()
    }
    
    private func isEqual(_ region1: MKCoordinateRegion, _ region2: MKCoordinateRegion, threshold: Double) -> Bool {
        abs(region1.center.latitude - region2.center.latitude) < threshold &&
        abs(region1.center.longitude - region2.center.longitude) < threshold &&
        abs(region1.span.latitudeDelta - region2.span.latitudeDelta) < threshold &&
        abs(region1.span.longitudeDelta - region2.span.longitudeDelta) < threshold
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
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
    }
}
