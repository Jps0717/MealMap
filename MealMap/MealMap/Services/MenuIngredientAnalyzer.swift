import Foundation

// MARK: - Ingredient Extraction and Nutrition Analysis
extension MenuOCRService {
    
    // MARK: - Ingredient Extraction
    func extractIngredients(from rawItem: RawMenuItem) async throws -> [IdentifiedIngredient] {
        let fullText = [rawItem.name, rawItem.description].compactMap { $0 }.joined(separator: " ")
        let lowercaseText = fullText.lowercased()
        
        var identifiedIngredients: [IdentifiedIngredient] = []
        
        // Use comprehensive ingredient database
        let ingredientMatches = IngredientDatabase.findIngredients(in: lowercaseText)
        
        for match in ingredientMatches {
            let ingredient = IdentifiedIngredient(
                name: match.name,
                category: match.category,
                confidence: match.confidence,
                nutritionContribution: calculateNutritionContribution(for: match)
            )
            identifiedIngredients.append(ingredient)
        }
        
        // Sort by confidence and limit results
        let sortedIngredients = identifiedIngredients
            .sorted { $0.confidence > $1.confidence }
            .prefix(MenuAnalysisConfig.maxIngredients)
        
        debugLog(" Found \(sortedIngredients.count) ingredients in '\(rawItem.name)'")
        return Array(sortedIngredients)
    }
    
    // MARK: - Nutrition Estimation
    func calculateNutritionEstimate(
        for ingredients: [IdentifiedIngredient],
        itemName: String
    ) -> NutritionEstimate {
        
        var totalCalories = NutritionRange(min: 0, max: 0, unit: "kcal")
        var totalCarbs = NutritionRange(min: 0, max: 0, unit: "g")
        var totalProtein = NutritionRange(min: 0, max: 0, unit: "g")
        var totalFat = NutritionRange(min: 0, max: 0, unit: "g")
        var totalFiber = NutritionRange(min: 0, max: 0, unit: "g")
        var totalSodium = NutritionRange(min: 0, max: 0, unit: "mg")
        var totalSugar = NutritionRange(min: 0, max: 0, unit: "g")
        var sourceDetails: String = ""
        
        var confidenceSum: Double = 0
        var portionMultiplier: Double = 1.0
        
        // Estimate portion size from item name and description
        portionMultiplier = estimatePortionMultiplier(from: itemName)
        
        // Sum up contributions from all ingredients
        for ingredient in ingredients {
            guard let contribution = ingredient.nutritionContribution else { continue }
            
            let weight = ingredient.confidence
            confidenceSum += weight
            
            totalCalories = addNutritionRanges(totalCalories, 
                NutritionRange(min: contribution.calories * 0.8, max: contribution.calories * 1.2, unit: "kcal"), 
                weight: weight)
            
            totalCarbs = addNutritionRanges(totalCarbs,
                NutritionRange(min: contribution.carbs * 0.7, max: contribution.carbs * 1.3, unit: "g"),
                weight: weight)
            
            totalProtein = addNutritionRanges(totalProtein,
                NutritionRange(min: contribution.protein * 0.8, max: contribution.protein * 1.2, unit: "g"),
                weight: weight)
            
            totalFat = addNutritionRanges(totalFat,
                NutritionRange(min: contribution.fat * 0.7, max: contribution.fat * 1.3, unit: "g"),
                weight: weight)
            
            sourceDetails += "\(ingredient.name) "
        }
        
        // Apply portion size multiplier
        totalCalories = multiplyNutritionRange(totalCalories, by: portionMultiplier)
        totalCarbs = multiplyNutritionRange(totalCarbs, by: portionMultiplier)
        totalProtein = multiplyNutritionRange(totalProtein, by: portionMultiplier)
        totalFat = multiplyNutritionRange(totalFat, by: portionMultiplier)
        
        // Estimate fiber and sodium based on ingredients
        totalFiber = estimateFiber(from: ingredients, portionMultiplier: portionMultiplier)
        totalSodium = estimateSodium(from: ingredients, itemName: itemName, portionMultiplier: portionMultiplier)
        totalSugar = estimateSugar(from: ingredients, portionMultiplier: portionMultiplier)
        
        let overallConfidence = confidenceSum > 0 ? min(confidenceSum / Double(ingredients.count), 1.0) : 0.3
        
        return NutritionEstimate(
            calories: totalCalories,
            carbs: totalCarbs,
            protein: totalProtein,
            fat: totalFat,
            fiber: totalFiber,
            sodium: totalSodium,
            sugar: totalSugar,
            confidence: overallConfidence,
            estimationSource: .ingredients,
            sourceDetails: sourceDetails,
            estimatedPortionSize: getPortionDescription(from: portionMultiplier),
            portionConfidence: 0.6
        )
    }
    
    // MARK: - Dietary Tag Determination
    func determineDietaryTags(
        ingredients: [IdentifiedIngredient],
        nutrition: NutritionEstimate
    ) -> [DietaryTag] {
        
        var tags: [DietaryTag] = []
        
        // Protein-based tags
        if nutrition.protein.average >= MenuAnalysisConfig.highProteinThreshold {
            tags.append(.highProtein)
        }
        
        // Carb-based tags
        if nutrition.carbs.average <= MenuAnalysisConfig.lowCarbThreshold {
            tags.append(.lowCarb)
        } else if nutrition.carbs.average >= MenuAnalysisConfig.highCarbThreshold {
            tags.append(.highCarb)
        }
        
        // Keto analysis
        let totalCalories = nutrition.calories.average
        let fatCalories = nutrition.fat.average * 9 // 9 calories per gram of fat
        if totalCalories > 0 && (fatCalories / totalCalories) >= MenuAnalysisConfig.ketoFatRatio {
            tags.append(.keto)
        }
        
        // Dietary restrictions
        let ingredientNames = ingredients.map { $0.name.lowercased() }
        
        // Vegan check
        let nonVeganIngredients = ["meat", "chicken", "beef", "pork", "fish", "cheese", "milk", "egg", "butter", "bacon", "ham"]
        if !ingredientNames.contains(where: { ingredient in
            nonVeganIngredients.contains { ingredient.contains($0) }
        }) {
            let veganIngredients = ["tofu", "tempeh", "quinoa", "beans", "lentils", "vegetables"]
            if ingredientNames.contains(where: { ingredient in
                veganIngredients.contains { ingredient.contains($0) }
            }) {
                tags.append(.vegan)
            }
        }
        
        // Vegetarian check (more lenient than vegan)
        let meatIngredients = ["meat", "chicken", "beef", "pork", "fish", "bacon", "ham", "sausage"]
        if !ingredientNames.contains(where: { ingredient in
            meatIngredients.contains { ingredient.contains($0) }
        }) {
            tags.append(.vegetarian)
        }
        
        // Gluten-free check
        let glutenIngredients = ["wheat", "bread", "pasta", "flour", "gluten", "barley", "rye"]
        if !ingredientNames.contains(where: { ingredient in
            glutenIngredients.contains { ingredient.contains($0) }
        }) {
            tags.append(.glutenFree)
        }
        
        // Health-based tags
        if let fiber = nutrition.fiber, fiber.average >= MenuAnalysisConfig.highFiberThreshold {
            tags.append(.highFiber)
        }
        
        if let sodium = nutrition.sodium, sodium.average <= MenuAnalysisConfig.lowSodiumThreshold {
            tags.append(.lowSodium)
        }
        
        if let sugar = nutrition.sugar, sugar.average <= 10.0 { // Low sugar threshold
            tags.append(.lowSugar)
        }
        
        // Overall health assessment
        let isHealthy = (nutrition.calories.average <= 600) &&
                       (nutrition.carbs.average <= 40) &&
                       (nutrition.protein.average >= 15) &&
                       tags.contains(.lowSodium)
        
        if isHealthy {
            tags.append(.healthy)
        } else if nutrition.calories.average > 800 {
            tags.append(.indulgent)
        }
        
        return tags
    }
    
    // MARK: - Helper Methods
    private func calculateNutritionContribution(for match: IngredientMatch) -> NutritionContribution? {
        return IngredientDatabase.getNutritionData(for: match.name)
    }
    
    private func estimatePortionMultiplier(from itemName: String) -> Double {
        let name = itemName.lowercased()
        
        // Size indicators
        if name.contains("large") || name.contains("big") || name.contains("jumbo") {
            return 1.5
        } else if name.contains("small") || name.contains("mini") || name.contains("lite") {
            return 0.7
        } else if name.contains("family") || name.contains("share") {
            return 2.5
        }
        
        // Item type multipliers
        if name.contains("appetizer") || name.contains("side") {
            return 0.6
        } else if name.contains("entree") || name.contains("main") {
            return 1.2
        } else if name.contains("dessert") {
            return 0.8
        }
        
        return 1.0 // Default serving
    }
    
    private func addNutritionRanges(_ range1: NutritionRange, _ range2: NutritionRange, weight: Double) -> NutritionRange {
        return NutritionRange(
            min: range1.min + (range2.min * weight),
            max: range1.max + (range2.max * weight),
            unit: range1.unit
        )
    }
    
    private func multiplyNutritionRange(_ range: NutritionRange, by multiplier: Double) -> NutritionRange {
        return NutritionRange(
            min: range.min * multiplier,
            max: range.max * multiplier,
            unit: range.unit
        )
    }
    
    private func estimateFiber(from ingredients: [IdentifiedIngredient], portionMultiplier: Double) -> NutritionRange {
        let fiberIngredients = ingredients.filter { 
            $0.category == .vegetable || $0.category == .fruit || $0.category == .grain 
        }
        let baseFiber = Double(fiberIngredients.count) * 2.0 // Rough estimate
        return NutritionRange(
            min: baseFiber * 0.5 * portionMultiplier,
            max: baseFiber * 1.5 * portionMultiplier,
            unit: "g"
        )
    }
    
    private func estimateSodium(from ingredients: [IdentifiedIngredient], itemName: String, portionMultiplier: Double) -> NutritionRange {
        let name = itemName.lowercased()
        var baseSodium: Double = 300 // Base sodium estimate
        
        // High sodium foods
        if name.contains("fried") || name.contains("pizza") || name.contains("burger") {
            baseSodium = 800
        } else if ingredients.contains(where: { $0.name.lowercased().contains("cheese") }) {
            baseSodium = 600
        } else if ingredients.contains(where: { $0.category == .sauce }) {
            baseSodium = 500
        }
        
        return NutritionRange(
            min: baseSodium * 0.7 * portionMultiplier,
            max: baseSodium * 1.3 * portionMultiplier,
            unit: "mg"
        )
    }
    
    private func estimateSugar(from ingredients: [IdentifiedIngredient], portionMultiplier: Double) -> NutritionRange {
        let sweetIngredients = ingredients.filter { 
            $0.name.lowercased().contains("sugar") || 
            $0.name.lowercased().contains("honey") ||
            $0.category == .fruit
        }
        let baseSugar = Double(sweetIngredients.count) * 8.0 + 5.0 // Base sugar + sweet ingredients
        return NutritionRange(
            min: baseSugar * 0.6 * portionMultiplier,
            max: baseSugar * 1.4 * portionMultiplier,
            unit: "g"
        )
    }
    
    private func getPortionDescription(from multiplier: Double) -> String {
        switch multiplier {
        case 0.0..<0.8:
            return "Small portion"
        case 0.8..<1.2:
            return "Regular portion"
        case 1.2..<1.8:
            return "Large portion"
        default:
            return "Extra large portion"
        }
    }
    
    // MARK: - ENHANCED: Three-tier nutrition estimation system
    func analyzeMenuItemWithFallback(from rawItem: RawMenuItem) async throws -> AnalyzedMenuItem {
        debugLog(" Analyzing item: '\(rawItem.name)' with fallback system")
        
        // TIER 1: Try ingredient-based analysis first (highest confidence)
        let ingredients = try await extractIngredients(from: rawItem)
        
        if !ingredients.isEmpty && ingredients.contains(where: { $0.confidence > 0.5 }) {
            debugLog(" Tier 1: Using ingredient-based analysis for '\(rawItem.name)'")
            return try await createIngredientBasedAnalysis(rawItem: rawItem, ingredients: ingredients)
        }
        
        // TIER 2: Fallback to USDA database lookup (medium confidence)
        debugLog(" Tier 2: Attempting USDA fallback for '\(rawItem.name)'")
        if let usdaEstimate = try? await USDAFoodDataService.shared.searchNutritionByName(rawItem.name) {
            debugLog(" USDA estimate found for '\(rawItem.name)'")
            return AnalyzedMenuItem.createWithUSDA(
                name: rawItem.name,
                description: rawItem.description,
                price: rawItem.price,
                usdaEstimate: usdaEstimate,
                textBounds: rawItem.bounds
            )
        }
        
        // TIER 3: No nutrition data available (lowest confidence)
        debugLog(" Tier 3: No nutrition data available for '\(rawItem.name)'")
        return AnalyzedMenuItem.createUnavailable(
            name: rawItem.name,
            description: rawItem.description,
            price: rawItem.price,
            textBounds: rawItem.bounds
        )
    }
    
    // MARK: - Original ingredient-based analysis (Tier 1)
    private func createIngredientBasedAnalysis(
        rawItem: RawMenuItem,
        ingredients: [IdentifiedIngredient]
    ) async throws -> AnalyzedMenuItem {
        let nutritionEstimate = calculateNutritionEstimate(
            for: ingredients,
            itemName: rawItem.name
        )
        
        let dietaryTags = determineDietaryTags(
            ingredients: ingredients,
            nutrition: nutritionEstimate
        )
        
        return AnalyzedMenuItem.createWithIngredients(
            name: rawItem.name,
            description: rawItem.description,
            price: rawItem.price,
            ingredients: ingredients,
            nutritionEstimate: nutritionEstimate,
            dietaryTags: dietaryTags,
            confidence: nutritionEstimate.confidence,
            textBounds: rawItem.bounds
        )
    }
    
    // MARK: - Enhanced Menu Analysis Batch Processing
    func analyzeMenuItemsBatch(_ rawItems: [RawMenuItem]) async throws -> [AnalyzedMenuItem] {
        debugLog(" Starting batch analysis of \(rawItems.count) items with USDA fallback")
        
        var analyzedItems: [AnalyzedMenuItem] = []
        var tierCounts = [EstimationTier: Int]()
        
        // Process items with concurrency control to avoid overwhelming USDA API
        for rawItem in rawItems {
            let analyzedItem = try await analyzeMenuItemWithFallback(from: rawItem)
            analyzedItems.append(analyzedItem)
            
            // Track tier usage
            tierCounts[analyzedItem.estimationTier, default: 0] += 1
            
            // Add small delay to avoid rate limiting USDA API
            if analyzedItem.estimationTier == .usda {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            }
        }
        
        // Log analysis summary
        debugLog(" Batch analysis complete:")
        debugLog("    Tier 1 (Ingredients): \(tierCounts[.ingredients] ?? 0)")
        debugLog("    Tier 2 (USDA): \(tierCounts[.usda] ?? 0)")
        debugLog("    Tier 3 (Unavailable): \(tierCounts[.unavailable] ?? 0)")
        
        return analyzedItems
    }
}