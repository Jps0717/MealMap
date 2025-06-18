import SwiftUI
import MapKit
import CoreLocation

// MARK: - Simplified MapScreen with ViewModel

struct MapScreen: View {
    @ObservedObject var viewModel: MapViewModel
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var searchManager = SearchManager()
    
    // UI State - Reduced state variables
    @State private var searchText = ""
    @State private var lastRegionUpdate = Date.distantPast
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingHomeScreen = false
    
    init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }
    
    // Haptic Feedback
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    
    // Configuration - Optimized for instant response
    private let pinVisibilityThreshold: CLLocationDegrees = 0.08
    private let maxZoomOutLevel: CLLocationDegrees = 0.08
    
    // Computed Properties
    private var hasValidLocation: Bool {
        locationManager.lastLocation != nil &&
        (locationManager.authorizationStatus == .authorizedWhenInUse ||
         locationManager.authorizationStatus == .authorizedAlways)
    }
    
    private var mapItems: [MapItem] {
        var items: [MapItem] = []
        
        // Add user location
        if let userLocation = locationManager.lastLocation {
            items.append(.userLocation(userLocation.coordinate))
        }
        
        // SIMPLIFIED: Always use radius-filtered restaurants when radius filter is active
        let restaurantsToShow: [Restaurant]
        
        if viewModel.hasActiveRadiusFilter || viewModel.showSearchResults {
            // Use radius-filtered restaurants (this will continuously apply radius filter)
            restaurantsToShow = viewModel.restaurantsWithinSearchRadius
        } else {
            // Normal browsing - show all available restaurants
            restaurantsToShow = viewModel.allAvailableRestaurants
        }
        
        items.append(contentsOf: getFilteredRestaurantsForDisplay(from: restaurantsToShow).map { .restaurant($0) })
        
        return items
    }
    
    var body: some View {
        ZStack {
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
                NoLocationView(
                    title: "No Location Found",
                    subtitle: "MealMap needs your location to find restaurants near you.",
                    buttonText: "Request Location",
                    onRetry: {
                        locationManager.requestLocationPermission()
                    }
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
            } else {
                mainMapView
            }
        }
        .preferredColorScheme(.light)
        .navigationBarHidden(true)
        .onAppear {
            setupInitialLocation()
        }
        .onChange(of: locationManager.lastLocation) { oldLocation, newLocation in
            handleLocationChange(newLocation)
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
    
    // MARK: - Main Map View - Always Interactive
    private var mainMapView: some View {
        ZStack {
            // Map layer - ALWAYS fully interactive with zoom limits
            Map(coordinateRegion: Binding(
                get: { viewModel.region },
                set: { newRegion in
                    var constrainedRegion = newRegion
                    if constrainedRegion.span.latitudeDelta > maxZoomOutLevel {
                        constrainedRegion.span.latitudeDelta = maxZoomOutLevel
                    }
                    if constrainedRegion.span.longitudeDelta > maxZoomOutLevel {
                        constrainedRegion.span.longitudeDelta = maxZoomOutLevel
                    }
                    
                    let latDiff = abs(viewModel.region.center.latitude - constrainedRegion.center.latitude)
                    let lonDiff = abs(viewModel.region.center.longitude - constrainedRegion.center.longitude)
                    let movement = latDiff + lonDiff
                    
                    if movement > 0.0005 { // ~50 meters - very sensitive
                        viewModel.updateRegion(constrainedRegion)
                    } else {
                        // Still update the region for zoom changes
                        viewModel.region = constrainedRegion
                    }
                }
            ), showsUserLocation: false, annotationItems: mapItems) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    switch item {
                    case .userLocation(_):
                        UserLocationAnnotationView()
                            .allowsHitTesting(false)
                        
                    case .restaurant(let restaurant):
                        RestaurantAnnotationView(
                            restaurant: restaurant,
                            hasNutritionData: RestaurantData.restaurantsWithNutritionData.contains(restaurant.name),
                            isSelected: viewModel.selectedRestaurant?.id == restaurant.id,
                            onTap: { tappedRestaurant in
                                viewModel.selectRestaurant(tappedRestaurant)
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedRestaurant?.id)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: []))
            .ignoresSafeArea(edges: .all)
            .disabled(false) // Explicitly ensure map is never disabled
            
            // UI overlays that DON'T block map interaction
            VStack {
                // UPDATED: Enhanced header with reorganized layout
                enhancedHeader
                    .allowsHitTesting(true) // Allow header interactions
                Spacer()
            }
            
            // Non-blocking loading indicator - positioned to not interfere
            if viewModel.isLoadingRestaurants {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        // UPDATED: Loading indicator with HomeScreen-consistent styling
                        ZStack {
                            Circle()
                                .stroke(Color(.systemBackground).opacity(0.8), lineWidth: 3) // More visible background
                                .frame(width: 40, height: 40) // Slightly larger for better visibility
                            
                            Circle()
                                .trim(from: 0, to: viewModel.loadingProgress)
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.3), value: viewModel.loadingProgress)
                            
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 30, height: 30)
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2) // Consistent shadow
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 120) // Position above restaurant detail area
                    }
                }
                .allowsHitTesting(false) // Critical: Don't block ANY interactions
                .zIndex(2) // Keep below search radius but above map
            }
            
            restaurantDetailOverlay
                .zIndex(100) // Keep restaurant detail on top
        }
        .allowsHitTesting(true) // Ensure the entire ZStack allows interactions
    }
    
    // MARK: - Enhanced Header with Reorganized Layout
    private var enhancedHeader: some View {
        VStack(spacing: 16) {
            // Search bar at the top - UPDATED: Match HomeScreen styling
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18)) // Match HomeScreen font size

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

                if !searchText.isEmpty {
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
            .padding(.horizontal, 20) // Match HomeScreen padding
            .padding(.vertical, 16) // Match HomeScreen padding
            .background(
                RoundedRectangle(cornerRadius: 16) // Match HomeScreen corner radius
                    .fill(Color(.systemBackground)) // Match HomeScreen background
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2) // Match HomeScreen shadow
            )
            .padding(.horizontal, 16)
            
            // UPDATED: Control buttons with consistent HomeScreen styling
            HStack(spacing: 16) {
                // Home button - UPDATED: Match HomeScreen Map button styling but with green color
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
                
                // Search results indicator - UPDATED: Match HomeScreen capsule styling
                if viewModel.showSearchResults {
                    HStack(spacing: 6) { // Increased spacing for better readability
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12)) // Slightly larger icon
                        Text("\(viewModel.restaurantsWithinSearchRadius.count) results")
                            .font(.system(size: 12, weight: .medium, design: .rounded)) // Larger, readable text
                        
                        Button(action: {
                            viewModel.clearSearch()
                            clearSearch()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
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
                
                // Location button - UPDATED: Match HomeScreen button sizing and style
                Button(action: {
                    heavyFeedback.impactOccurred()
                    centerOnUserLocation()
                }) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .medium))
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
                    isPresented: $viewModel.showingRestaurantDetail
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
        
        if let location = locationManager.lastLocation {
            initializeWithLocation(location.coordinate)
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
        withAnimation(.easeInOut(duration: 1.0)) {
            viewModel.region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        viewModel.refreshData(for: coordinate)
    }
    
    private func centerOnUserLocation() {
        guard let location = locationManager.lastLocation else { return }
        
        withAnimation(.easeInOut(duration: 1.0)) {
            viewModel.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        viewModel.refreshData(for: location.coordinate)
    }
    
    private func performSearch() {
        viewModel.performSearch(query: searchText, maxDistance: nil)
    }
    
    private func clearSearch() {
        searchText = ""
        viewModel.clearSearch()
    }
    
    private func getFilteredRestaurantsForDisplay(from restaurantList: [Restaurant]) -> [Restaurant] {
        let maxRestaurants = viewModel.showSearchResults ? 100 : 75
        let center = viewModel.region.center
        let isZoomedIn = viewModel.region.span.latitudeDelta <= pinVisibilityThreshold
        
        // Always show search results regardless of zoom level
        if viewModel.showSearchResults {
            // When showing search results, always display them regardless of zoom level
            return restaurantList.sorted { r1, r2 in
                let d1 = pow(r1.latitude - center.latitude, 2) + pow(r1.longitude - center.longitude, 2)
                let d2 = pow(r2.latitude - center.latitude, 2) + pow(r2.longitude - center.longitude, 2)
                return d1 < d2
            }.prefix(maxRestaurants).map { $0 }
        }
        
        // For regular browsing (not search), apply zoom limitations
        let isZoomedOutTooFar = viewModel.region.span.latitudeDelta > 0.15
        guard !isZoomedOutTooFar else { return [] }
        
        if isZoomedIn {
            // OPTIMIZED: More efficient distance calculation
            return restaurantList.sorted { r1, r2 in
                let d1 = pow(r1.latitude - center.latitude, 2) + pow(r1.longitude - center.longitude, 2)
                let d2 = pow(r2.latitude - center.latitude, 2) + pow(r2.longitude - center.longitude, 2)
                return d1 < d2
            }.prefix(maxRestaurants).map { $0 }
        }
        
        return Array(restaurantList.prefix(maxRestaurants))
    }
    
    private func formatSearchRadius(_ radius: Double) -> String {
        if radius == floor(radius) {
            return "\(Int(radius))mi"
        } else {
            return String(format: "%.1fmi", radius)
        }
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
