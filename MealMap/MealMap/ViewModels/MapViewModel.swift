import SwiftUI
import MapKit
import Combine
import CoreLocation

// MARK: - Helper Structures
struct ViewportBounds {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
}

/// OPTIMIZED MapViewModel - Max 50 pins with smart loading as you pan
@MainActor
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
    
    // MARK: - Private Properties
    private let overpassService = OverpassAPIService()
    private let locationManager = LocationManager.shared
    private let nutritionManager = NutritionDataManager.shared
    
    // PERFORMANCE: Fast debouncing with smart loading as you pan
    private var lastUpdateTime: Date = Date.distantPast
    private let debounceInterval: TimeInterval = 0.2  // Ultra-fast for smooth panning
    private let maxPinsInViewport = 50  // FIXED: Max 50 pins for optimal balance
    
    // SMART LOADING: Multi-layer caching system
    private var allCachedRestaurants: [Restaurant] = []
    private var lastFetchedBounds: MKCoordinateRegion?
    private let cacheValidityRadius: Double = 2000 // 2km cache radius
    
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
        return getOptimal50RestaurantsForViewport()
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

    // SMART: Best 50 restaurants prioritized by nutrition + proximity
    var restaurantsSortedByScore: [Restaurant] {
        return getOptimal50RestaurantsForViewport().sorted { restaurant1, restaurant2 in
            // Primary sort by nutrition data availability
            if restaurant1.hasNutritionData != restaurant2.hasNutritionData {
                return restaurant1.hasNutritionData
            }
            
            // Secondary sort by distance from map center
            let mapCenter = region.center
            let distance1 = restaurant1.distanceFrom(mapCenter)
            let distance2 = restaurant2.distanceFrom(mapCenter)
            return distance1 < distance2
        }
    }
    
    var topScoredRestaurants: [Restaurant] {
        return restaurantsSortedByScore
            .filter { $0.hasNutritionData }
            .prefix(10)
            .compactMap { $0 }
    }
    
    init() {
        setupLocationObserver()
        debugLog(" MapViewModel initialized - SMART 50-PIN LOADING SYSTEM")
    }

    // MARK: - SMART: Best 50 Restaurants with Intelligent Prioritization
    
    /// Get the best 50 restaurants for current viewport with smart prioritization
    private func getOptimal50RestaurantsForViewport() -> [Restaurant] {
        let viewportBounds = calculateViewportBounds(region)
        
        // Filter restaurants within viewport
        let viewportRestaurants = allCachedRestaurants.filter { restaurant in
            isRestaurantInViewport(restaurant, bounds: viewportBounds)
        }
        
        // SMART PRIORITIZATION: Get the best 50 restaurants
        let prioritizedRestaurants = intelligentlySelect50Restaurants(from: viewportRestaurants)
        
        debugLog(" SMART 50: Selected \(prioritizedRestaurants.count) best restaurants from \(viewportRestaurants.count) in viewport")
        return prioritizedRestaurants
    }
    
    /// Intelligently select the best 50 restaurants based on nutrition data and proximity
    private func intelligentlySelect50Restaurants(from restaurants: [Restaurant]) -> [Restaurant] {
        let mapCenter = region.center
        
        // Separate by nutrition data availability
        let nutritionRestaurants = restaurants.filter { $0.hasNutritionData }
        let regularRestaurants = restaurants.filter { !$0.hasNutritionData }
        
        // Sort each group by distance from map center
        let sortedNutrition = nutritionRestaurants.sorted { 
            $0.distanceFrom(mapCenter) < $1.distanceFrom(mapCenter) 
        }
        let sortedRegular = regularRestaurants.sorted { 
            $0.distanceFrom(mapCenter) < $1.distanceFrom(mapCenter) 
        }
        
        // SMART ALLOCATION: Prioritize nutrition restaurants but ensure diverse coverage
        var selectedRestaurants: [Restaurant] = []
        
        // Take up to 35 closest nutrition restaurants (70% of pins for high-value restaurants)
        let nutritionToTake = min(35, sortedNutrition.count)
        selectedRestaurants.append(contentsOf: Array(sortedNutrition.prefix(nutritionToTake)))
        
        // Fill remaining slots with closest regular restaurants
        let remainingSlots = maxPinsInViewport - selectedRestaurants.count
        let regularToTake = min(remainingSlots, sortedRegular.count)
        selectedRestaurants.append(contentsOf: Array(sortedRegular.prefix(regularToTake)))
        
        debugLog(" SMART SELECTION: \(nutritionToTake) nutrition + \(regularToTake) regular = \(selectedRestaurants.count) total")
        return selectedRestaurants
    }
    
    /// Calculate viewport bounds for filtering
    private func calculateViewportBounds(_ region: MKCoordinateRegion) -> ViewportBounds {
        let center = region.center
        let span = region.span
        
        // Small buffer for smooth panning transitions
        let buffer = 0.0002
        
        return ViewportBounds(
            minLat: center.latitude - (span.latitudeDelta / 2) - buffer,
            maxLat: center.latitude + (span.latitudeDelta / 2) + buffer,
            minLon: center.longitude - (span.longitudeDelta / 2) - buffer,
            maxLon: center.longitude + (span.longitudeDelta / 2) + buffer
        )
    }
    
    /// Check if restaurant is within viewport bounds
    private func isRestaurantInViewport(_ restaurant: Restaurant, bounds: ViewportBounds) -> Bool {
        let coord = restaurant.coordinate
        return coord.latitude >= bounds.minLat &&
               coord.latitude <= bounds.maxLat &&
               coord.longitude >= bounds.minLon &&
               coord.longitude <= bounds.maxLon
    }

    // MARK: - SMOOTH LOADING: Load as you pan with smart caching
    
    func fetchRestaurantsForViewport(_ mapRegion: MKCoordinateRegion) async {
        // ULTRA-FAST: Immediate response for smooth panning
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= debounceInterval else {
            return
        }
        lastUpdateTime = now
        
        // INSTANT: Update from cache first for immediate response
        if canUseCachedData(for: mapRegion) {
            await updateViewportRestaurantsInstant(mapRegion)
            return
        }
        
        // BACKGROUND: Fetch new data for expanded area
        await fetchExpandedAreaData(for: mapRegion)
    }
    
    /// Instantly update restaurants from cache as user pans
    private func updateViewportRestaurantsInstant(_ mapRegion: MKCoordinateRegion) async {
        await MainActor.run {
            updateViewportRestaurantsSync(mapRegion)
        }
    }
    
    /// Background fetch for expanded area when cache is insufficient
    private func fetchExpandedAreaData(for mapRegion: MKCoordinateRegion) async {
        let center = mapRegion.center
        let span = mapRegion.span
        
        // SMART EXPANSION: Fetch 3x viewport size for better cache coverage
        let expandedSpan = MKCoordinateSpan(
            latitudeDelta: span.latitudeDelta * 3.0,
            longitudeDelta: span.longitudeDelta * 3.0
        )
        
        let minLat = center.latitude - (expandedSpan.latitudeDelta / 2)
        let maxLat = center.latitude + (expandedSpan.latitudeDelta / 2)
        let minLon = center.longitude - (expandedSpan.longitudeDelta / 2)
        let maxLon = center.longitude + (expandedSpan.longitudeDelta / 2)
        
        await MainActor.run {
            isLoadingRestaurants = true
        }
        
        do {
            // Fetch restaurants in expanded area
            let fetchedRestaurants = try await overpassService.fetchRestaurants(
                minLat: minLat,
                minLon: minLon, 
                maxLat: maxLat,
                maxLon: maxLon
            )
            
            await MainActor.run {
                // Update cache with new data
                self.allCachedRestaurants = fetchedRestaurants
                self.lastFetchedBounds = MKCoordinateRegion(
                    center: center,
                    span: expandedSpan
                )
                
                // Update viewport with best 50 restaurants
                self.updateViewportRestaurantsSync(mapRegion)
                self.isLoadingRestaurants = false
                
                let nutritionCount = self.restaurants.filter { $0.hasNutritionData }.count
                debugLog(" LOADED: \(fetchedRestaurants.count) cached, showing best \(self.restaurants.count) (\(nutritionCount) nutrition)")
            }
        } catch {
            await MainActor.run {
                self.isLoadingRestaurants = false
                debugLog(" Error fetching restaurants: \(error)")
            }
        }
    }
    
    /// Update viewport restaurants synchronously with best 50 selection
    @MainActor
    private func updateViewportRestaurantsSync(_ mapRegion: MKCoordinateRegion) {
        let best50Restaurants = getOptimal50RestaurantsForViewport()
        self.restaurants = best50Restaurants
        
        let nutritionCount = best50Restaurants.filter { $0.hasNutritionData }.count
        debugLog(" VIEWPORT UPDATE: \(best50Restaurants.count) restaurants (\(nutritionCount) nutrition)")
    }
    
    /// Check if we can use cached data for instant updates
    private func canUseCachedData(for region: MKCoordinateRegion) -> Bool {
        guard let lastBounds = lastFetchedBounds else { return false }
        
        // Check if current viewport is within cached bounds
        let currentBounds = calculateViewportBounds(region)
        let cachedBounds = calculateViewportBounds(lastBounds)
        
        return currentBounds.minLat >= cachedBounds.minLat &&
               currentBounds.maxLat <= cachedBounds.maxLat &&
               currentBounds.minLon >= cachedBounds.minLon &&
               currentBounds.maxLon <= cachedBounds.maxLon
    }
    
    // MARK: - Map Region Updates with Smooth Loading
    @MainActor
    func updateMapRegion(_ newRegion: MKCoordinateRegion) {
        region = newRegion
        updateAreaNameDebounced(for: newRegion.center)
        
        // INSTANT: Update from cache for smooth panning
        if canUseCachedData(for: newRegion) {
            updateViewportRestaurantsSync(newRegion)
        } else {
            // SMOOTH: Load new data in background while keeping current pins
            Task {
                await fetchRestaurantsForViewport(newRegion)
            }
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
        // Viewport fetching handles this automatically
    }

    // MARK: - Fresh Data Loading
    func refreshData(for coordinate: CLLocationCoordinate2D) {
        guard !isLoadingRestaurants else { return }
        
        debugLog(" REFRESH - Loading best 50 restaurants for new area")
        
        // Clear cache for fresh data
        restaurants.removeAll()
        allCachedRestaurants.removeAll()
        lastFetchedBounds = nil
        lastUpdateTime = Date.distantPast
        
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
        Task { @MainActor in
            updateMapRegion(newRegion)
        }
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
    
    func fetchRestaurantsSimple(for coordinate: CLLocationCoordinate2D) async {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        await fetchRestaurantsForViewport(region)
    }

    // MARK: - ENHANCED: Advanced Search with Food Types and Menu Items
    func performSearch(query: String) async {
        isLoadingRestaurants = true
        
        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // ENHANCED: Multi-criteria search
        let searchResults = allCachedRestaurants.filter { restaurant in
            // 1. Restaurant name search
            let nameMatch = restaurant.name.localizedCaseInsensitiveContains(searchQuery)
            
            // 2. Cuisine type search
            let cuisineMatch = restaurant.cuisine?.localizedCaseInsensitiveContains(searchQuery) == true
            
            // 3. ENHANCED: Food type search by restaurant specialization
            let foodTypeMatch = searchByFoodType(restaurant: restaurant, query: searchQuery)
            
            // 4. ENHANCED: Menu item search (for restaurants with nutrition data)
            let menuItemMatch = searchMenuItems(restaurant: restaurant, query: searchQuery)
            
            return nameMatch || cuisineMatch || foodTypeMatch || menuItemMatch
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
            // Limit search results to 50 for consistency
            self.filteredRestaurants = Array(sortedResults.prefix(50))
            self.showSearchResults = true
            self.isLoadingRestaurants = false
            
            // Auto-zoom to show search results
            if !self.filteredRestaurants.isEmpty {
                self.zoomToFitSearchResults()
            }
            
            debugLog(" ADVANCED SEARCH: Found \(self.filteredRestaurants.count) results for '\(query)'")
        }
    }
    
    // ENHANCED: Search by food type based on restaurant name and specialization
    private func searchByFoodType(restaurant: Restaurant, query: String) -> Bool {
        let restaurantName = restaurant.name.lowercased()
        
        // Food type mappings - search for food types in restaurant names
        let foodTypeKeywords: [String: [String]] = [
            // Pizza
            "pizza": ["pizza", "pizzeria", "pie", "pizza hut", "domino", "papa john", "little caesar", "sbarro"],
            
            // Burgers
            "burger": ["burger", "burgers", "mcdonald", "burger king", "wendy", "five guys", "shake shack", "in-n-out", "white castle", "whataburger", "carl's jr", "hardee"],
            "burgers": ["burger", "burgers", "mcdonald", "burger king", "wendy", "five guys", "shake shack", "in-n-out", "white castle", "whataburger", "carl's jr", "hardee"],
            
            // Tacos
            "taco": ["taco", "tacos", "taco bell", "chipotle", "qdoba", "del taco", "mexican"],
            "tacos": ["taco", "tacos", "taco bell", "chipotle", "qdoba", "del taco", "mexican"],
            
            // Sushi
            "sushi": ["sushi", "japanese", "sashimi", "roll", "hibachi", "benihana", "panda express"],
            
            // Chinese
            "chinese": ["chinese", "china", "wok", "panda", "express", "pf chang", "pick up stix"],
            
            // Chicken
            "chicken": ["chicken", "kfc", "popeyes", "chick-fil-a", "raising cane", "church's", "bojangles", "zaxby", "pdq"],
            
            // Sandwiches
            "sandwich": ["sandwich", "sub", "subway", "jimmy john", "quiznos", "panera", "potbelly", "jersey mike"],
            "sandwiches": ["sandwich", "sub", "subway", "jimmy john", "quiznos", "panera", "potbelly", "jersey mike"],
            
            // Coffee
            "coffee": ["coffee", "starbucks", "dunkin", "tim horton", "caribou", "peet", "cafe"],
            
            // Ice cream
            "ice cream": ["ice cream", "baskin robbins", "dairy queen", "cold stone", "ben & jerry", "häagen-dazs"],
            "icecream": ["ice cream", "baskin robbins", "dairy queen", "cold stone", "ben & jerry", "häagen-dazs"],
            
            // Donuts
            "donut": ["donut", "donuts", "dunkin", "krispy kreme", "tim horton"],
            "donuts": ["donut", "donuts", "dunkin", "krispy kreme", "tim horton"],
            
            // BBQ
            "bbq": ["bbq", "barbecue", "grill", "smokehouse", "ribs"],
            "barbecue": ["bbq", "barbecue", "grill", "smokehouse", "ribs"],
            
            // Salad
            "salad": ["salad", "salads", "sweetgreen", "chop't", "panera", "fresh"],
            "salads": ["salad", "salads", "sweetgreen", "chop't", "panera", "fresh"],
            
            // Seafood
            "seafood": ["seafood", "fish", "shrimp", "lobster", "crab", "red lobster", "long john silver"],
            
            // Pasta
            "pasta": ["pasta", "italian", "spaghetti", "olive garden", "fazoli", "noodles"],
            
            // Steak
            "steak": ["steak", "steakhouse", "outback", "texas roadhouse", "longhorn", "ruth's chris"],
            
            // Breakfast
            "breakfast": ["breakfast", "ihop", "denny", "waffle house", "pancake", "ihop", "perkins"],
            
            // Deli
            "deli": ["deli", "delicatessen", "pastrami", "corned beef", "reuben"]
        ]
        
        // Check if query matches any food type and if restaurant name contains related keywords
        for (foodType, keywords) in foodTypeKeywords {
            if query.contains(foodType) {
                return keywords.contains { keyword in
                    restaurantName.contains(keyword)
                }
            }
        }
        
        return false
    }
    
    // ENHANCED: Search through menu items for restaurants with nutrition data
    private func searchMenuItems(restaurant: Restaurant, query: String) -> Bool {
        // Only search menu items for restaurants with nutrition data
        guard restaurant.hasNutritionData else { return false }
        
        // This would require accessing the nutrition data for each restaurant
        // For now, we'll do basic food type matching based on restaurant specialization
        // In a full implementation, you'd load the actual menu data and search through it
        
        // Basic menu item inference based on restaurant type
        let inferredMenuItems = getInferredMenuItems(for: restaurant)
        
        return inferredMenuItems.contains { menuItem in
            menuItem.localizedCaseInsensitiveContains(query)
        }
    }
    
    // Helper function to infer likely menu items based on restaurant name/type
    private func getInferredMenuItems(for restaurant: Restaurant) -> [String] {
        let name = restaurant.name.lowercased()
        var menuItems: [String] = []
        
        // Pizza places
        if name.contains("pizza") {
            menuItems += ["pizza", "pepperoni", "cheese", "supreme", "margherita", "hawaiian", "meat lovers", "veggie"]
        }
        
        // Burger places
        if name.contains("burger") || name.contains("mcdonald") || name.contains("burger king") {
            menuItems += ["burger", "cheeseburger", "fries", "chicken nuggets", "milkshake", "big mac", "whopper"]
        }
        
        // Taco places
        if name.contains("taco") || name.contains("chipotle") {
            menuItems += ["taco", "burrito", "quesadilla", "nachos", "guacamole", "salsa", "carnitas", "chicken"]
        }
        
        // Chinese places
        if name.contains("chinese") || name.contains("panda") {
            menuItems += ["fried rice", "lo mein", "sweet and sour", "orange chicken", "beef broccoli", "kung pao"]
        }
        
        // Chicken places
        if name.contains("chicken") || name.contains("kfc") {
            menuItems += ["fried chicken", "chicken sandwich", "wings", "tenders", "popcorn chicken"]
        }
        
        // Sandwich shops
        if name.contains("subway") || name.contains("sandwich") {
            menuItems += ["sandwich", "sub", "turkey", "ham", "tuna", "italian", "veggie", "meatball"]
        }
        
        // Coffee shops
        if name.contains("starbucks") || name.contains("coffee") {
            menuItems += ["coffee", "latte", "cappuccino", "frappuccino", "espresso", "macchiato", "pastry"]
        }
        
        return menuItems
    }
    
    /// Auto-zoom the map to fit all search results
    private func zoomToFitSearchResults() {
        guard !filteredRestaurants.isEmpty else { return }
        
        // Calculate bounds for all search results
        var minLat = filteredRestaurants[0].latitude
        var maxLat = filteredRestaurants[0].latitude
        var minLon = filteredRestaurants[0].longitude
        var maxLon = filteredRestaurants[0].longitude
        
        for restaurant in filteredRestaurants {
            minLat = min(minLat, restaurant.latitude)
            maxLat = max(maxLat, restaurant.latitude)
            minLon = min(minLon, restaurant.longitude)
            maxLon = max(maxLon, restaurant.longitude)
        }
        
        // Add padding around the bounds
        let padding = 0.01 // Padding in degrees
        minLat -= padding
        maxLat += padding
        minLon -= padding
        maxLon += padding
        
        // Calculate center and span
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01), // Minimum span
            longitudeDelta: max(maxLon - minLon, 0.01)
        )
        
        // Update region with animation
        let newRegion = MKCoordinateRegion(center: center, span: span)
        
        withAnimation(.easeInOut(duration: 1.0)) {
            region = newRegion
        }
        
        debugLog(" ZOOM: Adjusted map to show \(filteredRestaurants.count) search results")
    }
    
    func clearSearch() {
        showSearchResults = false
        filteredRestaurants = []
        debugLog(" CLEAR: Search cleared")
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