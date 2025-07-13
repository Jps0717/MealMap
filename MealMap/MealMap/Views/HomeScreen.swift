import SwiftUI
import Combine
import MapKit

struct HomeScreen: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var mapViewModel = MapViewModel()
    @ObservedObject private var nutritionManager = NutritionDataManager.shared
    @StateObject private var savedMenuManager = SavedMenuManager.shared
    @StateObject private var profileCompletionManager = ProfileCompletionManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var mainCategoryManager = MainCategoryManager.shared

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
    @State private var showSearchDropdown = false
    @State private var showingMapScreen = false
    @State private var showingMenuPhotoCapture = false
    @State private var showingNutritionixSettings = false
    @State private var showingEditProfile = false
    @State private var showingCustomCategories = false
    @State private var showingDietaryChat = false
    @State private var showingCarouselMapScreen = false
    @State private var showingCarouselMenuCapture = false
    @State private var showingCarouselDietaryChat = false
    @State private var selectedSavedMenu: SavedMenuAnalysis?
    @State private var isEditingMenus = false
    
    @FocusState private var isSearchFieldFocused: Bool

    private let categoryMapping: [String: RestaurantCategory] = [
        "Fast Food": .fastFood,
        "Healthy": .healthy,
        "High Protein": .highProtein
    ]

    private var scanMenuCard: some View {
        AutoSlidingCarousel(
            showingMenuPhotoCapture: $showingCarouselMenuCapture,
            showingMapScreen: $showingCarouselMapScreen,
            showingDietaryChat: $showingCarouselDietaryChat
        )
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
            
            // Check profile completion after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                profileCompletionManager.checkProfileCompletion(for: authManager.currentUser)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myCategoriesChanged)) { _ in
            // Categories will auto-update through @StateObject
        }
        .onDisappear {
            // Clean up any timers when leaving the screen
        }
        .sheet(item: $selectedRestaurant) { restaurant in
            RestaurantDetailView(
                restaurant: restaurant,
                isPresented: .constant(true),
                selectedCategory: nil
            )
            .environmentObject(nutritionManager)
        }
        .fullScreenCover(isPresented: $showingMapScreen) {
            MapScreen(viewModel: mapViewModel)
        }
        .fullScreenCover(isPresented: $showingCarouselMapScreen) {
            MapScreen(viewModel: mapViewModel)
        }
        .sheet(isPresented: $showingMenuPhotoCapture) {
            MenuPhotoCaptureView(autoTriggerCamera: true)
        }
        .sheet(isPresented: $showingCarouselMenuCapture) {
            MenuPhotoCaptureView(autoTriggerCamera: false)
        }
        .sheet(isPresented: $showingNutritionixSettings) {
            NutritionixSettingsView()
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingCustomCategories) {
            CustomCategoriesView()
        }
        .sheet(isPresented: $showingDietaryChat) {
            DietaryChatView()
        }
        .sheet(isPresented: $showingCarouselDietaryChat) {
            DietaryChatView()
        }
        .sheet(item: $selectedSavedMenu) { savedMenu in
            SavedMenuDetailView(savedMenu: savedMenu)
        }
        .overlay {
            if profileCompletionManager.shouldShowProfilePrompt {
                ProfileCompletionPopup(
                    isPresented: $profileCompletionManager.shouldShowProfilePrompt,
                    onEditProfile: {
                        profileCompletionManager.markPromptAsShown()
                        showingEditProfile = true
                    },
                    onSkipForNow: {
                        profileCompletionManager.dismissPrompt()
                    }
                )
            }
        }
    }

    private func clearFiltersOnHomeScreen() {
        // UPDATED: No more filters to clear - map shows all restaurants
        debugLog("🗺️ No filters to clear - map shows all restaurants")
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
        ZStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerView
                    searchBarView
                    
                    // Only show other content when search dropdown is not active
                    if !showSearchDropdown {
                        FoodTypeCarousel(mapViewModel: mapViewModel)
                        scanMenuCard
                        categoriesView
                        savedMenusView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("MealMap")
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
            .onTapGesture {
                // Close search dropdown when tapping outside
                if showSearchDropdown {
                    showSearchDropdown = false
                    isSearchFieldFocused = false
                }
            }
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

            HStack(spacing: 12) {
                Button(action: {
                    HapticService.shared.navigate()
                    showingMapScreen = true
                }) {
                    Image(systemName: "map")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                
                // Dietary Chat Button
                Button(action: {
                    HapticService.shared.sheetPresent()
                    showingDietaryChat = true
                }) {
                    Image(systemName: "message.circle")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .frame(width: 44, height: 44)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                }

                Button(action: {
                    HapticService.shared.sheetPresent()
                    showingNutritionixSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
    }

    private var searchBarView: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))

                TextField("Search restaurants...", text: $searchText)
                    .focused($isSearchFieldFocused)
                    .font(.system(size: 16))
                    .onChange(of: searchText) { _, newValue in
                        handleSearchTextChange(newValue)
                    }
                    .onSubmit {
                        if !searchText.isEmpty {
                            performSearch()
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        isSearching = false
                        showSearchDropdown = false
                        isSearchFieldFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .onTapGesture {
                isSearchFieldFocused = true
                if searchText.isEmpty {
                    showSearchDropdown = true
                }
            }
            
            // Search Dropdown
            if showSearchDropdown {
                searchDropdownView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSearchDropdown)
    }
    
    private var searchDropdownView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
            
            VStack(spacing: 16) {
                if searchText.isEmpty {
                    // Popular Searches
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Popular Searches")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(["McDonald's", "Subway", "Starbucks", "Chipotle", "KFC", "Taco Bell"], id: \.self) { search in
                                Button(action: {
                                    searchText = search
                                    performSearch()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "flame")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        
                                        Text(search)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // ENHANCED: Dynamic Cuisine Searches
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Search by Cuisine")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        let popularCuisines = getPopularCuisines()
                        
                        if popularCuisines.isEmpty {
                            // Fallback to predefined cuisines when no data available
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach([
                                    CuisineCategory(name: "Italian", count: 0, emoji: "🍝", searchTerms: ["italian", "pizza", "pasta"]),
                                    CuisineCategory(name: "Chinese", count: 0, emoji: "🥡", searchTerms: ["chinese", "asian"]),
                                    CuisineCategory(name: "Mexican", count: 0, emoji: "🌮", searchTerms: ["mexican", "taco", "burrito"]),
                                    CuisineCategory(name: "American", count: 0, emoji: "🍔", searchTerms: ["american", "burger"])
                                ], id: \.name) { cuisine in
                                    CuisineSearchButton(cuisine: cuisine) {
                                        searchText = cuisine.name.lowercased()
                                        performCuisineSearch(cuisine)
                                    }
                                }
                            }
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(popularCuisines.prefix(6), id: \.name) { cuisine in
                                    CuisineSearchButton(cuisine: cuisine) {
                                        searchText = cuisine.name.lowercased()
                                        performCuisineSearch(cuisine)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Category Searches
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Search by Category")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            CategorySearchDropdownButton(
                                title: "Fast Food",
                                subtitle: "Burgers, fries, quick service",
                                icon: "🍔"
                            ) {
                                searchText = "fast food"
                                performCategorySearch(.fastFood)
                            }
                            
                            CategorySearchDropdownButton(
                                title: "Healthy Options",
                                subtitle: "Salads, fresh ingredients",
                                icon: "🥗"
                            ) {
                                searchText = "healthy"
                                performCategorySearch(.healthy)
                            }
                            
                            CategorySearchDropdownButton(
                                title: "High Protein",
                                subtitle: "Protein-rich meals",
                                icon: "🥩"
                            ) {
                                searchText = "high protein"
                                performCategorySearch(.highProtein)
                            }
                        }
                    }
                } else {
                    // Search Results
                    if isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    } else if searchResults.isEmpty {
                        VStack(spacing: 12) {
                            Text("No results found for '\(searchText)'")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // Show cuisine suggestions based on available data
                            let availableCuisines = getAvailableCuisines()
                            if !availableCuisines.isEmpty {
                                Text("Try: \(availableCuisines.prefix(3).joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Try: McDonald's, Subway, Starbucks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(searchResults.prefix(5), id: \.id) { restaurant in
                                Button(action: {
                                    selectedRestaurant = restaurant
                                    showSearchDropdown = false
                                    isSearchFieldFocused = false
                                }) {
                                    HStack(spacing: 12) {
                                        Text(restaurant.emoji)
                                            .font(.title2)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(restaurant.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            if let cuisine = restaurant.cuisine {
                                                Text(cuisine)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if restaurant.hasNutritionData {
                                            Text("📊")
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if searchResults.count > 5 {
                                Button("View All \(searchResults.count) Results") {
                                    showSearchScreen = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 8)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        searchWorkItem?.cancel()
        
        if newValue.isEmpty {
            searchResults = []
            isSearching = false
            showSearchDropdown = true
        } else {
            showSearchDropdown = true
            if newValue.count >= 2 {
                let workItem = DispatchWorkItem {
                    Task { @MainActor in
                        await performSearch()
                    }
                }
                searchWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
            }
        }
    }
    
    // MARK: - Enhanced Search with Dynamic Cuisines
    private func performSearch() {
        Task { @MainActor in
            isSearching = true
            
            var allResults: [Restaurant] = []
            
            // 1. Search static nutrition data (for exact chain matches)
            let staticMatches = RestaurantData.restaurantsWithNutritionData.filter { restaurantName in
                restaurantName.localizedCaseInsensitiveContains(searchText)
            }
            
            let staticResults = staticMatches.compactMap { name -> Restaurant? in
                Restaurant(
                    id: name.hashValue,
                    name: name,
                    latitude: locationManager.lastLocation?.coordinate.latitude ?? 0,
                    longitude: locationManager.lastLocation?.coordinate.longitude ?? 0,
                    address: "Multiple locations",
                    cuisine: getCuisineType(for: name),
                    openingHours: nil,
                    phone: nil,
                    website: nil,
                    type: "chain"
                )
            }
            
            allResults.append(contentsOf: staticResults)
            
            // 2. Search live restaurant data near user location
            if let userLocation = locationManager.lastLocation?.coordinate {
                do {
                    let nearbyRestaurants = try await OverpassAPIService().fetchAllNearbyRestaurants(
                        near: userLocation,
                        radius: 10.0
                    )
                    
                    // ENHANCED: Search by name, cuisine, and cuisine search terms
                    let liveMatches = nearbyRestaurants.filter { restaurant in
                        let searchLower = searchText.lowercased()
                        
                        // Check restaurant name
                        if restaurant.name.localizedCaseInsensitiveContains(searchText) {
                            return true
                        }
                        
                        // Check cuisine direct match
                        if let cuisine = restaurant.cuisine?.lowercased(),
                           cuisine.contains(searchLower) {
                            return true
                        }
                        
                        // Check cuisine search terms (dynamic)
                        if let cuisine = restaurant.cuisine {
                            let cuisineCategory = CuisineCategory(
                                name: cuisine,
                                count: 1,
                                emoji: getCuisineEmoji(for: cuisine),
                                searchTerms: generateSearchTerms(for: cuisine)
                            )
                            
                            return cuisineCategory.searchTerms.contains { term in
                                term.contains(searchLower) || searchLower.contains(term)
                            }
                        }
                        
                        return false
                    }
                    
                    // Sort by distance from user
                    let sortedLiveMatches = liveMatches.sorted { restaurant1, restaurant2 in
                        let distance1 = restaurant1.distanceFrom(userLocation)
                        let distance2 = restaurant2.distanceFrom(userLocation)
                        return distance1 < distance2
                    }
                    
                    allResults.append(contentsOf: sortedLiveMatches)
                    
                } catch {
                    print("❌ Live search failed: \(error.localizedDescription)")
                }
            }
            
            // 3. Remove duplicates and prioritize results
            var seenNames: Set<String> = []
            let uniqueResults = allResults.filter { restaurant in
                let key = restaurant.name.lowercased()
                if seenNames.contains(key) {
                    return false
                } else {
                    seenNames.insert(key)
                    return true
                }
            }
            
            // 4. Sort final results: nutrition data first, then by distance/relevance
            let finalResults = uniqueResults.sorted { restaurant1, restaurant2 in
                // Prioritize exact name matches
                let name1Match = restaurant1.name.localizedCaseInsensitiveContains(searchText)
                let name2Match = restaurant2.name.localizedCaseInsensitiveContains(searchText)
                
                if name1Match && !name2Match { return true }
                if !name1Match && name2Match { return false }
                
                // Then prioritize restaurants with nutrition data
                if restaurant1.hasNutritionData && !restaurant2.hasNutritionData {
                    return true
                } else if !restaurant1.hasNutritionData && restaurant2.hasNutritionData {
                    return false
                } else if let userLocation = locationManager.lastLocation?.coordinate {
                    // Sort by distance if both have same nutrition status
                    let distance1 = restaurant1.distanceFrom(userLocation)
                    let distance2 = restaurant2.distanceFrom(userLocation)
                    return distance1 < distance2
                } else {
                    return restaurant1.name < restaurant2.name
                }
            }
            
            searchResults = Array(finalResults.prefix(15))
            isSearching = false
        }
    }
    
    private func performCategorySearch(_ category: RestaurantCategory) {
        Task { @MainActor in
            isSearching = true
            
            let categoryRestaurants: [String]
            
            switch category {
            case .fastFood:
                categoryRestaurants = ["McDonald's", "Burger King", "KFC", "Taco Bell", "Subway", "Wendy's", "Dunkin' Donuts", "Domino's"]
            case .healthy:
                categoryRestaurants = ["Panera Bread", "Chipotle", "Subway"]
            case .highProtein:
                categoryRestaurants = ["KFC", "Chick-fil-A", "Popeyes", "Chipotle"]
            case .lowCarb:
                categoryRestaurants = ["Chipotle", "Five Guys", "In-N-Out Burger"]
            }
            
            let results = categoryRestaurants.compactMap { name -> Restaurant? in
                guard RestaurantData.restaurantsWithNutritionData.contains(name) else { return nil }
                return Restaurant(
                    id: name.hashValue,
                    name: name,
                    latitude: locationManager.lastLocation?.coordinate.latitude ?? 0,
                    longitude: locationManager.lastLocation?.coordinate.longitude ?? 0,
                    address: "Multiple locations",
                    cuisine: getCuisineType(for: name),
                    openingHours: nil,
                    phone: nil,
                    website: nil,
                    type: "node"
                )
            }
            
            searchResults = results
            isSearching = false
        }
    }
    
    private func performCuisineSearch(_ cuisine: CuisineCategory) {
        Task { @MainActor in
            isSearching = true
            
            if let userLocation = locationManager.lastLocation?.coordinate {
                do {
                    let nearbyRestaurants = try await OverpassAPIService().fetchAllNearbyRestaurants(
                        near: userLocation,
                        radius: 10.0
                    )
                    
                    let cuisineMatches = nearbyRestaurants.filter { restaurant in
                        guard let restaurantCuisine = restaurant.cuisine?.lowercased() else { return false }
                        
                        // Check if restaurant cuisine matches any search terms
                        return cuisine.searchTerms.contains { term in
                            restaurantCuisine.contains(term) || term.contains(restaurantCuisine)
                        }
                    }
                    
                    let sortedResults = cuisineMatches.sorted { restaurant1, restaurant2 in
                        let distance1 = restaurant1.distanceFrom(userLocation)
                        let distance2 = restaurant2.distanceFrom(userLocation)
                        return distance1 < distance2
                    }
                    
                    searchResults = Array(sortedResults.prefix(15))
                    isSearching = false
                    
                } catch {
                    print("❌ Cuisine search failed: \(error.localizedDescription)")
                    searchResults = []
                    isSearching = false
                }
            } else {
                searchResults = []
                isSearching = false
            }
        }
    }
    
    private func getCuisineType(for restaurantName: String) -> String {
        let fastFood = ["McDonald's", "Burger King", "KFC", "Taco Bell", "Wendy's"]
        let coffee = ["Starbucks", "Dunkin' Donuts"]
        
        if fastFood.contains(restaurantName) { return "Fast Food" }
        if coffee.contains(restaurantName) { return "Coffee" }
        return "Restaurant"
    }

    // MARK: - Dynamic Cuisine Discovery
    private func getAvailableCuisines() -> [String] {
        // Get all unique cuisines from current restaurants
        let allCuisines = Set(mapViewModel.restaurants.compactMap { $0.cuisine?.lowercased() })
        
        // Clean and normalize cuisine names
        let cleanedCuisines = allCuisines.compactMap { cuisine -> String? in
            let cleaned = cuisine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty && cleaned.count > 2 else { return nil }
            
            // Skip overly generic terms
            let skipTerms = ["food", "restaurant", "dining", "other", "various", "mixed"]
            guard !skipTerms.contains(cleaned) else { return nil }
            
            return cleaned.capitalized
        }
        
        // Sort by popularity (frequency) and alphabetically
        return Array(cleanedCuisines).sorted()
    }
    
    private func getPopularCuisines() -> [CuisineCategory] {
        let cuisineFrequency = Dictionary(grouping: mapViewModel.restaurants.compactMap { $0.cuisine?.lowercased() }, by: { $0 })
            .mapValues { $0.count }
        
        // Get most frequent cuisines
        let sortedCuisines = cuisineFrequency.sorted { $0.value > $1.value }
        
        // Convert to CuisineCategory objects with smart emoji assignment
        return sortedCuisines.prefix(12).compactMap { (cuisine, count) in
            let cleanedName = cuisine.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
            guard !cleanedName.isEmpty && count >= 2 else { return nil }
            
            return CuisineCategory(
                name: cleanedName,
                count: count,
                emoji: getCuisineEmoji(for: cleanedName),
                searchTerms: generateSearchTerms(for: cleanedName)
            )
        }
    }
    
    private func getCuisineEmoji(for cuisine: String) -> String {
        let name = cuisine.lowercased()
        
        // Smart emoji mapping based on cuisine keywords
        if name.contains("pizza") { return "🍕" }
        if name.contains("chinese") { return "🥡" }
        if name.contains("japanese") || name.contains("sushi") { return "🍣" }
        if name.contains("mexican") { return "🌮" }
        if name.contains("italian") { return "🍝" }
        if name.contains("thai") { return "🍜" }
        if name.contains("indian") { return "🍛" }
        if name.contains("american") || name.contains("burger") { return "🍔" }
        if name.contains("french") { return "🥖" }
        if name.contains("mediterranean") { return "🫒" }
        if name.contains("seafood") || name.contains("fish") { return "🐟" }
        if name.contains("steak") || name.contains("barbecue") || name.contains("bbq") { return "🥩" }
        if name.contains("chicken") { return "🍗" }
        if name.contains("sandwich") || name.contains("deli") { return "🥪" }
        if name.contains("coffee") || name.contains("cafe") { return "☕" }
        if name.contains("bakery") || name.contains("pastry") { return "🧁" }
        if name.contains("ice") || name.contains("cream") { return "🍦" }
        if name.contains("vegetarian") || name.contains("vegan") { return "🥗" }
        if name.contains("korean") { return "🍲" }
        if name.contains("vietnamese") { return "🍜" }
        if name.contains("middle") || name.contains("arabic") { return "🥙" }
        if name.contains("german") { return "🌭" }
        
        // Fallback emoji
        return "🍽️"
    }
    
    private func generateSearchTerms(for cuisine: String) -> [String] {
        let base = cuisine.lowercased()
        var terms = [base]
        
        // Add variations and synonyms
        switch base {
        case "chinese":
            terms.append(contentsOf: ["asian", "cantonese", "szechuan", "mandarin"])
        case "mexican":
            terms.append(contentsOf: ["latin", "tex-mex", "burrito", "taco"])
        case "italian":
            terms.append(contentsOf: ["pasta", "pizza", "mediterranean"])
        case "japanese":
            terms.append(contentsOf: ["sushi", "asian", "ramen", "hibachi"])
        case "american":
            terms.append(contentsOf: ["burger", "grill", "diner", "fast food"])
        case "indian":
            terms.append(contentsOf: ["curry", "tandoori", "asian"])
        case "thai":
            terms.append(contentsOf: ["asian", "pad thai", "curry"])
        case "mediterranean":
            terms.append(contentsOf: ["greek", "middle eastern", "falafel"])
        case "fast food":
            terms.append(contentsOf: ["quick", "drive thru", "takeout"])
        case "coffee":
            terms.append(contentsOf: ["cafe", "espresso", "latte"])
        default:
            break
        }
        
        return terms
    }

    private var categoriesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                // Dynamic categories from MainCategoryManager
                ForEach(mainCategoryManager.myCategories.prefix(3), id: \.id) { userCategory in
                    // FIXED: Navigate to FlexibleCategoryListView for ALL categories
                    NavigationLink(destination: FlexibleCategoryListView(
                        userCategory: userCategory,
                        isPresented: .constant(true)
                    )) {
                        MinimalCategoryCard(
                            title: userCategory.name,
                            count: nil,
                            icon: userCategory.icon
                        )
                    }
                }
                
                // Add "More" button if we have less than maximum categories or available categories to add
                if mainCategoryManager.myCategories.count < 3 || !mainCategoryManager.getAvailableCategoriesNotInMy().isEmpty {
                    Button(action: {
                        showingCustomCategories = true
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
    }
    
    // MARK: - Saved Menus Section
    private var savedMenusView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Saved Menus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                if !savedMenuManager.savedMenus.isEmpty {
                    Button(action: {
                        HapticService.shared.toggle()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditingMenus.toggle()
                        }
                    }) {
                        Text(isEditingMenus ? "Done" : "Edit")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }

            if savedMenuManager.savedMenus.isEmpty {
                savedMenusEmptyState
            } else {
                savedMenusCarousel
            }
        }
    }

    private var savedMenusEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("No Saved Menus")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Scan a menu and save your analysis to see it here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                HapticService.shared.menuScan()
                
                // Track menu scanner usage from saved menus empty state
                AnalyticsService.shared.trackMenuScannerUsage(
                    restaurantName: nil,
                    source: "saved_menus_empty_state",
                    hasNutritionData: false,
                    cuisine: nil
                )
                
                showingMenuPhotoCapture = true
            }) {
                Text("Scan Your First Menu")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var savedMenusCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(savedMenuManager.savedMenus) { savedMenu in
                    SavedMenuCard(
                        savedMenu: savedMenu,
                        isEditMode: isEditingMenus,
                        onTap: {
                            if !isEditingMenus {
                                selectedSavedMenu = savedMenu
                            }
                        },
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                savedMenuManager.deleteMenu(savedMenu)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 200)
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
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
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

    struct CategorySearchDropdownButton: View {
        let title: String
        let subtitle: String
        let icon: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Text(icon)
                        .font(.title2)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
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
                        .font(.subheadline)
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

// MARK: - Auto Sliding Carousel
struct AutoSlidingCarousel: View {
    @Binding var showingMenuPhotoCapture: Bool
    @Binding var showingMapScreen: Bool
    @Binding var showingDietaryChat: Bool
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @State private var isActive = true // Track if view is active
    
    private let autoSlideInterval: TimeInterval = 3.0 // 3 seconds
    
    var carouselItems: [CarouselItem] {
        [
            CarouselItem(
                id: 0,
                title: "Scan Menu",
                subtitle: "Analyze nutrition from photos",
                icon: "camera.fill",
                iconColor: .blue,
                backgroundColor: Color.blue.opacity(0.1),
                action: {
                    HapticService.shared.menuScan()
                    showingMenuPhotoCapture = true
                }
            ),
            CarouselItem(
                id: 1,
                title: "MealMap",
                subtitle: "Find restaurants near you",
                icon: "map.fill",
                iconColor: .green,
                backgroundColor: Color.green.opacity(0.1),
                action: {
                    HapticService.shared.navigate()
                    showingMapScreen = true
                }
            ),
            CarouselItem(
                id: 2,
                title: "Meal Chat",
                subtitle: "Get personalized nutrition advice",
                icon: "message.circle.fill",
                iconColor: .purple,
                backgroundColor: Color.purple.opacity(0.1),
                action: {
                    HapticService.shared.sheetPresent()
                    showingDietaryChat = true
                }
            )
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Carousel Container
            TabView(selection: $currentIndex) {
                ForEach(carouselItems, id: \.id) { item in
                    CarouselItemView(item: item)
                        .tag(item.id)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 100)
            .clipped()
            .onChange(of: currentIndex) { oldValue, newValue in
                // Handle manual swipe - restart timer from new position
                if oldValue != newValue && isActive {
                    restartTimer()
                }
            }
            
            // Custom Page Indicators
            HStack(spacing: 8) {
                ForEach(0..<carouselItems.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }
            .padding(.top, 12)
        }
        .onAppear {
            isActive = true
            startAutoSlide()
        }
        .onDisappear {
            isActive = false
            stopAutoSlide()
        }
        // Add additional safety for when app goes to background
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            stopAutoSlide()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if isActive {
                startAutoSlide()
            }
        }
    }
    
    private func startAutoSlide() {
        // Ensure we don't have multiple timers
        stopAutoSlide()
        
        timer = Timer.scheduledTimer(withTimeInterval: autoSlideInterval, repeats: true) { _ in
            guard isActive else {
                stopAutoSlide()
                return
            }
            
            withAnimation(.easeInOut(duration: 0.5)) {
                moveToNextIndex()
            }
        }
    }
    
    private func stopAutoSlide() {
        timer?.invalidate()
        timer = nil
    }
    
    private func restartTimer() {
        guard isActive else { return }
        stopAutoSlide()
        // Add small delay to prevent immediate restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.isActive {
                self.startAutoSlide()
            }
        }
    }
    
    private func moveToNextIndex() {
        currentIndex = (currentIndex + 1) % carouselItems.count
    }
}

// MARK: - Supporting Models and Views
struct CuisineCategory {
    let name: String
    let count: Int
    let emoji: String
    let searchTerms: [String]
}

struct CuisineSearchButton: View {
    let cuisine: CuisineCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(cuisine.emoji)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(cuisine.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if cuisine.count > 0 {
                        Text("\(cuisine.count) nearby")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct CarouselItem {
    let id: Int
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let backgroundColor: Color
    let action: () -> Void
}

struct CarouselItemView: View {
    let item: CarouselItem
    
    var body: some View {
        Button(action: item.action) {
            HStack(spacing: 16) {
                // Icon Container
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(item.backgroundColor)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(item.iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(item.subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Food Type Carousel Component

struct FoodTypeCarousel: View {
    @ObservedObject var mapViewModel: MapViewModel
    
    let foodTypes: [FoodType] = [
        FoodType(name: "Pizza", emoji: "🍕", searchTerms: ["pizza"]),
        FoodType(name: "Sushi", emoji: "🍣", searchTerms: ["sushi", "japanese"]),
        FoodType(name: "Chinese", emoji: "🥡", searchTerms: ["chinese"]),
        FoodType(name: "Thai", emoji: "🍜", searchTerms: ["thai"]),
        FoodType(name: "Indian", emoji: "🍛", searchTerms: ["indian"]),
        FoodType(name: "Mexican", emoji: "🌮", searchTerms: ["mexican", "taco", "burrito"]),
        FoodType(name: "Burgers", emoji: "🍔", searchTerms: ["burger", "fast food"]),
        FoodType(name: "Coffee", emoji: "☕", searchTerms: ["coffee", "cafe"]),
        FoodType(name: "Sandwiches", emoji: "🥪", searchTerms: ["sandwich", "sub", "deli"]),
        FoodType(name: "BBQ", emoji: "🍖", searchTerms: ["bbq", "barbecue", "grill"]),
        FoodType(name: "Seafood", emoji: "🦐", searchTerms: ["seafood", "fish"]),
        FoodType(name: "Healthy", emoji: "🥗", searchTerms: ["salad", "healthy", "fresh"])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Food Types")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(foodTypes, id: \.name) { foodType in
                        NavigationLink(destination: FoodTypeCategoryView(
                            foodType: foodType,
                            mapViewModel: mapViewModel
                        )) {
                            FoodTypeCard(foodType: foodType)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

struct FoodType {
    let name: String
    let emoji: String
    let searchTerms: [String]
}

struct FoodTypeCard: View {
    let foodType: FoodType
    
    var body: some View {
        VStack(spacing: 8) {
            // Emoji circle with background
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 60, height: 60)
                
                Text(foodType.emoji)
                    .font(.system(size: 28))
            }
            
            // Food type name
            Text(foodType.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
        .padding(.vertical, 8)
    }
}

struct FoodTypeCategoryView: View {
    let foodType: FoodType
    @ObservedObject var mapViewModel: MapViewModel
    
    @State private var restaurants: [Restaurant] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRestaurant: Restaurant?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(foodType.emoji)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(foodType.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(restaurants.count) restaurants near you")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            
            // Restaurant list
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Finding \(foodType.name) restaurants...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Error Loading Restaurants")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        loadRestaurants()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else if restaurants.isEmpty {
                VStack(spacing: 16) {
                    Text(foodType.emoji)
                        .font(.system(size: 50))
                    
                    Text("No \(foodType.name) restaurants found nearby")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Try expanding your search radius or check back later")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                List {
                    ForEach(restaurants, id: \.id) { restaurant in
                        Button(action: {
                            selectedRestaurant = restaurant
                        }) {
                            RestaurantRowView(restaurant: restaurant)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color(.systemBackground))
                    }
                }
                .listStyle(.plain)
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadRestaurants()
        }
        .sheet(item: $selectedRestaurant) { restaurant in
            RestaurantDetailView(
                restaurant: restaurant,
                isPresented: .constant(true),
                selectedCategory: nil
            )
        }
    }
    
    private func loadRestaurants() {
        guard let userLocation = LocationManager().lastLocation?.coordinate else {
            errorMessage = "Location not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Get all nearby restaurants
                let allRestaurants = try await OverpassAPIService().fetchAllNearbyRestaurants(
                    near: userLocation,
                    radius: 5.0
                )
                
                // Filter by food type
                let filteredRestaurants = allRestaurants.filter { restaurant in
                    let name = restaurant.name.lowercased()
                    let cuisine = restaurant.cuisine?.lowercased() ?? ""
                    
                    return foodType.searchTerms.contains { term in
                        name.contains(term) || cuisine.contains(term)
                    }
                }
                
                // Sort by distance
                let sortedRestaurants = filteredRestaurants.sorted { restaurant1, restaurant2 in
                    let distance1 = restaurant1.distanceFrom(userLocation)
                    let distance2 = restaurant2.distanceFrom(userLocation)
                    return distance1 < distance2
                }
                
                await MainActor.run {
                    self.restaurants = Array(sortedRestaurants.prefix(50))
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct RestaurantRowView: View {
    let restaurant: Restaurant
    
    var body: some View {
        HStack(spacing: 16) {
            // Restaurant emoji/icon
            Text(restaurant.emoji)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            // Restaurant info
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let cuisine = restaurant.cuisine {
                    Text(cuisine)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let address = restaurant.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Nutrition badge
            if restaurant.hasNutritionData {
                Text("📊")
                    .font(.caption)
            }
            
            // Distance (if available)
            if let userLocation = LocationManager().lastLocation?.coordinate {
                let distance = restaurant.distanceFrom(userLocation)
                Text(String(format: "%.1f mi", distance))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Saved Menu Card

struct SavedMenuCard: View {
    let savedMenu: SavedMenuAnalysis
    let isEditMode: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            // Main card content
            Button(action: onTap) {
                VStack(spacing: 0) {
                    // Header with menu name and date
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(savedMenu.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Spacer()

                            if !isEditMode {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text(savedMenu.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    // Nutrition summary
                    VStack(spacing: 8) {
                        HStack(spacing: 16) {
                            NutritionStat(label: "Cal", value: "\(Int(savedMenu.totalCalories))", color: .red)
                            NutritionStat(label: "Protein", value: "\(Int(savedMenu.totalProtein))g", color: .blue)
                            NutritionStat(label: "Carbs", value: "\(Int(savedMenu.totalCarbs))g", color: .orange)
                            NutritionStat(label: "Fat", value: "\(Int(savedMenu.totalFat))g", color: .green)
                        }

                        Text(savedMenu.displaySummary)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    // Bottom accent bar
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 4)
                }
            }
            .buttonStyle(.plain)
            .disabled(isEditMode)

            // Delete button overlay (only visible in edit mode)
            if isEditMode {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .offset(x: 8, y: -8)
                    }
                    Spacer()
                }
            }
        }
        .frame(width: 200)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct NutritionStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}