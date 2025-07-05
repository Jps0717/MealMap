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
    @State private var showingMapScreen = false
    @State private var showingMenuPhotoCapture = false
    
    // Categories mapping string to enum - UPDATED: Only 3 categories + custom
    private let categoryMapping: [String: RestaurantCategory] = [
        "Fast Food": .fastFood,
        "Healthy": .healthy,
        "High Protein": .highProtein
    ]
    
    private var scanMenuCard: some View {
        Button(action: {
            showingMenuPhotoCapture = true
        }) {
            HStack(spacing: 16) {
                Image(systemName: "camera")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan Menu")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Analyze nutrition from photos")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
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
        // ENHANCED: Modal map presentation for proper home button navigation
        .fullScreenCover(isPresented: $showingMapScreen) {
            MapScreen(viewModel: mapViewModel)
        }
        .sheet(isPresented: $showingMenuPhotoCapture) {
            MenuPhotoCaptureView()
        }
    }
    
    private func clearFiltersOnHomeScreen() {
        if mapViewModel.currentFilter.hasActiveFilters {
            updateLoadingStatus("Clearing filters", "Preparing clean experience...")
            // FIXED: Use the correct method name
            mapViewModel.clearFiltersOnHomeScreen()
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
            VStack(spacing: 32) {
                headerView
                searchBarView
                scanMenuCard
                categoriesView
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("MealMap")
        .navigationBarHidden(true)
        .background(Color(.systemBackground))
    }
    
    private var searchBarView: some View {
        Button {
            showSearchScreen = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                Text("Search restaurants...")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSearchScreen) {
            SearchScreen(isPresented: $showSearchScreen)
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("MealMap")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if !mapViewModel.currentAreaName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("📍 \(mapViewModel.currentAreaName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                showingMapScreen = true
            }) {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
    
    private var categoriesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                NavigationLink(destination: CategoryListView(
                    category: .fastFood,
                    restaurants: getFastFoodRestaurants(),
                    isPresented: .constant(true)
                )) {
                    MinimalCategoryCard(
                        title: "Fast Food",
                        count: getFastFoodRestaurants().count,
                        icon: "🍔"
                    )
                }
                
                NavigationLink(destination: CategoryListView(
                    category: .healthy,
                    restaurants: getHealthyRestaurants(),
                    isPresented: .constant(true)
                )) {
                    MinimalCategoryCard(
                        title: "Healthy",
                        count: getHealthyRestaurants().count,
                        icon: "🥗"
                    )
                }
                
                NavigationLink(destination: CategoryListView(
                    category: .highProtein,
                    restaurants: getHighProteinRestaurants(),
                    isPresented: .constant(true)
                )) {
                    MinimalCategoryCard(
                        title: "High Protein",
                        count: getHighProteinRestaurants().count,
                        icon: "🥩"
                    )
                }
                
                Button(action: {
                    showingMapScreen = true // Show map for more options
                }) {
                    MinimalCategoryCard(
                        title: "More",
                        count: nil,
                        icon: "•••"
                    )
                }
            }
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
    
    struct MinimalCategoryCard: View {
        let title: String
        let count: Int?
        let icon: String
        
        var body: some View {
            VStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 32))
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let count = count {
                        Text("\(count) restaurants")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
        }
    }

    struct CategoryCardView: View {
        let category: String
        let count: Int
        
        var body: some View {
            VStack(spacing: 12) {
                Text(getCategoryIcon(category))
                    .font(.system(size: 28))
                
                VStack(spacing: 4) {
                    Text(category)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(count) restaurants")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5), lineWidth: 1)
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
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}