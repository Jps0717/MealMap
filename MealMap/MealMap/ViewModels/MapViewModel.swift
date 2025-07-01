import SwiftUI
import MapKit
import Combine
import CoreLocation

/// Enhanced MapViewModel with nutrition-only display and background caching
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
            debugLog(" 🔄 Filter updated: \(currentFilter.hasActiveFilters ? "active" : "none")")
        }
    }

    // MARK: - Private Properties
    private let _overpassService = OverpassAPIService()
    private let locationManager = LocationManager.shared
    private let nutritionManager = NutritionDataManager.shared
    
    // ENHANCED: Background caching for immediate area
    private var cachedRestaurants: [Restaurant] = []
    private var cacheLocation: CLLocationCoordinate2D?
    private var cacheRadius: Double = 3.0 // Cache 3 mile radius
    private var cacheTimestamp: Date?
    private let cacheExpiryMinutes: Double = 15.0
    
    // State tracking
    var hasInitialized = false
    var userLocation: CLLocationCoordinate2D? {
        locationManager.lastLocation?.coordinate
    }
    
    // FIXED: Reduced geocoding to prevent throttling
    private var lastGeocodedCoordinate: CLLocationCoordinate2D?
    private var lastGeocodingTime: Date = .distantPast
    private let minimumGeocodingInterval: TimeInterval = 10.0 // Increased from 2.0 to 10.0
    
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties
    var hasActiveRadiusFilter: Bool {
        return searchRadius < 20.0
    }

    var shouldShowClusters: Bool {
        return region.span.latitudeDelta > 0.02 && !showSearchResults
    }

    // ENHANCED: Always show restaurants with nutrition data only
    var allAvailableRestaurants: [Restaurant] {
        debugLog(" 🍽️ MapViewModel - allAvailableRestaurants called")
        debugLog(" 🍽️ MapViewModel - Raw restaurants count: \(restaurants.count)")
        
        // FEATURE: Show only restaurants with nutrition data
        let nutritionRestaurants = restaurants.filter { restaurant in
            restaurant.hasNutritionData
        }
        
        debugLog(" 🍽️ MapViewModel - Nutrition restaurants: \(nutritionRestaurants.count)")
        debugLog(" 🍽️ MapViewModel - Filter active: \(currentFilter.hasActiveFilters)")
        
        if !currentFilter.isEmpty {
            let filtered = nutritionRestaurants.filter { restaurant in
                currentFilter.matchesRestaurant(restaurant, userLocation: userLocation)
            }
            debugLog(" 🍽️ MapViewModel - Filtered to \(filtered.count) restaurants")
            return filtered
        }
        
        debugLog(" 🍽️ MapViewModel - Returning \(nutritionRestaurants.count) nutrition restaurants")
        return nutritionRestaurants
    }

    var restaurantsWithinSearchRadius: [Restaurant] {
        debugLog(" 🍽️ MapViewModel - restaurantsWithinSearchRadius called")
        
        guard hasActiveRadiusFilter, let userLocation = userLocation else {
            return allAvailableRestaurants
        }
        
        let filteredByRadius = allAvailableRestaurants.filter { restaurant in
            restaurant.distanceFrom(userLocation) <= searchRadius
        }
        
        debugLog(" 🍽️ MapViewModel - Filtered by \(searchRadius) mile radius: \(filteredByRadius.count) restaurants")
        return filteredByRadius
    }

    init() {
        setupLocationObserver()
        debugLog(" 🍽️ MapViewModel initialized - NUTRITION ONLY with caching")
    }

    // MARK: - ENHANCED: Background caching system
    func fetchRestaurantsWithCaching(for coordinate: CLLocationCoordinate2D) async {
        debugLog(" 🗺️ CACHE CHECK: Checking cache for location: \(coordinate)")
        
        // Check if we have valid cached data
        if let cachedData = getCachedRestaurants(for: coordinate) {
            debugLog(" 🗺️ CACHE HIT: Using \(cachedData.count) cached restaurants")
            await MainActor.run {
                self.restaurants = cachedData
                self.isLoadingRestaurants = false
            }
            
            // Start background refresh for fresh data
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshCacheInBackground(for: coordinate)
            }
            return
        }
        
        // No cache hit, fetch fresh data
        debugLog(" 🗺️ CACHE MISS: Fetching fresh data")
        await fetchRestaurantsForMapCenter(coordinate)
    }
    
    private func getCachedRestaurants(for coordinate: CLLocationCoordinate2D) -> [Restaurant]? {
        guard let cacheLocation = cacheLocation,
              let cacheTimestamp = cacheTimestamp else {
            return nil
        }
        
        // Check if cache is still valid (within 15 minutes)
        let cacheAge = Date().timeIntervalSince(cacheTimestamp)
        if cacheAge > (cacheExpiryMinutes * 60) {
            debugLog(" 🗺️ CACHE EXPIRED: Age \(Int(cacheAge/60)) minutes")
            return nil
        }
        
        // Check if location is within cached area
        let cacheLocationCL = CLLocation(latitude: cacheLocation.latitude, longitude: cacheLocation.longitude)
        let currentLocationCL = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = cacheLocationCL.distance(from: currentLocationCL)
        let distanceInMiles = distance / 1609.34
        
        if distanceInMiles <= cacheRadius {
            debugLog(" 🗺️ CACHE VALID: Distance \(String(format: "%.1f", distanceInMiles)) miles")
            return cachedRestaurants
        }
        
        debugLog(" 🗺️ CACHE MISS: Distance \(String(format: "%.1f", distanceInMiles)) miles > \(cacheRadius) miles")
        return nil
    }
    
    private func refreshCacheInBackground(for coordinate: CLLocationCoordinate2D) async {
        debugLog(" 🗺️ BACKGROUND REFRESH: Updating cache")
        
        do {
            let freshRestaurants = try await _overpassService.fetchAllNearbyRestaurants(
                near: coordinate,
                radius: cacheRadius * 1.5 // Fetch slightly larger area
            )
            
            // Update cache
            cachedRestaurants = freshRestaurants
            cacheLocation = coordinate
            cacheTimestamp = Date()
            
            // FEATURE: Preload nutrition data for popular chains
            await preloadNutritionData(for: freshRestaurants)
            
            debugLog(" 🗺️ BACKGROUND REFRESH: Cache updated with \(freshRestaurants.count) restaurants")
            
        } catch {
            debugLog(" 🗺️ BACKGROUND REFRESH: Failed - \(error)")
        }
    }
    
    private func preloadNutritionData(for restaurants: [Restaurant]) async {
        let nutritionRestaurants = restaurants.filter { $0.hasNutritionData }
        let popularChains = Array(nutritionRestaurants.prefix(10)) // Preload top 10
        
        debugLog(" 🍽️ PRELOAD: Starting nutrition data preload for \(popularChains.count) restaurants")
        
        // Preload in background with delay to not overwhelm API
        for (index, restaurant) in popularChains.enumerated() {
            try? await Task.sleep(nanoseconds: UInt64(index * 100_000_000)) // 100ms delay between requests
            
            Task.detached(priority: .background) { [weak self] in
                guard let self = self else { return }
                _ = await self.nutritionManager.loadNutritionData(for: restaurant.name)
            }
        }
    }

    // MARK: - Direct Map Region Updates
    func updateMapRegion(_ newRegion: MKCoordinateRegion) {
        region = newRegion
        updateAreaNameDebounced(for: newRegion.center)
        
        debugLog(" 🗺️ MAP REGION CHANGED: Fetching restaurants for new viewport")
        Task {
            await fetchRestaurantsWithCaching(for: newRegion.center)
        }
    }
    
    func fetchRestaurantsForMapRegion(_ mapRegion: MKCoordinateRegion) async {
        await fetchRestaurantsWithCaching(for: mapRegion.center)
    }

    // MARK: - Enhanced data refresh
    func refreshData(for coordinate: CLLocationCoordinate2D) {
        guard !isLoadingRestaurants else { return }
        
        debugLog(" 🔄 REFRESH: Getting restaurants for coordinate: \(coordinate)")
        
        locationManager.refreshCurrentLocation()
        
        isLoadingRestaurants = true
        loadingProgress = 0.0
        
        // Update region first
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
            
            await self.fetchRestaurantsWithCaching(for: coordinate)
            
            await MainActor.run {
                self.loadingProgress = 1.0
                self.hasInitialized = true
                debugLog(" 🔄 REFRESH FINAL: Loaded \(self.restaurants.count) restaurants")
            }
        }
    }
    
    // MARK: - Backward compatibility methods
    func updateRegion(_ newRegion: MKCoordinateRegion) {
        updateMapRegion(newRegion)
    }
    
    func fetchRestaurantsForRegion(_ mapRegion: MKCoordinateRegion) async {
        await fetchRestaurantsForMapRegion(mapRegion)
    }
    
    func fetchRestaurantsForMapCenter(_ center: CLLocationCoordinate2D) async {
        debugLog(" 🗺️ DIRECT FETCH: Getting restaurants for center: \(center)")
        
        await MainActor.run {
            self.isLoadingRestaurants = true
        }
        
        do {
            let restaurants = try await _overpassService.fetchAllNearbyRestaurants(
                near: center,
                radius: cacheRadius
            )
            
            // Update cache
            cachedRestaurants = restaurants
            cacheLocation = center
            cacheTimestamp = Date()
            
            await MainActor.run {
                self.restaurants = restaurants
                self.isLoadingRestaurants = false
                debugLog(" 🗺️ SUCCESS: Loaded \(restaurants.count) restaurants")
                
                if let firstRestaurant = restaurants.first {
                    debugLog(" 🗺️ First restaurant: \(firstRestaurant.name) at \(firstRestaurant.latitude), \(firstRestaurant.longitude)")
                }
            }
            
            // Background nutrition preload
            await preloadNutritionData(for: restaurants)
            
        } catch {
            await MainActor.run {
                self.isLoadingRestaurants = false
                debugLog(" 🗺️ Error fetching restaurants: \(error)")
                
                // Use cached data if available
                if !cachedRestaurants.isEmpty {
                    self.restaurants = cachedRestaurants
                    debugLog(" 🗺️ Using cached data: \(self.cachedRestaurants.count) restaurants")
                } else {
                    self.restaurants = createFallbackRestaurants(for: center)
                }
            }
        }
    }
    
    func fetchRestaurantsForCurrentRegion() async {
        await fetchRestaurantsForMapRegion(region)
    }
    
    func fetchRestaurantsForZoomLevel(_ center: CLLocationCoordinate2D, zoomLevel: ZoomLevel) async {
        await fetchRestaurantsForMapCenter(center)
    }
    
    func updateZoomLevel(for region: MKCoordinateRegion) {
        // No-op for simplicity
    }

    // MARK: - Search functionality
    func performSearch(query: String) async {
        isLoadingRestaurants = true
        
        // Search through all restaurants including cached ones
        let allRestaurants = restaurants + cachedRestaurants
        let uniqueRestaurants = Array(Set(allRestaurants))
        
        let searchResults = uniqueRestaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(query) ||
            restaurant.cuisine?.localizedCaseInsensitiveContains(query) == true
        }
        
        // FEATURE: Prioritize restaurants with nutrition data
        let nutritionResults = searchResults.filter { $0.hasNutritionData }
        let otherResults = searchResults.filter { !$0.hasNutritionData }
        
        let combinedResults = nutritionResults + otherResults
        
        // Sort by distance if user location is available
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
            debugLog(" 🔍 Search completed: \(self.filteredRestaurants.count) results for '\(query)'")
        }
    }
    
    func clearSearch() {
        showSearchResults = false
        filteredRestaurants = []
        debugLog(" 🔍 Search cleared")
    }

    // MARK: - Location and area management
    func setInitialLocation(_ coordinate: CLLocationCoordinate2D) {
        debugLog(" 📍 Setting initial location: \(coordinate)")
        
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
                if let location = self?.locationManager.lastLocation?.coordinate {
                    self?.setInitialLocation(location)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - FIXED: Reduced geocoding to prevent throttling
    func updateAreaNameDebounced(for coordinate: CLLocationCoordinate2D) {
        guard shouldPerformGeocoding(for: coordinate) else { return }
        
        Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // Increased to 3 seconds
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
                    debugLog(" 📍 Updated area name: \(areaName)")
                }
            }
        } catch {
            await MainActor.run {
                self.currentAreaName = "Unknown Location"
                debugLog(" ❌ Geocoding failed: \(error)")
            }
        }
    }

    private func shouldPerformGeocoding(for coordinate: CLLocationCoordinate2D) -> Bool {
        let now = Date()
        
        // FIXED: Increased minimum interval to prevent throttling
        if now.timeIntervalSince(lastGeocodingTime) < minimumGeocodingInterval {
            return false
        }
        
        if let lastCoordinate = lastGeocodedCoordinate {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = lastLocation.distance(from: currentLocation)
            
            // FIXED: Increased distance threshold to reduce geocoding frequency
            return distance > 5000 // Increased from 2000 to 5000 meters
        }
        
        return true
    }
    
    // MARK: - Fallback restaurants (nutrition chains only)
    private func createFallbackRestaurants(for coordinate: CLLocationCoordinate2D) -> [Restaurant] {
        debugLog(" 🆘 Using fallback nutrition restaurants for location: \(coordinate)")
        
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

// MARK: - Filter clearing
extension MapViewModel {
    func clearFiltersOnHomeScreen() {
        debugLog(" 🏠 Clearing filters for home screen")
        currentFilter = RestaurantFilter()
    }
    
    func createCleanMapViewModel() -> MapViewModel {
        let cleanViewModel = MapViewModel()
        cleanViewModel.restaurants = self.restaurants
        cleanViewModel.cachedRestaurants = self.cachedRestaurants
        cleanViewModel.region = self.region
        cleanViewModel.currentAreaName = self.currentAreaName
        cleanViewModel.hasInitialized = self.hasInitialized
        cleanViewModel.cacheLocation = self.cacheLocation
        cleanViewModel.cacheTimestamp = self.cacheTimestamp
        return cleanViewModel
    }
}
