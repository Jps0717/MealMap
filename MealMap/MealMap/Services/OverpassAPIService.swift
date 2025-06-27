import Foundation
import CoreLocation
import SwiftUI

// MARK: - Enhanced Viewport-Based Caching
private class ViewportCache {
    private var cache: [String: (data: [Restaurant], timestamp: Date)] = [:]
    private let maxAge: TimeInterval = 1800 // 30 minutes for viewport data
    
    func get(for key: String) -> [Restaurant]? {
        guard let cached = cache[key],
              Date().timeIntervalSince(cached.timestamp) < maxAge else {
            cache.removeValue(forKey: key)
            return nil
        }
        return cached.data
    }
    
    func store(_ data: [Restaurant], for key: String) {
        cache[key] = (data, Date())
        // Clean old entries periodically
        if cache.count > 50 {
            let cutoff = Date().addingTimeInterval(-maxAge)
            cache = cache.filter { $0.value.timestamp > cutoff }
        }
    }
    
    func createViewportKey(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        // Round to 3 decimal places (~100m precision) for better cache hits
        return String(format: "%.3f_%.3f_%.3f_%.3f",
                     (minLat * 1000).rounded() / 1000,
                     (minLon * 1000).rounded() / 1000,
                     (maxLat * 1000).rounded() / 1000,
                     (maxLon * 1000).rounded() / 1000)
    }
}

/// Model representing a restaurant fetched from the Overpass API.
struct Restaurant: Identifiable, Equatable, Hashable, Codable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let cuisine: String?
    let openingHours: String?
    let phone: String?
    let website: String?
    let type: String
    
    var amenityType: String? = nil
    
    var hasNutritionData: Bool {
        // Use the centralized helper from RestaurantData
        return RestaurantData.hasNutritionData(for: self.name)
    }
    
    var displayPriority: Int {
        if amenityType == "fast_food" && hasNutritionData {
            return 4 // Highest priority: fast food with nutrition
        } else if amenityType == "restaurant" && hasNutritionData {
            return 3 // High priority: restaurant with nutrition
        } else if amenityType == "fast_food" {
            return 2 // Medium priority: fast food without nutrition
        } else {
            return 1 // Low priority: restaurant without nutrition
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension Restaurant {
    func matchesCategory(_ category: RestaurantCategory) -> Bool {
        let name = self.name.lowercased()
        let cuisine = self.cuisine?.lowercased() ?? ""
        
        switch category {
        case .fastFood:
            return RestaurantData.restaurantsWithNutritionData.contains { chain in
                name.contains(chain.lowercased())
            } ||
                   PopularChains.fastFoodChains.contains { chain in
                       name.contains(chain.lowercased())
                   }
            
        case .healthy:
            return name.contains("salad") || name.contains("fresh") || name.contains("bowl") ||
                   name.contains("juice") || name.contains("smoothie") || name.contains("organic") ||
                   PopularChains.healthyChains.contains { chain in
                       name.contains(chain.lowercased())
                   }
            
        case .highProtein:
            return name.contains("grill") || name.contains("steakhouse") || name.contains("bbq") ||
                   name.contains("chicken") || name.contains("protein") || name.contains("meat")
        }
    }
    
    func matchesHealthyType(_ type: HealthyType) -> Bool {
        let name = self.name.lowercased()
        return type.searchTerms.contains { term in
            name.contains(term)
        }
    }
    
    func distanceFrom(_ coordinate: CLLocationCoordinate2D) -> Double {
        let restaurantLocation = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distanceInMeters = restaurantLocation.distance(from: userLocation)
        let distanceInMiles = distanceInMeters / 1609.34 // Convert to miles
        
        // DETAILED LOGGING: Show distance calculations
        debugLog("📏 DISTANCE: '\(self.name)' is \(String(format: "%.2f", distanceInMiles)) miles away")
        debugLog("   ↳ Restaurant: (\(self.latitude), \(self.longitude))")
        debugLog("   ↳ User: (\(coordinate.latitude), \(coordinate.longitude))")
        debugLog("   ↳ Distance: \(String(format: "%.0f", distanceInMeters))m / \(String(format: "%.2f", distanceInMiles)) miles")
        
        return distanceInMiles
    }
}

/// Service responsible for fetching restaurants using the Overpass API - ZERO CACHING
final class OverpassAPIService {
    // OPTIMIZED: Use high-performance Overpass instances
    private let baseURLs = [
        "https://overpass.kumi.systems/api/interpreter",  // High-capacity mirror
        "https://overpass-api.de/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ]
    private var currentURLIndex = 0
    
    private var lastRequestTime: Date = Date.distantPast
    private let minimumRequestInterval: TimeInterval = 0.3 // Reduced for faster fresh calls
    
    /// ZERO CACHING: Always fresh viewport-based restaurant fetching
    func fetchRestaurantsForViewport(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [Restaurant] {
        debugLog("🔥 ZERO CACHING - FRESH API CALL (MEMORY LIMITED):")
        debugLog("🔥 Bounds: (\(minLat), \(minLon)) to (\(maxLat), \(maxLon))")
        debugLog("🔥 NO CACHE CHECK - Going straight to API")
        
        // Throttle requests
        await throttleRequest()
        
        // Use optimized bounding box query
        let query = createOptimizedViewportQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        debugLog("🔥 OVERPASS QUERY (MEMORY CONSCIOUS):")
        debugLog(query)
        
        let restaurants = try await executeQuery(query)
        
        debugLog("🔥 ZERO CACHING - FRESH API RESPONSE: \(restaurants.count) restaurants (memory limited)")
        return restaurants
    }
    
    /// ZERO CACHING: Always fresh nutrition-data restaurants
    func fetchNutritionRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 2.5) async throws -> [Restaurant] {
        let radiusInDegrees = radius / 69.0
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLon = coordinate.longitude - radiusInDegrees
        let maxLon = coordinate.longitude + radiusInDegrees
        
        debugLog("🔥 ZERO CACHING - FRESH NUTRITION QUERY (2.5 miles)")
        
        let query = createNutritionFocusedBoundingBoxQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        let restaurants = try await executeQuery(query)
        
        // Filter to only restaurants with nutrition data
        let nutritionRestaurants = restaurants.filter { restaurant in
            restaurant.hasNutritionData
        }
        
        debugLog("🔥 ZERO CACHING - FRESH NUTRITION RESPONSE: \(nutritionRestaurants.count) restaurants (never cached)")
        return nutritionRestaurants
    }
    
    /// ZERO CACHING: Always fresh fast food restaurants
    func fetchFastFoodRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 2.5) async throws -> [Restaurant] {
        let radiusInDegrees = radius / 69.0
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLon = coordinate.longitude - radiusInDegrees
        let maxLon = coordinate.longitude + radiusInDegrees
        
        debugLog("🔥 ZERO CACHING - FRESH FAST FOOD QUERY")
        
        let query = createFastFoodBoundingBoxQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        let restaurants = try await executeQuery(query)
        
        debugLog("🔥 ZERO CACHING - FRESH FAST FOOD RESPONSE: \(restaurants.count) restaurants (never cached)")
        return restaurants
    }
    
    /// ZERO CACHING: All nearby restaurants with bounding box approach - LIMITED TO 2.5 MILES
    func fetchAllNearbyRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 2.5) async throws -> [Restaurant] {
        // Convert to bounding box for consistent querying - FIXED AT 2.5 MILES
        let radiusInDegrees = radius / 69.0
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLon = coordinate.longitude - radiusInDegrees
        let maxLon = coordinate.longitude + radiusInDegrees
        
        debugLog("🔥 ZERO CACHING - 2.5 MILE LIMIT: Fetching restaurants in 2.5 mile radius")
        
        return try await fetchRestaurantsForViewport(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
    }
    
    // GET ALL RESTAURANTS: No filtering, no requirements, just everything
    private func createOptimizedViewportQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        return """
        [out:json][timeout:8][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
        (
          node["amenity"="fast_food"];
          node["amenity"="restaurant"];
          node["amenity"="cafe"];
          node["amenity"="bar"];
          node["amenity"="pub"];
          node["amenity"="food_court"];
          node["amenity"="ice_cream"];
        );
        out;
        """
    }
    
    private func createNutritionFocusedBoundingBoxQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        // Same query - get everything, filter later
        return createOptimizedViewportQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
    }
    
    private func createFastFoodBoundingBoxQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        return """
        [out:json][timeout:8][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
        (
          node["amenity"="fast_food"];
          node["amenity"="restaurant"];
          node["amenity"="cafe"];
          node["amenity"="bar"];
          node["amenity"="pub"];
          node["amenity"="food_court"];
          node["amenity"="ice_cream"];
        );
        out;
        """
    }
    
    // MARK: - Core Query Execution
    private func executeQuery(_ query: String) async throws -> [Restaurant] {
        guard let url = URL(string: baseURLs[currentURLIndex]) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        request.timeoutInterval = 8 // Reduced timeout for speed
        
        debugLog("🌐 Ultra-fast query to: \(baseURLs[currentURLIndex])")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                debugLog("❌ HTTP Error: \(statusCode)")
                throw URLError(.badServerResponse)
            }
            
            // Parse on background thread for smooth UI
            let restaurants = try await Task.detached(priority: .utility) {
                try self.parseRestaurantsFromData(data)
            }.value
            
            return restaurants
            
        } catch {
            debugLog("🔄 Primary API failed: \(error.localizedDescription)")
            
            // Try next server URL
            currentURLIndex = (currentURLIndex + 1) % baseURLs.count
            
            // Don't try fallback - just retry with next server
            if currentURLIndex != 0 {
                debugLog("🔄 Retrying with server: \(baseURLs[currentURLIndex])")
                return try await executeQuery(query)
            } else {
                debugLog("❌ All servers failed")
                throw error
            }
        }
    }
    
    private func throttleRequest() async {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest < minimumRequestInterval {
            let sleepTime = minimumRequestInterval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
    
    private func parseRestaurantsFromData(_ data: Data) throws -> [Restaurant] {
        let decoder = JSONDecoder()
        let overpass = try decoder.decode(OverpassResponse.self, from: data)
        
        debugLog("📡 MEMORY-LIMITED API RESPONSE: Received \(overpass.elements.count) elements")
        
        var restaurants: [Restaurant] = []
        
        for element in overpass.elements {
            // MINIMAL REQUIREMENTS: Just coordinates and any kind of name/brand
            guard let lat = element.lat,
                  let lon = element.lon else {
                continue // Skip logging for memory efficiency
            }
            
            // Try to get a name from multiple sources
            let name = element.tags["name"] ??
                      element.tags["brand"] ??
                      element.tags["operator"] ??
                      element.tags["amenity"]?.capitalized ??
                      "Restaurant #\(element.id)"
            
            var restaurant = Restaurant(
                id: element.id,
                name: name,
                latitude: lat,
                longitude: lon,
                address: element.tags["addr:street"],
                cuisine: element.tags["cuisine"],
                openingHours: element.tags["opening_hours"],
                phone: element.tags["phone"],
                website: element.tags["website"],
                type: element.type
            )
            
            // Set amenity type
            restaurant.amenityType = element.tags["amenity"]
            
            restaurants.append(restaurant)
        }
        
        debugLog("✅ MEMORY-LIMITED PARSE: \(restaurants.count) restaurants (2.5 mile limit)")
        
        // Sort by nutrition data availability for better user experience
        let sortedRestaurants = restaurants.sorted { r1, r2 in
            if r1.hasNutritionData != r2.hasNutritionData {
                return r1.hasNutritionData
            }
            return r1.name < r2.name
        }
        
        debugLog("🎯 NUTRITION BREAKDOWN (2.5 MILES):")
        let withNutrition = sortedRestaurants.filter { $0.hasNutritionData }
        let withoutNutrition = sortedRestaurants.filter { !$0.hasNutritionData }
        debugLog("   ✅ With nutrition: \(withNutrition.count)")
        debugLog("   ❌ Without nutrition: \(withoutNutrition.count)")
        
        // MAP LIMIT: Return only 50 restaurants for map display
        let mapLimitedResults = Array(sortedRestaurants.prefix(50))
        debugLog("📊 MAP LIMITED: Returning \(mapLimitedResults.count) restaurants (max 50 for map)")
        return mapLimitedResults
    }
}

// MARK: - Overpass Response Models (Updated for 'out center;')
private struct OverpassResponse: Decodable {
    let version: Double
    let generator: String
    let osm3s: OSM3S
    let elements: [Element]
}

private struct OSM3S: Decodable {
    let timestamp_osm_base: String
    let copyright: String
}

private struct Element: Decodable {
    let type: String
    let id: Int
    let lat: Double?
    let lon: Double?
    let tags: [String: String]
}
