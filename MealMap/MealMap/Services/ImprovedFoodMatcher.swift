import Foundation

// MARK: - Improved Food Matching with Enhanced Scoring

class ImprovedFoodMatcher {
    
    private let textCleaner = EnhancedFoodTextCleaner()
    
    // MARK: - Enhanced Match Scoring
    
    func calculateMatchScore(
        productName: String,
        coreFood: EnhancedFoodTextCleaner.CoreFoodTerms,
        originalName: String
    ) -> Double {
        let productNameLower = productName.lowercased()
        var score: Double = 0.0
        
        debugLog("🎯 Scoring: '\(productName)' vs core food: '\(coreFood.primaryFood)'")
        
        // 1. Exact primary food match (50% of score) - Most important
        let primaryFoodScore = calculatePrimaryFoodMatch(productNameLower, coreFood.primaryFood)
        score += primaryFoodScore * 0.5
        debugLog("   Primary food score: \(String(format: "%.2f", primaryFoodScore))")
        
        // 2. Modifier relevance (20% of score)
        let modifierScore = calculateModifierRelevance(productNameLower, coreFood.modifiers)
        score += modifierScore * 0.2
        debugLog("   Modifier score: \(String(format: "%.2f", modifierScore))")
        
        // 3. Category consistency (20% of score)
        let categoryScore = calculateCategoryConsistency(productNameLower, coreFood)
        score += categoryScore * 0.2
        debugLog("   Category score: \(String(format: "%.2f", categoryScore))")
        
        // 4. Penalty for irrelevant matches (10% of score)
        let relevancePenalty = calculateIrrelevancePenalty(productNameLower, coreFood)
        score += relevancePenalty * 0.1
        debugLog("   Relevance penalty: \(String(format: "%.2f", relevancePenalty))")
        
        // 5. Apply parsing confidence multiplier
        score *= coreFood.confidence
        
        let finalScore = max(0.0, min(1.0, score))
        debugLog("🎯 Final score: \(String(format: "%.2f", finalScore)) for '\(productName)'")
        
        return finalScore
    }
    
    // MARK: - Scoring Components
    
    private func calculatePrimaryFoodMatch(_ productName: String, _ primaryFood: String) -> Double {
        // Exact match gets highest score
        if productName.contains(primaryFood) {
            // Check if it's a word boundary match (not substring)
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: primaryFood))\\b"
            if productName.range(of: pattern, options: .regularExpression) != nil {
                return 1.0 // Perfect match
            } else {
                return 0.8 // Substring match
            }
        }
        
        // Check for related food terms
        let relatedTerms = getRelatedFoodTerms(for: primaryFood)
        for term in relatedTerms {
            if productName.contains(term) {
                return 0.6 // Related match
            }
        }
        
        // Fuzzy string similarity as fallback
        let similarity = calculateStringSimilarity(productName, primaryFood)
        return similarity * 0.4 // Lower weight for fuzzy matches
    }
    
    private func calculateModifierRelevance(_ productName: String, _ modifiers: [String]) -> Double {
        guard !modifiers.isEmpty else { return 0.5 } // Neutral if no modifiers
        
        var relevantModifiers = 0
        for modifier in modifiers {
            if productName.contains(modifier) || 
               productName.contains(getRelatedModifier(modifier)) {
                relevantModifiers += 1
            }
        }
        
        return Double(relevantModifiers) / Double(modifiers.count)
    }
    
    private func calculateCategoryConsistency(_ productName: String, _ coreFood: EnhancedFoodTextCleaner.CoreFoodTerms) -> Double {
        let expectedCategory = inferFoodCategory(from: coreFood.primaryFood)
        let productCategory = inferFoodCategory(from: productName)
        
        if expectedCategory == productCategory {
            return 1.0 // Perfect category match
        } else if areRelatedCategories(expectedCategory, productCategory) {
            return 0.6 // Related categories
        } else {
            return 0.0 // Unrelated categories
        }
    }
    
    private func calculateIrrelevancePenalty(_ productName: String, _ coreFood: EnhancedFoodTextCleaner.CoreFoodTerms) -> Double {
        // Check for completely irrelevant products
        let irrelevantKeywords = [
            "chocolate", "candy", "dessert", "cake", "cookie", "ice cream",
            "soda", "juice", "beverage", "drink", "alcohol", "wine", "beer"
        ]
        
        // If looking for savory food but product is sweet
        if !isSweetFood(coreFood.primaryFood) {
            for keyword in irrelevantKeywords {
                if productName.contains(keyword) {
                    return -0.8 // Heavy penalty for completely wrong category
                }
            }
        }
        
        return 0.0 // No penalty
    }
    
    // MARK: - Helper Methods
    
    private func getRelatedFoodTerms(for food: String) -> [String] {
        let foodRelations: [String: [String]] = [
            "chicken": ["poultry", "fowl", "bird"],
            "beef": ["meat", "steak", "burger", "cow"],
            "fish": ["seafood", "salmon", "tuna", "cod"],
            "cheese": ["dairy", "cheddar", "mozzarella", "parmesan"],
            "salad": ["lettuce", "greens", "vegetable", "leaves"],
            "bread": ["bakery", "wheat", "grain", "baked"],
            "rice": ["grain", "cereal", "carbohydrate"]
        ]
        
        return foodRelations[food] ?? []
    }
    
    private func getRelatedModifier(_ modifier: String) -> String {
        let modifierMappings: [String: String] = [
            "grilled": "barbecued",
            "fried": "crispy",
            "baked": "roasted",
            "fresh": "organic"
        ]
        
        return modifierMappings[modifier] ?? modifier
    }
    
    private func inferFoodCategory(from text: String) -> String {
        let categoryKeywords: [String: [String]] = [
            "protein": ["chicken", "beef", "fish", "meat", "seafood", "poultry"],
            "dairy": ["cheese", "milk", "yogurt", "cream", "butter"],
            "vegetable": ["salad", "lettuce", "tomato", "vegetable", "greens"],
            "grain": ["bread", "rice", "pasta", "wheat", "cereal"],
            "snack": ["chips", "crackers", "nuts"],
            "sweet": ["chocolate", "candy", "dessert", "cake", "cookie"]
        ]
        
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if text.contains(keyword) {
                    return category
                }
            }
        }
        
        return "unknown"
    }
    
    private func areRelatedCategories(_ cat1: String, _ cat2: String) -> Bool {
        let relatedPairs: Set<Set<String>> = [
            Set(["protein", "meat"]),
            Set(["vegetable", "salad"]),
            Set(["grain", "bread"]),
            Set(["dairy", "cheese"])
        ]
        
        return relatedPairs.contains(Set([cat1, cat2]))
    }
    
    private func isSweetFood(_ food: String) -> Bool {
        let sweetFoods = ["chocolate", "candy", "dessert", "cake", "cookie", "ice cream", "fruit"]
        return sweetFoods.contains { food.contains($0) }
    }
    
    private func calculateStringSimilarity(_ string1: String, _ string2: String) -> Double {
        let distance = levenshteinDistance(string1, string2)
        let maxLength = max(string1.count, string2.count)
        
        guard maxLength > 0 else { return 1.0 }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    private func levenshteinDistance(_ string1: String, _ string2: String) -> Int {
        let s1 = Array(string1)
        let s2 = Array(string2)
        
        let m = s1.count
        let n = s2.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            matrix[i][0] = i
        }
        
        for j in 0...n {
            matrix[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1[i - 1] == s2[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
}