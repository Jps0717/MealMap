import Foundation
import CoreLocation

class OverpassDiskCache {
    private let cacheDirectory: URL
    private let maxCacheAge: TimeInterval = 24 * 60 * 60 // 24 hours
    private let maxCacheSize: Int = 100 * 1024 * 1024 // 100MB
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("OverpassCache")
        
        // Create cache directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Clean up old cache files on init
        cleanupOldFiles()
    }
    
    // MARK: - Restaurant Stubs Cache
    func store(_ result: CachedOverpassResult, forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(CacheEntry(result: result))
            try data.write(to: fileURL)
            debugLog(" DISK CACHE: Stored \(result.restaurants.count) restaurants for key: \(key)")
        } catch {
            debugLog(" DISK CACHE ERROR: Failed to store \(key) - \(error)")
        }
    }
    
    func retrieve(forKey key: String) -> CachedOverpassResult? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let entry = try decoder.decode(CacheEntry.self, from: data)
            
            // Check if cache is still valid
            if Date().timeIntervalSince(entry.timestamp) < maxCacheAge {
                debugLog(" DISK CACHE HIT: Retrieved \(entry.restaurantData.count) restaurants for key: \(key)")
                return CachedOverpassResult(
                    restaurants: entry.restaurantData.map { $0.toRestaurantStub() },
                    timestamp: entry.timestamp
                )
            } else {
                // Remove expired cache
                try? FileManager.default.removeItem(at: fileURL)
                debugLog(" DISK CACHE: Removed expired cache for key: \(key)")
                return nil
            }
        } catch {
            debugLog(" DISK CACHE ERROR: Failed to retrieve \(key) - \(error)")
            return nil
        }
    }
    
    // MARK: - Restaurant Details Cache
    func storeDetails(_ details: RestaurantDetails, forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("details_\(key).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let entry = CacheDetailsEntry(details: details, timestamp: Date())
            let data = try encoder.encode(entry)
            try data.write(to: fileURL)
            debugLog(" DISK CACHE: Stored details for \(details.stub.name)")
        } catch {
            debugLog(" DISK CACHE ERROR: Failed to store details - \(error)")
        }
    }
    
    func retrieveDetails(forKey key: String) -> RestaurantDetails? {
        let fileURL = cacheDirectory.appendingPathComponent("details_\(key).json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let entry = try decoder.decode(CacheDetailsEntry.self, from: data)
            
            // Check if cache is still valid (shorter expiry for details)
            if Date().timeIntervalSince(entry.timestamp) < maxCacheAge / 2 {
                debugLog(" DISK CACHE HIT: Retrieved details for \(entry.stubData.name)")
                return RestaurantDetails(
                    stub: entry.stubData.toRestaurantStub(),
                    cuisine: entry.cuisine,
                    dietVegan: entry.dietVegan,
                    nutritionCalories: entry.nutritionCalories,
                    openingHours: entry.openingHours,
                    website: entry.website,
                    phone: entry.phone,
                    wheelchairAccessible: entry.wheelchairAccessible
                )
            } else {
                // Remove expired cache
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
        } catch {
            debugLog(" DISK CACHE ERROR: Failed to retrieve details - \(error)")
            return nil
        }
    }
    
    // MARK: - Cache Management
    private func cleanupOldFiles() {
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            let currentDate = Date()
            
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = attributes.contentModificationDate {
                    if currentDate.timeIntervalSince(modificationDate) > maxCacheAge {
                        try fileManager.removeItem(at: file)
                        debugLog(" DISK CACHE: Removed old cache file: \(file.lastPathComponent)")
                    }
                }
            }
        } catch {
            debugLog(" DISK CACHE: Cleanup error - \(error)")
        }
    }
    
    func getCacheSize() -> Int {
        let fileManager = FileManager.default
        var totalSize = 0
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.fileSizeKey])
                totalSize += attributes.fileSize ?? 0
            }
        } catch {
            debugLog(" DISK CACHE: Size calculation error - \(error)")
        }
        
        return totalSize
    }
    
    func clearCache() {
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
            debugLog(" DISK CACHE: Cleared all cache files")
        } catch {
            debugLog(" DISK CACHE: Clear error - \(error)")
        }
    }
}

// MARK: - Cache Entry Models
private struct CacheEntry: Codable {
    let timestamp: Date
    let restaurantData: [RestaurantStubData]
    
    init(result: CachedOverpassResult) {
        self.timestamp = result.timestamp
        self.restaurantData = result.restaurants.map { RestaurantStubData(from: $0) }
    }
}

private struct CacheDetailsEntry: Codable {
    let timestamp: Date
    let stubData: RestaurantStubData
    let cuisine: String?
    let dietVegan: String?
    let nutritionCalories: String?
    let openingHours: String?
    let website: String?
    let phone: String?
    let wheelchairAccessible: String?
    
    init(details: RestaurantDetails, timestamp: Date) {
        self.timestamp = timestamp
        self.stubData = RestaurantStubData(from: details.stub)
        self.cuisine = details.cuisine
        self.dietVegan = details.dietVegan
        self.nutritionCalories = details.nutritionCalories
        self.openingHours = details.openingHours
        self.website = details.website
        self.phone = details.phone
        self.wheelchairAccessible = details.wheelchairAccessible
    }
}

private struct RestaurantStubData: Codable {
    let name: String
    let amenity: String
    let latitude: Double
    let longitude: Double
    let hasNutritionData: Bool
    
    init(from stub: RestaurantStub) {
        self.name = stub.name
        self.amenity = stub.amenity
        self.latitude = stub.coordinate.latitude
        self.longitude = stub.coordinate.longitude
        self.hasNutritionData = stub.hasNutritionData
    }
    
    func toRestaurantStub() -> RestaurantStub {
        return RestaurantStub(
            name: name,
            amenity: amenity,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            hasNutritionData: hasNutritionData
        )
    }
}
