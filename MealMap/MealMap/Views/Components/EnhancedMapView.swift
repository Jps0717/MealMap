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
            viewModel.updateRegion(newRegion)
        }
    }
}

// MARK: - Real-time MapKit Implementation
struct RealTimeMapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    let onRestaurantTap: (Restaurant) -> Void
    
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
        // Update region if changed externally
        if !mapView.region.isApproximatelyEqual(to: viewModel.region) {
            mapView.setRegion(viewModel.region, animated: true)
        }
        
        // Update annotations
        updateAnnotations(mapView)
    }
    
    private func updateAnnotations(_ mapView: MKMapView) {
        // Remove existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add user location annotation if available
        if let userLocation = LocationManager.shared.lastLocation {
            let userAnnotation = UserLocationAnnotation(coordinate: userLocation.coordinate)
            mapView.addAnnotation(userAnnotation)
        }
        
        // Add restaurant annotations
        let restaurantAnnotations = viewModel.restaurants.map { restaurant in
            RestaurantMapAnnotation(restaurant: restaurant)
        }
        mapView.addAnnotations(restaurantAnnotations)
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
            // Cancel previous debounce task
            debounceTask?.cancel()
            
            // Debounce region changes (500ms)
            debounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
                
                guard !Task.isCancelled else { return }
                
                // Update view model region
                parent.viewModel.updateMapRegion(mapView.region)
                
                // Fetch restaurants for new region
                await parent.viewModel.fetchRestaurantsForRegion(mapView.region)
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
