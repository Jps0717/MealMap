import SwiftUI
import MapKit
import CoreLocation

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Binding var isPresented: Bool
    let selectedCategory: RestaurantCategory?
    @State private var animateIn = false
    @State private var hasNutritionData: Bool = false
    @ObservedObject private var nutritionManager = NutritionDataManager.shared
    @State private var viewState: ViewState = .initializing
    @State private var searchText = ""
    @State private var selectedMenuCategory: MenuCategory = .all
    @State private var showingMenuScanner = false
    @State private var showSlowLoadingTip = false
    @State private var slowLoadingTimer: Timer?
    @State private var showingSignIn = false

    @StateObject private var authService = AuthenticationManager.shared
    
    // SIMPLIFIED: Use RestaurantMapScoringService for on-demand scoring
    @StateObject private var scoringService = RestaurantMapScoringService.shared
    @State private var restaurantMapScore: RestaurantMapScore?
    @State private var isCalculatingScore = false
    @State private var showingScoreLegend = false
    @Environment(\.dismiss) private var dismiss

    enum MenuCategory: String, CaseIterable {
        case all = "All"
        case food = "Food"
        case drinks = "Drinks"
        case desserts = "Desserts"
    }

    enum ViewState: Equatable {
        case initializing
        case loading
        case loaded
        case noData
        case error(String)
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    restaurantHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .background(Color(.systemBackground))

                    contentView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticService.shared.buttonPress()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(restaurant.name)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if let website = restaurant.website, let url = URL(string: website) {
                            Button {
                                trackWebsiteClick(restaurantName: restaurant.name, website: website)
                                UIApplication.shared.open(url)
                            } label: {
                                Label("Visit Website", systemImage: "globe")
                            }
                        }

                        if shouldShowScoring {
                            Button {
                                showingScoreLegend = true
                            } label: {
                                Label("Scoring Guide", systemImage: "questionmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingScoreLegend) {
            DietaryRatingLegendView()
        }
        .onAppear { 
            setupView() 
        }
        .onDisappear { cleanup() }
        .onChange(of: nutritionManager.currentRestaurantData) { _, newData in 
            debugLog(" DATA CHANGE: \(newData?.restaurantName ?? "nil")")
            updateViewStateBasedOnData()
        }
        .onChange(of: nutritionManager.errorMessage) { _, newError in 
            if let error = newError {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewState = .error(error)
                    stopSlowLoadingTimer()
                }
            }
        }
        .onChange(of: nutritionManager.isLoading) { _, isLoading in
            if isLoading && viewState != .loading {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewState = .loading
                    startSlowLoadingTimer()
                }
            }
        }
    }
    
    private var shouldShowScoring: Bool {
        // Always show scoring section if restaurant has nutrition data (to encourage sign-up)
        return hasNutritionData
    }
    
    // SIMPLIFIED: Calculate restaurant score on-demand using existing service
    private func calculateRestaurantScore() {
        guard hasNutritionData && restaurantMapScore == nil && !isCalculatingScore else { return }
        
        debugLog(" Calculating on-demand score for \(restaurant.name)")
        isCalculatingScore = true
        
        Task {
            let score = await scoringService.calculateScoreForRestaurant(restaurant)
            
            await MainActor.run {
                self.restaurantMapScore = score
                self.isCalculatingScore = false
                debugLog(" Score calculated: \(score?.overallScore ?? 0)")
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewState {
        case .initializing, .loading:
            enhancedLoadingView
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

        case .loaded:
            if let restaurantData = nutritionManager.currentRestaurantData {
                fullMenuContent(restaurantData)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .onAppear {
                        // Calculate restaurant score when menu loads
                        calculateRestaurantScore()
                    }
            }

        case .noData:
            noDataView
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

        case .error(let message):
            errorView(message: message)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private var enhancedLoadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: animateIn)
                }
                
                VStack(spacing: 8) {
                    Text(loadingTitle)
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text(loadingSubtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    HStack(spacing: 8) {
                        loadingTierIcon
                        Text(loadingTierText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                }
            }
            
            if showSlowLoadingTip {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                        
                        Text("Taking longer than expected?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    
                    Text("Our system is checking multiple sources for the best nutrition data")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isPresented = true
                        }
                    } label: {
                        Text("Close and reopen for faster loading")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            Spacer()
        }
        .onAppear {
            startSlowLoadingTimer()
        }
    }

    private var loadingTitle: String {
        switch nutritionManager.loadingState {
        case .checkingCache:
            return "Checking Cache..."
        case .loadingFromAPI:
            return "Loading from API..."
        case .retryingAPI:
            return "Retrying..."
        case .loadingFromStatic:
            return "Loading Fallback Data..."
        case .loadingFromNutritionix:
            return "Loading from Nutritionix..."
        default:
            return "Loading Menu..."
        }
    }
    
    private var loadingSubtitle: String {
        switch nutritionManager.loadingState {
        case .checkingCache:
            return "Looking for cached nutrition data"
        case .loadingFromAPI:
            return "Fetching fresh nutrition data"
        case .retryingAPI:
            return "Trying again with backup servers"
        case .loadingFromStatic:
            return "Using emergency nutrition database"
        case .loadingFromNutritionix:
            return "Fetching from alternative nutrition source"
        default:
            return "Getting nutrition data for \(restaurant.name)"
        }
    }
    
    @ViewBuilder
    private var loadingTierIcon: some View {
        switch nutritionManager.loadingState {
        case .checkingCache:
            Image(systemName: "bolt.circle.fill")
                .foregroundColor(.green)
        case .loadingFromAPI:
            Image(systemName: "globe.americas.fill")
                .foregroundColor(.blue)
        case .retryingAPI:
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundColor(.orange)
        case .loadingFromStatic:
            Image(systemName: "database.fill")
                .foregroundColor(.purple)
        case .loadingFromNutritionix:
            Image(systemName: "network")
                .foregroundColor(.indigo)
        default:
            Image(systemName: "circle.fill")
                .foregroundColor(.gray)
        }
    }
    
    private var loadingTierText: String {
        switch nutritionManager.loadingState {
        case .checkingCache:
            return "TIER 1: Cache"
        case .loadingFromAPI:
            return "TIER 2: Primary API"
        case .retryingAPI:
            return "TIER 3: Retry Logic"
        case .loadingFromStatic:
            return "TIER 4: Static Data"
        case .loadingFromNutritionix:
            return "TIER 5: Nutritionix"
        default:
            return "Loading..."
        }
    }

    private var restaurantHeader: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 60, height: 60)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    if let cuisine = restaurant.cuisine {
                        Text(cuisine.capitalized)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        if hasNutritionData {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text("Nutrition data available")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("No nutrition data")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
                Spacer()
            }
            
            // SIMPLIFIED: Restaurant scoring section
            if shouldShowScoring {
                restaurantScoringSection
            }

            restaurantInfoSquares
            
            if let category = selectedCategory {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(category.color)
                    Text("Filtering by \(category.rawValue)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(category.color)
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(category.color.opacity(0.1)))
            }
        }
    }
    
    // SIMPLIFIED: Restaurant scoring section using RestaurantMapScore
    private var restaurantScoringSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Restaurant Nutrition Score")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if authService.isAuthenticated {
                    Button("Guide") {
                        showingScoreLegend = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if !authService.isAuthenticated {
                // Show blurred/locked state when not authenticated
                restaurantScoreLockedView
            } else if isCalculatingScore {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Calculating restaurant score...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            } else if let score = restaurantMapScore {
                SimpleRestaurantScoreCard(score: score)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var restaurantScoreLockedView: some View {
        HStack(spacing: 16) {
            // Blurred score circle with realistic-looking data
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.75) // Show as if it's a "Good" score
                    .stroke(Color.blue, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 2)
                
                Text("••")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .blur(radius: 1)
                
                // Lock overlay
                VStack(spacing: 2) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .background(Circle().fill(Color.white).frame(width: 24, height: 24))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("••••")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .blur(radius: 1.5)
                    
                    Text("👍")
                        .font(.subheadline)
                        .blur(radius: 1)
                    
                    Text("🔒")
                        .font(.subheadline)
                }
                
                Text("••• of ••• items scored")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .blur(radius: 1)
                
                Text("Sign in to view personalized restaurant scoring")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Button("Sign In") {
                    HapticService.shared.buttonPress()
                    showingSignIn = true
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(8)
                
                Text("Unlock")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $showingSignIn) {
            AuthenticationScreen(
                onSignUpSuccess: {
                    showingSignIn = false
                },
                onSignInSuccess: {
                    showingSignIn = false
                }
            )
        }
    }

    private var restaurantInfoSquares: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if let website = restaurant.website {
                    RestaurantInfoSquare(
                        icon: "globe",
                        iconColor: Color.blue,
                        text: formatWebsiteDisplay(website),
                        action: {
                            trackWebsiteClick(restaurantName: restaurant.name, website: website)
                            if let url = URL(string: website) {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                }
                
                if let address = restaurant.address {
                    RestaurantInfoSquare(
                        icon: "location.fill",
                        iconColor: Color.red,
                        text: formatAddressDisplay(address),
                        action: {
                            openInMaps()
                        }
                    )
                }
                
                if let phone = restaurant.phone {
                    RestaurantInfoSquare(
                        icon: "phone.fill",
                        iconColor: Color.green,
                        text: formatPhoneDisplay(phone),
                        action: {
                            AnalyticsService.shared.trackPhoneCall(
                                restaurantName: restaurant.name,
                                phoneNumber: phone
                            )
                            
                            if let phoneURL = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                                UIApplication.shared.open(phoneURL)
                            }
                        }
                    )
                }
                
                if let hours = restaurant.openingHours {
                    RestaurantInfoSquare(
                        icon: "clock.fill",
                        iconColor: Color.orange,
                        text: formatHoursDisplay(hours),
                        action: nil
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }

    private func formatWebsiteDisplay(_ website: String) -> String {
        return website
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .components(separatedBy: "/").first ?? website
    }

    private func formatAddressDisplay(_ address: String) -> String {
        let components = address.components(separatedBy: ",")
        if components.count >= 2 {
            return components[0].trimmingCharacters(in: .whitespaces)
        }
        return address
    }

    private func formatPhoneDisplay(_ phone: String) -> String {
        return phone
    }

    private func formatHoursDisplay(_ hours: String) -> String {
        if hours.contains("24/7") || hours.contains("24 hours") {
            return "24/7"
        } else if hours.contains("AM") && hours.contains("PM") {
            return "Open"
        }
        return hours
    }

    private func trackWebsiteClick(restaurantName: String, website: String) {
        AnalyticsService.shared.trackRestaurantWebsiteClick(
            restaurantName: restaurantName,
            website: website,
            source: "restaurant_detail_view",
            hasNutritionData: hasNutritionData,
            cuisine: restaurant.cuisine
        )
    }

    private func setupView() {
        hasNutritionData = nutritionManager.hasNutritionData(for: restaurant.name)
        debugLog(" Opening '\(restaurant.name)' – has nutrition: \(hasNutritionData)")

        AnalyticsService.shared.trackRestaurantView(
            restaurantName: restaurant.name,
            source: "restaurant_detail_view",
            hasNutritionData: hasNutritionData,
            cuisine: restaurant.cuisine
        )

        if hasNutritionData {
            if let existingData = nutritionManager.currentRestaurantData,
               existingData.restaurantName.lowercased() == restaurant.name.lowercased() {
                debugLog(" Data already loaded for \(restaurant.name), showing menu immediately")
                
                AnalyticsService.shared.trackNutritionDataUsage(
                    restaurantName: restaurant.name,
                    source: "restaurant_detail_cached",
                    itemCount: existingData.items.count,
                    cuisine: restaurant.cuisine
                )
                
                viewState = .loaded
                // Calculate score immediately if data is already loaded
                calculateRestaurantScore()
            } else {
                viewState = .loading
                debugLog(" Loading nutrition for \(restaurant.name)")
                nutritionManager.loadNutritionData(for: restaurant.name)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.updateViewStateBasedOnData()
                }
            }
        } else {
            viewState = .noData
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            animateIn = true
        }
    }

    private func updateViewStateBasedOnData() {
        if let data = nutritionManager.currentRestaurantData {
            if data.restaurantName.lowercased().contains(restaurant.name.lowercased()) ||
               restaurant.name.lowercased().contains(data.restaurantName.lowercased()) {
                debugLog(" UI SUCCESS: Menu loaded for '\(restaurant.name)' with \(data.items.count) items")
                
                AnalyticsService.shared.trackNutritionDataUsage(
                    restaurantName: restaurant.name,
                    source: "restaurant_detail_loaded",
                    itemCount: data.items.count,
                    cuisine: restaurant.cuisine
                )
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewState = .loaded
                }
                stopSlowLoadingTimer()
                return
            } else {
                debugLog(" Data mismatch: Expected '\(restaurant.name)', got '\(data.restaurantName)'")
            }
        }
        
        if let error = nutritionManager.errorMessage {
            debugLog(" Error state: \(error)")
            withAnimation(.easeInOut(duration: 0.3)) {
                viewState = .error(error)
            }
            stopSlowLoadingTimer()
            return
        }
        
        if nutritionManager.isLoading && hasNutritionData {
            debugLog(" Still loading...")
            if case .loading = viewState {
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewState = .loading
                }
                startSlowLoadingTimer()
            }
            return
        }
        
        if hasNutritionData {
            debugLog(" Should have data but loading failed")
            withAnimation(.easeInOut(duration: 0.3)) {
                viewState = .error("Failed to load nutrition data for \(restaurant.name)")
            }
            stopSlowLoadingTimer()
        } else {
            debugLog(" No nutrition data available")
            withAnimation(.easeInOut(duration: 0.3)) {
                viewState = .noData
            }
        }
    }

    private func startSlowLoadingTimer() {
        slowLoadingTimer?.invalidate()
        slowLoadingTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showSlowLoadingTip = true
            }
        }
    }
    
    private func stopSlowLoadingTimer() {
        slowLoadingTimer?.invalidate()
        slowLoadingTimer = nil
        showSlowLoadingTip = false
    }
    
    private func cleanup() {
        stopSlowLoadingTimer()
    }

    private func fullMenuContent(_ data: RestaurantNutritionData) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Picker("Menu Category", selection: $selectedMenuCategory) {
                    ForEach(MenuCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search menu items...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            List(filteredItems(from: data.items)) { item in
                NavigationLink {
                    MenuItemDetailView(item: item)
                } label: {
                    MenuItemCard(
                        item: item,
                        category: selectedCategory
                    )
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color(.systemBackground))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func filteredItems(from items: [NutritionData]) -> [NutritionData] {
        var list = items
        
        list = filterByMenuCategory(list, category: selectedMenuCategory)
        
        if let cat = selectedCategory {
            list = filterItemsByCategory(list, category: cat)
        }
        if !searchText.isEmpty {
            list = list.filter { $0.item.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }

    private func filterByMenuCategory(_ items: [NutritionData], category: MenuCategory) -> [NutritionData] {
        switch category {
        case .all:
            return items
        case .food:
            return items.filter { !isDrink($0) && !isDessert($0) }
        case .drinks:
            return items.filter { isDrink($0) }
        case .desserts:
            return items.filter { isDessert($0) }
        }
    }
    
    private func isDrink(_ item: NutritionData) -> Bool {
        let drinkKeywords = ["coffee", "latte", "cappuccino", "espresso", "tea", "smoothie", "shake", 
                           "juice", "soda", "cola", "drink", "water", "milk", "hot chocolate", 
                           "frappuccino", "refresher", "iced", "cold brew", "macchiato", "mocha"]
        let itemLower = item.item.lowercased()
        return drinkKeywords.contains { itemLower.contains($0) }
    }
    
    private func isDessert(_ item: NutritionData) -> Bool {
        let dessertKeywords = ["cookie", "cake", "pie", "donut", "doughnut", "muffin", "brownie", 
                             "ice cream", "sundae", "froyo", "parfait", "cheesecake", "cupcake",
                             "danish", "pastry", "scone", "cinnamon roll", "sweet", "dessert",
                             "chocolate chip", "fudge", "caramel", "vanilla", "strawberry"]
        let itemLower = item.item.lowercased()
        return dessertKeywords.contains { itemLower.contains($0) }
    }

    private func filterItemsByCategory(_ items: [NutritionData], category: RestaurantCategory) -> [NutritionData] {
        switch category {
        case .fastFood: return items
        case .healthy: return items.filter { $0.sodium <= 600 && $0.fiber >= 3 && $0.calories <= 500 }
        case .highProtein: return items.filter { $0.protein >= 20 }
        case .lowCarb: return items.filter { $0.carbs <= 15 }
        }
    }

    private var noDataView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "info.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            VStack(spacing: 12) {
                Text("No Nutrition Data")
                    .font(.system(size: 24, weight: .bold))
                
                Text("We don't have detailed nutrition for \(restaurant.name), but you can scan their menu!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Button {
                    AnalyticsService.shared.trackMenuScannerUsage(
                        restaurantName: restaurant.name,
                        source: "restaurant_detail_no_nutrition",
                        hasNutritionData: false,
                        cuisine: restaurant.cuisine
                    )
                    
                    showingMenuScanner = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan Menu")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Take a photo to analyze nutrition")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)], 
                            startPoint: .leading, 
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.blue.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                
                Text("📊 Get instant nutrition analysis for any menu item")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                
                if restaurant.address == nil && restaurant.phone == nil && restaurant.website == nil {
                    Text("No additional restaurant information available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .sheet(isPresented: $showingMenuScanner) {
            MenuPhotoCaptureView()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)

            VStack(spacing: 12) {
                Text("Unable to Load Menu")
                    .font(.system(size: 24, weight: .bold))
                
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Button {
                    debugLog(" Manual retry for \(restaurant.name)")
                    nutritionManager.clearData()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewState = .loading
                    }
                    nutritionManager.loadNutritionData(for: restaurant.name)
                    startSlowLoadingTimer()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .padding()
                    .background(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button {
                    AnalyticsService.shared.trackMenuScannerUsage(
                        restaurantName: restaurant.name,
                        source: "restaurant_detail_error_recovery",
                        hasNutritionData: hasNutritionData,
                        cuisine: restaurant.cuisine
                    )
                    
                    showingMenuScanner = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Scan Menu Instead")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
            Spacer()
        }
        .sheet(isPresented: $showingMenuScanner) {
            MenuPhotoCaptureView()
        }
    }

    private func openInMaps() {
        AnalyticsService.shared.trackDirections(
            restaurantName: restaurant.name,
            address: restaurant.address ?? "Unknown address"
        )
        
        let coordinate = CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = restaurant.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// SIMPLIFIED: Restaurant score card using RestaurantMapScore from RestaurantMapScoringService
struct SimpleRestaurantScoreCard: View {
    let score: RestaurantMapScore
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(score.scoreColor.opacity(0.3), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: score.overallScore / 100)
                    .stroke(score.scoreColor, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: score.overallScore)
                
                Text("\(Int(score.overallScore))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(score.scoreColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(score.scoreGrade.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(score.scoreColor)
                    
                    Text(score.scoreGrade.emoji)
                        .font(.subheadline)
                    
                    if score.isChainScore {
                        Text("(Chain)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("\(score.scoredItemCount) of \(score.menuItemCount) items scored")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !score.topRatedItems.isEmpty {
                    Text("Top: \(score.topRatedItems.prefix(2).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(score.scoreColor.opacity(0.1))
        .cornerRadius(12)
    }
}

// SIMPLIFIED: Remove complex MenuItemScore integration
struct MenuItemCard: View {
    let item: NutritionData
    let category: RestaurantCategory?
    
    private var isHighCalories: Bool { item.calories > 800 }
    private var isHighSodium:  Bool { item.sodium  > 1000 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.item)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(item.calories))")
                        .bold()
                        .foregroundColor(isHighCalories ? .red : .primary)
                    Text("cal").font(.caption)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    NutritionBadge(
                        value: "\(Int(item.sodium))mg sodium",
                        highlighted: isHighSodium
                    )
                    NutritionBadge(value: "\(format(item.fat))g fat")
                    NutritionBadge(value: "\(format(item.protein))g protein")
                    NutritionBadge(value: "\(format(item.carbs))g carbs")
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        )
    }
    
    private func format(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

struct NutritionBadge: View {
    let value: String
    let highlighted: Bool
    
    init(value: String, highlighted: Bool = false) {
        self.value = value
        self.highlighted = highlighted
    }
    
    var body: some View {
        Text(value)
            .font(.caption2)
            .foregroundColor(highlighted ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(highlighted ? Color.red : Color.gray.opacity(0.2))
            .cornerRadius(6)
    }
}

struct RestaurantInfoSquare: View {
    let icon: String
    let iconColor: Color
    let text: String
    let action: (() -> Void)?
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 20, height: 20)
                
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}