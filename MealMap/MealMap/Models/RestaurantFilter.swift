import Foundation
import CoreLocation
import SwiftUI

// MARK: - Restaurant Category Enum (updated to remove vegan and lowCarb)
enum RestaurantCategory: String, CaseIterable, Equatable {
    case fastFood = "Fast Food"
    case healthy = "Healthy"
    case highProtein = "High Protein"
    
    var icon: String {
        switch self {
        case .fastFood: return "takeoutbag.and.cup.and.straw"
        case .healthy: return "leaf.fill"
        case .highProtein: return "dumbbell.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .fastFood: return .orange
        case .healthy: return .green
        case .highProtein: return .red
        }
    }
}

// MARK: - Restaurant Filter Models

struct RestaurantFilter: Equatable {
    var category: RestaurantCategory?
    var specificChains: Set<String> = []
    var healthyTypes: Set<HealthyType> = []
    var cuisineTypes: Set<String> = []
    var distanceRange: DistanceRange = .all
    var priceRange: Set<PriceRange> = []
    var amenities: Set<RestaurantAmenity> = []
    var hasNutritionData: Bool? = nil
    
    var isEmpty: Bool {
        return !hasActiveFilters
    }
    
    var hasActiveFilters: Bool {
        return category != nil ||
               !specificChains.isEmpty ||
               !healthyTypes.isEmpty ||
               !cuisineTypes.isEmpty ||
               distanceRange != .all ||
               !priceRange.isEmpty ||
               !amenities.isEmpty ||
               hasNutritionData != nil
    }
    
    var hasActiveNonCategoryFilters: Bool {
        return !specificChains.isEmpty ||
               !healthyTypes.isEmpty ||
               !cuisineTypes.isEmpty ||
               distanceRange != .all ||
               !priceRange.isEmpty ||
               !amenities.isEmpty ||
               hasNutritionData != nil
    }
    
    var hasActiveNonNutritionFilters: Bool {
        return category != nil ||
               !specificChains.isEmpty ||
               !healthyTypes.isEmpty ||
               !cuisineTypes.isEmpty ||
               distanceRange != .all ||
               !priceRange.isEmpty ||
               !amenities.isEmpty
    }
    
    func matchesRestaurant(_ restaurant: Restaurant, userLocation: CLLocationCoordinate2D?) -> Bool {
        // Category filter
        if let category = category {
            if !restaurant.matchesCategory(category) {
                return false
            }
        }
        
        // Specific chain filter
        if !specificChains.isEmpty {
            let restaurantName = restaurant.name.lowercased()
            let matches = specificChains.contains { chain in
                restaurantName.contains(chain.lowercased())
            }
            if !matches { return false }
        }
        
        // Healthy type filter
        if !healthyTypes.isEmpty {
            let matches = healthyTypes.contains { type in
                restaurant.matchesHealthyType(type)
            }
            if !matches { return false }
        }
        
        // Cuisine type filter
        if !cuisineTypes.isEmpty {
            guard let restaurantCuisine = restaurant.cuisine?.lowercased() else { return false }
            let matches = cuisineTypes.contains { cuisine in
                restaurantCuisine.contains(cuisine.lowercased()) ||
                restaurant.name.lowercased().contains(cuisine.lowercased())
            }
            if !matches { return false }
        }
        
        // Distance filter
        if distanceRange != .all, let userLocation = userLocation {
            let distance = restaurant.distanceFrom(userLocation)
            if !distanceRange.contains(distance) {
                return false
            }
        }
        
        // Nutrition data filter
        if let needsNutrition = hasNutritionData {
            let hasData = RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
            if needsNutrition != hasData {
                return false
            }
        }
        
        // Price range filter (simplified - would need real data)
        // For now, just pass through
        
        // Amenities filter (simplified - would need real data)
        // For now, just pass through
        
        return true
    }
    
    static func empty() -> RestaurantFilter {
        return RestaurantFilter()
    }
}

// MARK: - Filter Options

enum HealthyType: String, CaseIterable, Equatable {
    case salad = "Salad"
    case smoothie = "Smoothie"
    case bowl = "Bowl"
    case fresh = "Fresh"
    case juice = "Juice"
    case organic = "Organic"
    
    var searchTerms: [String] {
        switch self {
        case .salad: return ["salad", "greens"]
        case .smoothie: return ["smoothie", "blend"]
        case .bowl: return ["bowl", "poke"]
        case .fresh: return ["fresh", "farm"]
        case .juice: return ["juice", "pressed"]
        case .organic: return ["organic", "natural"]
        }
    }
}

enum DistanceRange: String, CaseIterable, Equatable {
    case all = "All Distances"
    case nearby = "< 1 mile"
    case close = "< 2 miles"
    case moderate = "< 5 miles"
    case far = "< 10 miles"
    
    var maxDistance: Double? {
        switch self {
        case .all: return nil
        case .nearby: return 1.0
        case .close: return 2.0
        case .moderate: return 5.0
        case .far: return 10.0
        }
    }
    
    func contains(_ distanceInMiles: Double) -> Bool {
        guard let maxDistance = maxDistance else { return true }
        return distanceInMiles <= maxDistance
    }
}

enum PriceRange: String, CaseIterable, Equatable {
    case budget = "$"
    case moderate = "$$"
    case expensive = "$$$"
    case luxury = "$$$$"
    
    var description: String {
        switch self {
        case .budget: return "Under $10"
        case .moderate: return "$10-20"
        case .expensive: return "$20-35"
        case .luxury: return "$35+"
        }
    }
}

enum RestaurantAmenity: String, CaseIterable, Equatable {
    case driveThru = "Drive-thru"
    case delivery = "Delivery"
    case takeout = "Takeout"
    case dineIn = "Dine-in"
    case wifi = "WiFi"
    case parking = "Parking"
    
    var icon: String {
        switch self {
        case .driveThru: return "car.fill"
        case .delivery: return "bicycle"
        case .takeout: return "takeoutbag.and.cup.and.straw.fill"
        case .dineIn: return "fork.knife"
        case .wifi: return "wifi"
        case .parking: return "parkingsign"
        }
    }
}

// MARK: - Popular Fast Food Chains

struct PopularChains {
    static let fastFoodChains = [
        "McDonald's", "Subway", "Starbucks", "Burger King", "KFC",
        "Taco Bell", "Pizza Hut", "Domino's", "Wendy's", "Chick-fil-A",
        "Chipotle", "Five Guys", "In-N-Out", "Sonic", "Dairy Queen",
        "Arby's", "Jack in the Box", "Carl's Jr.", "Hardee's", "Popeyes"
    ]
    
    static let healthyChains = [
        "Panera Bread", "Chipotle", "Sweetgreen", "Chopt", "Freshii",
        "Just Salad", "Tender Greens", "Dig", "Honeygrow", "Saladworks"
    ]
    
    static let coffeChains = [
        "Starbucks", "Dunkin'", "Tim Hortons", "Peet's Coffee",
        "The Coffee Bean", "Caribou Coffee"
    ]
}

// MARK: - Common Cuisine Types

struct CuisineTypes {
    static let popular = [
        "American", "Italian", "Mexican", "Chinese", "Japanese",
        "Indian", "Thai", "Mediterranean", "Greek", "French",
        "Korean", "Vietnamese", "BBQ", "Seafood", "Pizza",
        "Burger", "Sandwich", "Coffee", "Bakery", "Dessert"
    ]
}
