import Foundation
import CoreLocation

/// Model representing a fast food restaurant fetched from the Overpass API.
struct Restaurant: Identifiable, Equatable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
}

/// Service responsible for fetching nearby fast food restaurants using the Overpass API.
final class RestaurantService {
    /// Fetches fast food restaurants within five miles of the provided coordinate.
    /// - Parameter coordinate: The location to search around.
    /// - Returns: An array of `Restaurant` objects sorted by name.
    func fetchFastFoodRestaurants(near coordinate: CLLocationCoordinate2D) async throws -> [Restaurant] {
        // Radius of five miles in meters.
        let radius = 5.0 * 1609.34
        // Construct the Overpass query.
        let query = """
        [out:json];
        node[\"amenity\"=\"fast_food\"](around:\(radius),\(coordinate.latitude),\(coordinate.longitude));
        out body;
        """
        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else {
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
        let restaurants = overpass.elements.compactMap { element -> Restaurant? in
            guard let name = element.tags["name"] else { return nil }
            let address = element.tags["addr:full"] ?? element.tags["addr:street"]
            return Restaurant(
                id: element.id,
                name: name,
                latitude: element.lat,
                longitude: element.lon,
                address: address
            )
        }
        return restaurants.sorted { $0.name < $1.name }
    }
}

private struct OverpassResponse: Decodable {
    let elements: [Element]

    struct Element: Decodable {
        let id: Int
        let lat: Double
        let lon: Double
        let tags: [String: String]
    }
}
