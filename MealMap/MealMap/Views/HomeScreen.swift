// MARK: - Enhanced Search with Dynamic Cuisines
private func performSearch() {
    Task { @MainActor in
        isSearching = true
        
        var allResults: [Restaurant] = []
        
        // 1. Search static nutrition data (for exact chain matches)
        let staticMatches = RestaurantData.restaurantsWithNutritionData.filter { restaurantName in
            restaurantName.localizedCaseInsensitiveContains(searchText)
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
                type: "chain"
            )
        }
        
        allResults.append(contentsOf: staticResults)
        
        // 2. Search live restaurant data near user location
        if let userLocation = locationManager.lastLocation?.coordinate {
            do {
                let nearbyRestaurants = try await OverpassAPIService().fetchAllNearbyRestaurants(
                    near: userLocation,
                    radius: 10.0
                )
                
                // ENHANCED: Search by name, cuisine, and cuisine search terms
                let liveMatches = nearbyRestaurants.filter { restaurant in
                    let searchLower = searchText.lowercased()
                    
                    // Check restaurant name
                    if restaurant.name.localizedCaseInsensitiveContains(searchText) {
                        return true
                    }
                    
                    // Check cuisine direct match
                    if let cuisine = restaurant.cuisine?.lowercased(),
                       cuisine.contains(searchLower) {
                        return true
                    }
                    
                    // Check cuisine search terms (dynamic)
                    if let cuisine = restaurant.cuisine {
                        let cuisineCategory = CuisineCategory(
                            name: cuisine,
                            count: 1,
                            emoji: getCuisineEmoji(for: cuisine),
                            searchTerms: generateSearchTerms(for: cuisine)
                        )
                        
                        return cuisineCategory.searchTerms.contains { term in
                            term.contains(searchLower) || searchLower.contains(term)
                        }
                    }
                    
                    return false
                }
                
                // Sort by distance from user
                let sortedLiveMatches = liveMatches.sorted { restaurant1, restaurant2 in
                    let distance1 = restaurant1.distanceFrom(userLocation)
                    let distance2 = restaurant2.distanceFrom(userLocation)
                    return distance1 < distance2
                }
                
                allResults.append(contentsOf: sortedLiveMatches)
                
            } catch {
                print("❌ Live search failed: \(error.localizedDescription)")
            }
        }
        
        // 3. Remove duplicates and prioritize results
        var seenNames: Set<String> = []
        let uniqueResults = allResults.filter { restaurant in
            let key = restaurant.name.lowercased()
            if seenNames.contains(key) {
                return false
            } else {
                seenNames.insert(key)
                return true
            }
        }
        
        // 4. Sort final results: nutrition data first, then by distance/relevance
        let finalResults = uniqueResults.sorted { restaurant1, restaurant2 in
            // Prioritize exact name matches
            let name1Match = restaurant1.name.localizedCaseInsensitiveContains(searchText)
            let name2Match = restaurant2.name.localizedCaseInsensitiveContains(searchText)
            
            if name1Match && !name2Match { return true }
            if !name1Match && name2Match { return false }
            
            // Then prioritize restaurants with nutrition data
            if restaurant1.hasNutritionData && !restaurant2.hasNutritionData {
                return true
            } else if !restaurant1.hasNutritionData && restaurant2.hasNutritionData {
                return false
            } else if let userLocation = locationManager.lastLocation?.coordinate {
                // Sort by distance if both have same nutrition status
                let distance1 = restaurant1.distanceFrom(userLocation)
                let distance2 = restaurant2.distanceFrom(userLocation)
                return distance1 < distance2
            } else {
                return restaurant1.name < restaurant2.name
            }
        }
        
        searchResults = Array(finalResults.prefix(15))
        isSearching = false
        
        // ENHANCED: Track search analytics
        AnalyticsService.shared.trackSearch(
            query: searchText,
            resultCount: searchResults.count,
            source: "home_screen_dynamic_search"
        )
        
        // Track user journey for search behavior
        AnalyticsService.shared.trackUserJourney(
            step: "search_completed",
            restaurantName: searchResults.first?.name
        )
    }
    
    private func performCategorySearch(_ category: RestaurantCategory) {
        Task { @MainActor in
            isSearching = true
            
            let categoryRestaurants: [String]
            
            switch category {
            case .fastFood:
                categoryRestaurants = ["McDonald's", "Burger King", "KFC", "Taco Bell", "Subway", "Wendy's", "Dunkin' Donuts", "Domino's"]
            case .healthy:
                categoryRestaurants = ["Panera Bread", "Chipotle", "Subway"]
            case .highProtein:
                categoryRestaurants = ["KFC", "Chick-fil-A", "Popeyes", "Chipotle"]
            case .lowCarb:
                categoryRestaurants = ["Chipotle", "Five Guys", "In-N-Out Burger"]
            }
            
            let results = categoryRestaurants.compactMap { name -> Restaurant? in
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
                    type: "chain"
                )
            }
            
            searchResults = results
            isSearching = false
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(foodTypes, id: \.name) { foodType in
                        NavigationLink(destination: FoodTypeCategoryView(
                            foodType: foodType,
                            mapViewModel: mapViewModel
                        )) {
                            FoodTypeCard(foodType: foodType)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }