import SwiftUI
import CoreLocation

struct FlexibleCategoryListView: View {
    let userCategory: UserCategory
    @Binding var isPresented: Bool
    
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var overpassService = OverpassAPIService()
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    @State private var isLoadingRestaurants = true
    @State private var searchText = ""
    @State private var fetchedRestaurants: [Restaurant] = []
    @State private var errorMessage: String?
    @State private var showingLoadingDetails = false
    
    // Enhanced: Category-specific restaurant filtering
    private var allCategoryRestaurants: [Restaurant] {
        let restaurants = fetchedRestaurants
        
        // Sort by distance from user if location is available
        guard let userLocation = locationManager.lastLocation?.coordinate else {
            return restaurants
        }
        
        return restaurants.sorted { restaurant1, restaurant2 in
            let distance1 = restaurant1.distanceFrom(userLocation)
            let distance2 = restaurant2.distanceFrom(userLocation)
            return distance1 < distance2
        }
    }
    
    private var nutritionRestaurants: [Restaurant] {
        return allCategoryRestaurants.filter { RestaurantData.hasNutritionData(for: $0.name) }
    }
    
    // FIXED: Remove the extra category filtering - restaurants are already filtered by category
    private var nonNutritionRestaurants: [Restaurant] {
        return allCategoryRestaurants.filter { !RestaurantData.hasNutritionData(for: $0.name) }
    }
    
    private var filteredNutritionRestaurants: [Restaurant] {
        let filtered = searchText.isEmpty ? nutritionRestaurants : 
            nutritionRestaurants.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return Array(filtered.prefix(25)) // Limit for performance
    }
    
    private var filteredNonNutritionRestaurants: [Restaurant] {
        let filtered = searchText.isEmpty ? nonNutritionRestaurants : 
            nonNutritionRestaurants.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return Array(filtered.prefix(25)) // Limit for performance
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
                
                if isLoadingRestaurants {
                    LoadingView(
                        title: "Finding \(userCategory.name) Restaurants",
                        subtitle: "Searching within 5 miles...",
                        style: .fullScreen
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    mainContent
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoadingRestaurants {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: getCategoryColor()))
                    } else {
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingRestaurantDetail) {
            if let restaurant = selectedRestaurant {
                RestaurantDetailView(
                    restaurant: restaurant,
                    isPresented: $showingRestaurantDetail,
                    selectedCategory: mapUserCategoryToRestaurantCategory()
                )
                .preferredColorScheme(.light)
            }
        }
        .onAppear {
            fetchCategoryRestaurants()
        }
    }
    
    // MARK: - Fetch Category-Specific Restaurants
    private func fetchCategoryRestaurants() {
        guard let userLocation = locationManager.lastLocation?.coordinate else {
            print("❌ FlexibleCategoryListView: No user location available")
            isLoadingRestaurants = false
            return
        }
        
        print("🍽️ FlexibleCategoryListView: Fetching \(userCategory.name) restaurants near \(userLocation)")
        
        Task {
            do {
                showingLoadingDetails = true
                
                // ENHANCED: Use diet-specific search for categories with good OSM coverage
                let allRestaurants: [Restaurant]
                let searchMethod: String
                
                if let dietTag = getDietTagForCategory() {
                    print("🎯 FlexibleCategoryListView: Using diet:\(dietTag) search for \(userCategory.name)")
                    allRestaurants = try await overpassService.fetchRestaurantsByDiet(
                        diet: dietTag,
                        near: userLocation,
                        radius: 5.0
                    )
                    searchMethod = "diet:\(dietTag)"
                } else {
                    print("🍽️ FlexibleCategoryListView: Using general restaurant search for \(userCategory.name)")
                    allRestaurants = try await overpassService.fetchAllNearbyRestaurants(
                        near: userLocation, 
                        radius: 5.0
                    )
                    searchMethod = "general filtering"
                }
                
                print("🍽️ FlexibleCategoryListView: Received \(allRestaurants.count) total restaurants from API")
                
                await MainActor.run {
                    let finalRestaurants: [Restaurant]
                    
                    if searchMethod.starts(with: "diet:") {
                        // For diet-based searches, show ALL results (already filtered by API)
                        finalRestaurants = Array(allRestaurants.prefix(100))
                        print("🎯 FlexibleCategoryListView: Showing all \(finalRestaurants.count) \(searchMethod) restaurants")
                    } else {
                        // For other categories, apply manual filtering
                        print("🍽️ FlexibleCategoryListView: Filtering restaurants for \(userCategory.name)...")
                        let categoryRestaurants = filterRestaurantsByUserCategory(allRestaurants)
                        finalRestaurants = Array(categoryRestaurants.prefix(100))
                        print("🍽️ FlexibleCategoryListView: After filtering: \(finalRestaurants.count) restaurants match category")
                    }
                    
                    fetchedRestaurants = finalRestaurants
                    isLoadingRestaurants = false
                    showingLoadingDetails = false
                    errorMessage = nil
                    
                    print("🍽️ FlexibleCategoryListView: Final results - \(finalRestaurants.count) restaurants for \(userCategory.name)")
                    print("🍽️ With nutrition: \(nutritionRestaurants.count)")
                    print("🍽️ Without nutrition: \(nonNutritionRestaurants.count)")
                }
                
            } catch {
                await MainActor.run {
                    print("❌ FlexibleCategoryListView: Error fetching restaurants: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    isLoadingRestaurants = false
                    showingLoadingDetails = false
                }
            }
        }
    }
    
    // Helper to get diet tag for any category
    private func getDietTagForCategory() -> String? {
        switch userCategory.id {
        case "highProtein":
            return "meat"
        case "healthy":
            return "vegetarian"
        case "vegan":
            return "vegan"
        case "glutenFree":
            return "gluten_free"
        case "lowCarb", "keto":
            return "meat" // Low carb and keto are often meat-focused
        default:
            return nil // Use traditional filtering
        }
    }
    
    // Helper to get search method description
    private func getSearchMethodDescription() -> String {
        if let dietTag = getDietTagForCategory() {
            return "Tagged with diet:\(dietTag) • Sorted by distance"
        } else {
            return "Within 5 miles • Sorted by distance"
        }
    }
    
    // Helper to get category color
    private func getCategoryColor() -> Color {
        switch userCategory.id {
        case "fastFood":
            return .orange
        case "healthy":
            return .green
        case "highProtein":
            return .red
        case "vegan":
            return .green
        case "glutenFree":
            return .orange
        case "lowCarb", "keto":
            return .purple
        default:
            return .blue
        }
    }
    
    // Map UserCategory to RestaurantCategory for RestaurantDetailView
    private func mapUserCategoryToRestaurantCategory() -> RestaurantCategory? {
        switch userCategory.id {
        case "fastFood":
            return .fastFood
        case "healthy":
            return .healthy
        case "highProtein":
            return .highProtein
        default:
            return nil // Additional categories don't map to RestaurantCategory
        }
    }
    
    // Traditional filtering for categories without diet tags
    private func filterRestaurantsByUserCategory(_ restaurants: [Restaurant]) -> [Restaurant] {
        switch userCategory.id {
        case "fastFood":
            return restaurants.filter { restaurant in
                RestaurantData.hasNutritionData(for: restaurant.name) ||
                restaurant.amenityType == "fast_food" ||
                restaurant.name.lowercased().contains("burger") ||
                restaurant.name.lowercased().contains("pizza") ||
                restaurant.name.lowercased().contains("taco") ||
                restaurant.name.lowercased().contains("chicken")
            }
        default:
            // For custom categories, include most restaurants
            return restaurants.filter { restaurant in
                let amenity = restaurant.amenityType ?? ""
                return amenity == "restaurant" || amenity == "fast_food" || amenity == "cafe"
            }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerSection
            
            if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else if allCategoryRestaurants.isEmpty {
                emptyStateView
            } else {
                restaurantsList
            }
        }
    }
    
    // MARK: - Header Section with Search
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                TextField("Search \(userCategory.name.lowercased()) restaurants...", text: $searchText)
                    .font(.system(size: 16))
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
            
            // Results summary with search method info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 16) {
                        if !nutritionRestaurants.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                Text("\(filteredNutritionRestaurants.count) with nutrition")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if !nonNutritionRestaurants.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text("\(filteredNonNutritionRestaurants.count) nearby")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    // ENHANCED: Show search method based on category
                    HStack(spacing: 8) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(getSearchMethodDescription())
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        if let userLocation = locationManager.lastLocation?.coordinate,
                           let closestRestaurant = allCategoryRestaurants.first {
                            let distance = closestRestaurant.distanceFrom(userLocation)
                            Text("• Closest: \(String(format: "%.1f mi", distance))")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Restaurants List
    private var restaurantsList: some View {
        List {
            // Nutrition restaurants section
            if !filteredNutritionRestaurants.isEmpty {
                Section {
                    ForEach(filteredNutritionRestaurants, id: \.id) { restaurant in
                        FlexibleCategoryRestaurantRow(
                            restaurant: restaurant,
                            userCategory: userCategory,
                            hasNutrition: true,
                            onTap: {
                                selectedRestaurant = restaurant
                                showingRestaurantDetail = true
                            }
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                        Text("With Detailed Nutrition Data")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Non-nutrition restaurants section
            if !filteredNonNutritionRestaurants.isEmpty {
                Section {
                    ForEach(filteredNonNutritionRestaurants, id: \.id) { restaurant in
                        FlexibleCategoryRestaurantRow(
                            restaurant: restaurant,
                            userCategory: userCategory,
                            hasNutrition: false,
                            onTap: {
                                selectedRestaurant = restaurant
                                showingRestaurantDetail = true
                            }
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        Text("Nearby \(userCategory.name) Restaurants")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text("These restaurants match your category but don't have detailed nutrition data available.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Unable to Load Restaurants")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                fetchCategoryRestaurants()
            }) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(getCategoryColor())
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(userCategory.icon)
                .font(.system(size: 64))
            
            VStack(spacing: 8) {
                Text("No \(userCategory.name) Restaurants Found")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Try expanding your search radius or check back later.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                fetchCategoryRestaurants()
            }) {
                Text("Refresh")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(getCategoryColor())
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Flexible Category Restaurant Row
struct FlexibleCategoryRestaurantRow: View {
    let restaurant: Restaurant
    let userCategory: UserCategory
    let hasNutrition: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var categoryColor: Color {
        switch userCategory.id {
        case "fastFood":
            return .orange
        case "healthy":
            return .green
        case "highProtein":
            return .red
        case "vegan":
            return .green
        case "glutenFree":
            return .orange
        case "lowCarb", "keto":
            return .purple
        default:
            return .blue
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Restaurant icon with nutrition indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(hasNutrition ? Color.green.opacity(0.1) : categoryColor.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 4) {
                        Text(restaurant.emoji)
                            .font(.system(size: 20))
                        
                        if hasNutrition {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(hasNutrition ? Color.green : categoryColor, lineWidth: 2)
                )
                
                // Restaurant details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(restaurant.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Distance if available
                        if let userLocation = LocationManager.shared.lastLocation?.coordinate {
                            let distance = restaurant.distanceFrom(userLocation)
                            Text(String(format: "%.1f mi", distance))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let cuisine = restaurant.cuisine {
                        Text(cuisine.capitalized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Status indicators
                    HStack(spacing: 8) {
                        if hasNutrition {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                Text("Nutrition Data")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.1))
                            )
                        } else {
                            HStack(spacing: 2) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text("Location Only")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                        
                        Spacer()
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
            .overlay(
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(hasNutrition ? Color.green : categoryColor)
                        .frame(width: 4)
                    Spacer()
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

#Preview {
    FlexibleCategoryListView(
        userCategory: UserCategory(id: "vegan", name: "Vegan", icon: "🌱", type: .additional, order: 0),
        isPresented: .constant(true)
    )
}