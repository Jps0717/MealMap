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
    @State private var showSearchScreen = false
    
    // Categories mapping string to enum - UPDATED: Only 3 categories + custom
    private let categoryMapping: [String: RestaurantCategory] = [
        "Fast Food": .fastFood,
        "Healthy": .healthy,
        "High Protein": .highProtein
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
                
                contentSectionsView
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
        Button {
            showSearchScreen = true
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                Text("Search restaurants...")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSearchScreen) {
            SearchScreen(isPresented: $showSearchScreen)
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
                
                NavigationLink(destination: MapScreen(viewModel: mapViewModel)) {
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
    
    private var categoriesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Category")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                NavigationLink(destination: CategoryListView(
                    category: .fastFood,
                    restaurants: getFastFoodRestaurants(),
                    isPresented: .constant(true)
                )) {
                    CategoryCardView(
                        category: "Fast Food",
                        count: getFastFoodRestaurants().count
                    )
                }
                
                NavigationLink(destination: CategoryListView(
                    category: .healthy,
                    restaurants: getHealthyRestaurants(),
                    isPresented: .constant(true)
                )) {
                    CategoryCardView(
                        category: "Healthy",
                        count: getHealthyRestaurants().count
                    )
                }
                
                NavigationLink(destination: CategoryListView(
                    category: .highProtein,
                    restaurants: getHighProteinRestaurants(),
                    isPresented: .constant(true)
                )) {
                    CategoryCardView(
                        category: "High Protein",
                        count: getHighProteinRestaurants().count
                    )
                }
                
                Button(action: {
                    print("Custom category creation not yet implemented")
                }) {
                    CustomCategoryCardView()
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
                
                NavigationLink(destination: MapScreen(viewModel: mapViewModel)) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
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
                
                NavigationLink(destination: MapScreen(viewModel: mapViewModel)) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
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
                
                NavigationLink(destination: MapScreen(viewModel: mapViewModel)) {
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
    
    private func createRestaurantsFromNames(_ names: [String], cuisine: String) -> [Restaurant] {
        let restaurants: [Restaurant] = names.compactMap { name in
            guard RestaurantData.hasNutritionData(for: name) else { return nil }
            
            return Restaurant(
                id: name.hashValue,
                name: name,
                latitude: locationManager.lastLocation?.coordinate.latitude ?? 37.7749,
                longitude: locationManager.lastLocation?.coordinate.longitude ?? -122.4194,
                address: "Multiple locations",
                cuisine: cuisine,
                openingHours: "Varies by location",
                phone: nil,
                website: nil,
                type: "chain"
            )
        }
        
        return restaurants.sorted { $0.name < $1.name }
    }
    
    private func getFastFoodRestaurants() -> [Restaurant] {
        let fastFoodNames = [
            "7 Eleven",
            "Arby's",
            "Bojangles",
            "Burger King",
            "Carl's Jr.",
            "Checkers Drive-In / Rally's",
            "Chick-fil-A",
            "Church's Chicken",
            "Dairy Queen",
            "Domino's",
            "Dunkin' Donuts",
            "Five Guys",
            "Hardee's",
            "In-N-Out Burger",
            "Jack in the Box",
            "KFC",
            "McDonald's",
            "Papa John's",
            "Pizza Hut",
            "Popeyes",
            "Quiznos",
            "Sbarro",
            "Sonic",
            "Subway",
            "Taco Bell",
            "Wendy's",
            "Whataburger",
            "White Castle",
            "Wingstop"
        ]

        return createRestaurantsFromNames(fastFoodNames, cuisine: "Fast Food")
    }
    
    private func getHealthyRestaurants() -> [Restaurant] {
        let healthyNames = [
            "Panera Bread", "Chipotle", "Subway", "Noodles & Company",
            "Panda Express", "Jason's Deli", "Firehouse Subs",
            "Potbelly Sandwich Shop", "Qdoba", "Moe's Southwest Grill"
        ]
        
        return createRestaurantsFromNames(healthyNames, cuisine: "Healthy/Fast Casual")
    }
    
    private func getHighProteinRestaurants() -> [Restaurant] {
        let highProteinNames = [
            "KFC", "Chick-fil-A", "Popeyes", "Chipotle", "Five Guys",
            "In-N-Out Burger", "Whataburger", "Arby's", "Boston Market",
            "Outback Steakhouse", "LongHorn Steakhouse", "Red Lobster",
            "TGI Friday's", "Applebee's", "Red Robin"
        ]
        
        return createRestaurantsFromNames(highProteinNames, cuisine: "High Protein")
    }
    
    private func startOptimizedLoading() {
        if hasLoadedInitialData {
            showMainLoadingScreen = false
            return
        }
        
        Task { @MainActor in
            updateLoadingStatus("Getting Location", "Requesting location permission...", progress: 0.2)
            locationManager.requestLocationPermission()
            
            updateLoadingStatus("Initializing", "Setting up nutrition database...", progress: 0.4)
            
            await nutritionManager.initializeIfNeeded()
            
            updateLoadingStatus("Finding Location", "Getting your location...", progress: 0.6)
            var attempts = 0
            while locationManager.lastLocation == nil && attempts < 15 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                attempts += 1
                
                let waitProgress = 0.6 + (Double(attempts) / 15.0) * 0.2
                updateLoadingStatus("Finding Location", "GPS signal: \(attempts * 7)%...", progress: waitProgress)
            }
            
            updateLoadingStatus("Almost Ready", "Finalizing setup...", progress: 0.9)
            
            if let userLocation = locationManager.lastLocation?.coordinate {
                mapViewModel.region = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
            
            hasLoadedInitialData = true
            updateLoadingStatus("Ready!", "Welcome to MealMap!", progress: 1.0)
            
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            withAnimation(.easeInOut(duration: 0.3)) {
                showMainLoadingScreen = false
            }
        }
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
            
            Text("\(count) restaurant\(count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.blue)
                .fontWeight(.medium)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func getCategoryIcon(_ category: String) -> String {
        switch category {
        case "Fast Food": return "🍔"
        case "Healthy": return "🥗"
        case "High Protein": return "🥩"
        default: return "🍽️"
        }
    }
}

struct CustomCategoryCardView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("Custom")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            Text("Create category")
                .font(.caption)
                .foregroundColor(.gray)
                .fontWeight(.medium)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
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
