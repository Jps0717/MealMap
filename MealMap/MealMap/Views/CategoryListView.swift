import SwiftUI
import CoreLocation

struct CategoryListView: View {
    let category: RestaurantCategory
    let restaurants: [Restaurant]
    @Binding var isPresented: Bool
    
    @StateObject private var locationManager = LocationManager.shared
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    @State private var showingFilters = false
    @State private var isLoadingView = true
    @State private var isSearching = false
    
    @State private var currentFilter = RestaurantFilter()
    @State private var searchText = ""
    
    // Computed property for filtered restaurants
    private var filteredRestaurants: [Restaurant] {
        var result = restaurants
        
        if currentFilter.hasNutritionData != false {
            result = result.filter { restaurant in
                RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
            }
        }
        
        // Apply current filter (other filters)
        if currentFilter.hasActiveNonNutritionFilters {
            result = result.filter { restaurant in
                currentFilter.matchesRestaurant(restaurant, userLocation: locationManager.lastLocation?.coordinate)
            }
        }
        
        // Apply search text filter
        if !searchText.isEmpty {
            result = result.filter { restaurant in
                restaurant.name.localizedCaseInsensitiveContains(searchText) ||
                (restaurant.cuisine?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return result
    }
    
    // MARK: - Helper Methods
    
    private var activeFilterCount: Int {
        var count = 0
        if !currentFilter.specificChains.isEmpty { count += 1 }
        if !currentFilter.healthyTypes.isEmpty { count += 1 }
        if currentFilter.distanceRange != .all { count += 1 }
        if !currentFilter.cuisineTypes.isEmpty { count += 1 }
        if currentFilter.hasNutritionData != nil { count += 1 }
        if !currentFilter.amenities.isEmpty { count += 1 }
        return count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if isLoadingView {
                    CategoryLoadingView(category: category)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    mainContent
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .navigationTitle(category.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoadingView {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: category.color))
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
                .preferredColorScheme(.light) // Force light mode in restaurant detail
            }
        }
        .sheet(isPresented: $showingFilters) {
            RestaurantFilterView(
                filter: $currentFilter,
                isPresented: $showingFilters,
                availableRestaurants: restaurants,
                userLocation: locationManager.lastLocation?.coordinate
            )
        }
        .onAppear {
            setupCategoryView()
        }
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty && oldValue.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSearching = true
                }
                
                // Simulate search processing time
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSearching = false
                    }
                }
            } else if newValue.isEmpty {
                isSearching = false
            }
        }
    }
    
    // MARK: - Setup
    private func setupCategoryView() {
        currentFilter.category = category
        currentFilter.hasNutritionData = true
        
        // Simulate loading time for smooth UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoadingView = false
            }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                // Search bar with loading indicator
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                    
                    TextField("Search \(category.rawValue.lowercased()) restaurants...", text: $searchText)
                        .font(.system(size: 16))
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: category.color))
                    } else if !searchText.isEmpty {
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
                
                HStack {
                    Button(action: {
                        // Set category in filter to match current category
                        currentFilter.category = category
                        showingFilters = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Add Filters")
                                .font(.system(size: 16, weight: .semibold))
                            
                            if currentFilter.hasActiveNonCategoryFilters {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(currentFilter.hasActiveNonCategoryFilters ? Color.blue : category.color)
                        )
                    }
                    
                    Spacer()
                    
                    if currentFilter.hasActiveNonCategoryFilters {
                        Text("\(activeFilterCount) active filters")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color(.systemBackground))
            
            // Results count and sorting
            HStack {
                HStack(spacing: 8) {
                    if currentFilter.hasNutritionData != false {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text("With Nutrition")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                    
                    if isSearching {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .progressViewStyle(CircularProgressViewStyle(tint: category.color))
                            Text("Searching...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(category.color)
                        }
                    } else {
                        Text("\(filteredRestaurants.count) restaurants")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if filteredRestaurants.isEmpty && (currentFilter.hasActiveFilters || !searchText.isEmpty) {
                    Button("Clear Filters") {
                        currentFilter = RestaurantFilter()
                        currentFilter.category = category // Keep the category
                        currentFilter.hasNutritionData = true // Keep nutrition filter by default
                        searchText = ""
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            // Restaurant list with loading states
            if restaurants.isEmpty && !currentFilter.hasActiveFilters && searchText.isEmpty {
                // Show loading when no restaurants are provided and no filters are active
                LoadingView(
                    title: "Loading \(category.rawValue)",
                    subtitle: "Finding restaurants near you...",
                    progress: nil,
                    style: .fullScreen
                )
            } else if isSearching {
                // Show search loading
                VStack(spacing: 20) {
                    Spacer()
                    
                    SearchLoadingView(searchQuery: searchText)
                    
                    Text("Filtering \(restaurants.count) restaurants...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            } else if filteredRestaurants.isEmpty {
                EmptyResultsView(
                    hasFilters: currentFilter.hasActiveFilters || !searchText.isEmpty,
                    category: category,
                    hasNutritionFilter: currentFilter.hasNutritionData != false,
                    onDisableNutritionFilter: {
                        currentFilter.hasNutritionData = false
                    }
                )
            } else {
                List(filteredRestaurants, id: \.id) { restaurant in
                    CategoryRestaurantRow(
                        restaurant: restaurant,
                        action: {
                            selectedRestaurant = restaurant
                            showingRestaurantDetail = true
                        },
                        category: category
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

struct ActiveFilterChip: View {
    let title: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color)
        )
    }
}

struct EmptyResultsView: View {
    let hasFilters: Bool
    let category: RestaurantCategory
    let hasNutritionFilter: Bool
    let onDisableNutritionFilter: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: hasFilters ? "slider.horizontal.3" : category.icon)
                    .font(.system(size: 48))
                    .foregroundColor(category.color.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text(hasFilters ? "No matches found" : "No \(category.rawValue.lowercased()) restaurants")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if hasNutritionFilter && hasFilters {
                        Text("No \(category.rawValue.lowercased()) restaurants with nutrition data match your criteria.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    } else {
                        Text(hasFilters ? 
                             "Try adjusting your filters or search terms to find more restaurants." :
                             "We couldn't find any \(category.rawValue.lowercased()) restaurants in your area.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                
                if hasNutritionFilter {
                    VStack(spacing: 12) {
                        Text("Try showing restaurants without nutrition data")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: onDisableNutritionFilter) {
                            HStack(spacing: 8) {
                                Image(systemName: "eye")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Show All Restaurants")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(category.color)
                            )
                        }
                    }
                    .padding(.top, 8)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CategoryRestaurantRow: View {
    let restaurant: Restaurant
    let action: () -> Void
    let category: RestaurantCategory
    
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var nutritionManager = NutritionDataManager()
    @State private var isPressed = false
    @State private var isPreloading = false
    
    private var restaurantCategory: RestaurantCategory? {
        if restaurant.matchesCategory(category) {
            return category
        }
        
        // Otherwise, find any matching category
        for otherCategory in RestaurantCategory.allCases {
            if restaurant.matchesCategory(otherCategory) {
                return otherCategory
            }
        }
        return nil
    }
    
    var body: some View {
        Button(action: {
            // Preload nutrition data before navigation
            if RestaurantData.restaurantsWithNutritionData.contains(restaurant.name) {
                nutritionManager.preloadNutritionData(for: restaurant.name)
            }
            action()
        }) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(restaurantCategory?.color.opacity(0.1) ?? Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        VStack(spacing: 2) {
                            Image(systemName: restaurantCategory?.icon ?? "fork.knife")
                                .font(.system(size: 16))
                                .foregroundColor(restaurantCategory?.color ?? .gray)
                            
                            if RestaurantData.restaurantsWithNutritionData.contains(restaurant.name) {
                                if isPreloading {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(restaurantCategory?.color ?? Color.clear, lineWidth: restaurantCategory != nil ? 2 : 0)
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(restaurant.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let category = restaurantCategory {
                            Text(category.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(category.color)
                                )
                        }
                    }
                    
                    if let cuisine = restaurant.cuisine {
                        Text(cuisine.capitalized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        if let userLocation = locationManager.lastLocation {
                            let distance = calculateDistance(
                                from: userLocation.coordinate,
                                to: CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
                            )
                            
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(restaurantCategory?.color ?? .blue)
                                
                                Text(formatDistance(distance))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(restaurantCategory?.color ?? .blue)
                            }
                        }
                        
                        if RestaurantData.restaurantsWithNutritionData.contains(restaurant.name) {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                Text(isPreloading ? "Loading..." : "Nutrition")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    if isPreloading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    
                    if let category = restaurantCategory {
                        Circle()
                            .fill(category.color)
                            .frame(width: 6, height: 6)
                    }
                }
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
                        .fill(restaurantCategory?.color ?? Color.clear)
                        .frame(width: restaurantCategory != nil ? 4 : 0)
                    Spacer()
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isPreloading ? 0.8 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isPreloading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing && !isPreloading
            }
        }, perform: {})
        .onAppear {
            // Preload nutrition data for restaurants with nutrition data
            if RestaurantData.restaurantsWithNutritionData.contains(restaurant.name) {
                nutritionManager.preloadNutritionData(for: restaurant.name)
            }
        }
        .onChange(of: nutritionManager.isLoading) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                isPreloading = newValue
            }
        }
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        let miles = distance / 1609.34
        if miles < 0.1 {
            return "< 0.1 mi"
        } else if miles < 1.0 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.1f mi", miles)
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
