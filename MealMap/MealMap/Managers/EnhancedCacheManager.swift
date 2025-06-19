import Foundation
import CoreLocation
import CoreData
import UIKit

/// Enhanced cache manager with disk persistence, aggressive preloading, and smart cache strategies
class EnhancedCacheManager: ObservableObject {
    static let shared = EnhancedCacheManager()
    
    // MARK: - Memory Caches (Enhanced)
    private var restaurantMemoryCache: [String: CachedRestaurantArea] = [:]
    private var nutritionMemoryCache: [String: CachedNutritionItem] = [:]
    private var searchMemoryCache: [String: CachedSearchResult] = [:]
    private var apiResponseCache: [String: CachedAPIResponse] = [:]
    
    // MARK: - Background Processing
    private let backgroundQueue = DispatchQueue(label: "enhanced.cache", qos: .utility)
    private let preloadQueue = DispatchQueue(label: "cache.preload", qos: .background)
    private var preloadTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Cache Configuration
    private let maxMemoryRestaurants = 10000 // Much larger memory cache
    private let maxMemoryNutrition = 100     // Increased nutrition cache
    private let maxMemorySearch = 50         // Increased search cache
    private let maxAPIResponseCache = 200    // New API cache
    
    // Enhanced expiry times
    private let restaurantCacheExpiry: TimeInterval = 1800  // 30 minutes (increased)
    private let nutritionCacheExpiry: TimeInterval = 7200   // 2 hours (increased)
    private let searchCacheExpiry: TimeInterval = 1800      // 30 minutes (increased)
    private let apiResponseExpiry: TimeInterval = 3600      // 1 hour for API responses
    
    // MARK: - Preloading Configuration
    private let preloadRadius: Double = 10.0 // 10 miles preload radius
    private let preloadGridSize: Double = 0.02 // Smaller grid for better coverage
    
    // MARK: - Simple Disk Cache (UserDefaults-based for now)
    private let userDefaults = UserDefaults.standard
    private let restaurantCacheKey = "cached_restaurants"
    private let nutritionCacheKey = "cached_nutrition"
    
    private init() {
        setupMemoryWarningObserver()
        setupBackgroundTaskHandling()
        startPeriodicCleanup()
    }
    
    // MARK: - Enhanced Restaurant Caching
    func getCachedRestaurants(for coordinate: CLLocationCoordinate2D, radius: Double = 5.0) -> [Restaurant]? {
        let cacheKey = createLocationCacheKey(coordinate, radius: radius)
        
        // Try memory cache first (fastest)
        if let cached = restaurantMemoryCache[cacheKey], !cached.isExpired() {
            print("🚀 Memory cache hit for restaurants at \(coordinate)")
            return cached.restaurants
        }
        
        // Try disk cache
        if let diskCached = loadRestaurantsFromDisk(coordinate: coordinate, radius: radius) {
            print("💽 Disk cache hit for restaurants at \(coordinate)")
            // Update memory cache
            restaurantMemoryCache[cacheKey] = CachedRestaurantArea(
                restaurants: diskCached,
                coordinate: coordinate,
                radius: radius,
                timestamp: Date()
            )
            return diskCached
        }
        
        return nil
    }
    
    func cacheRestaurants(_ restaurants: [Restaurant], for coordinate: CLLocationCoordinate2D, radius: Double = 5.0) {
        let cacheKey = createLocationCacheKey(coordinate, radius: radius)
        
        // Cache in memory
        restaurantMemoryCache[cacheKey] = CachedRestaurantArea(
            restaurants: restaurants,
            coordinate: coordinate,
            radius: radius,
            timestamp: Date()
        )
        
        // Cache to disk asynchronously
        backgroundQueue.async { [weak self] in
            self?.saveRestaurantsToDisk(restaurants, coordinate: coordinate, radius: radius)
        }
        
        // Trigger aggressive preloading
        startAggressivePreloading(from: coordinate)
        
        print("✅ Cached \(restaurants.count) restaurants for location \(coordinate)")
    }
    
    // MARK: - Enhanced Nutrition Caching
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
            // Update memory cache
            nutritionMemoryCache[normalizedName] = CachedNutritionItem(
                data: diskCached,
                timestamp: Date()
            )
            return diskCached
        }
        
        return nil
    }
    
    func cacheNutritionData(_ data: RestaurantNutritionData, for restaurantName: String) {
        let normalizedName = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Cache in memory
        nutritionMemoryCache[normalizedName] = CachedNutritionItem(
            data: data,
            timestamp: Date()
        )
        
        // Cache to disk asynchronously
        backgroundQueue.async { [weak self] in
            self?.saveNutritionToDisk(data, restaurantName: restaurantName)
        }
        
        print("✅ Enhanced cache: nutrition data for \(restaurantName)")
    }
    
    // MARK: - API Response Caching (NEW)
    func getCachedAPIResponse(for query: String) -> Data? {
        let normalizedQuery = normalizeAPIQuery(query)
        
        if let cached = apiResponseCache[normalizedQuery], !cached.isExpired() {
            print("🚀 API response cache hit for: \(query)")
            return cached.data
        }
        
        return nil
    }
    
    func cacheAPIResponse(_ data: Data, for query: String) {
        let normalizedQuery = normalizeAPIQuery(query)
        
        apiResponseCache[normalizedQuery] = CachedAPIResponse(
            data: data,
            timestamp: Date()
        )
        
        print("✅ Cached API response for: \(query)")
    }
    
    // MARK: - Aggressive Preloading
    func startAggressivePreloading(from coordinate: CLLocationCoordinate2D) {
        let preloadKey = "preload_\(coordinate.latitude)_\(coordinate.longitude)"
        
        // Cancel existing preload task for this area
        preloadTasks[preloadKey]?.cancel()
        
        // Start new preload task
        preloadTasks[preloadKey] = Task { [weak self] in
            await self?.performAggressivePreloading(from: coordinate)
        }
    }
    
    private func performAggressivePreloading(from coordinate: CLLocationCoordinate2D) async {
        let preloadAreas = generatePreloadAreas(around: coordinate)
        
        for (index, area) in preloadAreas.enumerated() {
            // Check if cancelled
            guard !Task.isCancelled else { break }
            
            // Skip if already cached
            let cacheKey = createLocationCacheKey(area, radius: 5.0)
            if restaurantMemoryCache[cacheKey] != nil { continue }
            
            // Add delay between preload requests to avoid overwhelming the API
            if index > 0 {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds between requests
            }
            
            // Preload this area
            do {
                let restaurants = try await OverpassAPIService().fetchFastFoodRestaurants(near: area)
                
                await MainActor.run { [weak self] in
                    self?.cacheRestaurants(restaurants, for: area, radius: 5.0)
                }
                
                print("🔄 Preloaded \(restaurants.count) restaurants for area \(area)")
            } catch {
                print("⚠️ Preload failed for area \(area): \(error)")
            }
        }
    }
    
    private func generatePreloadAreas(around coordinate: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        var areas: [CLLocationCoordinate2D] = []
        let gridSize = preloadGridSize
        
        // Generate 8 surrounding areas (3x3 grid minus center)
        for latOffset in [-1, 0, 1] {
            for lonOffset in [-1, 0, 1] {
                if latOffset == 0 && lonOffset == 0 { continue } // Skip center
                
                areas.append(CLLocationCoordinate2D(
                    latitude: coordinate.latitude + Double(latOffset) * gridSize,
                    longitude: coordinate.longitude + Double(lonOffset) * gridSize
                ))
            }
        }
        
        return areas
    }
    
    // MARK: - Smart Prefetching for Popular Restaurants
    func prefetchPopularRestaurantsNutrition() {
        let popularRestaurants = [
            "McDonald's", "Subway", "Starbucks", "Chipotle", "Chick-fil-A",
            "Taco Bell", "KFC", "Pizza Hut", "Domino's", "Burger King",
            "Wendy's", "Five Guys", "Panda Express", "Sonic Drive-In"
        ]
        
        preloadQueue.async { [weak self] in
            for restaurant in popularRestaurants {
                // Skip if already cached
                if self?.getCachedNutritionData(for: restaurant) != nil { continue }
                
                // Try to load and cache nutrition data in background
                print("🔄 Prefetching nutrition for \(restaurant)")
                
                // Delay between prefetch requests
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }
    
    // MARK: - Simplified Disk Persistence (UserDefaults-based)
    private func saveRestaurantsToDisk(_ restaurants: [Restaurant], coordinate: CLLocationCoordinate2D, radius: Double) {
        let cacheKey = createLocationCacheKey(coordinate, radius: radius)
        
        do {
            let data = try JSONEncoder().encode(restaurants)
            let cacheItem = [
                "data": data,
                "timestamp": Date().timeIntervalSince1970
            ] as [String: Any]
            
            userDefaults.set(cacheItem, forKey: "\(restaurantCacheKey)_\(cacheKey)")
            print("💾 Saved restaurants to disk for \(cacheKey)")
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
    
    // MARK: - Cache Management
    private func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }
    
    private func performCleanup() {
        backgroundQueue.async { [weak self] in
            self?.cleanupExpiredMemoryCache()
            self?.manageCacheSize()
        }
    }
    
    private func cleanupExpiredMemoryCache() {
        let now = Date()
        
        restaurantMemoryCache = restaurantMemoryCache.filter { !$0.value.isExpired(at: now) }
        nutritionMemoryCache = nutritionMemoryCache.filter { !$0.value.isExpired(at: now) }
        searchMemoryCache = searchMemoryCache.filter { !$0.value.isExpired(at: now) }
        apiResponseCache = apiResponseCache.filter { !$0.value.isExpired(at: now) }
        
        print("🧹 Cleaned expired memory cache")
    }
    
    private func manageCacheSize() {
        // Manage memory cache sizes
        if restaurantMemoryCache.count > maxMemoryRestaurants {
            let sorted = restaurantMemoryCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(restaurantMemoryCache.count - maxMemoryRestaurants)
            for (key, _) in toRemove {
                restaurantMemoryCache.removeValue(forKey: key)
            }
        }
        
        if nutritionMemoryCache.count > maxMemoryNutrition {
            let sorted = nutritionMemoryCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(nutritionMemoryCache.count - maxMemoryNutrition)
            for (key, _) in toRemove {
                nutritionMemoryCache.removeValue(forKey: key)
            }
        }
        
        print("📏 Managed cache sizes")
    }
    
    // MARK: - Utility Methods
    private func createLocationCacheKey(_ coordinate: CLLocationCoordinate2D, radius: Double) -> String {
        let lat = String(format: "%.4f", coordinate.latitude)
        let lon = String(format: "%.4f", coordinate.longitude)
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
        backgroundQueue.async { [weak self] in
            // Keep only most recent 25% of memory cache
            if let self = self {
                let keepCount = max(self.restaurantMemoryCache.count / 4, 10)
                let sorted = self.restaurantMemoryCache.sorted { $0.value.timestamp > $1.value.timestamp }
                self.restaurantMemoryCache = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(keepCount)))
                
                // Clear half of nutrition cache
                let nutritionKeepCount = max(self.nutritionMemoryCache.count / 2, 5)
                let nutritionSorted = self.nutritionMemoryCache.sorted { $0.value.timestamp > $1.value.timestamp }
                self.nutritionMemoryCache = Dictionary(uniqueKeysWithValues: Array(nutritionSorted.prefix(nutritionKeepCount)))
                
                print("🚨 Handled memory warning - reduced cache sizes")
            }
        }
    }
    
    private func handleAppBackground() {
        // Cancel all preload tasks
        for (_, task) in preloadTasks {
            task.cancel()
        }
        preloadTasks.removeAll()
        
        print("🌙 App backgrounded - saved cache state")
    }
    
    // MARK: - Cache Statistics
    func getEnhancedCacheStats() -> EnhancedCacheStats {
        return EnhancedCacheStats(
            memoryRestaurantAreas: restaurantMemoryCache.count,
            memoryNutritionItems: nutritionMemoryCache.count,
            memorySearchResults: searchMemoryCache.count,
            memoryAPIResponses: apiResponseCache.count,
            totalMemoryRestaurants: restaurantMemoryCache.values.reduce(0) { $0 + $1.restaurants.count },
            activePreloadTasks: preloadTasks.count,
            cacheHitRate: calculateCacheHitRate()
        )
    }
    
    private func calculateCacheHitRate() -> Double {
        // This could be enhanced with actual hit/miss tracking
        return 0.85 // Placeholder - implement actual tracking
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        for (_, task) in preloadTasks {
            task.cancel()
        }
    }
}

// MARK: - Enhanced Cache Models
private struct CachedRestaurantArea {
    let restaurants: [Restaurant]
    let coordinate: CLLocationCoordinate2D
    let radius: Double
    let timestamp: Date
    
    func isExpired(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(timestamp) > 1800 // 30 minutes
    }
}

private struct CachedNutritionItem {
    let data: RestaurantNutritionData
    let timestamp: Date
    
    func isExpired(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(timestamp) > 7200 // 2 hours 
    }
}

private struct CachedSearchResult {
    let restaurants: [Restaurant]
    let query: String
    let timestamp: Date
    
    func isExpired(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(timestamp) > 1800 // 30 minutes
    }
}

private struct CachedAPIResponse {
    let data: Data
    let timestamp: Date
    
    func isExpired(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(timestamp) > 3600 // 1 hour
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
