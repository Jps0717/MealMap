import SwiftUI
import MapKit
import CoreLocation

// MARK: - Enhanced Map View with Immediate Restaurant Detail on Pin Tap
struct EnhancedMapView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    // Callback functions
    let onSearch: () -> Void
    let onClearSearch: () -> Void
    let onDismiss: () -> Void
    
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    @State private var showZoomInNotification = false
    @State private var currentZoomLevel: CLLocationDegrees = 0.01
    @State private var notificationTimer: Timer?

    var body: some View {
        ZStack {
            // Enhanced map with immediate detail view on pin tap
            SimplifiedRealTimeMapView(viewModel: viewModel, onZoomLevelChange: { zoomLevel in
                // FIXED: Defer state changes to avoid "modifying state during view update"
                DispatchQueue.main.async {
                    handleZoomLevelChange(zoomLevel)
                }
            }) { restaurant in
                selectRestaurant(restaurant)
            }
            .ignoresSafeArea()
            
            // Header overlay
            VStack {
                MapHeaderView(
                    searchText: $searchText,
                    isSearching: $isSearching,
                    viewModel: viewModel,
                    onSearch: onSearch,
                    onClearSearch: onClearSearch,
                    onDismiss: onDismiss,
                    onCenterLocation: {
                        centerOnUserLocation()
                    }
                )
                Spacer()
            }
            
            // Zoom In Notification Popup - CENTERED AND SQUARE
            VStack {
                Spacer()
                
                if showZoomInNotification {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Zoom in to see restaurants")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Pinch to zoom or double-tap for restaurant pins")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: {
                            centerOnUserLocation()
                            dismissNotification()
                        }) {
                            Text("Zoom In")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    )
                    .padding(.horizontal, 40)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                Spacer()
            }
            
            // Loading indicator - CENTERED
            if viewModel.isLoadingRestaurants {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                            
                            VStack(spacing: 8) {
                                Text("Loading restaurants...")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                // Beta disclaimer
                                HStack(spacing: 6) {
                                    Text("BETA")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.orange)
                                        )
                                    
                                    Text("Not all restaurants available")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
                        )
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            // Bottom right buttons - Fresh button only
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // Fresh/Refresh button
                        Button(action: {
                            debugLog(" User tapped FRESH location refresh")
                            LocationManager.shared.refreshCurrentLocation()
                            
                            // Wait a moment then refresh restaurants
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if let userLocation = LocationManager.shared.lastLocation?.coordinate {
                                    debugLog(" Forcing fresh restaurant data for: \(userLocation)")
                                    Task {
                                        await viewModel.fetchRestaurantsForCurrentRegion()
                                    }
                                }
                            }
                            
                            // Also center the map
                            centerOnUserLocation()
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
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
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showingRestaurantDetail) {
            if let restaurant = selectedRestaurant {
                RestaurantDetailView(
                    restaurant: restaurant,
                    isPresented: $showingRestaurantDetail,
                    selectedCategory: nil
                )
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            notificationTimer?.invalidate()
            notificationTimer = nil
        }
    }
    
    // FIXED: Separate function to handle zoom level changes safely
    private func handleZoomLevelChange(_ zoomLevel: CLLocationDegrees) {
        currentZoomLevel = zoomLevel
        
        let isZoomedOutTooFar = zoomLevel > 0.02
        
        if isZoomedOutTooFar && !showZoomInNotification {
            showNotification()
        } else if !isZoomedOutTooFar && showZoomInNotification {
            dismissNotification()
        }
    }
    
    private func showNotification() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showZoomInNotification = true
        }
        
        // Cancel any existing timer
        notificationTimer?.invalidate()
        
        // Auto-hide after 4 seconds
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            dismissNotification()
        }
    }
    
    private func dismissNotification() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showZoomInNotification = false
        }
        
        notificationTimer?.invalidate()
        notificationTimer = nil
    }
    
    private func selectRestaurant(_ restaurant: Restaurant) {
        debugLog(" Pin tapped: \(restaurant.name) - Opening detail view immediately")
        selectedRestaurant = restaurant
        showingRestaurantDetail = true
    }
    
    private func centerOnUserLocation() {
        if let userLocation = LocationManager.shared.lastLocation?.coordinate {
            withAnimation(.easeInOut(duration: 1.0)) {
                viewModel.region = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }
}

// MARK: - Enhanced Real-Time Map with Immediate Pin Tap Response
struct SimplifiedRealTimeMapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    let onZoomLevelChange: (CLLocationDegrees) -> Void
    let onRestaurantTap: (Restaurant) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsUserLocation = true  // Enable built-in user location
        mapView.userTrackingMode = .none
        
        // DISABLE ALL APPLE MAPS POINTS OF INTEREST
        mapView.pointOfInterestFilter = .excludingAll
        
        // Disable unnecessary features for performance
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // Set initial region
        mapView.setRegion(viewModel.region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if needed
        let currentRegion = mapView.region
        let newRegion = viewModel.region
        
        // Only update if there's a significant change (increased threshold)
        if abs(currentRegion.center.latitude - newRegion.center.latitude) > 0.005 ||
           abs(currentRegion.center.longitude - newRegion.center.longitude) > 0.005 ||
           abs(currentRegion.span.latitudeDelta - newRegion.span.latitudeDelta) > 0.005 {
            mapView.setRegion(newRegion, animated: true)
        }
        
        // Update annotations using the correct property
        let restaurantsToShow = viewModel.showSearchResults ? viewModel.filteredRestaurants : viewModel.allAvailableRestaurants
        context.coordinator.updateAnnotations(mapView: mapView, restaurants: restaurantsToShow)
    }
    
    private func constrainRegionToZoomLimits(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        var constrainedRegion = region
        
        // Constrain latitude delta (vertical zoom)
        if constrainedRegion.span.latitudeDelta > 0.5 {
            constrainedRegion.span.latitudeDelta = 0.5
        } else if constrainedRegion.span.latitudeDelta < 0.001 {
            constrainedRegion.span.latitudeDelta = 0.001
        }
        
        // Constrain longitude delta (horizontal zoom)
        if constrainedRegion.span.longitudeDelta > 0.5 {
            constrainedRegion.span.longitudeDelta = 0.5
        } else if constrainedRegion.span.longitudeDelta < 0.001 {
            constrainedRegion.span.longitudeDelta = 0.001
        }
        
        return constrainedRegion
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: SimplifiedRealTimeMapView
        private var debounceTimer: Timer?
        
        init(_ parent: SimplifiedRealTimeMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // ENHANCED: Apply zoom constraints to new region before processing
            let constrainedRegion = parent.constrainRegionToZoomLimits(mapView.region)
            
            // Update the map if constraints were applied
            if mapView.region.span.latitudeDelta != constrainedRegion.span.latitudeDelta ||
               mapView.region.span.longitudeDelta != constrainedRegion.span.longitudeDelta {
                mapView.setRegion(constrainedRegion, animated: true)
            }
            
            // FIXED: Defer zoom level change notification to avoid state modification during view update
            let currentSpan = constrainedRegion.span.latitudeDelta
            DispatchQueue.main.async { [weak self] in
                self?.parent.onZoomLevelChange(currentSpan)
            }
            
            // FIXED: Debounce map region changes to prevent constant refreshing
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                
                // ENHANCED: Check if we should show/hide pins based on zoom level
                let shouldShowPins = currentSpan <= 0.02
                
                if shouldShowPins {
                    // Only fetch restaurants when zoomed in enough to show pins
                    Task.detached(priority: .utility) { [weak self] in
                        guard let self = self else { return }
                        await self.parent.viewModel.fetchRestaurantsForMapRegion(mapView.region)
                    }
                }
            }
            
            // Update view model region immediately for UI consistency
            Task.detached(priority: .utility) { [weak self] in
                guard let self = self else { return }
                await MainActor.run {
                    self.parent.viewModel.region = constrainedRegion
                }
            }
        }
        
        // ENHANCED: Create tappable pins without callouts
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil // Use default user location view
            }
            
            if let restaurantAnnotation = annotation as? RestaurantMapAnnotation {
                return createCustomRestaurantView(for: restaurantAnnotation, in: mapView)
            }
            
            // Hide all other annotations (Apple Maps POIs)
            return MKAnnotationView()
        }
        
        private func createCustomRestaurantView(for annotation: RestaurantMapAnnotation, in mapView: MKMapView) -> MKAnnotationView {
            let restaurant = annotation.restaurant
            let identifier = "CustomRestaurant_\(restaurant.hasNutritionData ? "Nutrition" : "Basic")"
            
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if view == nil {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                
                // Create SwiftUI view and convert to UIView
                let restaurantPin = RestaurantPin(
                    restaurant: restaurant,
                    isSelected: false,
                    onTap: {
                        // Handle tap through the coordinator
                        self.parent.onRestaurantTap(restaurant)
                    }
                )
                
                let hostingController = UIHostingController(rootView: restaurantPin)
                hostingController.view.backgroundColor = UIColor.clear
                
                // Set the size to match your custom pin size
                hostingController.view.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
                
                // Add to annotation view
                view?.addSubview(hostingController.view)
                
                // Center the pin
                view?.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
                view?.centerOffset = CGPoint(x: 0, y: -18) // Offset to point to the location
                
                // DISABLED: No callout - direct tap interaction
                view?.canShowCallout = false
                
                // Enhanced priority for nutrition restaurants
                view?.displayPriority = restaurant.hasNutritionData ? .required : .defaultLow
            } else {
                // Update existing view with new annotation
                view?.annotation = annotation
            }
            
            return view!
        }
        
        // ENHANCED: Immediate detail view on pin tap
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // Immediately deselect to prevent selection state
            mapView.deselectAnnotation(view.annotation, animated: false)
            
            // Open restaurant detail immediately
            if let restaurantAnnotation = view.annotation as? RestaurantMapAnnotation {
                debugLog(" IMMEDIATE TAP: \(restaurantAnnotation.restaurant.name)")
                parent.onRestaurantTap(restaurantAnnotation.restaurant)
            }
        }
        
        func updateAnnotations(mapView: MKMapView, restaurants: [Restaurant]) {
            // Get current restaurant annotations (excluding user location)
            let currentRestaurantAnnotations = mapView.annotations.compactMap { $0 as? RestaurantMapAnnotation }
            let currentRestaurantIds = Set(currentRestaurantAnnotations.map { $0.restaurant.id })
            
            // Get new restaurant IDs
            let newRestaurantIds = Set(restaurants.map { $0.id })
            
            // Find annotations to remove (restaurants that are no longer in the list)
            let annotationsToRemove = currentRestaurantAnnotations.filter { annotation in
                !newRestaurantIds.contains(annotation.restaurant.id)
            }
            
            // Find restaurants to add (new restaurants not currently shown)
            let restaurantsToAdd = restaurants.filter { restaurant in
                !currentRestaurantIds.contains(restaurant.id)
            }
            
            // Only update if there are actual changes
            if !annotationsToRemove.isEmpty || !restaurantsToAdd.isEmpty {
                // Remove outdated annotations
                if !annotationsToRemove.isEmpty {
                    mapView.removeAnnotations(annotationsToRemove)
                }
                
                // Add new annotations
                if !restaurantsToAdd.isEmpty {
                    let newAnnotations = restaurantsToAdd.map { RestaurantMapAnnotation(restaurant: $0) }
                    mapView.addAnnotations(newAnnotations)
                }
                
                debugLog("🗺️ Updated annotations: removed \(annotationsToRemove.count), added \(restaurantsToAdd.count)")
            }
        }
        
        deinit {
            debounceTimer?.invalidate()
        }
    }
}

// MARK: - Map Annotations
class RestaurantMapAnnotation: NSObject, MKAnnotation {
    let restaurant: Restaurant
    
    var coordinate: CLLocationCoordinate2D {
        restaurant.coordinate
    }
    
    var title: String? {
        restaurant.name
    }
    
    var subtitle: String? {
        if restaurant.hasNutritionData {
            return "Nutrition data available"
        } else {
            return restaurant.amenityType?.capitalized ?? "Restaurant"
        }
    }
    
    init(restaurant: Restaurant) {
        self.restaurant = restaurant
    }
}