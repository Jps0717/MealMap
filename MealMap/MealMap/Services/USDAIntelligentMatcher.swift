import Foundation

// MARK: - USDA Intelligent Fuzzy Matching Service
@MainActor
class USDAIntelligentMatcher: ObservableObject {
    static let shared = USDAIntelligentMatcher()
    
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"
    private let apiKey = "DEMO_KEY" // Replace with actual API key
    private let session = URLSession.shared
    private let cache = USDAIntelligentCache()
    private let keywordExtractor = FoodKeywordExtractor()
    private let categoryClassifier = FoodCategoryClassifier()
    
    // Rate limiting
    private var lastRequestTime: Date = Date.distantPast
    private let requestInterval: TimeInterval = 1.0
    
    private init() {}
    
    // MARK: - Public API
    
    /// Main intelligent matching function
    func findBestNutritionMatch(for foodName: String) async throws -> IntelligentNutritionResult {
        debugLog(" Starting intelligent match for: '\(foodName)'")
        
        // Step 1: Check cache first
        let cacheKey = foodName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = await cache.getCachedResult(for: cacheKey) {
            debugLog(" Cache hit for: '\(foodName)'")
            return cached
        }
        
        // Step 2: Extract keywords and classify
        let keywords = keywordExtractor.extractKeywords(from: foodName)
        let expectedCategory = categoryClassifier.classifyFood(foodName)
        
        debugLog(" Keywords: \(keywords), Expected category: \(expectedCategory?.rawValue ?? "unknown")")
        
        // Step 3: Search USDA with intelligent query
        let searchResults = try await performIntelligentSearch(keywords: keywords, originalName: foodName)
        
        guard !searchResults.foods.isEmpty else {
            let result = IntelligentNutritionResult.unavailable(originalName: foodName)
            await cache.cacheResult(result, for: cacheKey)
            return result
        }
        
        // Step 4: Score and rank results
        let scoredResults = scoreAndRankResults(
            searchResults.foods,
            keywords: keywords,
            expectedCategory: expectedCategory
        )
        
        debugLog(" Scored \(scoredResults.count) results, best score: \(scoredResults.first?.score ?? 0)")
        
        // Step 5: Get nutrition for top matches
        let topMatches = Array(scoredResults.prefix(3))
        var nutritionData: [USDADetailedNutrition] = []
        
        for scoredResult in topMatches {
            do {
                await USDASharedRateLimit.shared.enforceRateLimit()
                let nutrition = try await fetchDetailedNutrition(fdcId: scoredResult.food.fdcId)
                nutritionData.append(nutrition)
            } catch {
                debugLog(" Failed to fetch nutrition for FDC ID \(scoredResult.food.fdcId): \(error)")
                continue
            }
        }
        
        guard !nutritionData.isEmpty else {
            let result = IntelligentNutritionResult.unavailable(originalName: foodName)
            await cache.cacheResult(result, for: cacheKey)
            return result
        }
        
        // Step 6: Create intelligent result
        let calories = nutritionData.map { $0.calories }
        let carbs = nutritionData.map { $0.carbs }
        let sugar = nutritionData.map { $0.sugar }
        let protein = nutritionData.map { $0.protein }
        let fat = nutritionData.map { $0.fat }
        let fiber = nutritionData.map { $0.fiber }
        let sodium = nutritionData.map { $0.sodium }
        
        let avgCompleteness = nutritionData.map { $0.completenessScore }.reduce(0, +) / Double(nutritionData.count)
        let confidence = calculateOverallConfidence(
            bestMatchScore: topMatches.first?.score ?? 0,
            dataCompleteness: avgCompleteness,
            matchCount: nutritionData.count
        )
        
        let estimatedNutrition = EstimatedNutrition(
            calories: IntelligentNutritionRange(min: calories.min() ?? 0, max: calories.max() ?? 0, unit: "kcal"),
            carbs: IntelligentNutritionRange(min: carbs.min() ?? 0, max: carbs.max() ?? 0, unit: "g"),
            sugar: sugar.allSatisfy({ $0 >= 0 }) ? IntelligentNutritionRange(min: sugar.min() ?? 0, max: sugar.max() ?? 0, unit: "g") : nil,
            protein: IntelligentNutritionRange(min: protein.min() ?? 0, max: protein.max() ?? 0, unit: "g"),
            fat: IntelligentNutritionRange(min: fat.min() ?? 0, max: fat.max() ?? 0, unit: "g"),
            fiber: fiber.allSatisfy({ $0 >= 0 }) ? IntelligentNutritionRange(min: fiber.min() ?? 0, max: fiber.max() ?? 0, unit: "g") : nil,
            sodium: sodium.allSatisfy({ $0 >= 0 }) ? IntelligentNutritionRange(min: sodium.min() ?? 0, max: sodium.max() ?? 0, unit: "mg") : nil,
            confidence: confidence,
            matchCount: nutritionData.count,
            isGeneralEstimate: true
        )
        
        let result = IntelligentNutritionResult(
            originalName: foodName,
            cleanedKeywords: keywords,
            bestMatchName: topMatches.first?.food.description ?? "Unknown",
            bestMatchScore: topMatches.first?.score ?? 0,
            estimatedNutrition: estimatedNutrition,
            matchCount: nutritionData.count,
            isAvailable: true
        )
        
        // Step 7: Cache and return
        await cache.cacheResult(result, for: cacheKey)
        
        debugLog(" Intelligent match complete for '\(foodName)': \(result.bestMatchName)")
        return result
    }
    
    // MARK: - Intelligent Search
    
    private func performIntelligentSearch(keywords: [String], originalName: String) async throws -> USDASearchResponse {
        await USDASharedRateLimit.shared.enforceRateLimit()
        
        // Create intelligent query - try multiple strategies
        let queries = generateSearchQueries(from: keywords, originalName: originalName)
        
        var bestResults: USDASearchResponse?
        var maxResults = 0
        
        // Try each query and pick the one with most relevant results
        for query in queries {
            do {
                let results = try await searchUSDA(query: query)
                if results.foods.count > maxResults {
                    maxResults = results.foods.count
                    bestResults = results
                }
            } catch {
                debugLog(" Query failed: '\(query)' - \(error)")
                continue
            }
        }
        
        return bestResults ?? USDASearchResponse(foods: [], totalHits: 0, currentPage: 1, totalPages: 0)
    }
    
    private func generateSearchQueries(from keywords: [String], originalName: String) -> [String] {
        var queries: [String] = []
        
        // Strategy 1: Original name as-is
        queries.append(originalName)
        
        // Strategy 2: Primary keywords only
        if keywords.count > 1 {
            queries.append(keywords.prefix(2).joined(separator: " "))
        }
        
        // Strategy 3: Single most important keyword
        if let primary = keywords.first {
            queries.append(primary)
        }
        
        // Strategy 4: Keywords with generic terms
        if keywords.contains(where: { ["chicken", "beef", "fish", "pork"].contains($0) }) {
            let proteinKeyword = keywords.first { ["chicken", "beef", "fish", "pork"].contains($0) }!
            queries.append("\(proteinKeyword) cooked")
        }
        
        return Array(Set(queries)) // Remove duplicates
    }
    
    private func searchUSDA(query: String) async throws -> USDASearchResponse {
        guard let url = USDAAPIHelper.createSearchURL(query: query, dataTypes: ["Foundation"], pageSize: 25) else {
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
    
    // MARK: - Intelligent Scoring and Ranking
    
    private func scoreAndRankResults(
        _ foods: [USDAFood],
        keywords: [String],
        expectedCategory: FoodCategory?
    ) -> [ScoredUSDAFood] {
        
        let scoredFoods = foods.map { food in
            let score = calculateIntelligentScore(
                food: food,
                keywords: keywords,
                expectedCategory: expectedCategory
            )
            return ScoredUSDAFood(food: food, score: score)
        }
        
        return scoredFoods.sorted { $0.score > $1.score }
    }
    
    private func calculateIntelligentScore(
        food: USDAFood,
        keywords: [String],
        expectedCategory: FoodCategory?
    ) -> Double {
        var score: Double = 0.0
        let description = food.description.lowercased()
        
        // 1. Keyword Coverage (40% of score)
        let keywordScore = calculateKeywordCoverage(description: description, keywords: keywords)
        score += keywordScore * 0.4
        
        // 2. Category Relevance (30% of score)
        let categoryScore = calculateCategoryRelevance(description: description, expectedCategory: expectedCategory)
        score += categoryScore * 0.3
        
        // 3. Food Specificity (20% of score) - prefer specific over generic
        let specificityScore = calculateSpecificityScore(description: description)
        score += specificityScore * 0.2
        
        // 4. Data Quality (10% of score) - prefer Foundation data
        let qualityScore = food.dataType == "Foundation" ? 1.0 : 0.5
        score += qualityScore * 0.1
        
        return score
    }
    
    private func calculateKeywordCoverage(description: String, keywords: [String]) -> Double {
        guard !keywords.isEmpty else { return 0.0 }
        
        var matchedKeywords = 0
        var totalImportance = 0.0
        
        for (index, keyword) in keywords.enumerated() {
            let importance = 1.0 / Double(index + 1) // First keyword is most important
            totalImportance += importance
            
            if description.contains(keyword.lowercased()) {
                matchedKeywords += 1
            }
        }
        
        return Double(matchedKeywords) / Double(keywords.count)
    }
    
    private func calculateCategoryRelevance(description: String, expectedCategory: FoodCategory?) -> Double {
        guard let expectedCategory = expectedCategory else { return 0.5 } // Neutral if unknown
        
        let categoryKeywords = expectedCategory.getRelevantKeywords()
        
        for keyword in categoryKeywords {
            if description.contains(keyword.lowercased()) {
                return 1.0 // Strong category match
            }
        }
        
        return 0.0 // No category match
    }
    
    private func calculateSpecificityScore(description: String) -> Double {
        // Prefer more specific descriptions over generic ones
        let specificityKeywords = ["cooked", "raw", "roasted", "grilled", "baked", "fried", "steamed"]
        let genericKeywords = ["food", "item", "product", "generic"]
        
        var score = 0.5 // Neutral base
        
        for keyword in specificityKeywords {
            if description.contains(keyword) {
                score += 0.2
            }
        }
        
        for keyword in genericKeywords {
            if description.contains(keyword) {
                score -= 0.3
            }
        }
        
        return max(0.0, min(1.0, score))
    }
    
    // MARK: - Nutrition Fetching
    
    private func fetchDetailedNutrition(fdcId: Int) async throws -> USDADetailedNutrition {
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
        return extractDetailedNutrition(from: foodDetail)
    }
    
    private func extractDetailedNutrition(from detail: USDAFoodDetail) -> USDADetailedNutrition {
        let detailedNutrition = USDANutritionExtractor.extractDetailedNutrition(from: detail)
        return USDADetailedNutrition(
            fdcId: detailedNutrition.fdcId,
            description: detailedNutrition.description,
            calories: detailedNutrition.calories,
            carbs: detailedNutrition.carbs,
            sugar: detailedNutrition.sugar,
            protein: detailedNutrition.protein,
            fat: detailedNutrition.fat,
            fiber: detailedNutrition.fiber,
            sodium: detailedNutrition.sodium,
            completenessScore: detailedNutrition.completenessScore
        )
    }
    
    private func calculateOverallConfidence(
        bestMatchScore: Double,
        dataCompleteness: Double,
        matchCount: Int
    ) -> Double {
        var confidence = 0.0
        
        // Match quality (50% of confidence)
        confidence += bestMatchScore * 0.5
        
        // Data completeness (30% of confidence)
        confidence += dataCompleteness * 0.3
        
        // Match count reliability (20% of confidence)
        let countScore = min(Double(matchCount) / 3.0, 1.0) // Normalize to 1.0 for 3+ matches
        confidence += countScore * 0.2
        
        return min(confidence, 0.85) // Cap at 85% for fuzzy matches
    }
    
    private func enforceRateLimit() async {
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < requestInterval {
            let sleepTime = requestInterval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
}

// MARK: - Supporting Services

class FoodKeywordExtractor {
    private let stopWords = Set(["with", "and", "or", "the", "a", "an", "in", "on", "at", "to", "for", "of", "from"])
    private let cookingMethods = Set(["grilled", "fried", "baked", "roasted", "steamed", "boiled", "raw", "cooked"])
    
    func extractKeywords(from foodName: String) -> [String] {
        let cleaned = foodName.lowercased()
            .replacingOccurrences(of: "[^a-z\\s]", with: "", options: .regularExpression)
        
        let words = cleaned.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
        
        // Prioritize main ingredients over cooking methods
        let ingredients = words.filter { !cookingMethods.contains($0) }
        let methods = words.filter { cookingMethods.contains($0) }
        
        return ingredients + methods
    }
}

class FoodCategoryClassifier {
    func classifyFood(_ foodName: String) -> FoodCategory? {
        let name = foodName.lowercased()
        
        for category in FoodCategory.allCases {
            if category.getIdentifiers().contains(where: { name.contains($0) }) {
                return category
            }
        }
        
        return nil
    }
}

enum FoodCategory: String, CaseIterable {
    case poultry = "poultry"
    case meat = "meat"
    case seafood = "seafood"
    case dairy = "dairy"
    case vegetables = "vegetables"
    case fruits = "fruits"
    case grains = "grains"
    case legumes = "legumes"
    case nuts = "nuts"
    case sweets = "sweets"
    case beverages = "beverages"
    
    func getIdentifiers() -> [String] {
        switch self {
        case .poultry: return ["chicken", "turkey", "duck", "poultry"]
        case .meat: return ["beef", "pork", "lamb", "meat"]
        case .seafood: return ["fish", "shrimp", "salmon", "tuna", "seafood", "shellfish"]
        case .dairy: return ["milk", "cheese", "yogurt", "butter", "cream"]
        case .vegetables: return ["vegetable", "lettuce", "tomato", "carrot", "broccoli"]
        case .fruits: return ["fruit", "apple", "banana", "orange", "berry"]
        case .grains: return ["bread", "rice", "pasta", "wheat", "oats"]
        case .legumes: return ["beans", "lentils", "peas", "hummus", "chickpeas"]
        case .nuts: return ["nuts", "almonds", "peanuts", "walnuts"]
        case .sweets: return ["cake", "cookie", "chocolate", "candy", "dessert"]
        case .beverages: return ["juice", "soda", "coffee", "tea", "water"]
        }
    }
    
    func getRelevantKeywords() -> [String] {
        switch self {
        case .poultry: return ["poultry products", "chicken", "turkey"]
        case .meat: return ["beef products", "pork", "lamb", "meat"]
        case .seafood: return ["finfish", "shellfish", "fish", "seafood"]
        case .dairy: return ["dairy", "milk products"]
        case .vegetables: return ["vegetables", "vegetable products"]
        case .fruits: return ["fruits", "fruit products"]
        case .grains: return ["cereal grains", "bread", "baked products"]
        case .legumes: return ["legumes", "beans", "peas"]
        case .nuts: return ["nuts", "seeds"]
        case .sweets: return ["sweets", "desserts", "candy"]
        case .beverages: return ["beverages", "drinks"]
        }
    }
}

// MARK: - Data Models

struct ScoredUSDAFood {
    let food: USDAFood
    let score: Double
}

struct USDADetailedNutrition: Codable {
    let fdcId: Int
    let description: String
    let calories: Double
    let carbs: Double
    let sugar: Double
    let protein: Double
    let fat: Double
    let fiber: Double
    let sodium: Double
    let completenessScore: Double
}

struct IntelligentNutritionResult: Codable {
    let originalName: String
    let cleanedKeywords: [String]
    let bestMatchName: String
    let bestMatchScore: Double
    let estimatedNutrition: EstimatedNutrition
    let matchCount: Int
    let isAvailable: Bool
    let timestamp: Date = Date()
    
    static func unavailable(originalName: String) -> IntelligentNutritionResult {
        return IntelligentNutritionResult(
            originalName: originalName,
            cleanedKeywords: [],
            bestMatchName: "",
            bestMatchScore: 0.0,
            estimatedNutrition: EstimatedNutrition.empty,
            matchCount: 0,
            isAvailable: false
        )
    }
}

struct EstimatedNutrition: Codable {
    let calories: IntelligentNutritionRange
    let carbs: IntelligentNutritionRange
    let sugar: IntelligentNutritionRange?
    let protein: IntelligentNutritionRange
    let fat: IntelligentNutritionRange
    let fiber: IntelligentNutritionRange?
    let sodium: IntelligentNutritionRange?
    let confidence: Double
    let matchCount: Int
    let isGeneralEstimate: Bool
    
    static let empty = EstimatedNutrition(
        calories: IntelligentNutritionRange(min: 0, max: 0, unit: "kcal"),
        carbs: IntelligentNutritionRange(min: 0, max: 0, unit: "g"),
        sugar: nil,
        protein: IntelligentNutritionRange(min: 0, max: 0, unit: "g"),
        fat: IntelligentNutritionRange(min: 0, max: 0, unit: "g"),
        fiber: nil,
        sodium: nil,
        confidence: 0.0,
        matchCount: 0,
        isGeneralEstimate: false
    )
}

// Rename to avoid conflicts
struct IntelligentNutritionRange: Codable {
    let min: Double
    let max: Double
    let unit: String
    
    var average: Double { (min + max) / 2 }
    
    var displayString: String {
        if min == max {
            return "\(Int(min))\(unit)"
        } else {
            return "\(Int(min))-\(Int(max))\(unit)"
        }
    }
}

// MARK: - USDA API Models (shared types)
struct USDASearchResponse: Codable {
    let foods: [USDAFood]
    let totalHits: Int?
    let currentPage: Int?
    let totalPages: Int?
    
    // Support both possible response formats
    init(foods: [USDAFood], totalHits: Int? = nil, currentPage: Int? = nil, totalPages: Int? = nil) {
        self.foods = foods
        self.totalHits = totalHits
        self.currentPage = currentPage
        self.totalPages = totalPages
    }
}

struct USDAFood: Codable {
    let fdcId: Int
    let description: String
    let dataType: String?
    let publicationDate: String?
    let brandOwner: String?
}

struct USDAFoodDetail: Codable {
    let fdcId: Int
    let description: String
    let dataType: String?
    let foodNutrients: [USDANutrient]
    let publicationDate: String?
    let brandOwner: String?
}

struct USDANutrient: Codable {
    let nutrient: USDANutrientInfo
    let amount: Double?
}

struct USDANutrientInfo: Codable {
    let number: String
    let name: String
    let unitName: String?
}

// Error handling
enum USDAError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case rateLimitExceeded
    case apiError(Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid USDA API URL"
        case .invalidResponse:
            return "Invalid response from USDA API"
        case .rateLimitExceeded:
            return "USDA API rate limit exceeded"
        case .apiError(let code):
            return "USDA API error with status code: \(code)"
        case .decodingError(let error):
            return "Failed to decode USDA response: \(error.localizedDescription)"
        }
    }
}

// API Helper
struct USDAAPIHelper {
    static let baseURL = "https://api.nal.usda.gov/fdc/v1"
    static let defaultAPIKey = "DEMO_KEY"
    
    static func createSearchURL(query: String, dataTypes: [String] = ["Foundation", "SR Legacy"], pageSize: Int = 25, apiKey: String = defaultAPIKey) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let dataTypeString = dataTypes.joined(separator: ",")
        let urlString = "\(baseURL)/foods/search?query=\(encodedQuery)&dataType=\(dataTypeString)&pageSize=\(pageSize)&api_key=\(apiKey)"
        return URL(string: urlString)
    }
    
    static func createFoodDetailURL(fdcId: Int, apiKey: String = defaultAPIKey) -> URL? {
        let urlString = "\(baseURL)/food/\(fdcId)?api_key=\(apiKey)"
        return URL(string: urlString)
    }
}

// Rate limiting helper
actor USDASharedRateLimit {
    static let shared = USDASharedRateLimit()
    
    private var lastRequestTime: Date = Date.distantPast
    private let requestInterval: TimeInterval = 1.0
    
    private init() {}
    
    func enforceRateLimit() async {
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < requestInterval {
            let sleepTime = requestInterval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
}

// Nutrition extraction helper
struct USDANutritionExtractor {
    static func extractDetailedNutrition(from detail: USDAFoodDetail) -> USDADetailedNutrition {
        var calories: Double = 0
        var carbs: Double = 0
        var sugar: Double = 0
        var protein: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var sodium: Double = 0
        
        var completenessScore = 0.0
        let totalNutrients = 7.0
        
        for nutrient in detail.foodNutrients {
            switch nutrient.nutrient.number {
            case "208": // Energy
                calories = nutrient.amount ?? 0
                if calories > 0 { completenessScore += 1 }
            case "205": // Carbohydrate
                carbs = nutrient.amount ?? 0
                if carbs >= 0 { completenessScore += 1 }
            case "269": // Sugars
                sugar = nutrient.amount ?? 0
                if sugar >= 0 { completenessScore += 1 }
            case "203": // Protein
                protein = nutrient.amount ?? 0
                if protein >= 0 { completenessScore += 1 }
            case "204": // Fat
                fat = nutrient.amount ?? 0
                if fat >= 0 { completenessScore += 1 }
            case "291": // Fiber
                fiber = nutrient.amount ?? 0
                if fiber >= 0 { completenessScore += 1 }
            case "307": // Sodium
                sodium = nutrient.amount ?? 0
                if sodium >= 0 { completenessScore += 1 }
            default: break
            }
        }
        
        return USDADetailedNutrition(
            fdcId: detail.fdcId,
            description: detail.description,
            calories: calories,
            carbs: carbs,
            sugar: sugar,
            protein: protein,
            fat: fat,
            fiber: fiber,
            sodium: sodium,
            completenessScore: completenessScore / totalNutrients
        )
    }
}

// MARK: - Enhanced Caching

actor USDAIntelligentCache {
    private let cacheDirectory: URL
    private let cacheExpiry: TimeInterval = 24 * 60 * 60 * 7 // 7 days
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("USDAIntelligentCache")
        
        // Create cache directory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getCachedResult(for key: String) -> IntelligentNutritionResult? {
        let fileName = key.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression) + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let result = try? JSONDecoder().decode(IntelligentNutritionResult.self, from: data) else { return nil }
        
        // Check expiry
        if Date().timeIntervalSince(result.timestamp) > cacheExpiry {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        
        return result
    }
    
    func cacheResult(_ result: IntelligentNutritionResult, for key: String) {
        let fileName = key.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression) + ".json"
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