import SwiftUI
import MapKit
import CoreLocation

/// Ultra-lightweight caching system specifically optimized for map pin performance
final class MapPinCache: ObservableObject {
    static let shared = MapPinCache()
    
    // MARK: - Cache Storage
    private var pinDataCache: [String: CachedPinData] = [:]
    private var visibilityCache: [String: [Restaurant]] = [:]
    private let maxCacheSize = 20
    private let cacheExpiry: TimeInterval = 300 // 5 minutes
    
    // MARK: - Performance Tracking
    private var lastCleanup: Date = Date()
    private let cleanupInterval: TimeInterval = 120 // 2 minutes
    
    private init() {
        startPeriodicCleanup()
    }
    
    // MARK: - Pin Data Caching
    func getCachedPins(for region: MKCoordinateRegion, restaurants: [Restaurant]) -> [Restaurant]? {
        let key = regionKey(region)
        
        // Check if we have valid cached data
        if let cached = pinDataCache[key],
           !cached.isExpired,
           cached.sourceCount == restaurants.count {
            return cached.displayRestaurants
        }
        
        return nil
    }
    
    func cachePins(_ restaurants: [Restaurant], for region: MKCoordinateRegion, from source: [Restaurant]) {
        let key = regionKey(region)
        
        // Limit cache size
        if pinDataCache.count >= maxCacheSize {
            // Remove oldest entries
            let sortedKeys = pinDataCache.keys.sorted { key1, key2 in
                pinDataCache[key1]?.timestamp ?? Date.distantPast <
                pinDataCache[key2]?.timestamp ?? Date.distantPast
            }
            
            for oldKey in sortedKeys.prefix(5) {
                pinDataCache.removeValue(forKey: oldKey)
            }
        }
        
        pinDataCache[key] = CachedPinData(
            displayRestaurants: restaurants,
            sourceCount: source.count,
            region: region,
            timestamp: Date()
        )
    }
    
    // MARK: - Visibility Optimization
    func getVisibleRestaurants(in region: MKCoordinateRegion, from restaurants: [Restaurant]) -> [Restaurant] {
        let key = regionKey(region)
        
        // Check cache first
        if let cached = visibilityCache[key] {
            // Verify cache is still valid for current restaurant set
            let currentIds = Set(restaurants.map { $0.id })
            let cachedIds = Set(cached.map { $0.id })
            
            if cachedIds.isSubset(of: currentIds) && cached.count <= getOptimalPinCount(for: region) {
                return cached
            }
        }
        
        // Calculate visible restaurants
        let visible = calculateVisibleRestaurants(in: region, from: restaurants)
        visibilityCache[key] = visible
        
        return visible
    }
    
    private func calculateVisibleRestaurants(in region: MKCoordinateRegion, from restaurants: [Restaurant]) -> [Restaurant] {
        let optimalCount = getOptimalPinCount(for: region)
        
        // Fast path for small datasets
        if restaurants.count <= optimalCount {
            return restaurants
        }
        
        // Pre-allocate arrays for better performance
        var nutritionRestaurants: [Restaurant] = []
        var regularRestaurants: [Restaurant] = []
        nutritionRestaurants.reserveCapacity(restaurants.count / 2)
        regularRestaurants.reserveCapacity(restaurants.count / 2)
        
        // Single pass separation
        for restaurant in restaurants {
            if restaurant.hasNutritionData {
                nutritionRestaurants.append(restaurant)
            } else {
                regularRestaurants.append(restaurant)
            }
        }
        
        // Allocate slots: prioritize nutrition restaurants
        let nutritionSlots = min(nutritionRestaurants.count, optimalCount * 3 / 4) // 75% for nutrition
        let regularSlots = optimalCount - nutritionSlots
        
        var result: [Restaurant] = []
        result.reserveCapacity(optimalCount)
        
        // Add top nutrition restaurants
        result.append(contentsOf: nutritionRestaurants.prefix(nutritionSlots))
        
        // Fill remaining slots with regular restaurants
        if regularSlots > 0 {
            result.append(contentsOf: regularRestaurants.prefix(regularSlots))
        }
        
        return result
    }
    
    private func getOptimalPinCount(for region: MKCoordinateRegion) -> Int {
        switch region.span.latitudeDelta {
        case 0...0.005: return 25
        case 0.005...0.02: return 20
        case 0.02...0.05: return 12
        case 0.05...0.1: return 8
        default: return 5
        }
    }
    
    // MARK: - Cache Management
    private func regionKey(_ region: MKCoordinateRegion) -> String {
        // Create key with appropriate precision for caching
        return String(format: "%.4f_%.4f_%.3f", 
                     region.center.latitude, 
                     region.center.longitude, 
                     region.span.latitudeDelta)
    }
    
    private func startPeriodicCleanup() {
        Task.detached { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 120_000_000_000) // 2 minutes
                await self?.performCleanup()
            }
        }
    }
    
    @MainActor
    private func performCleanup() {
        let now = Date()
        
        // Clean expired pin data
        pinDataCache = pinDataCache.filter { _, cached in
            !cached.isExpired
        }
        
        // Clean visibility cache (simpler cleanup)
        if now.timeIntervalSince(lastCleanup) > cleanupInterval {
            if visibilityCache.count > maxCacheSize {
                visibilityCache.removeAll()
            }
            lastCleanup = now
        }
        
        debugLog("🧹 MapPinCache cleanup: \(pinDataCache.count) pin caches, \(visibilityCache.count) visibility caches")
    }
    
    func clearCache() {
        pinDataCache.removeAll()
        visibilityCache.removeAll()
    }
}

// MARK: - Cache Data Models
private struct CachedPinData {
    let displayRestaurants: [Restaurant]
    let sourceCount: Int
    let region: MKCoordinateRegion
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
    }
}

// MARK: - Performance Extensions
extension MKCoordinateRegion {
    var cacheKey: String {
        String(format: "%.4f_%.4f_%.3f", center.latitude, center.longitude, span.latitudeDelta)
    }
}