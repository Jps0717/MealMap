import Foundation
import CoreLocation

/// Model representing a restaurant fetched from the Overpass API.
struct Restaurant: Identifiable, Equatable, Hashable {
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}

/// Service responsible for fetching restaurants using the Overpass API.
final class OverpassAPIService {
    private let baseURL = "https://overpass-api.de/api/interpreter"
    
    /// Fetches restaurants within a bounding box
    func fetchRestaurants(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [Restaurant] {
        let query = createRestaurantQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let overpass = try decoder.decode(OverpassResponse.self, from: data)
        
        return overpass.elements.compactMap { element -> Restaurant? in
            guard let name = element.tags["name"],
                  let lat = element.lat,
                  let lon = element.lon else { return nil }
            
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
                type: element.type
            )
        }
    }
    
    /// Fetches fast food restaurants within five miles of the provided coordinate.
    func fetchFastFoodRestaurants(near coordinate: CLLocationCoordinate2D) async throws -> [Restaurant] {
        let radius = 5.0 * 1609.34 // 5 miles in meters
        let query = """
        [out:json];
        (
          node["amenity"="restaurant"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
          node["amenity"="fast_food"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
        );
        out body;
        """
        
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = query.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let overpass = try decoder.decode(OverpassResponse.self, from: data)
        
        return overpass.elements.compactMap { element -> Restaurant? in
            guard let name = element.tags["name"],
                  let lat = element.lat,
                  let lon = element.lon else { return nil }
            
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
                type: element.type
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func createRestaurantQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        """
        [out:json][timeout:25];
        (
          node["amenity"="restaurant"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          way["amenity"="restaurant"](\(minLat),\(minLon),\(maxLat),\(maxLon));
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

// MARK: - Test Function
extension OverpassAPIService {
    static func testConnection() async {
        let service = OverpassAPIService()
        
        // Test with a small area in San Francisco
        let minLat = 37.7749
        let minLon = -122.4194
        let maxLat = 37.7849
        let maxLon = -122.4094
        
        do {
            let restaurants = try await service.fetchRestaurants(
                minLat: minLat,
                minLon: minLon,
                maxLat: maxLat,
                maxLon: maxLon
            )
            
            print("Successfully fetched \(restaurants.count) restaurants")
            
            // Print first few restaurants for verification
            for (index, restaurant) in restaurants.prefix(3).enumerated() {
                print("\nRestaurant \(index + 1):")
                print("ID: \(restaurant.id)")
                print("Name: \(restaurant.name)")
                print("Location: \(restaurant.latitude), \(restaurant.longitude)")
                print("Cuisine: \(restaurant.cuisine ?? "Unknown")")
                print("Address: \(restaurant.address ?? "Unknown")")
            }
            
        } catch {
            print("Error fetching restaurants: \(error)")
        }
    }
}
