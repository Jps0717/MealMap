import Foundation
import CoreLocation

class CacheManager {
    static let shared = CacheManager()
    
    private init() {
        loadRestaurantMappingFromCSV()
    }
    
    // MARK: - Restaurant Data Cache
    private var restaurantCache: [String: [Restaurant]] = [:]
    private var restaurantCacheTimestamps: [String: Date] = [:]
    private let restaurantCacheExpiry: TimeInterval = 300 // 5 minutes
    
    // MARK: - Nutrition Data Cache
    private var nutritionCache: [String: RestaurantNutritionData] = [:]
    private var nutritionCacheTimestamps: [String: Date] = [:]
    private let nutritionCacheExpiry: TimeInterval = 3600 // 1 hour
    
    // MARK: - Restaurant Mapping Cache
    private var restaurantMapping: [String: String] = [:]
    
    // MARK: - Search Results Cache
    private var searchCache: [String: [Restaurant]] = [:]
    private var searchCacheTimestamps: [String: Date] = [:]
    private let searchCacheExpiry: TimeInterval = 600 // 10 minutes
    
    // MARK: - Location-based Cache
    private var locationBasedCache: [String: [Restaurant]] = [:]
    private var locationCacheTimestamps: [String: Date] = [:]
    private let locationCacheExpiry: TimeInterval = 900 // 15 minutes
    
    // MARK: - Restaurant Mapping
    private func loadRestaurantMappingFromCSV() {
        // Try multiple possible paths for the mapfile.csv
        var path: String?
        let possiblePaths = [
            Bundle.main.path(forResource: "mapfile", ofType: "csv", inDirectory: "Services/restaurant_data"),
            Bundle.main.path(forResource: "mapfile", ofType: "csv"),
            Bundle.main.path(forResource: "mapfile", ofType: "csv", inDirectory: "restaurant_data")
        ]
        
        for possiblePath in possiblePaths {
            if let validPath = possiblePath, FileManager.default.fileExists(atPath: validPath) {
                path = validPath
                print("Found mapfile.csv at: \(validPath)")
                break
            }
        }
        
        guard let csvPath = path else {
            print("❌ Could not find mapfile.csv in any of these locations:")
            for possiblePath in possiblePaths {
                print("  - \(possiblePath ?? "nil")")
            }
            
            // List all CSV files in the bundle for debugging
            if let bundlePath = Bundle.main.resourcePath {
                let fileManager = FileManager.default
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: bundlePath)
                    let csvFiles = contents.filter { $0.hasSuffix(".csv") }
                    print("📁 Available CSV files in bundle: \(csvFiles)")
                } catch {
                    print("Could not list bundle contents: \(error)")
                }
            }
            return
        }
        
        guard let content = try? String(contentsOfFile: csvPath) else {
            print("❌ Could not read mapfile.csv from: \(csvPath)")
            return
        }
        
        print("✅ Successfully loaded mapfile.csv with \(content.count) characters")
        
        let lines = content.components(separatedBy: .newlines)
        print("📄 Processing \(lines.count) lines from CSV")
        
        for line in lines.dropFirst() { // Skip header
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            let components = line.components(separatedBy: ",")
            guard components.count >= 2 else { continue }
            
            let restaurantName = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let restaurantID = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Store both exact match and normalized lowercase version
            restaurantMapping[restaurantName] = restaurantID
            restaurantMapping[restaurantName.lowercased()] = restaurantID
            
            // Also store common variations
            if restaurantName == "Dunkin' Donuts" {
                restaurantMapping["Dunkin'"] = restaurantID
                restaurantMapping["dunkin'"] = restaurantID
                restaurantMapping["Dunkin"] = restaurantID
                restaurantMapping["dunkin"] = restaurantID
            }
            
            if restaurantName == "McDonald's" {
                restaurantMapping["McDonalds"] = restaurantID
                restaurantMapping["mcdonalds"] = restaurantID
            }
        }
        
        print("✅ Loaded \(restaurantMapping.count) restaurant mappings from CSV")
        print("🔍 Sample mappings: Chipotle -> \(restaurantMapping["Chipotle"] ?? "not found"), McDonald's -> \(restaurantMapping["McDonald's"] ?? "not found")")
    }
    
    func getRestaurantID(for restaurantName: String) -> String? {
        print("🔍 Looking up restaurant ID for: '\(restaurantName)'")
        
        // Try exact match first
        if let id = restaurantMapping[restaurantName] {
            print("✅ Found exact match: '\(restaurantName)' -> \(id)")
            return id
        }
        
        // Try lowercase match
        if let id = restaurantMapping[restaurantName.lowercased()] {
            print("✅ Found lowercase match: '\(restaurantName)' -> \(id)")
            return id
        }
        
        // Try partial matching for common cases
        let normalized = restaurantName.lowercased()
        for (key, value) in restaurantMapping {
            if key.lowercased().contains(normalized) || normalized.contains(key.lowercased()) {
                print("✅ Found partial match: '\(restaurantName)' -> '\(key)' -> \(value)")
                return value
            }
        }
        
        print("❌ No nutrition data mapping found for: '\(restaurantName)'")
        print("📋 Available restaurants: \(Array(restaurantMapping.keys).prefix(10))")
        return nil
    }
    
    // MARK: - Restaurant Data Caching
    func cacheRestaurants(_ restaurants: [Restaurant], for key: String) {
        restaurantCache[key] = restaurants
        restaurantCacheTimestamps[key] = Date()
        print("Cached \(restaurants.count) restaurants for key: \(key)")
    }
    
    func getCachedRestaurants(for key: String) -> [Restaurant]? {
        guard let timestamp = restaurantCacheTimestamps[key],
              Date().timeIntervalSince(timestamp) < restaurantCacheExpiry,
              let restaurants = restaurantCache[key] else {
            return nil
        }
        
        print("Retrieved \(restaurants.count) cached restaurants for key: \(key)")
        return restaurants
    }
    
    // MARK: - Location-based Caching
    func cacheLocationRestaurants(_ restaurants: [Restaurant], for location: CLLocationCoordinate2D, radius: Double = 5000) {
        let key = locationCacheKey(for: location, radius: radius)
        locationBasedCache[key] = restaurants
        locationCacheTimestamps[key] = Date()
        print("Cached \(restaurants.count) restaurants for location: \(location.latitude), \(location.longitude)")
    }
    
    func getCachedLocationRestaurants(for location: CLLocationCoordinate2D, radius: Double = 5000) -> [Restaurant]? {
        let key = locationCacheKey(for: location, radius: radius)
        
        guard let timestamp = locationCacheTimestamps[key],
              Date().timeIntervalSince(timestamp) < locationCacheExpiry,
              let restaurants = locationBasedCache[key] else {
            return nil
        }
        
        print("Retrieved \(restaurants.count) cached restaurants for location: \(location.latitude), \(location.longitude)")
        return restaurants
    }
    
    private func locationCacheKey(for location: CLLocationCoordinate2D, radius: Double) -> String {
        // Round to 3 decimal places for cache key grouping
        let lat = String(format: "%.3f", location.latitude)
        let lon = String(format: "%.3f", location.longitude)
        return "\(lat),\(lon),\(Int(radius))"
    }
    
    // MARK: - Nutrition Data Caching
    func cacheNutritionData(_ data: RestaurantNutritionData, for restaurantName: String) {
        nutritionCache[restaurantName] = data
        nutritionCacheTimestamps[restaurantName] = Date()
        print("Cached nutrition data for: \(restaurantName) with \(data.items.count) items")
    }
    
    func getCachedNutritionData(for restaurantName: String) -> RestaurantNutritionData? {
        guard let timestamp = nutritionCacheTimestamps[restaurantName],
              Date().timeIntervalSince(timestamp) < nutritionCacheExpiry,
              let data = nutritionCache[restaurantName] else {
            return nil
        }
        
        print("Retrieved cached nutrition data for: \(restaurantName) with \(data.items.count) items")
        return data
    }
    
    // MARK: - Search Results Caching
    func cacheSearchResults(_ restaurants: [Restaurant], for query: String) {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        searchCache[normalizedQuery] = restaurants
        searchCacheTimestamps[normalizedQuery] = Date()
        print("Cached \(restaurants.count) search results for query: \(normalizedQuery)")
    }
    
    func getCachedSearchResults(for query: String) -> [Restaurant]? {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let timestamp = searchCacheTimestamps[normalizedQuery],
              Date().timeIntervalSince(timestamp) < searchCacheExpiry,
              let restaurants = searchCache[normalizedQuery] else {
            return nil
        }
        
        print("Retrieved \(restaurants.count) cached search results for query: \(normalizedQuery)")
        return restaurants
    }
    
    // MARK: - Cache Management
    func clearExpiredCache() {
        let now = Date()
        
        // Clear expired restaurant cache
        for (key, timestamp) in restaurantCacheTimestamps {
            if now.timeIntervalSince(timestamp) > restaurantCacheExpiry {
                restaurantCache.removeValue(forKey: key)
                restaurantCacheTimestamps.removeValue(forKey: key)
            }
        }
        
        // Clear expired nutrition cache
        for (key, timestamp) in nutritionCacheTimestamps {
            if now.timeIntervalSince(timestamp) > nutritionCacheExpiry {
                nutritionCache.removeValue(forKey: key)
                nutritionCacheTimestamps.removeValue(forKey: key)
            }
        }
        
        // Clear expired search cache
        for (key, timestamp) in searchCacheTimestamps {
            if now.timeIntervalSince(timestamp) > searchCacheExpiry {
                searchCache.removeValue(forKey: key)
                searchCacheTimestamps.removeValue(forKey: key)
            }
        }
        
        // Clear expired location cache
        for (key, timestamp) in locationCacheTimestamps {
            if now.timeIntervalSince(timestamp) > locationCacheExpiry {
                locationBasedCache.removeValue(forKey: key)
                locationCacheTimestamps.removeValue(forKey: key)
            }
        }
        
        print("Cleared expired cache entries")
    }
    
    func clearAllCache() {
        restaurantCache.removeAll()
        restaurantCacheTimestamps.removeAll()
        nutritionCache.removeAll()
        nutritionCacheTimestamps.removeAll()
        searchCache.removeAll()
        searchCacheTimestamps.removeAll()
        locationBasedCache.removeAll()
        locationCacheTimestamps.removeAll()
        
        print("Cleared all cache")
    }
    
    // MARK: - Cache Statistics
    func getCacheStats() -> CacheStats {
        return CacheStats(
            restaurantCacheSize: restaurantCache.count,
            nutritionCacheSize: nutritionCache.count,
            searchCacheSize: searchCache.count,
            locationCacheSize: locationBasedCache.count,
            totalCachedRestaurants: restaurantCache.values.reduce(0) { $0 + $1.count },
            totalCachedNutritionItems: nutritionCache.values.reduce(0) { $0 + $1.items.count }
        )
    }
}

struct CacheStats {
    let restaurantCacheSize: Int
    let nutritionCacheSize: Int
    let searchCacheSize: Int
    let locationCacheSize: Int
    let totalCachedRestaurants: Int
    let totalCachedNutritionItems: Int
}
