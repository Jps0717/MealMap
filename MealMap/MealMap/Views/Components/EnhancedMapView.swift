import SwiftUI
import MapKit
import CoreLocation

// MARK: - Enhanced Map View with Smart 50-Pin Loading
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
    @State private var lastNotificationTime: Date = .distantPast
    
    var body: some View {
        ZStack {
            // SMART LOADING: Best 50 pins that load smoothly as you pan
            SmartLoadingMapView(viewModel: viewModel, onZoomLevelChange: { zoomLevel in
                // Defer state changes to avoid "modifying state during view update"
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
                        // This callback is no longer used since we removed the button
                    }
                )
                
                Spacer()
            }
            
            // Zoom In Notification Popup
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
                                Text("Pinch to zoom or double-tap to see restaurant pins")
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
            
            // Loading indicator
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
                                Text("Loading best restaurants...")
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
                                    
                                    Text("Showing top 50 restaurants")
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

            // UPDATED: Bottom right recenter button (moved from top and updated design)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // Recenter/Location button
                        Button(action: {
                            debugLog("📍 Recenter button tapped - centering on user location")
                            centerOnUserLocation()
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            
            // Bottom left BETA tag
            VStack {
                Spacer()
                HStack {
                    VStack {
                        Text("BETA")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange)
                            )
                            .shadow(color: .orange.opacity(0.3), radius: 4, y: 2)
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 20)
                    
                    Spacer()
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
    
    private func handleZoomLevelChange(_ zoomLevel: CLLocationDegrees) {
        currentZoomLevel = zoomLevel
        
        // Show notification when zoomed out too far
        let isZoomedOutTooFar = zoomLevel > 0.15
        
        if isZoomedOutTooFar && !showZoomInNotification {
            showNotification()
        } else if !isZoomedOutTooFar && showZoomInNotification {
            dismissNotification()
        }
    }
    
    private func showNotification() {
        // Check cooldown period
        let now = Date()
        let timeSinceLastNotification = now.timeIntervalSince(lastNotificationTime)
        
        if timeSinceLastNotification < 15.0 {
            return
        }
        
        lastNotificationTime = now
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showZoomInNotification = true
        }
        
        // Cancel any existing timer
        notificationTimer?.invalidate()
        
        // Auto-hide after 2 seconds
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
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
        debugLog("📍 Pin tapped: \(restaurant.name) - Opening detail view")
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

// MARK: - SMART LOADING: Max 50 Pins with Smooth Panning Updates
struct SmartLoadingMapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    let onZoomLevelChange: (CLLocationDegrees) -> Void
    let onRestaurantTap: (Restaurant) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // DISABLE ALL APPLE MAPS POINTS OF INTEREST
        mapView.pointOfInterestFilter = .excludingAll
        
        // OPTIMIZED: Disable heavy features for maximum performance
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // PERFORMANCE: Prefetch annotation view cache
        mapView.register(FastRestaurantAnnotationView.self, forAnnotationViewWithReuseIdentifier: "FastRestaurant")
        
        // Set initial region
        mapView.setRegion(viewModel.region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // SMOOTH: Reduced region update threshold for fluid panning
        let currentRegion = mapView.region
        let newRegion = viewModel.region
        
        // Only update if there's a significant change
        if abs(currentRegion.center.latitude - newRegion.center.latitude) > 0.001 ||
           abs(currentRegion.center.longitude - newRegion.center.longitude) > 0.001 ||
           abs(currentRegion.span.latitudeDelta - newRegion.span.latitudeDelta) > 0.001 {
            mapView.setRegion(newRegion, animated: true)
        }
        
        // Check zoom level to show/hide pins
        let currentSpan = mapView.region.span.latitudeDelta
        let shouldShowPins = currentSpan <= 0.15
        
        if shouldShowPins {
            // SMART: Show best 50 restaurants (nutrition prioritized)
            let restaurantsToShow = viewModel.showSearchResults ? 
                Array(viewModel.filteredRestaurants.prefix(50)) : 
                viewModel.allAvailableRestaurants  // Already limited to 50 best restaurants
            
            debugLog("🗺️ SMART PINS: \(restaurantsToShow.count) best restaurants")
            context.coordinator.updateAnnotations(mapView: mapView, restaurants: restaurantsToShow)
        } else {
            // Hide all pins when zoomed out
            context.coordinator.updateAnnotations(mapView: mapView, restaurants: [])
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: SmartLoadingMapView
        private var debounceTimer: Timer?
        private var currentAnnotationIds: Set<Int> = []
        
        init(_ parent: SmartLoadingMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let currentSpan = mapView.region.span.latitudeDelta
            
            // Notify zoom level change
            DispatchQueue.main.async { [weak self] in
                self?.parent.onZoomLevelChange(currentSpan)
            }
            
            // Check if we should show pins
            let shouldShowPins = currentSpan <= 0.15
            
            if shouldShowPins {
                // INSTANT: Update best 50 restaurants from cache as user pans
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    Task { @MainActor in
                        await self.parent.viewModel.updateMapRegion(mapView.region)
                    }
                }
                
                // SMOOTH: Load new restaurants in background if needed
                debounceTimer?.invalidate()
                debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    Task { @MainActor in
                        await self.parent.viewModel.fetchRestaurantsForViewport(mapView.region)
                    }
                }
            }
        }
        
        // FAST: Native annotation view creation
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            if let restaurantAnnotation = annotation as? RestaurantMapAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "FastRestaurant", for: annotation) as! FastRestaurantAnnotationView
                view.configure(with: restaurantAnnotation.restaurant)
                return view
            }
            
            return nil
        }
        
        // RESPONSIVE: Direct tap handling
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            mapView.deselectAnnotation(view.annotation, animated: false)
            
            if let restaurantAnnotation = view.annotation as? RestaurantMapAnnotation {
                parent.onRestaurantTap(restaurantAnnotation.restaurant)
            }
        }
        
        // OPTIMIZED: Efficient batch annotation updates for up to 50 pins
        func updateAnnotations(mapView: MKMapView, restaurants: [Restaurant]) {
            let newRestaurantIds = Set(restaurants.map { $0.id })
            
            // Quick exit if no changes
            if newRestaurantIds == currentAnnotationIds {
                return
            }
            
            // Get current restaurant annotations
            let currentRestaurantAnnotations = mapView.annotations.compactMap { $0 as? RestaurantMapAnnotation }
            
            // Use sets for faster lookups
            let currentIds = Set(currentRestaurantAnnotations.map { $0.restaurant.id })
            
            // Find annotations to remove
            let idsToRemove = currentIds.subtracting(newRestaurantIds)
            let annotationsToRemove = currentRestaurantAnnotations.filter { idsToRemove.contains($0.restaurant.id) }
            
            // Find restaurants to add
            let idsToAdd = newRestaurantIds.subtracting(currentIds)
            let restaurantsToAdd = restaurants.filter { idsToAdd.contains($0.id) }
            
            // PERFORMANCE: Batch update
            if !annotationsToRemove.isEmpty {
                mapView.removeAnnotations(annotationsToRemove)
            }
            
            if !restaurantsToAdd.isEmpty {
                let newAnnotations = restaurantsToAdd.map { RestaurantMapAnnotation(restaurant: $0) }
                mapView.addAnnotations(newAnnotations)
            }
            
            // Update tracking
            currentAnnotationIds = newRestaurantIds
            
            let nutritionCount = restaurants.filter { $0.hasNutritionData }.count
            debugLog("🗺️ PINS UPDATE: \(restaurants.count) restaurants (\(nutritionCount) nutrition)")
        }
        
        deinit {
            debounceTimer?.invalidate()
        }
    }
}

// ENHANCED: Restaurant Annotation View with Name Label
class FastRestaurantAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "FastRestaurant"
    
    private let pinView = UIView()
    private let iconLabel = UILabel()
    private let indicatorView = UIView()
    private let nameLabel = UILabel()
    private let nameBackgroundView = UIView()
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        frame = CGRect(x: 0, y: 0, width: 120, height: 60)
        centerOffset = CGPoint(x: 0, y: -30)
        canShowCallout = false
        
        pinView.frame = CGRect(x: 43, y: 0, width: 34, height: 34)
        pinView.layer.cornerRadius = 17
        pinView.layer.borderWidth = 2
        pinView.layer.borderColor = UIColor.white.cgColor
        pinView.layer.shadowColor = UIColor.black.cgColor
        pinView.layer.shadowOffset = CGSize(width: 0, height: 2)
        pinView.layer.shadowRadius = 3
        pinView.layer.shadowOpacity = 0.3
        addSubview(pinView)
        
        iconLabel.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
        iconLabel.textAlignment = .center
        iconLabel.font = UIFont.systemFont(ofSize: 16)
        pinView.addSubview(iconLabel)
        
        indicatorView.frame = CGRect(x: 67, y: 4, width: 8, height: 8)
        indicatorView.layer.cornerRadius = 4
        indicatorView.layer.borderWidth = 1
        indicatorView.layer.borderColor = UIColor.white.cgColor
        indicatorView.isHidden = true
        addSubview(indicatorView)
        
        nameBackgroundView.frame = CGRect(x: 5, y: 38, width: 110, height: 20)
        nameBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        nameBackgroundView.layer.cornerRadius = 10
        addSubview(nameBackgroundView)
        
        nameLabel.frame = CGRect(x: 10, y: 40, width: 100, height: 16)
        nameLabel.textAlignment = .center
        nameLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = UIColor.white
        nameLabel.numberOfLines = 1
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.8
        addSubview(nameLabel)
    }
    
    func configure(with restaurant: Restaurant) {
        if restaurant.hasNutritionData {
            pinView.backgroundColor = UIColor.systemGreen
            indicatorView.backgroundColor = UIColor.systemGreen
            indicatorView.isHidden = false
            displayPriority = .required
        } else {
            pinView.backgroundColor = UIColor.systemBlue
            indicatorView.isHidden = true
            displayPriority = .defaultLow
        }
        
        iconLabel.text = restaurant.emoji
        
        nameLabel.text = restaurant.name
        
        let textSize = (restaurant.name as NSString).size(withAttributes: [
            NSAttributedString.Key.font: nameLabel.font!
        ])
        let backgroundWidth = min(max(textSize.width + 12, 40), 110) 
        nameBackgroundView.frame = CGRect(
            x: (120 - backgroundWidth) / 2,
            y: 38,
            width: backgroundWidth,
            height: 20
        )
        nameLabel.frame = CGRect(
            x: nameBackgroundView.frame.minX + 6,
            y: 40,
            width: backgroundWidth - 12,
            height: 16
        )
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        indicatorView.isHidden = true
        pinView.backgroundColor = UIColor.systemBlue
        iconLabel.text = "🏪"
        nameLabel.text = ""
    }
}

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
