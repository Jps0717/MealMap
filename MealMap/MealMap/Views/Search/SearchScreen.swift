import SwiftUI
import CoreLocation

struct SearchScreen: View {
    @Binding var isPresented: Bool
    @StateObject private var locationManager = LocationManager()
    @ObservedObject private var nutritionManager = NutritionDataManager.shared
    private let overpassService = OverpassAPIService()
    
    @State private var searchText = ""
    @State private var searchResults: [Restaurant] = []
    @State private var recentSearches: [String] = []
    @State private var popularSearches = ["McDonald's", "Subway", "Starbucks", "Chipotle", "KFC", "Taco Bell"]
    @State private var isSearching = false
    @State private var selectedRestaurant: Restaurant?
    @State private var searchWorkItem: DispatchWorkItem?
    
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchHeader
                
                if searchText.isEmpty {
                    suggestionsView
                } else {
                    searchResultsView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                isSearchFieldFocused = true
                loadRecentSearches()
            }
        }
        .sheet(item: $selectedRestaurant) { restaurant in
            RestaurantDetailView(
                restaurant: restaurant,
                isPresented: .constant(true),
                selectedCategory: nil
            )
        }
    }
    
    private var searchHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search restaurants...", text: $searchText)
                        .focused($isSearchFieldFocused)
                        .onChange(of: searchText) { _, newValue in
                            handleSearchTextChange(newValue)
                        }
                        .onSubmit {
                            if !searchText.isEmpty {
                                addToRecentSearches(searchText)
                                performInstantSearch(query: searchText)
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                            isSearching = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            if isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
    }
    
    private var suggestionsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !recentSearches.isEmpty {
                    recentSearchesSection
                }
                
                popularSearchesSection
                categorySuggestionsSection
            }
            .padding()
        }
    }
    
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Searches")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Clear") {
                    recentSearches.removeAll()
                    saveRecentSearches()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(recentSearches.prefix(6), id: \.self) { search in
                    SearchSuggestionButton(
                        text: search,
                        icon: "clock",
                        iconColor: .gray
                    ) {
                        searchText = search
                        performInstantSearch(query: search)
                    }
                }
            }
        }
    }
    
    private var popularSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular Searches")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(popularSearches, id: \.self) { search in
                    SearchSuggestionButton(
                        text: search,
                        icon: "flame",
                        iconColor: .orange
                    ) {
                        searchText = search
                        addToRecentSearches(search)
                        performInstantSearch(query: search)
                    }
                }
            }
        }
    }
    
    private var categorySuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search by Category")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                CategorySearchButton(
                    title: "Fast Food",
                    subtitle: "Burgers, fries, quick service",
                    icon: "🍔",
                    color: .orange
                ) {
                    searchText = "fast food"
                    performCategorySearch(.fastFood)
                }
                
                CategorySearchButton(
                    title: "Healthy Options",
                    subtitle: "Salads, fresh ingredients",
                    icon: "🥗",
                    color: .green
                ) {
                    searchText = "healthy"
                    performCategorySearch(.healthy)
                }
                
                CategorySearchButton(
                    title: "High Protein",
                    subtitle: "Protein-rich meals",
                    icon: "🥩",
                    color: .red
                ) {
                    searchText = "high protein"
                    performCategorySearch(.highProtein)
                }
            }
        }
    }
    
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !searchResults.isEmpty {
                HStack {
                    Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            List {
                ForEach(searchResults, id: \.id) { restaurant in
                    SearchResultRow(restaurant: restaurant) {
                        selectedRestaurant = restaurant
                        addToRecentSearches(restaurant.name)
                    }
                    .listRowBackground(Color(.systemBackground))
                }
            }
            .listStyle(.plain)
            
            if searchResults.isEmpty && !isSearching && !searchText.isEmpty {
                noResultsView
            }
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Results Found")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Try searching for:")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                ForEach(["McDonald's", "Subway", "Starbucks"], id: \.self) { suggestion in
                    Button(suggestion) {
                        searchText = suggestion
                        performInstantSearch(query: suggestion)
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        searchWorkItem?.cancel()
        
        if newValue.isEmpty {
            searchResults = []
            isSearching = false
        } else if newValue.count >= 2 {
            let workItem = DispatchWorkItem {
                Task { @MainActor in
                    await performSearch(query: newValue)
                }
            }
            searchWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }
    }
    
    private func performInstantSearch(query: String) {
        Task { @MainActor in
            await performSearch(query: query)
        }
    }
    
    private func performSearch(query: String) async {
        isSearching = true
        
        var allResults: [Restaurant] = []
        
        // 1. Search through restaurants with nutrition data (static list)
        let staticMatches = RestaurantData.restaurantsWithNutritionData.filter { restaurantName in
            restaurantName.localizedCaseInsensitiveContains(query)
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
                type: "node"
            )
        }
        
        allResults.append(contentsOf: staticResults)
        
        // 2. Search through live Overpass API restaurants
        if let userLocation = locationManager.lastLocation?.coordinate {
            do {
                let nearbyRestaurants = try await overpassService.fetchAllNearbyRestaurants(
                    near: userLocation,
                    zoomLevel: ZoomLevel.medium
                )
                
                let overpassMatches = nearbyRestaurants.filter { restaurant in
                    restaurant.name.localizedCaseInsensitiveContains(query) ||
                    restaurant.cuisine?.localizedCaseInsensitiveContains(query) == true ||
                    (restaurant.amenityType == "fast_food" && query.localizedCaseInsensitiveContains("fast food")) ||
                    (restaurant.amenityType == "restaurant" && query.localizedCaseInsensitiveContains("restaurant"))
                }
                
                let filteredOverpassMatches = overpassMatches.filter { overpassRestaurant in
                    !allResults.contains { staticRestaurant in
                        staticRestaurant.name.localizedCaseInsensitiveContains(overpassRestaurant.name) ||
                        overpassRestaurant.name.localizedCaseInsensitiveContains(staticRestaurant.name)
                    }
                }
                
                allResults.append(contentsOf: filteredOverpassMatches)
                
                debugLog("🔍 SEARCH RESULTS for '\(query)':")
                debugLog("   📊 Static matches: \(staticResults.count)")
                debugLog("   🌐 Overpass matches: \(filteredOverpassMatches.count)")
                debugLog("   📈 Total results: \(allResults.count)")
                
            } catch {
                debugLog("❌ Overpass search failed: \(error.localizedDescription)")
                // Continue with just static results if Overpass fails
            }
        }
        
        let sortedResults = allResults.sorted { first, second in
            let firstExact = first.name.localizedCaseInsensitiveCompare(query) == .orderedSame
            let secondExact = second.name.localizedCaseInsensitiveCompare(query) == .orderedSame
            
            if firstExact && !secondExact { return true }
            if !firstExact && secondExact { return false }
            
            let firstHasNutrition = RestaurantData.restaurantsWithNutritionData.contains(first.name)
            let secondHasNutrition = RestaurantData.restaurantsWithNutritionData.contains(second.name)
            
            if firstHasNutrition && !secondHasNutrition { return true }
            if !firstHasNutrition && secondHasNutrition { return false }
            
            if query.localizedCaseInsensitiveContains("fast food") {
                let firstIsFastFood = first.amenityType == "fast_food"
                let secondIsFastFood = second.amenityType == "fast_food"
                
                if firstIsFastFood && !secondIsFastFood { return true }
                if !firstIsFastFood && secondIsFastFood { return false }
            }
            
            if let userLocation = locationManager.lastLocation?.coordinate {
                let firstDistance = first.distanceFrom(userLocation)
                let secondDistance = second.distanceFrom(userLocation)
                return firstDistance < secondDistance
            }
            
            return first.name < second.name
        }
        
        self.searchResults = Array(sortedResults.prefix(25))
        self.isSearching = false
    }
    
    private func performCategorySearch(_ category: RestaurantCategory) {
        Task { @MainActor in
            isSearching = true
            
            var allResults: [Restaurant] = []
            
            let categoryRestaurants: [String]
            
            switch category {
            case .fastFood:
                categoryRestaurants = ["McDonald's", "Burger King", "KFC", "Taco Bell", "Subway", "Wendy's", "Dunkin'", "Domino's Pizza"]
            case .healthy:
                categoryRestaurants = ["Panera Bread", "Chipotle", "Subway", "Sweetgreen"]
            case .highProtein:
                categoryRestaurants = ["KFC", "Chick-fil-A", "Popeyes", "Chipotle", "Subway"]
            }
            
            let staticResults = categoryRestaurants.compactMap { name -> Restaurant? in
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
            
            allResults.append(contentsOf: staticResults)
            
            if let userLocation = locationManager.lastLocation?.coordinate {
                do {
                    let nearbyRestaurants: [Restaurant]
                    
                    switch category {
                    case .fastFood:
                        nearbyRestaurants = try await overpassService.fetchNutritionRestaurants(
                            near: userLocation,
                            radius: 5.0
                        )
                    case .healthy, .highProtein:
                        nearbyRestaurants = try await overpassService.fetchAllNearbyRestaurants(
                            near: userLocation,
                            zoomLevel: ZoomLevel.medium
                        )
                    }
                    
                    let categoryMatches = nearbyRestaurants.filter { restaurant in
                        restaurant.matchesCategory(category)
                    }
                    
                    let filteredCategoryMatches = categoryMatches.filter { overpassRestaurant in
                        !allResults.contains { staticRestaurant in
                            staticRestaurant.name.localizedCaseInsensitiveContains(overpassRestaurant.name) ||
                            overpassRestaurant.name.localizedCaseInsensitiveContains(staticRestaurant.name)
                        }
                    }
                    
                    allResults.append(contentsOf: filteredCategoryMatches)
                    
                    debugLog("🏷️ CATEGORY SEARCH for \(category.rawValue):")
                    debugLog("   📊 Static results: \(staticResults.count)")
                    debugLog("   🌐 Overpass results: \(filteredCategoryMatches.count)")
                    debugLog("   📈 Total results: \(allResults.count)")
                    
                } catch {
                    debugLog("❌ Category search failed: \(error.localizedDescription)")
                }
            }
            
            let sortedResults = allResults.sorted { first, second in
                let firstHasNutrition = RestaurantData.restaurantsWithNutritionData.contains(first.name)
                let secondHasNutrition = RestaurantData.restaurantsWithNutritionData.contains(second.name)
                
                if firstHasNutrition && !secondHasNutrition { return true }
                if !firstHasNutrition && secondHasNutrition { return false }
                
                if let userLocation = locationManager.lastLocation?.coordinate {
                    let firstDistance = first.distanceFrom(userLocation)
                    let secondDistance = second.distanceFrom(userLocation)
                    return firstDistance < secondDistance
                }
                
                return first.name < second.name
            }
            
            self.searchResults = Array(sortedResults.prefix(20))
            addToRecentSearches(category.rawValue)
            self.isSearching = false
        }
    }
    
    private func getCuisineType(for restaurantName: String) -> String {
        let fastFood = ["McDonald's", "Burger King", "KFC", "Taco Bell", "Wendy's"]
        let coffee = ["Starbucks", "Dunkin' Donuts"]
        
        if fastFood.contains(restaurantName) { return "Fast Food" }
        if coffee.contains(restaurantName) { return "Coffee" }
        return "Restaurant"
    }
    
    private func addToRecentSearches(_ search: String) {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        
        if recentSearches.count > 10 {
            recentSearches.removeLast()
        }
        
        saveRecentSearches()
    }
    
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: "RecentSearches"),
           let searches = try? JSONDecoder().decode([String].self, from: data) {
            recentSearches = searches
        }
    }
    
    private func saveRecentSearches() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: "RecentSearches")
        }
    }
}

// MARK: - Supporting Views

struct SearchSuggestionButton: View {
    let text: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.caption)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct CategorySearchButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
