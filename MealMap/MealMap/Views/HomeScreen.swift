import SwiftUI
import CoreLocation

struct HomeScreen: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var mapViewModel = MapViewModel()
    @StateObject private var nutritionManager = NutritionDataManager()
    @State private var isLoadingData = false
    
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
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView
                    
                    searchBarView
                    
                    if isSearching && !searchText.isEmpty {
                        searchResultsView
                    } else {
                        // Original content (categories, etc.)
                        originalContentView
                    }
                }
                .padding()
            }
            .navigationTitle("MealMap")
            .navigationBarHidden(true)
            .onAppear {
                startLoading()
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
    
    // Original content when not searching
    private var originalContentView: some View {
        VStack(spacing: 20) {
            if isLoadingData {
                loadingView
            } else {
                mainContentView
            }
        }
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        searchWorkItem?.cancel()
        
        if newValue.isEmpty {
            isSearching = false
            searchResults = []
        } else if newValue.count >= 2 {
            let workItem = DispatchWorkItem {
                Task {
                    await performSearch(query: newValue)
                }
            }
            searchWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }
    
    private func performSearch(query: String) async {
        await MainActor.run {
            isSearching = true
        }
        
        // Simple search through loaded restaurants
        let results = mapViewModel.restaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(query)
        }
        
        await MainActor.run {
            self.searchResults = Array(results.prefix(20)) // Limit to 20 results
            self.isSearching = false
        }
    }
    
    private func clearSearch() {
        searchText = ""
        searchResults = []
        isSearching = false
        searchWorkItem?.cancel()
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
                
                NavigationLink(destination: MapScreen(viewModel: mapViewModel)) {
                    HStack {
                        Image(systemName: "map")
                        Text("Map")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
            }
            
            if !mapViewModel.currentAreaName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("📍 \(mapViewModel.currentAreaName)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            VStack(spacing: 8) {
                Text("Loading restaurant data...")
                    .font(.headline)
                
                Text("Finding restaurants near you")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var mainContentView: some View {
        VStack(spacing: 24) {
            categoriesView
            popularChainsView
            nearbyRestaurantsView
        }
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
                            CategoryCardView(category: categoryString, count: getCategoryCount(categoryString))
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
                
                NavigationLink("View All", destination: MapScreen(viewModel: mapViewModel))
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            let chains = getPopularChains()
            if chains.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading chains...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(chains.prefix(8), id: \.id) { restaurant in
                            PopularChainCardView(restaurant: restaurant) {
                                selectedRestaurant = restaurant
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
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
                
                NavigationLink("View All", destination: MapScreen(viewModel: mapViewModel))
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            let nearby = getNearbyRestaurants()
            if nearby.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading restaurants...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(nearby.prefix(5), id: \.id) { restaurant in
                        NearbyRestaurantRowView(restaurant: restaurant) {
                            selectedRestaurant = restaurant
                        }
                    }
                }
            }
        }
    }
    
    // Simplified helper methods - no caching or complex processing
    private func startLoading() {
        isLoadingData = true
        
        if !mapViewModel.restaurants.isEmpty {
            isLoadingData = false
            return
        }
        
        Task {
            if let userLocation = locationManager.lastLocation?.coordinate {
                mapViewModel.refreshData(for: userLocation)
            }
            await MainActor.run {
                isLoadingData = false
            }
        }
    }
    
    private func getCategoryRestaurants(_ category: String) -> [Restaurant] {
        let restaurants = mapViewModel.restaurants
        
        switch category {
        case "Fast Food":
            return restaurants.filter { $0.amenityType == "fast_food" }
        case "Healthy":
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("salad") || name.contains("fresh") || name.contains("bowl")
            }
        case "Vegan":
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("vegan") || name.contains("plant")
            }
        case "High Protein":
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("grill") || name.contains("chicken")
            }
        case "Low Carb":
            return restaurants.filter { restaurant in
                let name = restaurant.name.lowercased()
                return name.contains("salad") || name.contains("grill")
            }
        default:
            return []
        }
    }
    
    private func getCategoryCount(_ category: String) -> Int {
        return getCategoryRestaurants(category).count
    }
    
    private func getPopularChains() -> [Restaurant] {
        return mapViewModel.restaurants
            .filter { $0.hasNutritionData }
            .prefix(10)
            .map { $0 }
    }
    
    private func getNearbyRestaurants() -> [Restaurant] {
        guard let userLocation = locationManager.lastLocation else {
            return Array(mapViewModel.restaurants.prefix(6))
        }
        
        // Simple distance sorting without complex caching
        return mapViewModel.restaurants
            .sorted { restaurant1, restaurant2 in
                let distance1 = userLocation.distance(from: CLLocation(latitude: restaurant1.latitude, longitude: restaurant1.longitude))
                let distance2 = userLocation.distance(from: CLLocation(latitude: restaurant2.latitude, longitude: restaurant2.longitude))
                return distance1 < distance2
            }
            .prefix(6)
            .map { $0 }
    }
}

// Simplified UI components
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
        case "Fast Food": return "🍔"
        case "Healthy": return "🥗"
        case "Vegan": return "🌱"
        case "High Protein": return "🥩"
        case "Low Carb": return "🥬"
        default: return "🍽️"
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
                    
                    if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                        Text(cuisine)
                            .font(.caption)
                            .foregroundColor(.gray)
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
