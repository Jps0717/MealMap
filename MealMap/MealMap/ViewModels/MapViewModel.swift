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
    
    @Published var currentFilter = RestaurantFilter()

    // MARK: - Private Properties
    private let overpassService = OverpassAPIService()
    private let locationManager = LocationManager.shared
    private let searchManager = SearchManager()
    private let nutritionManager = NutritionDataManager.shared
    private let boundingBoxCache = BoundingBoxCacheService.shared
    
    var userLocation: CLLocationCoordinate2D? {
        locationManager.lastLocation?.coordinate
    }
    private var hasLoadedInitialData = false
    private var geocodeTask: Task<Void, Never>?
    private var dataFetchTask: Task<Void, Never>?
    private var currentLoadingTask: Task<Void, Never>?
    
    // PERFORMANCE: Simple initialization tracking
    private var hasInitialized = false
    
    // PERFORMANCE: Add debouncing for region updates
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

    // SIMPLIFIED: Direct restaurant access without complex caching
    var allAvailableRestaurants: [Restaurant] {
        print("🔍 MapViewModel - allAvailableRestaurants called")
        print("🔍 MapViewModel - Raw restaurants count: \(restaurants.count)")
        
        if !currentFilter.isEmpty {
            let filtered = restaurants.filter { restaurant in
                currentFilter.matchesRestaurant(restaurant, userLocation: userLocation)
            }
            print("🔍 MapViewModel - Filtered to \(filtered.count) restaurants")
            return filtered
        }
        
        // Return ALL restaurants without any filtering
        print("🔍 MapViewModel - Returning ALL \(restaurants.count) restaurants")
        return restaurants
    }

    var restaurantsWithinSearchRadius: [Restaurant] {
        print("🔍 MapViewModel - restaurantsWithinSearchRadius called")
        print("🔍 MapViewModel - hasActiveRadiusFilter: \(hasActiveRadiusFilter)")
        print("🔍 MapViewModel - showSearchResults: \(showSearchResults)")
        
        // SIMPLIFIED: Always return all restaurants for now
        print("🔍 MapViewModel - Returning ALL restaurants (no radius filtering)")
        return allAvailableRestaurants
    }

    // MARK: - Initialization
    init() {
        setupLocationObserver()
    }

    // MARK: - Enhanced Map Methods
    func updateMapRegion(_ newRegion: MKCoordinateRegion) {
        region = newRegion
        updateAreaNameDebounced(for: newRegion.center)
    }
    
    func fetchRestaurantsForRegion(_ mapRegion: MKCoordinateRegion) async {
        // Check cache first
        if let cachedRestaurants = boundingBoxCache.getCachedRestaurants(for: mapRegion) {
            print("⚡ Using cached restaurants for region")
            await MainActor.run {
                self.restaurants = cachedRestaurants
            }
            return
        }
        
        // Fetch new data
        await MainActor.run {
            self.isLoadingRestaurants = true
        }
        
        do {
            let bbox = mapRegion.boundingBox
            let newRestaurants = try await fetchRestaurantsForBoundingBox(
                minLat: bbox.minLat,
                minLon: bbox.minLon,
                maxLat: bbox.maxLat,
                maxLon: bbox.maxLon
            )
            
            // Cache the results
            boundingBoxCache.cacheRestaurants(newRestaurants, for: mapRegion)
            
            await MainActor.run {
                self.restaurants = newRestaurants
                self.isLoadingRestaurants = false
                print("✅ Loaded \(newRestaurants.count) restaurants for region")
            }
            
        } catch {
            print("❌ Error fetching restaurants for region: \(error)")
            await MainActor.run {
                self.isLoadingRestaurants = false
            }
        }
    }
    
    private func fetchRestaurantsForBoundingBox(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [Restaurant] {
        // Issue two separate queries as specified
        async let fastFoodQuery = overpassService.fetchRestaurants(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        // For now, we'll use the existing method that handles both types
        // In the future, you could split this into two separate Overpass queries
        let allRestaurants = try await fastFoodQuery
        
        // Separate fast food and restaurants, prioritize nutrition data
        let sortedRestaurants = allRestaurants.sorted { r1, r2 in
            if r1.hasNutritionData != r2.hasNutritionData {
                return r1.hasNutritionData
            }
            return r1.displayPriority > r2.displayPriority
        }
        
        return Array(sortedRestaurants.prefix(100)) // Limit for performance
    }

    // MARK: - Public Methods
    // SIMPLIFIED: Direct region updates
    func updateRegion(_ newRegion: MKCoordinateRegion) {
        // Cancel previous update task
        regionUpdateTask?.cancel()
        
        regionUpdateTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Debounce region updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms debounce
            
            guard !Task.isCancelled else { return }
            
            // Only update if there's a meaningful change
            let latDiff = abs(self.region.center.latitude - newRegion.center.latitude)
            let lonDiff = abs(self.region.center.longitude - newRegion.center.longitude)
            let spanDiff = abs(self.region.span.latitudeDelta - newRegion.span.latitudeDelta)
            
            if latDiff > 0.0005 || lonDiff > 0.0005 || spanDiff > 0.002 {
                self.region = newRegion
                
                // Only update area name if we've moved significantly
                if latDiff > 0.02 || lonDiff > 0.02 {
                    self.updateAreaNameDebounced(for: newRegion.center)
                }
            }
        }
    }
    
    // PERFORMANCE: Debounced area name updates
    private func updateAreaNameDebounced(for coordinate: CLLocationCoordinate2D) {
        // Cancel previous area name update task
        areaNameUpdateTask?.cancel()
        
        areaNameUpdateTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Debounce area name updates
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
            
            guard !Task.isCancelled else { return }
            
            await self.updateAreaName(for: coordinate)
        }
    }

    func refreshData(for coordinate: CLLocationCoordinate2D) {
        guard !isLoadingRestaurants else { return }
        
        // Set user location immediately - CHANGE: Make userLocation publicly accessible
        // userLocation = coordinate
        print("🔍 MapViewModel - Setting user location: \(coordinate)")
        
        isLoadingRestaurants = true
        loadingProgress = 0.0
        
        // Cancel any existing task
        dataFetchTask?.cancel()
        
        dataFetchTask = Task { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run {
                self.loadingProgress = 0.2
            }
            
            do {
                print("🔍 MapViewModel - Starting API fetch for coordinate: \(coordinate)")
                
                // Fetch restaurants with reasonable radius
                let fetchedRestaurants = try await self.overpassService.fetchAllNearbyRestaurants(
                    near: coordinate,
                    radius: 10.0 // 10 miles for good coverage
                )
                
                print("🔍 MapViewModel - API returned \(fetchedRestaurants.count) restaurants")
                
                await MainActor.run {
                    self.loadingProgress = 0.8
                }
                
                // Limit restaurants for performance
                let limitedRestaurants = Array(fetchedRestaurants.prefix(100))
                
                // Background: Preload nutrition data for top nutrition restaurants only
                let nutritionRestaurants = limitedRestaurants.filter { $0.hasNutritionData }
                let topNutritionRestaurants = Array(nutritionRestaurants.prefix(5))
                if !topNutritionRestaurants.isEmpty {
                    Task.detached { [weak self] in
                        await self?.nutritionManager.batchLoadNutritionData(for: topNutritionRestaurants.map(\.name))
                    }
                }
                
                await MainActor.run {
                    self.restaurants = limitedRestaurants
                    self.loadingProgress = 1.0
                    self.isLoadingRestaurants = false
                    self.hasInitialized = true
                    
                    print("🔍 MapViewModel - Set restaurants array to \(limitedRestaurants.count) items")
                    
                    // Print first few restaurants for debugging
                    for (index, restaurant) in limitedRestaurants.prefix(3).enumerated() {
                        print("🔍 MapViewModel - Restaurant \(index + 1): \(restaurant.name) at (\(restaurant.latitude), \(restaurant.longitude))")
                    }
                    
                    print("✅ Loaded \(limitedRestaurants.count) restaurants near user location")
                    print("📊 \(nutritionRestaurants.count) have nutrition data")
                }
                
            } catch {
                await MainActor.run {
                    print("❌ Error fetching restaurants: \(error)")
                    
                    // Fallback test restaurants for debugging
                    let testRestaurants = [
                        Restaurant(
                            id: 999991,
                            name: "Test McDonald's",
                            latitude: coordinate.latitude + 0.001,
                            longitude: coordinate.longitude + 0.001,
                            address: "Test Address 1",
                            cuisine: "Fast Food",
                            openingHours: nil,
                            phone: nil,
                            website: nil,
                            type: "node"
                        ),
                        Restaurant(
                            id: 999992,
                            name: "Test Subway",
                            latitude: coordinate.latitude - 0.001,
                            longitude: coordinate.longitude + 0.001,
                            address: "Test Address 2",
                            cuisine: "Fast Food",
                            openingHours: nil,
                            phone: nil,
                            website: nil,
                            type: "node"
                        )
                    ]
                    
                    self.restaurants = testRestaurants
                    print("🔍 MapViewModel - Using fallback test restaurants: \(testRestaurants.count)")
                    
                    self.searchErrorMessage = "Unable to load restaurants right now. Showing test data."
                    self.showSearchError = true
                    self.isLoadingRestaurants = false
                    self.loadingProgress = 1.0
                }
            }
        }
    }

    func performSearch(query: String, maxDistance: Double?) {
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
            maxDistance: nil
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
        currentFilter = filter
    }
    
    func clearFilters() {
        currentFilter = RestaurantFilter()
    }

    func selectRestaurant(_ restaurant: Restaurant) {
        selectedRestaurant = restaurant
        zoomToRestaurant(restaurant)
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            self?.showingRestaurantDetail = true
        }
    }

    func cleanup() {
        dataFetchTask?.cancel()
        geocodeTask?.cancel()
        regionUpdateTask?.cancel()
        areaNameUpdateTask?.cancel()
        currentLoadingTask?.cancel()
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
        
        Task { [weak self] in
            await self?.updateAreaName(for: coordinate)
        }
    }

    private func updateAreaName(for coordinate: CLLocationCoordinate2D) async {
        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            
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
                    }
                }
            }
        } catch {
            print("Failed to get area name: \(error)")
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
    return await Task.detached {
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
