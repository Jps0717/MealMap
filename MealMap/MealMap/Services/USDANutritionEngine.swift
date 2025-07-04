import Foundation

// MARK: - USDA-Only Nutrition Engine
@MainActor
class USDANutritionEngine: ObservableObject {
    static let shared = USDANutritionEngine()
    
    private let session = URLSession.shared
    private let cache = USDAEngineFileCache()
    private let cleaner = USDAMenuItemCleaner()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Main entry point: Process raw menu item and return USDA-based nutrition
    func analyzeMenuItem(_ rawName: String) async throws -> USDAEngineMenuItem {
        debugLog("Analyzing menu item: '\(rawName)'")
        
        // Step 1: Clean and normalize the menu item name
        let cleanedNames = cleaner.cleanMenuItem(rawName)
        
        guard !cleanedNames.isEmpty else {
            debugLog("No valid names after cleaning: '\(rawName)'")
            return USDAEngineMenuItem.unavailable(originalName: rawName)
        }
        
        // Step 2: Try USDA lookup for each cleaned name
        for cleanedName in cleanedNames {
            if let result = try? await fetchUSDANutrition(cleanedName: cleanedName, originalName: rawName) {
                return result
            }
        }
        
        debugLog("No USDA matches found for: \(cleanedNames)")
        return USDAEngineMenuItem.unavailable(originalName: rawName)
    }
    
    /// Enhanced menu item analysis using intelligent fuzzy matching
    func analyzeMenuItemIntelligent(_ rawName: String) async throws -> AnalyzedMenuItem {
        debugLog("Starting intelligent analysis for: '\(rawName)'")
        
        // Step 1: Clean and preprocess the menu item name
        let cleanedNames = cleaner.cleanMenuItem(rawName)
        
        guard let primaryName = cleanedNames.first else {
            debugLog("No valid names after cleaning: '\(rawName)'")
            return AnalyzedMenuItem.createUnavailable(
                name: rawName,
                description: nil,
                price: nil,
                textBounds: nil
            )
        }
        
        // Step 2: Use intelligent matcher for fuzzy USDA matching
        do {
            let intelligentResult = try await USDAIntelligentMatcher.shared.findBestNutritionMatch(for: primaryName)
            
            if intelligentResult.isAvailable {
                // Create enhanced item with intelligent matching data
                return AnalyzedMenuItem.createWithIntelligentUSDA(
                    name: rawName,
                    description: nil,
                    price: nil,
                    intelligentResult: intelligentResult,
                    textBounds: nil
                )
            } else {
                // Create unavailable item
                return AnalyzedMenuItem.createUnavailable(
                    name: rawName,
                    description: nil,
                    price: nil,
                    textBounds: nil
                )
            }
        } catch {
            debugLog("Intelligent analysis failed: \(error)")
            return AnalyzedMenuItem.createUnavailable(
                name: rawName,
                description: nil,
                price: nil,
                textBounds: nil
            )
        }
    }
    
    // MARK: - USDA API Integration
    
    private func fetchUSDANutrition(cleanedName: String, originalName: String) async throws -> USDAEngineMenuItem {
        // Check cache first
        if let cached = await cache.getCachedItem(for: cleanedName) {
            debugLog("Cache hit for: '\(cleanedName)'")
            return cached
        }
        
        // Rate limiting using shared service
        await USDASharedRateLimit.shared.enforceRateLimit()
        
        // Search USDA database
        let searchResults = try await searchUSDAFoods(query: cleanedName)
        
        guard !searchResults.foods.isEmpty else {
            let result = USDAEngineMenuItem.unavailable(originalName: originalName)
            await cache.cacheItem(result, for: cleanedName)
            return result
        }
        
        // Get nutrition for top matches (up to 3)
        let topMatches = Array(searchResults.foods.prefix(3))
        var nutritionData: [USDAEngineBasicNutrition] = []
        
        for food in topMatches {
            do {
                await USDASharedRateLimit.shared.enforceRateLimit()
                let nutrition = try await fetchFoodDetails(fdcId: food.fdcId)
                nutritionData.append(nutrition)
            } catch {
                debugLog("Failed to fetch details for FDC ID \(food.fdcId): \(error)")
                continue
            }
        }
        
        guard !nutritionData.isEmpty else {
            let result = USDAEngineMenuItem.unavailable(originalName: originalName)
            await cache.cacheItem(result, for: cleanedName)
            return result
        }
        
        // Calculate nutrition range
        let result = createUSDAEngineMenuItem(
            from: nutritionData,
            cleanedName: cleanedName,
            originalName: originalName
        )
        
        // Cache the result
        await cache.cacheItem(result, for: cleanedName)
        
        debugLog("USDA nutrition found for '\(cleanedName)': \(Int(result.nutrition.calories.average))cal")
        return result
    }
    
    private func searchUSDAFoods(query: String) async throws -> USDASearchResponse {
        guard let url = USDAAPIHelper.createSearchURL(query: query) else {
            throw USDAError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw USDAError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw USDAError.rateLimitExceeded
            }
            throw USDAError.apiError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(USDASearchResponse.self, from: data)
    }
    
    private func fetchFoodDetails(fdcId: Int) async throws -> USDAEngineBasicNutrition {
        guard let url = USDAAPIHelper.createFoodDetailURL(fdcId: fdcId) else {
            throw USDAError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw USDAError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw USDAError.apiError(httpResponse.statusCode)
        }
        
        let foodDetail = try JSONDecoder().decode(USDAFoodDetail.self, from: data)
        return extractBasicNutrition(from: foodDetail)
    }
    
    private func extractBasicNutrition(from detail: USDAFoodDetail) -> USDAEngineBasicNutrition {
        var calories: Double = 0
        var carbs: Double = 0
        var sugar: Double = 0
        var protein: Double = 0
        var fat: Double = 0
        
        for nutrient in detail.foodNutrients {
            switch nutrient.nutrient.number {
            case "208": calories = nutrient.amount ?? 0    // Energy (kcal)
            case "205": carbs = nutrient.amount ?? 0       // Carbohydrate
            case "269": sugar = nutrient.amount ?? 0       // Sugars, total
            case "203": protein = nutrient.amount ?? 0     // Protein
            case "204": fat = nutrient.amount ?? 0         // Total lipid (fat)
            default: break
            }
        }
        
        return USDAEngineBasicNutrition(
            calories: calories,
            carbs: carbs,
            sugar: sugar,
            protein: protein,
            fat: fat
        )
    }
    
    private func createUSDAEngineMenuItem(
        from nutritionData: [USDAEngineBasicNutrition],
        cleanedName: String,
        originalName: String
    ) -> USDAEngineMenuItem {
        
        let calories = nutritionData.map { $0.calories }
        let carbs = nutritionData.map { $0.carbs }
        let sugar = nutritionData.map { $0.sugar }
        let protein = nutritionData.map { $0.protein }
        let fat = nutritionData.map { $0.fat }
        
        let nutrition = USDAEngineNutrition(
            calories: NutritionRange(min: calories.min() ?? 0, max: calories.max() ?? 0, unit: "kcal"),
            carbs: NutritionRange(min: carbs.min() ?? 0, max: carbs.max() ?? 0, unit: "g"),
            sugar: NutritionRange(min: sugar.min() ?? 0, max: sugar.max() ?? 0, unit: "g"),
            protein: NutritionRange(min: protein.min() ?? 0, max: protein.max() ?? 0, unit: "g"),
            fat: NutritionRange(min: fat.min() ?? 0, max: fat.max() ?? 0, unit: "g")
        )
        
        let confidence = calculateConfidence(matchCount: nutritionData.count, cleanedName: cleanedName)
        
        return USDAEngineMenuItem(
            originalName: originalName,
            cleanedName: cleanedName,
            nutrition: nutrition,
            confidence: confidence,
            matchCount: nutritionData.count,
            isGeneralEstimate: true,
            isAvailable: true
        )
    }
    
    private func calculateConfidence(matchCount: Int, cleanedName: String) -> Double {
        var baseConfidence: Double = 0.5
        
        // Confidence based on match count
        switch matchCount {
        case 3...: baseConfidence = 0.7
        case 2: baseConfidence = 0.6
        case 1: baseConfidence = 0.5
        default: baseConfidence = 0.3
        }
        
        // Boost for common foods
        let commonFoods = ["chicken", "beef", "fish", "rice", "pasta", "salad", "pizza", "burger", "sandwich", "tart", "tiramisu"]
        if commonFoods.contains(where: { cleanedName.contains($0) }) {
            baseConfidence += 0.1
        }
        
        return min(baseConfidence, 0.8) // Cap at 80%
    }
}

// MARK: - Menu Item Cleaner (Engine-specific)
class USDAMenuItemCleaner {
    
    private let aliases: [String: String] = [
        // Italian specialties
        "crostatine": "tart",
        "tiramisu tradizionale": "tiramisu",
        "bruschette": "bruschetta",
        "antipasti": "appetizer",
        
        // Common abbreviations
        "chx": "chicken",
        "chk": "chicken",
        "ckn": "chicken",
        "w/": "",
        "fries": "french fries",
        
        // OCR corrections
        "chickne": "chicken",
        "saiad": "salad",
        "burgre": "burger",
        "pizzza": "pizza"
    ]
    
    func cleanMenuItem(_ rawName: String) -> [String] {
        debugLog("Cleaning menu item: '\(rawName)'")
        
        // Step 1: Split composite items
        let splitItems = splitCompositeItems(rawName)
        
        // Step 2: Clean each item
        var cleanedNames: [String] = []
        for item in splitItems {
            if let cleaned = cleanSingleItem(item) {
                cleanedNames.append(cleaned)
            }
        }
        
        // Step 3: Remove duplicates and sort by preference
        let uniqueNames = Array(Set(cleanedNames)).sorted { name1, name2 in
            // Prefer longer, more descriptive names
            return name1.count > name2.count
        }
        
        debugLog("Cleaned names: \(uniqueNames)")
        return uniqueNames
    }
    
    private func splitCompositeItems(_ rawName: String) -> [String] {
        // Handle patterns like "w/Hummus 25 | w/Chicken 28"
        let separators = ["|", "/", " or ", " OR ", " & ", " and "]
        var items = [rawName]
        
        for separator in separators {
            var newItems: [String] = []
            for item in items {
                newItems.append(contentsOf: item.components(separatedBy: separator))
            }
            items = newItems
        }
        
        return items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    private func cleanSingleItem(_ rawItem: String) -> String? {
        var cleaned = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Step 1: Remove pricing and numbers
        cleaned = removePricing(from: cleaned)
        
        // Step 2: Remove prefixes and suffixes
        cleaned = removePrefixesAndSuffixes(from: cleaned)
        
        // Step 3: Clean OCR errors
        cleaned = cleanOCRErrors(from: cleaned)
        
        // Step 4: Apply aliases
        cleaned = applyAliases(to: cleaned)
        
        // Step 5: Final validation
        guard isValidFoodName(cleaned) else {
            debugLog("Invalid after cleaning: '\(cleaned)'")
            return nil
        }
        
        return cleaned.lowercased()
    }
    
    private func removePricing(from text: String) -> String {
        // Remove currency and standalone numbers
        let patterns = [
            #"\$\d+\.?\d*"#,           // $12.99, $12
            #"\b\d{1,3}\.?\d{0,2}\b"#  // 25, 28.50 (but not 1000+)
        ]
        
        var result = text
        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func removePrefixesAndSuffixes(from text: String) -> String {
        let prefixesToRemove = [
            "w/", "with", "includes", "served with", "topped with",
            "add", "extra", "side of", "choice of", "fresh"
        ]
        
        var result = text.lowercased()
        
        for prefix in prefixesToRemove {
            if result.hasPrefix(prefix + " ") {
                result = String(result.dropFirst(prefix.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return result
    }
    
    private func cleanOCRErrors(from text: String) -> String {
        var result = text
        
        // Remove non-alphabetic characters except spaces and hyphens
        result = result.replacingOccurrences(
            of: #"[^a-zA-Z\s\-']"#,
            with: "",
            options: .regularExpression
        )
        
        // Clean up multiple spaces
        result = result.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func applyAliases(to text: String) -> String {
        let lowercased = text.lowercased()
        
        // Direct alias match
        if let standardName = aliases[lowercased] {
            return standardName
        }
        
        // Partial match for longer names
        for (alias, standard) in aliases {
            if lowercased.contains(alias) && alias.count > 2 {
                return lowercased.replacingOccurrences(of: alias, with: standard)
            }
        }
        
        return text
    }
    
    private func isValidFoodName(_ name: String) -> Bool {
        // Must be at least 4 characters and contain letters
        guard name.count >= 4 else { return false }
        guard name.rangeOfCharacter(from: .letters) != nil else { return false }
        
        // Reject common OCR garbage
        let garbagePatterns = ["ddar", "ing", "tion", "xxx", "yyy", "zzz"]
        for pattern in garbagePatterns {
            if name.lowercased().contains(pattern) { return false }
        }
        
        return true
    }
}

// MARK: - Data Models (Engine-specific)

struct USDAEngineMenuItem: Codable {
    let originalName: String
    let cleanedName: String
    let nutrition: USDAEngineNutrition
    let confidence: Double
    let matchCount: Int
    let isGeneralEstimate: Bool
    let isAvailable: Bool
    let timestamp: Date = Date()
    
    static func unavailable(originalName: String) -> USDAEngineMenuItem {
        return USDAEngineMenuItem(
            originalName: originalName,
            cleanedName: "",
            nutrition: USDAEngineNutrition.empty,
            confidence: 0.0,
            matchCount: 0,
            isGeneralEstimate: false,
            isAvailable: false
        )
    }
}

struct USDAEngineNutrition: Codable {
    let calories: NutritionRange
    let carbs: NutritionRange
    let sugar: NutritionRange
    let protein: NutritionRange
    let fat: NutritionRange
    
    static let empty = USDAEngineNutrition(
        calories: NutritionRange(min: 0, max: 0, unit: "kcal"),
        carbs: NutritionRange(min: 0, max: 0, unit: "g"),
        sugar: NutritionRange(min: 0, max: 0, unit: "g"),
        protein: NutritionRange(min: 0, max: 0, unit: "g"),
        fat: NutritionRange(min: 0, max: 0, unit: "g")
    )
}

struct USDAEngineBasicNutrition: Codable {
    let calories: Double
    let carbs: Double
    let sugar: Double
    let protein: Double
    let fat: Double
}

// MARK: - File-based Cache (Engine-specific)
actor USDAEngineFileCache {
    private let cacheDirectory: URL
    private let cacheExpiry: TimeInterval = 24 * 60 * 60 * 7 // 7 days
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("USDAEngineCache")
        
        // Create cache directory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getCachedItem(for cleanedName: String) -> USDAEngineMenuItem? {
        let fileName = cleanedName.replacingOccurrences(of: " ", with: "_") + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let item = try? JSONDecoder().decode(USDAEngineMenuItem.self, from: data) else { return nil }
        
        // Check expiry
        if Date().timeIntervalSince(item.timestamp) > cacheExpiry {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        
        return item
    }
    
    func cacheItem(_ item: USDAEngineMenuItem, for cleanedName: String) {
        let fileName = cleanedName.replacingOccurrences(of: " ", with: "_") + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? JSONEncoder().encode(item) else { return }
        try? data.write(to: fileURL)
    }
}