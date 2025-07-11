import Foundation

class MenuItemScoringService {
    
    struct MenuItemScore {
        let overallScore: Double // 0-100
        let categoryScores: [String: Double]
        let violations: [String]
        let recommendations: [String]
        let matchLevel: MatchLevel
    }
    
    enum MatchLevel: String, CaseIterable {
        case excellent = "Excellent Match"
        case good = "Good Match"
        case fair = "Fair Match"
        case poor = "Poor Match"
        case avoid = "Avoid"
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "yellow"
            case .poor: return "orange"
            case .avoid: return "red"
            }
        }
    }
    
    static func scoreMenuItem(_ item: AnalyzedMenuItem, for user: User) -> MenuItemScore {
        var totalScore: Double = 0
        var categoryScores: [String: Double] = [:]
        var violations: [String] = []
        var recommendations: [String] = []
        
        // 1. Dietary Restrictions Check (Critical - can make item unsuitable)
        let restrictionScore = checkDietaryRestrictions(item: item, restrictions: user.profile.dietaryRestrictions)
        if restrictionScore.score == 0 {
            return MenuItemScore(
                overallScore: 0,
                categoryScores: ["restrictions": 0],
                violations: restrictionScore.violations,
                recommendations: ["This item doesn't meet your dietary restrictions"],
                matchLevel: .avoid
            )
        }
        
        // 2. Macro Goals Alignment (40% of score)
        let macroScore = scoreMacroAlignment(item: item, preferences: user.preferences)
        totalScore += macroScore.score * 0.4
        categoryScores["macros"] = macroScore.score
        violations.append(contentsOf: macroScore.violations)
        recommendations.append(contentsOf: macroScore.recommendations)
        
        // 3. Health Goals Alignment (30% of score)
        let healthScore = scoreHealthGoals(item: item, goals: user.profile.healthGoals)
        totalScore += healthScore.score * 0.3
        categoryScores["health"] = healthScore.score
        violations.append(contentsOf: healthScore.violations)
        recommendations.append(contentsOf: healthScore.recommendations)
        
        // 4. Nutritional Quality (20% of score)
        let qualityScore = scoreNutritionalQuality(item: item)
        totalScore += qualityScore.score * 0.2
        categoryScores["quality"] = qualityScore.score
        violations.append(contentsOf: qualityScore.violations)
        recommendations.append(contentsOf: qualityScore.recommendations)
        
        // 5. Calorie Alignment (10% of score)
        let calorieScore = scoreCalorieAlignment(item: item, preferences: user.preferences)
        totalScore += calorieScore.score * 0.1
        categoryScores["calories"] = calorieScore.score
        violations.append(contentsOf: calorieScore.violations)
        recommendations.append(contentsOf: calorieScore.recommendations)
        
        let matchLevel = determineMatchLevel(score: totalScore)
        
        return MenuItemScore(
            overallScore: totalScore,
            categoryScores: categoryScores,
            violations: violations,
            recommendations: recommendations,
            matchLevel: matchLevel
        )
    }
    
    // MARK: - Dietary Restrictions
    private static func checkDietaryRestrictions(item: AnalyzedMenuItem, restrictions: [DietaryRestriction]) -> (score: Double, violations: [String]) {
        var violations: [String] = []
        
        for restriction in restrictions {
            if violatesRestriction(item: item, restriction: restriction) {
                violations.append("Contains ingredients not suitable for \(restriction.rawValue)")
                return (0.0, violations) // Hard fail for dietary restrictions
            }
        }
        
        return (100.0, violations)
    }
    
    private static func violatesRestriction(item: AnalyzedMenuItem, restriction: DietaryRestriction) -> Bool {
        let itemTags = item.dietaryTags
        let itemName = item.name.lowercased()
        let itemDescription = item.description?.lowercased() ?? ""
        
        switch restriction {
        case .vegetarian:
            return containsMeat(name: itemName, description: itemDescription)
        case .vegan:
            return containsAnimalProducts(name: itemName, description: itemDescription)
        case .glutenFree:
            return containsGluten(name: itemName, description: itemDescription)
        case .dairyFree:
            return containsDairy(name: itemName, description: itemDescription)
        case .nutFree:
            return containsNuts(name: itemName, description: itemDescription)
        case .lowCarb:
            return item.nutritionEstimate.carbs.average > 20
        case .keto:
            return !itemTags.contains(.keto) && item.nutritionEstimate.carbs.average > 10
        case .paleo:
            return containsProcessedFoods(name: itemName, description: itemDescription)
        case .lowSodium:
            return item.nutritionEstimate.sodium?.average ?? 0 > 600
        case .diabetic:
            return item.nutritionEstimate.sugar?.average ?? 0 > 15
        }
    }
    
    // MARK: - Macro Alignment
    private static func scoreMacroAlignment(item: AnalyzedMenuItem, preferences: UserPreferences) -> (score: Double, violations: [String], recommendations: [String]) {
        var score: Double = 0
        var violations: [String] = []
        var recommendations: [String] = []
        
        let nutrition = item.nutritionEstimate
        let mealCalories = nutrition.calories.average
        let targetMealCalories = Double(preferences.dailyCalorieGoal) / 3 // Assuming 3 meals per day
        
        // Calculate macro percentages
        let proteinCals = nutrition.protein.average * 4
        let carbCals = nutrition.carbs.average * 4
        let fatCals = nutrition.fat.average * 9
        
        let proteinPercent = proteinCals / mealCalories
        let carbPercent = carbCals / mealCalories
        let fatPercent = fatCals / mealCalories
        
        // Target macro percentages based on goals
        let targetProtein = Double(preferences.dailyProteinGoal) / 3
        let targetCarbs = Double(preferences.dailyCarbGoal) / 3
        let targetFat = Double(preferences.dailyFatGoal) / 3
        
        // Score protein alignment
        let proteinScore = scoreNutrientAlignment(
            actual: nutrition.protein.average,
            target: targetProtein,
            tolerance: 0.3
        )
        score += proteinScore * 0.4
        
        // Score carb alignment
        let carbScore = scoreNutrientAlignment(
            actual: nutrition.carbs.average,
            target: targetCarbs,
            tolerance: 0.3
        )
        score += carbScore * 0.3
        
        // Score fat alignment
        let fatScore = scoreNutrientAlignment(
            actual: nutrition.fat.average,
            target: targetFat,
            tolerance: 0.3
        )
        score += fatScore * 0.3
        
        // Add violations and recommendations
        if proteinScore < 0.5 {
            violations.append("Protein content doesn't align with your goals")
            recommendations.append("Look for items with more protein")
        }
        
        if carbScore < 0.5 {
            violations.append("Carb content doesn't align with your goals")
            recommendations.append("Consider your daily carb targets")
        }
        
        return (score * 100, violations, recommendations)
    }
    
    // MARK: - Health Goals
    private static func scoreHealthGoals(item: AnalyzedMenuItem, goals: [HealthGoal]) -> (score: Double, violations: [String], recommendations: [String]) {
        var score: Double = 100
        var violations: [String] = []
        var recommendations: [String] = []
        
        for goal in goals {
            let goalScore = scoreForHealthGoal(item: item, goal: goal)
            score = min(score, goalScore.score)
            violations.append(contentsOf: goalScore.violations)
            recommendations.append(contentsOf: goalScore.recommendations)
        }
        
        return (score, violations, recommendations)
    }
    
    private static func scoreForHealthGoal(item: AnalyzedMenuItem, goal: HealthGoal) -> (score: Double, violations: [String], recommendations: [String]) {
        let nutrition = item.nutritionEstimate
        var violations: [String] = []
        var recommendations: [String] = []
        
        switch goal {
        case .weightLoss:
            let calorieScore = nutrition.calories.average < 400 ? 100.0 : max(0, 100.0 - (nutrition.calories.average - 400) / 10)
            if calorieScore < 70 {
                violations.append("High calorie content for weight loss")
                recommendations.append("Look for lighter options")
            }
            return (calorieScore, violations, recommendations)
            
        case .buildMuscle:
            let proteinScore = nutrition.protein.average > 20 ? 100.0 : nutrition.protein.average / 20 * 100.0
            if proteinScore < 70 {
                violations.append("Low protein content for muscle building")
                recommendations.append("Add protein-rich items")
            }
            return (proteinScore, violations, recommendations)
            
        case .improveHealth:
            let fiberScore = (nutrition.fiber?.average ?? 0) > 5 ? 100.0 : 70.0
            let sodiumScore = (nutrition.sodium?.average ?? 0) < 600 ? 100.0 : 70.0
            let avgScore = (fiberScore + sodiumScore) / 2
            if avgScore < 70 {
                violations.append("May not support health goals")
                recommendations.append("Choose items with more fiber and less sodium")
            }
            return (avgScore, violations, recommendations)
            
        default:
            return (100.0, violations, recommendations)
        }
    }
    
    // MARK: - Nutritional Quality
    private static func scoreNutritionalQuality(item: AnalyzedMenuItem) -> (score: Double, violations: [String], recommendations: [String]) {
        var score: Double = 100
        var violations: [String] = []
        var recommendations: [String] = []
        
        let nutrition = item.nutritionEstimate
        
        // Penalize high sodium
        if let sodium = nutrition.sodium?.average, sodium > 800 {
            score -= 20
            violations.append("High sodium content")
            recommendations.append("Consider lower sodium options")
        }
        
        // Penalize high sugar
        if let sugar = nutrition.sugar?.average, sugar > 20 {
            score -= 15
            violations.append("High sugar content")
            recommendations.append("Look for lower sugar alternatives")
        }
        
        // Reward high fiber
        if let fiber = nutrition.fiber?.average, fiber > 5 {
            score += 10
            score = min(score, 100)
        }
        
        // Reward balanced macros
        let calories = nutrition.calories.average
        let proteinCals = nutrition.protein.average * 4
        let proteinPercent = proteinCals / calories
        
        if proteinPercent > 0.15 && proteinPercent < 0.35 {
            score += 5
            score = min(score, 100)
        }
        
        return (score, violations, recommendations)
    }
    
    // MARK: - Calorie Alignment
    private static func scoreCalorieAlignment(item: AnalyzedMenuItem, preferences: UserPreferences) -> (score: Double, violations: [String], recommendations: [String]) {
        let itemCalories = item.nutritionEstimate.calories.average
        let targetMealCalories = Double(preferences.dailyCalorieGoal) / 3
        
        let score = scoreNutrientAlignment(
            actual: itemCalories,
            target: targetMealCalories,
            tolerance: 0.4
        ) * 100
        
        var violations: [String] = []
        var recommendations: [String] = []
        
        if score < 70 {
            if itemCalories > targetMealCalories * 1.4 {
                violations.append("High calorie content for your goals")
                recommendations.append("Consider sharing or choosing a smaller portion")
            } else {
                violations.append("Low calorie content for your goals")
                recommendations.append("Consider adding sides or protein")
            }
        }
        
        return (score, violations, recommendations)
    }
    
    // MARK: - Helper Methods
    private static func scoreNutrientAlignment(actual: Double, target: Double, tolerance: Double) -> Double {
        let ratio = actual / target
        let idealRange = (1.0 - tolerance)...(1.0 + tolerance)
        
        if idealRange.contains(ratio) {
            return 1.0
        } else if ratio < idealRange.lowerBound {
            return max(0, ratio / idealRange.lowerBound)
        } else {
            return max(0, 1.0 - (ratio - idealRange.upperBound) / idealRange.upperBound)
        }
    }
    
    private static func determineMatchLevel(score: Double) -> MatchLevel {
        switch score {
        case 90...100: return .excellent
        case 75..<90: return .good
        case 60..<75: return .fair
        case 30..<60: return .poor
        default: return .avoid
        }
    }
    
    // MARK: - Dietary Restriction Helper Methods
    private static func containsMeat(name: String, description: String) -> Bool {
        let meatKeywords = ["beef", "chicken", "pork", "lamb", "turkey", "fish", "salmon", "tuna", "shrimp", "bacon", "ham", "sausage", "steak", "burger"]
        return meatKeywords.contains { name.contains($0) || description.contains($0) }
    }
    
    private static func containsAnimalProducts(name: String, description: String) -> Bool {
        let animalKeywords = ["beef", "chicken", "pork", "lamb", "turkey", "fish", "salmon", "tuna", "shrimp", "bacon", "ham", "sausage", "steak", "burger", "cheese", "milk", "butter", "cream", "egg", "yogurt", "mayo"]
        return animalKeywords.contains { name.contains($0) || description.contains($0) }
    }
    
    private static func containsGluten(name: String, description: String) -> Bool {
        let glutenKeywords = ["wheat", "bread", "pasta", "noodles", "flour", "bun", "sandwich", "wrap", "pizza", "beer", "barley", "rye"]
        return glutenKeywords.contains { name.contains($0) || description.contains($0) }
    }
    
    private static func containsDairy(name: String, description: String) -> Bool {
        let dairyKeywords = ["cheese", "milk", "butter", "cream", "yogurt", "ice cream", "parmesan", "mozzarella", "cheddar"]
        return dairyKeywords.contains { name.contains($0) || description.contains($0) }
    }
    
    private static func containsNuts(name: String, description: String) -> Bool {
        let nutKeywords = ["almond", "peanut", "walnut", "pecan", "cashew", "pistachio", "hazelnut", "macadamia", "brazil nut"]
        return nutKeywords.contains { name.contains($0) || description.contains($0) }
    }
    
    private static func containsProcessedFoods(name: String, description: String) -> Bool {
        let processedKeywords = ["bread", "pasta", "rice", "potato", "bean", "grain", "cereal", "sugar", "corn"]
        return processedKeywords.contains { name.contains($0) || description.contains($0) }
    }
}