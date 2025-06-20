import SwiftUI
import MapKit
import CoreLocation

// MARK: - Enhanced Map View with Real-time Loading
struct EnhancedMapView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    let onDismiss: () -> Void
    let onSearch: () -> Void
    let onClearSearch: () -> Void
    
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    @State private var showSearchErrorAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Enhanced MapKit view with real-time loading
                RealTimeMapView(viewModel: viewModel) { restaurant in
                    selectRestaurant(restaurant)
                }
                .ignoresSafeArea()
                
                // Header overlay
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
                
                // Bottom right loading indicator
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        if viewModel.isLoadingRestaurants {
                            SpinningMapIndicator()
                                .padding(.trailing, 20)
                                .padding(.bottom, 20) // Moved lower from 30 to 20
                        }
                    }
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
        .alert("Search Error", isPresented: $showSearchErrorAlert) {
            Button("OK") {
                showSearchErrorAlert = false
                viewModel.showSearchError = false
            }
        } message: {
            Text(viewModel.searchErrorMessage ?? "An error occurred")
        }
        .onChange(of: viewModel.showSearchError) { _, newValue in
            showSearchErrorAlert = newValue
        }
    }
    
    private func selectRestaurant(_ restaurant: Restaurant) {
        selectedRestaurant = restaurant
        showingRestaurantDetail = true
        viewModel.selectRestaurant(restaurant)
    }
    
    private func centerOnUserLocation() {
        if let userLocation = LocationManager.shared.lastLocation {
            let newRegion = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            
            // Force programmatic update by setting region directly
            // This will trigger updateUIView to set the map region
            viewModel.region = newRegion
        }
    }
}

// MARK: - Real-time MapKit Implementation
struct RealTimeMapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    let onRestaurantTap: (Restaurant) -> Void
    @State private var shouldUpdateRegionProgrammatically = false
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Disable default Apple pins and overlays
        mapView.showsUserLocation = false
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsPointsOfInterest = false
        
        // Set initial region
        mapView.setRegion(viewModel.region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // PREVENT SNAP-BACK: Only update region for explicit programmatic changes
        // Never update region while loading to avoid disrupting user interaction
        if !viewModel.isLoadingRestaurants {
            // Only update if there's a significant difference suggesting intentional programmatic update
            if !mapView.region.isApproximatelyEqual(to: viewModel.region, tolerance: 0.001) {
                mapView.setRegion(viewModel.region, animated: true)
            }
        }
        
        // Always update annotations (this doesn't affect map position)
        updateAnnotations(mapView)
    }
    
    private func updateAnnotations(_ mapView: MKMapView) {
        // Only update annotations if not currently loading to prevent flickering
        guard !viewModel.isLoadingRestaurants else { return }
        
        // Remove existing restaurant annotations only (keep user location)
        let restaurantAnnotations = mapView.annotations.compactMap { $0 as? RestaurantMapAnnotation }
        mapView.removeAnnotations(restaurantAnnotations)
        
        // Add user location annotation if available and not already present
        if let userLocation = LocationManager.shared.lastLocation {
            let hasUserAnnotation = mapView.annotations.contains { $0 is UserLocationAnnotation }
            if !hasUserAnnotation {
                let userAnnotation = UserLocationAnnotation(coordinate: userLocation.coordinate)
                mapView.addAnnotation(userAnnotation)
            }
        }
        
        // Add restaurant annotations
        let newRestaurantAnnotations = viewModel.restaurants.map { restaurant in
            RestaurantMapAnnotation(restaurant: restaurant)
        }
        mapView.addAnnotations(newRestaurantAnnotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RealTimeMapView
        private var debounceTask: Task<Void, Never>?
        
        init(_ parent: RealTimeMapView) {
            self.parent = parent
        }
        
        // MARK: - Region Change Detection with Debouncing
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Skip updates if currently loading to prevent snap-back
            guard !parent.viewModel.isLoadingRestaurants else { return }
            
            // Cancel any existing debounce task
            debounceTask?.cancel()
            
            // Use Task.detached with utility priority for debouncing
            debounceTask = Task.detached(priority: .utility) { [weak self] in
                guard let self = self else { return }
                
                // Sleep 1 second
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Guard against cancellation
                guard !Task.isCancelled else { return }
                
                // Double-check we're not loading before proceeding
                let isStillLoading = await MainActor.run {
                    self.parent.viewModel.isLoadingRestaurants
                }
                
                guard !isStillLoading else { return }
                
                // On MainActor, set viewModel.region = mapView.region (no mapView.setRegion here)
                await MainActor.run {
                    self.parent.viewModel.region = mapView.region
                }
                
                // Still off-thread, call viewModel.fetchRestaurantsForRegion
                await self.parent.viewModel.fetchRestaurantsForRegion(mapView.region)
            }
        }
        
        // MARK: - Custom Annotation Views
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let userAnnotation = annotation as? UserLocationAnnotation {
                return createUserLocationView(for: userAnnotation, in: mapView)
            } else if let restaurantAnnotation = annotation as? RestaurantMapAnnotation {
                return createRestaurantView(for: restaurantAnnotation, in: mapView)
            }
            return nil
        }
        
        private func createUserLocationView(for annotation: UserLocationAnnotation, in mapView: MKMapView) -> MKAnnotationView {
            let identifier = "UserLocation"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ??
                      MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            view.glyphImage = UIImage(systemName: "location.fill")
            view.markerTintColor = .systemBlue
            view.glyphTintColor = .white
            view.canShowCallout = false
            
            return view
        }
        
        private func createRestaurantView(for annotation: RestaurantMapAnnotation, in mapView: MKMapView) -> MKAnnotationView {
            let restaurant = annotation.restaurant
            let emoji = RestaurantEmojiService.shared.getEmojiForRestaurant(restaurant)
            let colors = RestaurantEmojiService.shared.getColorForEmoji(emoji)
            
            // Use a unique identifier based on emoji to improve reuse
            let identifier = "Restaurant_\(emoji)"
            
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ??
                      MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            // Set the specific emoji for this restaurant
            view.glyphText = emoji
            
            // Set color based on the emoji
            if let bgColor = UIColor(hexString: colors.background) {
                view.markerTintColor = bgColor
            } else {
                // Fallback colors based on amenity type
                view.markerTintColor = restaurant.amenityType == "fast_food" ? .systemOrange : .systemGreen
            }
            
            // Set glyph color
            if let fgColor = UIColor(hexString: colors.foreground) {
                view.glyphTintColor = fgColor
            } else {
                view.glyphTintColor = restaurant.hasNutritionData ? .white : .systemGray
            }
            
            // Highlight if has nutrition data
            if restaurant.hasNutritionData {
                view.displayPriority = .required
            } else {
                view.displayPriority = .defaultLow
            }
            
            view.canShowCallout = true
            view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            
            return view
        }
        
        // MARK: - Annotation Selection
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let restaurantAnnotation = view.annotation as? RestaurantMapAnnotation {
                parent.onRestaurantTap(restaurantAnnotation.restaurant)
            }
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let restaurantAnnotation = view.annotation as? RestaurantMapAnnotation {
                parent.onRestaurantTap(restaurantAnnotation.restaurant)
            }
        }
    }
}

// MARK: - Custom Annotations
class UserLocationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String? = "Your Location"
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

class RestaurantMapAnnotation: NSObject, MKAnnotation {
    let restaurant: Restaurant
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    
    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        self.coordinate = CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
        self.title = restaurant.name
        self.subtitle = restaurant.cuisine
    }
}

// MARK: - MKCoordinateRegion Extension
extension MKCoordinateRegion {
    func isApproximatelyEqual(to other: MKCoordinateRegion, tolerance: Double = 0.001) -> Bool {
        abs(center.latitude - other.center.latitude) < tolerance &&
        abs(center.longitude - other.center.longitude) < tolerance &&
        abs(span.latitudeDelta - other.span.latitudeDelta) < tolerance &&
        abs(span.longitudeDelta - other.span.longitudeDelta) < tolerance
    }
    
    var boundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) {
        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLon = center.longitude - span.longitudeDelta / 2
        let maxLon = center.longitude + span.longitudeDelta / 2
        return (minLat, minLon, maxLat, maxLon)
    }
}

// MARK: - UIColor Extension for Hex Colors
extension UIColor {
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}

// MARK: - Spinning Map Loading Indicator
struct SpinningMapIndicator: View {
    @State private var isRotating = false
    
    var body: some View {
        // Map icon with spinning animation - no background circle
        Image(systemName: "map.fill")
            .font(.system(size: 28, weight: .medium))
            .foregroundColor(.blue)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 1, y: 2)
            .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
            .animation(
                Animation.linear(duration: 2.0)
                    .repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear {
                isRotating = true
            }
            .onDisappear {
                isRotating = false
            }
    }
}
