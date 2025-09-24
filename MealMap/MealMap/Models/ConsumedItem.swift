import Foundation
import Foundation
import SwiftUI
import SwiftUI

// MARK: - Consumed Item Models
struct ConsumedItem: Identifiable, Codable {
    let id: String
    let userId: String
    let restaurantName: String
    let menuItem: NutritionData
    let consumedAt: Date
    let quantity: Double // Multiplier for portions (1.0 = standard portion)
    
    init(userId: String, restaurantName: String, menuItem: NutritionData, consumedAt: Date = Date(), quantity: Double = 1.0) {
        self.id = UUID().uuidString
        self.userId = userId
        self.restaurantName = restaurantName
        self.menuItem = menuItem
        self.consumedAt = consumedAt
        self.quantity = quantity
    }
    
    // Calculate adjusted nutrition values based on quantity
    var adjustedCalories: Double { menuItem.calories * quantity }
    var adjustedProtein: Double { menuItem.protein * quantity }
    var adjustedCarbs: Double { menuItem.carbs * quantity }
    var adjustedFat: Double { menuItem.fat * quantity }
    var adjustedFiber: Double { menuItem.fiber * quantity }
    var adjustedSodium: Double { menuItem.sodium * quantity }
    var adjustedSugar: Double { menuItem.sugar * quantity }
}

// MARK: - Daily Nutrition Summary
struct DailyNutritionSummary: Codable {
    let date: Date
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let totalFiber: Double
    let totalSodium: Double
    let totalSugar: Double
    let consumedItems: [ConsumedItem]
    
    init(date: Date, consumedItems: [ConsumedItem]) {
        self.date = date
        self.consumedItems = consumedItems
        
        // Calculate totals
        self.totalCalories = consumedItems.reduce(0) { $0 + $1.adjustedCalories }
        self.totalProtein = consumedItems.reduce(0) { $0 + $1.adjustedProtein }
        self.totalCarbs = consumedItems.reduce(0) { $0 + $1.adjustedCarbs }
        self.totalFat = consumedItems.reduce(0) { $0 + $1.adjustedFat }
        self.totalFiber = consumedItems.reduce(0) { $0 + $1.adjustedFiber }
        self.totalSodium = consumedItems.reduce(0) { $0 + $1.adjustedSodium }
        self.totalSugar = consumedItems.reduce(0) { $0 + $1.adjustedSugar }
    }
    
    // Calculate percentage of daily goals achieved
    func percentageOfGoal(for nutrient: NutrientType, userPreferences: UserPreferences) -> Double {
        let goal: Double
        let consumed: Double
        
        switch nutrient {
        case .calories:
            goal = Double(userPreferences.dailyCalorieGoal)
            consumed = totalCalories
        case .protein:
            goal = Double(userPreferences.dailyProteinGoal)
            consumed = totalProtein
        case .carbs:
            goal = Double(userPreferences.dailyCarbGoal)
            consumed = totalCarbs
        case .fat:
            goal = Double(userPreferences.dailyFatGoal)
            consumed = totalFat
        case .fiber:
            goal = Double(userPreferences.dailyFiberGoal)
            consumed = totalFiber
        case .sodium:
            goal = Double(userPreferences.dailySodiumLimit)
            consumed = totalSodium
        case .sugar:
            // For sugar, we want to show how much of the limit is used (assuming 50g as limit)
            goal = 50.0
            consumed = totalSugar
        }
        
        return goal > 0 ? (consumed / goal) * 100 : 0
    }
}

// MARK: - Nutrient Type Enum
enum NutrientType: String, CaseIterable {
    case calories = "Calories"
    case protein = "Protein"
    case carbs = "Carbs"
    case fat = "Fat"
    case fiber = "Fiber"
    case sodium = "Sodium"
    case sugar = "Sugar"
    
    var unit: String {
        switch self {
        case .calories: return "kcal"
        case .protein: return "g"
        case .carbs: return "g"
        case .fat: return "g"
        case .fiber: return "g"
        case .sodium: return "mg"
        case .sugar: return "g"
        }
    }
    
    var color: Color {
        switch self {
        case .calories: return .orange
        case .protein: return .red
        case .carbs: return .green
        case .fat: return .yellow
        case .fiber: return .brown
        case .sodium: return .gray
        case .sugar: return .pink
        }
    }
}
