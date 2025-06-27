import SwiftUI
import MapKit
import CoreLocation

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
    @Published var searchRadius: Double = 2.5
    @Published var showSearchRadius = false
    @Published var activeSearchCenter: CLLocationCoordinate2D?
    @Published var hasActiveRadiusFilter = false

    // MARK: - Loading Progress
    @Published var loadingProgress: Double = 1.0
    
    @Published var currentFilter = RestaurantFilter() {
        didSet {
            objectWillChange.send()
            debugLog(" Filter updated: \(currentFilter.hasActiveFilters ? "active" : "none")")
        }
    }

    // MARK: - Private Properties - NO CACHING
    private let _overpassService = OverpassAPIService()
    private let locationManager = LocationManager.shared
    private let searchManager = SearchManager()
    private let nutritionManager = NutritionDataManager.shared
    
    var overpassService: OverpassAPIService {
        return _overpassService
    }
    
    private var geocoder = CLGeocoder()
    private var lastGeocodingTime: Date = Date.distantPast
    private var minimumGeocodingInterval: TimeInterval = 10.0 // 10 seconds between requests
    private var lastGeocodedCoordinate: CLLocationCoordinate2D?
    private var minimumDistanceThreshold: Double = 2000.0 // 2km in meters
    
    var userLocation: CLLocationCoordinate2D? {
        locationManager.lastLocation?.coordinate
    }
    private var hasLoadedInitialData = false
    private var geocodeTask: Task<Void, Never>?
    private var dataFetchTask: Task<Void, Never>?
    private var currentLoadingTask: Task<Void, Never>?
    
    private var hasInitialized = false
    
    private var regionUpdateTask: Task<Void, Never>?
    private var areaNameUpdateTask: Task<Void, Never>?

    // MARK: - Computed Properties
    var hasValidLocation: Bool {
        locationManager.lastLocation != nil &&
        (locationManager.authorizationStatus == .authorizedWhenInUse ||
         locationManager.authorizationStatus == .authorizedAlways)
    }

    var shouldShowClusters: Bool {
        region.span.latitudeDelta > 0.02 && !showSearchResults
    }

    var allAvailableRestaurants: [Restaurant] {
        debugLog(" MapViewModel - allAvailableRestaurants called (NO CACHING)")
        debugLog(" MapViewModel - Raw restaurants count: \(restaurants.count)")
        debugLog(" MapViewModel - Filter active: \(currentFilter.hasActiveFilters)")
        
        if !currentFilter.isEmpty {
            let filtered = restaurants.filter { restaurant in
                currentFilter.matchesRestaurant(restaurant, userLocation: userLocation)
            }
            debugLog(" MapViewModel - Filtered to \(filtered.count) restaurants")
            return filtered
        }
        
        debugLog(" MapViewModel - Returning ALL \(restaurants.count) restaurants")
        return restaurants
    }

    var restaurantsWithinSearchRadius: [Restaurant] {
        debugLog(" MapViewModel - restaurantsWithinSearchRadius called (NO CACHING)")
        debugLog(" MapViewModel - hasActiveRadiusFilter: \(hasActiveRadiusFilter)")
        debugLog(" MapViewModel - showSearchResults: \(showSearchResults)")
        
        debugLog(" MapViewModel - Returning ALL restaurants (no radius filtering)")
        return allAvailableRestaurants
    }

    // MARK: - Initialization
    init() {
        setupLocationObserver()
        debugLog(" MapViewModel initialized - NO CACHING - restaurant loading deferred until map is shown")
    }

    // MARK: - NO CACHING: Always fresh API calls - MAP CENTERED WITH 50 LIMIT
    func updateMapRegion(_ newRegion: MKCoordinateRegion) {
        region = newRegion
        updateAreaNameDebounced(for: newRegion.center)
        
        // DYNAMIC MAP UPDATE: Fetch restaurants for new map center
        debugLog(" MAP PAN: Fetching 50 restaurants centered on new map position")
        Task {
            await fetchRestaurantsForMapCenter(newRegion.center)
        }
    }
    
    func fetchRestaurantsForMapCenter(_ center: CLLocationCoordinate2D) async {
        debugLog(" MAP CENTER FETCH: Getting 50 restaurants around (\(center.latitude), \(center.longitude))")
        
        await MainActor.run {
            self.isLoadingRestaurants = true
        }
        
        do {
            // ALWAYS call API for map center with 2.5 mile radius
            let restaurants = try await _overpassService.fetchAllNearbyRestaurants(
                near: center,
                radius: 2.5
            )
            
            await MainActor.run {
                self.restaurants = restaurants
                self.isLoadingRestaurants = false
                debugLog(" MAP CENTER: Loaded \(restaurants.count) restaurants (max 50)")
            }
        } catch {
            await MainActor.run {
                self.isLoadingRestaurants = false
                debugLog(" Map center fetch failed: \(error)")
            }
        }
    }
    
    func fetchRestaurantsForRegion(_ mapRegion: MKCoordinateRegion) async {
        // REDIRECT: Use map center fetch instead
        await fetchRestaurantsForMapCenter(mapRegion.center)
    }

    func updateRegion(_ newRegion: MKCoordinateRegion) {
        regionUpdateTask?.cancel()
        
        regionUpdateTask = Task.detached(priority: .utility) { @MainActor [weak self] in
            guard let self = self else { return }
            
            try? await Task.sleep(nanoseconds: 500_000_000) // Reduced delay for faster updates
            guard !Task.isCancelled else { return }
            
            let latDiff = abs(self.region.center.latitude - newRegion.center.latitude)
            let lonDiff = abs(self.region.center.longitude - newRegion.center.longitude)
            let spanDiff = abs(self.region.span.latitudeDelta - newRegion.span.latitudeDelta)
            
            if latDiff > 0.002 || lonDiff > 0.002 || spanDiff > 0.001 {
                self.region = newRegion
                
                if latDiff > 0.01 || lonDiff > 0.01 {
                    self.updateAreaNameDebounced(for: newRegion.center)
                }
                
                // DYNAMIC UPDATE: Fetch fresh data when map moves significantly
                debugLog(" MAP MOVED: Fetching fresh 50 restaurants for new center")
                await self.fetchRestaurantsForMapCenter(newRegion.center)
            }
        }
    }

    func refreshData(for coordinate: CLLocationCoordinate2D) {
        guard !isLoadingRestaurants else { return }
        
        debugLog(" REFRESH: Getting 50 restaurants around coordinate: \(coordinate)")
        
        // Force a fresh location update first
        locationManager.refreshCurrentLocation()
        
        isLoadingRestaurants = true
        loadingProgress = 0.0
        
        dataFetchTask?.cancel()
        
        dataFetchTask = Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run {
                self.loadingProgress = 0.2
            }
            
            do {
                debugLog(" REFRESH API: Starting fresh fetch for 50 restaurants")
                
                // Use the standardized map center fetch
                let fetchedRestaurants = try await self._overpassService.fetchAllNearbyRestaurants(
                    near: coordinate,
                    radius: 2.5
                )
                
                debugLog(" REFRESH SUCCESS: Got \(fetchedRestaurants.count) restaurants")
                
                await MainActor.run {
                    self.loadingProgress = 0.8
                }
                
                await MainActor.run {
                    self.restaurants = fetchedRestaurants
                    self.loadingProgress = 1.0
                    self.isLoadingRestaurants = false
                    self.hasInitialized = true
                    
                    debugLog(" REFRESH FINAL: Loaded \(fetchedRestaurants.count) restaurants (max 50)")
                    
                    let nutritionRestaurants = fetchedRestaurants.filter { $0.hasNutritionData }
                    debugLog(" Found \(nutritionRestaurants.count) restaurants with nutrition data")
                }
                
            } catch {
                await MainActor.run {
                    debugLog(" Error fetching restaurants: \(error)")
                    
                    // Use fallback restaurants with REAL user coordinates
                    let userCoord = self.userLocation ?? coordinate
                    debugLog(" Using fallback restaurants for real location: \(userCoord)")
                    
                    let testRestaurants = [
                        Restaurant(
                            id: 999991,
                            name: "McDonald's",
                            latitude: userCoord.latitude + 0.001,
                            longitude: userCoord.longitude + 0.001,
                            address: "Test Address 1",
                            cuisine: "Fast Food",
                            openingHours: nil,
                            phone: nil,
                            website: nil,
                            type: "node"
                        ),
                        Restaurant(
                            id: 999992,
                            name: "Subway",
                            latitude: userCoord.latitude - 0.001,
                            longitude: userCoord.longitude + 0.001,
                            address: "Test Address 2",
                            cuisine: "Fast Food",
                            openingHours: nil,
                            phone: nil,
                            website: nil,
                            type: "node"
                        )
                    ]
                    
                    self.restaurants = testRestaurants
                    debugLog(" MapViewModel - Using fallback test restaurants: \(testRestaurants.count)")
                    
                    self.isLoadingRestaurants = false
                    self.loadingProgress = 1.0
                }
            }
        }
    }

    func performSearch(query: String, maxDistance: Double? = 2.5) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        guard let userLocation = locationManager.lastLocation else {
            Task { @MainActor in
                self.searchErrorMessage = "Location access required for search. Please enable location services."
                self.showSearchError = true
            }
            return
        }
        
        if let distance = maxDistance {
            searchRadius = distance
        }
        
        hasActiveRadiusFilter = true
        
        let result = searchManager.search(
            query: query,
            in: restaurants,
            userLocation: userLocation,
            maxDistance: searchRadius
        )
        
        Task { @MainActor in
            self.handleSearchResult(result)
        }
    }

    func clearSearch() {
        Task { @MainActor in
            self.filteredRestaurants = []
            self.showSearchResults = false
            self.hasActiveRadiusFilter = false
            self.searchManager.hasActiveSearch = false
        }
    }
    
    func applyFilter(_ filter: RestaurantFilter) {
        debugLog(" Applying filter: \(filter)")
        currentFilter = filter
    }
    
    func clearFilters() {
        debugLog(" Clearing all filters")
        currentFilter = RestaurantFilter()
    }

    func selectRestaurant(_ restaurant: Restaurant) {
        selectedRestaurant = restaurant
        zoomToRestaurant(restaurant)
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            self?.showingRestaurantDetail = true
        }
    }

    func cleanup() {
        dataFetchTask?.cancel()
        geocodeTask?.cancel()
        regionUpdateTask?.cancel()
        areaNameUpdateTask?.cancel()
        currentLoadingTask?.cancel()
        
        geocoder.cancelGeocode()
    }

    // MARK: - Private Methods
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
        
        Task.detached(priority: .utility) { [weak self] in
            await self?.updateAreaName(for: coordinate)
        }
    }
    
    private func updateAreaNameDebounced(for coordinate: CLLocationCoordinate2D) {
        areaNameUpdateTask?.cancel()
        
        areaNameUpdateTask = Task.detached(priority: .utility) { @MainActor [weak self] in
            guard let self = self else { return }
            
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            
            if !self.shouldPerformGeocoding(for: coordinate) {
                debugLog(" Skipping geocoding - too recent or too close")
                return
            }
            
            await self.updateAreaName(for: coordinate)
        }
    }

    private func shouldPerformGeocoding(for coordinate: CLLocationCoordinate2D) -> Bool {
        let now = Date()
        
        // Check time-based throttling
        if now.timeIntervalSince(lastGeocodingTime) < minimumGeocodingInterval {
            return false
        }
        
        // Check distance-based throttling
        if let lastCoordinate = lastGeocodedCoordinate {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = lastLocation.distance(from: currentLocation)
            
            if distance < minimumDistanceThreshold {
                return false
            }
        }
        
        return true
    }

    private func updateAreaName(for coordinate: CLLocationCoordinate2D) async {
        await MainActor.run {
            self.lastGeocodingTime = Date()
            self.lastGeocodedCoordinate = coordinate
        }
        
        do {
            geocoder.cancelGeocode()
            
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            if let placemark = placemarks.first {
                let components = [
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.country
                ].compactMap { $0 }
                
                let areaName = components.joined(separator: ", ")
                
                await MainActor.run {
                    if !areaName.isEmpty {
                        self.currentAreaName = areaName
                        debugLog(" Updated area name: \(areaName)")
                    }
                }
            }
        } catch {
            debugLog(" Failed to get area name: \(error)")
        }
    }

    private func handleSearchResult(_ result: SearchResult) {
        switch result {
        case .noQuery:
            break
            
        case .noResults(let query):
            searchErrorMessage = "No restaurants found for '\(query)'."
            showSearchError = true
            
        case .singleResult(let restaurant):
            if isRestaurantWithinRadius(restaurant) {
                filteredRestaurants = [restaurant]
                showSearchResults = true
                Task { @MainActor [weak self] in
                    self?.zoomToShowResults([restaurant])
                }
            } else {
                searchErrorMessage = "Restaurant found but outside search radius."
                showSearchError = true
            }
            
        case .chainResult(let restaurant, _):
            if isRestaurantWithinRadius(restaurant) {
                filteredRestaurants = [restaurant]
                showSearchResults = true
                Task { @MainActor [weak self] in
                    self?.zoomToShowResults([restaurant])
                }
            } else {
                searchErrorMessage = "Restaurant found but outside search radius."
                showSearchError = true
            }
            
        case .cuisineResults(let restaurants, _):
            let radiusFilteredResults = restaurants.filter { isRestaurantWithinRadius($0) }
            
            if !radiusFilteredResults.isEmpty {
                filteredRestaurants = radiusFilteredResults
                showSearchResults = true
                Task { @MainActor [weak self] in
                    self?.zoomToShowResults(radiusFilteredResults)
                }
            } else {
                searchErrorMessage = "Restaurants found but outside search radius."
                showSearchError = true
            }
            
        case .partialNameResult(let restaurant, _):
            if isRestaurantWithinRadius(restaurant) {
                filteredRestaurants = [restaurant]
                showSearchResults = true
                Task { @MainActor [weak self] in
                    self?.zoomToShowResults([restaurant])
                }
            } else {
                searchErrorMessage = "Restaurant found but outside search radius."
                showSearchError = true
            }
        }
    }

    private func isRestaurantWithinRadius(_ restaurant: Restaurant) -> Bool {
        guard let userLocation = locationManager.lastLocation else { return true }
        
        let userLocationCL = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let restaurantLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
        let distance = userLocationCL.distance(from: restaurantLocation)
        let radiusInMeters = searchRadius * 1609.344
        
        return distance <= radiusInMeters
    }

    private func zoomToShowResults(_ restaurants: [Restaurant]) {
        guard !restaurants.isEmpty,
              let userLocation = locationManager.lastLocation else { return }
        
        if restaurants.count == 1 {
            let restaurant = restaurants[0]
            let restaurantCoord = CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
            
            let centerLat = (userLocation.coordinate.latitude + restaurantCoord.latitude) / 2
            let centerLon = (userLocation.coordinate.longitude + restaurantCoord.longitude) / 2
            
            let latDiff = abs(userLocation.coordinate.latitude - restaurantCoord.latitude)
            let lonDiff = abs(userLocation.coordinate.longitude - restaurantCoord.longitude)
            
            withAnimation(.easeInOut(duration: 1.0)) {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MKCoordinateSpan(
                        latitudeDelta: max(latDiff * 2.5, 0.01),
                        longitudeDelta: max(lonDiff * 2.5, 0.01)
                    )
                )
            }
        } else {
            let allCoords = restaurants.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } + [userLocation.coordinate]
            
            let latitudes = allCoords.map { $0.latitude }
            let longitudes = allCoords.map { $0.longitude }
            
            let minLat = latitudes.min()!
            let maxLat = latitudes.max()!
            let minLon = longitudes.min()!
            let maxLon = longitudes.max()!
            
            withAnimation(.easeInOut(duration: 1.0)) {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: (minLat + maxLat) / 2,
                        longitude: (minLon + maxLon) / 2
                    ),
                    span: MKCoordinateSpan(
                        latitudeDelta: max((maxLat - minLat) * 1.5, 0.02),
                        longitudeDelta: max((maxLon - minLon) * 1.5, 0.02)
                    )
                )
            }
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
}

// MARK: - Utility Extensions
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

private func filterRestaurantsByRadius(_ restaurants: [Restaurant], coordinate: CLLocationCoordinate2D, radius: Double) async -> [Restaurant] {
    return await Task.detached(priority: .utility) {
        let radiusInMeters = radius * 1609.34
        let userLocationCL = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return restaurants.filter { restaurant in
            let restaurantLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
            let distance = userLocationCL.distance(from: restaurantLocation)
            return distance <= radiusInMeters
        }.sorted { restaurant1, restaurant2 in
            let distance1 = userLocationCL.distance(from: CLLocation(latitude: restaurant1.latitude, longitude: restaurant1.longitude))
            let distance2 = userLocationCL.distance(from: CLLocation(latitude: restaurant2.latitude, longitude: restaurant2.longitude))
            return distance1 < distance2
        }
    }.value
}
