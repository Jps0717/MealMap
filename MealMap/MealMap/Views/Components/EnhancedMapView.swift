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
    
    var body: some View {
        ZStack {
            // Enhanced map with immediate detail view on pin tap
            SimplifiedRealTimeMapView(viewModel: viewModel) { restaurant in
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
            
            // Bottom right buttons - Loading indicator and Fresh button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // Loading indicator
                        if viewModel.isLoadingRestaurants {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.2)
                        }
                        
                        // Fresh/Refresh button
                        Button(action: {
                            debugLog("🔄 User tapped FRESH location refresh")
                            LocationManager.shared.refreshCurrentLocation()
                            
                            // Wait a moment then refresh restaurants
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if let userLocation = LocationManager.shared.lastLocation?.coordinate {
                                    debugLog("📍 Forcing fresh restaurant data for: \(userLocation)")
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
    }
    
    private func selectRestaurant(_ restaurant: Restaurant) {
        debugLog("🍽️ Pin tapped: \(restaurant.name) - Opening detail view immediately")
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
    let onRestaurantTap: (Restaurant) -> Void
    
    private let pinHideThreshold: CLLocationDegrees = 0.02  // Hide pins when zoomed out beyond ~22km span
    private let maxLatitudeDelta: CLLocationDegrees = 0.5  // About 55km max zoom out
    private let maxLongitudeDelta: CLLocationDegrees = 0.5 // About 55km max zoom out
    private let minLatitudeDelta: CLLocationDegrees = 0.001 // About 110m min zoom in
    private let minLongitudeDelta: CLLocationDegrees = 0.001 // About 110m min zoom in
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.userTrackingMode = .none
        mapView.mapType = .standard
        
        // Disable expensive features for better performance
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        mapView.showsPointsOfInterest = false
        mapView.pointOfInterestFilter = .excludingAll
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Only update region if it's significantly different
        let currentRegion = mapView.region
        let targetRegion = constrainRegionToZoomLimits(viewModel.region)
        
        let latDiff = abs(currentRegion.center.latitude - targetRegion.center.latitude)
        let lonDiff = abs(currentRegion.center.longitude - targetRegion.center.longitude)
        let spanDiff = abs(currentRegion.span.latitudeDelta - targetRegion.span.latitudeDelta)
        
        if latDiff > 0.001 || lonDiff > 0.001 || spanDiff > 0.001 {
            mapView.setRegion(targetRegion, animated: false)
        }
        
        // ENHANCED: Hide pins when zoomed out too far for cleaner view
        let currentSpan = mapView.region.span.latitudeDelta
        let shouldShowPins = currentSpan <= pinHideThreshold
        
        if shouldShowPins {
            // Show restaurants with nutrition data only when zoomed in enough
            let restaurantsToShow = viewModel.showSearchResults ? viewModel.filteredRestaurants : viewModel.allAvailableRestaurants
            
            let newRestaurantAnnotations = restaurantsToShow.map {
                RestaurantMapAnnotation(restaurant: $0)
            }
            
            // Clear and add annotations
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotations(newRestaurantAnnotations)
            
            debugLog("🗺️ Showing \(newRestaurantAnnotations.count) nutrition pins (zoom level: \(String(format: "%.3f", currentSpan)))")
        } else {
            // Hide all pins when zoomed out too far
            mapView.removeAnnotations(mapView.annotations)
            debugLog("🗺️ Hiding all pins - zoomed out too far (zoom level: \(String(format: "%.3f", currentSpan)) > \(pinHideThreshold))")
        }
    }
    
    private func constrainRegionToZoomLimits(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        var constrainedRegion = region
        
        // Constrain latitude delta (vertical zoom)
        if constrainedRegion.span.latitudeDelta > maxLatitudeDelta {
            constrainedRegion.span.latitudeDelta = maxLatitudeDelta
            debugLog("🔒 Max zoom out reached - latitude delta constrained to \(maxLatitudeDelta)")
        } else if constrainedRegion.span.latitudeDelta < minLatitudeDelta {
            constrainedRegion.span.latitudeDelta = minLatitudeDelta
            debugLog("🔒 Max zoom in reached - latitude delta constrained to \(minLatitudeDelta)")
        }
        
        // Constrain longitude delta (horizontal zoom)
        if constrainedRegion.span.longitudeDelta > maxLongitudeDelta {
            constrainedRegion.span.longitudeDelta = maxLongitudeDelta
            debugLog("🔒 Max zoom out reached - longitude delta constrained to \(maxLongitudeDelta)")
        } else if constrainedRegion.span.longitudeDelta < minLongitudeDelta {
            constrainedRegion.span.longitudeDelta = minLongitudeDelta
            debugLog("🔒 Max zoom in reached - longitude delta constrained to \(minLongitudeDelta)")
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
            
            // FIXED: Debounce map region changes to prevent constant refreshing
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                
                // ENHANCED: Check if we should show/hide pins based on zoom level
                let currentSpan = mapView.region.span.latitudeDelta
                let shouldShowPins = currentSpan <= self.parent.pinHideThreshold
                
                if shouldShowPins {
                    // Only fetch restaurants when zoomed in enough to show pins
                    Task.detached(priority: .utility) { [weak self] in
                        guard let self = self else { return }
                        await self.parent.viewModel.fetchRestaurantsForMapRegion(mapView.region)
                    }
                } else {
                    // Clear annotations when zoomed out too far
                    DispatchQueue.main.async {
                        mapView.removeAnnotations(mapView.annotations)
                    }
                    debugLog("🗺️ Cleared pins - zoom level too high: \(String(format: "%.3f", currentSpan))")
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
            if let restaurantAnnotation = annotation as? RestaurantMapAnnotation {
                return createTappableRestaurantView(for: restaurantAnnotation, in: mapView)
            }
            return nil
        }
        
        private func createTappableRestaurantView(for annotation: RestaurantMapAnnotation, in mapView: MKMapView) -> MKAnnotationView {
            let restaurant = annotation.restaurant
            let identifier = "TappableRestaurant_\(restaurant.hasNutritionData ? "Nutrition" : "Basic")"
            
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ??
                      MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            // Enhanced visual styling
            view.glyphText = restaurant.emoji
            view.markerTintColor = UIColor(restaurant.pinColor)
            view.glyphTintColor = .white
            
            // DISABLED: No callout - direct tap interaction
            view.canShowCallout = false
            
            // Enhanced priority for nutrition restaurants
            view.displayPriority = restaurant.hasNutritionData ? .required : .defaultLow
            
            // Enhanced visual feedback
            if restaurant.hasNutritionData {
                view.layer.shadowColor = UIColor.green.cgColor
                view.layer.shadowOffset = CGSize(width: 0, height: 2)
                view.layer.shadowRadius = 4
                view.layer.shadowOpacity = 0.3
            }
            
            return view
        }
        
        // ENHANCED: Immediate detail view on pin tap
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // Immediately deselect to prevent selection state
            mapView.deselectAnnotation(view.annotation, animated: false)
            
            // Open restaurant detail immediately
            if let restaurantAnnotation = view.annotation as? RestaurantMapAnnotation {
                debugLog("🍽️ IMMEDIATE TAP: \(restaurantAnnotation.restaurant.name)")
                parent.onRestaurantTap(restaurantAnnotation.restaurant)
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