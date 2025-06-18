import SwiftUI
import CoreLocation

// MARK: - Optimized Restaurant Model Extension
extension Restaurant {
    private static var distanceKey: UInt8 = 0
    
    var distanceFromUser: Double {
        get {
            return objc_getAssociatedObject(self, &Restaurant.distanceKey) as? Double ?? 0.0
        }
        set {
            objc_setAssociatedObject(self, &Restaurant.distanceKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

private struct AssociatedKeys {
    static var distanceKey = "distanceFromUser"
}

// MARK: - Simplified Cached Results Manager
@MainActor
class HomeScreenDataManager: ObservableObject {
    @Published var cachedCategories: [RestaurantCategory: [Restaurant]] = [:]
    @Published var cachedPopularChains: [Restaurant] = []
    @Published var cachedNearbyRestaurants: [Restaurant] = []
    @Published var isProcessing = false
    
    private let processingQueue = DispatchQueue(label: "homescreen.processing", qos: .userInitiated)
    
    func precomputeData(restaurants: [Restaurant], userLocation: CLLocationCoordinate2D?) {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Process data in background - much simpler now
            let categories = self.processCategories(restaurants)
            let popularChains = self.processPopularChains(restaurants)
            let nearbyRestaurants = self.processNearbyRestaurants(restaurants, userLocation: userLocation)
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.cachedCategories = categories
                self.cachedPopularChains = popularChains
                self.cachedNearbyRestaurants = nearbyRestaurants
                self.isProcessing = false
            }
        }
    }
    
    private func processCategories(_ restaurants: [Restaurant]) -> [RestaurantCategory: [Restaurant]] {
        var results: [RestaurantCategory: [Restaurant]] = [:]
        
        for category in RestaurantCategory.allCases {
            results[category] = filterRestaurantsByCategory(category, from: restaurants)
        }
        
        return results
    }
    
    private func processPopularChains(_ restaurants: [Restaurant]) -> [Restaurant] {
        let popularChainNames = [
            "McDonald's", "Subway", "Starbucks", "Chipotle", "Chick-fil-A",
            "Taco Bell", "KFC", "Pizza Hut", "Domino's", "Burger King"
        ]
        
        return restaurants.filter { restaurant in
            let lowercaseName = restaurant.name.lowercased()
            return popularChainNames.contains { chainName in
                lowercaseName.contains(chainName.lowercased())
            }
        }.prefix(10).map { $0 }
    }
    
    private func processNearbyRestaurants(_ restaurants: [Restaurant], userLocation: CLLocationCoordinate2D?) -> [Restaurant] {
        guard let userLocation = userLocation else {
            return Array(restaurants.prefix(20)) // Just return first 20 if no location
        }
        
        // Sort by distance and return closest ones
        return restaurants.sorted { restaurant1, restaurant2 in
            let distance1 = calculateDistance(
                from: userLocation,
                to: CLLocationCoordinate2D(latitude: restaurant1.latitude, longitude: restaurant1.longitude)
            )
            let distance2 = calculateDistance(
                from: userLocation,
                to: CLLocationCoordinate2D(latitude: restaurant2.latitude, longitude: restaurant2.longitude)
            )
            return distance1 < distance2
        }
    }
    
    private func filterRestaurantsByCategory(_ category: RestaurantCategory, from restaurants: [Restaurant]) -> [Restaurant] {
        switch category {
        case .fastFood:
            return restaurants.filter { RestaurantData.restaurantsWithNutritionData.contains($0.name) }
        case .healthy:
            return restaurants.filter { restaurant in
                let healthyKeywords = ["salad", "fresh", "bowl", "juice", "smoothie"]
                let lowercaseName = restaurant.name.lowercased()
                return healthyKeywords.contains { lowercaseName.contains($0) }
            }
        case .vegan:
            return restaurants.filter { restaurant in
                let veganKeywords = ["vegan", "plant", "veggie", "green"]
                let lowercaseName = restaurant.name.lowercased()
                let lowercaseCuisine = restaurant.cuisine?.lowercased() ?? ""
                return veganKeywords.contains { lowercaseName.contains($0) } ||
                       lowercaseCuisine.contains("vegan")
            }
        case .highProtein:
            return restaurants.filter { restaurant in
                let proteinKeywords = ["grill", "steakhouse", "bbq", "chicken", "protein"]
                let lowercaseName = restaurant.name.lowercased()
                return proteinKeywords.contains { lowercaseName.contains($0) }
            }
        case .lowCarb:
            return restaurants.filter { restaurant in
                let lowCarbKeywords = ["salad", "grill", "steakhouse", "bowl"]
                let lowercaseName = restaurant.name.lowercased()
                return lowCarbKeywords.contains { lowercaseName.contains($0) }
            }
        }
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    func getDistanceForRestaurant(_ restaurant: Restaurant, userLocation: CLLocationCoordinate2D?) -> Double {
        guard let userLocation = userLocation else { return 0.0 }
        let restaurantLocation = CLLocationCoordinate2D(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        )
        return calculateDistance(from: userLocation, to: restaurantLocation)
    }
}

struct HomeScreen: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var mapViewModel = MapViewModel()
    @StateObject private var nutritionManager = NutritionDataManager()
    
    @State private var searchText = ""
    @State private var showingMapScreen = false
    @State private var selectedCategory: RestaurantCategory?
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    @State private var showingCategoryList = false
    
    // PERFORMANCE: Cache filtered results to avoid recomputation
    @State private var cachedCategoryCounts: [RestaurantCategory: Int] = [:]
    @State private var cachedPopularChains: [Restaurant] = []
    @State private var cachedNearbyRestaurants: [Restaurant] = []
    
    // Haptic feedback
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    // PERFORMANCE: Use LazyVStack for better scroll performance
                    LazyVStack(spacing: 24) {
                        // Header Section
                        headerSection
                        
                        // Search Bar
                        searchSection
                        
                        // Quick Access Categories
                        quickAccessSection
                        
                        // PERFORMANCE: Only show sections if we have data
                        if !cachedPopularChains.isEmpty {
                            popularChainsSection
                        }
                        
                        if !cachedNearbyRestaurants.isEmpty {
                            nearbyPicksSection
                        }
                        
                        // Bottom padding
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingMapScreen) {
                NavigationView {
                    MapScreen(viewModel: mapViewModel)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Back") {
                                    showingMapScreen = false
                                }
                                .font(.system(size: 16, weight: .semibold))
                            }
                        }
                }
            }
            .sheet(isPresented: $showingCategoryList) {
                if let category = selectedCategory {
                    CategoryListView(
                        category: category,
                        restaurants: filterRestaurantsByCategory(category),
                        isPresented: $showingCategoryList
                    )
                }
            }
            .sheet(isPresented: $showingRestaurantDetail) {
                if let restaurant = selectedRestaurant {
                    RestaurantDetailView(
                        restaurant: restaurant,
                        isPresented: $showingRestaurantDetail
                    )
                }
            }
        }
        .onAppear {
            setupInitialData()
        }
        // PERFORMANCE: Update cached data when restaurants change
        .onChange(of: mapViewModel.restaurants) { oldValue, newValue in
            updateCachedData()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good \(timeGreeting)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text(currentLocationText)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    mediumFeedback.impactOccurred()
                    showingMapScreen = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Map")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                }
            }
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
            
            TextField("Search restaurants, cuisines...", text: $searchText)
                .font(.system(size: 16, design: .rounded))
                .onSubmit {
                    performSearch()
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
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
    }
    
    // MARK: - Quick Access Categories
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Quick Access", subtitle: "Browse by category")
            
            // PERFORMANCE: Use simple Grid instead of LazyVGrid for small static content
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(Array(RestaurantCategory.allCases.prefix(2)), id: \.self) { category in
                        CategoryCard(
                            category: category,
                            restaurantCount: cachedCategoryCounts[category] ?? 0
                        ) {
                            selectCategory(category)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    ForEach(Array(RestaurantCategory.allCases.dropFirst(2)), id: \.self) { category in
                        CategoryCard(
                            category: category,
                            restaurantCount: cachedCategoryCounts[category] ?? 0
                        ) {
                            selectCategory(category)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Popular Chains Section
    private var popularChainsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Popular Chains", subtitle: "Top picks with nutrition data")
            
            ScrollView(.horizontal, showsIndicators: false) {
                // PERFORMANCE: Use LazyHStack only for horizontal scrolling
                LazyHStack(spacing: 16) {
                    ForEach(cachedPopularChains.prefix(10), id: \.id) { restaurant in
                        PopularChainCard(restaurant: restaurant) {
                            selectRestaurant(restaurant)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
    
    // MARK: - Nearby Picks Section
    private var nearbyPicksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nearby Picks")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Sorted by proximity")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showViewAllOnMap()
                }) {
                    HStack(spacing: 6) {
                        Text("View All")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Image(systemName: "map")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.blue.opacity(0.1))
                    )
                }
            }
            
            // PERFORMANCE: Show limited nearby restaurants
            LazyVStack(spacing: 12) {
                ForEach(cachedNearbyRestaurants.prefix(6), id: \.id) { restaurant in
                    NearbyRestaurantCard(restaurant: restaurant) {
                        selectRestaurant(restaurant)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
    
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default: return "Night"
        }
    }
    
    private var currentLocationText: String {
        guard let location = locationManager.lastLocation else {
            return "Getting location..."
        }
        
        // Use cached area name if available
        return mapViewModel.currentAreaName.isEmpty ? "Current Location" : mapViewModel.currentAreaName
    }
    
    // PERFORMANCE: Simplified data setup
    private func setupInitialData() {
        locationManager.requestLocationPermission()
        
        // PERFORMANCE: Only load data when location is available
        if let location = locationManager.lastLocation {
            mapViewModel.refreshData(for: location.coordinate)
        }
    }
    
    // PERFORMANCE: Cache expensive computations
    private func updateCachedData() {
        guard !mapViewModel.restaurants.isEmpty else { return }
        
        // Cache category counts
        for category in RestaurantCategory.allCases {
            cachedCategoryCounts[category] = filterRestaurantsByCategory(category).count
        }
        
        // Cache popular chains
        cachedPopularChains = getPopularChains()
        
        // Cache nearby restaurants
        cachedNearbyRestaurants = getNearbyRestaurants()
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        mapViewModel.performSearch(query: searchText, maxDistance: nil)
        showingMapScreen = true
    }
    
    private func selectCategory(_ category: RestaurantCategory) {
        lightFeedback.impactOccurred()
        selectedCategory = category
        showingCategoryList = true
    }
    
    private func selectRestaurant(_ restaurant: Restaurant) {
        mediumFeedback.impactOccurred()
        selectedRestaurant = restaurant
        showingRestaurantDetail = true
    }
    
    private func showViewAllOnMap() {
        mediumFeedback.impactOccurred()
        showingMapScreen = true
    }
    
    // PERFORMANCE: Simplified filtering with early returns
    private func filterRestaurantsByCategory(_ category: RestaurantCategory, from restaurants: [Restaurant]? = nil) -> [Restaurant] {
        let restaurantList = restaurants ?? mapViewModel.allAvailableRestaurants
        guard !restaurantList.isEmpty else { return [] }
        
        switch category {
        case .fastFood:
            return restaurantList.filter { RestaurantData.restaurantsWithNutritionData.contains($0.name) }
        case .healthy:
            return restaurantList.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("salad") || name.contains("fresh") || name.contains("bowl") || 
                       name.contains("juice") || name.contains("smoothie")
            }
        case .vegan:
            return restaurantList.filter { restaurant in
                let name = restaurant.name.lowercased()
                let cuisine = restaurant.cuisine?.lowercased() ?? ""
                return name.contains("vegan") || name.contains("plant") || name.contains("veggie") || 
                       name.contains("green") || cuisine.contains("vegan")
            }
        case .highProtein:
            return restaurantList.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("grill") || name.contains("steakhouse") || name.contains("bbq") || 
                       name.contains("chicken") || name.contains("protein")
            }
        case .lowCarb:
            return restaurantList.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("salad") || name.contains("grill") || name.contains("steakhouse") || 
                       name.contains("bowl")
            }
        }
    }
    
    // PERFORMANCE: Simplified popular chains with static list
    private func getPopularChains() -> [Restaurant] {
        let popularChainNames = [
            "McDonald's", "Subway", "Starbucks", "Chipotle", "Chick-fil-A",
            "Taco Bell", "KFC", "Pizza Hut", "Domino's", "Burger King"
        ]
        
        return mapViewModel.allAvailableRestaurants.filter { restaurant in
            popularChainNames.contains { chainName in
                restaurant.name.lowercased().contains(chainName.lowercased())
            }
        }
    }
    
    // PERFORMANCE: Simplified distance calculation
    private func getNearbyRestaurants() -> [Restaurant] {
        guard let userLocation = locationManager.lastLocation else {
            return Array(mapViewModel.allAvailableRestaurants.prefix(6))
        }
        
        let userCoordinate = userLocation.coordinate
        
        return mapViewModel.allAvailableRestaurants.sorted { restaurant1, restaurant2 in
            let distance1 = calculateDistance(
                from: userCoordinate,
                to: CLLocationCoordinate2D(latitude: restaurant1.latitude, longitude: restaurant1.longitude)
            )
            let distance2 = calculateDistance(
                from: userCoordinate,
                to: CLLocationCoordinate2D(latitude: restaurant2.latitude, longitude: restaurant2.longitude)
            )
            return distance1 < distance2
        }
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        let miles = distance / 1609.34
        if miles < 0.1 {
            return "< 0.1 mi"
        } else if miles < 1.0 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
}

// MARK: - Restaurant Category Enum
enum RestaurantCategory: String, CaseIterable {
    case fastFood = "Fast Food"
    case healthy = "Healthy"
    case vegan = "Vegan"
    case highProtein = "High Protein"
    case lowCarb = "Low Carb"
    
    var icon: String {
        switch self {
        case .fastFood: return "takeoutbag.and.cup.and.straw"
        case .healthy: return "leaf.fill"
        case .vegan: return "carrot.fill"
        case .highProtein: return "dumbbell.fill"
        case .lowCarb: return "minus.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .fastFood: return .orange
        case .healthy: return .green
        case .vegan: return .mint
        case .highProtein: return .red
        case .lowCarb: return .blue
        }
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: RestaurantCategory
    let restaurantCount: Int
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(category.color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(category.color)
                }
                
                VStack(spacing: 4) {
                    Text(category.rawValue)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("\(restaurantCount) options")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Popular Chain Card
struct PopularChainCard: View {
    let restaurant: Restaurant
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Restaurant image placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 80)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                            
                            if RestaurantData.restaurantsWithNutritionData.contains(restaurant.name) {
                                HStack(spacing: 2) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.green)
                                    Text("Nutrition")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    )
                
                VStack(spacing: 4) {
                    Text(restaurant.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    if let cuisine = restaurant.cuisine {
                        Text(cuisine.capitalized)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 120)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Nearby Restaurant Card
struct NearbyRestaurantCard: View {
    let restaurant: Restaurant
    let action: () -> Void
    
    @StateObject private var locationManager = LocationManager.shared
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Restaurant image placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        VStack(spacing: 2) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            if RestaurantData.restaurantsWithNutritionData.contains(restaurant.name) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.green)
                            }
                        }
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(restaurant.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let cuisine = restaurant.cuisine {
                        Text(cuisine.capitalized)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        // Distance
                        if let userLocation = locationManager.lastLocation {
                            let distance = calculateDistance(
                                from: userLocation.coordinate,
                                to: CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
                            )
                            
                            Text(formatDistance(distance))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        
                        // Nutrition score placeholder
                        if RestaurantData.restaurantsWithNutritionData.contains(restaurant.name) {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.yellow)
                                Text("4.2")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        let miles = distance / 1609.34
        if miles < 0.1 {
            return "< 0.1 mi"
        } else if miles < 1.0 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
}

#Preview {
    HomeScreen()
}
