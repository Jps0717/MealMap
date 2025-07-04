import Foundation
import UIKit

@MainActor
class NutritionDataManager: ObservableObject {
    @Published var isLoading = false
    @Published var currentRestaurantData: RestaurantNutritionData?
    @Published var errorMessage: String?
    
    // ENHANCED: Batch loading tracking
    @Published var isBatchLoading = false
    @Published var batchLoadingProgress: Double = 0.0
    @Published var batchLoadingStatus: String = ""
    
    // MARK: - Singleton Pattern
    static let shared = NutritionDataManager()
    
    // MARK: - API Configuration
    private let baseURL = "https://meal-map-api.onrender.com"
    private let session: URLSession
    
    // MARK: - Enhanced Cache
    private var nutritionCache = NutritionCache()
    private let diskCache = NutritionDiskCache()
    private var loadingTasks: [String: Task<RestaurantNutritionData?, Never>] = [:]
    private var availableRestaurantIDs: [String] = []
    
    // MARK: - API Connection Status
    private var hasCheckedAPIAvailability = false
    
    // MARK: - Performance Tracking
    private var cacheHits = 0
    private var cacheMisses = 0
    
    private init() {
        // OPTIMIZED: Configure session for fast, unlimited API access
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3.0 // FIXED: Aggressive timeout for fast startup
        config.timeoutIntervalForResource = 5.0 // FIXED: Quick total timeout
        config.requestCachePolicy = .useProtocolCachePolicy // Use normal caching
        config.httpMaximumConnectionsPerHost = 10 // Allow more concurrent requests
        config.waitsForConnectivity = false // FIXED: Don't wait for connectivity
        self.session = URLSession(configuration: config)

        // Prime in-memory cache from persisted disk cache
        let persisted = diskCache.allEntries
        for entry in persisted {
            nutritionCache.store(restaurant: entry)
        }

        debugLog("⚡ NutritionDataManager optimized for unlimited API access (restored \(persisted.count) cached restaurants)")
    }
    
    // MARK: - Startup Methods - Lightweight Initialization Only
    // FIXED: Truly fast startup - background API check only
    func initializeIfNeeded() async {
        guard !hasCheckedAPIAvailability else { return }
        hasCheckedAPIAvailability = true
        
        debugLog("⚡ Lightning-fast API initialization...")
        
        // FIXED: Fire-and-forget background API check - don't await
        Task.detached(priority: .background) { [weak self] in
            await self?.checkAPIAvailability()
        }
        
        debugLog("✅ Initialization completed instantly (API check running in background)")
    }
    
    // FIXED: Fast API availability check with aggressive timeout
    private func checkAPIAvailability() async {
        guard availableRestaurantIDs.isEmpty else {
            debugLog("📋 Restaurant IDs already loaded")
            return
        }
        
        guard let url = URL(string: "\(baseURL)/restaurants") else {
            debugLog("❌ Invalid API URL")
            return
        }
        
        debugLog("🔍 Background API availability check...")
        
        do {
            // FIXED: Use aggressive timeout
            let request = URLRequest(url: url, timeoutInterval: 3.0)
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                debugLog("📊 API Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let restaurantIDs = try JSONDecoder().decode([String].self, from: data)
                    await MainActor.run {
                        self.availableRestaurantIDs = restaurantIDs
                    }
                    debugLog("✅ API ready with \(restaurantIDs.count) restaurants (background)")
                    return
                }
            }
        } catch {
            debugLog("⚠️ API check failed in background (app continues normally): \(error.localizedDescription)")
            // Don't treat this as fatal - app can still work with static data
        }
        
        debugLog("📱 App continues with fallback nutrition data")
    }

    // MARK: - Optimized API Methods
    // OPTIMIZED: Fast API call with better error handling
    private func fetchRestaurantFromAPI(restaurantId: String) async -> RestaurantNutritionData? {
        guard let url = URL(string: "\(baseURL)/restaurants/\(restaurantId)") else {
            debugLog("❌ API ERROR: Invalid URL for \(restaurantId)")
            return nil
        }
        
        do {
            debugLog("🌐 API CALL: Requesting \(restaurantId) from \(baseURL)")
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                debugLog("📊 API RESPONSE: \(httpResponse.statusCode) for \(restaurantId)")
                
                if httpResponse.statusCode != 200 {
                    debugLog("⚠️ API ERROR: Non-200 status \(httpResponse.statusCode) for \(restaurantId)")
                    return nil
                }
            }
            
            let restaurantJSON = try JSONDecoder().decode(RestaurantJSON.self, from: data)
            
            let nutritionItems = restaurantJSON.menu.map { menuItem in
                NutritionData(
                    item: menuItem.Item,
                    calories: menuItem.Calories,
                    fat: menuItem.Fat_g,
                    saturatedFat: menuItem.Saturated_Fat_g,
                    cholesterol: menuItem.Cholesterol_mg,
                    sodium: menuItem.Sodium_mg,
                    carbs: menuItem.Carbs_g,
                    fiber: menuItem.Fiber_g,
                    sugar: menuItem.Sugar_g,
                    protein: menuItem.Protein_g
                )
            }
            
            debugLog("✅ API SUCCESS: \(restaurantJSON.restaurant_name) -> \(nutritionItems.count) menu items parsed")
            
            return RestaurantNutritionData(
                restaurantName: restaurantJSON.restaurant_name,
                items: nutritionItems
            )
        } catch {
            debugLog("🔥 API ERROR: \(restaurantId) failed with error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func loadFromAPI(restaurantName: String) async -> RestaurantNutritionData? {
        if let restaurantId = findRestaurantIdForName(restaurantName) {
            debugLog("📡 API REQUEST: '\(restaurantName)' -> Fetching \(restaurantId)")
            let result = await fetchRestaurantFromAPI(restaurantId: restaurantId)
            
            if result != nil {
                debugLog("✅ API SUCCESS: '\(restaurantName)' -> \(restaurantId) returned data")
            } else {
                debugLog("❌ API FAILED: '\(restaurantName)' -> \(restaurantId) returned no data")
            }
            
            return result
        } else {
            debugLog("❌ API SKIPPED: '\(restaurantName)' -> No ID mapping found")
            return nil
        }
    }
    
    func loadNutritionData(for restaurantName: String) {
        let cacheKey = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let restaurantId = findRestaurantIdForName(restaurantName)
        
        // LOG: Initial attempt
        debugLog("🍽️ NUTRITION LOAD ATTEMPT: '\(restaurantName)' -> ID: \(restaurantId ?? "NOT_FOUND")")
        
        // Fast path: Check cache first
        if let cachedData = nutritionCache.getRestaurant(named: restaurantName) {
            debugLog("✅ NUTRITION SUCCESS (CACHE): '\(restaurantName)' -> \(cachedData.items.count) items from cache")
            isLoading = false
            currentRestaurantData = cachedData
            errorMessage = nil
            cacheHits += 1
            return
        }
        
        // Check if we have an ID mapping
        guard let validRestaurantId = restaurantId else {
            debugLog("❌ NUTRITION FAILED: '\(restaurantName)' -> No ID mapping found")
            isLoading = false
            errorMessage = "Restaurant '\(restaurantName)' not found in our nutrition database"
            return
        }
        
        // Cancel any existing task
        loadingTasks[cacheKey]?.cancel()
        isLoading = true
        errorMessage = nil
        cacheMisses += 1
        
        debugLog("🌐 NUTRITION API CALL: '\(restaurantName)' -> Calling API with ID: \(validRestaurantId)")
        
        let task = Task<RestaurantNutritionData?, Never> { [weak self] in
            guard let self = self else { return nil }
            let result = await self.loadFromAPI(restaurantName: restaurantName)
            
            await MainActor.run {
                self.isLoading = false
                
                if let result = result {
                    debugLog("✅ NUTRITION SUCCESS (API): '\(restaurantName)' -> \(result.items.count) items loaded from API")
                    self.currentRestaurantData = result
                    self.nutritionCache.store(restaurant: result)
                    self.diskCache.store(result)
                } else {
                    debugLog("❌ NUTRITION FAILED (API): '\(restaurantName)' -> API returned no data")
                    self.errorMessage = "Unable to load nutrition data for \(restaurantName). Please try again."
                }
                self.loadingTasks.removeValue(forKey: cacheKey)
            }
            return result
        }
        
        loadingTasks[cacheKey] = task
    }
    
    private func findRestaurantIdForName(_ restaurantName: String) -> String? {
        // Use the centralized helper from RestaurantData
        return RestaurantData.getRestaurantID(for: restaurantName)
    }
    
    func getAvailableRestaurants() -> [String] {
        return nutritionCache.restaurantNames.sorted()
    }
    
    // ENHANCED: Efficient nutrition data availability check
    func hasNutritionData(for restaurantName: String) -> Bool {
        // First check if already in cache
        if nutritionCache.contains(restaurantName: restaurantName) {
            return true
        }
        
        // Use the centralized helper from RestaurantData
        return RestaurantData.hasNutritionData(for: restaurantName)
    }
    
    func clearData() {
        currentRestaurantData = nil
        errorMessage = nil
    }
    
    func getCacheStats() -> (hits: Int, misses: Int, hitRate: Double) {
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        return (cacheHits, cacheMisses, hitRate)
    }
    
    func printPerformanceStats() {
        let stats = getCacheStats()
        debugLog(" NutritionDataManager Performance:")
        debugLog("   Cache Hits: \(stats.hits)")
        debugLog("   Cache Misses: \(stats.misses)")
        debugLog("   Hit Rate: \(stats.hitRate)")
        debugLog("   Available Restaurants: \(availableRestaurantIDs.count)")
        debugLog("   API Restaurant IDs: \(nutritionCache.restaurantNames.count)")
    }
    
    deinit {
        for (_, task) in loadingTasks {
            task.cancel()
        }
        loadingTasks.removeAll()
        debugLog(" NutritionDataManager deinitalized")
    }
}

// MARK: - JSON Data Models
struct RestaurantJSON: Codable {
    let restaurant_id: String
    let restaurant_name: String
    let menu: [MenuItemJSON]
}

struct MenuItemJSON: Codable {
    let Item: String
    let Calories: Double
    let Fat_g: Double
    let Saturated_Fat_g: Double
    let Cholesterol_mg: Double
    let Sodium_mg: Double
    let Carbs_g: Double
    let Fiber_g: Double
    let Sugar_g: Double
    let Protein_g: Double
    
    enum CodingKeys: String, CodingKey {
        case Item
        case Calories
        case Fat_g = "Fat (g)"
        case Saturated_Fat_g = "Saturated Fat (g)"
        case Cholesterol_mg = "Cholesterol (mg)"
        case Sodium_mg = "Sodium (mg)"
        case Carbs_g = "Carbs (g)"
        case Fiber_g = "Fiber (g)"
        case Sugar_g = "Sugar (g)"
        case Protein_g = "Protein (g)"
    }
}
