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
        // Configure session for better performance and Render cold start handling
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0 // Increased to handle Render cold start (50s+)
        config.timeoutIntervalForResource = 90.0 // Total timeout for resource
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 2 // Reduced to avoid overwhelming
        self.session = URLSession(configuration: config)

        // Prime in-memory cache from persisted disk cache
        let persisted = diskCache.allEntries
        for entry in persisted {
            nutritionCache.store(restaurant: entry)
        }

        debugLog(" NutritionDataManager singleton initialized (restored \(persisted.count) cached restaurants)")
    }
    
    // MARK: - Startup Methods - Lightweight Initialization Only
    func initializeIfNeeded() async {
        guard !hasCheckedAPIAvailability else { return }
        hasCheckedAPIAvailability = true
        
        debugLog("🚀 Starting lightweight API initialization...")
        
        // Only check API availability - don't preload any actual data
        await checkAPIAvailability()
        
        debugLog("✅ API availability check completed")
    }
    
    // ENHANCED: Just check if API is available - no data preloading
    private func checkAPIAvailability() async {
        guard availableRestaurantIDs.isEmpty else {
            debugLog(" Restaurant IDs already loaded")
            return
        }
        
        guard let url = URL(string: "\(baseURL)/restaurants") else {
            debugLog(" Invalid API URL")
            return
        }
        
        debugLog(" Checking API availability (lightweight check)")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                debugLog(" API Response: Status \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let restaurantIDs = try JSONDecoder().decode([String].self, from: data)
                    self.availableRestaurantIDs = restaurantIDs
                    debugLog(" API is available with \(restaurantIDs.count) restaurants")
                    return
                } else {
                    debugLog(" API returned status \(httpResponse.statusCode)")
                }
            } else {
                debugLog(" No HTTP response received")
            }
        } catch {
            debugLog(" API availability check failed: \(error.localizedDescription)")
            debugLog(" Will use static restaurant list for hasNutritionData checks")
        }
    }

    // MARK: - Optimized API Methods
    private func fetchRestaurantFromAPI(restaurantId: String) async -> RestaurantNutritionData? {
        guard let url = URL(string: "\(baseURL)/restaurants/\(restaurantId)") else {
            debugLog(" Invalid restaurant API URL for \(restaurantId)")
            return nil
        }
        
        do {
            debugLog(" Fetching \(restaurantId) from API...")
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                debugLog(" API returned status \(httpResponse.statusCode) for \(restaurantId)")
                return nil
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
            
            debugLog(" Successfully fetched \(restaurantJSON.restaurant_name) with \(nutritionItems.count) items")
            
            return RestaurantNutritionData(
                restaurantName: restaurantJSON.restaurant_name,
                items: nutritionItems
            )
        } catch {
            debugLog(" Failed to fetch \(restaurantId) from API: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func loadFromAPI(restaurantName: String) async -> RestaurantNutritionData? {
        if let restaurantId = findRestaurantIdForName(restaurantName) {
            return await fetchRestaurantFromAPI(restaurantId: restaurantId)
        }
        return nil
    }
    
    private func findRestaurantIdForName(_ restaurantName: String) -> String? {
        let restaurantMapping: [String: String] = [
            "mcdonalds": "R0056", "mcdonald's": "R0056",
            "subway": "R0083", "starbucks": "R0081",
            "burger king": "R0010", "kfc": "R0048",
            "taco bell": "R0085", "pizza hut": "R0068",
            "dominos": "R0029", "domino's": "R0029",
            "chick-fil-a": "R0017", "chick fil a": "R0017",
            "wendys": "R0089", "wendy's": "R0089",
            "chipotle": "R0020", "panera": "R0064", "panera bread": "R0064",
            "dunkin": "R0030", "dunkin donuts": "R0030"
        ]
        
        let lowercased = restaurantName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
        
        return restaurantMapping[lowercased]
    }
    
    func loadNutritionData(for restaurantName: String) {
        let cacheKey = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fast path: Check cache first
        if let cachedData = nutritionCache.getRestaurant(named: restaurantName) {
            isLoading = false
            currentRestaurantData = cachedData
            errorMessage = nil
            cacheHits += 1
            return
        }
        
        // Cancel any existing task
        loadingTasks[cacheKey]?.cancel()
        isLoading = true
        errorMessage = nil
        cacheMisses += 1
        
        let task = Task<RestaurantNutritionData?, Never> { [weak self] in
            guard let self = self else { return nil }
            let result = await self.loadFromAPI(restaurantName: restaurantName)
            
            await MainActor.run {
                self.isLoading = false
                self.currentRestaurantData = result
                if let result = result {
                    self.nutritionCache.store(restaurant: result)
                    self.diskCache.store(result)
                } else {
                    self.errorMessage = "No nutrition data available for "
                }
                self.loadingTasks.removeValue(forKey: cacheKey)
            }
            return result
        }
        
        loadingTasks[cacheKey] = task
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
        
        // Check against static list of known restaurants with nutrition data
        let normalizedName = restaurantName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
        
        // Check static list first (faster)
        let hasStaticData = RestaurantData.restaurantsWithNutritionData.contains { knownRestaurant in
            let normalizedKnown = knownRestaurant.lowercased()
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: ".", with: "")
            return normalizedName.contains(normalizedKnown) || normalizedKnown.contains(normalizedName)
        }
        
        // Also check if we have an API mapping for it
        let hasAPIMapping = findRestaurantIdForName(restaurantName) != nil
        
        return hasStaticData || hasAPIMapping
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
        debugLog("   Cache Hits: ")
        debugLog("   Cache Misses: ")
        debugLog("   Hit Rate: ")
        debugLog("   Available Restaurants: ")
        debugLog("   API Restaurant IDs: ")
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
