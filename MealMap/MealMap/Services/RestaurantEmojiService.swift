import Foundation

// MARK: - Restaurant Emoji Service
final class RestaurantEmojiService {
    static let shared = RestaurantEmojiService()
    
    private init() {}
    
    /// Returns the most appropriate emoji for a restaurant based on name and cuisine
    func getEmojiForRestaurant(_ restaurant: Restaurant) -> String {
        let name = restaurant.name.lowercased()
        let cuisine = restaurant.cuisine?.lowercased() ?? ""
        
        // MARK: - Brand-Specific Emojis
        
        // Pizza Places
        if name.contains("pizza") || name.contains("pizzeria") ||
           ["pizza hut", "domino's", "papa john's", "little caesars", "papa murphy's", 
            "blaze pizza", "california pizza kitchen", "sbarro", "jet's pizza"].contains(where: { name.contains($0) }) {
            return "🍕"
        }
        
        // Burger Places
        if ["mcdonald's", "burger king", "wendy's", "five guys", "in-n-out", "whataburger", 
            "shake shack", "white castle", "carl's jr", "hardee's", "jack in the box",
            "sonic", "culver's", "a&w", "fatburger"].contains(where: { name.contains($0) }) ||
           name.contains("burger") {
            return "🍔"
        }
        
        // Chicken Places
        if ["kfc", "chick-fil-a", "popeyes", "church's chicken", "raising cane's", 
            "bojangles", "el pollo loco", "zaxby's", "dave's hot chicken"].contains(where: { name.contains($0) }) ||
           name.contains("chicken") && !name.contains("sandwich") {
            return "🍗"
        }
        
        // Tacos & Mexican
        if ["taco bell", "chipotle", "qdoba", "del taco", "taco cabana", "el pollo loco",
            "moe's", "fuzzy's", "torchy's"].contains(where: { name.contains($0) }) ||
           name.contains("taco") || name.contains("mexican") || cuisine.contains("mexican") {
            return "🌮"
        }
        
        // Coffee & Cafes
        if ["starbucks", "dunkin'", "dunkin", "coffee bean", "peet's", "caribou coffee",
            "tim hortons", "costa coffee", "blue bottle", "intelligentsia"].contains(where: { name.contains($0) }) ||
           name.contains("coffee") || name.contains("cafe") || name.contains("espresso") ||
           cuisine.contains("coffee") || restaurant.amenityType == "cafe" {
            return "☕"
        }
        
        // Donuts & Bakery
        if ["krispy kreme", "dunkin'", "donut", "bakery"].contains(where: { name.contains($0) }) ||
           name.contains("donut") || name.contains("doughnut") || cuisine.contains("bakery") {
            return "🍩"
        }
        
        // Ice Cream
        if ["dairy queen", "baskin-robbins", "cold stone", "ben & jerry's", "häagen-dazs",
            "friendly's", "carvel", "tcby"].contains(where: { name.contains($0) }) ||
           name.contains("ice cream") || name.contains("frozen yogurt") || cuisine.contains("ice cream") {
            return "🍦"
        }
        
        // Sandwiches & Subs
        if ["subway", "jimmy john's", "quiznos", "jersey mike's", "firehouse subs",
            "which wich", "potbelly", "penn station"].contains(where: { name.contains($0) }) ||
           name.contains("sub") || name.contains("sandwich") || cuisine.contains("sandwich") {
            return "🥪"
        }
        
        // Asian Cuisine
        if ["panda express", "pick up stix", "pei wei", "pf chang's", "benihana"].contains(where: { name.contains($0) }) ||
           name.contains("chinese") || name.contains("asian") || name.contains("sushi") ||
           cuisine.contains("chinese") || cuisine.contains("japanese") || cuisine.contains("asian") ||
           cuisine.contains("sushi") || cuisine.contains("thai") || cuisine.contains("vietnamese") {
            return "🥢"
        }
        
        // Sushi Specific
        if name.contains("sushi") || cuisine.contains("sushi") {
            return "🍣"
        }
        
        // Noodles & Pasta
        if ["olive garden", "noodles & company", "fazoli's"].contains(where: { name.contains($0) }) ||
           name.contains("noodle") || name.contains("pasta") || cuisine.contains("pasta") ||
           cuisine.contains("italian") {
            return "🍝"
        }
        
        // BBQ & Grill
        if name.contains("bbq") || name.contains("grill") || name.contains("smokehouse") ||
           name.contains("barbecue") || cuisine.contains("barbecue") || cuisine.contains("grill") {
            return "🍖"
        }
        
        // Steakhouse
        if name.contains("steakhouse") || name.contains("steak") || cuisine.contains("steakhouse") {
            return "🥩"
        }
        
        // Seafood
        if ["long john silver's", "red lobster", "captain d's"].contains(where: { name.contains($0) }) ||
           name.contains("seafood") || name.contains("fish") || cuisine.contains("seafood") {
            return "🐟"
        }
        
        // Salads & Healthy
        if ["sweetgreen", "chopt", "freshii", "salata", "crisp & green"].contains(where: { name.contains($0) }) ||
           name.contains("salad") || name.contains("fresh") || name.contains("healthy") ||
           cuisine.contains("salad") || name.contains("juice") || name.contains("smoothie") {
            return "🥗"
        }
        
        // Deli
        if name.contains("deli") || cuisine.contains("deli") {
            return "🥖"
        }
        
        // Breakfast
        if ["ihop", "denny's", "waffle house", "cracker barrel", "bob evans",
            "perkins", "first watch"].contains(where: { name.contains($0) }) ||
           name.contains("pancake") || name.contains("waffle") || name.contains("breakfast") ||
           cuisine.contains("breakfast") {
            return "🥞"
        }
        
        // MARK: - Cuisine-Based Fallbacks
        
        switch cuisine {
        case let c where c.contains("indian"):
            return "🍛"
        case let c where c.contains("mediterranean"):
            return "🫒"
        case let c where c.contains("greek"):
            return "🫒"
        case let c where c.contains("korean"):
            return "🍜"
        case let c where c.contains("middle eastern"):
            return "🥙"
        case let c where c.contains("vegetarian") || c.contains("vegan"):
            return "🌱"
        case let c where c.contains("dessert"):
            return "🧁"
        default:
            break
        }
        
        // MARK: - Amenity Type Fallbacks
        
        if restaurant.amenityType == "fast_food" {
            return "🍔" // Default fast food emoji
        } else if restaurant.amenityType == "restaurant" {
            return "🍽️" // Default restaurant emoji
        } else if restaurant.amenityType == "cafe" {
            return "☕" // Default cafe emoji
        }
        
        // Ultimate fallback
        return "🍽️"
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
}