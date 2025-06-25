import Foundation
import CoreLocation

class StartupCache {
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "startup_restaurants_cache"
    private let cacheLocationKey = "startup_cache_location"
    private let cacheTimestampKey = "startup_cache_timestamp"
    
    // Cache is valid for 6 hours
    private let cacheValidityDuration: TimeInterval = 6 * 3600
    
    func getCachedRestaurants(near coordinate: CLLocationCoordinate2D) -> [Restaurant]? {
        // Check if cache exists and is still valid
        guard let cacheTimestamp = userDefaults.object(forKey: cacheTimestampKey) as? Date,
              Date().timeIntervalSince(cacheTimestamp) < cacheValidityDuration else {
            return nil
        }
        
        // Check if location is close enough (within 5 miles)
        guard let cachedLocationData = userDefaults.data(forKey: cacheLocationKey),
              let cachedLocation = try? JSONDecoder().decode(CachedLocation.self, from: cachedLocationData) else {
            return nil
        }
        
        let cachedCoordinate = CLLocationCoordinate2D(
            latitude: cachedLocation.latitude,
            longitude: cachedLocation.longitude
        )
        
        let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: cachedCoordinate.latitude, longitude: cachedCoordinate.longitude))
        
        // If more than 5 miles away, don't use cache
        guard distance < 8047 else { // 5 miles in meters
            return nil
        }
        
        // Load cached restaurants
        guard let restaurantData = userDefaults.data(forKey: cacheKey),
              let restaurants = try? JSONDecoder().decode([Restaurant].self, from: restaurantData) else {
            return nil
        }
        
        debugLog("⚡ Loaded \(restaurants.count) restaurants from startup cache")
        return restaurants
    }
    
    func store(_ restaurants: [Restaurant], for coordinate: CLLocationCoordinate2D) {
        do {
            let restaurantData = try JSONEncoder().encode(restaurants)
            let locationData = try JSONEncoder().encode(CachedLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ))
            
            userDefaults.set(restaurantData, forKey: cacheKey)
            userDefaults.set(locationData, forKey: cacheLocationKey)
            userDefaults.set(Date(), forKey: cacheTimestampKey)
            
            debugLog("💾 Cached \(restaurants.count) restaurants for startup")
        } catch {
            debugLog("❌ Failed to cache restaurants: \(error)")
        }
    }
}

private struct CachedLocation: Codable {
    let latitude: Double
    let longitude: Double
}