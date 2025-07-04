import Foundation

// MARK: - USDA-Only Nutrition Estimation Service
@MainActor
class USDAOnlyNutritionService: ObservableObject {
    static let shared = USDAOnlyNutritionService()
    
    private let session = URLSession.shared
    private let cache = USDAOnlyServiceDiskCache()
    private let aliasMapper = USDAOnlyFoodAliasMapper()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Main entry point: Process raw menu item name and return nutrition estimate
    func estimateNutrition(for rawItemName: String) async throws -> USDAOnlyServiceNutritionResult {
        debugLog(" Starting USDA estimation for: '\(rawItemName)'")
        
        // Step 1: Preprocess and clean the menu item name
        let cleanedNames = preprocessMenuItemName(rawItemName)
        
        guard !cleanedNames.isEmpty else {
            debugLog(" No valid food names after preprocessing: '\(rawItemName)'")
            return USDAOnlyServiceNutritionResult.unavailable(originalName: rawItemName)
        }
        
        // Step 2: Try to get nutrition for the best cleaned name
        for cleanedName in cleanedNames {
            if let result = try? await fetchNutritionFromUSDA(cleanedName: cleanedName, originalName: rawItemName) {
                return result
            }
        }
        
        debugLog(" No USDA matches found for any cleaned names: \(cleanedNames)")
        return USDAOnlyServiceNutritionResult.unavailable(originalName: rawItemName)
    }
    
    // MARK: - Menu Item Name Preprocessing Pipeline
    
    private func preprocessMenuItemName(_ rawName: String) -> [String] {
        debugLog(" Preprocessing: '\(rawName)'")
        
        var cleanedNames: [String] = []
        
        // Step 1: Handle combined options (e.g., "w/Hummus 25 | w/Chicken 28")
        let splitItems = splitCombinedOptions(rawName)
        
        for item in splitItems {
            if let cleanedName = cleanSingleMenuItem(item) {
                cleanedNames.append(cleanedName)
            }
        }
        
        // Step 2: Remove duplicates and sort by preference
        let uniqueNames = Array(Set(cleanedNames)).sorted { name1, name2 in
            // Prefer longer, more descriptive names
            return name1.count > name2.count
        }
        
        debugLog(" Cleaned names: \(uniqueNames)")
        return uniqueNames
    }
    
    private func splitCombinedOptions(_ rawName: String) -> [String] {
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
    
    private func cleanSingleMenuItem(_ rawItem: String) -> String? {
        var cleaned = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Step 1: Remove pricing patterns
        cleaned = removePricing(from: cleaned)
        
        // Step 2: Remove prefixes and suffixes
        cleaned = removePrefixesAndSuffixes(from: cleaned)
        
        // Step 3: Clean OCR errors and validate
        cleaned = cleanOCRErrors(from: cleaned)
        
        // Step 4: Apply known food aliases
        cleaned = aliasMapper.mapToStandardName(cleaned)
        
        // Step 5: Final validation
        guard isValidFoodName(cleaned) else {
            debugLog(" Invalid food name after cleaning: '\(cleaned)'")
            return nil
        }
        
        return cleaned.lowercased()
    }
    
    private func removePricing(from text: String) -> String {
        // Remove currency and numbers: "$12.99", "25", "28.50"
        let pricePatterns = [
            #"\$\d+\.?\d*"#,           // $12.99, $12
            #"\b\d{1,3}\.?\d{0,2}\b"#  // 25, 28.50 (but not 1000+)
        ]
        
        var result = text
        for pattern in pricePatterns {
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
            "add", "extra", "side of", "choice of", "option of"
        ]
        
        let suffixesToRemove = [
            "available", "option", "choice", "extra", "add-on"
        ]
        
        var result = text.lowercased()
        
        // Remove prefixes
        for prefix in prefixesToRemove {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove suffixes
        for suffix in suffixesToRemove {
            if result.hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return result
    }
    
    private func cleanOCRErrors(from text: String) -> String {
        var result = text
        
        // Remove non-alphabetic junk (but keep spaces and common punctuation)
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
    
    private func isValidFoodName(_ name: String) -> Bool {
        // Must be at least 4 characters and contain letters
        guard name.count >= 4 else { return false }
        guard name.rangeOfCharacter(from: .letters) != nil else { return false }
        
        // Reject common OCR errors
        let invalidPatterns = ["ddar", "ing", "tion", "xxx", "yyy", "zzz"]
        for pattern in invalidPatterns {
            if name.contains(pattern) { return false }
        }
        
        return true
    }
    
    // MARK: - USDA API Integration
    
    private func fetchNutritionFromUSDA(cleanedName: String, originalName: String) async throws -> USDAOnlyServiceNutritionResult {
        // Check cache first
        if let cachedResult = await cache.getCachedResult(for: cleanedName) {
            debugLog(" Cache hit for: '\(cleanedName)'")
            return cachedResult
        }
        
        // Rate limiting using shared service
        await USDASharedRateLimit.shared.enforceRateLimit()
        
        // Search USDA database using shared helper
        let searchResults = try await searchUSDAFoods(query: cleanedName)
        
        guard !searchResults.foods.isEmpty else {
            let result = USDAOnlyServiceNutritionResult.unavailable(originalName: originalName)
            await cache.cacheResult(result, for: cleanedName)
            return result
        }
        
        // Get nutrition details for top matches (up to 3)
        let topMatches = Array(searchResults.foods.prefix(3))
        var nutritionData: [USDAOnlyServiceBasicNutrition] = []
        
        for food in topMatches {
            do {
                await USDASharedRateLimit.shared.enforceRateLimit()
                let nutrition = try await fetchFoodDetails(fdcId: food.fdcId)
                nutritionData.append(nutrition)
            } catch {
                debugLog(" Failed to fetch details for FDC ID \(food.fdcId): \(error)")
                continue
            }
        }
        
        guard !nutritionData.isEmpty else {
            let result = USDAOnlyServiceNutritionResult.unavailable(originalName: originalName)
            await cache.cacheResult(result, for: cleanedName)
            return result
        }
        
        // Calculate nutrition range from matches
        let result = calculateNutritionRange(
            from: nutritionData,
            cleanedName: cleanedName,
            originalName: originalName,
            matchCount: nutritionData.count
        )
        
        // Cache the result
        await cache.cacheResult(result, for: cleanedName)
        
        debugLog(" USDA estimate complete for '\(cleanedName)': \(Int(result.calories.average))cal")
        return result
    }
    
    private func searchUSDAFoods(query: String) async throws -> USDASearchResponse {
        guard let url = USDAAPIHelper.createSearchURL(query: query, pageSize: 25) else {
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
        
        do {
            let searchResponse = try JSONDecoder().decode(USDASearchResponse.self, from: data)
            return searchResponse
        } catch {
            debugLog(" USDA decode error: \(error)")
            throw USDAError.decodingError(error)
        }
    }
    
    private func fetchFoodDetails(fdcId: Int) async throws -> USDAOnlyServiceBasicNutrition {
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
        
        do {
            let foodDetail = try JSONDecoder().decode(USDAFoodDetail.self, from: data)
            return extractBasicNutrition(from: foodDetail)
        } catch {
            debugLog(" USDA detail decode error: \(error)")
            throw USDAError.decodingError(error)
        }
    }
    
    private func extractBasicNutrition(from detail: USDAFoodDetail) -> USDAOnlyServiceBasicNutrition {
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
        
        return USDAOnlyServiceBasicNutrition(
            calories: calories,
            carbs: carbs,
            sugar: sugar,
            protein: protein,
            fat: fat
        )
    }
    
    private func calculateNutritionRange(
        from nutritionData: [USDAOnlyServiceBasicNutrition],
        cleanedName: String,
        originalName: String,
        matchCount: Int
    ) -> USDAOnlyServiceNutritionResult {
        
        let calories = nutritionData.map { $0.calories }
        let carbs = nutritionData.map { $0.carbs }
        let sugar = nutritionData.map { $0.sugar }
        let protein = nutritionData.map { $0.protein }
        let fat = nutritionData.map { $0.fat }
        
        let confidence = calculateConfidence(from: matchCount, cleanedName: cleanedName)
        
        return USDAOnlyServiceNutritionResult(
            originalName: originalName,
            cleanedName: cleanedName,
            calories: NutritionRange(min: calories.min() ?? 0, max: calories.max() ?? 0, unit: "kcal"),
            carbs: NutritionRange(min: carbs.min() ?? 0, max: carbs.max() ?? 0, unit: "g"),
            sugar: NutritionRange(min: sugar.min() ?? 0, max: sugar.max() ?? 0, unit: "g"),
            protein: NutritionRange(min: protein.min() ?? 0, max: protein.max() ?? 0, unit: "g"),
            fat: NutritionRange(min: fat.min() ?? 0, max: fat.max() ?? 0, unit: "g"),
            confidence: confidence,
            matchCount: matchCount,
            isGeneralEstimate: true,
            isAvailable: true
        )
    }
    
    private func calculateConfidence(from matchCount: Int, cleanedName: String) -> Double {
        var baseConfidence: Double = 0.5 // Base confidence for USDA matches
        
        // Boost confidence based on match count
        switch matchCount {
        case 3...: baseConfidence = 0.7  // Multiple matches
        case 2: baseConfidence = 0.6     // Two matches
        case 1: baseConfidence = 0.5     // Single match
        default: baseConfidence = 0.3    // Fallback
        }
        
        // Boost confidence for well-known foods
        let commonFoods = ["chicken", "beef", "fish", "rice", "pasta", "salad", "pizza", "burger", "sandwich"]
        if commonFoods.contains(where: { cleanedName.contains($0) }) {
            baseConfidence += 0.1
        }
        
        return min(baseConfidence, 0.8) // Cap at 80%
    }
}

// MARK: - Food Alias Mapper (Service-specific)
class USDAOnlyFoodAliasMapper {
    private let aliases: [String: String] = [
        // Italian foods
        "crostatine": "tart",
        "tiramisu tradizionale": "tiramisu",
        "bruschette": "bruschetta",
        "antipasti": "appetizer",
        
        // Common variations
        "chx": "chicken",
        "chk": "chicken", 
        "ckn": "chicken",
        "fries": "french fries",
        "soda": "soft drink",
        "pop": "soft drink",
        
        // OCR common errors
        "chickne": "chicken",
        "saiad": "salad",
        "burgre": "burger",
        "pizzza": "pizza"
    ]
    
    func mapToStandardName(_ name: String) -> String {
        let lowercased = name.lowercased()
        
        // Direct alias match
        if let standardName = aliases[lowercased] {
            return standardName
        }
        
        // Partial match for longer names
        for (alias, standard) in aliases {
            if lowercased.contains(alias) {
                return lowercased.replacingOccurrences(of: alias, with: standard)
            }
        }
        
        return name
    }
}

// MARK: - Data Models (Service-specific to avoid conflicts)

struct USDAOnlyServiceNutritionResult: Codable {
    let originalName: String
    let cleanedName: String
    let calories: NutritionRange
    let carbs: NutritionRange
    let sugar: NutritionRange
    let protein: NutritionRange
    let fat: NutritionRange
    let confidence: Double
    let matchCount: Int
    let isGeneralEstimate: Bool
    let isAvailable: Bool
    let timestamp: Date = Date()
    
    static func unavailable(originalName: String) -> USDAOnlyServiceNutritionResult {
        return USDAOnlyServiceNutritionResult(
            originalName: originalName,
            cleanedName: "",
            calories: NutritionRange(min: 0, max: 0, unit: "kcal"),
            carbs: NutritionRange(min: 0, max: 0, unit: "g"),
            sugar: NutritionRange(min: 0, max: 0, unit: "g"),
            protein: NutritionRange(min: 0, max: 0, unit: "g"),
            fat: NutritionRange(min: 0, max: 0, unit: "g"),
            confidence: 0.0,
            matchCount: 0,
            isGeneralEstimate: false,
            isAvailable: false
        )
    }
}

struct USDAOnlyServiceBasicNutrition: Codable {
    let calories: Double
    let carbs: Double
    let sugar: Double
    let protein: Double
    let fat: Double
}

// MARK: - Disk Cache (Service-specific)
actor USDAOnlyServiceDiskCache {
    private let cacheDirectory: URL
    private let cacheExpiry: TimeInterval = 24 * 60 * 60 * 7 // 7 days
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("USDAOnlyServiceCache")
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getCachedResult(for cleanedName: String) -> USDAOnlyServiceNutritionResult? {
        let fileName = cleanedName.replacingOccurrences(of: " ", with: "_") + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let result = try? JSONDecoder().decode(USDAOnlyServiceNutritionResult.self, from: data) else { return nil }
        
        // Check expiry
        if Date().timeIntervalSince(result.timestamp) > cacheExpiry {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        
        return result
    }
    
    func cacheResult(_ result: USDAOnlyServiceNutritionResult, for cleanedName: String) {
        let fileName = cleanedName.replacingOccurrences(of: " ", with: "_") + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? JSONEncoder().encode(result) else { return }
        try? data.write(to: fileURL)
    }
    
    func clearExpiredCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory, 
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        
        let expiredFiles = files.filter { fileURL in
            guard let attributes = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modificationDate = attributes.contentModificationDate else { return false }
            
            return Date().timeIntervalSince(modificationDate) > cacheExpiry
        }
        
        for file in expiredFiles {
            try? FileManager.default.removeItem(at: file)
        }
    }
}