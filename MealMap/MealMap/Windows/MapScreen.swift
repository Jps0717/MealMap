import SwiftUI
import MapKit
import CoreLocation

// MARK: - Simplified MapScreen with ViewModel

struct MapScreen: View {
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var clusterManager = ClusterManager()
    @StateObject private var searchManager = SearchManager()
    
    // UI State
    @State private var searchText = ""
    
    // Haptic Feedback
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    
    // Configuration
    private let pinVisibilityThreshold: CLLocationDegrees = 0.1
    private let clusterVisibilityThreshold: CLLocationDegrees = 0.15
    
    // Computed Properties
    private var hasValidLocation: Bool {
        locationManager.lastLocation != nil &&
        (locationManager.authorizationStatus == .authorizedWhenInUse ||
         locationManager.authorizationStatus == .authorizedAlways)
    }
    
    private var mapItems: [MapItem] {
        var items: [MapItem] = []
        
        // Add custom user location pin (non-interactive)
        if let userLocation = locationManager.lastLocation {
            items.append(.userLocation(userLocation.coordinate))
        }
        
        let restaurantsToShow = viewModel.showSearchResults ?
            viewModel.filteredRestaurants : viewModel.restaurants
        
        if viewModel.showSearchResults {
            items.append(contentsOf: getFilteredRestaurantsForDisplay(from: restaurantsToShow).map { .restaurant($0) })
        } else if viewModel.region.span.latitudeDelta > clusterVisibilityThreshold {
            // Don't show anything when too zoomed out
        } else if viewModel.region.span.latitudeDelta > 0.02 {
            items.append(contentsOf: clusterManager.clusters.map { .cluster($0) })
        } else {
            items.append(contentsOf: getFilteredRestaurantsForDisplay(from: restaurantsToShow).map { .restaurant($0) })
        }
        
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
    }
    
    // MARK: - Main Map View
    private var mainMapView: some View {
        ZStack {
            Map(coordinateRegion: Binding(
                get: { viewModel.region },
                set: { viewModel.updateRegion($0) }
            ), showsUserLocation: false, annotationItems: mapItems) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    switch item {
                    case .userLocation(let coordinate):
                        UserLocationAnnotationView()
                            .allowsHitTesting(false) // Make it non-interactive
                        
                    case .cluster(let cluster):
                        ClusterAnnotationView(
                            count: cluster.count,
                            nutritionDataCount: cluster.nutritionDataCount,
                            noNutritionDataCount: cluster.noNutritionDataCount
                        )
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: clusterManager.transitionState)
                        
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
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: clusterManager.transitionState)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: []))
            .ignoresSafeArea(edges: .all)
            
            VStack {
                streamlinedHeader
                Spacer()
            }
            
            if viewModel.isLoadingRestaurants {
                VStack {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                            .padding(.trailing, 20)
                            .padding(.top, 60)
                    }
                    Spacer()
                }
            }
            
            restaurantDetailOverlay
        }
        .onReceive(viewModel.$restaurants) { restaurants in
            updateClusters(with: restaurants)
        }
        .onReceive(viewModel.$region) { region in
            updateClusters(with: viewModel.restaurants)
        }
    }
    
    // MARK: - Streamlined Header
    private var streamlinedHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))

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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            )
            .padding(.horizontal, 16)
            
            HStack(spacing: 8) {
                if !viewModel.currentAreaName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(viewModel.currentAreaName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                }
                
                if viewModel.showSearchResults {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                        Text("\(viewModel.filteredRestaurants.count) results")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                        Button(action: {
                            viewModel.clearSearch()
                            clearSearch()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                
                Spacer()
                
                Button(action: {
                    heavyFeedback.impactOccurred()
                    centerOnUserLocation()
                }) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: .blue.opacity(0.3), radius: 6, y: 3)
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .padding(.top, 75)
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
        guard let location = location else { return }
        initializeWithLocation(location.coordinate)
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
    
    private func updateClusters(with restaurants: [Restaurant]) {
        clusterManager.updateClusters(
            restaurants: restaurants,
            zoomLevel: viewModel.region.span.latitudeDelta,
            span: viewModel.region.span,
            center: viewModel.region.center,
            debounceDelay: 0.15
        )
    }
    
    private func getFilteredRestaurantsForDisplay(from restaurantList: [Restaurant]) -> [Restaurant] {
        let maxRestaurants = viewModel.showSearchResults ? 75 : 50
        let center = viewModel.region.center
        let isZoomedIn = viewModel.region.span.latitudeDelta <= pinVisibilityThreshold
        let isZoomedOutTooFar = viewModel.region.span.latitudeDelta > clusterVisibilityThreshold && !viewModel.showSearchResults
        
        guard !isZoomedOutTooFar else { return [] }
        
        if isZoomedIn || viewModel.showSearchResults {
            return restaurantList.sorted { r1, r2 in
                let d1 = pow(r1.latitude - center.latitude, 2) + pow(r1.longitude - center.longitude, 2)
                let d2 = pow(r2.latitude - center.latitude, 2) + pow(r2.longitude - center.longitude, 2)
                return d1 < d2
            }.prefix(maxRestaurants).map { $0 }
        }
        
        return restaurantList
    }
}

// MARK: - Enhanced User Location with softer design
struct UserLocationAnnotationView: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Outer pulsing circle
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: isPulsing ? 32 : 16, height: isPulsing ? 32 : 16)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0.0 : 1.0)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false), value: isPulsing)
            
            // Inner solid circle
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
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
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
            Text(subtitle)
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
            Button(action: onRetry) {
                Text(buttonText)
                    .font(.system(.headline, design: .rounded))
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
            }
            Spacer()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

enum MapItem: Identifiable {
    case userLocation(CLLocationCoordinate2D)
    case cluster(MapCluster)
    case restaurant(Restaurant)

    var id: AnyHashable {
        switch self {
        case .userLocation(let coordinate): return "user_\(coordinate.latitude)_\(coordinate.longitude)"
        case .cluster(let c): return c.id
        case .restaurant(let r): return r.id
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .userLocation(let coordinate): return coordinate
        case .cluster(let c): return c.coordinate
        case .restaurant(let r): return CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude)
        }
    }
}

#Preview {
    MapScreen()
}
