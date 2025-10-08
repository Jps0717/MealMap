import Foundation
import CoreLocation
import SwiftUI
import MapKit

/// Background data loader that handles all API operations without blocking the UI
@MainActor
final class BackgroundDataLoader: ObservableObject {
    static let shared = BackgroundDataLoader()
    
    // MARK: - Published Properties (for monitoring only, not for UI blocking)
    @Published private(set) var isBackgroundLoading = false
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var cacheStats = CacheStats()
    
    // MARK: - Private Properties
    private let overpassService = OverpassAPIService()
    private let nutritionManager = NutritionDataManager.shared
    
    // MARK: - Aggressive Caching System
    private var restaurantCache: [String: CachedRestaurantData] = [:]
    private var nutritionCache: [String: Date] = [:] // Track preloaded nutrition
    private let cacheQueue = DispatchQueue(label: "BackgroundDataLoader.cache", qos: .utility)
    
    // MARK: - Background Task Management
    private var activeBackgroundTasks: Set<String> = []
    private let backgroundQueue = DispatchQueue(label: "BackgroundDataLoader.background", qos: .background)
    
    // MARK: - Configuration
    private let cacheExpiryTime: TimeInterval = 1800 // 30 minutes (aggressive caching)
    private let cacheRadius: Double = 10.0 // 10 mile radius (large coverage)
    private let minUpdateInterval: TimeInterval = 300 // 5 minutes minimum between updates for same area
    private let maxConcurrentTasks = 3
    
    private init() {
        debugLog("🔄 BackgroundDataLoader initialized with aggressive caching")
    }
}

// MARK: - Cache Data Models
struct CachedRestaurantData {
    let restaurants: [Restaurant]
    let location: CLLocationCoordinate2D
    let radius: Double
    let timestamp: Date
    let bounds: GeographicBounds
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 1800 // 30 minutes
    }
    
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return bounds.contains(coordinate)
    }
}

struct GeographicBounds {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    
    init(center: CLLocationCoordinate2D, radiusInDegrees: Double) {
        self.minLat = center.latitude - radiusInDegrees
        self.maxLat = center.latitude + radiusInDegrees
        self.minLon = center.longitude - radiusInDegrees
        self.maxLon = center.longitude + radiusInDegrees
    }
    
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude >= minLat &&
               coordinate.latitude <= maxLat &&
               coordinate.longitude >= minLon &&
               coordinate.longitude <= maxLon
    }
}

struct CacheStats {
    var totalCachedAreas = 0
    var cacheHitRate: Double = 0.0
    var backgroundTasksActive = 0
    var lastCacheUpdate: Date?
}

// MARK: - Public API
extension BackgroundDataLoader {
    
    /// Get restaurants for location immediately from cache, trigger background refresh if needed
    func getRestaurants(for location: CLLocationCoordinate2D, completion: @escaping ([Restaurant]) -> Void) {
        debugLog("🔄 BackgroundDataLoader: Getting restaurants for \(location)")
        
        // IMMEDIATE: Check cache first
        if let cachedData = getCachedRestaurants(for: location) {
            debugLog("✅ Cache HIT: Returning \(cachedData.restaurants.count) cached restaurants")
            completion(cachedData.restaurants)
            
            // BACKGROUND: Refresh if data is older than 15 minutes
            if Date().timeIntervalSince(cachedData.timestamp) > 900 {
                triggerBackgroundRefresh(for: location)
            }
            return
        }
        
        debugLog("❌ Cache MISS: No cached data, starting background load")
        
        // No cached data - start background load and return empty array for now
        completion([])
        triggerBackgroundRefresh(for: location)
    }
    
    /// Preload large geographic area in background during app startup
    func preloadDataForRegion(_ region: MKCoordinateRegion) {
        let taskId = "preload_\(UUID().uuidString.prefix(8))"
        
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run {
                self.activeBackgroundTasks.insert(taskId)
                self.updateBackgroundStatus()
            }
            
            defer {
                Task { @MainActor in
                    self.activeBackgroundTasks.remove(taskId)
                    self.updateBackgroundStatus()
                }
            }
            
            do {
                // Load large area around region center
                let restaurants = try await self.overpassService.fetchAllNearbyRestaurants(
                    near: region.center,
                    radius: self.cacheRadius
                )
                
                await MainActor.run {
                    self.storeCachedRestaurants(restaurants, for: region.center, radius: self.cacheRadius)
                    debugLog("🚀 Preloaded \(restaurants.count) restaurants for region")
                }
                
                // Preload nutrition for popular chains
                await self.preloadNutritionData(for: restaurants)
                
            } catch {
                debugLog("❌ Preload failed: \(error)")
            }
        }
    }
    
    /// Lazy load nutrition data only when user taps restaurant
    func loadNutritionDataLazy(for restaurantName: String) {
        let cacheKey = restaurantName.lowercased()
        
        // Check if already loaded or loading
        guard nutritionCache[cacheKey] == nil else { return }
        
        nutritionCache[cacheKey] = Date() // Mark as loading
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            debugLog("🍽️ Lazy loading nutrition for: \(restaurantName)")
            await MainActor.run {
                self.nutritionManager.loadNutritionData(for: restaurantName)
            }
        }
    }
}

// MARK: - Private Implementation
private extension BackgroundDataLoader {
    
    func getCachedRestaurants(for location: CLLocationCoordinate2D) -> CachedRestaurantData? {
        return cacheQueue.sync {
            for cachedData in self.restaurantCache.values {
                if !cachedData.isExpired && cachedData.contains(location) {
                    return cachedData
                }
            }
            return nil
        }
    }
    
    func storeCachedRestaurants(_ restaurants: [Restaurant], for location: CLLocationCoordinate2D, radius: Double) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            let radiusInDegrees = radius / 69.0 // Approximate degrees per mile
            let bounds = GeographicBounds(center: location, radiusInDegrees: radiusInDegrees)
            
            let cachedData = CachedRestaurantData(
                restaurants: restaurants,
                location: location,
                radius: radius,
                timestamp: Date(),
                bounds: bounds
            )
            
            let cacheKey = "\(location.latitude)_\(location.longitude)"
            
            Task { @MainActor in
                self.restaurantCache[cacheKey] = cachedData
                self.cacheStats.totalCachedAreas = self.restaurantCache.count
                self.cacheStats.lastCacheUpdate = Date()
            }
            
            debugLog("💾 Cached \(restaurants.count) restaurants for \(radius) mile radius")
        }
    }
    
    func triggerBackgroundRefresh(for location: CLLocationCoordinate2D) {
        let taskId = "refresh_\(location.latitude)_\(location.longitude)"
        
        // Prevent duplicate tasks for same location
        guard !activeBackgroundTasks.contains(taskId) else { return }
        
        // Limit concurrent background tasks
        guard activeBackgroundTasks.count < maxConcurrentTasks else {
            debugLog("🚫 Max background tasks reached, skipping refresh")
            return
        }
        
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run {
                self.activeBackgroundTasks.insert(taskId)
                self.updateBackgroundStatus()
            }
            
            defer {
                Task { @MainActor in
                    self.activeBackgroundTasks.remove(taskId)
                    self.updateBackgroundStatus()
                }
            }
            
            // Add small delay to prevent API hammering
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            do {
                debugLog("🔄 Background refresh starting for \(location)")
                
                let restaurants = try await self.overpassService.fetchAllNearbyRestaurants(
                    near: location,
                    radius: self.cacheRadius
                )
                
                await MainActor.run {
                    self.storeCachedRestaurants(restaurants, for: location, radius: self.cacheRadius)
                    self.lastUpdateTime = Date()
                    debugLog("✅ Background refresh completed: \(restaurants.count) restaurants")
                }
                
                // Preload nutrition for top 5 chains
                let topChains = Array(restaurants.filter { $0.hasNutritionData }.prefix(5))
                await self.preloadNutritionData(for: topChains)
                
            } catch {
                debugLog("❌ Background refresh failed: \(error)")
            }
        }
    }
    
    func preloadNutritionData(for restaurants: [Restaurant]) async {
        let nutritionRestaurants = restaurants.filter { $0.hasNutritionData }
        
        for (index, restaurant) in nutritionRestaurants.enumerated() {
            // Skip if already loaded
            let cacheKey = restaurant.name.lowercased()
            guard nutritionCache[cacheKey] == nil else { continue }
            
            nutritionCache[cacheKey] = Date()
            
            // Add delay between requests to avoid overwhelming API
            if index > 0 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
            }
            
            Task.detached(priority: .background) { [weak self] in
                guard let self = self else { return }
                await MainActor.run {
                    self.nutritionManager.loadNutritionData(for: restaurant.name)
                }
            }
        }
        
        debugLog("🍽️ Preloaded nutrition for \(nutritionRestaurants.count) restaurants")
    }
    
    func updateBackgroundStatus() {
        isBackgroundLoading = !activeBackgroundTasks.isEmpty
        cacheStats.backgroundTasksActive = activeBackgroundTasks.count
    }
}

// MARK: - Cache Management
extension BackgroundDataLoader {
    
    /// Clear expired cache entries
    func cleanupExpiredCache() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                let initialCount = self.restaurantCache.count
                self.restaurantCache = self.restaurantCache.filter { !$0.value.isExpired }
                
                let removedCount = initialCount - self.restaurantCache.count
                if removedCount > 0 {
                    debugLog("🧹 Cleaned up \(removedCount) expired cache entries")
                }
                
                self.cacheStats.totalCachedAreas = self.restaurantCache.count
            }
        }
    }
    
    /// Get current cache status for debugging
    func getCacheStatus() -> String {
        let validCaches = self.restaurantCache.values.filter { !$0.isExpired }
        return "Cache: \(validCaches.count) areas, \(self.activeBackgroundTasks.count) background tasks"
    }
}