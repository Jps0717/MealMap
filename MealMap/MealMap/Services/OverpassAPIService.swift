import Foundation
import CoreLocation
import SwiftUI

extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return abs(lhs.latitude - rhs.latitude) < 0.00001 &&
               abs(lhs.longitude - rhs.longitude) < 0.00001
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
    
    private var lastRequestTime: Date = Date.distantPast
    private let minimumRequestInterval: TimeInterval = 1.0 // 1 second between requests
    
    /// Fetches restaurants within a bounding box
    func fetchRestaurants(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [Restaurant] {
        // Throttle requests to avoid overwhelming the API
        await throttleRequest()
        
        let query = createRestaurantQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        request.timeoutInterval = 30 // 30 second timeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let restaurants = try parseRestaurantsFromData(data)
        return restaurants
    }
    
    /// Fetches fast food restaurants within specified radius
    func fetchFastFoodRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 5.0) async throws -> [Restaurant] {
        // Throttle requests
        await throttleRequest()
        
        let radiusInMeters = radius * 1609.34
        let query = createOptimizedFastFoodQuery(coordinate: coordinate, radius: radiusInMeters)
        
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        request.timeoutInterval = 25 // Shorter timeout for better UX
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let restaurants = try parseRestaurantsFromData(data)
        
        print("✅ Fetched \(restaurants.count) fast food restaurants")
        return restaurants
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
    
    private func createOptimizedFastFoodQuery(coordinate: CLLocationCoordinate2D, radius: Double) -> String {
        """
        [out:json][timeout:20];
        (
          node["amenity"="fast_food"]["name"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
        );
        out body;
        """
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
        
        // Sort by priority for better user experience
        return restaurants.sorted { $0.displayPriority > $1.displayPriority }
    }
    
    private func createRestaurantQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        """
        [out:json][timeout:25];
        (
          node["amenity"="restaurant"]["name"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["amenity"="fast_food"]["name"](\(minLat),\(minLon),\(maxLat),\(maxLon));
        );
        out body;
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

// MARK: - Test Function
extension OverpassAPIService {
    static func testConnection() async {
        let service = OverpassAPIService()
        
        // Test with a small area in San Francisco
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        do {
            let restaurants = try await service.fetchFastFoodRestaurants(near: coordinate, radius: 2.0)
            
            print("✅ Successfully fetched \(restaurants.count) restaurants")
            
            // Print first few restaurants for verification
            for (index, restaurant) in restaurants.prefix(3).enumerated() {
                print("\nRestaurant \(index + 1):")
                print("ID: \(restaurant.id)")
                print("Name: \(restaurant.name)")
                print("Location: \(restaurant.latitude), \(restaurant.longitude)")
                print("Cuisine: \(restaurant.cuisine ?? "Unknown")")
                print("Address: \(restaurant.address ?? "Unknown")")
                print("Priority: \(restaurant.displayPriority)")
            }
            
        } catch {
            print("❌ Error fetching restaurants: \(error)")
        }
    }
}
