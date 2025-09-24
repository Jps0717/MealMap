import SwiftUI
import CoreLocation

struct CategoryListView: View {
    let category: RestaurantCategory
    let restaurants: [Restaurant]
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
    
    // ENHANCED: Category-specific restaurant filtering
    private var allCategoryRestaurants: [Restaurant] {
        let restaurants = fetchedRestaurants.isEmpty ? restaurants : fetchedRestaurants
        
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
                    // Removed CategoryLoadingView - using the one from LoadingView.swift
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
        .sheet(isPresented: $showingRestaurantDetail) {
            if let restaurant = selectedRestaurant {
                RestaurantDetailView(
                    restaurant: restaurant,
                    isPresented: $showingRestaurantDetail,
                    selectedCategory: category
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
            print("❌ CategoryListView: No user location available")
            // Use provided restaurants if no location
            isLoadingRestaurants = false
            return
        }
        
        print("🍽️ CategoryListView: Fetching \(category.displayName) restaurants near \(userLocation)")
        
        Task {
            do {
                showingLoadingDetails = true
                
                // ENHANCED: Support for both RestaurantCategory and UserCategory
                let dietTag = getDietTagForCategory() ?? getDietTagForUserCategory("vegan")
                
                // ENHANCED: Use diet-specific search for categories with good OSM coverage
                let allRestaurants: [Restaurant]
                let searchMethod: String
                
                if let dietTag = dietTag {
                    allRestaurants = try await overpassService.fetchRestaurantsByDiet(
                        diet: dietTag,
                        near: userLocation,
                        radius: 5.0
                    )
                    searchMethod = "diet:\(dietTag)"
                } else {
                    allRestaurants = try await overpassService.fetchAllNearbyRestaurants(
                        near: userLocation, 
                        radius: 5.0
                    )
                    searchMethod = "amenity filtering"
                }
                
                print("🍽️ CategoryListView: Received \(allRestaurants.count) total restaurants from API")
                
                await MainActor.run {
                    let finalRestaurants: [Restaurant]
                    
                    if searchMethod.starts(with: "diet:") {
                        // For diet-based searches, show ALL results (already filtered by API)
                        finalRestaurants = Array(allRestaurants.prefix(100))
                        print("🎯 CategoryListView: Showing all \(finalRestaurants.count) \(searchMethod) restaurants")
                    } else {
                        // For other categories, apply filtering
                        print("🍽️ CategoryListView: Filtering restaurants for \(category.displayName)...")
                        let categoryRestaurants = filterRestaurantsByCategory(allRestaurants)
                        finalRestaurants = Array(categoryRestaurants.prefix(100))
                        print("🍽️ CategoryListView: After filtering: \(finalRestaurants.count) restaurants match category")
                    }
                    
                    // Show first few restaurant names for debugging
                    if !finalRestaurants.isEmpty {
                        let sampleNames = finalRestaurants.prefix(3).map { "\($0.name) (\($0.amenityType ?? "unknown"))" }
                        print("🍽️ CategoryListView: Sample restaurants: \(sampleNames)")
                    }
                    
                    fetchedRestaurants = finalRestaurants
                    isLoadingRestaurants = false
                    showingLoadingDetails = false
                    errorMessage = nil
                    
                    print("🍽️ CategoryListView: Final results - \(finalRestaurants.count) restaurants for \(category.displayName)")
                    print("🍽️ With nutrition: \(nutritionRestaurants.count)")
                    print("🍽️ Without nutrition: \(nonNutritionRestaurants.count)")
                    
                    // Enhanced debugging for the split
                    if finalRestaurants.count > 0 {
                        let nutritionCount = finalRestaurants.filter { RestaurantData.hasNutritionData(for: $0.name) }.count
                        let nonNutritionCount = finalRestaurants.count - nutritionCount
                        print("🍽️ SPLIT DEBUG: \(nutritionCount) with nutrition, \(nonNutritionCount) without nutrition")
                        
                        if nonNutritionCount > 0 {
                            let sampleNonNutrition = finalRestaurants.filter { !RestaurantData.hasNutritionData(for: $0.name) }.prefix(3).map { $0.name }
                            print("🍽️ Sample non-nutrition restaurants: \(sampleNonNutrition)")
                        }
                    }
                }
                
            } catch {
                await MainActor.run {
                    print("❌ CategoryListView: Error fetching restaurants: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    isLoadingRestaurants = false
                    showingLoadingDetails = false
                }
            }
        }
    }
    
    // Helper to get diet tag for any category
    private func getDietTagForCategory() -> String? {
        // First check if it's a main RestaurantCategory
        switch category {
        case .highProtein:
            return "meat"
        case .healthy:
            return "vegetarian"
        case .fastFood:
            return nil // Use traditional filtering
        case .lowCarb:
            return nil // Use comprehensive filtering instead of single diet tag
        }
    }
    
    // Helper to get diet tag for UserCategory (additional categories)
    private func getDietTagForUserCategory(_ categoryId: String) -> String? {
        switch categoryId {
        case "vegan":
            return "vegan"
        case "glutenFree":
            return "gluten_free"
        case "lowCarb":
            return "meat" // Low carb often means meat-focused
        case "keto":
            return "meat" // Keto is typically meat + fat focused
        default:
            return nil
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
    
    // ENHANCED: Comprehensive category-based restaurant filtering
    private func filterRestaurantsByCategory(_ restaurants: [Restaurant]) -> [Restaurant] {
        print(" FilterRestaurants: Starting with \(restaurants.count) restaurants for \(category.displayName)")
        
        let filtered = restaurants.filter { restaurant in
            switch category {
            case .fastFood:
                // Include all fast food + nutrition chains + specific fast food terms
                let name = restaurant.name.lowercased()
                return RestaurantData.hasNutritionData(for: restaurant.name) ||
                       restaurant.amenityType == "fast_food" ||
                       name.contains("burger") ||
                       name.contains("pizza") ||
                       name.contains("taco") ||
                       name.contains("chicken") ||
                       name.contains("mcdonald") ||
                       name.contains("kfc") ||
                       name.contains("subway") ||
                       name.contains("drive")
                
            case .healthy:
                // Include most restaurants except clearly unhealthy ones
                let name = restaurant.name.lowercased()
                let amenity = restaurant.amenityType ?? ""
                
                let excludeUnhealthy = name.contains("donut") ||
                                      name.contains("candy") ||
                                      amenity == "ice_cream"
                
                return !excludeUnhealthy
                
            case .highProtein:
                // COMPREHENSIVE: Include ALL restaurants that could have high protein options
                let name = restaurant.name.lowercased()
                let cuisine = restaurant.cuisine?.lowercased() ?? ""
                let amenity = restaurant.amenityType ?? ""
                
                // Include ALL restaurants and fast food by default
                let includeByType = amenity == "restaurant" ||
                                   amenity == "fast_food" ||
                                   amenity == "cafe" ||
                                   amenity == "pub" ||
                                   amenity == "bar"
                
                // Include specific high protein cuisines and terms
                let includeByKeywords = name.contains("grill") ||
                                       name.contains("steakhouse") ||
                                       name.contains("bbq") ||
                                       name.contains("barbecue") ||
                                       name.contains("chicken") ||
                                       name.contains("beef") ||
                                       name.contains("steak") ||
                                       name.contains("wings") ||
                                       name.contains("burger") ||
                                       name.contains("meat") ||
                                       name.contains("seafood") ||
                                       name.contains("fish") ||
                                       name.contains("salmon") ||
                                       name.contains("crab") ||
                                       name.contains("lobster") ||
                                       cuisine.contains("steak") ||
                                       cuisine.contains("barbecue") ||
                                       cuisine.contains("grill") ||
                                       cuisine.contains("american") ||
                                       cuisine.contains("seafood") ||
                                       cuisine.contains("mexican") ||
                                       cuisine.contains("tex-mex") ||
                                       cuisine.contains("indian") ||
                                       cuisine.contains("chinese") ||
                                       cuisine.contains("italian") ||
                                       cuisine.contains("burger")
                
                // Include all nutrition chains (they likely have protein options)
                let includeNutritionChains = RestaurantData.hasNutritionData(for: restaurant.name)
                
                // Only exclude places that clearly don't serve substantial protein
                let excludeNonProtein = amenity == "ice_cream" ||
                                       amenity == "bakery" ||
                                       name.contains("ice cream") ||
                                       name.contains("donut") ||
                                       name.contains("candy") ||
                                       name.contains("juice bar") ||
                                       name.contains("smoothie bar") ||
                                       cuisine.contains("ice_cream") ||
                                       cuisine.contains("dessert")
                
                return (includeByType || includeByKeywords || includeNutritionChains) && !excludeNonProtein
                
            case .lowCarb:
                // Include restaurants that serve low carb options
                let name = restaurant.name.lowercased()
                let cuisine = restaurant.cuisine?.lowercased() ?? ""
                let amenity = restaurant.amenityType ?? ""
                
                // Include restaurants that typically have low carb options
                let includeByType = amenity == "restaurant" ||
                                   amenity == "fast_food" ||
                                   amenity == "cafe"
                
                // Include specific low carb friendly terms
                let includeByKeywords = name.contains("grill") ||
                                       name.contains("steakhouse") ||
                                       name.contains("seafood") ||
                                       name.contains("salad") ||
                                       name.contains("keto") ||
                                       name.contains("burger") ||
                                       name.contains("chipotle") ||
                                       name.contains("five guys") ||
                                       cuisine.contains("steak") ||
                                       cuisine.contains("seafood") ||
                                       cuisine.contains("grill") ||
                                       cuisine.contains("mediterranean")
                
                // Include nutrition chains that offer low carb options
                let includeNutritionChains = RestaurantData.hasNutritionData(for: restaurant.name)
                
                // Exclude clearly high-carb places
                let excludeHighCarb = amenity == "bakery" ||
                                     name.contains("donut") ||
                                     name.contains("ice cream") ||
                                     name.contains("pizza") ||
                                     name.contains("pasta") ||
                                     cuisine.contains("pizza") ||
                                     cuisine.contains("dessert")
                
                return (includeByType || includeByKeywords || includeNutritionChains) && !excludeHighCarb
            }

        }
        
        print(" FilterRestaurants: After filtering \(category.displayName): \(filtered.count) restaurants")
        if !filtered.isEmpty {
            let sampleNames = filtered.prefix(3).map { "\($0.name) (\($0.amenityType ?? "unknown"))" }
            print(" FilterRestaurants: Sample results: \(sampleNames)")
        }
        
        return filtered
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
                
                TextField("Search \(category.displayName.lowercased()) restaurants...", text: $searchText)
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
                        CategoryRestaurantRow(
                            restaurant: restaurant,
                            category: category,
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
                        CategoryRestaurantRow(
                            restaurant: restaurant,
                            category: category,
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
                        Text("Nearby \(category.displayName) Restaurants")
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
                    .background(category.color)
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
            
            Text(category.emoji)
                .font(.system(size: 64))
            
            VStack(spacing: 8) {
                Text("No \(category.displayName) Restaurants Found")
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
                    .background(category.color)
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Restaurant Category Extensions
extension RestaurantCategory {
    var displayName: String {
        switch self {
        case .fastFood:
            return "Fast Food"
        case .healthy:
            return "Healthy"
        case .highProtein:
            return "High Protein"
        case .lowCarb:
            return "Low Carb"
        }
    }
    
    var emoji: String {
        switch self {
        case .fastFood:
            return "🍔"
        case .healthy:
            return "🥗"
        case .highProtein:
            return "🥩"
        case .lowCarb:
            return "🥑"
        }
    }
}

#Preview {
    CategoryListView(
        category: .fastFood,
        restaurants: [],
        isPresented: .constant(true)
    )
}