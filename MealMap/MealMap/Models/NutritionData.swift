import Foundation

struct NutritionData: Identifiable, Codable {
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
}

struct RestaurantNutritionData {
    let restaurantName: String
    let items: [NutritionData]
}