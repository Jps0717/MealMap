import SwiftUI
import CoreLocation

struct HomeScreen: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var mapViewModel = MapViewModel()
    @ObservedObject private var nutritionManager = NutritionDataManager.shared
    
    @State private var isLoadingRestaurants = false
    @State private var hasLoadedInitialData = false
    @State private var showMainLoadingScreen = true
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [Restaurant] = []
    @State private var selectedRestaurant: Restaurant?
    @State private var searchWorkItem: DispatchWorkItem?
    
    // Categories mapping string to enum
    private let categoryMapping: [String: RestaurantCategory] = [
        "Fast Food": .fastFood,
        "Healthy": .healthy,
        "Vegan": .vegan,
        "High Protein": .highProtein,
        "Low Carb": .lowCarb
    ]
    
    var body: some View {
        NavigationView {
            if showMainLoadingScreen {
                fullScreenLoadingView
            } else {
                mainContentView
            }
        }
        .onAppear {
            clearFiltersOnHomeScreen()
            startOptimizedLoading()
        }
        .sheet(item: $selectedRestaurant) { restaurant in
            RestaurantDetailView(
                restaurant: restaurant,
                isPresented: .constant(true),
                selectedCategory: nil
            )
            .environmentObject(nutritionManager)
        }
    }
    
    private func clearFiltersOnHomeScreen() {
        if mapViewModel.currentFilter.hasActiveFilters {
            print(" HomeScreen: Clearing active filters for clean home experience")
            mapViewModel.clearFilters()
        }
    }
    
    private var fullScreenLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            VStack(spacing: 8) {
                Text("Setting up MealMap...")
                    .font(.headline)
                
                if isLoadingRestaurants {
                    Text("Loading restaurants near you")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("Getting location...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .navigationTitle("MealMap")
        .navigationBarHidden(true)
    }
    
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView
                
                searchBarView
                
                if isSearching && !searchText.isEmpty {
                    searchResultsView
                } else {
                    contentSectionsView
                }
            }
            .padding()
        }
        .navigationTitle("MealMap")
        .navigationBarHidden(true)
    }
    
    private var contentSectionsView: some View {
        VStack(spacing: 24) {
            categoriesView
            
            popularChainsView
            nearbyRestaurantsView
        }
    }
    
    private var searchBarView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search restaurants (e.g., McDonald's, Subway...)", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: searchText) { oldValue, newValue in
                        handleSearchTextChange(newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Search Results")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Spacer()
            }
            
            if searchResults.isEmpty && !isSearching {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    
                    Text("No restaurants found")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Try searching for: McDonald's, Subway, Starbucks, etc.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(searchResults.prefix(10), id: \.id) { restaurant in
                        SearchResultRow(restaurant: restaurant) {
                            selectedRestaurant = restaurant
                        }
                    }
                }
            }
        }
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        searchWorkItem?.cancel()
        
        if newValue.isEmpty {
            Task { @MainActor in
                self.isSearching = false
                self.searchResults = []
            }
        } else if newValue.count >= 2 {
            let workItem = DispatchWorkItem {
                Task { @MainActor in
                    await self.performSearch(query: newValue)
                }
            }
            searchWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }
    
    private func performSearch(query: String) async {
        isSearching = true
        
        let results = mapViewModel.restaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(query)
        }
        
        self.searchResults = Array(results.prefix(20))
        self.isSearching = false
    }
    
    private func clearSearch() {
        Task { @MainActor in
            self.searchText = ""
            self.searchResults = []
            self.isSearching = false
            self.searchWorkItem?.cancel()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Welcome to")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("MealMap")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                NavigationLink(destination: MapScreen(viewModel: createCleanMapViewModel())) {
                    HStack {
                        Image(systemName: "map")
                        Text("Map")
                        
                        if !hasLoadedInitialData {
                            ProgressView()
                                .scaleEffect(0.6)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
            }
            
            if !mapViewModel.currentAreaName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(" \(mapViewModel.currentAreaName)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func createCleanMapViewModel() -> MapViewModel {
        let cleanViewModel = MapViewModel()
        
        cleanViewModel.restaurants = mapViewModel.restaurants
        cleanViewModel.region = mapViewModel.region
        cleanViewModel.currentAreaName = mapViewModel.currentAreaName
        
        cleanViewModel.clearFilters()
        
        print(" Created clean MapViewModel for navigation from HomeScreen")
        return cleanViewModel
    }
    
    private var categoriesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Category")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(Array(categoryMapping.keys), id: \.self) { categoryString in
                    if let categoryEnum = categoryMapping[categoryString] {
                        NavigationLink(destination: CategoryListView(
                            category: categoryEnum,
                            restaurants: getCategoryRestaurants(categoryString),
                            isPresented: .constant(true)
                        )) {
                            CategoryCardView(
                                category: categoryString,
                                count: hasLoadedInitialData ? getCategoryCount(categoryString) : 0
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var popularChainsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Popular Chains")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink("View All", destination: MapScreen(viewModel: createCleanMapViewModel()))
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if !hasLoadedInitialData {
                popularChainsLoadingView
            } else {
                popularChainsContentView
            }
        }
    }
    
    private var popularChainsLoadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading popular chains...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var popularChainsContentView: some View {
        Group {
            if let userLocation = locationManager.lastLocation {
                let popularRestaurants = getPopularChains()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(popularRestaurants, id: \.id) { restaurant in
                            PopularChainCardView(restaurant: restaurant) {
                                selectedRestaurant = restaurant
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                Text("Location unavailable")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private var nearbyRestaurantsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Restaurants")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink("View All", destination: MapScreen(viewModel: createCleanMapViewModel()))
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if !hasLoadedInitialData {
                nearbyRestaurantsLoadingView
            } else {
                nearbyRestaurantsContentView
            }
        }
    }
    
    private var nearbyRestaurantsLoadingView: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading restaurants...")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    private var nearbyRestaurantsContentView: some View {
        let nearby = getNearbyRestaurants()
        
        if nearby.isEmpty {
            return AnyView(
                Text("No restaurants found nearby")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, minHeight: 60)
            )
        } else {
            return AnyView(
                VStack(spacing: 8) {
                    ForEach(nearby, id: \.id) { restaurant in
                        NearbyRestaurantRowView(restaurant: restaurant) {
                            selectedRestaurant = restaurant
                        }
                    }
                }
            )
        }
    }
    
    private func startOptimizedLoading() {
        if hasLoadedInitialData && !mapViewModel.restaurants.isEmpty {
            showMainLoadingScreen = false
            return
        }
        
        locationManager.requestLocationPermission()
        
        Task {
            await nutritionManager.initializeIfNeeded()
        }
        
        Task { @MainActor in
            var attempts = 0
            while locationManager.lastLocation == nil && attempts < 50 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                attempts += 1
            }
            
            guard let userLocation = locationManager.lastLocation?.coordinate else {
                showMainLoadingScreen = false
                return
            }
            
            isLoadingRestaurants = true
            
            mapViewModel.refreshData(for: userLocation)
            
            hasLoadedInitialData = true
            isLoadingRestaurants = false
            
            withAnimation(.easeInOut(duration: 0.5)) {
                showMainLoadingScreen = false
            }
        }
    }
    
    private func getCategoryRestaurants(_ category: String) -> [Restaurant] {
        guard hasLoadedInitialData else { return [] }
        
        let restaurants = mapViewModel.restaurants
        
        switch category {
        case "Fast Food":
            return restaurants.filter { restaurant in
                restaurant.amenityType == "fast_food" || 
                isFastFoodChain(restaurant.name)
            }
        case "Healthy":
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("salad") || name.contains("fresh") || name.contains("bowl") ||
                       isHealthyChain(restaurant.name)
            }
        case "Vegan":
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("vegan") || name.contains("plant") ||
                       isVeganFriendlyChain(restaurant.name)
            }
        case "High Protein":
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("grill") || name.contains("chicken") ||
                       name.contains("steakhouse") || name.contains("bbq") ||
                       isHighProteinChain(restaurant.name)
            }
        case "Low Carb":
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("salad") || name.contains("grill") ||
                       name.contains("keto") || isLowCarbFriendlyChain(restaurant.name)
            }
        default:
            return []
        }
    }
    
    // MARK: - Chain Classification Helpers
    
    private func isFastFoodChain(_ name: String) -> Bool {
        let fastFoodChains = [
            "McDonald's", "Burger King", "KFC", "Taco Bell", "Wendy's",
            "Subway", "Domino's", "Pizza Hut", "Dairy Queen", "Arby's",
            "White Castle", "Carl's Jr", "Hardee's", "Jack in the Box",
            "Popeyes", "Sonic", "Whataburger", "In-N-Out", "Five Guys"
        ]
        return fastFoodChains.contains { chain in
            name.localizedCaseInsensitiveContains(chain)
        }
    }
    
    private func isHealthyChain(_ name: String) -> Bool {
        let healthyChains = [
            "Panera", "Chipotle", "Sweetgreen", "Freshii", "Noodles & Company",
            "Panda Express", "Subway" // Subway can be healthy with right choices
        ]
        return healthyChains.contains { chain in
            name.localizedCaseInsensitiveContains(chain)
        }
    }
    
    private func isVeganFriendlyChain(_ name: String) -> Bool {
        let veganFriendlyChains = [
            "Chipotle", "Subway", "Taco Bell", "Panera", "Starbucks"
        ]
        return veganFriendlyChains.contains { chain in
            name.localizedCaseInsensitiveContains(chain)
        }
    }
    
    private func isHighProteinChain(_ name: String) -> Bool {
        let highProteinChains = [
            "KFC", "Chick-fil-A", "Popeyes", "Chipotle", "Five Guys",
            "In-N-Out", "Whataburger", "Arby's", "Boston Market"
        ]
        return highProteinChains.contains { chain in
            name.localizedCaseInsensitiveContains(chain)
        }
    }
    
    private func isLowCarbFriendlyChain(_ name: String) -> Bool {
        let lowCarbChains = [
            "Chipotle", "Five Guys", "In-N-Out", "Subway", "Jimmy John's"
        ]
        return lowCarbChains.contains { chain in
            name.localizedCaseInsensitiveContains(chain)
        }
    }
    
    private func getCategoryCount(_ category: String) -> Int {
        return getCategoryRestaurants(category).count
    }
    
    private func getPopularChains() -> [Restaurant] {
        guard hasLoadedInitialData, let userLocation = locationManager.lastLocation else {
            return []
        }
        
        let limitedRestaurants = Array(mapViewModel.restaurants.prefix(20).filter({ $0.hasNutritionData }))
        
        var seen = Set<String>()
        var result: [Restaurant] = []
        
        for restaurant in limitedRestaurants.sorted(by: { r1, r2 in
            let distance1 = userLocation.distance(from: CLLocation(latitude: r1.latitude, longitude: r1.longitude))
            let distance2 = userLocation.distance(from: CLLocation(latitude: r2.latitude, longitude: r2.longitude))
            return distance1 < distance2
        }) {
            if !seen.contains(restaurant.name) && result.count < 6 {
                seen.insert(restaurant.name)
                result.append(restaurant)
            }
        }
        
        return result
    }
    
    private func getNearbyRestaurants() -> [Restaurant] {
        guard hasLoadedInitialData, let userLocation = locationManager.lastLocation else {
            return []
        }
        
        let limitedRestaurants = Array(mapViewModel.restaurants.prefix(15))
        
        return Array(limitedRestaurants.sorted { r1, r2 in
            let distance1 = userLocation.distance(from: CLLocation(latitude: r1.latitude, longitude: r1.longitude))
            let distance2 = userLocation.distance(from: CLLocation(latitude: r2.latitude, longitude: r2.longitude))
            return distance1 < distance2
        }.prefix(4))
    }
}

struct SearchResultRow: View {
    let restaurant: Restaurant
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if restaurant.hasNutritionData {
                        Text("Nutrition data available")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategoryCardView: View {
    let category: String
    let count: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text(getCategoryIcon(category))
                .font(.largeTitle)
            
            Text(category)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("\(count) restaurants")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func getCategoryIcon(_ category: String) -> String {
        switch category {
        case "Fast Food": return ""
        case "Healthy": return ""
        case "Vegan": return ""
        case "High Protein": return ""
        case "Low Carb": return ""
        default: return ""
        }
    }
}

struct PopularChainCardView: View {
    let restaurant: Restaurant
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                Text(restaurant.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 80)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NearbyRestaurantRowView: View {
    let restaurant: Restaurant
    let onTap: () -> Void
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(restaurant.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                            Text(cuisine)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        if let userLocation = locationManager.lastLocation {
                            let distance = userLocation.distance(from: CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude))
                            let distanceInMiles = distance / 1609.34
                            
                            if !restaurant.cuisine.isNilOrEmpty {
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Text(String(format: "%.1f mi", distanceInMiles))
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                if restaurant.hasNutritionData {
                    Image(systemName: "leaf.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}
