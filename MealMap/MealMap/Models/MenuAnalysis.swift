import Foundation
import CoreLocation
import UIKit

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
    
    // ENHANCED: USDA fallback support
    let estimationTier: EstimationTier
    let usdaEstimate: USDANutritionEstimate?
    let isGeneralizedEstimate: Bool
    
    // User corrections
    var userCorrectedName: String?
    var userCorrectedIngredients: [String]?
    var userDietaryFlags: [DietaryTag]?
    var userMarkedIncorrect: Bool = false
    
    // FIXED: Default initializer for backward compatibility
    init(
        name: String,
        description: String?,
        price: String?,
        ingredients: [IdentifiedIngredient],
        nutritionEstimate: NutritionEstimate,
        dietaryTags: [DietaryTag],
        confidence: Double,
        textBounds: CGRect?,
        estimationTier: EstimationTier = .ingredients,
        usdaEstimate: USDANutritionEstimate? = nil,
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
        self.usdaEstimate = usdaEstimate
        self.isGeneralizedEstimate = isGeneralizedEstimate
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
    
    // ENHANCED: Add estimation source tracking
    let estimationSource: EstimationSource
    let sourceDetails: String? // Additional context about the estimation
    
    // Portion size estimation
    let estimatedPortionSize: String? // "1 serving", "large portion", etc.
    let portionConfidence: Double
}

struct NutritionRange: Codable {
    let min: Double
    let max: Double
    let unit: String // "g", "mg", "kcal"
    
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
    
    var color: String {
        switch self {
        case .highProtein: return "#FF6B6B"
        case .lowCarb: return "#4ECDC4"
        case .highCarb: return "#FFE66D"
        case .keto: return "#95E1D3"
        case .vegan: return "#A8E6CF"
        case .vegetarian: return "#C7CEEA"
        case .glutenFree: return "#FDBCB4"
        case .dairyFree: return "#B8E6B8"
        case .lowSodium: return "#87CEEB"
        case .highFiber: return "#DDA0DD"
        case .lowSugar: return "#F0E68C"
        case .healthy: return "#98FB98"
        case .indulgent: return "#FFB6C1"
        }
    }
}

// ENHANCED: Add estimation tier system
enum EstimationTier: String, Codable, CaseIterable {
    case ingredients = "ingredients"    // Tier 1: High confidence from ingredient analysis
    case usda = "usda"                 // Tier 2: Medium confidence from USDA database
    case unavailable = "unavailable"   // Tier 3: No estimation available
    
    var displayName: String {
        switch self {
        case .ingredients: return "Ingredient Analysis"
        case .usda: return "USDA Database"
        case .unavailable: return "Nutrition Unavailable"
        }
    }
    
    var confidence: Double {
        switch self {
        case .ingredients: return 0.8
        case .usda: return 0.6
        case .unavailable: return 0.0
        }
    }
    
    var emoji: String {
        switch self {
        case .ingredients: return "🧪"
        case .usda: return "📊"
        case .unavailable: return "❓"
        }
    }
    
    var warningEmoji: String {
        switch self {
        case .ingredients: return ""
        case .usda: return "⚠️"
        case .unavailable: return "🚫"
        }
    }
    
    var description: String {
        switch self {
        case .ingredients: return "Nutrition estimated from identified ingredients"
        case .usda: return "Estimated from USDA database"
        case .unavailable: return "Nutrition information not available"
        }
    }
}

enum EstimationSource: String, Codable, CaseIterable {
    case ingredients = "ingredients"
    case usda = "usda"
    case unavailable = "unavailable"
    
    var displayName: String {
        switch self {
        case .ingredients: return "Ingredient Analysis"
        case .usda: return "USDA Database"
        case .unavailable: return "Unavailable"
        }
    }
    
    var confidence: Double {
        switch self {
        case .ingredients: return 0.8
        case .usda: return 0.6
        case .unavailable: return 0.0
        }
    }
    
    var emoji: String {
        switch self {
        case .ingredients: return "🧪"
        case .usda: return "📊"
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

struct USDANutritionEstimate: Codable {
    let originalItemName: String
    let calories: NutritionRange
    let carbs: NutritionRange
    let protein: NutritionRange
    let fat: NutritionRange
    let fiber: NutritionRange?
    let sugar: NutritionRange?
    let sodium: NutritionRange?
    let confidence: Double
    let estimationSource: EstimationSource
    let matchCount: Int
    let isGeneralizedEstimate: Bool
    let timestamp: Date = Date()
}

// ENHANCED: Add convenience initializers for different estimation tiers
extension AnalyzedMenuItem {
    static func createWithIngredients(
        name: String,
        description: String?,
        price: String?,
        ingredients: [IdentifiedIngredient],
        nutritionEstimate: NutritionEstimate,
        dietaryTags: [DietaryTag],
        confidence: Double,
        textBounds: CGRect?
    ) -> AnalyzedMenuItem {
        return AnalyzedMenuItem(
            name: name,
            description: description,
            price: price,
            ingredients: ingredients,
            nutritionEstimate: nutritionEstimate,
            dietaryTags: dietaryTags,
            confidence: confidence,
            textBounds: textBounds,
            estimationTier: .ingredients,
            usdaEstimate: nil,
            isGeneralizedEstimate: false
        )
    }
    
    static func createWithUSDA(
        name: String,
        description: String?,
        price: String?,
        usdaEstimate: USDANutritionEstimate,
        textBounds: CGRect?
    ) -> AnalyzedMenuItem {
        // Convert USDA estimate to NutritionEstimate format
        let nutritionEstimate = NutritionEstimate(
            calories: usdaEstimate.calories,
            carbs: usdaEstimate.carbs,
            protein: usdaEstimate.protein,
            fat: usdaEstimate.fat,
            fiber: usdaEstimate.fiber,
            sodium: usdaEstimate.sodium,
            sugar: usdaEstimate.sugar,
            confidence: usdaEstimate.confidence,
            estimationSource: .usda,
            sourceDetails: "Based on \(usdaEstimate.matchCount) USDA database matches",
            estimatedPortionSize: "1 serving",
            portionConfidence: 0.5
        )
        
        // Generate basic dietary tags from USDA data
        let dietaryTags = generateDietaryTagsFromUSDA(usdaEstimate)
        
        return AnalyzedMenuItem(
            name: name,
            description: description,
            price: price,
            ingredients: [], // No ingredients identified
            nutritionEstimate: nutritionEstimate,
            dietaryTags: dietaryTags,
            confidence: usdaEstimate.confidence,
            textBounds: textBounds,
            estimationTier: .usda,
            usdaEstimate: usdaEstimate,
            isGeneralizedEstimate: true
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
            usdaEstimate: nil,
            isGeneralizedEstimate: false
        )
    }
    
    // ENHANCED: Add intelligent USDA convenience initializer
    static func createWithIntelligentUSDA(
        name: String,
        description: String?,
        price: String?,
        intelligentResult: IntelligentNutritionResult,
        textBounds: CGRect?
    ) -> AnalyzedMenuItem {
        // Convert IntelligentNutritionRange to NutritionRange
        let nutritionEstimate = NutritionEstimate(
            calories: convertToNutritionRange(intelligentResult.estimatedNutrition.calories),
            carbs: convertToNutritionRange(intelligentResult.estimatedNutrition.carbs),
            protein: convertToNutritionRange(intelligentResult.estimatedNutrition.protein),
            fat: convertToNutritionRange(intelligentResult.estimatedNutrition.fat),
            fiber: intelligentResult.estimatedNutrition.fiber != nil ? convertToNutritionRange(intelligentResult.estimatedNutrition.fiber!) : nil,
            sodium: intelligentResult.estimatedNutrition.sodium != nil ? convertToNutritionRange(intelligentResult.estimatedNutrition.sodium!) : nil,
            sugar: intelligentResult.estimatedNutrition.sugar != nil ? convertToNutritionRange(intelligentResult.estimatedNutrition.sugar!) : nil,
            confidence: intelligentResult.estimatedNutrition.confidence,
            estimationSource: .usda,
            sourceDetails: "Intelligent USDA match: '\(intelligentResult.bestMatchName)' (score: \(String(format: "%.2f", intelligentResult.bestMatchScore)))",
            estimatedPortionSize: "1 serving",
            portionConfidence: 0.6
        )
        
        // Generate enhanced dietary tags from intelligent nutrition data
        let dietaryTags = generateIntelligentDietaryTags(from: intelligentResult.estimatedNutrition)
        
        return AnalyzedMenuItem(
            name: name,
            description: description,
            price: price,
            ingredients: [], // NO INGREDIENTS in USDA-only mode
            nutritionEstimate: nutritionEstimate,
            dietaryTags: dietaryTags,
            confidence: intelligentResult.estimatedNutrition.confidence,
            textBounds: textBounds,
            estimationTier: .usda,
            usdaEstimate: convertIntelligentToLegacyFormat(intelligentResult),
            isGeneralizedEstimate: true
        )
    }
}

// Helper function to generate dietary tags from USDA data
private func generateDietaryTagsFromUSDA(_ usdaEstimate: USDANutritionEstimate) -> [DietaryTag] {
    var tags: [DietaryTag] = []
    
    // High protein check
    if usdaEstimate.protein.average >= MenuAnalysisConfig.highProteinThreshold {
        tags.append(.highProtein)
    }
    
    // Carb-based tags
    if usdaEstimate.carbs.average <= MenuAnalysisConfig.lowCarbThreshold {
        tags.append(.lowCarb)
    } else if usdaEstimate.carbs.average >= MenuAnalysisConfig.highCarbThreshold {
        tags.append(.highCarb)
    }
    
    // Health assessment based on calories and sodium
    if usdaEstimate.calories.average <= 400,
       let sodium = usdaEstimate.sodium,
       sodium.average <= MenuAnalysisConfig.lowSodiumThreshold {
        tags.append(.healthy)
    } else if usdaEstimate.calories.average > 600 {
        tags.append(.indulgent)
    }
    
    return tags
}

// Helper functions for intelligent USDA mode
private func generateIntelligentDietaryTags(from nutrition: EstimatedNutrition) -> [DietaryTag] {
    var tags: [DietaryTag] = []
    
    // Enhanced macro-based rules with confidence consideration
    if nutrition.protein.average >= 20 && nutrition.confidence > 0.6 {
        tags.append(.highProtein)
    }
    
    if nutrition.carbs.average <= 15 && nutrition.confidence > 0.5 {
        tags.append(.lowCarb)
    } else if nutrition.carbs.average >= 45 && nutrition.confidence > 0.5 {
        tags.append(.highCarb)
    }
    
    if nutrition.calories.average <= 400 && nutrition.confidence > 0.6 {
        tags.append(.healthy)
    } else if nutrition.calories.average > 600 && nutrition.confidence > 0.6 {
        tags.append(.indulgent)
    }
    
    if let sugar = nutrition.sugar, sugar.average <= 5 && nutrition.confidence > 0.5 {
        tags.append(.lowSugar)
    }
    
    if let fiber = nutrition.fiber, fiber.average >= 5 && nutrition.confidence > 0.6 {
        tags.append(.highFiber)
    }
    
    if let sodium = nutrition.sodium, sodium.average <= 600 && nutrition.confidence > 0.6 {
        tags.append(.lowSodium)
    }
    
    return tags
}

// Helper function to convert between nutrition range types
private func convertToNutritionRange(_ intelligentRange: IntelligentNutritionRange) -> NutritionRange {
    return NutritionRange(
        min: intelligentRange.min,
        max: intelligentRange.max,
        unit: intelligentRange.unit
    )
}

// Convert intelligent result to legacy USDA format
private func convertIntelligentToLegacyFormat(_ intelligentResult: IntelligentNutritionResult) -> USDANutritionEstimate {
    return USDANutritionEstimate(
        originalItemName: intelligentResult.originalName,
        calories: convertToNutritionRange(intelligentResult.estimatedNutrition.calories),
        carbs: convertToNutritionRange(intelligentResult.estimatedNutrition.carbs),
        protein: convertToNutritionRange(intelligentResult.estimatedNutrition.protein),
        fat: convertToNutritionRange(intelligentResult.estimatedNutrition.fat),
        fiber: intelligentResult.estimatedNutrition.fiber != nil ? convertToNutritionRange(intelligentResult.estimatedNutrition.fiber!) : nil,
        sugar: intelligentResult.estimatedNutrition.sugar != nil ? convertToNutritionRange(intelligentResult.estimatedNutrition.sugar!) : nil,
        sodium: intelligentResult.estimatedNutrition.sodium != nil ? convertToNutritionRange(intelligentResult.estimatedNutrition.sodium!) : nil,
        confidence: intelligentResult.estimatedNutrition.confidence,
        estimationSource: .usda,
        matchCount: intelligentResult.matchCount,
        isGeneralizedEstimate: true
    )
}

// MARK: - Analysis Configuration
struct MenuAnalysisConfig {
    static let minConfidenceThreshold: Double = 0.3
    static let maxMenuItems: Int = 50
    static let maxIngredients: Int = 20
    static let defaultPortionSize: String = "1 serving"
    
    // Nutrition estimation rules
    static let highProteinThreshold: Double = 20.0 // grams
    static let lowCarbThreshold: Double = 15.0 // grams
    static let highCarbThreshold: Double = 45.0 // grams
    static let ketoFatRatio: Double = 0.70 // 70% calories from fat
    static let highFiberThreshold: Double = 5.0 // grams
    static let lowSodiumThreshold: Double = 600.0 // mg
}