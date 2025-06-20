import SwiftUI
import CoreLocation

struct ListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedSortOptions: Set<SortOption> = [.distance]
    @State private var isRefreshing: Bool = false
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    @State private var isLoadingRestaurant = false
    
    // Data passed from MapScreen
    let restaurants: [Restaurant]
    let userLocation: CLLocation?
    let searchManager: SearchManager
    let onRestaurantSelected: (Restaurant) -> Void
    
    // Computed properties for filtering and sorting
    private var filteredAndSortedRestaurants: [Restaurant] {
        let filtered = filteredRestaurants
        let additionallyFiltered = applyMultipleFilters(filtered)
        return sortRestaurants(additionallyFiltered)
    }
    
    private var filteredRestaurants: [Restaurant] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return restaurants
        }
        
        let lowercasedSearch = searchText.lowercased()
        return restaurants.filter { restaurant in
            restaurant.name.lowercased().contains(lowercasedSearch) ||
            restaurant.cuisine?.lowercased().contains(lowercasedSearch) == true
        }
    }
    
    // Haptic Feedback Generators
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    enum SortOption: String, CaseIterable {
        case distance = "Distance"
        case nutritionAvailable = "Nutrition Data"
        case cuisine = "Cuisine"
        
        var systemImage: String {
            switch self {
            case .distance: return "location.fill"
            case .nutritionAvailable: return "heart.fill"
            case .cuisine: return "fork.knife"
            }
        }
    }
    
    init(
        restaurants: [Restaurant] = [],
        userLocation: CLLocation? = nil,
        searchManager: SearchManager? = nil,
        onRestaurantSelected: @escaping (Restaurant) -> Void = { _ in }
    ) {
        self.restaurants = restaurants
        self.userLocation = userLocation
        self.searchManager = searchManager ?? SearchManager()
        self.onRestaurantSelected = onRestaurantSelected
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Sort Header
                VStack(spacing: 12) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("Search restaurants...", text: $searchText)
                            .font(.system(size: 16))
                            .disableAutocorrection(true)
                            .onChange(of: searchText) { oldValue, newValue in
                                if !newValue.isEmpty && oldValue.isEmpty {
                                    lightFeedback.impactOccurred()
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    searchText = ""
                                    lightFeedback.impactOccurred()
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                    )
                    
                    // Multiple selection filter buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    withAnimation {
                                        if selectedSortOptions.contains(option) {
                                            selectedSortOptions.remove(option)
                                        } else {
                                            selectedSortOptions.insert(option)
                                        }
                                        selectionFeedback.selectionChanged()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: option.systemImage)
                                            .font(.system(size: 12, weight: .medium))
                                        Text(option.rawValue)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(selectedSortOptions.contains(option) ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedSortOptions.contains(option) ? .blue : .blue.opacity(0.1))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    // Results count with active filters info
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(filteredAndSortedRestaurants.count) restaurants found")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            if !selectedSortOptions.isEmpty {
                                let filterText = selectedSortOptions.contains(.nutritionAvailable) ? "Showing only restaurants with nutrition data" : "Active filters: \(selectedSortOptions.map { $0.rawValue }.joined(separator: ", "))"
                                Text(filterText)
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        if !restaurants.isEmpty {
                            let nutritionCount = filteredAndSortedRestaurants.filter { restaurant in
                                RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
                            }.count
                            
                            if nutritionCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                    Text("\(nutritionCount) with nutrition data")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))
                
                // Restaurant List
                if filteredAndSortedRestaurants.isEmpty {
                    // Empty State
                    ScrollView {
                        VStack(spacing: 16) {
                            Image(systemName: searchText.isEmpty ? "fork.knife.circle" : "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text(searchText.isEmpty ? "No Restaurants Found" : "No Search Results")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(searchText.isEmpty ?
                                 "Pull down to refresh or move the map to find restaurants" :
                                 "Try adjusting your search terms")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                    .refreshable {
                        await performRefresh()
                    }
                } else {
                    // Restaurant List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredAndSortedRestaurants) { restaurant in
                                RestaurantCard(
                                    restaurant: restaurant,
                                    userLocation: userLocation,
                                    hasNutritionData: RestaurantData.restaurantsWithNutritionData.contains(restaurant.name),
                                    onTap: {
                                        isLoadingRestaurant = true
                                        selectedRestaurant = restaurant
                                        
                                        // Add a small delay to show loading state
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            showingRestaurantDetail = true
                                        }
                                    },
                                    onMapTap: {
                                        onRestaurantSelected(restaurant)
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        await performRefresh()
                    }
                }
            }
            .navigationTitle("Restaurants")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            )
        }
        .fullScreenCover(isPresented: $showingRestaurantDetail) {
            if let restaurant = selectedRestaurant {
                RestaurantDetailView(
                    restaurant: restaurant,
                    isPresented: $showingRestaurantDetail,
                    selectedCategory: nil
                )
            }
        }
        .overlay(
            // Loading overlay
            Group {
                if isLoadingRestaurant {
                    if let restaurant = selectedRestaurant {
                        RestaurantLoadingView(restaurantName: restaurant.name)
                    } else {
                        LoadingView(
                            title: "Loading Restaurant...",
                            subtitle: "Please wait...",
                            style: .overlay
                        )
                    }
                }
            }
        )
        .onChange(of: showingRestaurantDetail) { oldValue, newValue in
            if !newValue {
                // Reset loading state when detail view is dismissed
                isLoadingRestaurant = false
            }
        }
    }
    
    private func applyMultipleFilters(_ restaurants: [Restaurant]) -> [Restaurant] {
        var filtered = restaurants
        
        // Apply nutrition data filter if selected
        if selectedSortOptions.contains(.nutritionAvailable) {
            filtered = filtered.filter { restaurant in
                RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
            }
        }
        
        // Could add other filters here in the future
        // For now, cuisine and distance are just for sorting, not filtering
        
        return filtered
    }
    
    private func sortRestaurants(_ restaurants: [Restaurant]) -> [Restaurant] {
        var sorted = restaurants
        
        // Apply sorting based on selected options
        if selectedSortOptions.contains(.distance), let userLocation = userLocation {
            // Smart compound sort: Distance + Nutrition Data Priority
            sorted = sorted.sorted { restaurant1, restaurant2 in
                let location1 = CLLocation(latitude: restaurant1.latitude, longitude: restaurant1.longitude)
                let location2 = CLLocation(latitude: restaurant2.latitude, longitude: restaurant2.longitude)
                
                let distance1 = userLocation.distance(from: location1)
                let distance2 = userLocation.distance(from: location2)
                
                let hasNutrition1 = RestaurantData.restaurantsWithNutritionData.contains(restaurant1.name)
                let hasNutrition2 = RestaurantData.restaurantsWithNutritionData.contains(restaurant2.name)
                
                // Convert distances to miles for easier comparison
                let miles1 = distance1 / 1609.34
                let miles2 = distance2 / 1609.34
                
                // Define distance brackets (0.1 mile tolerance)
                let distanceTolerance = 0.1
                let distanceDifference = abs(miles1 - miles2)
                
                // If distances are very similar (within tolerance), prioritize nutrition data
                if distanceDifference <= distanceTolerance {
                    // Both have nutrition data or both don't - sort by exact distance
                    if hasNutrition1 == hasNutrition2 {
                        return distance1 < distance2
                    }
                    // One has nutrition data, one doesn't - prioritize nutrition data
                    return hasNutrition1 && !hasNutrition2
                }
                
                // If distances are significantly different, sort by distance primarily
                // But still give slight preference to nutrition data if distance difference is small
                if distanceDifference <= 0.3 { // Within 0.3 miles
                    // If both have different nutrition status and close distance, prefer nutrition data
                    if hasNutrition1 != hasNutrition2 {
                        // Only prefer nutrition data if the distance penalty is small
                        let nutritionPreference = hasNutrition1 && !hasNutrition2
                        
                        // If nutrition restaurant is only slightly farther (within 0.2 miles), prefer it
                        if nutritionPreference && miles1 <= miles2 + 0.2 {
                            return true
                        }
                        if !nutritionPreference && miles2 <= miles1 + 0.2 {
                            return false
                        }
                    }
                }
                
                // Default: sort by distance
                return distance1 < distance2
            }
        } else if selectedSortOptions.contains(.cuisine) {
            // Sort by cuisine if distance is not selected
            sorted = sorted.sorted { restaurant1, restaurant2 in
                let cuisine1 = restaurant1.cuisine ?? "Unknown"
                let cuisine2 = restaurant2.cuisine ?? "Unknown"
                return cuisine1.localizedCaseInsensitiveCompare(cuisine2) == .orderedAscending
            }
        } else if selectedSortOptions.isEmpty {
            // Fallback: Sort by name if no sorting options are selected
            sorted = sorted.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        
        return sorted
    }
    
    private func performRefresh() async {
        isRefreshing = true
        mediumFeedback.impactOccurred()
        
        // Simulate refresh delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isRefreshing = false
    }
}

struct RestaurantCard: View {
    let restaurant: Restaurant
    let userLocation: CLLocation?
    let hasNutritionData: Bool
    let onTap: () -> Void
    let onMapTap: () -> Void
    
    private var distance: String {
        guard let userLocation = userLocation else { return "Unknown" }
        
        let restaurantLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
        let distanceInMeters = userLocation.distance(from: restaurantLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        
        if distanceInMiles < 0.1 {
            return "< 0.1 mi"
        } else if distanceInMiles < 1.0 {
            return String(format: "%.1f mi", distanceInMiles)
        } else {
            return String(format: "%.1f mi", distanceInMiles)
        }
    }
    
    private var cuisineType: String {
        if let cuisine = restaurant.cuisine {
            return cuisine.capitalized
        }
        return "Fast Food"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Restaurant Image Placeholder
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
                .cornerRadius(12)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 24))
                            .foregroundColor(.blue.opacity(0.6))
                        
                        Text(restaurant.name.prefix(1).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                )
            
            // Restaurant Info
            VStack(alignment: .leading, spacing: 8) {
                // Name and Nutrition Data Indicator
                HStack {
                    Text(restaurant.name)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if hasNutritionData {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                            Text("Nutrition")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.red.opacity(0.1))
                        )
                    }
                }
                
                // Cuisine Type
                HStack {
                    Text(cuisineType)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    if let address = restaurant.address {
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text(address)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                // Distance and Actions
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text(distance)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: onMapTap) {
                            HStack(spacing: 4) {
                                Image(systemName: "map")
                                    .font(.system(size: 12))
                                Text("Map")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.blue.opacity(0.1))
                            )
                        }
                        
                        Button(action: onTap) {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                Text("Details")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.blue)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    ListView(
        restaurants: [
            Restaurant(
                id: 1,
                name: "McDonald's",
                latitude: 37.7749,
                longitude: -122.4194,
                address: "123 Main St",
                cuisine: "American",
                openingHours: "24/7",
                phone: "(555) 123-4567",
                website: "https://mcdonalds.com",
                type: "node"
            ),
            Restaurant(
                id: 2,
                name: "Chipotle Mexican Grill",
                latitude: 37.7849,
                longitude: -122.4094,
                address: "456 Oak Ave",
                cuisine: "Mexican",
                openingHours: "10:30 AM - 10:00 PM",
                phone: "(555) 987-6543",
                website: "https://chipotle.com",
                type: "node"
            )
        ],
        userLocation: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
}
