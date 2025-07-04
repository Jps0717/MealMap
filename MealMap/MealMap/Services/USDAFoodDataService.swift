import Foundation

// MARK: - USDA FoodData Central API Service
@MainActor
class USDAFoodDataService: ObservableObject {
    static let shared = USDAFoodDataService()
    
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"
    private let apiKey = "DEMO_KEY" // Replace with actual API key
    private let session = URLSession.shared
    private let cache = USDACache()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Search for foods by name and return nutrition estimates
    func searchNutritionByName(_ itemName: String) async throws -> USDANutritionEstimate? {
        let normalizedName = normalizeItemName(itemName)
        
        // Check cache first
        if let cached = await cache.getCachedEstimate(for: normalizedName) {
            debugLog("🥗 USDA cache hit for: \(normalizedName)")
            return cached
        }
        
        // Search USDA database
        let searchResults = try await searchFoods(query: normalizedName)
        
        guard !searchResults.foods.isEmpty else {
            debugLog("🥗 No USDA matches found for: \(normalizedName)")
            return nil
        }
        
        // Get detailed nutrition for top matches (up to 3)
        let topMatches = Array(searchResults.foods.prefix(3))
        var nutritionRanges: [USDANutritionData] = []
        
        for food in topMatches {
            if let nutrition = try? await getFoodDetails(fdcId: food.fdcId) {
                nutritionRanges.append(nutrition)
            }
        }
        
        guard !nutritionRanges.isEmpty else {
            debugLog("🥗 No nutrition data found for: \(normalizedName)")
            return nil
        }
        
        // Calculate nutrition range from multiple matches
        let estimate = calculateNutritionRange(from: nutritionRanges, originalName: itemName)
        
        // Cache the result
        await cache.cacheEstimate(estimate, for: normalizedName)
        
        debugLog("🥗 USDA estimate created for '\(itemName)': \(Int(estimate.calories.average))cal")
        return estimate
    }
    
    // MARK: - Private Methods
    
    private func normalizeItemName(_ name: String) -> String {
        let lowercased = name.lowercased()
        
        // Remove common menu descriptors
        let descriptorsToRemove = [
            "tradizionale", "classic", "signature", "house", "special",
            "fresh", "homemade", "organic", "local", "seasonal",
            "with", "and", "&", "served", "topped"
        ]
        
        var normalized = lowercased
        for descriptor in descriptorsToRemove {
            normalized = normalized.replacingOccurrences(of: descriptor, with: "")
        }
        
        // Clean up spacing and punctuation
        normalized = normalized
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle specific food normalizations
        let foodNormalizations = [
            "tiramisu tradizionale": "tiramisu",
            "chocolate chip cookie": "chocolate chip cookie",
            "caesar salad": "caesar salad",
            "chicken sandwich": "chicken sandwich",
            "beef burger": "hamburger",
            "veggie burger": "vegetable burger"
        ]
        
        for (original, normalized_form) in foodNormalizations {
            if lowercased.contains(original) {
                return normalized_form
            }
        }
        
        return normalized
    }
    
    private func searchFoods(query: String) async throws -> USDASearchResponse {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/foods/search?query=\(encodedQuery)&dataType=Foundation,SR%20Legacy&pageSize=10&api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
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
            let searchResponse = try JSONDecoder().decode(USDASearchResponse.self, from: data)
            return searchResponse
        } catch {
            debugLog("🥗 USDA decode error: \(error)")
            throw USDAError.decodingError(error)
        }
    }
    
    private func getFoodDetails(fdcId: Int) async throws -> USDANutritionData {
        let urlString = "\(baseURL)/food/\(fdcId)?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
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
            return extractNutritionData(from: foodDetail)
        } catch {
            debugLog("🥗 USDA detail decode error: \(error)")
            throw USDAError.decodingError(error)
        }
    }
    
    private func extractNutritionData(from detail: USDAFoodDetail) -> USDANutritionData {
        var calories: Double = 0
        var carbs: Double = 0
        var protein: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var sugar: Double = 0
        var sodium: Double = 0
        
        for nutrient in detail.foodNutrients {
            switch nutrient.nutrient.number {
            case "208": calories = nutrient.amount ?? 0    // Energy (kcal)
            case "205": carbs = nutrient.amount ?? 0       // Carbohydrate
            case "203": protein = nutrient.amount ?? 0     // Protein
            case "204": fat = nutrient.amount ?? 0         // Total lipid (fat)
            case "291": fiber = nutrient.amount ?? 0       // Fiber, total dietary
            case "269": sugar = nutrient.amount ?? 0       // Sugars, total
            case "307": sodium = nutrient.amount ?? 0      // Sodium
            default: break
            }
        }
        
        return USDANutritionData(
            calories: calories,
            carbs: carbs,
            protein: protein,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium
        )
    }
    
    private func calculateNutritionRange(from nutritionData: [USDANutritionData], originalName: String) -> USDANutritionEstimate {
        let calories = nutritionData.map { $0.calories }
        let carbs = nutritionData.map { $0.carbs }
        let protein = nutritionData.map { $0.protein }
        let fat = nutritionData.map { $0.fat }
        let fiber = nutritionData.map { $0.fiber }
        let sugar = nutritionData.map { $0.sugar }
        let sodium = nutritionData.map { $0.sodium }
        
        return USDANutritionEstimate(
            originalItemName: originalName,
            calories: NutritionRange(min: calories.min() ?? 0, max: calories.max() ?? 0, unit: "kcal"),
            carbs: NutritionRange(min: carbs.min() ?? 0, max: carbs.max() ?? 0, unit: "g"),
            protein: NutritionRange(min: protein.min() ?? 0, max: protein.max() ?? 0, unit: "g"),
            fat: NutritionRange(min: fat.min() ?? 0, max: fat.max() ?? 0, unit: "g"),
            fiber: fiber.allSatisfy({ $0 > 0 }) ? NutritionRange(min: fiber.min() ?? 0, max: fiber.max() ?? 0, unit: "g") : nil,
            sugar: sugar.allSatisfy({ $0 > 0 }) ? NutritionRange(min: sugar.min() ?? 0, max: sugar.max() ?? 0, unit: "g") : nil,
            sodium: sodium.allSatisfy({ $0 > 0 }) ? NutritionRange(min: sodium.min() ?? 0, max: sodium.max() ?? 0, unit: "mg") : nil,
            confidence: calculateConfidence(from: nutritionData.count),
            estimationSource: .usda,
            matchCount: nutritionData.count,
            isGeneralizedEstimate: true
        )
    }
    
    private func calculateConfidence(from matchCount: Int) -> Double {
        // Confidence based on number of USDA matches
        switch matchCount {
        case 3...: return 0.7  // Multiple matches provide good confidence
        case 2: return 0.6     // Two matches provide medium confidence
        case 1: return 0.5     // Single match provides lower confidence
        default: return 0.3    // Fallback confidence
        }
    }
}

// MARK: - USDA Nutrition Data (internal use only)
struct USDANutritionData: Codable {
    let calories: Double
    let carbs: Double
    let protein: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
}

// MARK: - USDA API Response Models

struct USDASearchResponse: Codable {
    let foods: [USDAFood]
    let totalHits: Int
    let currentPage: Int
    let totalPages: Int
}

struct USDAFood: Codable {
    let fdcId: Int
    let description: String
    let dataType: String?
    let brandOwner: String?
    let score: Double?
}

struct USDAFoodDetail: Codable {
    let fdcId: Int
    let description: String
    let dataType: String
    let foodNutrients: [USDANutrient]
}

struct USDANutrient: Codable {
    let nutrient: USDANutrientInfo
    let amount: Double?
    let unitName: String?
}

struct USDANutrientInfo: Codable {
    let id: Int
    let number: String
    let name: String
    let rank: Int?
}

// MARK: - USDA Errors

enum USDAError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(Int)
    case decodingError(Error)
    case noDataFound
    case rateLimitExceeded
    case networkFailure
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid USDA API URL"
        case .invalidResponse:
            return "Invalid response from USDA API"
        case .apiError(let code):
            return "USDA API error with status code: \(code)"
        case .decodingError(let error):
            return "Failed to decode USDA response: \(error.localizedDescription)"
        case .noDataFound:
            return "No nutrition data found in USDA database"
        case .rateLimitExceeded:
            return "USDA API rate limit exceeded"
        case .networkFailure:
            return "Network connection failed"
        }
    }
}

// MARK: - USDA Caching

actor USDACache {
    private var cache: [String: USDANutritionEstimate] = [:]
    private let cacheLimit = 100
    private let cacheExpiry: TimeInterval = 24 * 60 * 60 // 24 hours
    
    func getCachedEstimate(for key: String) -> USDANutritionEstimate? {
        guard let estimate = cache[key] else { return nil }
        
        // Check if cache entry has expired
        if Date().timeIntervalSince(estimate.timestamp) > cacheExpiry {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return estimate
    }
    
    func cacheEstimate(_ estimate: USDANutritionEstimate, for key: String) {
        // Remove oldest entries if cache is full
        if cache.count >= cacheLimit {
            let oldestKey = cache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let keyToRemove = oldestKey {
                cache.removeValue(forKey: keyToRemove)
            }
        }
        
        cache[key] = estimate
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

// The rest of the file remains the same