import SwiftUI
import CoreLocation
import ObjectiveC

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
    
    func precomputeData(restaurants: [Restaurant], userLocation: CLLocationCoordinate2D?) {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        let limitedRestaurants = Array(restaurants.prefix(100))
        
        let categories = processCategories(limitedRestaurants)
        let popularChains = processPopularChains(limitedRestaurants)
        let nearbyRestaurants = processNearbyRestaurants(limitedRestaurants, userLocation: userLocation)
        
        cachedCategories = categories
        cachedPopularChains = popularChains
        cachedNearbyRestaurants = nearbyRestaurants
        isProcessing = false
    }
    
    private func processCategories(_ restaurants: [Restaurant]) -> [RestaurantCategory: [Restaurant]] {
        var results: [RestaurantCategory: [Restaurant]] = [:]
        
        for category in RestaurantCategory.allCases {
            let filtered = filterRestaurantsByCategory(category, from: restaurants)
            results[category] = Array(filtered.prefix(10))
        }
        
        return results
    }
    
    private func processPopularChains(_ restaurants: [Restaurant]) -> [Restaurant] {
        let popularChainNames = [
            "McDonald's", "Subway", "Starbucks", "Chipotle", "Chick-fil-A"
        ]
        
        let filtered = restaurants.filter { restaurant in
            let lowercaseName = restaurant.name.lowercased()
            return popularChainNames.contains { chainName in
                lowercaseName.contains(chainName.lowercased())
            }
        }
        return Array(filtered.prefix(5))
    }
    
    private func processNearbyRestaurants(_ restaurants: [Restaurant], userLocation: CLLocationCoordinate2D?) -> [Restaurant] {
        guard let userLocation = userLocation else {
            return Array(restaurants.prefix(5))
        }
        
        let sorted = restaurants.sorted { restaurant1, restaurant2 in
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
        
        return Array(sorted.prefix(5))
    }
    
    private func filterRestaurantsByCategory(_ category: RestaurantCategory, from restaurants: [Restaurant]) -> [Restaurant] {
        guard !restaurants.isEmpty else { return [] }
        
        switch category {
        case .fastFood:
            return restaurants.filter { RestaurantData.restaurantsWithNutritionData.contains($0.name) }
        case .healthy:
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("salad") || name.contains("fresh") || name.contains("bowl")
            }
        case .vegan:
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("vegan") || name.contains("plant")
            }
        case .highProtein:
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("grill") || name.contains("chicken")
            }
        case .lowCarb:
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("salad") || name.contains("grill")
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
    @State private var isLoadingInitialData = false
    @State private var isLoadingCategoryData = false
    
    @State private var showingFilters = false
    @State private var globalFilter = RestaurantFilter()
    
    @State private var cachedCategoryCounts: [RestaurantCategory: Int] = [:]
    @State private var cachedPopularChains: [Restaurant] = []
    @State private var cachedNearbyRestaurants: [Restaurant] = []
    
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if isLoadingInitialData {
                    LoadingView(
                        title: "Setting up MealMap",
                        subtitle: "Loading restaurant data near you...",
                        progress: mapViewModel.loadingProgress,
                        style: .fullScreen
                    )
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 24) {
                            headerSection
                            
                            searchSection
                            
                            quickAccessSection
                            
                            if !cachedPopularChains.isEmpty {
                                popularChainsSection
                            } else if !isLoadingCategoryData && !mapViewModel.isLoadingRestaurants {
                                DataLoadingView(
                                    dataType: "Popular Chains",
                                    progress: nil
                                )
                                .padding(.horizontal, 20)
                            }
                            
                            if !cachedNearbyRestaurants.isEmpty {
                                nearbyPicksSection
                            } else if !isLoadingCategoryData && !mapViewModel.isLoadingRestaurants {
                                DataLoadingView(
                                    dataType: "Nearby Restaurants",  
                                    progress: nil
                                )
                                .padding(.horizontal, 20)
                            }
                            
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 50)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.light)
            .fullScreenCover(isPresented: $showingMapScreen) {
                NavigationView {
                    MapScreen(viewModel: mapViewModel)
                        .navigationBarTitleDisplayMode(.inline)
                        .preferredColorScheme(.light) 
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
                    .preferredColorScheme(.light) 
                }
            }
            .sheet(isPresented: $showingRestaurantDetail) {
                if let restaurant = selectedRestaurant {
                    RestaurantDetailView(
                        restaurant: restaurant,
                        isPresented: $showingRestaurantDetail,
                        selectedCategory: nil
                    )
                    .preferredColorScheme(.light) 
                }
            }
            .sheet(isPresented: $showingFilters) {
                RestaurantFilterView(
                    filter: $globalFilter,
                    isPresented: $showingFilters,
                    availableRestaurants: mapViewModel.allAvailableRestaurants,
                    userLocation: locationManager.lastLocation?.coordinate
                )
                .preferredColorScheme(.light)
            }
        }
        .onAppear {
            setupInitialData()
        }
        .onChange(of: mapViewModel.restaurants) { oldValue, newValue in
            if !newValue.isEmpty && cachedCategoryCounts.isEmpty {
                isLoadingCategoryData = true
            }
            updateCachedData()
            if isLoadingCategoryData {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoadingCategoryData = false
                }
            }
        }
        .onChange(of: mapViewModel.isLoadingRestaurants) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                isLoadingInitialData = newValue && mapViewModel.restaurants.isEmpty
            }
        }
        .onChange(of: globalFilter) { oldValue, newValue in
            if newValue.hasActiveFilters {
                showFilteredResultsOnMap()
            }
        }
    }
    
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
                
                HStack(spacing: 12) {
                    Button(action: {
                        lightFeedback.impactOccurred()
                        showingFilters = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .semibold))
                            
                            if globalFilter.hasActiveFilters {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .foregroundColor(globalFilter.hasActiveFilters ? .white : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(globalFilter.hasActiveFilters ? Color.blue : Color.blue.opacity(0.1))
                        )
                    }
                    
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
    }
    
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
    
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Quick Access", subtitle: "Browse by category")
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(Array(RestaurantCategory.allCases.prefix(2)), id: \.self) { category in
                        CategoryCard(
                            category: category,
                            restaurantCount: cachedCategoryCounts[category] ?? 0,
                            isLoading: false
                        ) {
                            selectCategory(category)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    ForEach(Array(RestaurantCategory.allCases.dropFirst(2)), id: \.self) { category in
                        CategoryCard(
                            category: category,
                            restaurantCount: cachedCategoryCounts[category] ?? 0,
                            isLoading: false
                        ) {
                            selectCategory(category)
                        }
                    }
                }
            }
        }
    }
    
    private var popularChainsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Popular Chains", subtitle: "Top picks with nutrition data")
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(cachedPopularChains.prefix(5), id: \.id) { restaurant in
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
            
            LazyVStack(spacing: 12) {
                ForEach(cachedNearbyRestaurants.prefix(3), id: \.id) { restaurant in
                    NearbyRestaurantCard(restaurant: restaurant) {
                        selectRestaurant(restaurant)
                    }
                }
            }
        }
    }
    
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
        
        return mapViewModel.currentAreaName.isEmpty ? "Current Location" : mapViewModel.currentAreaName
    }
    
    private func setupInitialData() {
        locationManager.requestLocationPermission()
        
        if let location = locationManager.lastLocation {
            mapViewModel.refreshData(for: location.coordinate)
        }
    }
    
    private func updateCachedData() {
        guard !mapViewModel.restaurants.isEmpty else { return }
        
        let limitedRestaurants = Array(mapViewModel.restaurants.prefix(50))
        
        for category in RestaurantCategory.allCases {
            cachedCategoryCounts[category] = filterRestaurantsByCategory(category, from: limitedRestaurants).count
        }
        
        cachedPopularChains = getPopularChains(from: limitedRestaurants)
        
        cachedNearbyRestaurants = getNearbyRestaurants(from: limitedRestaurants)
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        Task {
            await MainActor.run {
                lightFeedback.impactOccurred()
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                mapViewModel.performSearch(query: searchText, maxDistance: nil)
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingMapScreen = true
                }
            }
        }
    }
    
    private func selectCategory(_ category: RestaurantCategory) {
        lightFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedCategory = category
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showingCategoryList = true
        }
    }
    
    private func selectRestaurant(_ restaurant: Restaurant) {
        mediumFeedback.impactOccurred()
        
        if RestaurantData.restaurantsWithNutritionData.contains(restaurant.name) {
            nutritionManager.preloadNutritionData(for: restaurant.name)
        }
        
        selectedRestaurant = restaurant
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showingRestaurantDetail = true
        }
    }
    
    private func showViewAllOnMap() {
        mediumFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingMapScreen = true
        }
    }
    
    private func showFilteredResultsOnMap() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingMapScreen = true
        }
    }
    
    private func filterRestaurantsByCategory(_ category: RestaurantCategory, from restaurants: [Restaurant]? = nil) -> [Restaurant] {
        let restaurantList = restaurants ?? Array(mapViewModel.allAvailableRestaurants.prefix(50))
        guard !restaurantList.isEmpty else { return [] }
        
        switch category {
        case .fastFood:
            return restaurantList.filter { RestaurantData.restaurantsWithNutritionData.contains($0.name) }
        case .healthy:
            return restaurantList.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("salad") || name.contains("fresh") || name.contains("bowl")
            }
        case .vegan:
            return restaurantList.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("vegan") || name.contains("plant")
            }
        case .highProtein:
            return restaurantList.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("grill") || name.contains("chicken")
            }
        case .lowCarb:
            return restaurantList.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("salad") || name.contains("grill")
            }
        }
    }
    
    private func getPopularChains(from restaurants: [Restaurant]? = nil) -> [Restaurant] {
        let restaurantList = restaurants ?? Array(mapViewModel.allAvailableRestaurants.prefix(50))
        let popularChainNames = ["McDonald's", "Subway", "Starbucks"]
        
        let filtered = restaurantList.filter { restaurant in
            popularChainNames.contains { chainName in
                restaurant.name.lowercased().contains(chainName.lowercased())
            }
        }
        return Array(filtered.prefix(3))
    }
    
    private func getNearbyRestaurants(from restaurants: [Restaurant]? = nil) -> [Restaurant] {
        let restaurantList = restaurants ?? Array(mapViewModel.allAvailableRestaurants.prefix(50))
        
        guard let userLocation = locationManager.lastLocation else {
            return Array(restaurantList.prefix(3))
        }
        
        let userCoordinate = userLocation.coordinate
        
        let sorted = restaurantList.sorted { restaurant1, restaurant2 in
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
        
        return Array(sorted.prefix(3))
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

// MARK: - Category Card
struct CategoryCard: View {
    let category: RestaurantCategory
    let restaurantCount: Int
    let isLoading: Bool
    let action: () -> Void
    
    init(category: RestaurantCategory, restaurantCount: Int, isLoading: Bool = false, action: @escaping () -> Void) {
        self.category = category
        self.restaurantCount = restaurantCount
        self.isLoading = isLoading
        self.action = action
    }
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: isLoading ? {} : action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(category.color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: category.color))
                    } else {
                        Image(systemName: category.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(category.color)
                    }
                }
                
                VStack(spacing: 4) {
                    Text(category.rawValue)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    if isLoading {
                        LoadingView(
                            title: "",
                            subtitle: nil,
                            progress: nil,
                            style: .compact
                        )
                        .frame(height: 20)
                    } else {
                        Text("\(restaurantCount) options")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
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
            .opacity(isLoading ? 0.7 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing && !isLoading
            }
        }, perform: {})
    }
}

// MARK: - Popular Chain Card
struct PopularChainCard: View {
    let restaurant: Restaurant
    let action: () -> Void
    
    @State private var isPressed = false
    
    private var restaurantCategory: RestaurantCategory? {
        for category in RestaurantCategory.allCases {
            if restaurant.matchesCategory(category) {
                return category
            }
        }
        return nil
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 80)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 4) {
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
                                
                                if let category = restaurantCategory {
                                    HStack(spacing: 2) {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 8))
                                            .foregroundColor(category.color)
                                        Text(category.rawValue)
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(category.color)
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(category.color.opacity(0.15))
                                    )
                                }
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(restaurantCategory?.color ?? Color.clear, lineWidth: restaurantCategory != nil ? 2 : 0)
                    )
                
                VStack(spacing: 4) {
                    Text(restaurant.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    HStack {
                        if let cuisine = restaurant.cuisine {
                            Text(cuisine.capitalized)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if let category = restaurantCategory {
                            Circle()
                                .fill(category.color)
                                .frame(width: 8, height: 8)
                        }
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
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(restaurantCategory?.color.opacity(0.3) ?? Color.clear, lineWidth: restaurantCategory != nil ? 1 : 0)
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
    
    private var restaurantCategory: RestaurantCategory? {
        for category in RestaurantCategory.allCases {
            if restaurant.matchesCategory(category) {
                return category
            }
        }
        return nil
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(restaurantCategory?.color.opacity(0.1) ?? Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        VStack(spacing: 2) {
                            Image(systemName: restaurantCategory?.icon ?? "fork.knife")
                                .font(.system(size: 16))
                                .foregroundColor(restaurantCategory?.color ?? .gray)
                            
                            if RestaurantData.restaurantsWithNutritionData.contains(restaurant.name) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.green)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(restaurantCategory?.color ?? Color.clear, lineWidth: restaurantCategory != nil ? 2 : 0)
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(restaurant.name)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let category = restaurantCategory {
                            Text(category.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(category.color)
                                )
                        }
                    }
                    
                    if let cuisine = restaurant.cuisine {
                        Text(cuisine.capitalized)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        if let userLocation = locationManager.lastLocation {
                            let distance = calculateDistance(
                                from: userLocation.coordinate,
                                to: CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
                            )
                            
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(restaurantCategory?.color ?? .blue)
                                
                                Text(formatDistance(distance))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(restaurantCategory?.color ?? .blue)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    if let category = restaurantCategory {
                        Circle()
                            .fill(category.color)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            )
            .overlay(
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(restaurantCategory?.color ?? Color.clear)
                        .frame(width: restaurantCategory != nil ? 4 : 0)
                    Spacer()
                }
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
