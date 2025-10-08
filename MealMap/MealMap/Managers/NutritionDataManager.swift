import Foundation
import UIKit

/// Enhanced nutrition data manager with comprehensive fallback system
@MainActor
class NutritionDataManager: ObservableObject {
    @Published var isLoading = false
    @Published var currentRestaurantData: RestaurantNutritionData?
    @Published var errorMessage: String?
    @Published var loadingState: LoadingState = .idle
    
    // ENHANCED: Batch loading tracking
    @Published var isBatchLoading = false
    @Published var batchLoadingProgress: Double = 0.0
    @Published var batchLoadingStatus: String = ""
    
    // MARK: - Singleton Pattern
    static let shared = NutritionDataManager()
    
    // MARK: - API Configuration
    private let baseURL = "https://meal-map-api.onrender.com"
    private let session: URLSession
    
    // MARK: - Enhanced Cache System
    private var nutritionCache = NutritionCache()
    private let diskCache = NutritionDiskCache()
    private var loadingTasks: [String: Task<RestaurantNutritionData?, Never>] = [:]
    private var availableRestaurantIDs: [String] = []
    
    // MARK: - Fallback System
    private var apiHealth: APIHealthStatus = .unknown
    private var lastAPICheck: Date = .distantPast
    private let apiHealthCheckInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Retry Logic
    private var retryAttempts: [String: Int] = [:]
    private let maxRetries = 3
    private let retryDelays: [TimeInterval] = [1.0, 2.0, 5.0] // Exponential backoff
    
    // MARK: - Performance Tracking
    private var cacheHits = 0
    private var cacheMisses = 0
    private var apiSuccesses = 0
    private var apiFailures = 0
    private var staticFallbacks = 0
    
    // MARK: - Loading States
    enum LoadingState {
        case idle
        case checkingCache
        case loadingFromAPI
        case retryingAPI
        case loadingFromStatic
        case failed
        case success
    }
    
    enum APIHealthStatus {
        case unknown
        case healthy
        case degraded
        case offline
    }
    
    private init() {
        // OPTIMIZED: Configure session for reliable API access with fallbacks
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0 // Longer timeout for reliability
        config.timeoutIntervalForResource = 15.0 // Allow time for retries
        config.requestCachePolicy = .useProtocolCachePolicy
        config.httpMaximumConnectionsPerHost = 5
        config.waitsForConnectivity = true // Wait briefly for connectivity
        self.session = URLSession(configuration: config)

        // Prime in-memory cache from persisted disk cache
        let persisted = diskCache.allEntries
        for entry in persisted {
            nutritionCache.store(restaurant: entry)
        }

        debugLog(" NutritionDataManager initialized with robust fallback system (restored \(persisted.count) cached restaurants)")
    }
    
    // MARK: - Enhanced Startup Methods
    func initializeIfNeeded() async {
        debugLog(" Initializing nutrition system with fallback support...")
        
        // Background API health check
        Task.detached(priority: .background) { [weak self] in
            await self?.checkAPIHealth()
        }
        
        // Preload popular restaurants in background
        Task.detached(priority: .background) { [weak self] in
            await self?.preloadPopularRestaurants()
        }
        
        debugLog(" Nutrition system initialized with fallback support")
    }
    
    // MARK: - API Health Monitoring
    private func checkAPIHealth() async {
        let now = Date()
        guard now.timeIntervalSince(lastAPICheck) > apiHealthCheckInterval else {
            return
        }
        lastAPICheck = now
        
        guard let url = URL(string: "\(baseURL)/restaurants") else {
            await MainActor.run {
                self.apiHealth = .offline
            }
            return
        }
        
        debugLog(" Checking API health...")
        
        do {
            let request = URLRequest(url: url, timeoutInterval: 5.0)
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                await MainActor.run {
                    switch httpResponse.statusCode {
                    case 200...299:
                        self.apiHealth = .healthy
                        debugLog(" API is healthy")
                    case 500...599:
                        self.apiHealth = .degraded
                        debugLog(" API is degraded")
                    default:
                        self.apiHealth = .offline
                        debugLog(" API is offline")
                    }
                }
                
                if httpResponse.statusCode == 200 {
                    let restaurantIDs = try JSONDecoder().decode([String].self, from: data)
                    await MainActor.run {
                        self.availableRestaurantIDs = restaurantIDs
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.apiHealth = .offline
            }
            debugLog(" API health check failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Enhanced Load Method with Comprehensive Fallback
    func loadNutritionData(for restaurantName: String) {
        let cacheKey = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        debugLog(" ENHANCED LOAD: '\(restaurantName)' starting comprehensive load process")
        
        // Prevent duplicate requests
        if loadingTasks[cacheKey] != nil {
            debugLog(" Already loading '\(restaurantName)', skipping duplicate request")
            return
        }
        
        // Reset state
        errorMessage = nil
        retryAttempts[cacheKey] = 0
        
        let task = Task<RestaurantNutritionData?, Never> { [weak self] in
            guard let self = self else { return nil }
            
            // TIER 1: Memory Cache (Fastest)
            await MainActor.run { self.loadingState = .checkingCache }
            if let cachedData = self.nutritionCache.getRestaurant(named: restaurantName) {
                await MainActor.run {
                    self.currentRestaurantData = cachedData
                    self.loadingState = .success
                    self.cacheHits += 1
                }
                debugLog(" TIER 1 SUCCESS: '\(restaurantName)' loaded from memory cache")
                return cachedData
            }
            
            // TIER 2: Disk Cache (Fast)
            if let diskData = self.diskCache.get(restaurantName) {
                await MainActor.run {
                    self.currentRestaurantData = diskData
                    self.nutritionCache.store(restaurant: diskData)
                    self.loadingState = .success
                    self.cacheHits += 1
                }
                debugLog(" TIER 2 SUCCESS: '\(restaurantName)' loaded from disk cache")
                return diskData
            }
            
            // TIER 3: API with Retry Logic (Reliable)
            let apiData = await self.loadFromAPIWithRetry(restaurantName: restaurantName)
            if let apiData = apiData {
                await MainActor.run {
                    self.currentRestaurantData = apiData
                    self.nutritionCache.store(restaurant: apiData)
                    self.diskCache.store(apiData)
                    self.loadingState = .success
                    self.apiSuccesses += 1
                }
                debugLog(" TIER 3 SUCCESS: '\(restaurantName)' loaded from API")
                return apiData
            }
            
            // TIER 4: Static Fallback Data (Emergency)
            await MainActor.run { self.loadingState = .loadingFromStatic }
            if let staticData = StaticNutritionData.getStaticNutritionData(for: restaurantName) {
                await MainActor.run {
                    self.currentRestaurantData = staticData
                    self.nutritionCache.store(restaurant: staticData)
                    self.loadingState = .success
                    self.staticFallbacks += 1
                }
                debugLog(" TIER 4 SUCCESS: '\(restaurantName)' loaded from static fallback")
                return staticData
            }
            
            // ALL TIERS FAILED
            await MainActor.run {
                self.loadingState = .failed
                self.errorMessage = self.generateFallbackErrorMessage(for: restaurantName)
                self.apiFailures += 1
            }
            debugLog(" ALL TIERS FAILED: '\(restaurantName)' could not be loaded from any source")
            return nil
        }
        
        isLoading = true
        loadingTasks[cacheKey] = task
        
        Task {
            _ = await task.value
            await MainActor.run {
                self.isLoading = false
                self.loadingTasks.removeValue(forKey: cacheKey)
            }
        }
    }
    
    // MARK: - Enhanced API Loading with Retry Logic
    private func loadFromAPIWithRetry(restaurantName: String) async -> RestaurantNutritionData? {
        let cacheKey = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        for attempt in 0..<maxRetries {
            await MainActor.run {
                self.loadingState = attempt == 0 ? .loadingFromAPI : .retryingAPI
            }
            
            debugLog(" API ATTEMPT \(attempt + 1)/\(maxRetries): '\(restaurantName)'")
            
            if let data = await loadFromAPI(restaurantName: restaurantName) {
                retryAttempts[cacheKey] = 0
                return data
            }
            
            // Wait before retry (exponential backoff)
            if attempt < maxRetries - 1 {
                let delay = retryDelays[min(attempt, retryDelays.count - 1)]
                debugLog(" Waiting \(delay)s before retry for '\(restaurantName)'")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        retryAttempts[cacheKey] = maxRetries
        debugLog(" API EXHAUSTED: '\(restaurantName)' failed after \(maxRetries) attempts")
        return nil
    }
    
    // MARK: - Original API Method (Enhanced)
    private func loadFromAPI(restaurantName: String) async -> RestaurantNutritionData? {
        guard let restaurantId = RestaurantData.getRestaurantID(for: restaurantName) else {
            debugLog(" No restaurant ID found for '\(restaurantName)'")
            return nil
        }
        
        guard let url = URL(string: "\(baseURL)/restaurants/\(restaurantId)") else {
            debugLog(" Invalid URL for '\(restaurantName)' (\(restaurantId))")
            return nil
        }
        
        do {
            debugLog(" API REQUEST: '\(restaurantName)' -> \(restaurantId)")
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                debugLog(" API RESPONSE: \(httpResponse.statusCode) for '\(restaurantName)'")
                
                guard httpResponse.statusCode == 200 else {
                    debugLog(" API ERROR: Non-200 status \(httpResponse.statusCode) for '\(restaurantName)'")
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
            
            debugLog(" API SUCCESS: '\(restaurantName)' -> \(nutritionItems.count) menu items")
            
            return RestaurantNutritionData(
                restaurantName: restaurantJSON.restaurant_name,
                items: nutritionItems
            )
        } catch {
            debugLog(" API ERROR: '\(restaurantName)' failed with: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Background Preloading
    private func preloadPopularRestaurants() async {
        let popularRestaurants = ["McDonald's", "Subway", "Starbucks", "Taco Bell", "Chipotle"]
        
        for restaurant in popularRestaurants {
            if !nutritionCache.contains(restaurantName: restaurant) && diskCache.get(restaurant) == nil {
                debugLog(" Preloading '\(restaurant)' in background")
                _ = await loadFromAPI(restaurantName: restaurant)
                
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        
        debugLog(" Background preloading completed")
    }
    
    // MARK: - Error Message Generation
    private func generateFallbackErrorMessage(for restaurantName: String) -> String {
        switch apiHealth {
        case .healthy, .unknown:
            return "Unable to load nutrition data for \(restaurantName). Please check your internet connection and try again."
        case .degraded:
            return "Our nutrition service is experiencing issues. Please try again in a few minutes."
        case .offline:
            return "Nutrition service is temporarily unavailable. Please try again later."
        }
    }
    
    // MARK: - Public Helper Methods
    func hasNutritionData(for restaurantName: String) -> Bool {
        return nutritionCache.contains(restaurantName: restaurantName) ||
               diskCache.get(restaurantName) != nil ||
               RestaurantData.hasNutritionData(for: restaurantName) ||
               StaticNutritionData.hasStaticData(for: restaurantName)
    }
    
    func getAvailableRestaurants() -> [String] {
        let cached = nutritionCache.restaurantNames
        let staticRestaurants = StaticNutritionData.availableRestaurants
        let known = RestaurantData.restaurantsWithNutritionData
        
        return Array(Set(cached + staticRestaurants + known)).sorted()
    }
    
    func clearData() {
        currentRestaurantData = nil
        errorMessage = nil
        loadingState = .idle
        retryAttempts.removeAll()
    }
    
    // MARK: - Performance Analytics
    func getPerformanceStats() -> (cacheHits: Int, cacheMisses: Int, apiSuccesses: Int, apiFailures: Int, staticFallbacks: Int, hitRate: Double) {
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        return (cacheHits, cacheMisses, apiSuccesses, apiFailures, staticFallbacks, hitRate)
    }
    
    func printPerformanceStats() {
        let stats = getPerformanceStats()
        debugLog(" NutritionDataManager Performance:")
        debugLog("   Cache Hits: \(stats.cacheHits)")
        debugLog("   Cache Misses: \(stats.cacheMisses)")
        debugLog("   API Successes: \(stats.apiSuccesses)")
        debugLog("   API Failures: \(stats.apiFailures)")
        debugLog("   Static Fallbacks: \(stats.staticFallbacks)")
        debugLog("   Hit Rate: \(String(format: "%.1f", stats.hitRate * 100))%")
        debugLog("   API Health: \(apiHealth)")
    }
    
    // MARK: - Debug Logging
    private func debugLog(_ message: String) {
        print("[NutritionDataManager] \(message)")
    }
    
    // MARK: - Cleanup
    deinit {
        for (_, task) in loadingTasks {
            task.cancel()
        }
        loadingTasks.removeAll()
        print("[NutritionDataManager] NutritionDataManager cleanup completed")
    }
}

// MARK: - Enhanced JSON Data Models
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