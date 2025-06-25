import Foundation

// MARK: - Core Nutrition Data Models
struct NutritionData: Identifiable, Codable, Equatable {
    let id = UUID()
    let item: String
    let calories: Double
    let fat: Double
    let saturatedFat: Double
    let cholesterol: Double
    let sodium: Double
    let carbs: Double
    let fiber: Double
    let sugar: Double
    let protein: Double
    
    // JSON-optimized coding keys
    enum CodingKeys: String, CodingKey {
        case item
        case calories
        case fat
        case saturatedFat
        case cholesterol
        case sodium
        case carbs
        case fiber
        case sugar
        case protein
    }
    
    // Custom decoder to handle UUID
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        item = try container.decode(String.self, forKey: .item)
        calories = try container.decode(Double.self, forKey: .calories)
        fat = try container.decode(Double.self, forKey: .fat)
        saturatedFat = try container.decode(Double.self, forKey: .saturatedFat)
        cholesterol = try container.decode(Double.self, forKey: .cholesterol)
        sodium = try container.decode(Double.self, forKey: .sodium)
        carbs = try container.decode(Double.self, forKey: .carbs)
        fiber = try container.decode(Double.self, forKey: .fiber)
        sugar = try container.decode(Double.self, forKey: .sugar)
        protein = try container.decode(Double.self, forKey: .protein)
    }
    
    // Manual initializer for backward compatibility
    init(item: String, calories: Double, fat: Double, saturatedFat: Double, 
         cholesterol: Double, sodium: Double, carbs: Double, fiber: Double, 
         sugar: Double, protein: Double) {
        self.item = item
        self.calories = calories
        self.fat = fat
        self.saturatedFat = saturatedFat
        self.cholesterol = cholesterol
        self.sodium = sodium
        self.carbs = carbs
        self.fiber = fiber
        self.sugar = sugar
        self.protein = protein
    }
    
    static func == (lhs: NutritionData, rhs: NutritionData) -> Bool {
        return lhs.item == rhs.item &&
               lhs.calories == rhs.calories &&
               lhs.fat == rhs.fat &&
               lhs.saturatedFat == rhs.saturatedFat &&
               lhs.cholesterol == rhs.cholesterol &&
               lhs.sodium == rhs.sodium &&
               lhs.carbs == rhs.carbs &&
               lhs.fiber == rhs.fiber &&
               lhs.sugar == rhs.sugar &&
               lhs.protein == rhs.protein
    }
}

// MARK: - Restaurant Nutrition Bundle Models
struct NutritionBundle: Codable {
    let version: String
    let lastUpdated: String
    let restaurants: [String: RestaurantNutritionBundle]
    let restaurantMapping: [String: String]
}

struct RestaurantNutritionBundle: Codable {
    let id: String
    let name: String
    let items: [NutritionData]
}

// MARK: - Legacy Model for Compatibility
struct RestaurantNutritionData: Equatable {
    let restaurantName: String
    let items: [NutritionData]
    
    static func == (lhs: RestaurantNutritionData, rhs: RestaurantNutritionData) -> Bool {
        return lhs.restaurantName == rhs.restaurantName && lhs.items == rhs.items
    }
}

// MARK: - Fast Lookup Cache Models
struct NutritionCache: Codable {
    private var restaurantCache: [String: RestaurantNutritionData] = [:]
    private var itemCache: [String: [NutritionData]] = [:]

    enum CodingKeys: String, CodingKey {
        case restaurantCache
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        restaurantCache = try container.decode([String: RestaurantNutritionData].self, forKey: .restaurantCache)
        itemCache = restaurantCache.reduce(into: [:]) { $0[$1.key] = $1.value.items }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(restaurantCache, forKey: .restaurantCache)
    }
    
    mutating func store(restaurant: RestaurantNutritionData) {
        let key = restaurant.restaurantName.lowercased()
        restaurantCache[key] = restaurant
        itemCache[key] = restaurant.items
    }
    
    func getRestaurant(named name: String) -> RestaurantNutritionData? {
        return restaurantCache[name.lowercased()]
    }
    
    func getItems(for restaurantName: String) -> [NutritionData]? {
        return itemCache[restaurantName.lowercased()]
    }
    
    func contains(restaurantName: String) -> Bool {
        return restaurantCache.keys.contains(restaurantName.lowercased())
    }
    
    var restaurantNames: [String] {
        return Array(restaurantCache.keys)
    }
}
