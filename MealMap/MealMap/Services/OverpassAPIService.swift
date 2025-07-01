import Foundation
import CoreLocation
import SwiftUI

/// Enhanced Restaurant Model with improved nutrition data detection
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
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    func distanceFrom(_ coordinate: CLLocationCoordinate2D) -> Double {
        let restaurantLocation = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distanceInMeters = restaurantLocation.distance(from: userLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        return distanceInMiles
    }
    
    // ENHANCED: Improved nutrition data detection
    var hasNutritionData: Bool {
        // Use the RestaurantData helper for consistent detection
        return RestaurantData.hasNutritionData(for: self.name)
    }
    
    // Get restaurant ID for API calls
    var restaurantID: String? {
        return RestaurantData.getRestaurantID(for: self.name)
    }
    
    // Enhanced emoji logic based on restaurant name and type
    var emoji: String {
        let name = self.name.lowercased()
        
        // Chain-specific emojis
        if name.contains("mcdonald") { return "🍟" }
        if name.contains("burger king") { return "👑" }
        if name.contains("subway") { return "🥪" }
        if name.contains("starbucks") { return "☕" }
        if name.contains("domino") { return "🍕" }
        if name.contains("pizza hut") { return "🍕" }
        if name.contains("taco bell") { return "🌮" }
        if name.contains("chipotle") { return "🌯" }
        if name.contains("wendy") { return "🍔" }
        if name.contains("kfc") { return "🍗" }
        if name.contains("popeyes") { return "🍗" }
        if name.contains("chick-fil-a") { return "🐔" }
        if name.contains("dunkin") { return "🍩" }
        if name.contains("baskin") || name.contains("dairy queen") { return "🍦" }
        if name.contains("panera") { return "🥖" }
        if name.contains("five guys") { return "🍔" }
        if name.contains("in-n-out") { return "🍔" }
        if name.contains("shake shack") { return "🥤" }
        
        // Cuisine-specific emojis
        if name.contains("sushi") || cuisine?.lowercased().contains("sushi") == true { return "🍣" }
        if name.contains("chinese") || cuisine?.lowercased().contains("chinese") == true { return "🥡" }
        if name.contains("italian") || cuisine?.lowercased().contains("italian") == true { return "🍝" }
        if name.contains("mexican") || cuisine?.lowercased().contains("mexican") == true { return "🌮" }
        if name.contains("thai") || cuisine?.lowercased().contains("thai") == true { return "🍜" }
        if name.contains("indian") || cuisine?.lowercased().contains("indian") == true { return "🍛" }
        if name.contains("seafood") || cuisine?.lowercased().contains("seafood") == true { return "🦐" }
        if name.contains("steakhouse") || name.contains("steak") { return "🥩" }
        if name.contains("bbq") || name.contains("barbecue") { return "🍖" }
        if name.contains("deli") { return "🥪" }
        if name.contains("bakery") { return "🧁" }
        if name.contains("ice cream") { return "🍦" }
        
        // Type-based fallbacks
        switch amenityType {
        case "fast_food":
            return "🍔"
        case "restaurant":
            return "🍽️"
        case "cafe":
            return "☕"
        case "bar", "pub":
            return "🍻"
        case "bakery":
            return "🥖"
        case "ice_cream":
            return "🍦"
        case "food_court":
            return "🍱"
        default:
            return "🍽️"
        }
    }
    
    // ENHANCED: Color based on nutrition data availability
    var pinColor: Color {
        // Priority: Nutrition data gets distinctive colors
        if hasNutritionData {
            return .green // Nutrition data available - bright green
        }
        
        // Fallback color by amenity type
        switch amenityType {
        case "fast_food":
            return .orange
        case "restaurant":
            return .blue
        case "cafe":
            return .brown
        case "bar", "pub":
            return .purple
        case "bakery":
            return .pink
        case "ice_cream":
            return .cyan
        case "food_court":
            return .indigo
        default:
            return .gray
        }
    }
    
    // Background color for contrast
    var pinBackgroundColor: Color {
        return pinColor.opacity(0.9)
    }
    
    func matchesCategory(_ category: RestaurantCategory) -> Bool {
        let name = self.name.lowercased()
        let cuisine = self.cuisine?.lowercased() ?? ""
        
        switch category {
        case .fastFood:
            return hasNutritionData || amenityType == "fast_food"
            
        case .healthy:
            return name.contains("salad") || name.contains("fresh") || name.contains("bowl") ||
                   name.contains("juice") || name.contains("smoothie") || name.contains("organic")
            
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
}

/// Enhanced Overpass API Service with better performance
final class OverpassAPIService {
    private let baseURLs = [
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass-api.de/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ]
    private var currentURLIndex = 0
    
    /// Direct map viewport fetch optimized for nutrition chains
    func fetchRestaurants(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [Restaurant] {
        debugLog("🗺️ DIRECT FETCH: Getting restaurants for map viewport")
        debugLog("🗺️ Bounds: (\(minLat), \(minLon)) to (\(maxLat), \(maxLon))")
        
        // ENHANCED: Query optimized for nutrition chains
        let query = createNutritionOptimizedQuery(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        
        let restaurants = try await executeQuery(query)
        
        debugLog("🗺️ SUCCESS: Found \(restaurants.count) restaurants for map viewport")
        return restaurants
    }
    
    /// BACKWARD COMPATIBILITY: Support existing methods
    func fetchAllNearbyRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 5.0) async throws -> [Restaurant] {
        // Convert to bounding box and use direct fetch
        let radiusInDegrees = radius / 69.0
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLon = coordinate.longitude - radiusInDegrees
        let maxLon = coordinate.longitude + radiusInDegrees
        
        return try await fetchRestaurants(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
    }
    
    func fetchRestaurantsForViewport(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double, zoomLevel: ZoomLevel) async throws -> [Restaurant] {
        return try await fetchRestaurants(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
    }
    
    func fetchNutritionRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 5.0) async throws -> [Restaurant] {
        let allRestaurants = try await fetchAllNearbyRestaurants(near: coordinate, radius: radius)
        return allRestaurants.filter { $0.hasNutritionData }
    }
    
    func fetchFastFoodRestaurants(near coordinate: CLLocationCoordinate2D, radius: Double = 5.0) async throws -> [Restaurant] {
        let allRestaurants = try await fetchAllNearbyRestaurants(near: coordinate, radius: radius)
        return allRestaurants.filter { $0.amenityType == "fast_food" || $0.hasNutritionData }
    }
    
    func fetchAllNearbyRestaurants(near coordinate: CLLocationCoordinate2D, zoomLevel: ZoomLevel) async throws -> [Restaurant] {
        return try await fetchAllNearbyRestaurants(near: coordinate, radius: 5.0)
    }
    
    /// ENHANCED: Query optimized for nutrition chains
    private func createNutritionOptimizedQuery(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) -> String {
        // Get known nutrition chain names for targeted querying
        let knownChains = ["McDonald's", "Subway", "Starbucks", "Burger King", "Taco Bell", 
                          "Chipotle", "Panera", "KFC", "Wendy's", "Domino's", "Pizza Hut",
                          "Dunkin", "Five Guys", "Chick-fil-A", "Popeyes"]
        
        // Create targeted queries for known chains
        let chainQueries = knownChains.map { chain in
            "node[\"name\"~\"\(chain)\",i][\"amenity\"~\"restaurant|fast_food|cafe\"]"
        }.joined(separator: ";\n  ")
        
        return """
        [out:json][timeout:12][bbox:\(minLat),\(minLon),\(maxLat),\(maxLon)];
        (
          // Known nutrition chains
          \(chainQueries);
          
          // All fast food
          node["amenity"="fast_food"];
          
          // Chain restaurants with brand names
          node["amenity"="restaurant"]["brand"];
          
          // Popular cafes
          node["amenity"="cafe"]["brand"];
        );
        out;
        """
    }
    
    /// EXECUTE QUERY: Enhanced execution with better error handling
    private func executeQuery(_ query: String) async throws -> [Restaurant] {
        guard let url = URL(string: baseURLs[currentURLIndex]) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = query.data(using: .utf8)
        request.timeoutInterval = 12 // Increased timeout
        
        debugLog("🌐 Querying: \(baseURLs[currentURLIndex])")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                debugLog("❌ HTTP Error: \(statusCode)")
                throw URLError(.badServerResponse)
            }
            
            let restaurants = try parseRestaurantsFromData(data)
            
            // ENHANCED: Filter and prioritize nutrition restaurants
            let nutritionRestaurants = restaurants.filter { $0.hasNutritionData }
            let otherRestaurants = restaurants.filter { !$0.hasNutritionData }
            
            debugLog("🍽️ Nutrition restaurants: \(nutritionRestaurants.count)")
            debugLog("🍽️ Other restaurants: \(otherRestaurants.count)")
            
            // Prioritize nutrition restaurants
            return nutritionRestaurants + Array(otherRestaurants.prefix(100))
            
        } catch {
            debugLog("❌ Query failed: \(error.localizedDescription)")
            
            // Try next server
            currentURLIndex = (currentURLIndex + 1) % baseURLs.count
            
            // Retry once with next server
            if currentURLIndex != 0 {
                debugLog("🔄 Retrying with: \(baseURLs[currentURLIndex])")
                return try await executeQuery(query)
            } else {
                throw error
            }
        }
    }
    
    /// Enhanced parser with better restaurant detection
    private func parseRestaurantsFromData(_ data: Data) throws -> [Restaurant] {
        let decoder = JSONDecoder()
        let overpass = try decoder.decode(OverpassResponse.self, from: data)
        
        debugLog("📡 Raw response: \(overpass.elements.count) elements")
        
        var restaurants: [Restaurant] = []
        var seenRestaurants: Set<String> = []
        
        for element in overpass.elements {
            // Must have coordinates
            guard let lat = element.lat, let lon = element.lon else { continue }
            
            // Must be food-related
            guard let amenityType = element.tags["amenity"],
                  ["fast_food", "restaurant", "cafe", "bar", "pub", "food_court", "ice_cream", "bakery"].contains(amenityType) else {
                continue
            }
            
            // Get name with fallbacks
            let name = element.tags["name"] ??
                      element.tags["brand"] ??
                      element.tags["operator"] ??
                      "\(amenityType.capitalized) #\(element.id)"
            
            // Skip if name is empty, too long, or already seen
            guard !name.isEmpty && name.count < 100 else { continue }
            
            let locationKey = "\(name)_\(String(format: "%.3f", lat))_\(String(format: "%.3f", lon))"
            guard !seenRestaurants.contains(locationKey) else { continue }
            seenRestaurants.insert(locationKey)
            
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
            
            restaurant.amenityType = amenityType
            restaurants.append(restaurant)
        }
        
        debugLog("✅ Parsed: \(restaurants.count) unique food locations")
        return restaurants
    }
}

// MARK: - Simplified Zoom Level (for backward compatibility)
enum ZoomLevel {
    case veryFar, far, medium, close, veryClose
    
    static func from(latitudeDelta: Double) -> ZoomLevel {
        switch latitudeDelta {
        case 0.2...: return .veryFar
        case 0.05..<0.2: return .far
        case 0.01..<0.05: return .medium
        case 0.002..<0.01: return .close
        default: return .veryClose
        }
    }
    
    var shouldShowPins: Bool {
        return true // Always show pins for simplicity
    }
    
    var maxRestaurants: Int {
        return 200 // Higher limit for better coverage
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
