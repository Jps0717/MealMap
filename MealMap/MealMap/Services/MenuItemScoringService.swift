import Foundation
import SwiftUI

// MARK: - Menu Item Scoring Service
class MenuItemScoringService: ObservableObject {
    static let shared = MenuItemScoringService()
    
    private init() {}
    
    // MARK: - Core Scoring Function
    func calculatePersonalizedScore(
        for item: AnalyzedMenuItem,
        user: User?
    ) -> MenuItemScore {
        // If no user, return basic health score
        guard let user = user else {
            return calculateBasicHealthScore(for: item)
        }
        
        let nutritionScore = calculateNutritionScore(item: item, user: user)
        let goalAlignmentScore = calculateGoalAlignmentScore(item: item, user: user)
        let restrictionScore = calculateRestrictionScore(item: item, user: user)
        let portionScore = calculatePortionScore(item: item, user: user)
        
        // Weighted overall score
        let overallScore = (
            nutritionScore.value * 0.35 +
            goalAlignmentScore.value * 0.30 +
            restrictionScore.value * 0.25 +
            portionScore.value * 0.10
        )
        
        let explanations = [
            nutritionScore.explanation,
            goalAlignmentScore.explanation,
            restrictionScore.explanation,
            portionScore.explanation
        ].compactMap { $0 }
        
        return MenuItemScore(
            overallScore: min(100, max(0, overallScore)),
            nutritionScore: nutritionScore.value,
            goalAlignmentScore: goalAlignmentScore.value,
            restrictionScore: restrictionScore.value,
            portionScore: portionScore.value,
            explanations: explanations,
            personalizedFor: user,
            confidence: item.confidence,
            calculatedAt: Date()
        )
    }
    
    // MARK: - Basic Health Score (No User)
    private func calculateBasicHealthScore(for item: AnalyzedMenuItem) -> MenuItemScore {
        let nutrition = item.nutritionEstimate
        var score: Double = 70 // Base score
        var explanations: [ScoreExplanation] = []
        
        // Calorie assessment
        let avgCalories = nutrition.calories.average
        if avgCalories <= 400 {
            score += 15
            explanations.append(ScoreExplanation(
                category: .nutrition,
                impact: .positive,
                points: 15,
                reason: "Moderate calorie content (≤400 kcal)"
            ))
        } else if avgCalories <= 600 {
            score += 5
            explanations.append(ScoreExplanation(
                category: .nutrition,
                impact: .neutral,
                points: 5,
                reason: "Reasonable calorie content (401-600 kcal)"
            ))
        } else {
            score -= 10
            explanations.append(ScoreExplanation(
                category: .nutrition,
                impact: .negative,
                points: -10,
                reason: "High calorie content (>600 kcal)"
            ))
        }
        
        // Protein assessment
        let avgProtein = nutrition.protein.average
        if avgProtein >= 25 {
            score += 15
            explanations.append(ScoreExplanation(
                category: .nutrition,
                impact: .positive,
                points: 15,
                reason: "Excellent protein content (≥25g)"
            ))
        } else if avgProtein >= 15 {
            score += 8
            explanations.append(ScoreExplanation(
                category: .nutrition,
                impact: .positive,
                points: 8,
                reason: "Good protein content (15-24g)"
            ))
        }
        
        // Sodium assessment
        if let sodium = nutrition.sodium {
            let avgSodium = sodium.average
            if avgSodium <= 600 {
                score += 10
                explanations.append(ScoreExplanation(
                    category: .nutrition,
                    impact: .positive,
                    points: 10,
                    reason: "Low sodium content (≤600mg)"
                ))
            } else if avgSodium > 1500 {
                score -= 15
                explanations.append(ScoreExplanation(
                    category: .nutrition,
                    impact: .negative,
                    points: -15,
                    reason: "High sodium content (>1500mg)"
                ))
            }
        }
        
        // Fiber assessment
        if let fiber = nutrition.fiber {
            let avgFiber = fiber.average
            if avgFiber >= 5 {
                score += 10
                explanations.append(ScoreExplanation(
                    category: .nutrition,
                    impact: .positive,
                    points: 10,
                    reason: "High fiber content (≥5g)"
                ))
            }
        }
        
        // Dietary tag bonuses
        for tag in item.dietaryTags {
            switch tag {
            case .healthy:
                score += 5
                explanations.append(ScoreExplanation(
                    category: .general,
                    impact: .positive,
                    points: 5,
                    reason: "Tagged as healthy option"
                ))
            case .highProtein:
                score += 8
                explanations.append(ScoreExplanation(
                    category: .general,
                    impact: .positive,
                    points: 8,
                    reason: "High protein option"
                ))
            case .lowSodium:
                score += 6
                explanations.append(ScoreExplanation(
                    category: .general,
                    impact: .positive,
                    points: 6,
                    reason: "Low sodium option"
                ))
            case .indulgent:
                score -= 8
                explanations.append(ScoreExplanation(
                    category: .general,
                    impact: .negative,
                    points: -8,
                    reason: "Indulgent/high-calorie option"
                ))
            default:
                break
            }
        }
        
        return MenuItemScore(
            overallScore: min(100, max(0, score)),
            nutritionScore: score,
            goalAlignmentScore: 0,
            restrictionScore: 0,
            portionScore: 70,
            explanations: explanations,
            personalizedFor: nil,
            confidence: item.confidence,
            calculatedAt: Date()
        )
    }
    
    // MARK: - Nutrition Score (Macros & Micros)
    private func calculateNutritionScore(item: AnalyzedMenuItem, user: User) -> (value: Double, explanation: ScoreExplanation?) {
        let nutrition = item.nutritionEstimate
        let preferences = user.preferences
        var score: Double = 70
        var reasons: [String] = []
        
        // Calorie alignment
        let avgCalories = nutrition.calories.average
        let targetCalories = Double(preferences.dailyCalorieGoal) / 3 // Per meal target
        let calorieDeviation = abs(avgCalories - targetCalories) / targetCalories
        
        if calorieDeviation <= 0.2 {
            score += 15
            reasons.append("Calories align well with your daily goal")
        } else if calorieDeviation <= 0.4 {
            score += 5
            reasons.append("Calories moderately aligned with your goal")
        } else {
            score -= 10
            reasons.append("Calories don't align well with your daily goal")
        }
        
        // Protein alignment
        let avgProtein = nutrition.protein.average
        let targetProtein = Double(preferences.dailyProteinGoal) / 3 // Per meal target
        let proteinRatio = avgProtein / targetProtein
        
        if proteinRatio >= 0.8 {
            score += 15
            reasons.append("Excellent protein content for your goals")
        } else if proteinRatio >= 0.5 {
            score += 8
            reasons.append("Good protein content")
        } else {
            score -= 5
            reasons.append("Low protein content for your goals")
        }
        
        // Sodium check
        if let sodium = nutrition.sodium {
            let avgSodium = sodium.average
            let dailySodiumLimit = Double(preferences.dailySodiumLimit)
            let sodiumPercentage = (avgSodium / dailySodiumLimit) * 100
            
            if sodiumPercentage <= 20 {
                score += 10
                reasons.append("Low sodium content")
            } else if sodiumPercentage > 40 {
                score -= 15
                reasons.append("High sodium content")
            }
        }
        
        // Fiber bonus
        if let fiber = nutrition.fiber {
            let avgFiber = fiber.average
            let targetFiber = Double(preferences.dailyFiberGoal) / 3
            if avgFiber >= targetFiber {
                score += 10
                reasons.append("High fiber content")
            }
        }
        
        let explanation = ScoreExplanation(
            category: .nutrition,
            impact: score >= 70 ? .positive : .negative,
            points: Int(score - 70),
            reason: reasons.joined(separator: ", ")
        )
        
        return (min(100, max(0, score)), explanation)
    }
    
    // MARK: - Goal Alignment Score
    private func calculateGoalAlignmentScore(item: AnalyzedMenuItem, user: User) -> (value: Double, explanation: ScoreExplanation?) {
        let nutrition = item.nutritionEstimate
        let goals = user.profile.healthGoals
        var score: Double = 70
        var reasons: [String] = []
        
        for goal in goals {
            switch goal {
            case .weightLoss:
                let avgCalories = nutrition.calories.average
                if avgCalories <= 400 {
                    score += 15
                    reasons.append("Low calorie - supports weight loss")
                } else if avgCalories <= 600 {
                    score += 5
                    reasons.append("Moderate calories for weight loss")
                } else {
                    score -= 10
                    reasons.append("High calories - not ideal for weight loss")
                }
                
            case .buildMuscle:
                let avgProtein = nutrition.protein.average
                if avgProtein >= 25 {
                    score += 15
                    reasons.append("High protein - excellent for muscle building")
                } else if avgProtein >= 15 {
                    score += 8
                    reasons.append("Good protein for muscle building")
                } else {
                    score -= 5
                    reasons.append("Low protein for muscle building goals")
                }
                
            case .improveHealth:
                // Bonus for healthy tags
                if item.dietaryTags.contains(.healthy) {
                    score += 10
                    reasons.append("Tagged as healthy option")
                }
                if item.dietaryTags.contains(.lowSodium) {
                    score += 8
                    reasons.append("Low sodium supports health goals")
                }
                if item.dietaryTags.contains(.highFiber) {
                    score += 8
                    reasons.append("High fiber supports digestive health")
                }
                
            case .increaseEnergy:
                let avgCarbs = nutrition.carbs.average
                if avgCarbs >= 30 && avgCarbs <= 60 {
                    score += 10
                    reasons.append("Balanced carbs for sustained energy")
                }
                
            case .weightGain:
                let avgCalories = nutrition.calories.average
                if avgCalories >= 600 {
                    score += 10
                    reasons.append("High calories support weight gain")
                }
                
            case .maintainWeight:
                let avgCalories = nutrition.calories.average
                if avgCalories >= 400 && avgCalories <= 600 {
                    score += 10
                    reasons.append("Balanced calories for weight maintenance")
                }
            }
        }
        
        let explanation = ScoreExplanation(
            category: .goals,
            impact: score >= 70 ? .positive : .negative,
            points: Int(score - 70),
            reason: reasons.isEmpty ? "No specific goal alignment" : reasons.joined(separator: ", ")
        )
        
        return (min(100, max(0, score)), explanation)
    }
    
    // MARK: - Dietary Restriction Score
    private func calculateRestrictionScore(item: AnalyzedMenuItem, user: User) -> (value: Double, explanation: ScoreExplanation?) {
        let restrictions = user.profile.dietaryRestrictions
        var score: Double = 100 // Start perfect
        var violations: [String] = []
        
        for restriction in restrictions {
            switch restriction {
            case .vegan:
                if !item.dietaryTags.contains(.vegan) {
                    // Check for non-vegan indicators
                    let nonVeganTerms = ["chicken", "beef", "pork", "fish", "cheese", "milk", "egg", "bacon", "turkey", "lamb"]
                    let itemText = (item.name + " " + (item.description ?? "")).lowercased()
                    
                    if nonVeganTerms.contains(where: { itemText.contains($0) }) {
                        score = 0
                        violations.append("Contains animal products (not vegan)")
                    }
                }
                
            case .vegetarian:
                if !item.dietaryTags.contains(.vegetarian) && !item.dietaryTags.contains(.vegan) {
                    let meatTerms = ["chicken", "beef", "pork", "fish", "bacon", "turkey", "lamb", "sausage"]
                    let itemText = (item.name + " " + (item.description ?? "")).lowercased()
                    
                    if meatTerms.contains(where: { itemText.contains($0) }) {
                        score = 0
                        violations.append("Contains meat (not vegetarian)")
                    }
                }
                
            case .glutenFree:
                if !item.dietaryTags.contains(.glutenFree) {
                    let glutenTerms = ["bread", "pasta", "wheat", "flour", "croutons", "bun", "wrap", "tortilla"]
                    let itemText = (item.name + " " + (item.description ?? "")).lowercased()
                    
                    if glutenTerms.contains(where: { itemText.contains($0) }) {
                        score = 0
                        violations.append("May contain gluten")
                    }
                }
                
            case .dairyFree:
                if !item.dietaryTags.contains(.dairyFree) {
                    let dairyTerms = ["cheese", "milk", "cream", "butter", "yogurt", "parmesan", "mozzarella"]
                    let itemText = (item.name + " " + (item.description ?? "")).lowercased()
                    
                    if dairyTerms.contains(where: { itemText.contains($0) }) {
                        score = 0
                        violations.append("Contains dairy")
                    }
                }
                
            case .lowCarb, .keto:
                let avgCarbs = item.nutritionEstimate.carbs.average
                let threshold = restriction == .keto ? 10.0 : 20.0
                
                if avgCarbs > threshold {
                    score -= 30
                    violations.append("High carbs (\(Int(avgCarbs))g) for \(restriction.rawValue)")
                }
                
            case .lowSodium:
                if let sodium = item.nutritionEstimate.sodium {
                    let avgSodium = sodium.average
                    if avgSodium > 600 {
                        score -= 25
                        violations.append("High sodium (\(Int(avgSodium))mg) for low-sodium diet")
                    }
                }
                
            case .diabetic:
                if let sugar = item.nutritionEstimate.sugar {
                    let avgSugar = sugar.average
                    if avgSugar > 15 {
                        score -= 20
                        violations.append("High sugar (\(Int(avgSugar))g) for diabetic diet")
                    }
                }
                
            default:
                break
            }
        }
        
        let explanation = ScoreExplanation(
            category: .restrictions,
            impact: score >= 90 ? .positive : .negative,
            points: Int(score - 100),
            reason: violations.isEmpty ? "Meets all dietary restrictions" : violations.joined(separator: ", ")
        )
        
        return (min(100, max(0, score)), explanation)
    }
    
    // MARK: - Portion Score
    private func calculatePortionScore(item: AnalyzedMenuItem, user: User) -> (value: Double, explanation: ScoreExplanation?) {
        let nutrition = item.nutritionEstimate
        let avgCalories = nutrition.calories.average
        let targetCalories = Double(user.preferences.dailyCalorieGoal) / 3
        
        var score: Double = 70
        var reason: String
        
        let ratio = avgCalories / targetCalories
        
        if ratio >= 0.8 && ratio <= 1.2 {
            score = 90
            reason = "Appropriate portion size for your daily goals"
        } else if ratio >= 0.6 && ratio <= 1.4 {
            score = 75
            reason = "Reasonable portion size"
        } else if ratio < 0.6 {
            score = 60
            reason = "Small portion - may need additional food"
        } else {
            score = 50
            reason = "Large portion - consider sharing or saving some"
        }
        
        let explanation = ScoreExplanation(
            category: .portion,
            impact: score >= 70 ? .positive : .neutral,
            points: Int(score - 70),
            reason: reason
        )
        
        return (score, explanation)
    }
    
    // MARK: - Batch Scoring
    func calculateScoresForItems(
        _ items: [AnalyzedMenuItem],
        user: User?
    ) -> [String: MenuItemScore] {
        var scores: [String: MenuItemScore] = [:]
        
        for item in items {
            let score = calculatePersonalizedScore(for: item, user: user)
            scores[item.id.uuidString] = score
        }
        
        return scores
    }
}

// MARK: - Score Data Models
struct MenuItemScore: Identifiable, Codable {
    var id = UUID()
    let overallScore: Double
    let nutritionScore: Double
    let goalAlignmentScore: Double
    let restrictionScore: Double
    let portionScore: Double
    let explanations: [ScoreExplanation]
    let personalizedFor: User?
    let confidence: Double
    let calculatedAt: Date
    
    var scoreGrade: ScoreGrade {
        switch overallScore {
        case 90...:
            return .excellent
        case 80..<90:
            return .veryGood
        case 70..<80:
            return .good
        case 60..<70:
            return .fair
        case 50..<60:
            return .poor
        default:
            return .veryPoor
        }
    }
    
    var scoreColor: Color {
        scoreGrade.color
    }
    
    var isPersonalized: Bool {
        personalizedFor != nil
    }
}

struct ScoreExplanation: Identifiable, Codable {
    var id = UUID()
    let category: ScoreCategory
    let impact: ScoreImpact
    let points: Int
    let reason: String
}

enum ScoreCategory: String, CaseIterable, Codable {
    case nutrition = "Nutrition"
    case goals = "Goals"
    case restrictions = "Restrictions"
    case portion = "Portion"
    case general = "General"
    
    var icon: String {
        switch self {
        case .nutrition:
            return "chart.bar.fill"
        case .goals:
            return "target"
        case .restrictions:
            return "exclamationmark.shield.fill"
        case .portion:
            return "scalemass.fill"
        case .general:
            return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .nutrition:
            return .blue
        case .goals:
            return .green
        case .restrictions:
            return .red
        case .portion:
            return .orange
        case .general:
            return .purple
        }
    }
}

enum ScoreImpact: String, CaseIterable, Codable {
    case positive = "Positive"
    case negative = "Negative"
    case neutral = "Neutral"
    
    var color: Color {
        switch self {
        case .positive:
            return .green
        case .negative:
            return .red
        case .neutral:
            return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .positive:
            return "plus.circle.fill"
        case .negative:
            return "minus.circle.fill"
        case .neutral:
            return "circle.fill"
        }
    }
}