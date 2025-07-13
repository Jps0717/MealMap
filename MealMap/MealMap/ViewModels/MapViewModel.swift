import SwiftUI
import MapKit
import Combine
import CoreLocation

/// ULTRA-FAST MapViewModel - Viewport-only, No Caching, Minimal Pins
final class MapViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var restaurants: [Restaurant] = []
    @Published var isLoadingRestaurants = false
    @Published var showSearchResults = false
    @Published var filteredRestaurants: [Restaurant] = []
    @Published var searchRadius: Double = 5.0
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published var currentAreaName: String = "Loading location..."
    @Published var loadingProgress: Double = 0.0
    
    // MARK: - REMOVED: All caching services and complex dependencies
    
    // MARK: - Private Properties
    private let overpassService = OverpassAPIService()
    private let locationManager = LocationManager.shared
    private let nutritionManager = NutritionDataManager.shared
    
    // SIMPLIFIED: Basic debouncing only - no complex movement tracking
    private var lastUpdateTime: Date = Date.distantPast
    private let debounceInterval: TimeInterval = 2.0  // 2 second debounce
    private let maxPinsInViewport = 50  // HARD LIMIT: Maximum pins to show
    
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

    // SIMPLIFIED: Basic sorting without complex scoring
    var restaurantsSortedByScore: [Restaurant] {
        return allAvailableRestaurants.sorted { restaurant1, restaurant2 in
            // Primary sort by nutrition data availability
            if restaurant1.hasNutritionData != restaurant2.hasNutritionData {
                return restaurant1.hasNutritionData
            }
            
            // Secondary sort by distance
            if let userLocation = userLocation {
                let distance1 = restaurant1.distanceFrom(userLocation)
                let distance2 = restaurant2.distanceFrom(userLocation)
                return distance1 < distance2
            }
            
            return restaurant1.name < restaurant2.name
        }
    }
    
    // SIMPLIFIED: No complex scoring
    var topScoredRestaurants: [Restaurant] {
        return restaurantsSortedByScore
            .filter { $0.hasNutritionData }
            .prefix(10)
            .compactMap { $0 }
    }
    
    init() {
        setupLocationObserver()
        debugLog("🗺️ MapViewModel initialized - VIEWPORT-ONLY VERSION")
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

    // MARK: - NEW: Viewport-Based Restaurant Fetching
    
    func fetchRestaurantsForViewport(_ mapRegion: MKCoordinateRegion) async {
        // ENHANCED: Strict debouncing to prevent API spam
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= debounceInterval else {
            debugLog("🗺️ DEBOUNCED: Skipping fetch (too soon)")
            return
        }
        lastUpdateTime = now
        
        // Calculate viewport bounds
        let center = mapRegion.center
        let span = mapRegion.span
        
        let minLat = center.latitude - (span.latitudeDelta / 2)
        let maxLat = center.latitude + (span.latitudeDelta / 2)
        let minLon = center.longitude - (span.longitudeDelta / 2)
        let maxLon = center.longitude + (span.longitudeDelta / 2)
        
        await MainActor.run {
            isLoadingRestaurants = true
        }
        
        debugLog("🗺️ VIEWPORT FETCH: (\(minLat), \(minLon)) to (\(maxLat), \(maxLon))")
        
        do {
            // DIRECT API call using viewport bounds - NO CACHING
            let allRestaurants = try await overpassService.fetchRestaurants(
                minLat: minLat,
                minLon: minLon, 
                maxLat: maxLat,
                maxLon: maxLon
            )
            
            // HARD LIMIT: Only show top 50 restaurants in viewport
            let sortedRestaurants = sortRestaurantsByPriority(allRestaurants)
            let limitedRestaurants = Array(sortedRestaurants.prefix(maxPinsInViewport))
            
            await MainActor.run {
                self.restaurants = limitedRestaurants
                self.isLoadingRestaurants = false
                
                let nutritionCount = limitedRestaurants.filter { $0.hasNutritionData }.count
                debugLog("🗺️ VIEWPORT: Loaded \(limitedRestaurants.count)/\(allRestaurants.count) restaurants (\(nutritionCount) with nutrition)")
            }
        } catch {
            await MainActor.run {
                self.isLoadingRestaurants = false
                debugLog("🗺️ Error fetching restaurants: \(error)")
            }
        }
    }
    
    // MARK: - Map Region Updates
    func updateMapRegion(_ newRegion: MKCoordinateRegion) {
        region = newRegion
        updateAreaNameDebounced(for: newRegion.center)
        
        // IMMEDIATE: Fetch restaurants for new viewport
        Task {
            await fetchRestaurantsForViewport(newRegion)
        }
    }
    
    func fetchRestaurantsForMapRegion(_ mapRegion: MKCoordinateRegion) async {
        await fetchRestaurantsForViewport(mapRegion)
    }

    func fetchRestaurantsForZoomLevel(_ center: CLLocationCoordinate2D, zoomLevel: ZoomLevel) async {
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        await fetchRestaurantsForViewport(region)
    }

    func updateZoomLevel(for region: MKCoordinateRegion) {
        // No-op - viewport fetching handles this automatically
    }

    // MARK: - DEPRECATED: Legacy methods for backward compatibility
    func fetchRestaurantsSimple(for coordinate: CLLocationCoordinate2D) async {
        // Convert to region and use viewport method
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        await fetchRestaurantsForViewport(region)
    }

    func refreshData(for coordinate: CLLocationCoordinate2D) {
        guard !isLoadingRestaurants else { return }
        
        debugLog("🗺️ MANUAL REFRESH")
        
        restaurants.removeAll()
        lastUpdateTime = Date.distantPast  // Force refresh
        
        locationManager.refreshCurrentLocation()
        
        isLoadingRestaurants = true
        loadingProgress = 0.0
        
        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        Task {
            await self.fetchRestaurantsForViewport(self.region)
            
            await MainActor.run {
                self.loadingProgress = 1.0
                self.hasInitialized = true
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
        await fetchRestaurantsSimple(for: center)
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
            self.filteredRestaurants = Array(sortedResults.prefix(25))  // Limit search results too
            self.showSearchResults = true
            self.isLoadingRestaurants = false
        }
    }
    
    func clearSearch() {
        showSearchResults = false
        filteredRestaurants = []
    }

    // MARK: - Location management
    func setInitialLocation(_ coordinate: CLLocationCoordinate2D) {
        debugLog("🗺️ Setting initial location: \(coordinate)")
        
        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        Task {
            await updateAreaName(for: coordinate)
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
        
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await updateAreaName(for: coordinate)
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
                }
            }
        } catch {
            await MainActor.run {
                self.currentAreaName = "Unknown Location"
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
    
    // MARK: - REMOVED: All complex scoring and caching methods
    
    func recalculateScores() {
        // No-op: Scores calculated on-demand in RestaurantDetailView
    }

    func clearFiltersOnHomeScreen() {
        // No-op: No filters to clear in simplified version
    }
    
    func createCleanMapViewModel() -> MapViewModel {
        let cleanViewModel = MapViewModel()
        cleanViewModel.region = self.region
        cleanViewModel.currentAreaName = self.currentAreaName
        cleanViewModel.hasInitialized = self.hasInitialized
        return cleanViewModel
    }
}