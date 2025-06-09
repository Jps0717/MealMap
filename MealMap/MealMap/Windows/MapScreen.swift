import SwiftUI
import MapKit
import CoreLocation

// MARK: - Main MapScreen

struct MapScreen: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var clusterManager = ClusterManager()
    @StateObject private var searchManager = SearchManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var showFilterPanel: Bool = false
    @State private var hasActiveFilters: Bool = false
    @State private var currentAreaName: String = "Loading..."
    @State private var lastGeocodeTime: Date = Date()
    @State private var lastGeocodeLocation: CLLocationCoordinate2D?
    @State private var hasInitialLocation: Bool = false
    @State private var showListView: Bool = false
    @State private var restaurants: [Restaurant] = []
    @State private var lastClusterUpdateTime: Date = Date.distantPast // For throttling cluster updates
    @State private var isLoadingRestaurants: Bool = false
    @State private var lastDataFetchLocation: CLLocationCoordinate2D?
    @State private var lastDataFetchTime: Date = Date.distantPast
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    @State private var filteredRestaurants: [Restaurant] = []
    @State private var showSearchResults = false
    @State private var searchErrorMessage: String?
    @State private var showSearchError = false

    // Overpass API Service
    private let overpassService = OverpassAPIService()

    // Haptic Feedback Generators
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    // Filter States
    @State private var selectedPriceRange: FilterPanel.PriceRange = .all
    @State private var selectedCuisines: Set<String> = []
    @State private var selectedRating: Double = 0
    @State private var isOpenNow: Bool = false
    @State private var maxDistance: Double = 5.0 // in miles

    private let minimumGeocodeInterval: TimeInterval = 5.0
    private let minimumDistanceChange: CLLocationDegrees = 0.01
    private let zoomedOutThreshold: CLLocationDegrees = 0.5 // Threshold for showing state vs city
    private let pinVisibilityThreshold: CLLocationDegrees = 0.1 // Threshold for showing individual pins
    private let clusterVisibilityThreshold: CLLocationDegrees = 0.15 // Threshold for showing clusters
    private let clusterUpdateThrottle: TimeInterval = 0.5 // Throttle cluster updates to every 0.5 seconds

    private let minimumDataFetchInterval: TimeInterval = 2.0
    private let minimumDataFetchDistance: CLLocationDegrees = 0.05

    // List of restaurants with nutrition data
    private let restaurantsWithNutritionData = [
        "7 Eleven", "Applebee's", "Arby's", "Auntie Anne's", "BJ's Restaurant & Brewhouse",
        "Baskin Robbins", "Bob Evans", "Bojangles", "Bonefish Grill", "Boston Market",
        "Burger King", "California Pizza Kitchen", "Captain D's", "Carl's Jr.",
        "Carrabba's Italian Grill", "Casey's General Store", "Checker's Drive-In/Rallys",
        "Chick-Fil-A", "Chick-fil-A", "Chili's", "Chipotle", "Chuck E. Cheese",
        "Church's Chicken", "Ci Ci's Pizza", "Culver's", "Dairy Queen", "Del Taco",
        "Denny's", "Dickey's Barbeque Pit", "Dominos", "Dunkin' Donuts", "Einstein Bros",
        "El Pollo Loco", "Famous Dave's", "Firehouse Subs", "Five Guys", "Friendly's",
        "Frisch's Big Boy", "Golden Corral", "Hardee's", "Hooters", "IHOP",
        "In-N-Out Burger", "Jack in the Box", "Jamba Juice", "Jason's Deli",
        "Jersey Mike's Subs", "Joe's Crab Shack", "KFC", "Krispy Klement", "Krystal",
        "Little Caesars", "Long John Silver's", "LongHorn Steakhouse", "Marco's Pizza",
        "McAlister's Deli", "McDonald's", "Moe's Southwest Grill", "Noodles & Company",
        "O'Charley's", "Olive Garden", "Outback Steakhouse", "PF Chang's", "Panda Express",
        "Panera Bread", "Papa John's", "Papa Murphy's", "Perkins", "Pizza Hut", "Popeyes",
        "Potbelly Sandwich Shop", "Qdoba", "Quiznos", "Red Lobster", "Red Robin",
        "Romano's Macaroni Grill", "Round Table Pizza", "Ruby Tuesday", "Sbarro", "Sheetz",
        "Sonic", "Starbucks", "Steak 'N Shake", "Subway", "TGI Friday's", "Taco Bell",
        "The Capital Grille", "Tim Hortons", "Wawa", "Wendy's", "Whataburger",
        "White Castle", "Wingstop", "Yard House", "Zaxby's"
    ]

    private var shouldShowClusters: Bool {
        region.span.latitudeDelta > 0.02 && !showSearchResults // Don't show clusters during search
    }

    private var mapItems: [MapItem] {
        // Use filtered restaurants if there's an active search, otherwise use all restaurants
        let restaurantsToShow = showSearchResults ? filteredRestaurants : restaurants
        
        if showSearchResults {
            // When searching, always show individual pins regardless of zoom level
            return getFilteredRestaurantsForDisplay(from: restaurantsToShow).map { .restaurant($0) }
        }
        
        // Hide all annotations if zoomed out too far (only when not searching)
        if region.span.latitudeDelta > clusterVisibilityThreshold {
            return []
        }
        
        if shouldShowClusters {
            // Only show clusters when not searching
            return clusterManager.clusters.map { .cluster($0) }
        } else {
            return getFilteredRestaurantsForDisplay(from: restaurantsToShow).map { .restaurant($0) }
        }
    }
    
    private func getFilteredRestaurantsForDisplay(from restaurantList: [Restaurant]) -> [Restaurant] {
        let maxRestaurants = showSearchResults ? 100 : 50 // Show more results when searching
        let center = region.center
        let isZoomedIn = region.span.latitudeDelta <= pinVisibilityThreshold
        let isZoomedOutTooFar = region.span.latitudeDelta > clusterVisibilityThreshold && !showSearchResults
        
        // If zoomed out too far, return empty array to hide everything (except during search)
        guard !isZoomedOutTooFar else { return [] }
        
        // If zoomed in enough or searching, show individual pins
        if isZoomedIn || showSearchResults {
            return restaurantList.sorted { r1, r2 in
                let d1 = pow(r1.latitude - center.latitude, 2) + pow(r1.longitude - center.longitude, 2)
                let d2 = pow(r2.latitude - center.latitude, 2) + pow(r2.longitude - center.longitude, 2)
                return d1 < d2
            }.prefix(maxRestaurants).map { $0 }
        }
        
        // Otherwise, show all restaurants for clustering
        return restaurantList
    }

    var body: some View {
        ZStack {
            if let locationError = locationManager.locationError {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "location.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text(locationError)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    Button(action: { locationManager.restart() }) {
                        Text("Try Again")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(24)
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    }
                    Spacer()
                }
                .background(Color(.systemBackground).ignoresSafeArea())
            } else if !networkMonitor.isConnected {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Network Connection")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Button(action: { locationManager.restart() }) {
                        Text("Try Again")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(24)
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    }
                    Spacer()
                }
                .background(Color(.systemBackground).ignoresSafeArea())
            } else {
                ZStack(alignment: .top) {
                    Map(coordinateRegion: Binding(
                        get: { region },
                        set: { newRegion in
                            let oldRegion = region
                            region = newRegion
                            
                            // Only update area name if significantly moved
                            let regionChange = abs(oldRegion.center.latitude - newRegion.center.latitude) + 
                                             abs(oldRegion.center.longitude - newRegion.center.longitude)
                            if regionChange > 0.01 {
                                updateAreaName(for: newRegion.center)
                            }

                            // More efficient cluster and data updates with transition detection
                            let now = Date()
                            let zoomChange = abs(oldRegion.span.latitudeDelta - newRegion.span.latitudeDelta)
                            
                            // Only update clusters if zoom changed significantly or enough time has passed and not searching
                            if !showSearchResults && (zoomChange > 0.001 || now.timeIntervalSince(lastClusterUpdateTime) > clusterUpdateThrottle) {
                                clusterManager.updateClusters(
                                    restaurants: restaurants,
                                    zoomLevel: newRegion.span.latitudeDelta,
                                    span: newRegion.span,
                                    center: newRegion.center,
                                    debounceDelay: zoomChange > 0.005 ? 0.1 : 0.3
                                )
                                lastClusterUpdateTime = now
                            }

                            fetchRestaurantDataAndUpdateClusters(for: newRegion.center)
                        }
                    ), showsUserLocation: true, annotationItems: mapItems) { item in
                        MapAnnotation(coordinate: item.coordinate) {
                            switch item {
                            case .cluster(let cluster):
                                ClusterAnnotationView(
                                    count: cluster.count,
                                    nutritionDataCount: cluster.nutritionDataCount,
                                    noNutritionDataCount: cluster.noNutritionDataCount
                                )
                                .transition(.asymmetric(
                                    insertion: clusterManager.transitionState == .mergingToClusters ? 
                                        .scale(scale: 0.1).combined(with: .opacity) : 
                                        .scale.combined(with: .opacity),
                                    removal: clusterManager.transitionState == .splittingToIndividual ?
                                        .scale(scale: 3.0).combined(with: .opacity) :
                                        .scale.combined(with: .opacity)
                                ))
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: clusterManager.transitionState)
                                
                            case .restaurant(let restaurant):
                                RestaurantAnnotationView(
                                    restaurant: restaurant,
                                    hasNutritionData: restaurantsWithNutritionData.contains(restaurant.name),
                                    isSelected: selectedRestaurant?.id == restaurant.id,
                                    onTap: { tappedRestaurant in
                                        selectedRestaurant = tappedRestaurant
                                        showingRestaurantDetail = true
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: clusterManager.transitionState == .splittingToIndividual ?
                                        .scale(scale: 0.1).combined(with: .opacity).combined(with: .offset(y: -10)) :
                                        .scale.combined(with: .opacity),
                                    removal: clusterManager.transitionState == .mergingToClusters ?
                                        .scale(scale: 0.1).combined(with: .opacity).combined(with: .offset(y: 10)) :
                                        .scale.combined(with: .opacity)
                                ))
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double.random(in: 0...0.2)), value: clusterManager.transitionState)
                            }
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: []))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: clusterManager.clusters.count)
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: clusterManager.transitionState)

                    // --- TOP OVERLAYS: Search bar & City tag ---
                    VStack(alignment: .center, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .font(.system(size: 16, weight: .medium))

                            TextField("Search restaurants, cuisines...", text: $searchText)
                                .font(.system(size: 16))
                                .disableAutocorrection(true)
                                .onSubmit {
                                    performSearch()
                                }
                                .onChange(of: searchText) { oldValue, newValue in
                                    if !newValue.isEmpty && oldValue.isEmpty {
                                        lightFeedback.impactOccurred()
                                    }
                                    
                                    // Clear search results when text is cleared
                                    if newValue.isEmpty {
                                        clearSearch()
                                    }
                                }

                            if !searchText.isEmpty {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        clearSearch()
                                        lightFeedback.impactOccurred()
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                }
                            }

                            Button(action: {
                                performSearch()
                                mediumFeedback.impactOccurred()
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Enhanced City tag - centered and interactive
                        HStack(spacing: 4) {
                            Text(currentAreaName.uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                        )
                        
                        if showSearchResults {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 12))
                                
                                if maxDistance < 20.0 {
                                    Text("Showing \(filteredRestaurants.count) results within \(Int(maxDistance)) mi")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.blue)
                                } else {
                                    Text("Showing \(filteredRestaurants.count) results")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                                
                                Button("Clear") {
                                    clearSearch()
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                            )
                        }

                        Spacer()
                    }
                    .ignoresSafeArea(.keyboard)

                    // --- BOTTOM OVERLAY: Enhanced List, Filter, User Location ---
                    VStack {
                        Spacer()
                        MapBottomOverlay(
                            hasActiveFilters: hasActiveFilters,
                            onListView: {
                                mediumFeedback.impactOccurred()
                                showListView = true
                            },
                            onFilter: {
                                mediumFeedback.impactOccurred()
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    showFilterPanel = true
                                }
                            },
                            onUserLocation: {
                                // Animate map to user location with haptic feedback
                                heavyFeedback.impactOccurred()

                                if let loc = locationManager.lastLocation {
                                    withAnimation(.easeInOut(duration: 1.0)) {
                                        region = MKCoordinateRegion(
                                            center: loc.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                        )
                                    }
                                    updateAreaName(for: loc.coordinate)
                                    fetchRestaurantDataAndUpdateClusters(for: loc.coordinate)
                                }
                            }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 12)
                }

                // --- ENHANCED FILTER PANEL (sheet style) ---
                if showFilterPanel {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            lightFeedback.impactOccurred()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                showFilterPanel = false
                            }
                        }
                    FilterPanel(
                        show: $showFilterPanel,
                        hasActiveFilters: $hasActiveFilters,
                        selectedPriceRange: $selectedPriceRange,
                        selectedCuisines: $selectedCuisines,
                        selectedRating: $selectedRating,
                        isOpenNow: $isOpenNow,
                        maxDistance: $maxDistance
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                    .onChange(of: maxDistance) { oldValue, newValue in
                        hasActiveFilters = newValue < 20.0
                    }
                }

                // Enhanced Loading State
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(1.2)
                            Text("Finding restaurants...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                    }
                }

                if isLoadingRestaurants {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                                Text("Loading restaurants...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            )
                            .padding(.trailing, 16)
                        }
                        Spacer()
                    }
                    .padding(.top, 120) // Position below search bar
                }

                // Restaurant detail overlay
                if showingRestaurantDetail, let restaurant = selectedRestaurant {
                    RestaurantDetailView(
                        restaurant: restaurant,
                        isPresented: $showingRestaurantDetail
                    )
                    .zIndex(100) // Ensure it appears above everything
                    .onDisappear {
                        selectedRestaurant = nil
                    }
                }
            }
        }
        .preferredColorScheme(.light)  // Force light theme
        .sheet(isPresented: $showListView) {
            ListView()
        }
        .onDisappear {
            clusterManager.clearCache()
        }
        .alert("Search Results", isPresented: $showSearchError) {
            Button("OK") { }
        } message: {
            Text(searchErrorMessage ?? "")
        }
    }
    
    private func updateAreaName(for coordinate: CLLocationCoordinate2D) {
        guard shouldUpdateLocation(coordinate) else { return }

        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        Task { @MainActor in
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                guard let placemark = placemarks.first else {
                    print("No placemark found")
                    return
                }

                // Update our tracking variables
                lastGeocodeTime = Date()
                lastGeocodeLocation = coordinate

                // Check if we're zoomed out
                let isZoomedOut = region.span.latitudeDelta > zoomedOutThreshold

                if isZoomedOut {
                    // When zoomed out, show state
                    if let state = placemark.administrativeArea {
                        currentAreaName = state
                    } else if let country = placemark.country {
                        currentAreaName = country
                    }
                } else {
                    // When zoomed in, show city/town
                    if let city = placemark.locality {
                        currentAreaName = city
                    } else if let town = placemark.subLocality {
                        currentAreaName = town
                    } else if let state = placemark.administrativeArea {
                        currentAreaName = state
                    }
                }

                // Debug information
                print("Map Center Location details:")
                print("Zoom Level: \(isZoomedOut ? "Out" : "In")")
                print("Latitude Delta: \(region.span.latitudeDelta)")
                print("City: \(placemark.locality ?? "nil")")
                print("Town: \(placemark.subLocality ?? "nil")")
                print("State: \(placemark.administrativeArea ?? "nil")")
            } catch {
                print("Geocoding error: \(error.localizedDescription)")
            }
        }
    }

    private func shouldUpdateLocation(_ newLocation: CLLocationCoordinate2D) -> Bool {
        let timeSinceLastGeocode = Date().timeIntervalSince(lastGeocodeTime)
        guard timeSinceLastGeocode >= minimumGeocodeInterval else { return false }

        if let lastLocation = lastGeocodeLocation {
            let distance = abs(newLocation.latitude - lastLocation.latitude) +
                          abs(newLocation.longitude - lastLocation.longitude)
            return distance >= minimumDistanceChange
        }

        return true
    }

    private func fetchRestaurantDataAndUpdateClusters(for center: CLLocationCoordinate2D) {
        guard shouldFetchNewData(for: center) && !isLoadingRestaurants else { return }
        
        // Update tracking variables immediately to prevent duplicate requests
        lastDataFetchLocation = center
        lastDataFetchTime = Date()
        isLoadingRestaurants = true
        
        Task {
            do {
                let fetched = try await overpassService.fetchFastFoodRestaurants(near: center)
                print("Found \(fetched.count) restaurants in the current region")
                if let firstRestaurant = fetched.first {
                    print("First restaurant: \(firstRestaurant.name) at \(firstRestaurant.latitude), \(firstRestaurant.longitude)")
                }
                
                await MainActor.run {
                    restaurants = fetched
                    isLoadingRestaurants = false
                    // Always update clusters when new restaurant data arrives
                    clusterManager.updateClusters(
                        restaurants: restaurants,
                        zoomLevel: region.span.latitudeDelta,
                        span: region.span,
                        center: region.center,
                        debounceDelay: 0.3
                    )
                    print("Updated clusters with \(clusterManager.clusters.count) clusters")
                }
            } catch {
                await MainActor.run {
                    isLoadingRestaurants = false
                }
                print("Error fetching restaurants: \(error)")
            }
        }
    }

    private func shouldFetchNewData(for newCenter: CLLocationCoordinate2D) -> Bool {
        let timeSinceLastFetch = Date().timeIntervalSince(lastDataFetchTime)
        guard timeSinceLastFetch >= minimumDataFetchInterval else { return false }
        
        if let lastLocation = lastDataFetchLocation {
            let distance = abs(newCenter.latitude - lastLocation.latitude) +
                          abs(newCenter.longitude - lastLocation.longitude)
            return distance >= minimumDataFetchDistance
        }
        
        return true
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let distanceFilter = maxDistance < 20.0 ? maxDistance : nil
        
        let result = searchManager.search(
            query: searchText,
            in: restaurants,
            userLocation: locationManager.lastLocation,
            maxDistance: distanceFilter
        )
        
        handleSearchResult(result)
    }
    
    private func handleSearchResult(_ result: SearchResult) {
        switch result {
        case .noQuery:
            break
            
        case .noResults(let query):
            searchErrorMessage = "No restaurants found for '\(query)'. Try searching for a restaurant name or cuisine type."
            showSearchError = true
            
        case .singleResult(let restaurant):
            // Pan and zoom to the single restaurant
            zoomToRestaurant(restaurant)
            filteredRestaurants = [restaurant]
            showSearchResults = true
            
        case .chainResult(let restaurant, let totalCount):
            // Pan to closest location of the chain
            zoomToRestaurant(restaurant)
            filteredRestaurants = [restaurant]
            showSearchResults = true
            
        case .cuisineResults(let restaurants, let cuisine):
            // Zoom out and show all matching restaurants
            showCuisineResults(restaurants, cuisine: cuisine)
            
        case .partialNameResult(let restaurant, let matches):
            // Pan to closest match
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
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005) // Zoom in close
            )
        }
    }
    
    private func showCuisineResults(_ restaurants: [Restaurant], cuisine: String) {
        filteredRestaurants = restaurants
        showSearchResults = true
        
        // Calculate region to show all results
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
        
        let spanLat = max((maxLat - minLat) * 1.2, 0.01) // Add 20% padding
        let spanLon = max((maxLon - minLon) * 1.2, 0.01)
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }
    
    private func clearSearch() {
        searchText = ""
        filteredRestaurants = []
        showSearchResults = false
        searchManager.hasActiveSearch = false
    }
}

// MARK: - Enhanced Bottom Overlay Bar

struct MapBottomOverlay: View {
    let hasActiveFilters: Bool
    var onListView: () -> Void
    var onFilter: () -> Void
    var onUserLocation: () -> Void

    @State private var lastTapTime: Date?
    @State private var tapCount: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            // Enhanced LIST VIEW button with icon
            Button(action: onListView) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14, weight: .semibold))
                    Text("LIST VIEW")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.white)
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Enhanced Filter button with active state indicator
            Button(action: onFilter) {
                ZStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(hasActiveFilters ? .white : .blue)
                        .frame(width: 44, height: 44)
                        .background(hasActiveFilters ? .blue : .white)
                        .cornerRadius(22)
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)

                    // Active filter indicator
                    if hasActiveFilters {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 14, y: -14)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Enhanced User location button with gradient
            Button(action: onUserLocation) {
                Image(systemName: "location.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(22)
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
    }
}

// MARK: - Enhanced Filter Panel

struct FilterPanel: View {
    @Binding var show: Bool
    @Binding var hasActiveFilters: Bool
    @Binding var selectedPriceRange: PriceRange
    @Binding var selectedCuisines: Set<String>
    @Binding var selectedRating: Double
    @Binding var isOpenNow: Bool
    @Binding var maxDistance: Double

    @State private var selectedSection: FilterSection? = nil
    @State private var lastShowTime: Date?
    @State private var showClearConfirmation: Bool = false
    @State private var screenWidth: CGFloat = UIScreen.main.bounds.width

    enum FilterSection: String, CaseIterable {
        case distance = "Maximum Distance"
    }

    enum PriceRange: String, CaseIterable {
        case all = "All"
        case budget = "$"
        case moderate = "$$"
        case expensive = "$$$"
        case luxury = "$$$$"
    }

    let cuisineTypes = ["Italian", "Asian", "Mexican", "American", "Mediterranean", "Indian", "Japanese", "Thai"]

    private func calculateContentHeight() -> CGFloat {
        let baseHeight: CGFloat = 160
        let itemHeight: CGFloat = 76  
        let spacing: CGFloat = 16     
        let padding: CGFloat = 32
        let maxHeight: CGFloat = 600 

        let contentHeight: CGFloat
        switch selectedSection {
        case .distance:
            contentHeight = baseHeight + 100
        case .none:
            contentHeight = baseHeight + (CGFloat(FilterSection.allCases.count) * 80) + padding
        }
        return min(contentHeight, maxHeight)
    }

    private func calculateScrollViewHeight() -> CGFloat {
        let baseHeight: CGFloat = 160
        let maxHeight: CGFloat = 400
        let itemHeight: CGFloat = 76
        let spacing: CGFloat = 16

        switch selectedSection {
        case .distance:
            return 120
        case .none:
            return 300
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Capsule()
                .frame(width: 40, height: 5)
                .foregroundColor(Color(.systemGray4))
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Header
            HStack {
                Text("Preferences")
                    .font(.system(size: 24, weight: .bold))
                Spacer()
                Button("Clear All") {
                    showClearConfirmation = true
                }
                .foregroundColor(.red)
                .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 20)

            if let selectedSection = selectedSection {
                // Carousel View
                VStack(spacing: 25) {
                    // Section Header
                    HStack {
                        Button(action: {
                            withAnimation {
                                self.selectedSection = nil
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }

                        Text(selectedSection.rawValue)
                            .font(.system(size: 20, weight: .bold))

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    // Section Content
                    VStack(spacing: 4) {
                        switch selectedSection {
                        case .distance:
                            VStack(spacing: 20) {
                                HStack {
                                    Text("1 mi")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    Slider(value: $maxDistance, in: 1...20, step: 1)
                                        .accentColor(.blue)
                                    Text("20 mi")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                Text("\(Int(maxDistance)) miles")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                // Main Menu
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(FilterSection.allCases, id: \.self) { section in
                            Button(action: {
                                withAnimation {
                                    selectedSection = section
                                }
                            }) {
                                HStack {
                                    Text(section.rawValue)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Spacer()

                                    // Show selection count or value
                                    switch section {
                                    case .distance:
                                        Text("\(Int(maxDistance)) mi")
                                            .foregroundColor(.gray)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }

            Spacer(minLength: 0)

            // Apply Button
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    show = false
                }
            }) {
                Text("Save Preferences")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(24)
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: calculateContentHeight())
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 20, y: -8)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .ignoresSafeArea(.keyboard)
        .onTapGesture { } // absorb tap
        .onChange(of: show) { oldValue, newValue in
            if newValue {
                lastShowTime = Date()
            }
        }
        .alert("Clear All Preferences?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedPriceRange = .all
                    selectedCuisines.removeAll()
                    selectedRating = 0
                    isOpenNow = false
                    maxDistance = 5.0
                    hasActiveFilters = false
                }
            }
        } message: {
            Text("Are you sure you want to clear all your preferences? This cannot be undone.")
        }
    }

    private func updateActiveFilters() {
        hasActiveFilters = maxDistance < 20.0
    }
}

// MARK: - Preference Toggle Button
struct PreferenceToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    let scale: CGFloat
    let opacity: Double
    let isSelectable: Bool

    var body: some View {
        Button(action: isSelectable ? action : {}) {
            HStack(spacing: 20) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 26))
                        .foregroundColor(.gray)
                }

                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isSelectable)
    }
}

struct FadingScrollView<Content: View>: View {
    let items: [Any]
    let content: (Any, Bool) -> Content

    @State private var scrollOffset: CGFloat = 0
    @State private var viewHeight: CGFloat = 0

    private let itemHeight: CGFloat = 60
    private let spacing: CGFloat = 8
    private let fadeHeight: CGFloat = 30

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: spacing) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        content(item, false)
                            .frame(height: itemHeight)
                    }
                }
                .padding(.vertical, fadeHeight)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: proxy.frame(in: .named("scrollView")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scrollView")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
                viewHeight = geometry.size.height
            }
            .mask(
                VStack(spacing: 0) {
                    // Top fade
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: fadeHeight)

                    // Middle solid
                    Rectangle()
                        .fill(Color.black)

                    // Bottom fade
                    LinearGradient(
                        gradient: Gradient(colors: [.black, .clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: fadeHeight)
                }
            )
        }
    }
}

struct FocusedScrollView<Content: View>: View {
    let content: Content
    @State private var scrollOffset: CGFloat = 0
    @State private var viewHeight: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("scrollView")).minY
                            )
                        }
                    )
            }
            .coordinateSpace(name: "scrollView")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
                viewHeight = geometry.size.height
            }
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    MapScreen()
}

enum MapItem: Identifiable {
    case cluster(MapCluster)
    case restaurant(Restaurant)

    var id: AnyHashable {
        switch self {
        case .cluster(let c): return c.id
        case .restaurant(let r): return r.id
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .cluster(let c): return c.coordinate
        case .restaurant(let r): return CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude)
        }
    }
}
