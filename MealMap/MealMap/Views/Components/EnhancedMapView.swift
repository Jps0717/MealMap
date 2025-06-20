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
                // REAL-TIME: Enhanced MapKit view with immediate updates
                OptimizedRealTimeMapView(viewModel: viewModel) { restaurant in
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
                                .padding(.bottom, 20)
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

// MARK: - REAL-TIME: MapKit Implementation with Immediate Pin Updates
struct OptimizedRealTimeMapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    let onRestaurantTap: (Restaurant) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // OPTIMIZED: Disable resource-heavy features for better performance
        mapView.showsUserLocation = false
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsPointsOfInterest = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // Set initial region
        mapView.setRegion(viewModel.region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // NEVER reset the map's region here — user panning stays entirely in their control
        
        // Always update annotations (this doesn't affect map position)
        updateAnnotations(mapView)
    }
    
    private func updateAnnotations(_ mapView: MKMapView) {
        // Skip annotation updates during loading to prevent flicker
        guard !viewModel.isLoadingRestaurants else { return }
        
        // Add user location annotation if available and not already present
        if let userLocation = LocationManager.shared.lastLocation {
            let hasUserAnnotation = mapView.annotations.contains { $0 is UserLocationAnnotation }
            if !hasUserAnnotation {
                let userAnnotation = UserLocationAnnotation(coordinate: userLocation.coordinate)
                mapView.addAnnotation(userAnnotation)
            }
        }
        
        // Show every restaurant returned
        let newRestaurantAnnotations = viewModel.restaurants.map {
            RestaurantMapAnnotation(restaurant: $0)
        }
        
        // Clear old pins and add all new ones
        let old = mapView.annotations.compactMap { $0 as? RestaurantMapAnnotation }
        mapView.removeAnnotations(old)
        mapView.addAnnotations(newRestaurantAnnotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: OptimizedRealTimeMapView
        
        init(_ parent: OptimizedRealTimeMapView) {
            self.parent = parent
        }
        
        // MARK: - REAL-TIME: Immediate Region Change Detection
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Fire off every pan immediately, off the main thread
            Task.detached(priority: .utility) { [weak self] in
                guard let self = self else { return }
                // Update viewModel.region so it stays in sync
                await MainActor.run {
                    self.parent.viewModel.region = mapView.region
                }
                // Fetch every move—no debounce, no cancellation
                await self.parent.viewModel.fetchRestaurantsForRegion(mapView.region)
            }
        }
        
        // MARK: - OPTIMIZED: Custom Annotation Views with Better Performance
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let userAnnotation = annotation as? UserLocationAnnotation {
                return createUserLocationView(for: userAnnotation, in: mapView)
            } else if let restaurantAnnotation = annotation as? RestaurantMapAnnotation {
                return createOptimizedRestaurantView(for: restaurantAnnotation, in: mapView)
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
            view.displayPriority = .required
            
            return view
        }
        
        // OPTIMIZED: Simplified restaurant annotation for better performance
        private func createOptimizedRestaurantView(for annotation: RestaurantMapAnnotation, in mapView: MKMapView) -> MKAnnotationView {
            let restaurant = annotation.restaurant
            
            // Use simpler identifier for better reuse
            let identifier = restaurant.hasNutritionData ? "RestaurantNutrition" : "RestaurantBasic"
            
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ??
                      MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            // OPTIMIZED: Simplified emoji and coloring logic
            let emoji = getSimpleEmoji(for: restaurant)
            view.glyphText = emoji
            
            // OPTIMIZED: Simple color scheme for better performance
            if restaurant.hasNutritionData {
                view.markerTintColor = restaurant.amenityType == "fast_food" ? .systemOrange : .systemGreen
                view.glyphTintColor = .white
                view.displayPriority = .required
            } else {
                view.markerTintColor = .systemGray2
                view.glyphTintColor = .systemGray
                view.displayPriority = .defaultLow
            }
            
            view.canShowCallout = true
            view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            
            return view
        }
        
        // OPTIMIZED: Simple emoji logic for performance
        private func getSimpleEmoji(for restaurant: Restaurant) -> String {
            let name = restaurant.name.lowercased()
            
            // Fast lookup for common chains
            if name.contains("mcdonald") { return "🍟" }
            if name.contains("subway") { return "🥪" }
            if name.contains("starbucks") { return "☕" }
            if name.contains("pizza") { return "🍕" }
            if name.contains("taco") { return "🌮" }
            if name.contains("burger") { return "🍔" }
            if name.contains("kfc") || name.contains("chicken") { return "🍗" }
            if name.contains("dunkin") { return "🍩" }
            
            // Default by amenity type
            return restaurant.amenityType == "fast_food" ? "🍔" : "🍽️"
        }
        
        // MARK: - Annotation Selection with Improved Performance
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

// MARK: - Custom Annotations (Unchanged but optimized)
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

// MARK: - MKCoordinateRegion Extension (Enhanced)
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

// MARK: - UIColor Extension for Hex Colors (Unchanged)
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

// MARK: - OPTIMIZED: Spinning Map Loading Indicator
struct SpinningMapIndicator: View {
    @State private var isRotating = false
    
    var body: some View {
        // Simplified loading indicator for better performance
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
