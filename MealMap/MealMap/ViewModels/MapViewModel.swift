import SwiftUI
import MapKit
import Combine
import CoreLocation

/// Enhanced MapViewModel with smart pin caching and minimal reloading
final class MapViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var restaurants: [Restaurant] = []
    @Published var isLoadingRestaurants = false
    @Published var showSearchResults = false
    @Published var filteredRestaurants: [Restaurant] = []
    @Published var searchRadius: Double = 5.0
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var currentAreaName: String = "Loading location..."
    @Published var loadingProgress: Double = 0.0
    
    // Filter management
    @Published var currentFilter = RestaurantFilter() {
        didSet {
            objectWillChange.send()
            debugLog("🔄 Filter updated: \(currentFilter.hasActiveFilters ? "active" : "none")")
        }
    }

    // MARK: - Private Properties
    private let _overpassService = OverpassAPIService()
    private let locationManager = LocationManager.shared
    private let nutritionManager = NutritionDataManager.shared
    
    // ENHANCED: Smart pin caching system
    private var displayedPinIds: Set<Int> = []
    private var loadedRegions: [CachedRegion] = []
    private var cacheLocation: CLLocationCoordinate2D?
    private var cacheRadius: Double = 3.0
    private var cacheTimestamp: Date?
    private let cacheExpiryMinutes: Double = 30.0
    
    private var lastUpdateTime: Date = Date.distantPast
    private var updateDebounceTimer: Timer?
    private let minimumMovementThreshold: Double = 500.0
    
    // MARK: - Cached Region Tracking
    struct CachedRegion {
        let center: CLLocationCoordinate2D
        let radius: Double
        let timestamp: Date
        let restaurantIds: Set<Int>
        
        func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return centerLocation.distance(from: targetLocation) <= radius
        }
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 1800
        }
    }
    
    // State tracking
    var hasInitialized = false
    var userLocation: CLLocationCoordinate2D? {
        locationManager.lastLocation?.coordinate
    }
    
    private var lastGeocodedCoordinate: CLLocationCoordinate2D?
    private var lastGeocodingTime: Date = .distantPast
    private let minimumGeocodingInterval: TimeInterval = 30.0
    
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties
    var hasActiveRadiusFilter: Bool {
        return searchRadius < 20.0
    }

    var shouldShowClusters: Bool {
        return region.span.latitudeDelta > 0.02 && !showSearchResults
    }

    var allAvailableRestaurants: [Restaurant] {
        if !currentFilter.isEmpty {
            let filtered = restaurants.filter { restaurant in
                currentFilter.matchesRestaurant(restaurant, userLocation: userLocation)
            }
            return sortRestaurantsByPriority(filtered)
        }
        
        return sortRestaurantsByPriority(restaurants)
    }
    
    var restaurantsWithinSearchRadius: [Restaurant] {
        guard hasActiveRadiusFilter, let userLocation = userLocation else {
            return allAvailableRestaurants
        }
        
        let filteredByRadius = allAvailableRestaurants.filter { restaurant in
            restaurant.distanceFrom(userLocation) <= searchRadius
        }
        
        return filteredByRadius
    }

    init() {
        setupLocationObserver()
        debugLog("🍽️ MapViewModel initialized - Smart pin caching enabled")
    }

    // MARK: - Private Methods
    private func sortRestaurantsByPriority(_ restaurants: [Restaurant]) -> [Restaurant] {
        return restaurants.sorted { restaurant1, restaurant2 in
            let hasNutrition1 = restaurant1.hasNutritionData
            let hasNutrition2 = restaurant2.hasNutritionData
            
            if hasNutrition1 != hasNutrition2 {
                return hasNutrition1
            }
            
            if let userLocation = userLocation {
                let distance1 = restaurant1.distanceFrom(userLocation)
                let distance2 = restaurant2.distanceFrom(userLocation)
                return distance1 < distance2
            }
            
            return restaurant1.name < restaurant2.name
        }
    }

    // MARK: - Smart pin caching system
    func fetchRestaurantsWithCaching(for coordinate: CLLocationCoordinate2D) async {
        if let cachedData = getRestaurantsForRegion(coordinate) {
            debugLog("📍 REGION CACHED: Using existing data for \(coordinate)")
            await MainActor.run {
                let newRestaurants = cachedData.filter { restaurant in
                    !self.displayedPinIds.contains(restaurant.id)
                }
                
                if !newRestaurants.isEmpty {
                    self.restaurants.append(contentsOf: newRestaurants)
                    self.displayedPinIds.formUnion(Set(newRestaurants.map { $0.id }))
                    debugLog("📍 ADDED \(newRestaurants.count) new pins to existing \(self.restaurants.count) pins")
                }
                self.isLoadingRestaurants = false
            }
            return
        }
        
        if !shouldFetchNewData(for: coordinate) {
            debugLog("📍 MOVEMENT TOO SMALL: Skipping fetch for \(coordinate)")
            return
        }
        
        debugLog("📍 FETCHING NEW REGION: \(coordinate)")
        await fetchRestaurantsForNewRegion(coordinate)
    }
    
    private func getRestaurantsForRegion(_ coordinate: CLLocationCoordinate2D) -> [Restaurant]? {
        loadedRegions.removeAll { $0.isExpired }
        
        for region in loadedRegions {
            if region.contains(coordinate) {
                let regionRestaurants = restaurants.filter { restaurant in
                    region.restaurantIds.contains(restaurant.id)
                }
                if !regionRestaurants.isEmpty {
                    return regionRestaurants
                }
            }
        }
        
        return nil
    }
    
    private func shouldFetchNewData(for coordinate: CLLocationCoordinate2D) -> Bool {
        guard let lastLocation = cacheLocation else { return true }
        
        let lastLocationCL = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
        let currentLocationCL = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = lastLocationCL.distance(from: currentLocationCL)
        
        return distance >= minimumMovementThreshold
    }
    
    private func fetchRestaurantsForNewRegion(_ coordinate: CLLocationCoordinate2D) async {
        await MainActor.run {
            self.isLoadingRestaurants = true
        }
        
        do {
            let newRestaurants = try await _overpassService.fetchAllNearbyRestaurants(
                near: coordinate,
                radius: cacheRadius
            )
            
            await MainActor.run {
                let trulyNewRestaurants = newRestaurants.filter { restaurant in
                    !self.displayedPinIds.contains(restaurant.id)
                }
                
                if !trulyNewRestaurants.isEmpty {
                    self.restaurants.append(contentsOf: trulyNewRestaurants)
                    self.displayedPinIds.formUnion(Set(trulyNewRestaurants.map { $0.id }))
                }
                
                let cachedRegion = CachedRegion(
                    center: coordinate,
                    radius: self.cacheRadius * 1609.34,
                    timestamp: Date(),
                    restaurantIds: Set(newRestaurants.map { $0.id })
                )
                self.loadedRegions.append(cachedRegion)
                
                self.cacheLocation = coordinate
                self.cacheTimestamp = Date()
                
                self.isLoadingRestaurants = false
                debugLog("📍 LOADED \(trulyNewRestaurants.count) new restaurants. Total: \(self.restaurants.count)")
            }
            
            await preloadOnlyNutritionAvailability(for: newRestaurants)
            
        } catch {
            await MainActor.run {
                self.isLoadingRestaurants = false
                debugLog("❌ Error fetching restaurants: \(error)")
            }
        }
    }
    
    private func preloadOnlyNutritionAvailability(for restaurants: [Restaurant]) async {
        let nutritionRestaurants = restaurants.filter { $0.hasNutritionData }
        debugLog("🍽️ NUTRITION CHECK: \(nutritionRestaurants.count) restaurants have nutrition data (no menu loading)")
        
        for restaurant in nutritionRestaurants.prefix(5) {
            if await nutritionManager.hasNutritionData(for: restaurant.name) {
                debugLog("✅ \(restaurant.name) - nutrition available")
            }
        }
    }

    // MARK: - Map Region Updates
    func updateMapRegion(_ newRegion: MKCoordinateRegion) {
        region = newRegion
        updateAreaNameDebounced(for: newRegion.center)
        
        Task {
            await smartRegionUpdate(for: newRegion.center)
        }
    }
    
    private func smartRegionUpdate(for coordinate: CLLocationCoordinate2D) async {
        if getRestaurantsForRegion(coordinate) != nil {
            debugLog("📍 REGION KNOWN: No fetch needed for \(coordinate)")
            return
        }
        
        await fetchRestaurantsWithCaching(for: coordinate)
    }
    
    func fetchRestaurantsForMapRegion(_ mapRegion: MKCoordinateRegion) async {
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) > 3.0 else {
            debugLog("🔒 RATE LIMITED: Skipping fetch, too soon after last update")
            return
        }
        
        let currentSpan = mapRegion.span.latitudeDelta
        let shouldFetch = currentSpan <= 0.02
        
        guard shouldFetch else {
            debugLog("🗺️ SKIPPED: Zoom level too high for fetching: \(String(format: "%.3f", currentSpan))")
            return
        }
        
        lastUpdateTime = now
        
        let coordinate = mapRegion.center
        await fetchRestaurantsWithCaching(for: coordinate)
    }

    func fetchRestaurantsForZoomLevel(_ center: CLLocationCoordinate2D, zoomLevel: ZoomLevel) async {
        await fetchRestaurantsForMapCenter(center)
    }

    func updateZoomLevel(for region: MKCoordinateRegion) {
        // No-op for simplicity
    }

    // MARK: - Data refresh
    func refreshData(for coordinate: CLLocationCoordinate2D) {
        guard !isLoadingRestaurants else { return }
        
        debugLog("🔄 MANUAL REFRESH: Force clearing cache and fetching fresh data")
        
        clearAllCachedData()
        
        locationManager.refreshCurrentLocation()
        
        isLoadingRestaurants = true
        loadingProgress = 0.0
        
        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run {
                self.loadingProgress = 0.2
            }
            
            await self.fetchRestaurantsForNewRegion(coordinate)
            
            await MainActor.run {
                self.loadingProgress = 1.0
                self.hasInitialized = true
                debugLog("🔄 MANUAL REFRESH COMPLETE: \(self.restaurants.count) restaurants")
            }
        }
    }
    
    private func clearAllCachedData() {
        restaurants.removeAll()
        displayedPinIds.removeAll()
        loadedRegions.removeAll()
        cacheLocation = nil
        cacheTimestamp = nil
        debugLog("🗑️ CACHE CLEARED: All pin and region data cleared")
    }
    
    // MARK: - Backward compatibility methods
    func updateRegion(_ newRegion: MKCoordinateRegion) {
        updateMapRegion(newRegion)
    }
    
    func fetchRestaurantsForRegion(_ mapRegion: MKCoordinateRegion) async {
        await fetchRestaurantsForMapRegion(mapRegion)
    }
    
    func fetchRestaurantsForMapCenter(_ center: CLLocationCoordinate2D) async {
        await fetchRestaurantsWithCaching(for: center)
    }
    
    func fetchRestaurantsForCurrentRegion() async {
        await fetchRestaurantsForMapRegion(region)
    }

    // MARK: - Search functionality
    func performSearch(query: String) async {
        isLoadingRestaurants = true
        
        let searchResults = restaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(query) ||
            restaurant.cuisine?.localizedCaseInsensitiveContains(query) == true
        }
        
        let nutritionResults = searchResults.filter { $0.hasNutritionData }
        let otherResults = searchResults.filter { !$0.hasNutritionData }
        
        let combinedResults = nutritionResults + otherResults
        
        let sortedResults: [Restaurant]
        if let userLocation = userLocation {
            sortedResults = combinedResults.sorted { r1, r2 in
                let distance1 = r1.distanceFrom(userLocation)
                let distance2 = r2.distanceFrom(userLocation)
                return distance1 < distance2
            }
        } else {
            sortedResults = combinedResults.sorted { $0.name < $1.name }
        }
        
        await MainActor.run {
            self.filteredRestaurants = Array(sortedResults.prefix(50))
            self.showSearchResults = true
            self.isLoadingRestaurants = false
            debugLog("🔍 Search completed: \(self.filteredRestaurants.count) results for '\(query)'")
        }
    }
    
    func clearSearch() {
        showSearchResults = false
        filteredRestaurants = []
        debugLog("🔍 Search cleared")
    }

    // MARK: - Location and area management
    func setInitialLocation(_ coordinate: CLLocationCoordinate2D) {
        if let lastCoordinate = cacheLocation {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = lastLocation.distance(from: currentLocation)
            
            if distance < 100 {
                return
            }
        }
        
        debugLog("📍 Setting initial location: \(coordinate)")
        
        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        Task.detached(priority: .utility) { [weak self] in
            await self?.updateAreaName(for: coordinate)
        }
    }

    private func setupLocationObserver() {
        locationManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                
                if let location = self.locationManager.lastLocation?.coordinate {
                    if !self.hasInitialized {
                        self.setInitialLocation(location)
                        self.hasInitialized = true
                    }
                }
            }
            .store(in: &cancellables)
    }

    func updateAreaNameDebounced(for coordinate: CLLocationCoordinate2D) {
        guard shouldPerformGeocoding(for: coordinate) else { return }
        
        Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await self?.updateAreaName(for: coordinate)
        }
    }

    private func updateAreaName(for coordinate: CLLocationCoordinate2D) async {
        lastGeocodingTime = Date()
        lastGeocodedCoordinate = coordinate
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let areaName = placemark.locality ?? placemark.subAdministrativeArea ?? "Current Location"
                
                await MainActor.run {
                    self.currentAreaName = areaName
                    debugLog("📍 Updated area name: \(areaName)")
                }
            }
        } catch {
            await MainActor.run {
                self.currentAreaName = "Unknown Location"
                debugLog("❌ Geocoding failed: \(error)")
            }
        }
    }

    private func shouldPerformGeocoding(for coordinate: CLLocationCoordinate2D) -> Bool {
        let now = Date()
        
        if now.timeIntervalSince(lastGeocodingTime) < minimumGeocodingInterval {
            return false
        }
        
        if let lastCoordinate = lastGeocodedCoordinate {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = lastLocation.distance(from: currentLocation)
            
            return distance > 5000
        }
        
        return true
    }
    
    private func createFallbackRestaurants(for coordinate: CLLocationCoordinate2D) -> [Restaurant] {
        debugLog("🆘 Using fallback nutrition restaurants for location: \(coordinate)")
        
        return [
            Restaurant(
                id: 999991,
                name: "McDonald's",
                latitude: coordinate.latitude + 0.001,
                longitude: coordinate.longitude + 0.001,
                address: "123 Main St",
                cuisine: "Fast Food",
                openingHours: "24/7",
                phone: nil,
                website: nil,
                type: "node"
            ),
            Restaurant(
                id: 999992,
                name: "Starbucks",
                latitude: coordinate.latitude - 0.001,
                longitude: coordinate.longitude + 0.001,
                address: "456 Coffee Ave",
                cuisine: "Cafe",
                openingHours: "6 AM - 10 PM",
                phone: nil,
                website: nil,
                type: "node"
            ),
            Restaurant(
                id: 999993,
                name: "Subway",
                latitude: coordinate.latitude + 0.001,
                longitude: coordinate.longitude - 0.001,
                address: "789 Sandwich Blvd",
                cuisine: "Sandwiches",
                openingHours: "10 AM - 10 PM",
                phone: nil,
                website: nil,
                type: "node"
            ),
            Restaurant(
                id: 999994,
                name: "Chipotle",
                latitude: coordinate.latitude - 0.001,
                longitude: coordinate.longitude - 0.001,
                address: "321 Burrito Lane",
                cuisine: "Mexican",
                openingHours: "11 AM - 10 PM",
                phone: nil,
                website: nil,
                type: "node"
            ),
            Restaurant(
                id: 999995,
                name: "Panera Bread",
                latitude: coordinate.latitude + 0.002,
                longitude: coordinate.longitude,
                address: "555 Bread St",
                cuisine: "Bakery",
                openingHours: "6 AM - 9 PM",
                phone: nil,
                website: nil,
                type: "node"
            )
        ]
    }
}

// MARK: - Filter clearing extension
extension MapViewModel {
    func clearFiltersOnHomeScreen() {
        debugLog("🏠 Clearing filters for home screen")
        currentFilter = RestaurantFilter()
    }
    
    func createCleanMapViewModel() -> MapViewModel {
        let cleanViewModel = MapViewModel()
        cleanViewModel.restaurants = self.restaurants
        cleanViewModel.loadedRegions = self.loadedRegions
        cleanViewModel.region = self.region
        cleanViewModel.currentAreaName = self.currentAreaName
        cleanViewModel.hasInitialized = self.hasInitialized
        cleanViewModel.cacheLocation = self.cacheLocation
        cleanViewModel.cacheTimestamp = self.cacheTimestamp
        return cleanViewModel
    }
}