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

    // MARK: - Private Properties
    private let overpassService = OverpassAPIService()
    private let locationManager = LocationManager.shared
    private let searchManager = SearchManager()

    private var userLocation: CLLocationCoordinate2D?
    private var hasLoadedInitialData = false
    private var geocodeTask: Task<Void, Never>?
    private var dataFetchTask: Task<Void, Never>?
    
    private var currentLoadingTask: Task<Void, Never>?
    
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

    var allAvailableRestaurants: [Restaurant] {
        return restaurants
    }

    var restaurantsWithinSearchRadius: [Restaurant] {
        guard let userLocation = userLocation,
              hasActiveRadiusFilter || showSearchResults else {
            return restaurants
        }

        let userLocationCL = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let radiusInMeters = searchRadius * 1609.344

        return restaurants.filter { restaurant in
            let restaurantLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
            return userLocationCL.distance(from: restaurantLocation) <= radiusInMeters
        }
    }

    // MARK: - Initialization
    init() {
        setupLocationObserver()
    }

    // MARK: - Public Methods
    // FIX: Simplified region updates without publishing changes during view updates
    func updateRegion(_ newRegion: MKCoordinateRegion) {
        // Cancel previous update task
        regionUpdateTask?.cancel()
        
        regionUpdateTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Debounce region updates
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms debounce
            
            guard !Task.isCancelled else { return }
            
            // Only update if there's a meaningful change
            let latDiff = abs(self.region.center.latitude - newRegion.center.latitude)
            let lonDiff = abs(self.region.center.longitude - newRegion.center.longitude)
            let spanDiff = abs(self.region.span.latitudeDelta - newRegion.span.latitudeDelta)
            
            if latDiff > 0.0001 || lonDiff > 0.0001 || spanDiff > 0.001 {
                self.region = newRegion
                
                // Only update area name if we've moved significantly (debounced separately)
                if latDiff > 0.01 || lonDiff > 0.01 {
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
            
            // Debounce area name updates - longer delay since they're less critical
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            
            guard !Task.isCancelled else { return }
            
            await self.updateAreaName(for: coordinate)
        }
    }

    func refreshData(for coordinate: CLLocationCoordinate2D) {
        guard !hasLoadedInitialData else { return }
        
        userLocation = coordinate
        
        currentLoadingTask?.cancel()
        currentLoadingTask = Task.detached { [weak self] in
            await self?.loadRestaurants(coordinate)
        }
    }
    
    func refreshDataWithRadius(for coordinate: CLLocationCoordinate2D, radius: Double) async {
        if hasLoadedInitialData && !restaurants.isEmpty {
            return
        }
        
        userLocation = coordinate
        
        currentLoadingTask?.cancel()
        currentLoadingTask = Task.detached { [weak self] in
            await self?.loadOptimizedRestaurants(coordinate, radius: radius)
        }
        
        // Wait for completion
        await currentLoadingTask?.value
    }
    
    private func loadRestaurants(_ coordinate: CLLocationCoordinate2D) async {
        await MainActor.run {
            isLoadingRestaurants = true
            loadingProgress = 0.0
        }
        
        do {
            await MainActor.run { loadingProgress = 0.3 }
            
            let fetchedRestaurants = try await overpassService.fetchFastFoodRestaurants(near: coordinate)
            
            await MainActor.run { loadingProgress = 0.8 }
            
            await MainActor.run {
                restaurants = fetchedRestaurants
                hasLoadedInitialData = true
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    loadingProgress = 1.0
                    isLoadingRestaurants = false
                }
                
                print("✅ Loaded \(fetchedRestaurants.count) restaurants")
            }
            
        } catch {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoadingRestaurants = false
                    loadingProgress = 1.0
                }
                print("❌ Error loading restaurants: \(error)")
            }
        }
    }

    private func loadOptimizedRestaurants(_ coordinate: CLLocationCoordinate2D, radius: Double) async {
        await MainActor.run {
            isLoadingRestaurants = true
            loadingProgress = 0.0
        }
        
        do {
            // STEP 1: Single API call with optimized radius
            await MainActor.run { loadingProgress = 0.3 }
            
            let fetchedRestaurants = try await overpassService.fetchFastFoodRestaurants(near: coordinate, radius: radius)
            
            await MainActor.run {
                loadingProgress = 0.8
                print("✅ Loaded \(fetchedRestaurants.count) restaurants within \(radius) miles")
            }
            
            await MainActor.run {
                restaurants = fetchedRestaurants
                hasLoadedInitialData = true
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    loadingProgress = 1.0
                    isLoadingRestaurants = false
                }
            }
            
        } catch {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoadingRestaurants = false
                    loadingProgress = 1.0
                }
                print("❌ Error loading restaurants: \(error)")
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

    func selectRestaurant(_ restaurant: Restaurant) {
        Task { @MainActor in
            self.selectedRestaurant = restaurant
            self.zoomToRestaurant(restaurant)
            
            Task.detached { [weak self] in
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                await MainActor.run {
                    self?.showingRestaurantDetail = true
                }
            }
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

    // PERFORMANCE: Optimized area name updates
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
                Task.detached { [weak self] in
                    await MainActor.run {
                        self?.zoomToShowResults([restaurant])
                    }
                }
            } else {
                searchErrorMessage = "Restaurant found but outside search radius."
                showSearchError = true
            }
            
        case .chainResult(let restaurant, _):
            if isRestaurantWithinRadius(restaurant) {
                filteredRestaurants = [restaurant]
                showSearchResults = true
                Task.detached { [weak self] in
                    await MainActor.run {
                        self?.zoomToShowResults([restaurant])
                    }
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
                Task.detached { [weak self] in
                    await MainActor.run {
                        self?.zoomToShowResults(radiusFilteredResults)
                    }
                }
            } else {
                searchErrorMessage = "Restaurants found but outside search radius."
                showSearchError = true
            }
            
        case .partialNameResult(let restaurant, _):
            if isRestaurantWithinRadius(restaurant) {
                filteredRestaurants = [restaurant]
                showSearchResults = true
                Task.detached { [weak self] in
                    await MainActor.run {
                        self?.zoomToShowResults([restaurant])
                    }
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
            // FIX: Use userLocation.coordinate instead of userLocation directly
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

private struct CachedRestaurantData {
    let restaurants: [Restaurant]
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 600
    }
}

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
