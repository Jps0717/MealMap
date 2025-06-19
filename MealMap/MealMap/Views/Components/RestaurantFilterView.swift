import SwiftUI
import CoreLocation

struct RestaurantFilterView: View {
    @Binding var filter: RestaurantFilter
    @Binding var isPresented: Bool
    
    let availableRestaurants: [Restaurant]
    let userLocation: CLLocationCoordinate2D?
    
    @State private var localFilter: RestaurantFilter
    @State private var selectedSection: FilterSection = .chains
    
    init(filter: Binding<RestaurantFilter>, isPresented: Binding<Bool>, availableRestaurants: [Restaurant], userLocation: CLLocationCoordinate2D?) {
        self._filter = filter
        self._isPresented = isPresented
        self.availableRestaurants = availableRestaurants
        self.userLocation = userLocation
        self._localFilter = State(initialValue: filter.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter section tabs (without category)
                filterSectionTabs
                
                // Content based on selected section
                ScrollView {
                    LazyVStack(spacing: 20) {
                        switch selectedSection {
                        case .chains:
                            chainsSection
                        case .distance:
                            distanceSection
                        case .cuisine:
                            cuisineSection
                        case .amenities:
                            amenitiesSection
                        }
                        
                        // Results preview
                        resultsPreviewSection
                        
                        // Bottom padding
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Additional Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        let currentCategory = localFilter.category
                        localFilter = RestaurantFilter.empty()
                        localFilter.category = currentCategory // Keep the category
                    }
                    .disabled(!localFilter.hasActiveNonCategoryFilters)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        filter = localFilter
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Filter Section Tabs (without category)
    
    private var filterSectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach([FilterSection.chains, FilterSection.distance, FilterSection.cuisine, FilterSection.amenities], id: \.self) { section in
                    FilterSectionTab(
                        section: section,
                        isSelected: selectedSection == section,
                        hasActiveFilter: sectionHasActiveFilter(section)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSection = section
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Category", subtitle: "Choose your dining preference")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(RestaurantCategory.allCases, id: \.self) { category in
                    CategoryFilterCard(
                        category: category,
                        isSelected: localFilter.category == category,
                        restaurantCount: countRestaurantsForCategory(category)
                    ) {
                        if localFilter.category == category {
                            localFilter.category = nil
                        } else {
                            localFilter.category = category
                            // Clear conflicting filters when category changes
                            localFilter.specificChains.removeAll()
                            localFilter.healthyTypes.removeAll()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Chains Section (enhanced for category context)
    
    private var chainsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let category = localFilter.category {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(category.color)
                        Text("Filtering \(category.rawValue) restaurants")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(category.color.opacity(0.1))
                    )
                }
            }
            
            sectionHeader("Specific Chains", subtitle: "Filter by restaurant brands")
            
            if let category = localFilter.category {
                switch category {
                case .fastFood:
                    fastFoodChainsGrid
                case .healthy:
                    healthyChainsGrid
                default:
                    popularChainsGrid
                }
            } else {
                popularChainsGrid
            }
        }
    }
    
    private var fastFoodChainsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(PopularChains.fastFoodChains, id: \.self) { chain in
                ChainFilterChip(
                    name: chain,
                    isSelected: localFilter.specificChains.contains(chain),
                    count: countRestaurantsForChain(chain)
                ) {
                    toggleChainFilter(chain)
                }
            }
        }
    }
    
    private var healthyChainsGrid: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(PopularChains.healthyChains, id: \.self) { chain in
                    ChainFilterChip(
                        name: chain,
                        isSelected: localFilter.specificChains.contains(chain),
                        count: countRestaurantsForChain(chain)
                    ) {
                        toggleChainFilter(chain)
                    }
                }
            }
            
            // Healthy types section
            VStack(alignment: .leading, spacing: 12) {
                Text("Healthy Types")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(HealthyType.allCases, id: \.self) { type in
                        HealthyTypeChip(
                            type: type,
                            isSelected: localFilter.healthyTypes.contains(type),
                            count: countRestaurantsForHealthyType(type)
                        ) {
                            toggleHealthyTypeFilter(type)
                        }
                    }
                }
            }
        }
    }
    
    private var popularChainsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(PopularChains.fastFoodChains.prefix(15), id: \.self) { chain in
                ChainFilterChip(
                    name: chain,
                    isSelected: localFilter.specificChains.contains(chain),
                    count: countRestaurantsForChain(chain)
                ) {
                    toggleChainFilter(chain)
                }
            }
        }
    }
    
    // MARK: - Distance Section
    
    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Distance", subtitle: "How far are you willing to travel?")
            
            VStack(spacing: 12) {
                ForEach(DistanceRange.allCases, id: \.self) { range in
                    DistanceRangeRow(
                        range: range,
                        isSelected: localFilter.distanceRange == range,
                        restaurantCount: countRestaurantsForDistance(range)
                    ) {
                        localFilter.distanceRange = range
                    }
                }
            }
        }
    }
    
    // MARK: - Cuisine Section
    
    private var cuisineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Cuisine Type", subtitle: "Select your preferred cuisines")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CuisineTypes.popular, id: \.self) { cuisine in
                    CuisineFilterChip(
                        name: cuisine,
                        isSelected: localFilter.cuisineTypes.contains(cuisine),
                        count: countRestaurantsForCuisine(cuisine)
                    ) {
                        toggleCuisineFilter(cuisine)
                    }
                }
            }
        }
    }
    
    // MARK: - Amenities Section
    
    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Amenities", subtitle: "Services and features you need")
            
            VStack(spacing: 12) {
                // Nutrition data toggle
                NutritionDataToggle(
                    hasNutritionData: localFilter.hasNutritionData,
                    restaurantCount: countRestaurantsWithNutrition()
                ) { value in
                    localFilter.hasNutritionData = value
                }
                
                // Other amenities (simplified for now)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(RestaurantAmenity.allCases.prefix(4), id: \.self) { amenity in
                        AmenityFilterChip(
                            amenity: amenity,
                            isSelected: localFilter.amenities.contains(amenity)
                        ) {
                            toggleAmenityFilter(amenity)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Results Preview Section
    
    private var resultsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Results Preview")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(filteredRestaurantCount) restaurants")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            if filteredRestaurantCount == 0 {
                EmptyFilterResultsView()
            } else {
                Text("Tap 'Apply' to see filtered results")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Helper Methods
    
    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    private func sectionHasActiveFilter(_ section: FilterSection) -> Bool {
        switch section {
        case .chains:
            return !localFilter.specificChains.isEmpty || !localFilter.healthyTypes.isEmpty
        case .distance:
            return localFilter.distanceRange != .all
        case .cuisine:
            return !localFilter.cuisineTypes.isEmpty
        case .amenities:
            return !localFilter.amenities.isEmpty || localFilter.hasNutritionData != nil
        }
    }
    
    private var filteredRestaurantCount: Int {
        return availableRestaurants.filter { restaurant in
            localFilter.matchesRestaurant(restaurant, userLocation: userLocation)
        }.count
    }
    
    // MARK: - Counting Methods
    
    private func countRestaurantsForCategory(_ category: RestaurantCategory) -> Int {
        return availableRestaurants.filter { $0.matchesCategory(category) }.count
    }
    
    private func countRestaurantsForChain(_ chain: String) -> Int {
        return availableRestaurants.filter { restaurant in
            restaurant.name.lowercased().contains(chain.lowercased())
        }.count
    }
    
    private func countRestaurantsForHealthyType(_ type: HealthyType) -> Int {
        return availableRestaurants.filter { restaurant in
            restaurant.matchesHealthyType(type)
        }.count
    }
    
    private func countRestaurantsForDistance(_ range: DistanceRange) -> Int {
        guard let userLocation = userLocation else { return availableRestaurants.count }
        return availableRestaurants.filter { restaurant in
            let distance = restaurant.distanceFrom(userLocation)
            return range.contains(distance)
        }.count
    }
    
    private func countRestaurantsForCuisine(_ cuisine: String) -> Int {
        return availableRestaurants.filter { restaurant in
            let restaurantCuisine = restaurant.cuisine?.lowercased() ?? ""
            return restaurantCuisine.contains(cuisine.lowercased()) ||
                   restaurant.name.lowercased().contains(cuisine.lowercased())
        }.count
    }
    
    private func countRestaurantsWithNutrition() -> Int {
        return availableRestaurants.filter { restaurant in
            RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
        }.count
    }
    
    // MARK: - Filter Toggle Methods
    
    private func toggleChainFilter(_ chain: String) {
        if localFilter.specificChains.contains(chain) {
            localFilter.specificChains.remove(chain)
        } else {
            localFilter.specificChains.insert(chain)
        }
    }
    
    private func toggleHealthyTypeFilter(_ type: HealthyType) {
        if localFilter.healthyTypes.contains(type) {
            localFilter.healthyTypes.remove(type)
        } else {
            localFilter.healthyTypes.insert(type)
        }
    }
    
    private func toggleCuisineFilter(_ cuisine: String) {
        if localFilter.cuisineTypes.contains(cuisine) {
            localFilter.cuisineTypes.remove(cuisine)
        } else {
            localFilter.cuisineTypes.insert(cuisine)
        }
    }
    
    private func toggleAmenityFilter(_ amenity: RestaurantAmenity) {
        if localFilter.amenities.contains(amenity) {
            localFilter.amenities.remove(amenity)
        } else {
            localFilter.amenities.insert(amenity)
        }
    }
}

// MARK: - Filter Section Enum (updated without category)

enum FilterSection: String, CaseIterable {
    case chains = "Chains"
    case distance = "Distance"
    case cuisine = "Cuisine"
    case amenities = "Features"
    
    var icon: String {
        switch self {
        case .chains: return "building.2"
        case .distance: return "location"
        case .cuisine: return "fork.knife"
        case .amenities: return "checkmark.circle"
        }
    }
}

// MARK: - Filter Components

struct FilterSectionTab: View {
    let section: FilterSection
    let isSelected: Bool
    let hasActiveFilter: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(section.rawValue)
                    .font(.system(size: 14, weight: .medium))
                
                if hasActiveFilter {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.systemBackground))
            )
        }
    }
}

struct CategoryFilterCard: View {
    let category: RestaurantCategory
    let isSelected: Bool
    let restaurantCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 24, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Text("\(restaurantCount)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? category.color : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(category.color, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

struct ChainFilterChip: View {
    let name: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.orange : Color(.systemGray6))
            )
        }
        .disabled(count == 0)
        .opacity(count == 0 ? 0.5 : 1.0)
    }
}

struct HealthyTypeChip: View {
    let type: HealthyType
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("(\(count))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.green : Color(.systemGray6))
            )
        }
        .disabled(count == 0)
        .opacity(count == 0 ? 0.5 : 1.0)
    }
}

struct DistanceRangeRow: View {
    let range: DistanceRange
    let isSelected: Bool
    let restaurantCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(range.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("\(restaurantCount) restaurants")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
        }
    }
}

struct CuisineFilterChip: View {
    let name: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.purple : Color(.systemGray6))
            )
        }
        .disabled(count == 0)
        .opacity(count == 0 ? 0.5 : 1.0)
    }
}

struct NutritionDataToggle: View {
    let hasNutritionData: Bool?
    let restaurantCount: Int
    let onToggle: (Bool?) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nutrition Data Available")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Only show restaurants with nutrition information")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                FilterToggleButton(
                    title: "All",
                    isSelected: hasNutritionData == nil,
                    count: nil
                ) {
                    onToggle(nil)
                }
                
                FilterToggleButton(
                    title: "With Nutrition",
                    isSelected: hasNutritionData == true,
                    count: restaurantCount
                ) {
                    onToggle(true)
                }
                
                FilterToggleButton(
                    title: "Without",
                    isSelected: hasNutritionData == false,
                    count: nil
                ) {
                    onToggle(false)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct FilterToggleButton: View {
    let title: String
    let isSelected: Bool
    let count: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.green : Color(.systemBackground))
            )
        }
    }
}

struct AmenityFilterChip: View {
    let amenity: RestaurantAmenity
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: amenity.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(amenity.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
        }
    }
}

struct EmptyFilterResultsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("No restaurants match your filters")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Try adjusting your filters to see more results")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
}

#Preview {
    RestaurantFilterView(
        filter: .constant(RestaurantFilter()),
        isPresented: .constant(true),
        availableRestaurants: [],
        userLocation: nil
    )
}
