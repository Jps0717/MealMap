import Foundation

struct CachedNutritionEntry: Codable {
    let restaurant: RestaurantNutritionData
    let timestamp: Date
}

final class NutritionDiskCache {
    private let fileURL: URL
    private let expiry: TimeInterval = 24 * 3600 // 24 hours
    private var cache: [String: CachedNutritionEntry] = [:]

    init() {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.fileURL = directory.appendingPathComponent("nutrition_cache.json")
        loadCache()
    }

    // Load cache from disk and remove expired entries
    private func loadCache() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: CachedNutritionEntry].self, from: data)
            let valid = decoded.filter { Date().timeIntervalSince($0.value.timestamp) < expiry }
            cache = valid
            // Remove expired entries on disk
            if valid.count != decoded.count { saveCache() }
        } catch {
            debugLog("Failed to load nutrition disk cache: \(error)")
        }
    }

    private func saveCache() {
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            debugLog("Failed to save nutrition disk cache: \(error)")
        }
    }

    func store(_ restaurant: RestaurantNutritionData) {
        cache[restaurant.restaurantName.lowercased()] = CachedNutritionEntry(restaurant: restaurant, timestamp: Date())
        saveCache()
    }

    func get(_ name: String) -> RestaurantNutritionData? {
        let key = name.lowercased()
        guard let entry = cache[key] else { return nil }
        if Date().timeIntervalSince(entry.timestamp) < expiry {
            return entry.restaurant
        } else {
            cache.removeValue(forKey: key)
            saveCache()
            return nil
        }
    }

    var allEntries: [RestaurantNutritionData] {
        cache.values.compactMap { entry in
            if Date().timeIntervalSince(entry.timestamp) < expiry {
                return entry.restaurant
            }
            return nil
        }
    }
}

