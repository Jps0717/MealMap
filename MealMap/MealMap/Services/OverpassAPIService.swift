import Foundation
import CoreLocation
import SwiftUI

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
        return RestaurantData.restaurantsWithNutritionData.contains(self.name)
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
}

extension Restaurant {
    func matchesCategory(_ category: RestaurantCategory) -> Bool {
        let name = self.name.lowercased()
        let cuisine = self.cuisine?.lowercased() ?? ""
        
        switch category {
        case .fastFood:
            return RestaurantData.restaurantsWithNutritionData.contains(self.name) ||
                   PopularChains.fastFoodChains.contains { chain in
                       name.contains(chain.lowercased())
                   }
            
        case .healthy:
            return name.contains("salad") || name.contains("fresh") || name.contains("bowl") ||
                   name.contains("juice") || name.contains("smoothie") || name.contains("organic") ||
                   PopularChains.healthyChains.contains { chain in
                       name.contains(chain.lowercased())
                   }
            
        case .vegan:
            return name.contains("vegan") || name.contains("plant") || name.contains("veggie") ||
                   name.contains("green") || cuisine.contains("vegan") || cuisine.contains("vegetarian")
            
        case .highProtein:
            return name.contains("grill") || name.contains("steakhouse") || name.contains("bbq") ||
                   name.contains("chicken") || name.contains("protein") || name.contains("meat")
            
        case .lowCarb:
            return name.contains("salad") || name.contains("grill") || name.contains("steakhouse") ||
                   name.contains("bowl") || name.contains("keto")
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
        return distanceInMeters / 1609.34 // Convert to miles
    }
}

/// Service responsible for fetching restaurants using the Overpass API.
final class OverpassAPIService {
    private let baseURL = "https://overpass-api.de/api/interpreter"
    private let enhancedCache = EnhancedCacheManager.shared
    
    // MARK: - Enhanced Caching Methods
    
    /// Fetches restaurants with enhanced caching and preloading
    func fetchFastFoodRestaurants(near coordinate: CLLocationCoordinate2D, useCache: Bool = true) async throws -> [Restaurant] {
        // Try enhanced cache first
        if useCache, let cachedRestaurants = enhancedCache.getCachedRestaurants(for: coordinate, radius: 5.0) {
            
            // Start background preloading for surrounding areas
            enhancedCache.startAggressivePreloading(from: coordinate)
            
            return cachedRestaurants
        }
        
        print("🌐 Fetching fresh restaurant data from API for \(coordinate)")
        
        let radius = 5.0 * 1609.34 // 5 miles in meters
        let query = """
        [out:json][timeout:30];
        (
          node["amenity"="fast_food"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
          node["amenity"="restaurant"]["brand"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
        );
        out body;
        """
        
        // Check for cached API response
        if let cachedResponse = enhancedCache.getCachedAPIResponse(for: query) {
            print("🚀 Using cached API response")
            let restaurants = try parseOverpassResponse(cachedResponse)
            
            // Cache the parsed restaurants
            enhancedCache.cacheRestaurants(restaurants, for: coordinate, radius: 5.0)
            
            return restaurants
        }
        
        // Make fresh API call
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = query.data(using: .utf8)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Cache the raw API response
        enhancedCache.cacheAPIResponse(data, for: query)
        
        let restaurants = try parseOverpassResponse(data)
        
        // Cache the parsed restaurants with enhanced caching
        enhancedCache.cacheRestaurants(restaurants, for: coordinate, radius: 5.0)
        
        return restaurants
    }
    
    /// Fetches restaurants within a bounding box with enhanced caching
    func fetchRestaurants(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double, useCache: Bool = true) async throws -> [Restaurant] {
        let centerCoordinate = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let approximateRadius = calculateRadius(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        // Try enhanced cache
        if useCache, let cachedRestaurants = enhancedCache.getCachedRestaurants(for: centerCoordinate, radius: approximateRadius) {
            return cachedRestaurants
        }
        
        let query = createRestaurantQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        // Check for cached API response
        if let cachedResponse = enhancedCache.getCachedAPIResponse(for: query) {
            let restaurants = try parseOverpassResponse(cachedResponse)
            enhancedCache.cacheRestaurants(restaurants, for: centerCoordinate, radius: approximateRadius)
            return restaurants
        }
        
        // Make fresh API call
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Cache the raw API response
        enhancedCache.cacheAPIResponse(data, for: query)
        
        let restaurants = try parseOverpassResponse(data)
        
        // Cache parsed restaurants
        enhancedCache.cacheRestaurants(restaurants, for: centerCoordinate, radius: approximateRadius)
        
        return restaurants
    }
    
    // MARK: - Batch Preloading for Popular Areas
    func preloadPopularAreas(_ coordinates: [CLLocationCoordinate2D]) {
        Task {
            for coordinate in coordinates {
                // Small delay between requests
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Skip if already cached
                if enhancedCache.getCachedRestaurants(for: coordinate, radius: 5.0) != nil {
                    continue
                }
                
                do {
                    _ = try await fetchFastFoodRestaurants(near: coordinate, useCache: false)
                    print("✅ Preloaded restaurants for \(coordinate)")
                } catch {
                    print("⚠️ Failed to preload \(coordinate): \(error)")
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func parseOverpassResponse(_ data: Data) throws -> [Restaurant] {
        let decoder = JSONDecoder()
        let overpass = try decoder.decode(OverpassResponse.self, from: data)
        
        return overpass.elements.compactMap { element -> Restaurant? in
            guard let name = element.tags["name"],
                  let lat = element.lat,
                  let lon = element.lon else { return nil }
            
            // Filter out very generic names that might not be useful
            if name.count < 3 || name.lowercased().contains("untitled") {
                return nil
            }
            
            return Restaurant(
                id: element.id,
                name: name,
                latitude: lat,
                longitude: lon,
                address: element.tags["addr:street"],
                cuisine: element.tags["cuisine"],
                openingHours: element.tags["opening_hours"],
                phone: element.tags["phone"],
                website: element.tags["website"],
                type: element.type,
                amenityType: element.tags["amenity"]
            )
        }
    }
    
    private func calculateRadius(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> Double {
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let corner = CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon)
        let distance = center.distance(to: corner) / 1609.34 // Convert to miles
        return distance
    }
    
    // MARK: - Private Methods
    
    private func createRestaurantQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        """
        [out:json][timeout:30];
        (
          node["amenity"="restaurant"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["amenity"="fast_food"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          way["amenity"="restaurant"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          way["amenity"="fast_food"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          relation["amenity"="restaurant"](\(minLat),\(minLon),\(maxLat),\(maxLon));
        );
        out body;
        >;
        out skel qt;
        """
    }
}

// MARK: - Overpass Response Models
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

// MARK: - Enhanced Test Function
extension OverpassAPIService {
    static func testEnhancedCaching() async {
        let service = OverpassAPIService()
        let testCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
        
        print("🧪 Testing enhanced caching system...")
        
        // First call - should hit API
        let start1 = Date()
        do {
            let restaurants1 = try await service.fetchFastFoodRestaurants(near: testCoordinate)
            let duration1 = Date().timeIntervalSince(start1)
            print("✅ First call: \(restaurants1.count) restaurants in \(String(format: "%.2f", duration1))s (API)")
        } catch {
            print("❌ First call failed: \(error)")
        }
        
        // Second call - should hit cache
        let start2 = Date()
        do {
            let restaurants2 = try await service.fetchFastFoodRestaurants(near: testCoordinate)
            let duration2 = Date().timeIntervalSince(start2)
            print("✅ Second call: \(restaurants2.count) restaurants in \(String(format: "%.2f", duration2))s (Cache)")
        } catch {
            print("❌ Second call failed: \(error)")
        }
        
        // Test cache stats
        let stats = EnhancedCacheManager.shared.getEnhancedCacheStats()
        print("📊 Cache Stats:")
        print("  - Memory restaurant areas: \(stats.memoryRestaurantAreas)")
        print("  - Memory nutrition items: \(stats.memoryNutritionItems)")
        print("  - Total restaurants cached: \(stats.totalMemoryRestaurants)")
        print("  - Active preload tasks: \(stats.activePreloadTasks)")
        print("  - Cache hit rate: \(String(format: "%.1f", stats.cacheHitRate * 100))%")
    }
}
