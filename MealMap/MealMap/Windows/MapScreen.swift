import SwiftUI
import MapKit

// MARK: - Main MapScreen

struct MapScreen: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var showFilterPanel: Bool = false
    @State private var hasActiveFilters: Bool = false
    @State private var currentAreaName: String = "Loading..."
    @State private var lastGeocodeTime: Date = Date()
    @State private var lastGeocodeLocation: CLLocationCoordinate2D?
    
    // Filter States
    @State private var selectedPriceRange: FilterPanel.PriceRange = .all
    @State private var selectedCuisines: Set<String> = []
    @State private var selectedRating: Double = 0
    @State private var isOpenNow: Bool = false
    @State private var selectedPriorities: Set<FilterPanel.Priority> = []
    @State private var dietaryRestrictions: Set<FilterPanel.DietaryRestriction> = []
    @State private var favoriteFoods: Set<String> = []
    @State private var maxDistance: Double = 5.0 // in miles

    private let minimumGeocodeInterval: TimeInterval = 1
    private let minimumDistanceChange: CLLocationDegrees = 0.005
    private let zoomedOutThreshold: CLLocationDegrees = 0.5 // Threshold for showing state vs city

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
                print("City: \(placemark.locality ?? "nil")")
                print("Town: \(placemark.subLocality ?? "nil")")
                print("State: \(placemark.administrativeArea ?? "nil")")
            } catch {
                print("Geocoding error: \(error.localizedDescription)")
            }
        }
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
                            region = newRegion
                            updateAreaName(for: newRegion.center)
                        }
                    ), showsUserLocation: true)
                        .mapStyle(.standard(pointsOfInterest: []))
                        .onAppear {
                            if let location = locationManager.lastLocation {
                                withAnimation {
                                    region = MKCoordinateRegion(
                                        center: location.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )
                                }
                                updateAreaName(for: location.coordinate)
                            }
                        }
                        .ignoresSafeArea(edges: .all)

                    // --- TOP OVERLAYS: Search bar & City tag ---
                    VStack(alignment: .center, spacing: 8) {
                        // Enhanced Search bar
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .font(.system(size: 16, weight: .medium))
                            
                            TextField("Search restaurants, cuisines...", text: $searchText)
                                .font(.system(size: 16))
                                .disableAutocorrection(true)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        searchText = ""
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                }
                            }
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    showFilterPanel = true
                                }
                            }) {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16, weight: .medium))
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

                        Spacer()
                    }
                    .ignoresSafeArea(.keyboard)

                    // --- BOTTOM OVERLAY: Enhanced List, Filter, User Location ---
                    VStack {
                        Spacer()
                        MapBottomOverlay(
                            hasActiveFilters: hasActiveFilters,
                            onListView: {
                                // TODO: Show List View with haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            },
                            onFilter: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    showFilterPanel = true
                                }
                            },
                            onUserLocation: {
                                // Animate map to user location with haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                if let loc = locationManager.lastLocation {
                                    withAnimation(.easeInOut(duration: 1.0)) {
                                        region = MKCoordinateRegion(
                                            center: loc.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                        )
                                    }
                                    updateAreaName(for: loc.coordinate)
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
                        selectedPriorities: $selectedPriorities,
                        dietaryRestrictions: $dietaryRestrictions,
                        favoriteFoods: $favoriteFoods,
                        maxDistance: $maxDistance
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
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
            }
        }
    }
}

// MARK: - Enhanced Bottom Overlay Bar

struct MapBottomOverlay: View {
    let hasActiveFilters: Bool
    var onListView: () -> Void
    var onFilter: () -> Void
    var onUserLocation: () -> Void

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
    @Binding var selectedPriorities: Set<Priority>
    @Binding var dietaryRestrictions: Set<DietaryRestriction>
    @Binding var favoriteFoods: Set<String>
    @Binding var maxDistance: Double
    
    @State private var selectedSection: FilterSection? = nil
    
    enum FilterSection: String, CaseIterable {
        case priorities = "Priorities"
        case dietary = "Dietary Restrictions"
        case favorites = "Favorite Foods"
        case distance = "Maximum Distance"
    }
    
    enum PriceRange: String, CaseIterable {
        case all = "All"
        case budget = "$"
        case moderate = "$$"
        case expensive = "$$$"
        case luxury = "$$$$"
    }
    
    enum Priority: String, CaseIterable {
        case proximity = "Proximity"
        case price = "Price"
        case variety = "Variety"
        case quality = "Quality"
        case popularity = "Popularity"
    }
    
    enum DietaryRestriction: String, CaseIterable {
        case vegetarian = "Vegetarian"
        case vegan = "Vegan"
        case glutenFree = "Gluten-Free"
        case dairyFree = "Dairy-Free"
        case nutFree = "Nut-Free"
        case halal = "Halal"
        case kosher = "Kosher"
    }
    
    let cuisineTypes = ["Italian", "Asian", "Mexican", "American", "Mediterranean", "Indian", "Japanese", "Thai"]
    let favoriteFoodOptions = ["Pizza", "Sushi", "Burgers", "Pasta", "Tacos", "Curry", "Steak", "Seafood", "Salad", "Sandwiches"]
    
    private func calculateContentHeight() -> CGFloat {
        let baseHeight: CGFloat = 160
        let itemHeight: CGFloat = 60
        let spacing: CGFloat = 8
        let padding: CGFloat = 32
        
        switch selectedSection {
        case .priorities:
            return baseHeight + (CGFloat(Priority.allCases.count) * (itemHeight + spacing)) + padding
        case .dietary:
            return baseHeight + (CGFloat(DietaryRestriction.allCases.count) * (itemHeight + spacing)) + padding
        case .favorites:
            return baseHeight + (CGFloat(favoriteFoodOptions.count) * (itemHeight + spacing)) + padding
        case .distance:
            return baseHeight + 80
        case .none:
            return baseHeight + (CGFloat(FilterSection.allCases.count) * 80) + padding
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
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedPriceRange = .all
                        selectedCuisines.removeAll()
                        selectedRating = 0
                        isOpenNow = false
                        selectedPriorities.removeAll()
                        dietaryRestrictions.removeAll()
                        favoriteFoods.removeAll()
                        maxDistance = 5.0
                        hasActiveFilters = false
                    }
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
                        case .priorities:
                            FadingScrollView(items: Priority.allCases) { priority, isSelected in
                                PreferenceToggleButton(
                                    title: (priority as! Priority).rawValue,
                                    isSelected: selectedPriorities.contains(priority as! Priority),
                                    action: {
                                        if selectedPriorities.contains(priority as! Priority) {
                                            selectedPriorities.remove(priority as! Priority)
                                        } else {
                                            selectedPriorities.insert(priority as! Priority)
                                        }
                                        updateActiveFilters()
                                    },
                                    scale: 1.0,
                                    opacity: 1.0,
                                    isSelectable: true
                                )
                            }
                            .frame(height: min(calculateContentHeight() - 150, 400))
                            .padding(.horizontal, 20)
                            .padding(.top, -8)
                            
                        case .dietary:
                            FadingScrollView(items: DietaryRestriction.allCases) { restriction, isSelected in
                                PreferenceToggleButton(
                                    title: (restriction as! DietaryRestriction).rawValue,
                                    isSelected: dietaryRestrictions.contains(restriction as! DietaryRestriction),
                                    action: {
                                        if dietaryRestrictions.contains(restriction as! DietaryRestriction) {
                                            dietaryRestrictions.remove(restriction as! DietaryRestriction)
                                        } else {
                                            dietaryRestrictions.insert(restriction as! DietaryRestriction)
                                        }
                                        updateActiveFilters()
                                    },
                                    scale: 1.0,
                                    opacity: 1.0,
                                    isSelectable: true
                                )
                            }
                            .frame(height: min(calculateContentHeight() - 150, 400))
                            .padding(.horizontal, 20)
                            .padding(.top, -25)
                            
                        case .favorites:
                            FadingScrollView(items: favoriteFoodOptions) { food, isSelected in
                                PreferenceToggleButton(
                                    title: food as! String,
                                    isSelected: favoriteFoods.contains(food as! String),
                                    action: {
                                        if favoriteFoods.contains(food as! String) {
                                            favoriteFoods.remove(food as! String)
                                        } else {
                                            favoriteFoods.insert(food as! String)
                                        }
                                        updateActiveFilters()
                                    },
                                    scale: 1.0,
                                    opacity: 1.0,
                                    isSelectable: true
                                )
                            }
                            .frame(height: min(calculateContentHeight() - 150, 400))
                            .padding(.horizontal, 20)
                            .padding(.top, -8)
                            
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
                                    case .priorities:
                                        if !selectedPriorities.isEmpty {
                                            Text("\(selectedPriorities.count) selected")
                                                .foregroundColor(.gray)
                                        }
                                    case .dietary:
                                        if !dietaryRestrictions.isEmpty {
                                            Text("\(dietaryRestrictions.count) selected")
                                                .foregroundColor(.gray)
                                        }
                                    case .favorites:
                                        if !favoriteFoods.isEmpty {
                                            Text("\(favoriteFoods.count) selected")
                                                .foregroundColor(.gray)
                                        }
                                    case .distance:
                                        Text("\(Int(maxDistance)) mi")
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            
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
            .padding(.bottom, 20)
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
    }
    
    private func updateActiveFilters() {
        hasActiveFilters = !selectedPriorities.isEmpty ||
                          !dietaryRestrictions.isEmpty ||
                          !favoriteFoods.isEmpty ||
                          maxDistance < 20.0
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
            HStack(spacing: 16) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
