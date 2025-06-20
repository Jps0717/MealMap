import Foundation
import MapKit
import CoreLocation

// MARK: - Bounding Box Cache Service
final class BoundingBoxCacheService {
    static let shared = BoundingBoxCacheService()
    
    private var cache: [String: CachedRegionData] = [:]
    private let maxCacheSize = 50
    private let cacheExpiry: TimeInterval = 1800 // 30 minutes
    
    private init() {}
    
    // MARK: - Cache Operations
    func getCachedRestaurants(for region: MKCoordinateRegion) -> [Restaurant]? {
        let key = cacheKey(for: region)
        
        guard var cached = cache[key],
              !cached.isExpired else {
            cache.removeValue(forKey: key)
            return nil
        }
        
        cached.lastAccessed = Date()
        cache[key] = cached // Update the cache with new access time
        return cached.restaurants
    }
    
    func cacheRestaurants(_ restaurants: [Restaurant], for region: MKCoordinateRegion) {
        let key = cacheKey(for: region)
        
        // Remove oldest entries if cache is full
        if cache.count >= maxCacheSize {
            removeOldestEntries()
        }
        
        cache[key] = CachedRegionData(
            restaurants: restaurants,
            timestamp: Date(),
            lastAccessed: Date(),
            region: region
        )
        
        print("💾 Cached \(restaurants.count) restaurants for region \(key)")
    }
    
    // MARK: - Cache Management
    private func cacheKey(for region: MKCoordinateRegion) -> String {
        // Create key with appropriate precision for bounding box
        let bbox = region.boundingBox
        return String(format: "%.3f_%.3f_%.3f_%.3f", 
                     bbox.minLat, bbox.minLon, bbox.maxLat, bbox.maxLon)
    }
    
    private func removeOldestEntries() {
        let sortedKeys = cache.keys.sorted { key1, key2 in
            let time1 = cache[key1]?.lastAccessed ?? Date.distantPast
            let time2 = cache[key2]?.lastAccessed ?? Date.distantPast
            return time1 < time2
        }
        
        // Remove oldest 20% of entries
        let entriesToRemove = max(1, sortedKeys.count / 5)
        for key in sortedKeys.prefix(entriesToRemove) {
            cache.removeValue(forKey: key)
        }
        
        print("🧹 Cleaned \(entriesToRemove) cache entries")
    }
    
    func clearCache() {
        cache.removeAll()
        print("🗑️ Cleared all cache entries")
    }
    
    // MARK: - Cache Statistics
    var cacheStats: (count: Int, hitRate: String) {
        let count = cache.count
        // Simple hit rate calculation could be added here
        return (count, "N/A")
    }
}

// MARK: - Cache Data Model
private struct CachedRegionData {
    let restaurants: [Restaurant]
    let timestamp: Date
    var lastAccessed: Date
    let region: MKCoordinateRegion
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 1800 // 30 minutes
    }
}
