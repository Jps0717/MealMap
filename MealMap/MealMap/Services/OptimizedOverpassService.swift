import Foundation
import CoreLocation
import MapKit

// MARK: - Optimized Two-Stage Overpass API Service
@MainActor
class OptimizedOverpassService: ObservableObject {
    static let shared = OptimizedOverpassService()
    
    // MARK: - Configuration
    private let baseURL = "https://overpass-api.de/api/interpreter"
    private let session: URLSession
    private let maxResultsPerTile = 50
    private let tileSize: CLLocationDegrees = 0.01 // ~1km tiles
    
    // MARK: - Caching
    private let cache = NSCache<NSString, CachedOverpassResult>()
    private let diskCache = OverpassDiskCache()
    
    // MARK: - Rate Limiting & Backoff
    private var lastRequestTime: Date = Date.distantPast
    private var currentBackoffDelay: TimeInterval = 1.0
    private let maxBackoffDelay: TimeInterval = 60.0
    private let minRequestInterval: TimeInterval = 1.0
    
    // MARK: - Performance Tracking
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastLoadTime: TimeInterval = 0
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
        
        // Configure cache
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    // MARK: - Initial Load (Minimal Data)
    func loadRestaurantsMinimal(
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance = 2000
    ) async throws -> [RestaurantStub] {
        let startTime = Date()
        isLoading = true
        errorMessage = nil
        
        defer {
            Task { @MainActor in
                self.isLoading = false
                self.lastLoadTime = Date().timeIntervalSince(startTime)
            }
        }
        
        // Check cache first
        let cacheKey = "minimal_\(center.latitude)_\(center.longitude)_\(radius)"
        if let cached = getCachedResult(key: cacheKey) {
            debugLog("🚀 CACHE HIT: Returning \(cached.restaurants.count) restaurants from cache")
            return cached.restaurants
        }
        
        // Determine if we need tile splitting
        let estimatedResults = await estimateResultCount(center: center, radius: radius)
        
        if estimatedResults > maxResultsPerTile {
            debugLog("🧩 TILE SPLIT: Estimated \(estimatedResults) results, splitting into tiles")
            return try await loadWithTileSplitting(center: center, radius: radius)
        } else {
            debugLog("🎯 DIRECT LOAD: Estimated \(estimatedResults) results, loading directly")
            return try await loadDirectMinimal(center: center, radius: radius, cacheKey: cacheKey)
        }
    }
    
    private func loadDirectMinimal(
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        cacheKey: String
    ) async throws -> [RestaurantStub] {
        
        // Rate limiting
        await enforceRateLimit()
        
        let query = createMinimalQuery(center: center, radius: radius)
        let restaurants = try await executeCSVQuery(query: query)
        
        // Cache results
        let cached = CachedOverpassResult(restaurants: restaurants, timestamp: Date())
        cache.setObject(cached, forKey: cacheKey as NSString)
        diskCache.store(cached, forKey: cacheKey)
        
        debugLog("✅ MINIMAL LOAD: \(restaurants.count) restaurants loaded and cached")
        return restaurants
    }
    
    private func loadWithTileSplitting(
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance
    ) async throws -> [RestaurantStub] {
        
        let tiles = calculateTiles(center: center, radius: radius)
        var allRestaurants: [RestaurantStub] = []
        
        debugLog("🧩 TILE SPLIT: Processing \(tiles.count) tiles")
        
        for tile in tiles {
            do {
                let tileRestaurants = try await loadTile(tile: tile)
                allRestaurants.append(contentsOf: tileRestaurants)
                
                // Rate limiting between tiles
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            } catch {
                debugLog("⚠️ TILE ERROR: \(error.localizedDescription)")
                // Continue with other tiles
            }
        }
        
        // Remove duplicates and limit results
        let uniqueRestaurants = removeDuplicates(allRestaurants)
        let limitedResults = Array(uniqueRestaurants.prefix(maxResultsPerTile * 2))
        
        debugLog("✅ TILE SPLIT COMPLETE: \(limitedResults.count) unique restaurants from \(tiles.count) tiles")
        return limitedResults
    }
    
    // MARK: - Detailed Load (On-Tap)
    func loadRestaurantDetails(
        location: CLLocationCoordinate2D,
        stub: RestaurantStub
    ) async throws -> RestaurantDetails {
        
        let cacheKey = "details_\(location.latitude)_\(location.longitude)"
        if let cached = getCachedDetails(key: cacheKey) {
            debugLog("🚀 DETAILS CACHE HIT: \(stub.name)")
            return cached
        }
        
        await enforceRateLimit()
        
        let query = createDetailQuery(location: location)
        let details = try await executeJSONQuery(query: query, stub: stub)
        
        // Cache details
        diskCache.storeDetails(details, forKey: cacheKey)
        
        debugLog("✅ DETAILS LOADED: \(stub.name) - \(details.cuisine ?? "Unknown cuisine")")
        return details
    }
    
    // MARK: - Query Creation
    private func createMinimalQuery(center: CLLocationCoordinate2D, radius: CLLocationDistance) -> String {
        return """
        [out:csv(name,amenity,::lat,::lon;false)][timeout:10];
        (
          nwr["amenity"~"^(restaurant|fast_food|cafe)$"](around:\(Int(radius)),\(center.latitude),\(center.longitude));
        )->.all;
        .all out center \(maxResultsPerTile);
        """
    }
    
    private func createDetailQuery(location: CLLocationCoordinate2D) -> String {
        return """
        [out:json][timeout:5];
        (
          nwr["amenity"~"^(restaurant|fast_food|cafe)$"](around:50,\(location.latitude),\(location.longitude));
        )->.target;
        .target out center meta;
        """
    }
    
    // MARK: - Query Execution
    private func executeCSVQuery(query: String) async throws -> [RestaurantStub] {
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "data=\(query)".data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OverpassError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            await applyBackoff()
            throw OverpassError.rateLimited
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OverpassError.httpError(httpResponse.statusCode)
        }
        
        // Reset backoff on success
        currentBackoffDelay = 1.0
        
        return try parseCSVResponse(data: data)
    }
    
    private func executeJSONQuery(query: String, stub: RestaurantStub) async throws -> RestaurantDetails {
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "data=\(query)".data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OverpassError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            await applyBackoff()
            throw OverpassError.rateLimited
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OverpassError.httpError(httpResponse.statusCode)
        }
        
        return try parseJSONResponse(data: data, stub: stub)
    }
    
    // MARK: - Parsing
    private func parseCSVResponse(data: Data) throws -> [RestaurantStub] {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw OverpassError.invalidData
        }
        
        let lines = csvString.components(separatedBy: .newlines)
        var restaurants: [RestaurantStub] = []
        
        for line in lines.dropFirst() { // Skip header
            if line.isEmpty { continue }
            
            let columns = line.components(separatedBy: "\t")
            guard columns.count >= 4 else { continue }
            
            let name = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let amenity = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !name.isEmpty,
                  let lat = Double(columns[2]),
                  let lon = Double(columns[3]) else { continue }
            
            let stub = RestaurantStub(
                name: name,
                amenity: amenity,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                hasNutritionData: RestaurantData.hasNutritionData(for: name)
            )
            
            restaurants.append(stub)
        }
        
        return restaurants
    }
    
    private func parseJSONResponse(data: Data, stub: RestaurantStub) throws -> RestaurantDetails {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let elements = json?["elements"] as? [[String: Any]] ?? []
        
        // Find the closest element to our stub
        guard let element = elements.first else {
            throw OverpassError.noResults
        }
        
        let tags = element["tags"] as? [String: String] ?? [:]
        
        return RestaurantDetails(
            stub: stub,
            cuisine: tags["cuisine"],
            dietVegan: tags["diet:vegan"],
            nutritionCalories: tags["nutrition:calories"],
            openingHours: tags["opening_hours"],
            website: tags["website"],
            phone: tags["phone"],
            wheelchairAccessible: tags["wheelchair"]
        )
    }
    
    // MARK: - Helper Methods
    private func estimateResultCount(center: CLLocationCoordinate2D, radius: CLLocationDistance) async -> Int {
        // Simple heuristic based on location density
        // Urban areas: ~30-50 restaurants per km²
        // Suburban: ~10-20 restaurants per km²
        // Rural: ~5-10 restaurants per km²
        
        let area = Double(radius * radius) * .pi / 1_000_000 // km²
        return Int(area * 25) // Average density estimate
    }
    
    private func calculateTiles(center: CLLocationCoordinate2D, radius: CLLocationDistance) -> [MapTile] {
        let radiusInDegrees = radius / 111_000.0 // Rough conversion
        let tilesPerSide = Int(ceil(radiusInDegrees * 2 / tileSize))
        
        var tiles: [MapTile] = []
        
        for i in 0..<tilesPerSide {
            for j in 0..<tilesPerSide {
                let tileLat = center.latitude - radiusInDegrees + Double(i) * tileSize
                let tileLon = center.longitude - radiusInDegrees + Double(j) * tileSize
                
                let tile = MapTile(
                    southWest: CLLocationCoordinate2D(latitude: tileLat, longitude: tileLon),
                    northEast: CLLocationCoordinate2D(latitude: tileLat + tileSize, longitude: tileLon + tileSize)
                )
                
                tiles.append(tile)
            }
        }
        
        return tiles
    }
    
    private func loadTile(tile: MapTile) async throws -> [RestaurantStub] {
        let query = """
        [out:csv(name,amenity,::lat,::lon;false)][timeout:5];
        (
          nwr["amenity"~"^(restaurant|fast_food|cafe)$"](\(tile.southWest.latitude),\(tile.southWest.longitude),\(tile.northEast.latitude),\(tile.northEast.longitude));
        )->.all;
        .all out center \(maxResultsPerTile);
        """
        
        return try await executeCSVQuery(query: query)
    }
    
    private func removeDuplicates(_ restaurants: [RestaurantStub]) -> [RestaurantStub] {
        var unique: [RestaurantStub] = []
        var seen: Set<String> = []
        
        for restaurant in restaurants {
            let key = "\(restaurant.name)_\(restaurant.coordinate.latitude)_\(restaurant.coordinate.longitude)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(restaurant)
            }
        }
        
        return unique
    }
    
    // MARK: - Rate Limiting & Backoff
    private func enforceRateLimit() async {
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minRequestInterval {
            let delay = minRequestInterval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
    
    private func applyBackoff() async {
        debugLog("⏱️ BACKOFF: Waiting \(currentBackoffDelay)s before retry")
        try? await Task.sleep(nanoseconds: UInt64(currentBackoffDelay * 1_000_000_000))
        currentBackoffDelay = min(currentBackoffDelay * 2, maxBackoffDelay)
    }
    
    // MARK: - Caching
    private func getCachedResult(key: String) -> CachedOverpassResult? {
        // Check memory cache
        if let cached = cache.object(forKey: key as NSString) {
            if cached.isValid {
                return cached
            } else {
                cache.removeObject(forKey: key as NSString)
            }
        }
        
        // Check disk cache
        return diskCache.retrieve(forKey: key)
    }
    
    private func getCachedDetails(key: String) -> RestaurantDetails? {
        return diskCache.retrieveDetails(forKey: key)
    }
}

// MARK: - Data Models
struct RestaurantStub: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let amenity: String
    let coordinate: CLLocationCoordinate2D
    let hasNutritionData: Bool
    
    // UI Properties
    var emoji: String {
        RestaurantEmojiService.emoji(for: amenity, cuisine: nil)
    }
    
    var pinColorHex: String {
        hasNutritionData ? "#4CAF50" : "#9E9E9E" // Green for nutrition data, gray for no data
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
    
    static func == (lhs: RestaurantStub, rhs: RestaurantStub) -> Bool {
        lhs.name == rhs.name &&
        abs(lhs.coordinate.latitude - rhs.coordinate.latitude) < 0.0001 &&
        abs(lhs.coordinate.longitude - rhs.coordinate.longitude) < 0.0001
    }
}

struct RestaurantDetails {
    let stub: RestaurantStub
    let cuisine: String?
    let dietVegan: String?
    let nutritionCalories: String?
    let openingHours: String?
    let website: String?
    let phone: String?
    let wheelchairAccessible: String?
    
    // Enhanced UI Properties
    var cuisineEmoji: String {
        RestaurantEmojiService.emoji(for: stub.amenity, cuisine: cuisine)
    }
    
    var isVeganFriendly: Bool {
        dietVegan?.lowercased().contains("yes") == true ||
        cuisine?.lowercased().contains("vegan") == true
    }
    
    var hasNutritionInfo: Bool {
        nutritionCalories != nil || stub.hasNutritionData
    }
}

struct MapTile {
    let southWest: CLLocationCoordinate2D
    let northEast: CLLocationCoordinate2D
}

class CachedOverpassResult: NSObject {
    let restaurants: [RestaurantStub]
    let timestamp: Date
    private let maxAge: TimeInterval = 300 // 5 minutes
    
    init(restaurants: [RestaurantStub], timestamp: Date) {
        self.restaurants = restaurants
        self.timestamp = timestamp
    }
    
    var isValid: Bool {
        Date().timeIntervalSince(timestamp) < maxAge
    }
}

// MARK: - Error Handling
enum OverpassError: Error, LocalizedError {
    case invalidResponse
    case invalidData
    case rateLimited
    case httpError(Int)
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Overpass API"
        case .invalidData:
            return "Could not parse response data"
        case .rateLimited:
            return "Rate limited by Overpass API"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .noResults:
            return "No results found"
        }
    }
}
