import SwiftUI
import CoreLocation
import MapKit

struct HomeScreen: View {
    @StateObject private var locationManager = LocationManager()
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
    @State private var showingMapScreen = false
    @State private var showingMenuPhotoCapture = false
    @State private var showingNutritionixSettings = false
    @State private var showingEditProfile = false
    @State private var showingCustomCategories = false
    @State private var selectedSavedMenu: SavedMenuAnalysis?
    @State private var isEditingMenus = false

    private let categoryMapping: [String: RestaurantCategory] = [
        "Fast Food": .fastFood,
        "Healthy": .healthy,
        "High Protein": .highProtein
    ]

    private var scanMenuCard: some View {
        Button(action: {
            HapticService.shared.menuScan()
            
            // Track menu scanner usage from home screen
            AnalyticsService.shared.trackMenuScannerUsage(
                restaurantName: nil,
                source: "home_screen",
                hasNutritionData: false,
                cuisine: nil
            )
            
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
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
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
        .sheet(isPresented: $showingMenuPhotoCapture) {
            MenuPhotoCaptureView(autoTriggerCamera: true)
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
                savedMenusView
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("MealMap")
        .navigationBarHidden(true)
        .background(Color(.systemBackground))
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
        Button {
            HapticService.shared.search()
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
    
    // Helper function to map UserCategory to RestaurantCategory
    private func mapUserCategoryToRestaurantCategory(_ userCategory: UserCategory) -> RestaurantCategory? {
        switch userCategory.id {
        case "fastFood":
            return .fastFood
        case "healthy":
            return .healthy
        case "highProtein":
            return .highProtein
        default:
            // Custom categories or additional categories that don't map directly
            return nil
        }
    }

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

enum QuickAction {
    case scanMenu
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}