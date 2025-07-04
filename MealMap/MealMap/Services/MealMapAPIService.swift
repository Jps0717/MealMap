import Foundation

// MARK: - MealMap Custom API Service
@MainActor
class MealMapAPIService: ObservableObject {
    static let shared = MealMapAPIService()
    
    private let baseURL = "https://meal-map-api-njio.onrender.com"
    private let session = URLSession.shared
    private let cache = MealMapAPICache()
    
    // Cached food list
    private var foodEntries: [String] = []
    private var lastFetchTime: Date = Date.distantPast
    private let cacheExpiry: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private init() {}
    
    // MARK: - Public API
    
    /// Main entry point: Get nutrition match for food name (prioritizes R-codes)
    func findNutritionMatch(for foodName: String) async throws -> MealMapNutritionResult {
        debugLog("🍽️ Starting MealMap API match for: '\(foodName)'")
        
        // Step 1: Ensure we have fresh food list
        try await ensureFoodListIsLoaded()
        
        // Step 2: Use enhanced fuzzy matcher that prioritizes R-codes
        let matcher = MealMapFoodMatcher(foodEntries: foodEntries)
        let matchResult = matcher.findBestMatch(for: foodName)
        
        guard let match = matchResult else {
            debugLog("❌ No match found for: '\(foodName)'")
            return MealMapNutritionResult.unavailable(originalName: foodName)
        }
        
        // Step 3: Extract ID from matched entry (now prioritizes R-codes!)
        guard let extractedID = MealMapIDExtractor.extractID(from: match.matchedEntry) else {
            debugLog("❌ Could not extract ID from: '\(match.matchedEntry)'")
            return MealMapNutritionResult.unavailable(originalName: foodName)
        }
        
        // Step 4: Determine data type and confidence
        let isRestaurantData = MealMapIDExtractor.isRestaurantNutritionID(extractedID)
        let dataType: MealMapDataType = isRestaurantData ? .restaurantNutrition : .genericFood
        let baseConfidence = calculateConfidence(from: match.score, dataType: dataType)
        
        debugLog("✅ Found match: '\(match.matchedEntry)' with ID: \(extractedID), score: \(match.score), type: \(dataType.displayName)")
        
        // Step 5: Create result with enhanced metadata
        return MealMapNutritionResult(
            originalName: foodName,
            cleanedName: match.cleanedInput,
            matchedEntry: match.matchedEntry,
            extractedID: extractedID,
            matchScore: match.score,
            confidence: baseConfidence,
            dataType: dataType,
            isGeneralEstimate: !isRestaurantData, // Restaurant data is more specific
            isAvailable: true
        )
    }
    
    /// Find top matches for debugging and comparison
    func findTopMatches(for foodName: String, limit: Int = 5) async throws -> [MealMapNutritionResult] {
        try await ensureFoodListIsLoaded()
        
        let matcher = MealMapFoodMatcher(foodEntries: foodEntries)
        let topMatches = matcher.findTopMatches(for: foodName, limit: limit)
        
        return topMatches.compactMap { match in
            guard let extractedID = MealMapIDExtractor.extractID(from: match.matchedEntry) else {
                return nil
            }
            
            let isRestaurantData = MealMapIDExtractor.isRestaurantNutritionID(extractedID)
            let dataType: MealMapDataType = isRestaurantData ? .restaurantNutrition : .genericFood
            let baseConfidence = calculateConfidence(from: match.score, dataType: dataType)
            
            return MealMapNutritionResult(
                originalName: foodName,
                cleanedName: match.cleanedInput,
                matchedEntry: match.matchedEntry,
                extractedID: extractedID,
                matchScore: match.score,
                confidence: baseConfidence,
                dataType: dataType,
                isGeneralEstimate: !isRestaurantData,
                isAvailable: true
            )
        }
    }
    
    /// Get all available food entries (useful for debugging)
    func getAllFoodEntries() async throws -> [String] {
        try await ensureFoodListIsLoaded()
        return foodEntries
    }
    
    /// Clear cache - useful for debugging or forcing refresh
    func clearCache() async {
        await cache.clearCache()
        foodEntries = []
        lastFetchTime = Date.distantPast
        debugLog("🗑️ MealMap API cache cleared")
    }
    
    // MARK: - Food List Management
    
    private func ensureFoodListIsLoaded() async throws {
        // Check if we need to refresh the food list
        let timeSinceLastFetch = Date().timeIntervalSince(lastFetchTime)
        
        if foodEntries.isEmpty || timeSinceLastFetch > cacheExpiry {
            debugLog("🔄 Fetching fresh food list from MealMap API...")
            try await fetchFoodList()
        } else {
            debugLog("💾 Using cached food list (\(foodEntries.count) entries)")
        }
    }
    
    private func fetchFoodList() async throws {
        // Try cache first
        if let cachedEntries = await cache.getCachedFoodList(),
           Date().timeIntervalSince(await cache.getLastCacheTime()) < cacheExpiry {
            debugLog("💾 Using disk-cached food list (\(cachedEntries.count) entries)")
            self.foodEntries = cachedEntries
            self.lastFetchTime = await cache.getLastCacheTime()
            return
        }
        
        // Fetch from API
        guard let url = URL(string: "\(baseURL)/restaurants") else {
            throw MealMapAPIError.invalidURL
        }
        
        debugLog("🌐 Fetching food list from: \(url.absoluteString)")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MealMapAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw MealMapAPIError.serverError(httpResponse.statusCode)
            }
            
            // Parse response as string array
            let entries = try JSONDecoder().decode([String].self, from: data)
            
            // Log R-code statistics
            let rCodes = entries.filter { $0.hasPrefix("R") }
            let genericFoods = entries.filter { !$0.hasPrefix("R") }
            
            debugLog("✅ Fetched \(entries.count) food entries from MealMap API")
            debugLog("  🏪 Restaurant nutrition entries (R-codes): \(rCodes.count)")
            debugLog("  🥗 Generic food entries: \(genericFoods.count)")
            
            // Update cache
            self.foodEntries = entries
            self.lastFetchTime = Date()
            
            // Cache to disk
            await cache.cacheFoodList(entries)
            
        } catch {
            debugLog("❌ Failed to fetch food list: \(error)")
            
            // Try to use stale cache as fallback
            if let staleEntries = await cache.getCachedFoodList(), !staleEntries.isEmpty {
                debugLog("🔄 Using stale cached food list as fallback (\(staleEntries.count) entries)")
                self.foodEntries = staleEntries
                self.lastFetchTime = await cache.getLastCacheTime()
                return
            }
            
            throw error
        }
    }
    
    private func calculateConfidence(from matchScore: Double, dataType: MealMapDataType) -> Double {
        // Base confidence from match score (0-1) 
        var baseConfidence = matchScore
        
        // Boost confidence for restaurant nutrition data (R-codes have CSV files)
        switch dataType {
        case .restaurantNutrition:
            baseConfidence = min(baseConfidence * 1.2, 0.9) // Boost up to 90%
        case .genericFood:
            baseConfidence = min(baseConfidence * 0.8, 0.7) // Cap at 70%
        }
        
        return baseConfidence
    }
    
    // MARK: - Debugging and Statistics
    
    func getFoodListStatistics() async throws -> MealMapAPIStatistics {
        try await ensureFoodListIsLoaded()
        
        let totalEntries = foodEntries.count
        let restaurantEntries = foodEntries.filter { $0.hasPrefix("R") }.count
        let genericFoodEntries = foodEntries.filter { !$0.hasPrefix("R") }.count
        
        // Sample entries for debugging
        let sampleRestaurant = foodEntries.filter { $0.hasPrefix("R") }.prefix(5)
        let sampleGenericFood = foodEntries.filter { !$0.hasPrefix("R") }.prefix(5)
        
        return MealMapAPIStatistics(
            totalEntries: totalEntries,
            restaurantEntries: restaurantEntries,
            genericFoodEntries: genericFoodEntries,
            lastFetchTime: lastFetchTime,
            sampleRestaurantEntries: Array(sampleRestaurant),
            sampleGenericFoodEntries: Array(sampleGenericFood)
        )
    }
}

// MARK: - Data Models

enum MealMapDataType: String, Codable {
    case restaurantNutrition = "restaurant_nutrition"
    case genericFood = "generic_food"
    
    var displayName: String {
        switch self {
        case .restaurantNutrition: return "Restaurant Nutrition Data"
        case .genericFood: return "Generic Food Data"
        }
    }
    
    var emoji: String {
        switch self {
        case .restaurantNutrition: return "🏪"
        case .genericFood: return "🥗"
        }
    }
    
    var priority: Int {
        switch self {
        case .restaurantNutrition: return 1 // Highest priority
        case .genericFood: return 2        // Lower priority
        }
    }
}

struct MealMapNutritionResult: Codable {
    let originalName: String
    let cleanedName: String
    let matchedEntry: String
    let extractedID: String
    let matchScore: Double
    let confidence: Double
    let dataType: MealMapDataType
    let isGeneralEstimate: Bool
    let isAvailable: Bool
    let timestamp: Date = Date()
    
    var isRestaurantNutrition: Bool {
        return dataType == .restaurantNutrition
    }
    
    var isGenericFood: Bool {
        return dataType == .genericFood
    }
    
    static func unavailable(originalName: String) -> MealMapNutritionResult {
        return MealMapNutritionResult(
            originalName: originalName,
            cleanedName: "",
            matchedEntry: "",
            extractedID: "",
            matchScore: 0.0,
            confidence: 0.0,
            dataType: .genericFood,
            isGeneralEstimate: false,
            isAvailable: false
        )
    }
}

struct MealMapAPIStatistics {
    let totalEntries: Int
    let restaurantEntries: Int
    let genericFoodEntries: Int
    let lastFetchTime: Date
    let sampleRestaurantEntries: [String]
    let sampleGenericFoodEntries: [String]
    
    var restaurantPercentage: Double {
        guard totalEntries > 0 else { return 0.0 }
        return Double(restaurantEntries) / Double(totalEntries) * 100.0
    }
    
    var genericFoodPercentage: Double {
        guard totalEntries > 0 else { return 0.0 }
        return Double(genericFoodEntries) / Double(totalEntries) * 100.0
    }
    
    var summary: String {
        return """
        MealMap API Statistics:
        Total Entries: \(totalEntries)
        🏪 Restaurant Nutrition (R-codes): \(restaurantEntries) (\(String(format: "%.1f", restaurantPercentage))%)
        🥗 Generic Food Entries: \(genericFoodEntries) (\(String(format: "%.1f", genericFoodPercentage))%)
        Last Fetch: \(lastFetchTime.formatted())
        
        Priority: Restaurant nutrition entries (R-codes) have CSV nutrition data!
        """
    }
}

// MARK: - Error Handling

enum MealMapAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case noDataFound
    case decodingError(Error)
    case networkFailure
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid MealMap API URL"
        case .invalidResponse:
            return "Invalid response from MealMap API"
        case .serverError(let code):
            return "MealMap API server error: \(code)"
        case .noDataFound:
            return "No data found from MealMap API"
        case .decodingError(let error):
            return "Failed to decode MealMap API response: \(error.localizedDescription)"
        case .networkFailure:
            return "Network connection failed"
        }
    }
}

// MARK: - Caching

actor MealMapAPICache {
    private let cacheDirectory: URL
    private let cacheFileName = "mealmap_food_list.json"
    private let timestampFileName = "mealmap_cache_timestamp.txt"
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("MealMapAPICache")
        
        // Create cache directory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func cacheFoodList(_ entries: [String]) {
        let cacheURL = cacheDirectory.appendingPathComponent(cacheFileName)
        let timestampURL = cacheDirectory.appendingPathComponent(timestampFileName)
        
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: cacheURL)
            
            let timestamp = Date().timeIntervalSince1970
            try String(timestamp).write(to: timestampURL, atomically: true, encoding: .utf8)
            
            let rCodes = entries.filter { $0.hasPrefix("R") }.count
            let genericFoods = entries.filter { !$0.hasPrefix("R") }.count
            debugLog("💾 Cached \(entries.count) food entries to disk (\(rCodes) R-codes, \(genericFoods) generic)")
        } catch {
            debugLog("❌ Failed to cache food list: \(error)")
        }
    }
    
    func getCachedFoodList() -> [String]? {
        let cacheURL = cacheDirectory.appendingPathComponent(cacheFileName)
        
        guard let data = try? Data(contentsOf: cacheURL),
              let entries = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        
        return entries
    }
    
    func getLastCacheTime() -> Date {
        let timestampURL = cacheDirectory.appendingPathComponent(timestampFileName)
        
        guard let timestampString = try? String(contentsOf: timestampURL),
              let timestamp = Double(timestampString) else {
            return Date.distantPast
        }
        
        return Date(timeIntervalSince1970: timestamp)
    }
    
    func clearCache() {
        let cacheURL = cacheDirectory.appendingPathComponent(cacheFileName)
        let timestampURL = cacheDirectory.appendingPathComponent(timestampFileName)
        
        try? FileManager.default.removeItem(at: cacheURL)
        try? FileManager.default.removeItem(at: timestampURL)
        
        debugLog("🗑️ MealMap API cache files cleared")
    }
}