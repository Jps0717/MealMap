import Foundation

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
    
    enum CodingKeys: String, CodingKey {
        case item = "Item"
        case calories = "Calories"
        case fat = "Fat (g)"
        case saturatedFat = "Saturated Fat (g)"
        case cholesterol = "Cholesterol (mg)"
        case sodium = "Sodium (mg)"
        case carbs = "Carbs (g)"
        case fiber = "Fiber (g)"
        case sugar = "Sugar (g)"
        case protein = "Protein (g)"
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

struct RestaurantNutritionData: Equatable {
    let restaurantName: String
    let items: [NutritionData]
    
    static func == (lhs: RestaurantNutritionData, rhs: RestaurantNutritionData) -> Bool {
        return lhs.restaurantName == rhs.restaurantName && lhs.items == rhs.items
    }
}
