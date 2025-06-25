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
    
    // MARK: - Batch Loading Control
    private var batchLoadingTask: Task<Void, Never>?
    private var hasStartedPreloading = false
    
    // MARK: - Performance Tracking
    private var cacheHits = 0
    private var cacheMisses = 0
    
    private init() {
        // Configure session for better performance
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0 // Increased timeout
        config.timeoutIntervalForResource = 15.0
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
    
    // MARK: - Startup Methods
    func initializeIfNeeded() async {
        guard !hasStartedPreloading else { return }
        hasStartedPreloading = true
        
        await loadAvailableRestaurants()
        await preloadCriticalRestaurants()
    }
    
    // MARK: - Optimized Preloading
    private func preloadCriticalRestaurants() async {
        // Only preload the most commonly accessed restaurants
        let criticalChains = [
            "McDonald's", "Subway", "Burger King", "KFC", "Wendy's"
        ]
        
        debugLog(" Preloading critical restaurant data...")
        
        for chain in criticalChains {
            guard !nutritionCache.contains(restaurantName: chain) else { 
                debugLog("  already cached")
                continue 
            }
            
            if let data = await loadFromAPI(restaurantName: chain) {
                nutritionCache.store(restaurant: data)
                diskCache.store(data)
                debugLog(" Preloaded ")
            } else {
                debugLog(" Failed to preload ")
            }
            
            // Longer delay to avoid overwhelming the API
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        debugLog(" Critical preloading completed")
    }
    
    // ENHANCED: Await-able batch loading with progress tracking
    func batchLoadNutritionData(for restaurantNames: [String]) async {
        // Prevent multiple batch operations
        batchLoadingTask?.cancel()
        
        // Filter out already cached restaurants
        let uncachedRestaurants = restaurantNames.filter { !nutritionCache.contains(restaurantName: $0) }
        
        guard !uncachedRestaurants.isEmpty else {
            debugLog(" All restaurants already cached")
            return
        }
        
        // Limit batch size to prevent overwhelming
        let limitedRestaurants = Array(uncachedRestaurants.prefix(5))
        
        await MainActor.run {
            self.isBatchLoading = true
            self.batchLoadingProgress = 0.0
            self.batchLoadingStatus = "Starting batch load..."
        }
        
        var results: [RestaurantNutritionData] = []
        
        debugLog(" Batch loading restaurants...")
        
        for (index, restaurantName) in limitedRestaurants.enumerated() {
            await MainActor.run {
                self.batchLoadingStatus = "Loading ..."
                self.batchLoadingProgress = Double(index) / Double(limitedRestaurants.count)
            }
            
            if let data = await loadFromAPI(restaurantName: restaurantName) {
                nutritionCache.store(restaurant: data)
                diskCache.store(data)
                results.append(data)
                cacheMisses += 1
                debugLog(" Batch loaded ")
            } else {
                debugLog(" Failed to batch load ")
            }
            
            // Delay between requests
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        }
        
        await MainActor.run {
            self.batchLoadingProgress = 1.0
            self.batchLoadingStatus = "Batch loading complete"
            self.isBatchLoading = false
        }
        
        debugLog(" Batch loaded / restaurants")
    }
    
    // MARK: - Old method for backward compatibility
    func batchLoadNutritionData(for restaurantNames: [String]) {
        Task {
            await batchLoadNutritionData(for: restaurantNames)
        }
    }
    
    // MARK: - Optimized API Methods
    private func loadAvailableRestaurants() async {
        guard availableRestaurantIDs.isEmpty else {
            debugLog(" Restaurant IDs already loaded")
            return
        }
        
        guard let url = URL(string: "\(baseURL)/restaurants") else {
            debugLog(" Invalid API URL")
            return
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            let restaurantIDs = try JSONDecoder().decode([String].self, from: data)
            self.availableRestaurantIDs = restaurantIDs
            debugLog(" Loaded  available restaurant IDs from API")
        } catch {
            debugLog(" Failed to load available restaurants: ")
        }
    }
    
    private func fetchRestaurantFromAPI(restaurantId: String) async -> RestaurantNutritionData? {
        guard let url = URL(string: "\(baseURL)/restaurants/\(restaurantId)") else {
            debugLog(" Invalid restaurant API URL for ")
            return nil
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                debugLog(" API returned status  for ")
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
            
            return RestaurantNutritionData(
                restaurantName: restaurantJSON.restaurant_name,
                items: nutritionItems
            )
        } catch {
            debugLog(" Failed to fetch  from API: ")
            return nil
        }
    }
    
    // MARK: - Public API with Fast Path
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
    
    func getAvailableRestaurants() -> [String] {
        return nutritionCache.restaurantNames.sorted()
    }
    
    func hasNutritionData(for restaurantName: String) -> Bool {
        return nutritionCache.contains(restaurantName: restaurantName) ||
               findRestaurantIdForName(restaurantName) != nil
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
