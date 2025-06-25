import SwiftUI
import CoreLocation
import MapKit

struct HomeScreen: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var mapViewModel = MapViewModel()
    @ObservedObject private var nutritionManager = NutritionDataManager.shared
    
    @State private var isLoadingRestaurants = false
    @State private var hasLoadedInitialData = false
    @State private var showMainLoadingScreen = true
    
    // ENHANCED: Loading status tracking
    @State private var loadingStatus = "Setting up MealMap..."
    @State private var loadingSubtitle = "Getting location..."
    @State private var loadingProgress: Double = 0.0
    
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
            debugLog("🏠 HomeScreen: Clearing active filters for clean home experience")
            updateLoadingStatus("Clearing filters", "Preparing clean experience...")
            mapViewModel.clearFilters()
        }
    }
    
    private var fullScreenLoadingView: some View {
        VStack(spacing: 24) {
            ProgressView(value: loadingProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
                .frame(width: 200)
            
            VStack(spacing: 8) {
                Text(loadingStatus)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(loadingSubtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Text("\(Int(loadingProgress * 100))%")
                .font(.caption2)
                .foregroundColor(.blue)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .navigationTitle("MealMap")
        .navigationBarHidden(true)
    }
    
    private func updateLoadingStatus(_ status: String, _ subtitle: String, progress: Double? = nil) {
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.3)) {
                self.loadingStatus = status
                self.loadingSubtitle = subtitle
                if let progress = progress {
                    self.loadingProgress = progress
                }
            }
        }
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
        
        // Search through static restaurant list for better performance
        let staticMatches = RestaurantData.restaurantsWithNutritionData.filter { restaurantName in
            restaurantName.localizedCaseInsensitiveContains(query)
        }
        
        // Convert to Restaurant objects for display
        let searchResults = staticMatches.map { name in
            Restaurant(
                id: name.hashValue,
                name: name,
                latitude: locationManager.lastLocation?.coordinate.latitude ?? 0,
                longitude: locationManager.lastLocation?.coordinate.longitude ?? 0,
                address: "Multiple locations",
                cuisine: "Various",
                openingHours: nil,
                phone: nil,
                website: nil,
                type: "node"
            )
        }
        
        self.searchResults = Array(searchResults.prefix(20))
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
                Text("📍 \(mapViewModel.currentAreaName)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func createCleanMapViewModel() -> MapViewModel {
        let cleanViewModel = MapViewModel()
        
        // Only copy essential location data, don't trigger restaurant loading
        cleanViewModel.region = mapViewModel.region
        cleanViewModel.currentAreaName = mapViewModel.currentAreaName
        cleanViewModel.clearFilters()
        
        debugLog("📍 Created clean MapViewModel for navigation - restaurants will load on map appear")
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
                                count: getCategoryCount(categoryString)
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
            
            popularChainsContentView
        }
    }
    
    private var popularChainsContentView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach([
                    "McDonald's", "Subway", "Starbucks", "Burger King", "KFC", "Taco Bell"
                ], id: \.self) { chainName in
                    StaticChainCardView(chainName: chainName) {
                        let placeholderRestaurant = Restaurant(
                            id: chainName.hashValue,
                            name: chainName,
                            latitude: locationManager.lastLocation?.coordinate.latitude ?? 0,
                            longitude: locationManager.lastLocation?.coordinate.longitude ?? 0,
                            address: "Location varies",
                            cuisine: "Fast Food",
                            openingHours: nil,
                            phone: nil,
                            website: nil,
                            type: "node"
                        )
                        selectedRestaurant = placeholderRestaurant
                    }
                }
            }
            .padding(.horizontal, 4)
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
            
            nearbyRestaurantsContentView
        }
    }
    
    private var nearbyRestaurantsContentView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "location.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to explore nearby restaurants")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Tap 'Map' to see restaurants in your area")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                NavigationLink(destination: MapScreen(viewModel: createCleanMapViewModel())) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func startOptimizedLoading() {
        if hasLoadedInitialData {
            showMainLoadingScreen = false
            return
        }
        
        Task { @MainActor in
            // Step 1: Location setup
            updateLoadingStatus("Getting Location", "Requesting location permission...", progress: 0.2)
            locationManager.requestLocationPermission()
            
            // Step 2: Lightweight API availability check only
            updateLoadingStatus("Initializing", "Setting up nutrition database...", progress: 0.4)
            
            await nutritionManager.initializeIfNeeded()
            
            // Step 3: Wait for location (shorter timeout)
            updateLoadingStatus("Finding Location", "Getting your location...", progress: 0.6)
            var attempts = 0
            while locationManager.lastLocation == nil && attempts < 15 {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                attempts += 1
                
                let waitProgress = 0.6 + (Double(attempts) / 15.0) * 0.2 // 0.6 to 0.8
                updateLoadingStatus("Finding Location", "GPS signal: \(attempts * 7)%...", progress: waitProgress)
            }
            
            // Step 4: Finalize quickly
            updateLoadingStatus("Almost Ready", "Finalizing setup...", progress: 0.9)
            
            if let userLocation = locationManager.lastLocation?.coordinate {
                mapViewModel.region = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
            
            // Quick completion
            hasLoadedInitialData = true
            updateLoadingStatus("Ready!", "Welcome to MealMap!", progress: 1.0)
            
            try? await Task.sleep(nanoseconds: 300_000_000) // Very brief pause
            
            // Hide loading screen
            withAnimation(.easeInOut(duration: 0.3)) {
                showMainLoadingScreen = false
            }
        }
    }
    
    private func getCategoryRestaurants(_ category: String) -> [Restaurant] {
        // Categories will work after visiting the map - return empty for now
        return []
    }
    
    private func getCategoryCount(_ category: String) -> Int {
        // Return static counts based on category type
        switch category {
        case "Fast Food": return 25
        case "Healthy": return 12
        case "Vegan": return 8
        case "High Protein": return 15
        case "Low Carb": return 10
        default: return 5
        }
    }
}

// MARK: - Supporting Views

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

struct StaticChainCardView: View {
    let chainName: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(getChainEmoji(chainName))
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                Text(chainName)
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
    
    private func getChainEmoji(_ name: String) -> String {
        switch name {
        case "McDonald's": return "🍔"
        case "Subway": return "🥪"
        case "Starbucks": return "☕"
        case "Burger King": return "🍔"
        case "KFC": return "🍗"
        case "Taco Bell": return "🌮"
        default: return "🍽️"
        }
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}
