import SwiftUI
import Combine
import MapKit

struct HomeScreen: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var mapViewModel = MapViewModel()
    @ObservedObject private var nutritionManager = NutritionDataManager.shared
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
    @State private var showingEditProfile = false
    @State private var showingCustomCategories = false
    @State private var showingDietaryChat = false
    @State private var showingCarouselMapScreen = false
    @State private var showingCarouselDietaryChat = false
    
    // Category navigation states
    @State private var selectedCategory: UserCategory?
    @State private var showingCategoryView = false
    
    @FocusState private var isSearchFieldFocused: Bool
    @State private var debounceTimer: Timer?

    private let categoryMapping: [String: RestaurantCategory] = [
        "Fast Food": .fastFood,
        "Healthy": .healthy,
        "High Protein": .highProtein
    ]

    private var scanMenuCard: some View {
        AutoSlidingCarousel(
            showingMapScreen: $showingCarouselMapScreen,
            showingDietaryChat: $showingCarouselDietaryChat
        )
    }

    var body: some View {
        // NO NavigationView or NavigationStack - pure content view
        Group {
            if showMainLoadingScreen {
                fullScreenLoadingView
            } else {
                mainContentView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        // iPhone: Extend background to edges but respect safe area for content
        .ignoresSafeArea(.container, edges: DynamicSizing.isIPad ? .all : [])
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
            NavigationView {
                RestaurantDetailView(
                    restaurant: restaurant,
                    isPresented: Binding(
                        get: { selectedRestaurant != nil },
                        set: { if !$0 { selectedRestaurant = nil } }
                    ),
                    selectedCategory: nil
                )
            }
        }
        .fullScreenCover(isPresented: $showingMapScreen) {
            MapScreen(viewModel: mapViewModel)
        }
        .fullScreenCover(isPresented: $showingCarouselMapScreen) {
            MapScreen(viewModel: mapViewModel)
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
        .sheet(isPresented: $showingCategoryView) {
            if let category = selectedCategory {
                NavigationView {
                    FlexibleCategoryListView(
                        userCategory: category,
                        isPresented: $showingCategoryView
                    )
                }
            }
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
        GeometryReader { geometry in
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
            // Add safe area padding for iPhone
            .padding(.top, DynamicSizing.contentTopOffset(geometry: geometry))
        }
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
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DynamicSizing.isIPad ? 
                       DynamicSizing.spacing(50, geometry: geometry) : // iPad: Keep larger spacing
                       DynamicSizing.spacing(25, geometry: geometry)   // iPhone: Reduce spacing significantly
                ) {
                    headerView(geometry: geometry)
                    searchBarView(geometry: geometry)
                    
                    // Only show other content when search dropdown is not active
                    if !showSearchDropdown {
                        FoodTypeCarousel(mapViewModel: mapViewModel)
                            .padding(.bottom, DynamicSizing.isIPad ? 
                                    DynamicSizing.spacing(20, geometry: geometry) :
                                    DynamicSizing.spacing(5, geometry: geometry)) // Less bottom padding on iPhone
                        
                        scanMenuCard
                            .padding(.vertical, DynamicSizing.isIPad ?
                                    DynamicSizing.spacing(10, geometry: geometry) :
                                    DynamicSizing.spacing(5, geometry: geometry)) // Less vertical padding on iPhone
                        
                        categoriesView(geometry: geometry)
                    }
                }
                .padding(.horizontal, DynamicSizing.spacing(20, geometry: geometry))
                .padding(.vertical, DynamicSizing.spacing(20, geometry: geometry))
                // Smart top padding that respects safe areas on iPhone - INCREASED to move content down
                .padding(.top, DynamicSizing.isIPad ? 
                        DynamicSizing.contentTopOffset(geometry: geometry) :           // iPad: unchanged
                        DynamicSizing.contentTopOffset(geometry: geometry) + 20)      // iPhone: +20pt extra
                .frame(maxWidth: DynamicSizing.contentWidth(geometry: geometry))
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemBackground))
            .onTapGesture {
                if showSearchDropdown {
                    showSearchDropdown = false
                    isSearchFieldFocused = false
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // iPhone: Respect safe areas, iPad: Use full screen
        .ignoresSafeArea(.container, edges: DynamicSizing.isIPad ? [.top, .bottom] : [])
    }

    private func headerView(geometry: GeometryProxy) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DynamicSizing.spacing(4, geometry: geometry)) {
                Text("MealMap")
                    .dynamicFont(28, weight: .bold)
                    .foregroundColor(.primary)

                if !mapViewModel.currentAreaName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("📍 \(mapViewModel.currentAreaName)")
                        .dynamicFont(14)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: DynamicSizing.spacing(12, geometry: geometry)) {
                let buttonSize = DynamicSizing.iconSize(44)
                let iconSize = DynamicSizing.iconSize(18)
                
                Button(action: {
                    HapticService.shared.navigate()
                    showingMapScreen = true
                }) {
                    Image(systemName: "map")
                        .font(.system(size: iconSize))
                        .foregroundColor(.blue)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(DynamicSizing.cornerRadius(12))
                }
                
                // Dietary Chat Button
                Button(action: {
                    HapticService.shared.sheetPresent()
                    showingDietaryChat = true
                }) {
                    Image(systemName: "message.circle")
                        .font(.system(size: iconSize))
                        .foregroundColor(.purple)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(DynamicSizing.cornerRadius(12))
                }

                Button(action: {
                    HapticService.shared.sheetPresent()
                    showingEditProfile = true
                }) {
                    Image(systemName: "person.circle")
                        .font(.system(size: iconSize))
                        .foregroundColor(.blue)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(DynamicSizing.cornerRadius(12))
                }
            }
        }
    }

    private func searchBarView(geometry: GeometryProxy) -> some View {
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
                searchDropdownView(geometry: geometry)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSearchDropdown)
    }
    
    private func searchDropdownView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
            
            VStack(spacing: 16) {
                if searchText.isEmpty {
                    // Popular Searches and other content...
                    Text("Popular searches would go here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
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
    
    private func performSearch() {
        Task { @MainActor in
            isSearching = true
            // Add your search logic here
            searchResults = []
            isSearching = false
        }
    }

    private func categoriesView(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: DynamicSizing.isIPad ?
               DynamicSizing.spacing(20, geometry: geometry) : // iPad: Keep current spacing
               DynamicSizing.spacing(12, geometry: geometry)   // iPhone: Tighter spacing
        ) {
            Text("Categories")
                .dynamicFont(22, weight: .semibold)
                .foregroundColor(.primary)
            
            // Dynamic columns based on screen size with better spacing
            let columns = DynamicSizing.gridColumns(baseColumns: 2, geometry: geometry)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DynamicSizing.spacing(16, geometry: geometry)), count: columns),
                spacing: DynamicSizing.isIPad ?
                DynamicSizing.spacing(20, geometry: geometry) : // iPad: Keep current spacing  
                DynamicSizing.spacing(12, geometry: geometry)   // iPhone: Tighter grid spacing
            ) {
                // Dynamic categories from MainCategoryManager  
                ForEach(mainCategoryManager.myCategories.prefix(DynamicSizing.isIPad ? 7 : 3), id: \.id) { userCategory in
                    Button(action: {
                        HapticService.shared.buttonPress()
                        selectedCategory = userCategory
                        showingCategoryView = true
                    }) {
                        MinimalCategoryCard(
                            title: userCategory.name,
                            count: nil,
                            icon: userCategory.icon,
                            geometry: geometry
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Add "More" button
                if mainCategoryManager.myCategories.count < (DynamicSizing.isIPad ? 7 : 3) || !mainCategoryManager.getAvailableCategoriesNotInMy().isEmpty {
                    Button(action: {
                        HapticService.shared.buttonPress()
                        showingCustomCategories = true
                    }) {
                        MinimalCategoryCard(
                            title: "More",
                            count: nil,
                            icon: "•••",
                            geometry: geometry
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // Add this function to handle category presentation
    private func presentCategoryView(_ category: UserCategory) {
        // For now, we'll use a sheet presentation
        // You could add a @State variable to track the selected category
        // and present it as a sheet or fullScreenCover
        print("Category tapped: \(category.name)")
        // TODO: Add sheet presentation for category view
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

            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                Task { @MainActor in
                    self.mapViewModel.updateMapRegion(self.mapViewModel.region)
                }
            }
        }
    }

    struct MinimalCategoryCard: View {
        let title: String
        let count: Int?
        let icon: String
        let geometry: GeometryProxy
        
        var body: some View {
            VStack(spacing: DynamicSizing.spacing(12, geometry: geometry)) {
                Text(icon)
                    .font(.system(size: DynamicSizing.iconSize(32)))
                
                VStack(spacing: DynamicSizing.spacing(4, geometry: geometry)) {
                    Text(title)
                        .dynamicFont(16, weight: .semibold)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DynamicSizing.cardHeight(120, geometry: geometry))
            .background(Color(.systemBackground))
            .cornerRadius(DynamicSizing.cornerRadius(16))
            .overlay(
                RoundedRectangle(cornerRadius: DynamicSizing.cornerRadius(16))
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Auto Sliding Carousel
struct AutoSlidingCarousel: View {
    @Binding var showingMapScreen: Bool
    @Binding var showingDietaryChat: Bool
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @State private var isActive = true
    
    private let autoSlideInterval: TimeInterval = 3.0
    
    var carouselItems: [CarouselItem] {
        [
            CarouselItem(
                id: 0,
                title: "Meal Map",
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
                id: 1,
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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TabView(selection: $currentIndex) {
                    ForEach(carouselItems, id: \.id) { item in
                        CarouselItemView(item: item, geometry: geometry)
                            .tag(item.id)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: DynamicSizing.cardHeight(100, geometry: geometry))
                
                HStack(spacing: DynamicSizing.spacing(8, geometry: geometry)) {
                    ForEach(0..<carouselItems.count, id: \.self) { index in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentIndex = index
                            }
                        }) {
                            Circle()
                                .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: DynamicSizing.iconSize(8), height: DynamicSizing.iconSize(8))
                                .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.3), value: currentIndex)
                        }
                    }
                }
                .padding(.top, DynamicSizing.spacing(12, geometry: geometry))
            }
        }
        .frame(height: DynamicSizing.cardHeight(140))
        .onAppear {
            isActive = true
            startAutoSlide()
        }
        .onDisappear {
            isActive = false
            stopAutoSlide()
        }
    }
    
    private func startAutoSlide() {
        stopAutoSlide()
        timer = Timer.scheduledTimer(withTimeInterval: autoSlideInterval, repeats: true) { _ in
            guard isActive else {
                stopAutoSlide()
                return
            }
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIndex = (currentIndex + 1) % carouselItems.count
            }
        }
    }
    
    private func stopAutoSlide() {
        timer?.invalidate()
        timer = nil
    }
}

struct CarouselItemView: View {
    let item: CarouselItem
    let geometry: GeometryProxy
    
    var body: some View {
        Button(action: {
            HapticService.shared.lightImpact()
            item.action()
        }) {
            HStack(spacing: DynamicSizing.spacing(16, geometry: geometry)) {
                ZStack {
                    RoundedRectangle(cornerRadius: DynamicSizing.cornerRadius(16))
                        .fill(item.backgroundColor)
                        .frame(
                            width: DynamicSizing.iconSize(60),
                            height: DynamicSizing.iconSize(60)
                        )
                    
                    Image(systemName: item.icon)
                        .font(.system(size: DynamicSizing.iconSize(24), weight: .semibold))
                        .foregroundColor(item.iconColor)
                }
                
                VStack(alignment: .leading, spacing: DynamicSizing.spacing(4, geometry: geometry)) {
                    Text(item.title)
                        .dynamicFont(18, weight: .bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(item.subtitle)
                        .dynamicFont(14, weight: .medium)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: DynamicSizing.iconSize(16), weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, DynamicSizing.spacing(20, geometry: geometry))
            .padding(.vertical, DynamicSizing.spacing(16, geometry: geometry))
            .background(
                RoundedRectangle(cornerRadius: DynamicSizing.cornerRadius(20))
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: .black.opacity(0.08), 
                        radius: DynamicSizing.spacing(8, geometry: geometry), 
                        x: 0, 
                        y: DynamicSizing.spacing(4, geometry: geometry)
                    )
            )
            .padding(.horizontal, DynamicSizing.spacing(16, geometry: geometry))
        }
        .buttonStyle(.plain)
    }
}

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
        VStack(alignment: .leading, spacing: DynamicSizing.isIPad ? 
               DynamicSizing.spacing(16) : DynamicSizing.spacing(12)) { // Tighter spacing on iPhone
            Text("Food Types")
                .dynamicFont(22, weight: .semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, DynamicSizing.spacing(20))
            
            if DynamicSizing.isIPad {
                // iPad: Use responsive grid with dynamic columns
                GeometryReader { geometry in
                    let columns = DynamicSizing.gridColumns(baseColumns: 6, geometry: geometry)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: DynamicSizing.spacing(16, geometry: geometry)), count: columns),
                        spacing: DynamicSizing.spacing(20, geometry: geometry)
                    ) {
                        ForEach(foodTypes.prefix(12), id: \.name) { foodType in
                            FoodTypeCard(foodType: foodType)
                        }
                    }
                    .padding(.horizontal, DynamicSizing.spacing(20, geometry: geometry))
                    .padding(.bottom, DynamicSizing.spacing(20, geometry: geometry))
                }
            } else {
                // iPhone: Horizontal scroll with tighter spacing
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DynamicSizing.spacing(16)) { // Reduced from 20 to 16
                        ForEach(foodTypes, id: \.name) { foodType in
                            FoodTypeCard(foodType: foodType)
                        }
                    }
                    .padding(.horizontal, DynamicSizing.spacing(20))
                    .padding(.bottom, DynamicSizing.spacing(8)) // Reduced from 16 to 8
                }
            }
        }
        .frame(height: DynamicSizing.isIPad ? 
               DynamicSizing.cardHeight(280) : // iPad height unchanged
               DynamicSizing.cardHeight(140)   // iPhone: Reduced from 200 to 140
        )
    }
}

struct FoodTypeCard: View {
    let foodType: FoodType
    @State private var showingFoodTypeView = false
    
    var body: some View {
        Button(action: {
            HapticService.shared.lightImpact()
            showingFoodTypeView = true
        }) {
            VStack(spacing: DynamicSizing.spacing(8)) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(
                            width: DynamicSizing.iconSize(60),
                            height: DynamicSizing.iconSize(60)
                        )
                    
                    Text(foodType.emoji)
                        .font(.system(size: DynamicSizing.iconSize(28)))
                }
                
                Text(foodType.name)
                    .dynamicFont(12, weight: .medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: DynamicSizing.cardWidth(80))
            .padding(.vertical, DynamicSizing.spacing(8))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingFoodTypeView) {
            NavigationView {
                FoodTypeCategoryView(
                    foodType: foodType,
                    mapViewModel: MapViewModel()
                )
            }
        }
    }
}

struct FoodType {
    let name: String
    let emoji: String
    let searchTerms: [String]
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

#Preview {
    HomeScreen()
}