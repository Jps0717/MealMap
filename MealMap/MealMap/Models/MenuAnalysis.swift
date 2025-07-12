import Foundation
import CoreLocation
import UIKit
import SwiftUI

// MARK: - Codable Support for CoreGraphics Types
extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}

extension CGRect: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin.x, forKey: .x)
        try container.encode(origin.y, forKey: .y)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(x: x, y: y, width: width, height: height)
    }
    
    private enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }
}

// MARK: - Core Pipeline Data Models

struct ValidatedMenuItem: Identifiable, Codable {
    let id = UUID()
    let originalLine: String
    let validatedName: String
    let spoonacularId: Int // Kept for compatibility but not used
    let imageUrl: String?
    let nutritionInfo: NutritionInfo? // Simplified nutrition info
    let isValid: Bool
    let timestamp: Date = Date()
}

struct NutritionInfo: Codable {
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let sodium: Double?
    let sugar: Double?
}

// MARK: - Menu Analysis Models

struct MenuAnalysisResult: Identifiable, Codable {
    let id = UUID()
    let restaurantName: String?
    let location: CLLocationCoordinate2D?
    let menuItems: [AnalyzedMenuItem]
    let analysisDate: Date
    let imageData: Data?
    let confidence: Double
    
    var totalItems: Int { menuItems.count }
    var highConfidenceItems: Int { 
        menuItems.filter { $0.confidence > 0.7 }.count 
    }
    
    // MARK: - Scoring Data
    var menuItemScores: [String: MenuItemScore] = [:]
    var lastScoredFor: String? // User ID
    var scoringEnabled: Bool = true
    
    // MARK: - Scoring Helpers
    var scoredItems: [AnalyzedMenuItem] {
        menuItems.filter { $0.hasValidScore }
    }
    
    var highlyRatedItems: [AnalyzedMenuItem] {
        menuItems.filter { $0.isHighlyRated }
    }
    
    var averageScore: Double {
        let validScores = menuItems.compactMap { $0.menuItemScore?.overallScore }
        return validScores.isEmpty ? 0 : validScores.reduce(0, +) / Double(validScores.count)
    }
    
    var topRatedItems: [AnalyzedMenuItem] {
        menuItems
            .filter { $0.hasValidScore }
            .sorted { ($0.menuItemScore?.overallScore ?? 0) > ($1.menuItemScore?.overallScore ?? 0) }
            .prefix(3)
            .map { $0 }
    }
    
    var shouldShowScoring: Bool {
        scoringEnabled && confidence > 0.3
    }
}

struct AnalyzedMenuItem: Identifiable, Codable {
    let id = UUID()
    let name: String
    let description: String?
    let price: String?
    let ingredients: [IdentifiedIngredient]
    let nutritionEstimate: NutritionEstimate
    let dietaryTags: [DietaryTag]
    let confidence: Double
    let textBounds: CGRect?
    
    // Simplified estimation tier
    let estimationTier: EstimationTier
    let isGeneralizedEstimate: Bool
    
    // User corrections
    var userCorrectedName: String?
    var userCorrectedIngredients: [String]?
    var userDietaryFlags: [DietaryTag]?
    var userMarkedIncorrect: Bool = false
    
    // MARK: - Scoring Data
    var menuItemScore: MenuItemScore?
    var lastScoredFor: String? // User ID
    var scoringEnabled: Bool = true
    
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
        estimationTier: EstimationTier = .nutritionix,
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
    
    // MARK: - Scoring Helpers
    var hasValidScore: Bool {
        menuItemScore != nil && menuItemScore!.confidence > 0.5
    }
    
    var isHighlyRated: Bool {
        guard let score = menuItemScore else { return false }
        return score.overallScore >= 80
    }
    
    var shouldShowScoring: Bool {
        scoringEnabled && nutritionEstimate.confidence > 0.3
    }
}

struct IdentifiedIngredient: Identifiable, Codable {
    let id = UUID()
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

// Simplified estimation tier system - menu analysis only
enum EstimationTier: String, Codable, CaseIterable {
    case nutritionix = "nutritionix"   // Menu analysis with nutrition data
    case unavailable = "unavailable"   // No estimation available
    
    var displayName: String {
        switch self {
        case .nutritionix: return "Menu Analysis"
        case .unavailable: return "Nutrition Unavailable"
        }
    }
    
    var confidence: Double {
        switch self {
        case .nutritionix: return 0.85
        case .unavailable: return 0.0
        }
    }
    
    var emoji: String {
        switch self {
        case .nutritionix: return "📱🍽️"
        case .unavailable: return "❓"
        }
    }
    
    var warningEmoji: String {
        switch self {
        case .nutritionix: return ""
        case .unavailable: return "🚫"
        }
    }
    
    var description: String {
        switch self {
        case .nutritionix: return "AI-parsed menu items with nutrition analysis"
        case .unavailable: return "Nutrition information not available"
        }
    }
}

enum EstimationSource: String, Codable, CaseIterable {
    case nutritionix = "nutritionix"
    case unavailable = "unavailable"
    
    var displayName: String {
        switch self {
        case .nutritionix: return "Menu Analysis"
        case .unavailable: return "Unavailable"
        }
    }
    
    var confidence: Double {
        switch self {
        case .nutritionix: return 0.85
        case .unavailable: return 0.0
        }
    }
    
    var emoji: String {
        switch self {
        case .nutritionix: return "🍽️"
        case .unavailable: return "❓"
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

// MARK: - Analysis Configuration
struct MenuAnalysisConfig {
    static let minConfidenceThreshold: Double = 0.3
    static let maxMenuItems: Int = 50
    static let maxIngredients: Int = 20
    static let defaultPortionSize: String = "1 serving"
    
    static let highProteinThreshold: Double = 20.0 
    static let lowCarbThreshold: Double = 15.0 
    static let highCarbThreshold: Double = 45.0 
    static let ketoFatRatio: Double = 0.70 
    static let highFiberThreshold: Double = 5.0 
    static let lowSodiumThreshold: Double = 600.0 
}

extension AnalyzedMenuItem {
    static func createWithNutritionix(
        name: String,
        description: String?,
        price: String?,
        nutritionixResult: NutritionixNutritionResult,
        textBounds: CGRect?
    ) -> AnalyzedMenuItem {
        let nutritionEstimate = nutritionixResult.toNutritionEstimate()
        let dietaryTags = nutritionixResult.generateDietaryTags()
        
        return AnalyzedMenuItem(
            name: name,
            description: description ?? nutritionixResult.matchedFoodName,
            price: price,
            ingredients: [], // No ingredients identified from menu analysis
            nutritionEstimate: nutritionEstimate,
            dietaryTags: dietaryTags,
            confidence: nutritionixResult.confidence,
            textBounds: textBounds,
            estimationTier: .nutritionix,
            isGeneralizedEstimate: false
        )
    }
    
    static func createUnavailable(
        name: String,
        description: String?,
        price: String?,
        textBounds: CGRect?
    ) -> AnalyzedMenuItem {
        let nutritionEstimate = NutritionEstimate(
            calories: NutritionRange(min: 0, max: 0, unit: "kcal"),
            carbs: NutritionRange(min: 0, max: 0, unit: "g"),
            protein: NutritionRange(min: 0, max: 0, unit: "g"),
            fat: NutritionRange(min: 0, max: 0, unit: "g"),
            fiber: NutritionRange(min: 0, max: 0, unit: "g"),
            sodium: NutritionRange(min: 0, max: 0, unit: "mg"),
            sugar: NutritionRange(min: 0, max: 0, unit: "g"),
            confidence: 0.0,
            estimationSource: .unavailable,
            sourceDetails: "No nutrition data available",
            estimatedPortionSize: "Unknown",
            portionConfidence: 0.0
        )
        
        return AnalyzedMenuItem(
            name: name,
            description: description,
            price: price,
            ingredients: [],
            nutritionEstimate: nutritionEstimate,
            dietaryTags: [],
            confidence: 0.0,
            textBounds: textBounds,
            estimationTier: .unavailable,
            isGeneralizedEstimate: false
        )
    }
}