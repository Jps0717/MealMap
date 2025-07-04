import Foundation

// MARK: - Restaurant Emoji Service
final class RestaurantEmojiService {
    static let shared = RestaurantEmojiService()
    
    private init() {}
    
    /// Returns the most appropriate emoji for a restaurant based on name and cuisine
    func getEmojiForRestaurant(_ restaurant: Restaurant) -> String {
        let emoji = RestaurantEmojiService.emoji(for: restaurant.amenityType, cuisine: restaurant.cuisine?.lowercased())
        return emoji
    }
    
    /// Gets a color that matches the emoji for better visual consistency
    func getColorForEmoji(_ emoji: String) -> (background: String, foreground: String) {
        switch emoji {
        case "🍕": return ("#FF6B35", "#FFFFFF") // Pizza orange
        case "🍔": return ("#D4AF37", "#FFFFFF") // Burger gold
        case "🍗": return ("#CD853F", "#FFFFFF") // Chicken brown
        case "🌮": return ("#FF4500", "#FFFFFF") // Taco red-orange
        case "☕": return ("#6F4E37", "#FFFFFF") // Coffee brown
        case "🍩": return ("#FF69B4", "#FFFFFF") // Donut pink
        case "🍦": return ("#87CEEB", "#000000") // Ice cream blue
        case "🥪": return ("#DAA520", "#FFFFFF") // Sandwich gold
        case "🥢": return ("#DC143C", "#FFFFFF") // Asian red
        case "🍣": return ("#FF6347", "#FFFFFF") // Sushi tomato
        case "🍝": return ("#32CD32", "#FFFFFF") // Pasta green
        case "🍖": return ("#8B4513", "#FFFFFF") // BBQ brown
        case "🥩": return ("#A0522D", "#FFFFFF") // Steak brown
        case "🐟": return ("#4682B4", "#FFFFFF") // Seafood blue
        case "🥗": return ("#32CD32", "#FFFFFF") // Salad green
        case "🥖": return ("#DEB887", "#000000") // Deli beige
        case "🥞": return ("#FFD700", "#000000") // Breakfast gold
        case "🍛": return ("#FF8C00", "#FFFFFF") // Indian orange
        case "🫒": return ("#808000", "#FFFFFF") // Mediterranean olive
        case "🍜": return ("#FF0000", "#FFFFFF") // Korean red
        case "🥙": return ("#DAA520", "#FFFFFF") // Middle Eastern gold
        case "🌱": return ("#228B22", "#FFFFFF") // Vegan green
        case "🧁": return ("#FF1493", "#FFFFFF") // Dessert pink
        default: return ("#007AFF", "#FFFFFF") // Default blue
        }
    }
    
    // MARK: - Enhanced Emoji Mapping
    static func emoji(for amenity: String?, cuisine: String?) -> String {
        // First check cuisine-specific emojis
        if let cuisine = cuisine?.lowercased() {
            if let cuisineEmoji = cuisineEmojis[cuisine] {
                return cuisineEmoji
            }
            
            // Partial matches for cuisine
            for (key, emoji) in cuisineEmojis {
                if cuisine.contains(key) {
                    return emoji
                }
            }
        }
        
        // Fallback to amenity-based emojis
        let amenityKey = amenity?.lowercased() ?? "restaurant"
        return amenityEmojis[amenityKey] ?? defaultEmoji(for: amenityKey)
    }
    
    // MARK: - Cuisine-Specific Emojis
    private static let cuisineEmojis: [String: String] = [
        // Asian
        "sushi": "🍣",
        "japanese": "🍱",
        "chinese": "🥡",
        "thai": "🍜",
        "korean": "🍲",
        "vietnamese": "🍜",
        "asian": "🥢",
        "ramen": "🍜",
        "noodles": "🍜",
        
        // European
        "pizza": "🍕",
        "italian": "🍝",
        "french": "🥖",
        "german": "🥨",
        "greek": "🫒",
        "spanish": "🥘",
        "mediterranean": "🫒",
        
        // American
        "burger": "🍔",
        "american": "🍔",
        "bbq": "🍖",
        "barbecue": "🍖",
        "steak": "🥩",
        "sandwich": "🥪",
        "deli": "🥪",
        
        // Mexican/Latin
        "mexican": "🌮",
        "taco": "🌮",
        "burrito": "🌯",
        "tex-mex": "🌮",
        "latin": "🌮",
        
        // Indian/Middle Eastern
        "indian": "🍛",
        "curry": "🍛",
        "middle_eastern": "🧆",
        "lebanese": "🧆",
        "persian": "🍛",
        "turkish": "🧆",
        
        // Vegetarian/Vegan
        "vegetarian": "🥗",
        "vegan": "🌱",
        "salad": "🥗",
        "healthy": "🥗",
        
        // Dessert/Sweets
        "ice_cream": "🍦",
        "dessert": "🍰",
        "bakery": "🥐",
        "donut": "🍩",
        "cake": "🧁",
        
        // Beverages
        "coffee": "☕",
        "tea": "🍵",
        "juice": "🧃",
        "smoothie": "🥤",
        
        // Seafood
        "seafood": "🦞",
        "fish": "🐟",
        "oyster": "🦪",
        
        // Breakfast
        "breakfast": "🥞",
        "brunch": "🥞",
        "pancake": "🥞",
        
        // Fast Food Chains
        "mcdonald": "🍔",
        "burger_king": "🍔",
        "subway": "🥪",
        "kfc": "🍗",
        "taco_bell": "🌮",
        "pizza_hut": "🍕",
        "domino": "🍕",
        "starbucks": "☕",
        "dunkin": "🍩"
    ]
    
    // MARK: - Amenity-Based Emojis
    private static let amenityEmojis: [String: String] = [
        "restaurant": "🍽️",
        "fast_food": "🍔",
        "cafe": "☕",
        "bar": "🍺",
        "pub": "🍺",
        "food_court": "🍽️",
        "biergarten": "🍺"
    ]
    
    // MARK: - Default Emoji Logic
    private static func defaultEmoji(for amenity: String) -> String {
        switch amenity.lowercased() {
        case "fast_food":
            return "🍔"
        case "cafe":
            return "☕"
        case "bar", "pub":
            return "🍺"
        default:
            return "🍽️"
        }
    }
    
    // MARK: - Color Coding Logic
    static func pinColor(hasNutritionData: Bool, isVegan: Bool = false) -> String {
        if hasNutritionData {
            return isVegan ? "#4CAF50" : "#2196F3" // Green for vegan, blue for nutrition
        } else {
            return "#9E9E9E" // Gray for no nutrition data
        }
    }
    
    // MARK: - Enhanced Restaurant Analysis
    static func analyzeRestaurant(name: String, amenity: String?, cuisine: String?) -> RestaurantAnalysis {
        let emoji = emoji(for: amenity, cuisine: cuisine)
        let hasNutritionData = RestaurantData.hasNutritionData(for: name)
        let isVegan = cuisine?.lowercased().contains("vegan") == true
        let pinColor = pinColor(hasNutritionData: hasNutritionData, isVegan: isVegan)
        
        return RestaurantAnalysis(
            emoji: emoji,
            pinColor: pinColor,
            hasNutritionData: hasNutritionData,
            isVegan: isVegan,
            cuisineCategory: categorizeCuisine(cuisine)
        )
    }
    
    private static func categorizeCuisine(_ cuisine: String?) -> String {
        guard let cuisine = cuisine?.lowercased() else { return "general" }
        
        if ["chinese", "japanese", "korean", "thai", "vietnamese", "asian"].contains(where: cuisine.contains) {
            return "asian"
        } else if ["italian", "french", "german", "greek", "spanish", "mediterranean"].contains(where: cuisine.contains) {
            return "european"
        } else if ["mexican", "taco", "burrito", "tex-mex", "latin"].contains(where: cuisine.contains) {
            return "mexican"
        } else if ["indian", "curry", "middle_eastern", "lebanese", "persian", "turkish"].contains(where: cuisine.contains) {
            return "middle_eastern"
        } else if ["vegetarian", "vegan", "salad", "healthy"].contains(where: cuisine.contains) {
            return "healthy"
        } else if ["american", "burger", "bbq", "steak"].contains(where: cuisine.contains) {
            return "american"
        } else {
            return "general"
        }
    }
}

// MARK: - Analysis Result
struct RestaurantAnalysis {
    let emoji: String
    let pinColor: String
    let hasNutritionData: Bool
    let isVegan: Bool
    let cuisineCategory: String
}
