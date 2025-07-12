import Foundation
import CoreLocation
import SwiftUI

/// Enhanced Restaurant Model with improved nutrition data detection
struct Restaurant: Identifiable, Equatable, Hashable, Codable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let cuisine: String?
    let openingHours: String?
    let phone: String?
    let website: String?
    let type: String
    
    var amenityType: String? = nil
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    func distanceFrom(_ coordinate: CLLocationCoordinate2D) -> Double {
        let restaurantLocation = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distanceInMeters = restaurantLocation.distance(from: userLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        return distanceInMiles
    }
    
    // ENHANCED: Improved nutrition data detection
    var hasNutritionData: Bool {
        // Use the RestaurantData helper for consistent detection
        return RestaurantData.hasNutritionData(for: self.name)
    }
    
    // Get restaurant ID for API calls
    var restaurantID: String? {
        return RestaurantData.getRestaurantID(for: self.name)
    }
    
    // Enhanced emoji logic based on restaurant name and type
    var emoji: String {
        let name = self.name.lowercased()
        
        // Chain-specific emojis
        if name.contains("mcdonald") { return "🍟" }
        if name.contains("burger king") { return "👑" }
        if name.contains("subway") { return "🥪" }
        if name.contains("starbucks") { return "☕" }
        if name.contains("domino") { return "🍕" }
        if name.contains("pizza hut") { return "🍕" }
        if name.contains("taco bell") { return "🌮" }
        if name.contains("chipotle") { return "🌯" }
        if name.contains("wendy") { return "🍔" }
        if name.contains("kfc") { return "🍗" }
        if name.contains("popeyes") { return "🍗" }
        if name.contains("chick-fil-a") { return "🐔" }
        if name.contains("dunkin") { return "🍩" }
        if name.contains("baskin") || name.contains("dairy queen") { return "🍦" }
        if name.contains("panera") { return "🥖" }
        if name.contains("five guys") { return "🍔" }
        if name.contains("in-n-out") { return "🍔" }
        if name.contains("shake shack") { return "🥤" }
        
        // Cuisine-specific emojis
        if name.contains("sushi") || cuisine?.lowercased().contains("sushi") == true { return "🍣" }
        if name.contains("chinese") || cuisine?.lowercased().contains("chinese") == true { return "🥡" }
        if name.contains("italian") || cuisine?.lowercased().contains("italian") == true { return "🍝" }
        if name.contains("mexican") || cuisine?.lowercased().contains("mexican") == true { return "🌮" }
        if name.contains("thai") || cuisine?.lowercased().contains("thai") == true { return "🍜" }
        if name.contains("indian") || cuisine?.lowercased().contains("indian") == true { return "🍛" }
        if name.contains("seafood") || cuisine?.lowercased().contains("seafood") == true { return "🦐" }
        if name.contains("steakhouse") || name.contains("steak") { return "🥩" }
        if name.contains("bbq") || name.contains("barbecue") { return "🍖" }
        if name.contains("deli") { return "🥪" }
        if name.contains("bakery") { return "🧁" }
        if name.contains("ice cream") { return "🍦" }
        
        // Type-based fallbacks
        switch amenityType {
        case "fast_food":
            return "🍔"
        case "restaurant":
            return "🍽️"
        case "cafe":
            return "☕"
        case "bar", "pub":
            return "🍻"
        case "bakery":
            return "🥖"
        case "ice_cream":
            return "🍦"
        case "food_court":
            return "🍱"
        default:
            return "🍽️"
        }
    }
    
    // ENHANCED: Color based on nutrition data availability
    var pinColor: Color {
        // Priority: Nutrition data gets distinctive colors
        if hasNutritionData {
            return .green // Nutrition data available - bright green
        }
        
        // Fallback color by amenity type
        switch amenityType {
        case "fast_food":
            return .orange
        case "restaurant":
            return .blue
        case "cafe":
            return .brown
        case "bar", "pub":
            return .purple
        case "bakery":
            return .pink
        case "ice_cream":
            return .cyan
        case "food_court":
            return .indigo
        default:
            return .gray
        }
    }
    
    // Background color for contrast
    var pinBackgroundColor: Color {
        return pinColor.opacity(0.9)
    }
    
    // ENHANCED: Category matching logic for better filtering
    func matchesCategory(_ category: RestaurantCategory) -> Bool {
        let name = self.name.lowercased()
        let cuisine = self.cuisine?.lowercased() ?? ""
        
        switch category {
        case .fastFood:
            // Include all restaurants with nutrition data (mainly fast food chains)
            if hasNutritionData { return true }
            
            // Include fast food amenity types
            if amenityType == "fast_food" { return true }
            
            // Include known fast food terms
            let fastFoodTerms = ["burger", "pizza", "taco", "chicken", "drive", "wings", 
                                "fries", "donut", "ice cream", "shake", "grill"]
            return fastFoodTerms.contains { term in
                name.contains(term) || cuisine.contains(term)
            }
            
        case .healthy:
            // Include nutrition chains known for healthy options
            if hasNutritionData {
                let healthyChains = ["subway", "panera", "chipotle", "sweetgreen", "chopt"]
                if healthyChains.contains(where: { name.contains($0) }) {
                    return true
                }
            }
            
            // Include healthy keywords
            let healthyTerms = ["salad", "fresh", "bowl", "juice", "smoothie", "organic", 
                               "green", "garden", "harvest", "natural", "vegetarian", "vegan",
                               "mediterranean", "quinoa", "kale", "avocado"]
            return healthyTerms.contains { term in
                name.contains(term) || cuisine.contains(term)
            }
            
        case .highProtein:
            // Include nutrition chains known for high protein
            if hasNutritionData {
                let proteinChains = ["kfc", "popeyes", "chick", "outback", "longhorn", 
                                    "texas roadhouse", "applebee", "olive garden"]
                if proteinChains.contains(where: { name.contains($0) }) {
                    return true
                }
            }
            
            // Include high protein keywords
            let proteinTerms = ["grill", "steakhouse", "bbq", "barbecue", "chicken", "protein", 
                               "meat", "beef", "steak", "wings", "seafood", "fish", "salmon"]
            return proteinTerms.contains { term in
                name.contains(term) || cuisine.contains(term)
            }
            
        case .lowCarb:
            let restaurant = self
            let name = restaurant.name.lowercased()
            let cuisine = restaurant.cuisine?.lowercased() ?? ""
            let amenity = restaurant.amenityType ?? ""
            
            let includeByType = amenity == "restaurant" ||
                               amenity == "fast_food" ||
                               amenity == "cafe"
            
            let includeByKeywords = 
                name.contains("grill") ||
                name.contains("steakhouse") ||
                name.contains("bbq") ||
                name.contains("barbecue") ||
                name.contains("burger") ||
                name.contains("chicken") ||
                name.contains("seafood") ||
                name.contains("steak") ||
                cuisine.contains("steak") ||
                cuisine.contains("seafood") ||
                cuisine.contains("grill") ||
                cuisine.contains("barbecue") ||
                cuisine.contains("american") ||
                
                name.contains("salad") ||
                name.contains("bowl") ||
                name.contains("fresh") ||
                name.contains("organic") ||
                name.contains("vegetarian") ||
                name.contains("vegan") ||
                cuisine.contains("vegetarian") ||
                cuisine.contains("vegan") ||
                cuisine.contains("mediterranean") ||
                
                name.contains("gluten") ||
                name.contains("celiac") ||
                name.contains("paleo") ||
                
                name.contains("keto") ||
                name.contains("atkins") ||
                name.contains("bunless") ||
                name.contains("lettuce wrap") ||
                
                name.contains("chipotle") ||
                name.contains("five guys") ||
                name.contains("in-n-out") ||
                name.contains("chick-fil-a")
            
            let includeNutritionChains = RestaurantData.hasNutritionData(for: restaurant.name)
            
            let excludeHighCarb = amenity == "bakery" ||
                                 name.contains("donut") ||
                                 name.contains("doughnut") ||
                                 name.contains("ice cream") ||
                                 name.contains("pizza") ||
                                 name.contains("pasta") ||
                                 name.contains("noodle") ||
                                 name.contains("bread") ||
                                 name.contains("bagel") ||
                                 cuisine.contains("pizza") ||
                                 cuisine.contains("dessert") ||
                                 cuisine.contains("bakery")
            
            return (includeByType || includeByKeywords || includeNutritionChains) && !excludeHighCarb
        }
    }
    
    func matchesHealthyType(_ type: HealthyType) -> Bool {
        let name = self.name.lowercased()
        return type.searchTerms.contains { term in
            name.contains(term)
        }
    }
}

extension Restaurant {
    /// Get the current map score for this restaurant
    var mapScore: RestaurantMapScore? {
        return RestaurantMapScoringService.shared.getScoreForRestaurant(self)
    }
    
    /// Enhanced pin color that includes scoring information
    var enhancedPinColor: Color {
        // Priority: Show scoring color if available
        if let score = mapScore {
            return score.scoreColor
        }
        
        // Fallback to nutrition data indication
        if hasNutritionData {
            return .green
        }
        
        // Default color by amenity type
        switch amenityType {
        case "fast_food":
            return .orange
        case "restaurant":
            return .blue
        case "cafe":
            return .brown
        case "bar", "pub":
            return .purple
        case "bakery":
            return .pink
        case "ice_cream":
            return .cyan
        case "food_court":
            return .indigo
        default:
            return .gray
        }
    }
    
    /// Enhanced emoji that includes scoring information
    var enhancedEmoji: String {
        // Priority: Show score emoji if available
        if let score = mapScore {
            return score.scoreEmoji
        }
        
        // Fallback to restaurant emoji
        return emoji
    }
    
    /// Pin subtitle for scoring information
    var scoringSubtitle: String? {
        if let score = mapScore {
            return score.shortDescription
        }
        
        if hasNutritionData {
            return "Nutrition data available"
        }
        
        return amenityType?.capitalized ?? "Restaurant"
    }
}

// MARK: - Low Carb Diet Types
enum LowCarbDietType: String, CaseIterable {
    case vegetarian = "Vegetarian Low Carb"
    case vegan = "Vegan Low Carb" 
    case glutenFree = "Gluten-Free Low Carb"
    case meat = "Meat-Based Low Carb"
    
    var dietTag: String {
        switch self {
        case .vegetarian: return "diet:vegetarian"
        case .vegan: return "diet:vegan"
        case .glutenFree: return "diet:gluten_free"
        case .meat: return "diet:meat"
        }
    }
    
    var cuisineFilter: String {
        switch self {
        case .vegetarian: return "vegetarian|mediterranean|indian|thai"
        case .vegan: return "vegan|vegetarian|raw_food"
        case .glutenFree: return "gluten_free|seafood|steak|grill"
        case .meat: return "steak|barbecue|grill|american|brazilian"
        }
    }
    
    var nameFilter: String {
        switch self {
        case .vegetarian: return "vegetarian|veggie|garden|green|fresh"
        case .vegan: return "vegan|plant|raw|green|juice"
        case .glutenFree: return "gluten.free|gf|celiac|paleo|keto"
        case .meat: return "steak|grill|bbq|barbecue|meat|carnivore"
        }
    }
    
    var emoji: String {
        switch self {
        case .vegetarian: return "🥗"
        case .vegan: return "🌱"
        case .glutenFree: return "🚫🌾"
        case .meat: return "🥩"
        }
    }
    
    var description: String {
        switch self {
        case .vegetarian: return "Plant-based proteins, dairy, eggs"
        case .vegan: return "Plant-based only, no animal products"
        case .glutenFree: return "No wheat, barley, rye, or gluten"
        case .meat: return "Focus on meat, poultry, seafood"
        }
    }
}

/// Enhanced Overpass API Service as ObservableObject
final class OverpassAPIService: ObservableObject {
    private let baseURLs = [
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass-api.de/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ]
    private var currentURLIndex = 0
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// Fetch category-specific restaurants within radius
    func fetchCategoryRestaurants(category: RestaurantCategory, near coordinate: CLLocationCoordinate2D, radius: Double = 5.0) async throws -> [Restaurant] {
        print("🍽️ CATEGORY FETCH: \(category.rawValue) near \(coordinate)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        // Convert to bounding box
        let radiusInDegrees = radius / 69.0
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLon = coordinate.longitude - radiusInDegrees
        let maxLon = coordinate.longitude + radiusInDegrees
        
        // Create category-specific query
        let query = createCategoryOptimizedQuery(
            category: category, 
            minLat: minLat, 
            minLon: minLon, 
            maxLat: maxLat, 
            maxLon: maxLon
        )
        
        let allRestaurants = try await executeQuery(query)
        
        // Filter by category for additional validation
        let categoryRestaurants = allRestaurants.filter { $0.matchesCategory(category) }
        
        print("🍽️ SUCCESS: Found \(categoryRestaurants.count) \(category.rawValue) restaurants")
        return categoryRestaurants
    }
    
    /// Direct map viewport fetch optimized for nutrition chains
    func fetchRestaurants(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [Restaurant] {
        print("🗺️ DIRECT FETCH: Getting restaurants for map viewport")
        print("🗺️ Bounds: (\(minLat), \(minLon)) to (\(maxLat), \(maxLon))")
        
        // ENHANCED: Query optimized for nutrition chains
        let query = createNutritionOptimizedQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        let restaurants = try await executeQuery(query)
        
        print("🗺️ SUCCESS: Found \(restaurants.count) restaurants for map viewport")
        return restaurants
    }
    
    /// BACKWARD COMPATIBILITY: Support existing methods
    func fetchAllNearbyRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 5.0) async throws -> [Restaurant] {
        // Convert to bounding box and use direct fetch
        let radiusInDegrees = radius / 69.0
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLon = coordinate.longitude - radiusInDegrees
        let maxLon = coordinate.longitude + radiusInDegrees
        
        return try await fetchRestaurants(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
    }
    
    func fetchRestaurantsForViewport(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double, zoomLevel: ZoomLevel) async throws -> [Restaurant] {
        return try await fetchRestaurants(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
    }
    
    func fetchNutritionRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 5.0) async throws -> [Restaurant] {
        let allRestaurants = try await fetchAllNearbyRestaurants(near: coordinate, radius: radius)
        return allRestaurants.filter { $0.hasNutritionData }
    }
    
    func fetchFastFoodRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 5.0) async throws -> [Restaurant] {
        let allRestaurants = try await fetchAllNearbyRestaurants(near: coordinate, radius: radius)
        return allRestaurants.filter { $0.amenityType == "fast_food" || $0.hasNutritionData }
    }
    
    func fetchAllNearbyRestaurants(near coordinate: CLLocationCoordinate2D, zoomLevel: ZoomLevel) async throws -> [Restaurant] {
        return try await fetchAllNearbyRestaurants(near: coordinate, radius: 5.0)
    }
    
    /// Fetch restaurants with specific diet tags for low carb options
    func fetchLowCarbRestaurants(dietType: LowCarbDietType, near coordinate: CLLocationCoordinate2D, radius: Double = 5.0) async throws -> [Restaurant] {
        print("🥗 LOW CARB FETCH: Searching for \(dietType.rawValue) near \(coordinate)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        // Convert to bounding box
        let radiusInDegrees = radius / 69.0
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLon = coordinate.longitude - radiusInDegrees
        let maxLon = coordinate.longitude + radiusInDegrees
        
        // Create diet-specific query for low carb
        let query = createLowCarbDietQuery(dietType: dietType, minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        let restaurants = try await executeQuery(query)
        
        // Sort by distance from user
        let sortedRestaurants = restaurants.sorted { restaurant1, restaurant2 in
            let distance1 = restaurant1.distanceFrom(coordinate)
            let distance2 = restaurant2.distanceFrom(coordinate)
            return distance1 < distance2
        }
        
        print("🥗 SUCCESS: Found \(sortedRestaurants.count) \(dietType.rawValue) low carb restaurants")
        return sortedRestaurants
    }
    
    /// Fetch restaurants with specific diet tags (e.g., diet:meat for high protein)
    func fetchRestaurantsByDiet(diet: String, near coordinate: CLLocationCoordinate2D, radius: Double = 5.0) async throws -> [Restaurant] {
        print("🥩 DIET FETCH: Searching for diet:\(diet) near \(coordinate)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        // Convert to bounding box
        let radiusInDegrees = radius / 69.0
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLon = coordinate.longitude - radiusInDegrees
        let maxLon = coordinate.longitude + radiusInDegrees
        
        // Create diet-specific query
        let query = createDietQuery(diet: diet, minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        let restaurants = try await executeQuery(query)
        
        // Sort by distance from user
        let sortedRestaurants = restaurants.sorted { restaurant1, restaurant2 in
            let distance1 = restaurant1.distanceFrom(coordinate)
            let distance2 = restaurant2.distanceFrom(coordinate)
            return distance1 < distance2
        }
        
        print("🥩 SUCCESS: Found \(sortedRestaurants.count) restaurants with diet:\(diet)")
        return sortedRestaurants
    }
    
    /// Create low carb diet-specific Overpass query
    private func createLowCarbDietQuery(dietType: LowCarbDietType, minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        let dietTag = dietType.dietTag
        let cuisineFilter = dietType.cuisineFilter
        let nameFilter = dietType.nameFilter
        
        return """
        [out:json][timeout:15][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
        (
          // Restaurants with specific diet tag
          node["amenity"="restaurant"]["\(dietTag)"~"yes|only"];
          
          // Fast food with specific diet tag
          node["amenity"="fast_food"]["\(dietTag)"~"yes|only"];
          
          // Cafes with specific diet tag
          node["amenity"="cafe"]["\(dietTag)"~"yes|only"];
          
          // Cuisine-based filtering
          node["amenity"="restaurant"]["cuisine"~"\(cuisineFilter)"];
          
          // Name-based filtering for specific diet types
          node["amenity"~"restaurant|fast_food|cafe"]["name"~"\(nameFilter)",i];
          
          // Steakhouses and grills (good for all low carb diets)
          node["amenity"="restaurant"]["cuisine"~"steak|grill|barbecue"];
          
          // Seafood restaurants (good for all low carb diets)
          node["amenity"="restaurant"]["cuisine"~"seafood|fish"];
        );
        out;
        """
    }
    
    /// Create diet-specific Overpass query
    private func createDietQuery(diet: String, minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        return """
        [out:json][timeout:15][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
        (
          // Restaurants with specific diet tag
          node["amenity"="restaurant"]["diet:\(diet)"~"yes|only"];
          
          // Fast food with specific diet tag
          node["amenity"="fast_food"]["diet:\(diet)"~"yes|only"];
          
          // Cafes with specific diet tag
          node["amenity"="cafe"]["diet:\(diet)"~"yes|only"];
          
          // Pubs and bars with specific diet tag
          node["amenity"="pub"]["diet:\(diet)"~"yes|only"];
          node["amenity"="bar"]["diet:\(diet)"~"yes|only"];
        );
        out;
        """
    }
    
    /// ENHANCED: Category-specific query optimization
    private func createCategoryOptimizedQuery(category: RestaurantCategory, minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        switch category {
        case .fastFood:
            // Focus on fast food and known nutrition chains
            let knownChains = ["McDonald's", "Burger King", "KFC", "Taco Bell", "Wendy's", 
                              "Subway", "Pizza Hut", "Domino's", "Chick-fil-A", "Five Guys"]
            let chainQueries = knownChains.map { chain in
                "node[\"name\"~\"\(chain)\",i][\"amenity\"~\"restaurant|fast_food|cafe\"]"
            }.joined(separator: ";\n  ")
            
            return """
            [out:json][timeout:15][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
            (
              // Known fast food chains
              \(chainQueries);
              
              // All fast food
              node["amenity"="fast_food"];
              
              // Pizza places
              node["amenity"="restaurant"]["cuisine"~"pizza"];
              
              // Burger places
              node["amenity"="restaurant"]["name"~"burger",i];
            );
            out;
            """
            
        case .healthy:
            return """
            [out:json][timeout:15][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
            (
              // Healthy chains
              node["name"~"Panera|Chipotle|Sweetgreen|Chopt|Subway",i]["amenity"~"restaurant|fast_food|cafe"];
              
              // Salad-focused restaurants
              node["amenity"="restaurant"]["name"~"salad|fresh|bowl|juice|smoothie|organic",i];
              
              // Vegetarian/Vegan restaurants
              node["amenity"="restaurant"]["cuisine"~"vegetarian|vegan|healthy"];
              
              // Mediterranean restaurants
              node["amenity"="restaurant"]["cuisine"~"mediterranean"];
            );
            out;
            """
            
        case .highProtein:
            return """
            [out:json][timeout:15][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
            (
              // Steakhouses and grills
              node["amenity"="restaurant"]["cuisine"~"steak|grill|barbecue|american"];
              
              // Chicken restaurants
              node["amenity"="restaurant"]["name"~"chicken|kfc|popeyes|chick",i];
              
              // BBQ places
              node["amenity"="restaurant"]["name"~"bbq|barbecue|grill",i];
              
              // High protein chains
              node["name"~"KFC|Popeyes|Outback|LongHorn|Texas Roadhouse",i]["amenity"="restaurant"];
            );
            out;
            """
            
        case .lowCarb:
            return """
            [out:json][timeout:20][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
            (
              // ALL DIET TYPES FOR LOW CARB
              
              // Vegetarian diet restaurants
              node["amenity"="restaurant"]["diet:vegetarian"~"yes|only"];
              node["amenity"="fast_food"]["diet:vegetarian"~"yes|only"];
              node["amenity"="cafe"]["diet:vegetarian"~"yes|only"];
              
              // Vegan diet restaurants  
              node["amenity"="restaurant"]["diet:vegan"~"yes|only"];
              node["amenity"="fast_food"]["diet:vegan"~"yes|only"];
              node["amenity"="cafe"]["diet:vegan"~"yes|only"];
              
              // Gluten-free diet restaurants
              node["amenity"="restaurant"]["diet:gluten_free"~"yes|only"];
              node["amenity"="fast_food"]["diet:gluten_free"~"yes|only"];
              node["amenity"="cafe"]["diet:gluten_free"~"yes|only"];
              
              // Meat-based diet restaurants
              node["amenity"="restaurant"]["diet:meat"~"yes|only"];
              node["amenity"="fast_food"]["diet:meat"~"yes|only"];
              node["amenity"="cafe"]["diet:meat"~"yes|only"];
              
              // Low carb friendly chains (all diet types)
              node["name"~"Chipotle|Five Guys|In-N-Out|Chick-fil-A|Outback|LongHorn",i]["amenity"~"restaurant|fast_food"];
              
              // Steakhouses and grills (meat-based low carb)
              node["amenity"="restaurant"]["cuisine"~"steak|grill|barbecue|american"];
              
              // Seafood restaurants (all diet types except vegan)
              node["amenity"="restaurant"]["cuisine"~"seafood|fish"];
              
              // Mediterranean restaurants (vegetarian/vegan friendly)
              node["amenity"="restaurant"]["cuisine"~"mediterranean"];
              
              // Vegetarian/Vegan cuisine restaurants
              node["amenity"="restaurant"]["cuisine"~"vegetarian|vegan"];
              
              // Salad-focused restaurants (all diet types)
              node["amenity"="restaurant"]["name"~"salad|fresh|bowl|grill",i];
              
              // Additional low carb keywords
              node["amenity"~"restaurant|fast_food"]["name"~"keto|paleo|atkins|bunless|lettuce.wrap",i];
            );
            out;
            """
        }
    }
    
    /// ENHANCED: Query to get ALL restaurants in the area
    private func createNutritionOptimizedQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        // Get known nutrition chain names for targeted querying
        let knownChains = ["McDonald's", "Subway", "Starbucks", "Burger King", "Taco Bell", 
                          "Chipotle", "Panera", "KFC", "Wendy's", "Domino's", "Pizza Hut",
                          "Dunkin", "Five Guys", "Chick-fil-A", "Popeyes"]
        
        // Create targeted queries for known chains
        let chainQueries = knownChains.map { chain in
            "node[\"name\"~\"\(chain)\",i][\"amenity\"~\"restaurant|fast_food|cafe\"]"
        }.joined(separator: ";\n  ")
        
        return """
        [out:json][timeout:12][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
        (
          // Known nutrition chains (highest priority)
          \(chainQueries);
          
          // All fast food establishments
          node["amenity"="fast_food"];
          
          // All restaurants (including local ones)
          node["amenity"="restaurant"];
          
          // All cafes
          node["amenity"="cafe"];
          
          // Additional food establishments
          node["amenity"="bar"];
          node["amenity"="pub"];
          node["amenity"="food_court"];
          node["amenity"="ice_cream"];
          node["amenity"="bakery"];
        );
        out;
        """
    }
    
    /// EXECUTE QUERY: Enhanced execution to include ALL restaurants
    private func executeQuery(_ query: String) async throws -> [Restaurant] {
        guard let url = URL(string: baseURLs[currentURLIndex]) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        request.timeoutInterval = 15 // Increased timeout for category queries
        
        print("🌐 Querying: \(baseURLs[currentURLIndex])")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("❌ HTTP Error: \(statusCode)")
                
                await MainActor.run {
                    errorMessage = "Server error (\(statusCode)). Please try again."
                }
                
                throw URLError(.badServerResponse)
            }
            
            let restaurants = try parseRestaurantsFromData(data)
            
            // UPDATED: Include ALL restaurants but sort by priority
            let nutritionRestaurants = restaurants.filter { $0.hasNutritionData }
            let otherRestaurants = restaurants.filter { !$0.hasNutritionData }
            
            print("🍽️ Nutrition restaurants: \(nutritionRestaurants.count)")
            print("🍽️ Other restaurants: \(otherRestaurants.count)")
            print("🍽️ Total restaurants: \(restaurants.count)")
            
            // Return ALL restaurants (nutrition ones first, then others up to a reasonable limit)
            let combinedResults = nutritionRestaurants + Array(otherRestaurants.prefix(200))
            
            print("🍽️ Returning \(combinedResults.count) total restaurants")
            return combinedResults
            
        } catch {
            print("❌ Query failed: \(error.localizedDescription)")
            
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            
            // Try next server
            currentURLIndex = (currentURLIndex + 1) % baseURLs.count
            
            // Retry once with next server
            if currentURLIndex != 0 {
                print("🔄 Retrying with: \(baseURLs[currentURLIndex])")
                return try await executeQuery(query)
            } else {
                throw error
            }
        }
    }
    
    /// Enhanced parser with better restaurant detection
    private func parseRestaurantsFromData(_ data: Data) throws -> [Restaurant] {
        let decoder = JSONDecoder()
        let overpass = try decoder.decode(OverpassResponse.self, from: data)
        
        print("📡 Raw response: \(overpass.elements.count) elements")
        
        var restaurants: [Restaurant] = []
        var seenRestaurants: Set<String> = []
        
        for element in overpass.elements {
            // Must have coordinates
            guard let lat = element.lat, let lon = element.lon else { continue }
            
            // Must be food-related
            guard let amenityType = element.tags["amenity"],
                  ["fast_food", "restaurant", "cafe", "bar", "pub", "food_court", "ice_cream", "bakery"].contains(amenityType) else {
                continue
            }
            
            // Get name with fallbacks
            let name = element.tags["name"] ??
                      element.tags["brand"] ??
                      element.tags["operator"] ??
                      "\(amenityType.capitalized) #\(element.id)"
            
            // Skip if name is empty, too long, or already seen
            guard !name.isEmpty && name.count < 100 else { continue }
            
            let locationKey = "\(name)_\(String(format: "%.3f", lat))_\(String(format: "%.3f", lon))"
            guard !seenRestaurants.contains(locationKey) else { continue }
            seenRestaurants.insert(locationKey)
            
            var restaurant = Restaurant(
                id: element.id,
                name: name,
                latitude: lat,
                longitude: lon,
                address: element.tags["addr:street"],
                cuisine: element.tags["cuisine"],
                openingHours: element.tags["opening_hours"],
                phone: element.tags["phone"],
                website: element.tags["website"],
                type: element.type
            )
            
            restaurant.amenityType = amenityType
            restaurants.append(restaurant)
        }
        
        print("✅ Parsed: \(restaurants.count) unique food locations")
        return restaurants
    }
}

// MARK: - Simplified Zoom Level (for backward compatibility)
enum ZoomLevel {
    case veryFar, far, medium, close, veryClose
    
    static func from(latitudeDelta: Double) -> ZoomLevel {
        switch latitudeDelta {
        case 0.2...: return .veryFar
        case 0.05..<0.2: return .far
        case 0.01..<0.05: return .medium
        case 0.002..<0.01: return .close
        default: return .veryClose
        }
    }
    
    var shouldShowPins: Bool {
        return true // Always show pins for simplicity
    }
    
    var maxRestaurants: Int {
        return 200 // Higher limit for better coverage
    }
}

// MARK: - Overpass Response Models
private struct OverpassResponse: Decodable {
    let version: Double
    let generator: String
    let osm3s: OSM3S
    let elements: [Element]
}

private struct OSM3S: Decodable {
    let timestamp_osm_base: String
    let copyright: String
}

private struct Element: Decodable {
    let type: String
    let id: Int
    let lat: Double?
    let lon: Double?
    let tags: [String: String]
}