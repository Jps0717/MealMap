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
    @Published var hasActiveRadiusFilter = false

    // MARK: - Loading Progress
    @Published var loadingProgress: Double = 1.0

    // MARK: - Private Properties
    private let overpassService = OverpassAPIService()
    private let locationManager = LocationManager.shared
    private let searchManager = SearchManager()

    // PERFORMANCE: Simplified state tracking
    private var userLocation: CLLocationCoordinate2D?
    private var hasLoadedInitialData = false
    private var geocodeTask: Task<Void, Never>?
    private var dataFetchTask: Task<Void, Never>?

    // MARK: - Computed Properties
    var hasValidLocation: Bool {
        locationManager.lastLocation != nil &&
        (locationManager.authorizationStatus == .authorizedWhenInUse ||
         locationManager.authorizationStatus == .authorizedAlways)
    }

    var shouldShowClusters: Bool {
        region.span.latitudeDelta > 0.02 && !showSearchResults
    }

    // PERFORMANCE: Direct access to restaurants
    var allAvailableRestaurants: [Restaurant] {
        return restaurants
    }

    // PERFORMANCE: Optimized radius filtering
    var restaurantsWithinSearchRadius: [Restaurant] {
        guard let userLocation = locationManager.lastLocation,
              hasActiveRadiusFilter || showSearchResults else {
            return restaurants
        }

        let userLocationCL = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
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
    func updateRegion(_ newRegion: MKCoordinateRegion) {
        region = newRegion
        
        // PERFORMANCE: Only update area name for significant moves
        Task { @MainActor in
            await updateAreaNameIfNeeded(for: newRegion.center)
        }
    }

    // PERFORMANCE: Load data only once on app start
    func refreshData(for coordinate: CLLocationCoordinate2D) {
        guard !hasLoadedInitialData else { return }
        
        userLocation = coordinate
        loadRestaurantsAroundUser(coordinate)
    }

    func performSearch(query: String, maxDistance: Double?) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        guard let userLocation = locationManager.lastLocation else {
            searchErrorMessage = "Location access required for search. Please enable location services."
            showSearchError = true
            return
        }
        
        if let distance = maxDistance {
            searchRadius = distance
        }
        
        hasActiveRadiusFilter = true
        
        let result = searchManager.search(
            query: query,
            in: restaurants,
            userLocation: locationManager.lastLocation,
            maxDistance: nil
        )
        
        handleSearchResult(result)
    }

    func clearSearch() {
        filteredRestaurants = []
        showSearchResults = false
        hasActiveRadiusFilter = false
        searchManager.hasActiveSearch = false
    }

    func selectRestaurant(_ restaurant: Restaurant) {
        selectedRestaurant = restaurant
        zoomToRestaurant(restaurant)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showingRestaurantDetail = true
        }
    }

    func cleanup() {
        dataFetchTask?.cancel()
        geocodeTask?.cancel()
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
        refreshData(for: coordinate)
    }

    // PERFORMANCE: Simplified data loading
    private func loadRestaurantsAroundUser(_ coordinate: CLLocationCoordinate2D) {
        dataFetchTask?.cancel()
        
        isLoadingRestaurants = true
        loadingProgress = 0.0
        
        dataFetchTask = Task { @MainActor in
            do {
                loadingProgress = 0.3
                
                let fetchedRestaurants = try await overpassService.fetchFastFoodRestaurants(near: coordinate)
                
                loadingProgress = 0.8
                
                restaurants = fetchedRestaurants
                hasLoadedInitialData = true
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    loadingProgress = 1.0
                    isLoadingRestaurants = false
                }
                
                print("✅ Loaded \(fetchedRestaurants.count) restaurants")
                
            } catch {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoadingRestaurants = false
                    loadingProgress = 1.0
                }
                print("❌ Error loading restaurants: \(error)")
            }
        }
    }

    // PERFORMANCE: Debounced area name updates
    private func updateAreaNameIfNeeded(for coordinate: CLLocationCoordinate2D) async {
        guard let userLoc = userLocation else { return }
        let distance = userLoc.distance(to: coordinate)
        guard distance > 2000 else { return } // Only update if moved more than 2km
        
        await updateAreaNameDebounced(for: coordinate)
    }

    private func updateAreaNameDebounced(for coordinate: CLLocationCoordinate2D) async {
        geocodeTask?.cancel()
        geocodeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
            guard !Task.isCancelled else { return }
            await updateAreaName(for: coordinate)
        }
    }

    private func updateAreaName(for coordinate: CLLocationCoordinate2D) async {
        let result = await Task.detached {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                guard let placemark = placemarks.first else { return nil as String? }
                
                return placemark.locality ?? placemark.subLocality ?? placemark.administrativeArea ?? "Unknown Area"
            } catch {
                return nil as String?
            }
        }.value
        
        if let areaName = result {
            currentAreaName = areaName
        }
    }

    // PERFORMANCE: Simplified search result handling
    private func handleSearchResult(_ result: SearchResult) {
        switch result {
        case .noQuery:
            break
            
        case .noResults(let query):
            searchErrorMessage = "No restaurants found for '\(query)'."
            showSearchError = true
            
        case .singleResult(let restaurant):
            if isRestaurantWithinRadius(restaurant) {
                showSearchResults = true
                zoomToShowResults([restaurant])
            } else {
                searchErrorMessage = "Restaurant found but outside search radius."
                showSearchError = true
            }
            
        case .chainResult(let restaurant, _):
            if isRestaurantWithinRadius(restaurant) {
                showSearchResults = true
                zoomToShowResults([restaurant])
            } else {
                searchErrorMessage = "Restaurant found but outside search radius."
                showSearchError = true
            }
            
        case .cuisineResults(let restaurants, _):
            let radiusFilteredResults = restaurants.filter { isRestaurantWithinRadius($0) }
            
            if !radiusFilteredResults.isEmpty {
                showSearchResults = true
                zoomToShowResults(radiusFilteredResults)
            } else {
                searchErrorMessage = "Restaurants found but outside search radius."
                showSearchError = true
            }
            
        case .partialNameResult(let restaurant, _):
            if isRestaurantWithinRadius(restaurant) {
                showSearchResults = true
                zoomToShowResults([restaurant])
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

    private func formatRadius(_ radius: Double) -> String {
        if radius == floor(radius) {
            return "\(Int(radius)) mile\(radius == 1 ? "" : "s")"
        } else {
            return String(format: "%.1f miles", radius)
        }
    }

    // PERFORMANCE: Simplified zoom functions
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

private struct CachedRestaurantData {
    let restaurants: [Restaurant]
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 600
    }
}
