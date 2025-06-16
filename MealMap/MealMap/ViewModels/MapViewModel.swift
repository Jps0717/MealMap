import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Distance Calculation Extension
extension CLLocationCoordinate2D {
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
}

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
    
    // MARK: - Search Radius Properties
    @Published var searchRadius: Double = 5.0 // Default 5 miles
    @Published var showSearchRadius = false
    @Published var activeSearchCenter: CLLocationCoordinate2D?
    @Published var hasActiveRadiusFilter = false // NEW: Track if radius filter is active from search

    // MARK: - New Properties for Non-Blocking Loading
    @Published var backgroundLoadingAreas: Set<String> = []
    @Published var loadingProgress: Double = 1.0

    // MARK: - Private Properties
    private let overpassService = OverpassAPIService()
    private let locationManager = LocationManager.shared
    private let searchManager = SearchManager()

    // Enhanced caching for immediate response
    private var regionUpdateTask: Task<Void, Never>?
    private var geocodeTask: Task<Void, Never>?
    private var dataFetchTasks: [String: Task<Void, Never>] = [:]
    private var restaurantCache: [String: CachedRestaurantData] = [:]

    // State tracking
    private var lastGeocodeTime = Date.distantPast
    private var lastGeocodeLocation: CLLocationCoordinate2D?
    private var pendingDataFetches: Set<String> = []

    // Configuration - Optimized for responsiveness
    private let maxCacheSize = 25
    private let cacheExpiryInterval: TimeInterval = 600
    private let preloadRadius: Double = 2.0

    private let regionUpdateThreshold: Double = 0.001 // Was 0.005, now detects even small movements
    private let significantMoveThreshold: Double = 0.003 // Was 0.05, now triggers on 300m moves

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
        let currentCacheKey = createCacheKey(for: region.center)
        if let cached = restaurantCache[currentCacheKey] {
            return cached.restaurants
        }
        return restaurants
    }

    // SIMPLIFIED: Restaurants filtered by search radius - ALWAYS applies when radius is active
    var restaurantsWithinSearchRadius: [Restaurant] {
        guard let userLocation = locationManager.lastLocation else {
            return allAvailableRestaurants
        }

        // Only apply radius filter if we have an active search or radius filter
        guard hasActiveRadiusFilter || showSearchResults else {
            return allAvailableRestaurants
        }

        // ALWAYS filter by radius from user location when radius filter is active
        let userLocationCL = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let radiusInMeters = searchRadius * 1609.344 // Convert miles to meters

        // Get all available restaurants from cache and current area
        let allRestaurants = getAllCachedRestaurantsInArea()

        return allRestaurants.filter { restaurant in
            let restaurantLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
            let distance = userLocationCL.distance(from: restaurantLocation)
            return distance <= radiusInMeters
        }
    }

    // Helper to get all cached restaurants in the surrounding area
    private func getAllCachedRestaurantsInArea() -> [Restaurant] {
        var allRestaurants: [Restaurant] = []

        // Add restaurants from current area
        allRestaurants.append(contentsOf: restaurants)

        // Add restaurants from all cached areas
        for (_, cachedData) in restaurantCache {
            if !cachedData.isExpired {
                allRestaurants.append(contentsOf: cachedData.restaurants)
            }
        }

        // Remove duplicates based on restaurant ID
        var uniqueRestaurants: [Int: Restaurant] = [:]
        for restaurant in allRestaurants {
            uniqueRestaurants[restaurant.id] = restaurant
        }

        return Array(uniqueRestaurants.values)
    }

    // MARK: - Initialization
    init() {
        setupLocationObserver()
    }

    // MARK: - Public Methods - Always Non-blocking and Smooth
    func updateRegion(_ newRegion: MKCoordinateRegion) {
        // INSTANT: Update region immediately for smooth panning
        region = newRegion

        // BACKGROUND: Defer all heavy calculations to background
        Task { @MainActor in
            await handleRegionChangeInBackground(newRegion)
        }
    }

    private func handleRegionChangeInBackground(_ newRegion: MKCoordinateRegion) async {
        // Calculate movement in background to avoid blocking UI
        let latDiff = abs(region.center.latitude - newRegion.center.latitude)
        let lonDiff = abs(region.center.longitude - newRegion.center.longitude)
        let distanceMoved = latDiff + lonDiff

        // Quick check for significant movement
        let isSignificantMove = distanceMoved > significantMoveThreshold
        let needsBackgroundLoading = distanceMoved > regionUpdateThreshold

        // Only show loading for significant moves to new areas
        if isSignificantMove && needsBackgroundLoading {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoadingRestaurants = true
                loadingProgress = 0.0
            }
        }

        // Always start background loading for any meaningful movement (but don't block UI)
        if needsBackgroundLoading {
            startBackgroundDataLoading(for: newRegion, showLoading: isSignificantMove)
        }
    }

    func performSearch(query: String, maxDistance: Double?) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        guard let userLocation = locationManager.lastLocation else {
            searchErrorMessage = "Location access required for search. Please enable location services."
            showSearchError = true
            return
        }
        
        // Set search radius if provided
        if let distance = maxDistance {
            searchRadius = distance
        }
        
        // IMPORTANT: Activate radius filter for search
        hasActiveRadiusFilter = true
        
        // Perform search on ALL available restaurants first
        let result = searchManager.search(
            query: query,
            in: getAllCachedRestaurantsInArea(),
            userLocation: locationManager.lastLocation,
            maxDistance: nil // Don't let SearchManager filter by distance - we'll do it ourselves
        )
        
        handleSearchResult(result)
        
        // Load more data within search radius for better coverage
        loadDataWithinRadius(center: userLocation.coordinate, radiusInMiles: searchRadius)
    }

    func clearSearch() {
        filteredRestaurants = []
        showSearchResults = false
        hasActiveRadiusFilter = false // IMPORTANT: Clear radius filter when search is cleared
        searchManager.hasActiveSearch = false
        // Note: Don't clear radius settings - let user manually control radius
    }

    func refreshData(for coordinate: CLLocationCoordinate2D) {
        startBackgroundDataLoading(for: MKCoordinateRegion(
            center: coordinate,
            span: region.span
        ), force: true, showLoading: true)
    }

    func selectRestaurant(_ restaurant: Restaurant) {
        selectedRestaurant = restaurant
        zoomToRestaurant(restaurant)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showingRestaurantDetail = true
        }
    }

    func cleanup() {
        cancelAllTasks()
    }

    func getCachedRestaurants(for coordinate: CLLocationCoordinate2D) -> [Restaurant]? {
        let cacheKey = createCacheKey(for: coordinate)
        return restaurantCache[cacheKey]?.restaurants
    }

    func getBestAvailableRestaurants(for coordinate: CLLocationCoordinate2D) -> [Restaurant] {
        if let cached = getCachedRestaurants(for: coordinate) {
            return cached
        }
        return restaurants
    }

    // NEW: Update search radius and re-filter results
    func updateSearchRadius(_ newRadius: Double) {
        searchRadius = newRadius
        
        // If we have active search results, re-filter them
        if showSearchResults {
            let radiusFilteredResults = filteredRestaurants.filter { restaurant in
                guard let userLocation = locationManager.lastLocation else { return false }
                
                let userLocationCL = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
                let restaurantLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
                let distance = userLocationCL.distance(from: restaurantLocation)
                let radiusInMeters = searchRadius * 1609.344
                
                return distance <= radiusInMeters
            }
            
            filteredRestaurants = radiusFilteredResults
            
            if radiusFilteredResults.isEmpty {
                searchErrorMessage = "No restaurants found within \(formatRadius(searchRadius)). Try increasing the search distance."
                showSearchError = true
            }
        }
        
        // Load more data if needed
        if let userLocation = locationManager.lastLocation {
            loadDataWithinRadius(center: userLocation.coordinate, radiusInMiles: searchRadius)
        }
    }

    private func formatRadius(_ radius: Double) -> String {
        if radius == floor(radius) {
            return "\(Int(radius)) mile\(radius == 1 ? "" : "s")"
        } else {
            return String(format: "%.1f miles", radius)
        }
    }

    // NEW: Manual search radius toggle function
    func toggleSearchRadius() {
        guard let userLocation = locationManager.lastLocation else { return }
        
        withAnimation(.easeInOut(duration: 0.4)) {
            if showSearchRadius {
                // Turn off search radius
                showSearchRadius = false
                activeSearchCenter = nil
            } else {
                // Turn on search radius at user location
                showSearchRadius = true
                activeSearchCenter = userLocation.coordinate
                // Load data within the search radius
                loadDataWithinRadius(center: userLocation.coordinate, radiusInMiles: searchRadius)
            }
        }
    }

    // MARK: - NEW: Non-blocking Background Loading
    private func startBackgroundDataLoading(for newRegion: MKCoordinateRegion, force: Bool = false, showLoading: Bool = false) {
        // BACKGROUND: Do all work in background to keep UI smooth
        Task.detached { @MainActor in
            await self.updateAreaNameIfNeeded(for: newRegion.center)
            await self.loadRestaurantDataInBackground(for: newRegion.center, force: force, showLoading: showLoading)
            await self.preloadNearbyAreas(around: newRegion.center)
        }
    }

    private func loadRestaurantDataInBackground(for center: CLLocationCoordinate2D, force: Bool = false, showLoading: Bool = false) {
        let cacheKey = createCacheKey(for: center)

        // INSTANT: Check cache immediately without blocking
        if !force, let cached = restaurantCache[cacheKey], !cached.isExpired {
            restaurants = cached.restaurants
            // Hide loading immediately when using cached data
            if isLoadingRestaurants {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingRestaurants = false
                    loadingProgress = 1.0
                }
            }
            return
        }

        // BACKGROUND: Show loading only if we're actually fetching new data
        if showLoading {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoadingRestaurants = true
                loadingProgress = 0.0
            }
        }

        // BACKGROUND: Cancel any existing task for this area
        dataFetchTasks[cacheKey]?.cancel()
        backgroundLoadingAreas.insert(cacheKey)
        updateLoadingProgress()

        // BACKGROUND: Fetch data without blocking main thread
        dataFetchTasks[cacheKey] = Task.detached { @MainActor in
            await self.fetchRestaurantDataNonBlocking(for: center, cacheKey: cacheKey, force: force, showLoading: showLoading)
        }
    }

    private func fetchRestaurantDataNonBlocking(for center: CLLocationCoordinate2D, cacheKey: String, force: Bool, showLoading: Bool = false) async {
        do {
            // Only show loading if explicitly requested (for new data fetches)
            if showLoading {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingRestaurants = true
                    loadingProgress = 0.0
                }
            }

            let fetchedRestaurants = try await overpassService.fetchFastFoodRestaurants(near: center)

            restaurantCache[cacheKey] = CachedRestaurantData(
                restaurants: fetchedRestaurants,
                timestamp: Date()
            )

            cleanCache()

            let currentCacheKey = createCacheKey(for: region.center)
            if cacheKey == currentCacheKey {
                restaurants = fetchedRestaurants
            }

            backgroundLoadingAreas.remove(cacheKey)
            updateLoadingProgress()

            // Hide loading when done (only if we were showing it)
            if showLoading || isLoadingRestaurants {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingRestaurants = false
                    loadingProgress = 1.0
                }
            }

        } catch {
            backgroundLoadingAreas.remove(cacheKey)
            updateLoadingProgress()

            // Hide loading on error too
            if showLoading || isLoadingRestaurants {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingRestaurants = false
                    loadingProgress = 1.0
                }
            }

            print("Background restaurant fetch error: \(error)")
        }

        dataFetchTasks.removeValue(forKey: cacheKey)
    }

    private func preloadNearbyAreas(around center: CLLocationCoordinate2D) async {
        let offsets: [(lat: Double, lon: Double)] = [
            // Immediate adjacent areas (closer)
            (0.005, 0), (-0.005, 0), (0, 0.005), (0, -0.005),
            // Diagonal immediate
            (0.005, 0.005), (-0.005, -0.005), (0.005, -0.005), (-0.005, 0.005),
            // Slightly further areas
            (0.01, 0), (-0.01, 0), (0, 0.01), (0, -0.01),
            // Further diagonal
            (0.01, 0.01), (-0.01, -0.01), (0.01, -0.01), (-0.01, 0.01)
        ]

        for (index, offset) in offsets.enumerated() {
            let nearbyCenter = CLLocationCoordinate2D(
                latitude: center.latitude + offset.lat,
                longitude: center.longitude + offset.lon
            )

            let nearbyCacheKey = createCacheKey(for: nearbyCenter)

            // BACKGROUND: Check cache and loading status without blocking
            if restaurantCache[nearbyCacheKey]?.isExpired != false &&
               !backgroundLoadingAreas.contains(nearbyCacheKey) {

                Task.detached { @MainActor in
                    let delay = index < 8 ? 100_000_000 : 300_000_000 // 100ms for close, 300ms for far
                    try? await Task.sleep(nanoseconds: UInt64(delay))

                    if !self.backgroundLoadingAreas.contains(nearbyCacheKey) {
                        await self.loadRestaurantDataInBackground(for: nearbyCenter)
                    }
                }
            }
        }
    }

    private func updateLoadingProgress() {
        if backgroundLoadingAreas.isEmpty {
            loadingProgress = 1.0
        } else {
            loadingProgress = max(0.2, 1.0 - (Double(backgroundLoadingAreas.count) * 0.2))
        }
    }

    // MARK: - Search Radius Data Loading
    private func loadDataWithinRadius(center: CLLocationCoordinate2D, radiusInMiles: Double) {
        // Calculate the grid of areas to load within the radius
        let metersPerMile = 1609.344
        let radiusInMeters = radiusInMiles * metersPerMile
        let metersPerDegree = 111_319.9 * cos(center.latitude * .pi / 180)
        let radiusInDegrees = radiusInMeters / metersPerDegree

        // Create a grid of points within the radius
        let gridStep = 0.01 // About 1 km
        let gridRange = Int(ceil(radiusInDegrees / gridStep))

        var pointsToLoad: [CLLocationCoordinate2D] = []

        for latStep in -gridRange...gridRange {
            for lonStep in -gridRange...gridRange {
                let testPoint = CLLocationCoordinate2D(
                    latitude: center.latitude + (Double(latStep) * gridStep),
                    longitude: center.longitude + (Double(lonStep) * gridStep)
                )

                // Check if point is within the radius
                let distance = center.distance(to: testPoint)
                if distance <= radiusInMeters {
                    pointsToLoad.append(testPoint)
                }
            }
        }

        // Load data for all points within radius
        Task { @MainActor in
            for (index, point) in pointsToLoad.enumerated() {
                // Stagger the loading to avoid overwhelming the API
                let delay = Double(index) * 0.1
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                await self.loadRestaurantDataInBackground(for: point, showLoading: false)
            }
        }
    }

    private func updateAreaNameIfNeeded(for coordinate: CLLocationCoordinate2D) async {
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
            await updateAreaNameDebounced(for: coordinate)
        }
    }

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

    private func updateAreaNameDebounced(for coordinate: CLLocationCoordinate2D) async {
        geocodeTask?.cancel()
        geocodeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)

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

    private func handleSearchResult(_ result: SearchResult) {
        switch result {
        case .noQuery:
            break
            
        case .noResults(let query):
            searchErrorMessage = "No restaurants found for '\(query)'. Try searching for a restaurant name or cuisine type."
            showSearchError = true
            
        case .singleResult(let restaurant):
            // Apply radius filter to search results
            let radiusFilteredResults = [restaurant].filter { isRestaurantWithinRadius($0) }
            
            if !radiusFilteredResults.isEmpty {
                // Don't set static filteredRestaurants - let the dynamic filtering handle it
                showSearchResults = true
                zoomToShowResults(radiusFilteredResults)
            } else {
                searchErrorMessage = "Restaurant found but outside \(formatRadius(searchRadius)). Try increasing the search distance."
                showSearchError = true
            }
            
        case .chainResult(let restaurant, _):
            let radiusFilteredResults = [restaurant].filter { isRestaurantWithinRadius($0) }
            
            if !radiusFilteredResults.isEmpty {
                showSearchResults = true
                zoomToShowResults(radiusFilteredResults)
            } else {
                searchErrorMessage = "Restaurant found but outside \(formatRadius(searchRadius)). Try increasing the search distance."
                showSearchError = true
            }
            
        case .cuisineResults(let restaurants, _):
            // Filter restaurants by search radius
            let radiusFilteredResults = restaurants.filter { isRestaurantWithinRadius($0) }
            
            if !radiusFilteredResults.isEmpty {
                showSearchResults = true
                zoomToShowResults(radiusFilteredResults)
            } else {
                searchErrorMessage = "Restaurants found but outside \(formatRadius(searchRadius)). Try increasing the search distance."
                showSearchError = true
            }
            
        case .partialNameResult(let restaurant, _):
            let radiusFilteredResults = [restaurant].filter { isRestaurantWithinRadius($0) }
            
            if !radiusFilteredResults.isEmpty {
                showSearchResults = true
                zoomToShowResults(radiusFilteredResults)
            } else {
                searchErrorMessage = "Restaurant found but outside \(formatRadius(searchRadius)). Try increasing the search distance."
                showSearchError = true
            }
        }
    }

    // Helper to check if restaurant is within search radius
    private func isRestaurantWithinRadius(_ restaurant: Restaurant) -> Bool {
        guard let userLocation = locationManager.lastLocation else { return true } // If no location, don't filter
        
        let userLocationCL = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let restaurantLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
        let distance = userLocationCL.distance(from: restaurantLocation)
        let radiusInMeters = searchRadius * 1609.344
        
        return distance <= radiusInMeters
    }

    // Updated zoom function to show search results optimally
    private func zoomToShowResults(_ restaurants: [Restaurant]) {
        guard !restaurants.isEmpty else { return }
        guard let userLocation = locationManager.lastLocation else { return }
        
        if restaurants.count == 1 {
            // Single restaurant - zoom to show both user and restaurant
            let restaurant = restaurants[0]
            let restaurantCoord = CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
            
            let centerLat = (userLocation.coordinate.latitude + restaurantCoord.latitude) / 2
            let centerLon = (userLocation.coordinate.longitude + restaurantCoord.longitude) / 2
            
            let latDiff = abs(userLocation.coordinate.latitude - restaurantCoord.latitude)
            let lonDiff = abs(userLocation.coordinate.longitude - restaurantCoord.longitude)
            
            let span = MKCoordinateSpan(
                latitudeDelta: max(latDiff * 2.5, 0.01),
                longitudeDelta: max(lonDiff * 2.5, 0.01)
            )
            
            withAnimation(.easeInOut(duration: 1.0)) {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: span
                )
            }
        } else {
            // Multiple restaurants - show all within the search radius area
            let allCoords = restaurants.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } + [userLocation.coordinate]
            
            let latitudes = allCoords.map { $0.latitude }
            let longitudes = allCoords.map { $0.longitude }
            
            let minLat = latitudes.min()!
            let maxLat = latitudes.max()!
            let minLon = longitudes.min()!
            let maxLon = longitudes.max()!
            
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            
            let spanLat = max((maxLat - minLat) * 1.5, 0.02)
            let spanLon = max((maxLon - minLon) * 1.5, 0.02)
            
            withAnimation(.easeInOut(duration: 1.0)) {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
                )
            }
        }
    }

    private func showCuisineResults(_ restaurants: [Restaurant]) {
        filteredRestaurants = restaurants
        showSearchResults = true
        
        // Always zoom to show all cuisine results, regardless of zoom level
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
        
        let spanLat = max((maxLat - minLat) * 1.3, 0.02) // Increased padding and minimum span
        let spanLon = max((maxLon - minLon) * 1.3, 0.02) // Increased padding and minimum span
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
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

    private func createCacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        let lat = round(coordinate.latitude * 200) / 200
        let lon = round(coordinate.longitude * 200) / 200
        return "\(lat)_\(lon)"
    }

    private func cleanCache() {
        restaurantCache = restaurantCache.filter { !$0.value.isExpired }
        
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

    private func needsNewDataForRegion(from oldRegion: MKCoordinateRegion, to newRegion: MKCoordinateRegion) -> Bool {
        // Calculate distance moved between centers
        let latDiff = abs(oldRegion.center.latitude - newRegion.center.latitude)
        let lonDiff = abs(oldRegion.center.longitude - newRegion.center.longitude)
        let distanceMoved = latDiff + lonDiff
        
        // 0.003 degrees is roughly 300-400m, making it very responsive
        let significantDistanceThreshold: Double = significantMoveThreshold
        
        // Check if we need new data from the cache/API
        let newCacheKey = createCacheKey(for: newRegion.center)
        
        // Check if we already have this data cached
        let hasDataCached = restaurantCache[newCacheKey]?.isExpired == false
        
        // Always trigger background loading for ANY movement, but only show loading indicator for major moves
        if distanceMoved > regionUpdateThreshold {
            // Always start background loading for any movement
            return true
        }
        
        return false
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

private struct CachedRestaurantData {
    let restaurants: [Restaurant]
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 600
    }
}
