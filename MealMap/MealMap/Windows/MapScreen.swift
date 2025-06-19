import SwiftUI
import MapKit
import CoreLocation

// MARK: - Simplified MapScreen with ViewModel

struct MapScreen: View {
    @ObservedObject var viewModel: MapViewModel
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var searchManager = SearchManager()
    
    // UI State - Enhanced with loading states
    @State private var searchText = ""
    @State private var lastRegionUpdate = Date.distantPast
    @State private var isLoadingView = true
    @State private var isSearching = false
    @State private var searchLoadingProgress: Double = 0.0
    
    // PERFORMANCE: Cache filtered restaurants to reduce recomputation
    @State private var cachedFilteredRestaurants: [Restaurant] = []
    @State private var lastCachedZoom: CLLocationDegrees = 0
    @State private var lastCachedCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var cacheTimestamp: Date = Date.distantPast
    
    // PERFORMANCE: Debouncing state
    @State private var regionUpdateTask: Task<Void, Never>?
    @State private var filterTask: Task<Void, Never>?
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingHomeScreen = false
    
    init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }
    
    // Haptic Feedback
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    
    // Configuration - Optimized for progressive pin loading
    private let pinVisibilityThreshold: CLLocationDegrees = 0.08
    private let maxZoomOutLevel: CLLocationDegrees = 0.15
    
    // PERFORMANCE: Reduced zoom level complexity for better performance
    private let zoomLevels = (
        minimal: 0.15,    // Show only top 10 chains (zoomed way out)
        moderate: 0.08,   // Show top 20 chains (medium zoom)
        detailed: 0.04,   // Show top 35 restaurants (zoomed in)
        full: 0.02        // Show top 50 restaurants (very zoomed in) - REDUCED from 100
    )
    
    private let topPriorityChains = [
        "McDonald's", "Subway", "Starbucks", "Burger King", "KFC",
        "Taco Bell", "Pizza Hut", "Domino's", "Chick-fil-A", "Wendy's",
        "Chipotle", "Panera Bread", "Dunkin'", "Tim Hortons", "Arby's",
        "Olive Garden", "Applebee's", "IHOP", "Denny's", "Dairy Queen"
    ].filter { RestaurantData.restaurantsWithNutritionData.contains($0) }
    
    // Computed Properties
    private var hasValidLocation: Bool {
        locationManager.lastLocation != nil &&
        (locationManager.authorizationStatus == .authorizedWhenInUse ||
         locationManager.authorizationStatus == .authorizedAlways)
    }
    
    // PERFORMANCE: Optimized mapItems computation with caching
    private var mapItems: [MapItem] {
        var items: [MapItem] = []
        
        // Add user location
        if let userLocation = locationManager.lastLocation {
            items.append(.userLocation(userLocation.coordinate))
        }
        
        // PERFORMANCE: Use cached restaurants only - NO state modifications here
        items.append(contentsOf: cachedFilteredRestaurants.map { .restaurant($0) })
        
        return items
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if let locationError = locationManager.locationError {
                NoLocationView(
                    title: "Location Access Required",
                    subtitle: locationError,
                    buttonText: "Enable Location",
                    onRetry: {
                        locationManager.requestLocationPermission()
                    }
                )
            } else if !hasValidLocation {
                LoadingView(
                    title: "Getting Your Location",
                    subtitle: "MealMap needs your location to find restaurants near you...",
                    progress: nil,
                    style: .fullScreen
                )
            } else if !networkMonitor.isConnected {
                NoLocationView(
                    title: "No Network Connection",
                    subtitle: "Please check your internet connection and try again.",
                    buttonText: "Try Again",
                    onRetry: {
                        locationManager.restart()
                    }
                )
            } else if isLoadingView {
                LoadingView(
                    title: "Loading Map",
                    subtitle: "Preparing restaurant locations for you...",
                    progress: viewModel.loadingProgress,
                    style: .fullScreen
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                mainMapView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .preferredColorScheme(.light)
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.restaurants.isEmpty {
                setupMapView()
            } else {
                // If restaurants already loaded, skip loading screen
                isLoadingView = false
                // Initialize cache
                updateFilteredRestaurantsCache(for: viewModel.region)
            }
        }
        .onChange(of: locationManager.lastLocation) { oldLocation, newLocation in
            handleLocationChange(newLocation)
        }
        .onChange(of: viewModel.isLoadingRestaurants) { oldValue, newValue in
            if !newValue && isLoadingView {
                // Delay hiding loading to show smooth transition
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.isLoadingView = false
                    }
                }
            }
        }
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty && oldValue.isEmpty {
                Task { @MainActor in
                    self.startSearchAnimation()
                }
            } else if newValue.isEmpty {
                Task { @MainActor in
                    self.isSearching = false
                    self.searchLoadingProgress = 0.0
                }
            }
        }
        .onChange(of: viewModel.region) { oldRegion, newRegion in
            updateFilteredRestaurantsCache(for: newRegion)
        }
        .onChange(of: viewModel.restaurants) { oldRestaurants, newRestaurants in
            updateFilteredRestaurantsCache(for: viewModel.region)
        }
        .onChange(of: viewModel.hasActiveRadiusFilter) { oldValue, newValue in
            updateFilteredRestaurantsCache(for: viewModel.region)
        }
        .onChange(of: viewModel.showSearchResults) { oldValue, newValue in
            updateFilteredRestaurantsCache(for: viewModel.region)
        }
        .alert("Search Results", isPresented: $viewModel.showSearchError) {
            Button("OK") { }
        } message: {
            Text(viewModel.searchErrorMessage ?? "")
        }
        .sheet(isPresented: $showingHomeScreen) {
            NavigationView {
                HomeScreen()
                    .environmentObject(locationManager)
                    .environmentObject(viewModel)
                    .navigationBarTitleDisplayMode(.inline)
                    .preferredColorScheme(.light) // Force light mode in home screen
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showingHomeScreen = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Setup
    private func setupMapView() {
        setupInitialLocation()
        
        // Show loading for a minimum time for smooth UX
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            if !viewModel.isLoadingRestaurants {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.isLoadingView = false
                }
            }
        }
    }
    
    private func startSearchAnimation() {
        isSearching = true
        searchLoadingProgress = 0.0
        
        // Animate search progress
        Task { @MainActor in
            while searchLoadingProgress < 1.0 && isSearching {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                searchLoadingProgress += 0.15
                
                if searchLoadingProgress >= 1.0 {
                    searchLoadingProgress = 1.0
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second
                    isSearching = false
                    break
                }
            }
        }
    }
    
    // MARK: - Main Map View - Always Interactive
    private var mainMapView: some View {
        ZStack {
            // Map layer - PERFORMANCE: Simplified map interaction handling
            Map(coordinateRegion: Binding(
                get: { viewModel.region },
                set: { newRegion in
                    // PERFORMANCE: Move heavy computation to background
                    updateRegionAsync(newRegion)
                }
            ), showsUserLocation: false, annotationItems: mapItems) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    switch item {
                    case .userLocation(_):
                        UserLocationAnnotationView()
                            .allowsHitTesting(false)
                        
                    case .restaurant(let restaurant):
                        // PERFORMANCE: Optimized annotation view
                        OptimizedRestaurantAnnotationView(
                            restaurant: restaurant,
                            hasNutritionData: RestaurantData.restaurantsWithNutritionData.contains(restaurant.name),
                            isSelected: viewModel.selectedRestaurant?.id == restaurant.id,
                            onTap: { tappedRestaurant in
                                viewModel.selectRestaurant(tappedRestaurant)
                            }
                        )
                        .id("\(restaurant.id)_\(viewModel.selectedRestaurant?.id ?? 0)") // PERFORMANCE: Stable ID for better rendering
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: []))
            .ignoresSafeArea(edges: .all)
            .disabled(false) // Explicitly ensure map is never disabled
            // PERFORMANCE: Add gesture priority for smoother interactions
            .gesture(
                DragGesture()
                    .onChanged { _ in
                        // Light haptic feedback during map drag for better UX
                        mediumFeedback.impactOccurred()
                    }
            )
            
            // UI overlays that DON'T block map interaction
            VStack {
                // UPDATED: Enhanced header with reorganized layout
                enhancedHeader
                    .allowsHitTesting(true) // Allow header interactions
                Spacer()
            }
            
            // Non-blocking loading indicator - positioned to not interfere
            if viewModel.isLoadingRestaurants {
                MapDataLoadingView(progress: viewModel.loadingProgress)
            }
            
            // Search loading overlay
            if isSearching {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            CircularProgressView(progress: searchLoadingProgress, size: .medium)
                            
                            Text("Searching...")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        )
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                .allowsHitTesting(false)
                .zIndex(1)
            }
            
            restaurantDetailOverlay
                .zIndex(100) // Keep restaurant detail on top
        }
        .allowsHitTesting(true) // Ensure the entire ZStack allows interactions
    }
    
    // MARK: - Enhanced Header with Loading States
    private var enhancedHeader: some View {
        VStack(spacing: 16) {
            // Search bar at the top with loading indicator
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))

                TextField("Search restaurants, cuisines...", text: $searchText)
                    .font(.system(size: 16, design: .rounded))
                    .disableAutocorrection(true)
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        if newValue.isEmpty {
                            viewModel.clearSearch()
                        }
                    }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                } else if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            clearSearch()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            )
            .padding(.horizontal, 16)
            
            // Control buttons with loading indicators
            HStack(spacing: 16) {
                // Home button with loading state
                Button(action: {
                    heavyFeedback.impactOccurred()
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Home")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("Nutrition Only")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.green.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(.green.opacity(0.3), lineWidth: 1)
                        )
                )
                
                let currentZoom = viewModel.region.span.latitudeDelta
                let zoomInfo = getZoomLevelInfo(currentZoom)
                
                HStack(spacing: 4) {
                    Image(systemName: zoomInfo.icon)
                        .font(.system(size: 10))
                        .foregroundColor(zoomInfo.color)
                    Text(zoomInfo.label)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(zoomInfo.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(zoomInfo.color.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(zoomInfo.color.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Search results indicator with enhanced loading
                if viewModel.showSearchResults {
                    HStack(spacing: 6) {
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                        }
                        
                        let totalRestaurantCount = viewModel.restaurantsWithinSearchRadius.count
                        let nutritionRestaurantCount = viewModel.restaurantsWithinSearchRadius.filter { restaurant in
                            RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
                        }.count
                        
                        Text(isSearching ? "Searching..." : "\(totalRestaurantCount) restaurants (\(nutritionRestaurantCount) with nutrition)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                        
                        if !isSearching {
                            Button(action: {
                                viewModel.clearSearch()
                                clearSearch()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.blue.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Location button with loading state
                Button(action: {
                    heavyFeedback.impactOccurred()
                    centerOnUserLocation()
                }) {
                    if viewModel.isLoadingRestaurants {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
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
                .disabled(viewModel.isLoadingRestaurants)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 75) // Account for safe area
    }
    
    // MARK: - Restaurant Detail Overlay
    private var restaurantDetailOverlay: some View {
        Group {
            if viewModel.showingRestaurantDetail, let restaurant = viewModel.selectedRestaurant {
                RestaurantDetailView(
                    restaurant: restaurant,
                    isPresented: $viewModel.showingRestaurantDetail,
                    selectedCategory: nil
                )
                .ignoresSafeArea(.all)
                .zIndex(100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showingRestaurantDetail)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func setupInitialLocation() {
        locationManager.requestLocationPermission()
        
        if let location = locationManager.lastLocation, viewModel.restaurants.isEmpty {
            initializeWithLocation(location.coordinate)
        } else if !viewModel.restaurants.isEmpty {
            // If data already exists, just center the map without reloading
            if let location = locationManager.lastLocation {
                withAnimation(.easeInOut(duration: 1.0)) {
                    viewModel.region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
            }
            isLoadingView = false
        }
    }
    
    private func handleLocationChange(_ location: CLLocation?) {
        // Only update the location annotation, don't move the map view
        guard let location = location else { return }
        
        // Only initialize if this is the very first location and we don't have a proper region set
        if viewModel.region.center.latitude == 0 && viewModel.region.center.longitude == 0 {
            initializeWithLocation(location.coordinate)
        }
        
        // Otherwise just let the location annotation update without moving the map
    }
    
    private func initializeWithLocation(_ coordinate: CLLocationCoordinate2D) {
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 1.0)) {
                self.viewModel.region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
            self.viewModel.refreshData(for: coordinate)
        }
    }
    
    private func centerOnUserLocation() {
        guard let location = locationManager.lastLocation else { return }
        
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 1.0)) {
                self.viewModel.region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
            self.viewModel.refreshData(for: location.coordinate)
        }
    }
    
    private func performSearch() {
        Task { @MainActor in
            self.viewModel.performSearch(query: searchText, maxDistance: nil)
        }
    }
    
    private func clearSearch() {
        Task { @MainActor in
            self.searchText = ""
            self.viewModel.clearSearch()
        }
    }
    
    // PERFORMANCE: Move region updates to onChange to avoid state changes during render
    private func updateRegionAsync(_ newRegion: MKCoordinateRegion) {
        // Cancel previous update task
        regionUpdateTask?.cancel()
        
        regionUpdateTask = Task { @MainActor in
            // Debounce: wait 100ms before processing
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            guard !Task.isCancelled else { return }
            
            var constrainedRegion = newRegion
            
            // IMPROVED: Better zoom constraints for smoother experience
            if constrainedRegion.span.latitudeDelta > maxZoomOutLevel {
                constrainedRegion.span.latitudeDelta = maxZoomOutLevel
            }
            if constrainedRegion.span.longitudeDelta > maxZoomOutLevel {
                constrainedRegion.span.longitudeDelta = maxZoomOutLevel
            }
            
            // SMOOTHER: Reduce sensitivity threshold for smoother updates
            let latDiff = abs(viewModel.region.center.latitude - constrainedRegion.center.latitude)
            let lonDiff = abs(viewModel.region.center.longitude - constrainedRegion.center.longitude)
            let movement = latDiff + lonDiff
            
            // IMPROVED: More sensitive movement detection for smoother map updates
            if movement > 0.0001 { // ~10 meters - more sensitive for smoother updates
                viewModel.updateRegion(constrainedRegion)
                // Invalidate cache when region changes significantly
                if movement > 0.005 {
                    cacheTimestamp = Date.distantPast
                }
            } else {
                // Always update the region for zoom changes to ensure smooth zooming
                viewModel.region = constrainedRegion
                // Invalidate cache when zoom changes significantly
                let zoomDiff = abs(viewModel.region.span.latitudeDelta - constrainedRegion.span.latitudeDelta)
                if zoomDiff > 0.01 {
                    cacheTimestamp = Date.distantPast
                }
            }
        }
    }
    
    // PERFORMANCE: Background filtering moved to onChange
    private func updateFilteredRestaurantsCache(for region: MKCoordinateRegion) {
        // Cancel any existing filter task
        filterTask?.cancel()
        
        filterTask = Task.detached {
            let center = region.center
            let zoom = region.span.latitudeDelta
            let now = Date()
            
            // Check if cache is still valid
            let centerDiff = abs(center.latitude - await MainActor.run { self.lastCachedCenter.latitude }) +
                            abs(center.longitude - await MainActor.run { self.lastCachedCenter.longitude })
            let zoomDiff = abs(zoom - await MainActor.run { self.lastCachedZoom })
            let timeDiff = now.timeIntervalSince(await MainActor.run { self.cacheTimestamp })
            
            let isCacheValid = centerDiff < 0.005 && zoomDiff < 0.02 && timeDiff < 2.0
            
            guard !isCacheValid else { return }
            
            // Get restaurants to show
            let restaurantsToShow = await MainActor.run {
                if self.viewModel.hasActiveRadiusFilter || self.viewModel.showSearchResults {
                    return self.viewModel.restaurantsWithinSearchRadius
                } else {
                    return self.viewModel.allAvailableRestaurants
                }
            }
            
            // Compute filtered restaurants in background
            let filtered = await self.computeFilteredRestaurants(
                from: restaurantsToShow,
                center: center,
                zoom: zoom
            )
            
            // Update cache on main actor
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.cachedFilteredRestaurants = filtered
                self.lastCachedZoom = zoom
                self.lastCachedCenter = center
                self.cacheTimestamp = now
            }
        }
    }
    
    // PERFORMANCE: Background computation of filtered restaurants
    private func computeFilteredRestaurants(
        from restaurantList: [Restaurant],
        center: CLLocationCoordinate2D,
        zoom: CLLocationDegrees
    ) async -> [Restaurant] {
        
        // Always show search results regardless of zoom level
        if await MainActor.run({ viewModel.showSearchResults }) {
            return restaurantList.sorted { r1, r2 in
                let d1 = pow(r1.latitude - center.latitude, 2) + pow(r1.longitude - center.longitude, 2)
                let d2 = pow(r2.latitude - center.latitude, 2) + pow(r2.longitude - center.longitude, 2)
                return d1 < d2
            }.prefix(50).map { $0 } // PERFORMANCE: Reduced from 100 to 50
        }
        
        // PERFORMANCE: Progressive loading with reduced counts
        let restaurantsToShow: [Restaurant]
        let maxCount: Int
        
        if zoom >= zoomLevels.minimal {
            // MINIMAL: At max zoom out - show only top 10 chains
            maxCount = 10
            restaurantsToShow = await getTopPriorityRestaurantsAsync(from: restaurantList, center: center, count: 10)
        } else if zoom >= zoomLevels.moderate {
            // MODERATE: Medium zoom - show top 20 restaurants
            maxCount = 20
            restaurantsToShow = await getTopPriorityRestaurantsAsync(from: restaurantList, center: center, count: 20)
        } else if zoom >= zoomLevels.detailed {
            // DETAILED: Zoomed in - show top 35 restaurants
            maxCount = 35
            restaurantsToShow = await getMixedPriorityRestaurantsAsync(from: restaurantList, center: center, count: 35)
        } else {
            // FULL: Very zoomed in - show up to 50 restaurants (REDUCED from 100)
            maxCount = 50
            restaurantsToShow = restaurantList.sorted { r1, r2 in
                // Sort by combination of distance and priority
                let d1 = pow(r1.latitude - center.latitude, 2) + pow(r1.longitude - center.longitude, 2)
                let d2 = pow(r2.latitude - center.latitude, 2) + pow(r2.longitude - center.longitude, 2)
                
                let priority1 = getChainPriority(r1.name)
                let priority2 = getChainPriority(r2.name)
                
                // Prioritize restaurants with nutrition data first
                let r1HasNutrition = RestaurantData.restaurantsWithNutritionData.contains(r1.name)
                let r2HasNutrition = RestaurantData.restaurantsWithNutritionData.contains(r2.name)
                
                if r1HasNutrition != r2HasNutrition {
                    return r1HasNutrition
                }
                
                // Then by chain priority
                if priority1 != priority2 {
                    return priority1 < priority2
                }
                return d1 < d2
            }
        }
        
        return Array(restaurantsToShow.prefix(maxCount))
    }
    
    // PERFORMANCE: Async version of getTopPriorityRestaurants
    private func getTopPriorityRestaurantsAsync(from restaurants: [Restaurant], center: CLLocationCoordinate2D, count: Int) async -> [Restaurant] {
        // Group by chain name and keep only the closest location for each chain
        var chainMap: [String: Restaurant] = [:]
        
        for restaurant in restaurants {
            if let existingRestaurant = chainMap[restaurant.name] {
                let existingDistance = pow(existingRestaurant.latitude - center.latitude, 2) +
                                     pow(existingRestaurant.longitude - center.longitude, 2)
                let newDistance = pow(restaurant.latitude - center.latitude, 2) +
                                pow(restaurant.longitude - center.longitude, 2)
                
                if newDistance < existingDistance {
                    chainMap[restaurant.name] = restaurant
                }
            } else {
                chainMap[restaurant.name] = restaurant
            }
        }
        
        // Sort by nutrition data availability first, then chain priority, then distance
        return Array(chainMap.values).sorted { r1, r2 in
            let r1HasNutrition = RestaurantData.restaurantsWithNutritionData.contains(r1.name)
            let r2HasNutrition = RestaurantData.restaurantsWithNutritionData.contains(r2.name)
            
            // Nutrition restaurants first
            if r1HasNutrition != r2HasNutrition {
                return r1HasNutrition
            }
            
            let priority1 = getChainPriority(r1.name)
            let priority2 = getChainPriority(r2.name)
            
            if priority1 != priority2 {
                return priority1 < priority2 // Lower index = higher priority
            }
            
            let d1 = pow(r1.latitude - center.latitude, 2) + pow(r1.longitude - center.longitude, 2)
            let d2 = pow(r2.latitude - center.latitude, 2) + pow(r2.longitude - center.longitude, 2)
            return d1 < d2
        }
    }
    
    // PERFORMANCE: Async version of getMixedPriorityRestaurants
    private func getMixedPriorityRestaurantsAsync(from restaurants: [Restaurant], center: CLLocationCoordinate2D, count: Int) async -> [Restaurant] {
        
        // Separate restaurants with nutrition data from others
        let nutritionRestaurants = restaurants.filter { restaurant in
            RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
        }
        let otherRestaurants = restaurants.filter { restaurant in
            !RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
        }
        
        // Get priority chains with nutrition data
        let priorityChains = nutritionRestaurants.filter { topPriorityChains.contains($0.name) }
        let otherNutritionRestaurants = nutritionRestaurants.filter { !topPriorityChains.contains($0.name) }
        
        // Get best priority chains (deduplicated)
        let topChainsFiltered = await getTopPriorityRestaurantsAsync(from: priorityChains, center: center, count: min(12, count))
        
        // Get closest other nutrition restaurants
        let otherNutritionSorted = otherNutritionRestaurants.sorted { r1, r2 in
            let d1 = pow(r1.latitude - center.latitude, 2) + pow(r1.longitude - center.longitude, 2)
            let d2 = pow(r2.latitude - center.latitude, 2) + pow(r2.longitude - center.longitude, 2)
            return d1 < d2
        }
        
        // Get closest restaurants without nutrition data
        let otherRestaurantsSorted = otherRestaurants.sorted { r1, r2 in
            let d1 = pow(r1.latitude - center.latitude, 2) + pow(r1.longitude - center.longitude, 2)
            let d2 = pow(r2.latitude - center.latitude, 2) + pow(r2.longitude - center.longitude, 2)
            return d1 < d2
        }
        
        // Mix them: 40% priority chains, 30% other nutrition restaurants, 30% all other restaurants
        let chainCount = min(topChainsFiltered.count, Int(Double(count) * 0.4))
        let nutritionCount = min(otherNutritionSorted.count, Int(Double(count) * 0.3))
        let otherCount = count - chainCount - nutritionCount
        
        var result = Array(topChainsFiltered.prefix(chainCount))
        result.append(contentsOf: Array(otherNutritionSorted.prefix(nutritionCount)))
        result.append(contentsOf: Array(otherRestaurantsSorted.prefix(otherCount)))
        
        return result
    }
    
    private func getChainPriority(_ chainName: String) -> Int {
        // Return index in topPriorityChains array (lower = higher priority)
        return topPriorityChains.firstIndex(of: chainName) ?? Int.max
    }
    
    private func formatSearchRadius(_ radius: Double) -> String {
        if radius == floor(radius) {
            return "\(Int(radius))mi"
        } else {
            return String(format: "%.1fmi", radius)
        }
    }
    
    private func getZoomLevelInfo(_ currentZoom: CLLocationDegrees) -> (icon: String, label: String, color: Color) {
        // IMPROVED: Show current max zoom out level as "Minimal"
        if currentZoom >= zoomLevels.minimal {
            return ("star.fill", "Minimal", .orange) // At max zoom out
        } else if currentZoom >= zoomLevels.moderate {
            return ("crown.fill", "Top 25", .purple)
        } else if currentZoom >= zoomLevels.detailed {
            return ("location.fill", "Best 50", .blue)
        } else {
            return ("map.fill", "All Available", .green)
        }
    }
    
    private func getMostAvailableChains(from restaurants: [Restaurant]) -> [String] {
        // Count frequency of each chain in the current area
        var chainCounts: [String: Int] = [:]
        
        for restaurant in restaurants {
            if RestaurantData.restaurantsWithNutritionData.contains(restaurant.name) {
                chainCounts[restaurant.name, default: 0] += 1
            }
        }
        
        // Sort by frequency and return top chains
        return chainCounts
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }
}

// MARK: - Enhanced User Location with proper centering
struct UserLocationAnnotationView: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Outer pulsing circle - properly anchored to center
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 20, height: 20)
                .scaleEffect(isPulsing ? 2.0 : 1.0)
                .opacity(isPulsing ? 0.0 : 0.6)
                .animation(
                    .easeOut(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: isPulsing
                )
            
            // Inner solid circle - always perfectly centered
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        }
        .frame(width: 40, height: 40) // Fixed container prevents any drift
        .position(x: 20, y: 20) // Explicitly center within the frame
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Optimized annotation view with reduced complexity
struct OptimizedRestaurantAnnotationView: View {
    let restaurant: Restaurant
    let hasNutritionData: Bool
    let isSelected: Bool
    let onTap: (Restaurant) -> Void
    
    var body: some View {
        Button(action: { onTap(restaurant) }) {
            ZStack {
                // Background circle - simplified design for better performance
                Circle()
                    .fill(backgroundColor)
                    .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                    )
                    .shadow(color: .black.opacity(0.3), radius: isSelected ? 6 : 3, y: isSelected ? 3 : 1)
                
                // Simple icon - no complex SF Symbols for better performance
                Circle()
                    .fill(Color.white)
                    .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        if hasNutritionData {
            return restaurant.amenityType == "fast_food" ? .orange : .blue
        } else {
            return restaurant.amenityType == "fast_food" ? .red : .gray
        }
    }
}

// MARK: - Supporting Views

struct NoLocationView: View {
    let title: String
    let subtitle: String
    let buttonText: String
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            // UPDATED: Match HomeScreen background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) { // Increased spacing for better layout
                Spacer()
                
                // UPDATED: More prominent icon with consistent styling
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "location.slash")
                        .font(.system(size: 48, weight: .medium)) // More consistent with HomeScreen
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded)) // Match HomeScreen font style
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary) // Use primary color for better readability
                        .padding(.horizontal)
                        
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded)) // Match HomeScreen font style
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                }
                
                // UPDATED: Match HomeScreen button styling
                Button(action: onRetry) {
                    Text(buttonText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded)) // Match HomeScreen button font
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
                        .cornerRadius(20) // Match HomeScreen button corner radius
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4) // Match HomeScreen shadow
                }
                
                Spacer()
            }
        }
    }
}

enum MapItem: Identifiable {
    case userLocation(CLLocationCoordinate2D)
    case restaurant(Restaurant)

    var id: AnyHashable {
        switch self {
        case .userLocation(let coordinate): return "user_\(coordinate.latitude)_\(coordinate.longitude)"
        case .restaurant(let r): return r.id
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .userLocation(let coordinate): return coordinate
        case .restaurant(let r): return CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude)
        }
    }
}

#Preview {
    MapScreen(viewModel: MapViewModel())
}
