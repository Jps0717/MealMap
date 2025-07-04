import Foundation

// MARK: - Enhanced Food Text Cleaning with NLP-style Processing

class EnhancedFoodTextCleaner {
    
    // MARK: - Food Parsing Models
    
    struct CoreFoodTerms {
        let primaryFood: String        // Main ingredient: "chicken", "cheese", "salad"
        let modifiers: [String]        // Cooking methods: "grilled", "fresh", "aged"
        let accompaniments: [String]   // Side items: "rice", "bread", "sauce"
        let removedText: [String]      // Filtered out: prices, prefixes, etc.
        let confidence: Double         // Parsing confidence
    }
    
    // MARK: - Advanced Parsing Patterns
    
    private let pricePatterns = [
        "\\$?\\d+\\.?\\d*",           // $12.99, 12.99, 25
        "\\b\\d{1,2}\\b",             // Standalone numbers like 25, 28
        "\\d+\\s*oz",                 // 8 oz, 12oz
        "\\d+\\s*g\\b"                // 100g, 500 g
    ]
    
    private let prefixesToRemove = [
        "w/", "with", "includes", "served with", "comes with", "and",
        "fresh", "hot", "cold", "new", "signature", "house", "chef's"
    ]
    
    private let cookingMethods = [
        "grilled", "fried", "baked", "roasted", "steamed", "boiled", "sautéed",
        "blackened", "charred", "smoked", "barbecued", "crispy", "crunchy"
    ]
    
    private let coreProteinWords = [
        "chicken", "beef", "pork", "turkey", "fish", "salmon", "tuna", "shrimp",
        "lamb", "duck", "crab", "lobster", "scallops", "tofu", "tempeh"
    ]
    
    private let coreFoodWords = [
        // Dairy
        "cheese", "cheddar", "mozzarella", "parmesan", "goat cheese", "feta",
        "yogurt", "milk", "cream", "butter",
        
        // Vegetables
        "lettuce", "spinach", "arugula", "tomato", "onion", "mushroom",
        "pepper", "cucumber", "avocado", "broccoli", "carrot",
        
        // Grains & Starches
        "rice", "pasta", "bread", "potato", "quinoa", "couscous", "noodles",
        
        // Prepared Foods
        "salad", "soup", "sandwich", "burger", "pizza", "wrap", "bowl",
        "hummus", "guacamole", "salsa"
    ]
    
    private let accompanimentWords = [
        "sauce", "dressing", "mayo", "mustard", "ketchup", "aioli",
        "side", "fries", "chips", "crackers", "bread", "roll"
    ]
    
    // MARK: - Core Food Extraction
    
    func extractCoreFoodTerms(from text: String) -> CoreFoodTerms {
        debugLog("🧠 NLP: Parsing food text: '\(text)'")
        
        var workingText = text.lowercased()
        var removedItems: [String] = []
        
        // Step 1: Remove prices and numbers
        workingText = removePricesAndNumbers(from: workingText, removedItems: &removedItems)
        
        // Step 2: Remove prefixes and noise words
        workingText = removePrefixesAndNoise(from: workingText, removedItems: &removedItems)
        
        // Step 3: Extract cooking methods and modifiers
        let (cleanedText, modifiers) = extractModifiers(from: workingText)
        workingText = cleanedText
        
        // Step 4: Identify primary food and accompaniments
        let (primaryFood, accompaniments) = identifyPrimaryFoodAndAccompaniments(from: workingText)
        
        // Step 5: Calculate parsing confidence
        let confidence = calculateParsingConfidence(
            originalText: text,
            primaryFood: primaryFood,
            modifiers: modifiers,
            accompaniments: accompaniments
        )
        
        let result = CoreFoodTerms(
            primaryFood: primaryFood,
            modifiers: modifiers,
            accompaniments: accompaniments,
            removedText: removedItems,
            confidence: confidence
        )
        
        debugLog("🧠 NLP: Result - Primary: '\(primaryFood)', Modifiers: \(modifiers), Confidence: \(Int(confidence * 100))%")
        return result
    }
    
    // MARK: - Text Processing Steps
    
    private func removePricesAndNumbers(from text: String, removedItems: inout [String]) -> String {
        var cleanText = text
        
        for pattern in pricePatterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText))
            
            for match in matches.reversed() {
                let matchedText = String(cleanText[Range(match.range, in: cleanText)!])
                removedItems.append(matchedText)
                cleanText = cleanText.replacingCharacters(in: Range(match.range, in: cleanText)!, with: " ")
            }
        }
        
        return cleanText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func removePrefixesAndNoise(from text: String, removedItems: inout [String]) -> String {
        var cleanText = text
        
        for prefix in prefixesToRemove {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: prefix))\\b"
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            
            if regex.firstMatch(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText)) != nil {
                removedItems.append(prefix)
                cleanText = regex.stringByReplacingMatches(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText), withTemplate: " ")
            }
        }
        
        return cleanText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractModifiers(from text: String) -> (cleanedText: String, modifiers: [String]) {
        var cleanText = text
        var foundModifiers: [String] = []
        
        for method in cookingMethods {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: method))\\b"
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            
            if regex.firstMatch(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText)) != nil {
                foundModifiers.append(method)
                cleanText = regex.stringByReplacingMatches(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText), withTemplate: " ")
            }
        }
        
        return (
            cleanText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines),
            foundModifiers
        )
    }
    
    private func identifyPrimaryFoodAndAccompaniments(from text: String) -> (primaryFood: String, accompaniments: [String]) {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        // Strategy 1: Look for exact protein matches first
        for protein in coreProteinWords {
            if text.contains(protein) {
                let accompaniments = findAccompaniments(in: text, excluding: protein)
                return (protein, accompaniments)
            }
        }
        
        // Strategy 2: Look for exact core food matches
        for food in coreFoodWords {
            if text.contains(food) {
                let accompaniments = findAccompaniments(in: text, excluding: food)
                return (food, accompaniments)
            }
        }
        
        // Strategy 3: Multi-word food phrases (compound foods)
        let compoundFoods = findCompoundFoods(in: text)
        if !compoundFoods.isEmpty {
            let primaryFood = compoundFoods.first!
            let accompaniments = findAccompaniments(in: text, excluding: primaryFood)
            return (primaryFood, accompaniments)
        }
        
        // Strategy 4: First meaningful word as fallback
        let meaningfulWords = words.filter { word in
            !prefixesToRemove.contains(word) && 
            !cookingMethods.contains(word) &&
            word.count > 2
        }
        
        let primaryFood = meaningfulWords.first ?? text
        let accompaniments = findAccompaniments(in: text, excluding: primaryFood)
        
        return (primaryFood, accompaniments)
    }
    
    private func findCompoundFoods(in text: String) -> [String] {
        let compoundPatterns = [
            "caesar salad", "greek salad", "chicken sandwich", "turkey sandwich",
            "cheese burger", "veggie burger", "fish tacos", "chicken tacos",
            "chocolate chip", "peanut butter", "mac and cheese", "grilled cheese"
        ]
        
        var found: [String] = []
        for compound in compoundPatterns {
            if text.contains(compound) {
                found.append(compound)
            }
        }
        
        return found
    }
    
    private func findAccompaniments(in text: String, excluding primaryFood: String) -> [String] {
        var accompaniments: [String] = []
        
        for accompaniment in accompanimentWords {
            if text.contains(accompaniment) && accompaniment != primaryFood {
                accompaniments.append(accompaniment)
            }
        }
        
        return accompaniments
    }
    
    private func calculateParsingConfidence(
        originalText: String,
        primaryFood: String,
        modifiers: [String],
        accompaniments: [String]
    ) -> Double {
        var confidence: Double = 0.0
        
        // Base confidence for finding primary food
        if coreProteinWords.contains(primaryFood) || coreFoodWords.contains(primaryFood) {
            confidence += 0.6 // High confidence for known foods
        } else if primaryFood.count > 2 {
            confidence += 0.3 // Medium confidence for reasonable words
        }
        
        // Bonus for meaningful modifiers
        if !modifiers.isEmpty {
            confidence += 0.2
        }
        
        // Bonus for compound foods
        if findCompoundFoods(in: originalText).contains(primaryFood) {
            confidence += 0.2
        }
        
        // Penalty for very short or unclear extractions
        if primaryFood.count <= 2 {
            confidence -= 0.3
        }
        
        return max(0.0, min(1.0, confidence))
    }
    
    // MARK: - Cache Key Generation
    
    func createIngredientCacheKey(from primaryFood: String) -> String {
        return primaryFood.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
            .lowercased()
    }
    
    // MARK: - Legacy Compatibility
    
    func cleanFoodName(_ foodName: String) -> String {
        let coreTerms = extractCoreFoodTerms(from: foodName)
        return coreTerms.primaryFood
    }
    
    func extractSearchKeywords(from cleanedName: String) -> [String] {
        let coreTerms = extractCoreFoodTerms(from: cleanedName)
        return [coreTerms.primaryFood] + coreTerms.modifiers + coreTerms.accompaniments
    }
    
    func createCacheKey(from foodName: String) -> String {
        return createIngredientCacheKey(from: cleanFoodName(foodName))
    }
}