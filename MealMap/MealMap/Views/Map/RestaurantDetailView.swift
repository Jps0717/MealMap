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
                        isPresented = false
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
                    if let website = restaurant.website, let url = URL(string: website) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Image(systemName: "globe")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .onAppear { 
            setupView() 
        }
        .onDisappear { cleanup() }
        .onChange(of: nutritionManager.currentRestaurantData) { _, newData in 
            debugLog("📊 DATA CHANGE: \(newData?.restaurantName ?? "nil")")
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
            }

        case .noData:
            noDataView
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

        case .error(let message):
            errorView(message: message)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    // MARK: - Enhanced Loading View
    @ViewBuilder
    private var enhancedLoadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Loading indicator with tier information
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
                    
                    // Loading tier indicator
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
            
            // Slow loading tip
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
                        isPresented = false
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

    // MARK: - Loading State Helpers
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

    // MARK: - Setup and State Management
    private func setupView() {
        hasNutritionData = nutritionManager.hasNutritionData(for: restaurant.name)
        debugLog("🍽️ Opening '\(restaurant.name)' – has nutrition: \(hasNutritionData)")

        if hasNutritionData {
            // Check if data is already loaded
            if let existingData = nutritionManager.currentRestaurantData,
               existingData.restaurantName.lowercased() == restaurant.name.lowercased() {
                debugLog("✅ Data already loaded for \(restaurant.name), showing menu immediately")
                viewState = .loaded
            } else {
                viewState = .loading
                debugLog("🔄 Loading nutrition for \(restaurant.name)")
                nutritionManager.loadNutritionData(for: restaurant.name)
                
                // Set up a timeout to check for data loading issues
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

    // Simplified state management
    private func updateViewStateBasedOnData() {
        // Check current nutrition manager state
        if let data = nutritionManager.currentRestaurantData {
            // Data exists - check if it's for this restaurant
            if data.restaurantName.lowercased().contains(restaurant.name.lowercased()) ||
               restaurant.name.lowercased().contains(data.restaurantName.lowercased()) {
                debugLog("✅ UI SUCCESS: Menu loaded for '\(restaurant.name)' with \(data.items.count) items")
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewState = .loaded
                }
                stopSlowLoadingTimer()
                return
            } else {
                debugLog("⚠️ Data mismatch: Expected '\(restaurant.name)', got '\(data.restaurantName)'")
            }
        }
        
        // Check for errors
        if let error = nutritionManager.errorMessage {
            debugLog("❌ Error state: \(error)")
            withAnimation(.easeInOut(duration: 0.3)) {
                viewState = .error(error)
            }
            stopSlowLoadingTimer()
            return
        }
        
        // Check if still loading
        if nutritionManager.isLoading && hasNutritionData {
            debugLog("⏳ Still loading...")
            if case .loading = viewState {
                // Already in loading state
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewState = .loading
                }
                startSlowLoadingTimer()
            }
            return
        }
        
        // Not loading and no data - determine final state
        if hasNutritionData {
            debugLog("⚠️ Should have data but loading failed")
            withAnimation(.easeInOut(duration: 0.3)) {
                viewState = .error("Failed to load nutrition data for \(restaurant.name)")
            }
            stopSlowLoadingTimer()
        } else {
            debugLog("ℹ️ No nutrition data available")
            withAnimation(.easeInOut(duration: 0.3)) {
                viewState = .noData
            }
        }
    }

    // MARK: - Slow Loading Timer
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

    // MARK: - Restaurant Header
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

                    // Enhanced nutrition data indicator
                    HStack(spacing: 6) {
                        if hasNutritionData {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text("Multi-tier nutrition data")
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

            // Restaurant contact and website information
            restaurantInfoSection

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

    // MARK: - Restaurant Info Section
    private var restaurantInfoSection: some View {
        VStack(spacing: 8) {
            // Address
            if let address = restaurant.address {
                RestaurantInfoRow(
                    icon: "location.fill",
                    iconColor: .blue,
                    text: address,
                    action: {
                        openInMaps()
                    }
                )
            }
            
            // Phone
            if let phone = restaurant.phone {
                RestaurantInfoRow(
                    icon: "phone.fill",
                    iconColor: .green,
                    text: phone,
                    action: {
                        if let phoneURL = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                            UIApplication.shared.open(phoneURL)
                        }
                    }
                )
            }
            
            // Website
            if let website = restaurant.website {
                RestaurantInfoRow(
                    icon: "globe",
                    iconColor: .orange,
                    text: formatWebsiteDisplay(website),
                    action: {
                        if let url = URL(string: website) {
                            UIApplication.shared.open(url)
                        }
                    }
                )
            }
            
            // Opening Hours
            if let hours = restaurant.openingHours {
                RestaurantInfoRow(
                    icon: "clock.fill",
                    iconColor: .purple,
                    text: hours,
                    action: nil
                )
            }
        }
    }

    // MARK: - Helper Methods
    private func formatWebsiteDisplay(_ website: String) -> String {
        // Remove http/https prefix for cleaner display
        return website
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
    }

    private func openInMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = restaurant.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: - Enhanced No Data View
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
                
                // Performance stats (if available)
                if let stats = getPerformanceStatsText() {
                    Text(stats)
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 40)
                }
            }

            // Enhanced Scan Menu button
            VStack(spacing: 16) {
                Button {
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
                    .shadow(color: .blue.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                
                Text("✨ Get instant nutrition analysis for any menu item")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                
                // Restaurant info cards (moved to header)
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

    // MARK: - Enhanced Error View
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
                
                // Performance stats
                if let stats = getPerformanceStatsText() {
                    Text(stats)
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 40)
                }
            }

            VStack(spacing: 16) {
                Button {
                    debugLog("🔄 Manual retry for \(restaurant.name)")
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

    // MARK: - Performance Stats Helper
    private func getPerformanceStatsText() -> String? {
        let stats = nutritionManager.getPerformanceStats()
        if stats.cacheHits + stats.cacheMisses + stats.apiSuccesses + stats.apiFailures > 0 {
            return "Cache: \(Int(stats.hitRate * 100))% • API: \(stats.apiSuccesses) success, \(stats.apiFailures) failed"
        }
        return nil
    }

    // MARK: - Menu Content 
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
                    MenuItemCard(item: item, category: selectedCategory)
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
}

// MARK: - Restaurant Info Row Component
struct RestaurantInfoRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    let action: (() -> Void)?
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }
    
    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
            
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Menu Item Card 

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
                    Text("\(Int(item.calories)) calories")
                        .foregroundColor(isHighCalories ? .red : .secondary)
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

// MARK: - Nutrition Badge 

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

// MARK: - Preview

#Preview {
    RestaurantDetailView(
        restaurant: Restaurant(
            id: 1,
            name: "Krispy Kreme",
            latitude: 37.7749,
            longitude: -122.4194,
            address: "123 Main St",
            cuisine: "Donut",
            openingHours: "6:00 AM - 11:00 PM",
            phone: "+1-555-123-4567",
            website: "https://krispykreme.com",
            type: "node"
        ),
        isPresented: .constant(true),
        selectedCategory: .fastFood
    )
}