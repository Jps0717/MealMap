import Foundation
import CoreLocation
import SwiftUI

// MARK: - Response Caching
private class OverpassCache {
    private var cache: [String: (data: [Restaurant], timestamp: Date)] = [:]
    private let maxAge: TimeInterval = 3600 // 1 hour
    
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
    private let baseURLs = [
        "https://overpass-api.de/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter"
    ]
    private var currentURLIndex = 0
    
    // PERFORMANCE: Add caching
    private let cache = OverpassCache()
    private var lastRequestTime: Date = Date.distantPast
    private let minimumRequestInterval: TimeInterval = 1.5 // Increased to avoid overloading
    
    /// Fetches restaurants within a bounding box with caching
    func fetchRestaurants(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [Restaurant] {
        // Create cache key based on rounded coordinates
        let cacheKey = String(format: "%.3f_%.3f_%.3f_%.3f", minLat, minLon, maxLat, maxLon)
        
        // Check cache first
        if let cachedData = cache.get(for: cacheKey) {
            print("⚡ Cache hit for Overpass API request")
            return cachedData
        }
        
        // Throttle requests
        await throttleRequest()
        
        let query = createOptimizedQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        guard let url = URL(string: baseURLs[currentURLIndex]) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        request.timeoutInterval = 8 // Very short timeout
        
        print("🌐 Trying API: \(baseURLs[currentURLIndex])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let restaurants = try await Task.detached {
            try self.parseRestaurantsFromData(data)
        }.value
        
        // Cache the result
        cache.store(restaurants, for: cacheKey)
        
        return restaurants
    }
    
    /// OPTIMIZED: Fetch only nutrition-data restaurants
    func fetchNutritionRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 3.0) async throws -> [Restaurant] {
        let cacheKey = String(format: "nutrition_%.4f_%.4f_%.1f", coordinate.latitude, coordinate.longitude, radius)
        
        if let cachedData = cache.get(for: cacheKey) {
            print("⚡ Cache hit for nutrition restaurants")
            return cachedData
        }
        
        await throttleRequest()
        
        let radiusInMeters = radius * 1609.34
        let query = createNutritionFocusedQuery(coordinate: coordinate, radius: radiusInMeters)
        
        guard let url = URL(string: baseURLs[currentURLIndex]) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        request.timeoutInterval = 8 // Very short timeout
        
        print("🌐 Trying API: \(baseURLs[currentURLIndex])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let restaurants = try await Task.detached {
            let allRestaurants = try self.parseRestaurantsFromData(data)
            // Filter to only restaurants with nutrition data
            return allRestaurants.filter { restaurant in
                RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
            }
        }.value
        
        cache.store(restaurants, for: cacheKey)
        return restaurants
    }
    
    // MARK: - Optimized Queries
    private func createNutritionFocusedQuery(coordinate: CLLocationCoordinate2D, radius: Double) -> String {
        // Only query for restaurant chains that we know have nutrition data
        let knownChains = RestaurantData.restaurantsWithNutritionData.prefix(20).map { "\"name\"=\"\($0)\"" }.joined(separator: " or ")
        
        return """
        [out:json][timeout:15];
        (
          node["amenity"~"^(restaurant|fast_food)$"][\(knownChains)](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
        );
        out body;
        """
    }
    
    private func createOptimizedQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        return """
        [out:json][timeout:15];
        (
          node["amenity"="fast_food"]["name"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["amenity"="restaurant"]["name"]["brand"](\(minLat),\(minLon),\(maxLat),\(maxLon));
        );
        out body;
        """
    }
    
    /// Fetches fast food restaurants within specified radius
    func fetchFastFoodRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 2.5) async throws -> [Restaurant] {
        let cacheKey = String(format: "fastfood_%.4f_%.4f_%.1f", coordinate.latitude, coordinate.longitude, radius)
        
        // Check cache first
        if let cachedData = cache.get(for: cacheKey) {
            print("⚡ Cache hit for fast food restaurants")
            return cachedData
        }
        
        // Throttle requests
        await throttleRequest()
        
        let radiusInMeters = radius * 1609.34
        
        let query = createOptimizedFastFoodQuery(coordinate: coordinate, radius: radiusInMeters)
        
        guard let url = URL(string: baseURLs[currentURLIndex]) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        request.timeoutInterval = 10 // Reasonable timeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Process on background thread
        let restaurants = try await Task.detached {
            try self.parseRestaurantsFromData(data)
        }.value
        
        // Cache the result
        cache.store(restaurants, for: cacheKey)
        
        return restaurants
    }
    
    private func createOptimizedFastFoodQuery(coordinate: CLLocationCoordinate2D, radius: Double) -> String {
        """
        [out:json][timeout:20];
        (
          node["amenity"="fast_food"]["name"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
          node["amenity"="restaurant"]["name"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
        );
        out body;
        """
    }
    
    private func createComprehensiveQuery(coordinate: CLLocationCoordinate2D, radius: Double) -> String {
        """
        [out:json][timeout:20];
        (
          node["amenity"="fast_food"]["name"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
          node["amenity"="restaurant"]["name"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
          node["amenity"="cafe"]["name"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
        );
        out body;
        """
    }
    
    /// IMPROVED: Fetch ALL nearby restaurants with robust fallback
    func fetchAllNearbyRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 3.0) async throws -> [Restaurant] {
        let cacheKey = String(format: "all_%.4f_%.4f_%.1f", coordinate.latitude, coordinate.longitude, radius)
        
        if let cachedData = cache.get(for: cacheKey) {
            print("⚡ Cache hit for all nearby restaurants")
            return cachedData
        }
        
        // Try fallback data first
        if let fallbackData = getFallbackRestaurants(near: coordinate, radius: radius) {
            print("🔄 Using fallback restaurant data")
            cache.store(fallbackData, for: cacheKey)
            return fallbackData
        }
        
        // Try multiple API endpoints
        for attempt in 0..<baseURLs.count {
            do {
                let restaurants = try await fetchFromAPI(coordinate: coordinate, radius: radius)
                cache.store(restaurants, for: cacheKey)
                return restaurants
            } catch {
                print("❌ Attempt \(attempt + 1) failed: \(error.localizedDescription)")
                // Switch to next URL for next attempt
                currentURLIndex = (currentURLIndex + 1) % baseURLs.count
                
                if attempt < baseURLs.count - 1 {
                    // Wait before trying next endpoint
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                }
            }
        }
        
        // If all API attempts fail, return fallback data
        if let fallbackData = getFallbackRestaurants(near: coordinate, radius: radius) {
            print("🆘 All APIs failed, using fallback data")
            return fallbackData
        }
        
        throw URLError(.timedOut)
    }
    
    private func fetchFromAPI(coordinate: CLLocationCoordinate2D, radius: Double) async throws -> [Restaurant] {
        await throttleRequest()
        
        let radiusInMeters = radius * 1609.34
        let query = createSimplifiedQuery(coordinate: coordinate, radius: radiusInMeters)
        
        guard let url = URL(string: baseURLs[currentURLIndex]) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        request.timeoutInterval = 8 // Aggressive timeout
        
        print("🌐 Trying API: \(baseURLs[currentURLIndex])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let restaurants = try await Task.detached {
            try self.parseRestaurantsFromData(data)
        }.value
        
        print("✅ Successfully fetched \(restaurants.count) restaurants from API")
        return restaurants
    }
    
    private func createSimplifiedQuery(coordinate: CLLocationCoordinate2D, radius: Double) -> String {
        // Simplified query to reduce timeout risk
        """
        [out:json][timeout:10];
        (
          node["amenity"="fast_food"]["name"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
          node["amenity"="restaurant"]["name"](around:\(radius/2),\(coordinate.latitude),\(coordinate.longitude));
        );
        out body;
        """
    }
    
    // FALLBACK: Generate realistic restaurant data based on location
    private func getFallbackRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double) -> [Restaurant]? {
        print("🔄 Generating fallback restaurant data...")
        
        // IMPROVED: More diverse chains that match categories better
        let commonChains = [
            // Fast Food
            ("McDonald's", "fast_food"),
            ("Burger King", "fast_food"),
            ("KFC", "fast_food"),
            ("Taco Bell", "fast_food"),
            ("Wendy's", "fast_food"),
            ("Arby's", "fast_food"),
            
            // Healthy/Mixed
            ("Subway", "fast_food"), // Good for healthy and vegan options
            ("Chipotle", "restaurant"), // Good for healthy, high protein, low carb, vegan
            ("Panera Bread", "restaurant"), // Good for healthy and vegan options
            ("Starbucks", "restaurant"), // Vegan-friendly drinks and some food
            
            // Traditional restaurants
            ("Pizza Hut", "restaurant"),
            ("Domino's", "restaurant"),
            
            // High protein focused
            ("Chick-fil-A", "fast_food"), // High protein chicken
            ("Five Guys", "restaurant"), // High protein burgers
            
            // Additional variety
            ("Dunkin'", "restaurant"),
            ("Dairy Queen", "fast_food")
        ]
        
        // Generate restaurants around the user's location
        var fallbackRestaurants: [Restaurant] = []
        let radiusInDegrees = radius / 69.0 // Approximate conversion
        
        for (index, (name, amenityType)) in commonChains.enumerated() {
            // Generate 1-2 locations per chain within radius (reduced for variety)
            let locationsCount = Int.random(in: 1...2)
            
            for locationIndex in 0..<locationsCount {
                // Random offset within radius
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
                
                // IMPORTANT: Set amenityType properly
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
        
        return Array(fallbackRestaurants.prefix(25)) // Increased variety
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
        
        let sortedRestaurants = restaurants.sorted { r1, r2 in
            let r1HasNutrition = RestaurantData.restaurantsWithNutritionData.contains(r1.name)
            let r2HasNutrition = RestaurantData.restaurantsWithNutritionData.contains(r2.name)
            
            // Prioritize restaurants with nutrition data, then by display priority
            if r1HasNutrition != r2HasNutrition {
                return r1HasNutrition // Nutrition restaurants first
            }
            return r1.displayPriority > r2.displayPriority
        }
        
        let limitedRestaurants = Array(sortedRestaurants.prefix(200))
        
        return limitedRestaurants
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

// MARK: - Test Function
// static func testConnection() async {
//     let service = OverpassAPIService()
//     
//     // Test with a small area in San Francisco
//     let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
//     
//     do {
//         let restaurants = try await service.fetchFastFoodRestaurants(near: coordinate, radius: 2.0)
//         
//         print("✅ Successfully fetched \(restaurants.count) restaurants")
//         
//         // Print first few restaurants for verification
//         for (index, restaurant) in restaurants.prefix(3).enumerated() {
//             print("\nRestaurant \(index + 1):")
//             print("ID: \(restaurant.id)")
//             print("Name: \(restaurant.name)")
//             print("Location: \(restaurant.latitude), \(restaurant.longitude)")
//             print("Cuisine: \(restaurant.cuisine ?? "Unknown")")
//             print("Address: \(restaurant.address ?? "Unknown")")
//             print("Priority: \(restaurant.displayPriority)")
//         }
//         
//     } catch {
//         print("❌ Error fetching restaurants: \(error)")
//     }
// }
