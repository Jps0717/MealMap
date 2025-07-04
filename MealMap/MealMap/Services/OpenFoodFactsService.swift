import Foundation

// MARK: - Open Food Facts Service
@MainActor
class OpenFoodFactsService: ObservableObject {
    static let shared = OpenFoodFactsService()
    
    private let baseURL = "https://world.openfoodfacts.org/api/v2"
    private let session: URLSession
    private let cache = OpenFoodFactsCache()
    private let textCleaner = EnhancedFoodTextCleaner()
    private let matcher = ImprovedFoodMatcher()
    
    // ENHANCED: Stricter confidence requirements
    private let minimumConfidenceThreshold: Double = 0.60 // 60% minimum
    private let highConfidenceThreshold: Double = 0.75   // 75% for caching
    
    // Rate limiting - 10 requests/min = 6 seconds between requests
    private var lastRequestTime: Date = Date.distantPast
    private let requestInterval: TimeInterval = 6.0
    
    private init() {
        // Configure session with custom User-Agent
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "MealMap/1.0 (mealmapsupport@example.com)"
        ]
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// Find nutrition data for a food item using Open Food Facts with strict confidence filtering
    func findNutritionMatch(for foodName: String) async throws -> OpenFoodFactsResult {
        debugLog("🥫 OFF: Starting HIGH-CONFIDENCE search for: '\(foodName)'")
        
        // Input validation
        guard !foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            debugLog("🥫 OFF: Empty food name provided")
            return OpenFoodFactsResult.unavailable(originalName: foodName)
        }
        
        // Step 1: Extract core food terms using enhanced parsing
        let coreFood = textCleaner.extractCoreFoodTerms(from: foodName)
        let cacheKey = textCleaner.createIngredientCacheKey(from: coreFood.primaryFood)
        
        debugLog("🥫 OFF: Core food extraction: '\(foodName)' → '\(coreFood.primaryFood)' (modifiers: \(coreFood.modifiers))")
        
        // Step 2: Check cache for core ingredient (not full menu item)
        if let cached = await cache.getCachedResult(for: cacheKey),
           cached.confidence >= minimumConfidenceThreshold {
            debugLog("🥫 OFF: HIGH-CONFIDENCE cache hit for core food: '\(coreFood.primaryFood)' (confidence: \(Int(cached.confidence * 100))%)")
            return cached
        }
        
        // Step 3: Smart search with enhanced strategies
        let searchResults = try await performEnhancedSearch(
            originalName: foodName,
            coreFood: coreFood
        )
        
        guard !searchResults.products.isEmpty else {
            debugLog("🥫 OFF: No products found for '\(foodName)'")
            let result = OpenFoodFactsResult.unavailable(originalName: foodName)
            return result
        }
        
        // Step 4: Enhanced scoring and strict confidence filtering
        let scoredResults = scoreAndRankResultsEnhanced(
            searchResults.products,
            coreFood: coreFood,
            originalName: foodName
        )
        
        let bestResult = scoredResults.first
        debugLog("🥫 OFF: Best match score: \(String(format: "%.2f", bestResult?.score ?? 0)) for '\(bestResult?.product.productName ?? "N/A")'")
        
        // Step 5: STRICT confidence filtering - reject low confidence matches
        guard let bestMatch = bestResult,
              bestMatch.score >= minimumConfidenceThreshold,
              hasValidNutritionData(bestMatch.product) else {
            debugLog("🥫 OFF: ❌ REJECTED - Below \(Int(minimumConfidenceThreshold * 100))% confidence threshold")
            let result = OpenFoodFactsResult.unavailable(originalName: foodName)
            return result
        }
        
        // Step 6: Create high-confidence result
        let nutrition = extractNutritionData(from: bestMatch.product)
        let finalConfidence = calculateEnhancedConfidence(
            matchScore: bestMatch.score,
            nutritionCompleteness: nutrition.completenessScore,
            coreFood: coreFood
        )
        
        let result = OpenFoodFactsResult(
            originalName: foodName,
            cleanedQuery: coreFood.primaryFood,
            matchedProductName: bestMatch.product.productName ?? "Unknown Product",
            productId: bestMatch.product.id,
            barcode: bestMatch.product.code,
            nutrition: nutrition,
            matchScore: bestMatch.score,
            confidence: finalConfidence,
            isAvailable: true,
            isGeneralEstimate: true,
            source: "Open Food Facts"
        )
        
        // Step 7: Cache high-confidence matches for core ingredients
        if finalConfidence >= highConfidenceThreshold {
            await cache.cacheResult(result, for: cacheKey)
            debugLog("🥫 OFF: ✅ CACHED high-confidence match for '\(coreFood.primaryFood)'")
        }
        
        debugLog("🥫 OFF: ✅ HIGH-CONFIDENCE match for '\(foodName)': \(result.matchedProductName) (confidence: \(Int(finalConfidence * 100))%)")
        return result
    }
    
    // MARK: - Enhanced Search Implementation
    
    private func performEnhancedSearch(
        originalName: String,
        coreFood: EnhancedFoodTextCleaner.CoreFoodTerms
    ) async throws -> OpenFoodFactsSearchResponse {
        
        await enforceRateLimit()
        
        // Create focused search strategies based on core food analysis
        let searchStrategies = createEnhancedSearchStrategies(coreFood: coreFood)
        
        var bestResults: OpenFoodFactsSearchResponse?
        var maxQualityScore = 0.0
        
        for strategy in searchStrategies {
            do {
                let results = try await searchOFF(query: strategy.query, searchType: strategy.type)
                
                // Score results by relevance, not just count
                let qualityScore = calculateSearchQuality(results, coreFood: coreFood)
                
                if qualityScore > maxQualityScore {
                    maxQualityScore = qualityScore
                    bestResults = results
                }
                
                // If we found high-quality results, don't waste more API calls
                if qualityScore > 0.7 {
                    break
                }
            } catch OpenFoodFactsError.rateLimitExceeded {
                debugLog("🥫 OFF: Rate limit exceeded, stopping search")
                throw OpenFoodFactsError.rateLimitExceeded
            } catch {
                debugLog("🥫 OFF: Search failed for '\(strategy.query)': \(error)")
                continue
            }
        }
        
        return bestResults ?? OpenFoodFactsSearchResponse(products: [], count: 0, page: 1, pageSize: 20)
    }
    
    private func createEnhancedSearchStrategies(coreFood: EnhancedFoodTextCleaner.CoreFoodTerms) -> [SearchStrategy] {
        var strategies: [SearchStrategy] = []
        
        // Strategy 1: Primary food only (most focused)
        strategies.append(SearchStrategy(query: coreFood.primaryFood, type: .text))
        
        // Strategy 2: Primary food + main modifier
        if let mainModifier = coreFood.modifiers.first {
            strategies.append(SearchStrategy(query: "\(mainModifier) \(coreFood.primaryFood)", type: .text))
        }
        
        // Strategy 3: Category search for broad terms
        if let category = inferFoodCategory(from: coreFood.primaryFood) {
            strategies.append(SearchStrategy(query: category, type: .category))
        }
        
        return strategies
    }
    
    private func calculateSearchQuality(_ results: OpenFoodFactsSearchResponse, coreFood: EnhancedFoodTextCleaner.CoreFoodTerms) -> Double {
        guard !results.products.isEmpty else { return 0.0 }
        
        var totalRelevance = 0.0
        let maxProductsToCheck = min(5, results.products.count)
        
        for i in 0..<maxProductsToCheck {
            let product = results.products[i]
            if let productName = product.productName {
                let relevance = matcher.calculateMatchScore(
                    productName: productName,
                    coreFood: coreFood,
                    originalName: coreFood.primaryFood
                )
                totalRelevance += relevance
            }
        }
        
        return totalRelevance / Double(maxProductsToCheck)
    }
    
    private func searchOFF(query: String, searchType: SearchType) async throws -> OpenFoodFactsSearchResponse {
        guard let url = OpenFoodFactsAPIHelper.createSearchURL(
            query: query,
            searchType: searchType,
            pageSize: 20
        ) else {
            throw OpenFoodFactsError.invalidURL
        }
        
        debugLog("🥫 OFF: Searching with URL: \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenFoodFactsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw OpenFoodFactsError.rateLimitExceeded
            }
            throw OpenFoodFactsError.apiError(httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(OpenFoodFactsSearchResponse.self, from: data)
        } catch {
            debugLog("🥫 OFF: Decoding error: \(error)")
            throw OpenFoodFactsError.decodingError(error)
        }
    }
    
    // MARK: - Enhanced Scoring and Ranking
    
    private func scoreAndRankResultsEnhanced(
        _ products: [OpenFoodFactsProduct],
        coreFood: EnhancedFoodTextCleaner.CoreFoodTerms,
        originalName: String
    ) -> [ScoredOpenFoodFactsProduct] {
        
        let scoredProducts = products.compactMap { product -> ScoredOpenFoodFactsProduct? in
            guard let productName = product.productName else { return nil }
            
            let score = matcher.calculateMatchScore(
                productName: productName,
                coreFood: coreFood,
                originalName: originalName
            )
            
            return ScoredOpenFoodFactsProduct(product: product, score: score)
        }
        
        // Sort by score and filter low-confidence matches early
        return scoredProducts
            .filter { $0.score >= 0.3 } // Pre-filter obviously bad matches
            .sorted { $0.score > $1.score }
    }
    
    private func hasValidNutritionData(_ product: OpenFoodFactsProduct) -> Bool {
        guard let nutriments = product.nutriments else { return false }
        
        // Require at least calories to be considered valid
        return nutriments.energyKcal100g != nil && (nutriments.energyKcal100g ?? 0) > 0
    }
    
    // MARK: - Nutrition Extraction
    
    private func extractNutritionData(from product: OpenFoodFactsProduct) -> OpenFoodFactsNutrition {
        guard let nutriments = product.nutriments else {
            return OpenFoodFactsNutrition.empty
        }
        
        // Extract values with bounds checking to prevent negative values
        let calories = max(0, nutriments.energyKcal100g ?? 0)
        let carbs = max(0, nutriments.carbohydrates100g ?? 0)
        let sugar = nutriments.sugars100g != nil ? max(0, nutriments.sugars100g!) : nil
        let protein = max(0, nutriments.proteins100g ?? 0)
        let fat = max(0, nutriments.fat100g ?? 0)
        let fiber = nutriments.fiber100g != nil ? max(0, nutriments.fiber100g!) : nil
        let sodium = nutriments.sodium100g != nil ? max(0, (nutriments.sodium100g! * 1000)) : nil // Convert g to mg
        
        // Calculate completeness score
        var completenessScore = 0.0
        let totalNutrients = 7.0
        
        if calories > 0 { completenessScore += 1 }
        if carbs >= 0 { completenessScore += 1 }
        if sugar != nil { completenessScore += 1 }
        if protein >= 0 { completenessScore += 1 }
        if fat >= 0 { completenessScore += 1 }
        if fiber != nil { completenessScore += 1 }
        if sodium != nil { completenessScore += 1 }
        
        return OpenFoodFactsNutrition(
            calories: calories,
            carbs: carbs,
            sugar: sugar,
            protein: protein,
            fat: fat,
            fiber: fiber,
            sodium: sodium,
            completenessScore: completenessScore / totalNutrients,
            per100g: true
        )
    }
    
    // MARK: - Enhanced Confidence Calculation
    
    private func calculateEnhancedConfidence(
        matchScore: Double,
        nutritionCompleteness: Double,
        coreFood: EnhancedFoodTextCleaner.CoreFoodTerms
    ) -> Double {
        // Weight match score heavily since it's now more reliable
        var confidence = matchScore * 0.7
        
        // Nutrition completeness
        confidence += nutritionCompleteness * 0.2
        
        // Parsing confidence bonus
        confidence += coreFood.confidence * 0.1
        
        // Cap at 75% for Open Food Facts data (since it's a fallback)
        return min(confidence, 0.75)
    }
    
    // Helper method for category inference
    private func inferFoodCategory(from primaryFood: String) -> String? {
        let categoryMappings: [String: [String]] = [
            "snacks": ["chips", "crackers", "cookies", "candy"],
            "dairy": ["cheese", "milk", "yogurt", "butter"],
            "meat": ["chicken", "beef", "pork", "turkey", "ham"],
            "seafood": ["fish", "shrimp", "salmon", "tuna"],
            "beverages": ["juice", "soda", "coffee", "tea"],
            "bread": ["bread", "toast", "sandwich", "bun"],
            "fruits": ["apple", "banana", "orange", "berry"],
            "vegetables": ["salad", "lettuce", "tomato", "carrot"]
        ]
        
        for (category, keywords) in categoryMappings {
            if keywords.contains(where: { primaryFood.contains($0) }) {
                return category
            }
        }
        
        return nil
    }
    
    private func enforceRateLimit() async {
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < requestInterval {
            let sleepTime = requestInterval - timeSinceLastRequest
            debugLog("🥫 OFF: Rate limiting - waiting \(Int(sleepTime))s")
            try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
}

// MARK: - Supporting Types

struct SearchStrategy {
    let query: String
    let type: SearchType
}

enum SearchType {
    case text
    case category
}

struct ScoredOpenFoodFactsProduct {
    let product: OpenFoodFactsProduct
    let score: Double
}

// MARK: - API Helper

struct OpenFoodFactsAPIHelper {
    
    static func createSearchURL(
        query: String,
        searchType: SearchType,
        pageSize: Int = 20
    ) -> URL? {
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let baseURL = "https://world.openfoodfacts.org/api/v2/search"
        
        var urlString: String
        
        switch searchType {
        case .text:
            urlString = "\(baseURL)?search_terms=\(encodedQuery)&fields=product_name,nutriments,code,id&page_size=\(pageSize)"
        case .category:
            urlString = "\(baseURL)?categories_tags_en=\(encodedQuery)&fields=product_name,nutriments,code,id&page_size=\(pageSize)"
        }
        
        return URL(string: urlString)
    }
}

// MARK: - Error Handling

enum OpenFoodFactsError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case rateLimitExceeded
    case apiError(Int)
    case decodingError(Error)
    case noValidNutritionData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Open Food Facts API URL"
        case .invalidResponse:
            return "Invalid response from Open Food Facts API"
        case .rateLimitExceeded:
            return "Open Food Facts API rate limit exceeded"
        case .apiError(let code):
            return "Open Food Facts API error with status code: \(code)"
        case .decodingError(let error):
            return "Failed to decode Open Food Facts response: \(error.localizedDescription)"
        case .noValidNutritionData:
            return "No valid nutrition data found in Open Food Facts"
        }
    }
}