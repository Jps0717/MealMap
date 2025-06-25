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
        // Use static list for synchronous access - fast and reliable
        let normalizedName = self.name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
        
        return RestaurantData.restaurantsWithNutritionData.contains { knownRestaurant in
            let normalizedKnown = knownRestaurant.lowercased()
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: ".", with: "")
            return normalizedName.contains(normalizedKnown) || normalizedKnown.contains(normalizedName)
        }
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

/// Service responsible for fetching restaurants using the Overpass API with viewport optimization.
final class OverpassAPIService {
    // OPTIMIZED: Use high-performance Overpass instances
    private let baseURLs = [
        "https://overpass.kumi.systems/api/interpreter",  // High-capacity mirror
        "https://overpass-api.de/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ]
    private var currentURLIndex = 0
    
    // PERFORMANCE: Enhanced viewport-based caching
    private let viewportCache = ViewportCache()
    private var lastRequestTime: Date = Date.distantPast
    private let minimumRequestInterval: TimeInterval = 0.5 // Reduced for better responsiveness
    
    /// OPTIMIZED: Viewport-based restaurant fetching with exact bounding box
    func fetchRestaurantsForViewport(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [Restaurant] {
        // Create precise viewport cache key
        let cacheKey = viewportCache.createViewportKey(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        // Check viewport cache first for instant response
        if let cachedData = viewportCache.get(for: cacheKey) {
            debugLog("⚡ Viewport cache hit - instant response with \(cachedData.count) restaurants")
            return cachedData
        }
        
        // Throttle requests
        await throttleRequest()
        
        // Use optimized bounding box query
        let query = createOptimizedViewportQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        let restaurants = try await executeQuery(query)
        
        // Cache the viewport result
        viewportCache.store(restaurants, for: cacheKey)
        
        debugLog("✅ Viewport fetch completed: \(restaurants.count) restaurants cached for key: \(cacheKey)")
        return restaurants
    }
    
    // OPTIMIZED: Flattened query with exact bounding box and minimal output
    private func createOptimizedViewportQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        // Use exact bounding box coordinates and 'out center;' for minimal payload
        return """
        [out:json][timeout:8][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
        (
          node["amenity"="fast_food"]["name"];
          node["amenity"="restaurant"]["name"];
          node["amenity"="cafe"]["name"];
        );
        out center;
        """
    }
    
    /// LEGACY: Keep existing methods for compatibility
    func fetchRestaurants(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [Restaurant] {
        // Redirect to optimized viewport method
        return try await fetchRestaurantsForViewport(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
    }
    
    /// OPTIMIZED: Fetch only nutrition-data restaurants with viewport bounds
    func fetchNutritionRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 3.0) async throws -> [Restaurant] {
        // Convert radius to bounding box for consistency
        let radiusInDegrees = radius / 69.0 // Approximate conversion
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLon = coordinate.longitude - radiusInDegrees
        let maxLon = coordinate.longitude + radiusInDegrees
        
        let cacheKey = viewportCache.createViewportKey(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon) + "_nutrition"
        
        if let cachedData = viewportCache.get(for: cacheKey) {
            debugLog("⚡ Nutrition cache hit")
            return cachedData
        }
        
        // Use nutrition-focused query with bounding box
        let query = createNutritionFocusedBoundingBoxQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        let restaurants = try await executeQuery(query)
        
        // Filter to only restaurants with nutrition data
        let nutritionRestaurants = restaurants.filter { restaurant in
            restaurant.hasNutritionData
        }
        
        viewportCache.store(nutritionRestaurants, for: cacheKey)
        return nutritionRestaurants
    }
    
    private func createNutritionFocusedBoundingBoxQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        // Focus on known chains with nutrition data, use bounding box instead of radius
        let knownChains = RestaurantData.restaurantsWithNutritionData.prefix(15).map {
            "\"name\"~\"\($0)\""
        }.joined(separator: " or ")
        
        return """
        [out:json][timeout:8][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
        (
          node["amenity"~"^(restaurant|fast_food)$"][\(knownChains)];
        );
        out center;
        """
    }
    
    /// OPTIMIZED: All nearby restaurants with bounding box approach
    func fetchAllNearbyRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 3.0) async throws -> [Restaurant] {
        // Convert to bounding box for consistent caching and querying
        let radiusInDegrees = radius / 69.0
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLon = coordinate.longitude - radiusInDegrees
        let maxLon = coordinate.longitude + radiusInDegrees
        
        return try await fetchRestaurantsForViewport(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
    }
    
    /// OPTIMIZED: Fast food restaurants with bounding box
    func fetchFastFoodRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 2.5) async throws -> [Restaurant] {
        let radiusInDegrees = radius / 69.0
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLon = coordinate.longitude - radiusInDegrees
        let maxLon = coordinate.longitude + radiusInDegrees
        
        let cacheKey = viewportCache.createViewportKey(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon) + "_fastfood"
        
        if let cachedData = viewportCache.get(for: cacheKey) {
            debugLog("⚡ Fast food cache hit")
            return cachedData
        }
        
        let query = createFastFoodBoundingBoxQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        let restaurants = try await executeQuery(query)
        
        viewportCache.store(restaurants, for: cacheKey)
        return restaurants
    }
    
    private func createFastFoodBoundingBoxQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        return """
        [out:json][timeout:8][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
        (
          node["amenity"="fast_food"]["name"];
          node["amenity"="restaurant"]["name"]["brand"];
        );
        out center;
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
        request.timeoutInterval = 6 // Shorter timeout for responsiveness
        
        debugLog("🌐 Optimized query to: \(baseURLs[currentURLIndex])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Parse on background thread for smooth UI
        let restaurants = try await Task.detached(priority: .utility) {
            try self.parseRestaurantsFromData(data)
        }.value
        
        return restaurants
    }
    
    // FALLBACK: Generate realistic restaurant data based on location
    private func getFallbackRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double) -> [Restaurant]? {
        debugLog("🔄 Generating fallback restaurant data...")
        
        let commonChains = [
            ("McDonald's", "fast_food"), ("Burger King", "fast_food"), ("KFC", "fast_food"),
            ("Taco Bell", "fast_food"), ("Wendy's", "fast_food"), ("Subway", "fast_food"),
            ("Chipotle", "restaurant"), ("Panera Bread", "restaurant"), ("Starbucks", "restaurant"),
            ("Pizza Hut", "restaurant"), ("Domino's", "restaurant"), ("Chick-fil-A", "fast_food"),
            ("Five Guys", "restaurant"), ("Dunkin'", "restaurant"), ("Dairy Queen", "fast_food")
        ]
        
        var fallbackRestaurants: [Restaurant] = []
        let radiusInDegrees = radius / 69.0
        
        for (index, (name, amenityType)) in commonChains.enumerated() {
            let locationsCount = Int.random(in: 1...2)
            
            for locationIndex in 0..<locationsCount {
                let latOffset = Double.random(in: -radiusInDegrees...radiusInDegrees)
                let lonOffset = Double.random(in: -radiusInDegrees...radiusInDegrees)
                
                var restaurant = Restaurant(
                    id: index * 100 + locationIndex,
                    name: name,
                    latitude: coordinate.latitude + latOffset,
                    longitude: coordinate.longitude + lonOffset,
                    address: "Near \(Int(coordinate.latitude * 1000) / 1000), \(Int(coordinate.longitude * 1000) / 1000)",
                    cuisine: getCuisineType(for: name, amenityType: amenityType),
                    openingHours: "6:00-22:00",
                    phone: nil,
                    website: nil,
                    type: "node"
                )
                
                restaurant.amenityType = amenityType
                fallbackRestaurants.append(restaurant)
            }
        }
        
        // Sort by distance
        fallbackRestaurants.sort { r1, r2 in
            let d1 = pow(r1.latitude - coordinate.latitude, 2) + pow(r1.longitude - coordinate.longitude, 2)
            let d2 = pow(r2.latitude - coordinate.latitude, 2) + pow(r2.longitude - coordinate.longitude, 2)
            return d1 < d2
        }
        
        return Array(fallbackRestaurants.prefix(25))
    }
    
    private func getCuisineType(for restaurantName: String, amenityType: String) -> String {
        switch restaurantName {
        case "McDonald's", "Burger King", "Wendy's": return "Burgers"
        case "KFC", "Chick-fil-A": return "Chicken"
        case "Taco Bell": return "Mexican"
        case "Pizza Hut", "Domino's": return "Pizza"
        case "Subway": return "Sandwiches"
        case "Chipotle": return "Mexican"
        case "Panera Bread": return "Bakery & Cafe"
        case "Starbucks": return "Coffee & Light Meals"
        case "Five Guys": return "Burgers"
        case "Arby's": return "Sandwiches"
        case "Dunkin'": return "Coffee & Donuts"
        case "Dairy Queen": return "Ice Cream & Fast Food"
        default:
            return amenityType == "fast_food" ? "Fast Food" : "American"
        }
    }

    // MARK: - Private Methods
    
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
        
        let restaurants = overpass.elements.compactMap { element -> Restaurant? in
            guard let name = element.tags["name"],
                  let lat = element.lat,
                  let lon = element.lon,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            
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
            
            // Set amenity type for better categorization
            if element.tags["amenity"] == "fast_food" {
                restaurant.amenityType = "fast_food"
            } else if element.tags["amenity"] == "restaurant" {
                restaurant.amenityType = "restaurant"
            }
            
            return restaurant
        }
        
        // OPTIMIZED: Sort by nutrition data and priority
        let sortedRestaurants = restaurants.sorted { r1, r2 in
            let r1HasNutrition = r1.hasNutritionData
            let r2HasNutrition = r2.hasNutritionData
            
            if r1HasNutrition != r2HasNutrition {
                return r1HasNutrition
            }
            return r1.displayPriority > r2.displayPriority
        }
        
        // Limit results for performance - focus on quality over quantity
        return Array(sortedRestaurants.prefix(75))
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
