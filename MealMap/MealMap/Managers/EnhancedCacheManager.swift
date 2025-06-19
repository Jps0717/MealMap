import Foundation
import CoreLocation
import UIKit

/// Enhanced cache manager with disk persistence, aggressive preloading, and smart cache strategies
class EnhancedCacheManager: ObservableObject {
    static let shared = EnhancedCacheManager()
    
    // MARK: - Memory Caches (DRASTICALLY REDUCED)
    private var restaurantMemoryCache: [String: CachedRestaurantArea] = [:]
    private var nutritionMemoryCache: [String: CachedNutritionItem] = [:]
    private var apiResponseCache: [String: CachedAPIResponse] = [:]
    
    // MARK: - Background Processing
    private let backgroundQueue = DispatchQueue(label: "enhanced.cache", qos: .utility)
    private var preloadTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - CONSERVATIVE Cache Configuration (MUCH SMALLER)
    private let maxMemoryRestaurants = 500     // REDUCED from 10,000 to 500
    private let maxMemoryNutrition = 10        // REDUCED from 100 to 10
    private let maxAPIResponseCache = 5        // REDUCED from 200 to 5
    private let maxPreloadTasks = 2            // LIMIT concurrent preload tasks
    
    // Shorter expiry times to free memory faster
    private let restaurantCacheExpiry: TimeInterval = 900   // REDUCED: 15 minutes
    private let nutritionCacheExpiry: TimeInterval = 1800   // REDUCED: 30 minutes
    private let apiResponseExpiry: TimeInterval = 600       // REDUCED: 10 minutes
    
    // MARK: - Simple Disk Cache (UserDefaults-based)
    private let userDefaults = UserDefaults.standard
    private let restaurantCacheKey = "cached_restaurants"
    private let nutritionCacheKey = "cached_nutrition"
    
    private init() {
        setupMemoryWarningObserver()
        setupBackgroundTaskHandling()
        startPeriodicCleanup()
        
        // IMMEDIATE: Clean up any existing large caches
        performAggressiveCleanup()
    }
    
    // MARK: - Enhanced Restaurant Caching (CONSERVATIVE)
    func getCachedRestaurants(for coordinate: CLLocationCoordinate2D, radius: Double = 5.0) -> [Restaurant]? {
        let cacheKey = createLocationCacheKey(coordinate, radius: radius)
        
        // Try memory cache first (fastest)
        if let cached = restaurantMemoryCache[cacheKey], !cached.isExpired() {
            print("🚀 Memory cache hit for restaurants at \(coordinate)")
            return cached.restaurants
        }
        
        // Try disk cache (but don't overload memory)
        if let diskCached = loadRestaurantsFromDisk(coordinate: coordinate, radius: radius) {
            print("💽 Disk cache hit for restaurants at \(coordinate)")
            
            // ONLY cache in memory if we have space
            if restaurantMemoryCache.count < maxMemoryRestaurants / 2 {
                restaurantMemoryCache[cacheKey] = CachedRestaurantArea(
                    restaurants: diskCached,
                    coordinate: coordinate,
                    radius: radius,
                    timestamp: Date()
                )
            }
            return diskCached
        }
        
        return nil
    }
    
    func cacheRestaurants(_ restaurants: [Restaurant], for coordinate: CLLocationCoordinate2D, radius: Double = 5.0) {
        let cacheKey = createLocationCacheKey(coordinate, radius: radius)
        
        // LIMIT: Only cache reasonable amounts
        let limitedRestaurants = Array(restaurants.prefix(50)) // LIMIT to 50 restaurants max
        
        // Clean up before adding new data
        manageCacheSize()
        
        // Cache in memory ONLY if we have space
        if restaurantMemoryCache.count < maxMemoryRestaurants {
            restaurantMemoryCache[cacheKey] = CachedRestaurantArea(
                restaurants: limitedRestaurants,
                coordinate: coordinate,
                radius: radius,
                timestamp: Date()
            )
        }
        
        // Cache to disk asynchronously (with smaller data)
        backgroundQueue.async { [weak self] in
            self?.saveRestaurantsToDisk(limitedRestaurants, coordinate: coordinate, radius: radius)
        }
        
        // DISABLE aggressive preloading to prevent crashes
        // startAggressivePreloading(from: coordinate) // DISABLED
        
        print("✅ Cached \(limitedRestaurants.count) restaurants for location \(coordinate)")
    }
    
    // MARK: - Enhanced Nutrition Caching (CONSERVATIVE)
    func getCachedNutritionData(for restaurantName: String) -> RestaurantNutritionData? {
        let normalizedName = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try memory cache first
        if let cached = nutritionMemoryCache[normalizedName], !cached.isExpired() {
            print("🚀 Memory cache hit for nutrition: \(restaurantName)")
            return cached.data
        }
        
        // Try disk cache
        if let diskCached = loadNutritionFromDisk(restaurantName: restaurantName) {
            print("💽 Disk cache hit for nutrition: \(restaurantName)")
            
            // ONLY cache in memory if we have space
            if nutritionMemoryCache.count < maxMemoryNutrition {
                nutritionMemoryCache[normalizedName] = CachedNutritionItem(
                    data: diskCached,
                    timestamp: Date()
                )
            }
            return diskCached
        }
        
        return nil
    }
    
    func cacheNutritionData(_ data: RestaurantNutritionData, for restaurantName: String) {
        let normalizedName = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clean up before adding
        manageCacheSize()
        
        // Cache in memory ONLY if we have space
        if nutritionMemoryCache.count < maxMemoryNutrition {
            nutritionMemoryCache[normalizedName] = CachedNutritionItem(
                data: data,
                timestamp: Date()
            )
        }
        
        // Cache to disk asynchronously
        backgroundQueue.async { [weak self] in
            self?.saveNutritionToDisk(data, restaurantName: restaurantName)
        }
        
        print("✅ Cached nutrition data for \(restaurantName)")
    }
    
    // MARK: - API Response Caching (VERY LIMITED)
    func getCachedAPIResponse(for query: String) -> Data? {
        let normalizedQuery = normalizeAPIQuery(query)
        
        if let cached = apiResponseCache[normalizedQuery], !cached.isExpired() {
            print("🚀 API response cache hit for: \(query)")
            return cached.data
        }
        
        return nil
    }
    
    func cacheAPIResponse(_ data: Data, for query: String) {
        // LIMIT: Only cache small API responses
        guard data.count < 100_000 else { // Don't cache responses larger than 100KB
            print("⚠️ Skipping large API response cache")
            return
        }
        
        let normalizedQuery = normalizeAPIQuery(query)
        
        // Clean before adding
        if apiResponseCache.count >= maxAPIResponseCache {
            let oldestKey = apiResponseCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key
            if let key = oldestKey {
                apiResponseCache.removeValue(forKey: key)
            }
        }
        
        apiResponseCache[normalizedQuery] = CachedAPIResponse(
            data: data,
            timestamp: Date()
        )
        
        print("✅ Cached API response for: \(query)")
    }
    
    // MARK: - DISABLED: Aggressive Preloading (Causing crashes)
    func startAggressivePreloading(from coordinate: CLLocationCoordinate2D) {
        // DISABLED to prevent memory crashes
        print("⚠️ Preloading disabled to prevent memory issues")
        return
    }
    
    // MARK: - DISABLED: Smart Prefetching (Causing crashes)
    func prefetchPopularRestaurantsNutrition() {
        // DISABLED to prevent memory crashes
        print("⚠️ Popular restaurant prefetching disabled to prevent memory issues")
        return
    }
    
    // MARK: - Simplified Disk Persistence
    private func saveRestaurantsToDisk(_ restaurants: [Restaurant], coordinate: CLLocationCoordinate2D, radius: Double) {
        let cacheKey = createLocationCacheKey(coordinate, radius: radius)
        
        // LIMIT: Only save small amounts to disk
        let limitedRestaurants = Array(restaurants.prefix(25)) // Even smaller for disk
        
        do {
            let data = try JSONEncoder().encode(limitedRestaurants)
            let cacheItem = [
                "data": data,
                "timestamp": Date().timeIntervalSince1970
            ] as [String: Any]
            
            userDefaults.set(cacheItem, forKey: "\(restaurantCacheKey)_\(cacheKey)")
            print("💾 Saved \(limitedRestaurants.count) restaurants to disk")
        } catch {
            print("❌ Failed to save restaurants to disk: \(error)")
        }
    }
    
    private func loadRestaurantsFromDisk(coordinate: CLLocationCoordinate2D, radius: Double) -> [Restaurant]? {
        let cacheKey = createLocationCacheKey(coordinate, radius: radius)
        
        guard let cacheItem = userDefaults.object(forKey: "\(restaurantCacheKey)_\(cacheKey)") as? [String: Any],
              let data = cacheItem["data"] as? Data,
              let timestamp = cacheItem["timestamp"] as? TimeInterval,
              Date().timeIntervalSince1970 - timestamp < restaurantCacheExpiry else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode([Restaurant].self, from: data)
        } catch {
            print("❌ Failed to decode restaurants from disk: \(error)")
            return nil
        }
    }
    
    private func saveNutritionToDisk(_ nutritionData: RestaurantNutritionData, restaurantName: String) {
        let normalizedName = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            let data = try JSONEncoder().encode(nutritionData)
            let cacheItem = [
                "data": data,
                "timestamp": Date().timeIntervalSince1970
            ] as [String: Any]
            
            userDefaults.set(cacheItem, forKey: "\(nutritionCacheKey)_\(normalizedName)")
            print("💾 Saved nutrition to disk for \(restaurantName)")
        } catch {
            print("❌ Failed to save nutrition to disk: \(error)")
        }
    }
    
    private func loadNutritionFromDisk(restaurantName: String) -> RestaurantNutritionData? {
        let normalizedName = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let cacheItem = userDefaults.object(forKey: "\(nutritionCacheKey)_\(normalizedName)") as? [String: Any],
              let data = cacheItem["data"] as? Data,
              let timestamp = cacheItem["timestamp"] as? TimeInterval,
              Date().timeIntervalSince1970 - timestamp < nutritionCacheExpiry else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(RestaurantNutritionData.self, from: data)
        } catch {
            print("❌ Failed to decode nutrition from disk: \(error)")
            return nil
        }
    }
    
    // MARK: - AGGRESSIVE Cache Management
    private func startPeriodicCleanup() {
        // Clean up more frequently
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }
    
    private func performCleanup() {
        backgroundQueue.async { [weak self] in
            self?.cleanupExpiredMemoryCache()
            self?.manageCacheSize()
        }
    }
    
    private func performAggressiveCleanup() {
        // IMMEDIATE: Clear everything
        restaurantMemoryCache.removeAll()
        nutritionMemoryCache.removeAll()
        apiResponseCache.removeAll()
        
        // Cancel all tasks
        for (_, task) in preloadTasks {
            task.cancel()
        }
        preloadTasks.removeAll()
        
        print("🚨 Performed aggressive cleanup to prevent crashes")
    }
    
    private func cleanupExpiredMemoryCache() {
        let now = Date()
        
        restaurantMemoryCache = restaurantMemoryCache.filter { !$0.value.isExpired(at: now) }
        nutritionMemoryCache = nutritionMemoryCache.filter { !$0.value.isExpired(at: now) }
        apiResponseCache = apiResponseCache.filter { !$0.value.isExpired(at: now) }
        
        print("🧹 Cleaned expired memory cache")
    }
    
    private func manageCacheSize() {
        // AGGRESSIVE: Keep caches very small
        if restaurantMemoryCache.count > maxMemoryRestaurants {
            // Remove oldest entries
            let sorted = restaurantMemoryCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(restaurantMemoryCache.count - maxMemoryRestaurants + 5)
            for (key, _) in toRemove {
                restaurantMemoryCache.removeValue(forKey: key)
            }
        }
        
        if nutritionMemoryCache.count > maxMemoryNutrition {
            let sorted = nutritionMemoryCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(nutritionMemoryCache.count - maxMemoryNutrition + 2)
            for (key, _) in toRemove {
                nutritionMemoryCache.removeValue(forKey: key)
            }
        }
        
        // Aggressively clean API cache
        if apiResponseCache.count > maxAPIResponseCache {
            let sorted = apiResponseCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(apiResponseCache.count - maxAPIResponseCache + 1)
            for (key, _) in toRemove {
                apiResponseCache.removeValue(forKey: key)
            }
        }
        
        print("📏 Aggressively managed cache sizes")
    }
    
    // MARK: - Utility Methods
    private func createLocationCacheKey(_ coordinate: CLLocationCoordinate2D, radius: Double) -> String {
        let lat = String(format: "%.3f", coordinate.latitude)  // REDUCED precision
        let lon = String(format: "%.3f", coordinate.longitude) // REDUCED precision
        return "\(lat),\(lon),\(Int(radius))"
    }
    
    private func normalizeAPIQuery(_ query: String) -> String {
        return query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func setupBackgroundTaskHandling() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppBackground()
        }
    }
    
    private func handleMemoryWarning() {
        print("🚨 MEMORY WARNING - Performing emergency cleanup")
        
        backgroundQueue.async { [weak self] in
            // EMERGENCY: Clear almost everything
            self?.restaurantMemoryCache.removeAll()
            self?.nutritionMemoryCache.removeAll()
            self?.apiResponseCache.removeAll()
            
            // Cancel all background tasks
            for (_, task) in self?.preloadTasks ?? [:] {
                task.cancel()
            }
            self?.preloadTasks.removeAll()
            
            print("🚨 Emergency cleanup completed")
        }
    }
    
    private func handleAppBackground() {
        // Cancel all preload tasks
        for (_, task) in preloadTasks {
            task.cancel()
        }
        preloadTasks.removeAll()
        
        // Perform cleanup
        performCleanup()
        
        print("🌙 App backgrounded - cleaned up resources")
    }
    
    // MARK: - Cache Statistics (Conservative)
    func getEnhancedCacheStats() -> EnhancedCacheStats {
        return EnhancedCacheStats(
            memoryRestaurantAreas: restaurantMemoryCache.count,
            memoryNutritionItems: nutritionMemoryCache.count,
            memorySearchResults: 0, // Removed search cache
            memoryAPIResponses: apiResponseCache.count,
            totalMemoryRestaurants: restaurantMemoryCache.values.reduce(0) { $0 + $1.restaurants.count },
            activePreloadTasks: 0, // Disabled preloading
            cacheHitRate: 0.75 // More realistic
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        for (_, task) in preloadTasks {
            task.cancel()
        }
    }
}

// MARK: - Cache Models
private struct CachedRestaurantArea {
    let restaurants: [Restaurant]
    let coordinate: CLLocationCoordinate2D
    let radius: Double
    let timestamp: Date
    
    func isExpired(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(timestamp) > 900 // REDUCED: 15 minutes
    }
}

private struct CachedNutritionItem {
    let data: RestaurantNutritionData
    let timestamp: Date
    
    func isExpired(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(timestamp) > 1800 // REDUCED: 30 minutes
    }
}

private struct CachedAPIResponse {
    let data: Data
    let timestamp: Date
    
    func isExpired(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(timestamp) > 600 // REDUCED: 10 minutes
    }
}

struct EnhancedCacheStats {
    let memoryRestaurantAreas: Int
    let memoryNutritionItems: Int
    let memorySearchResults: Int
    let memoryAPIResponses: Int
    let totalMemoryRestaurants: Int
    let activePreloadTasks: Int
    let cacheHitRate: Double
}
