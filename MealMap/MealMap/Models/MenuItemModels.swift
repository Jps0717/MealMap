import Foundation
import CoreLocation
import UIKit
import SwiftUI

// MARK: - Essential models for menu item scoring

struct AnalyzedMenuItem: Identifiable, Codable {
    var id = UUID()
    let name: String
    let description: String?
    let price: String?
    let ingredients: [IdentifiedIngredient]
    let nutritionEstimate: NutritionEstimate
    let dietaryTags: [DietaryTag]
    let confidence: Double
    let textBounds: CGRect?
    
    let estimationTier: EstimationTier
    let isGeneralizedEstimate: Bool
    
    // User corrections
    var userCorrectedName: String?
    var userCorrectedIngredients: [String]?
    var userDietaryFlags: [DietaryTag]?
    var userMarkedIncorrect = false
    
    // MARK: - Scoring Data
    var menuItemScore: MenuItemScore?
    var lastScoredFor: String? // User ID
    var scoringEnabled = true
    
    // Default initializer
    init(
        name: String,
        description: String?,
        price: String?,
        ingredients: [IdentifiedIngredient],
        nutritionEstimate: NutritionEstimate,
        dietaryTags: [DietaryTag],
        confidence: Double,
        textBounds: CGRect?,
        estimationTier: EstimationTier = .database,
        isGeneralizedEstimate: Bool = false
    ) {
        self.name = name
        self.description = description
        self.price = price
        self.ingredients = ingredients
        self.nutritionEstimate = nutritionEstimate
        self.dietaryTags = dietaryTags
        self.confidence = confidence
        self.textBounds = textBounds
        self.estimationTier = estimationTier
        self.isGeneralizedEstimate = isGeneralizedEstimate
    }
}

struct IdentifiedIngredient: Identifiable, Codable {
    var id = UUID()
    let name: String
    let category: IngredientCategory
    let confidence: Double
    let nutritionContribution: NutritionContribution?
}

struct NutritionEstimate: Codable {
    let calories: NutritionRange
    let carbs: NutritionRange
    let protein: NutritionRange
    let fat: NutritionRange
    let fiber: NutritionRange?
    let sodium: NutritionRange?
    let sugar: NutritionRange?
    let confidence: Double
    
    // Estimation source tracking
    let estimationSource: EstimationSource
    let sourceDetails: String?
    
    // Portion size estimation
    let estimatedPortionSize: String?
    let portionConfidence: Double
}

struct NutritionRange: Codable {
    let min: Double
    let max: Double
    let unit: String // "g", "mg", "kcal"
    
    // Safe initializer that ensures min <= max
    init(min: Double, max: Double, unit: String) {
        let safeMin = Swift.max(0, min) // Ensure non-negative
        let safeMax = Swift.max(safeMin, max) // Ensure max >= min
        
        self.min = safeMin
        self.max = safeMax
        self.unit = unit
    }
    
    var average: Double { (min + max) / 2 }
    var displayString: String {
        if min == max {
            return "\(Int(min))\(unit)"
        } else {
            return "\(Int(min))-\(Int(max))\(unit)"
        }
    }
}

enum IngredientCategory: String, CaseIterable, Codable {
    case protein = "protein"
    case carbohydrate = "carbohydrate"
    case vegetable = "vegetable"
    case fruit = "fruit"
    case dairy = "dairy"
    case grain = "grain"
    case fat = "fat"
    case spice = "spice"
    case sauce = "sauce"
    case unknown = "unknown"
    
    var emoji: String {
        switch self {
        case .protein: return "🥩"
        case .carbohydrate: return "🍞"
        case .vegetable: return "🥬"
        case .fruit: return "🍎"
        case .dairy: return "🥛"
        case .grain: return "🌾"
        case .fat: return "🥑"
        case .spice: return "🧂"
        case .sauce: return "🫗"
        case .unknown: return "❓"
        }
    }
}

enum DietaryTag: String, CaseIterable, Codable {
    case highProtein = "high_protein"
    case lowCarb = "low_carb"
    case highCarb = "high_carb"
    case keto = "keto"
    case vegan = "vegan"
    case vegetarian = "vegetarian"
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"
    case lowSodium = "low_sodium"
    case highFiber = "high_fiber"
    case lowSugar = "low_sugar"
    case healthy = "healthy"
    case indulgent = "indulgent"
    
    var displayName: String {
        switch self {
        case .highProtein: return "High Protein"
        case .lowCarb: return "Low Carb"
        case .highCarb: return "High Carb"
        case .keto: return "Keto-Friendly"
        case .vegan: return "Vegan"
        case .vegetarian: return "Vegetarian"
        case .glutenFree: return "Gluten-Free"
        case .dairyFree: return "Dairy-Free"
        case .lowSodium: return "Low Sodium"
        case .highFiber: return "High Fiber"
        case .lowSugar: return "Low Sugar"
        case .healthy: return "Healthy"
        case .indulgent: return "Indulgent"
        }
    }
    
    var emoji: String {
        switch self {
        case .highProtein: return "💪"
        case .lowCarb: return "🥗"
        case .highCarb: return "🍞"
        case .keto: return "🥑"
        case .vegan: return "🌱"
        case .vegetarian: return "🥬"
        case .glutenFree: return "🌾"
        case .dairyFree: return "🚫🥛"
        case .lowSodium: return "🧂"
        case .highFiber: return "🌾"
        case .lowSugar: return "🍯"
        case .healthy: return "💚"
        case .indulgent: return "😋"
        }
    }
    
    var color: Color {
        switch self {
        case .highProtein: return .red
        case .lowCarb: return .teal
        case .highCarb: return .yellow
        case .keto: return .green
        case .vegan: return .green
        case .vegetarian: return .blue
        case .glutenFree: return .orange
        case .dairyFree: return .mint
        case .lowSodium: return .cyan
        case .highFiber: return .purple
        case .lowSugar: return .yellow
        case .healthy: return .green
        case .indulgent: return .pink
        }
    }
}

struct NutritionContribution: Codable {
    let calories: Double
    let carbs: Double
    let protein: Double
    let fat: Double
    let confidence: Double
}