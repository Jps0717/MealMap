import Foundation
import UIKit

class NutritionDataManager: ObservableObject {
    @Published var isLoading = false
    @Published var currentRestaurantData: RestaurantNutritionData?
    @Published var errorMessage: String?
    
    private let cache = CacheManager.shared
    
    private var memoryCache: [String: CachedNutritionItem] = [:]
    private var loadingTasks: [String: Task<RestaurantNutritionData?, Never>] = [:]
    
    private let maxMemoryCacheSize = 20
    private let cacheExpiryTime: TimeInterval = 600 // 10 minutes
    private let backgroundQueue = DispatchQueue(label: "nutrition.parsing", qos: .utility)
    
    private var csvParsingCache: [String: [String]] = [:]
    
    init() {
        print("NutritionDataManager initialized with enhanced caching system")
        setupMemoryManagement()
    }
    
    private func setupMemoryManagement() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearExpiredCache()
        }
    }
    
    func loadNutritionData(for restaurantName: String) {
        let cacheKey = restaurantName.lowercased()
        print("🍽️ Loading nutrition data for restaurant: '\(restaurantName)'")
        
        if let cachedItem = memoryCache[cacheKey], !cachedItem.isExpired {
            print("💾 Using memory cached nutrition data for \(restaurantName)")
            self.isLoading = false
            self.currentRestaurantData = cachedItem.data
            self.errorMessage = nil
            return
        }
        
        if let cachedData = cache.getCachedNutritionData(for: restaurantName) {
            print("💿 Using persistent cached nutrition data for \(restaurantName)")
            self.isLoading = false
            self.currentRestaurantData = cachedData
            self.errorMessage = nil
            updateMemoryCache(cacheKey, cachedData)
            return
        }
        
        if let existingTask = loadingTasks[cacheKey] {
            print("⏳ Already loading \(restaurantName), waiting for completion...")
            isLoading = true
            errorMessage = nil
            
            Task {
                if let result = await existingTask.value {
                    await MainActor.run {
                        self.isLoading = false
                        self.currentRestaurantData = result
                        self.updateMemoryCache(cacheKey, result)
                    }
                }
                loadingTasks.removeValue(forKey: cacheKey)
            }
            return
        }
        
        guard let restaurantID = cache.getRestaurantID(for: restaurantName) else {
            print("❌ No nutrition data available for \(restaurantName)")
            errorMessage = "No nutrition data available for \(restaurantName)"
            return
        }
        
        print("🆔 Found restaurant ID: \(restaurantID) for \(restaurantName)")
        isLoading = true
        errorMessage = nil
        
        let task = Task {
            return await loadNutritionDataInBackground(for: restaurantName, restaurantID: restaurantID)
        }
        
        loadingTasks[cacheKey] = task
        
        Task {
            if let result = await task.value {
                await MainActor.run {
                    self.isLoading = false
                    self.currentRestaurantData = result
                    self.updateMemoryCache(cacheKey, result)
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to load nutrition data for \(restaurantName)"
                }
            }
            loadingTasks.removeValue(forKey: cacheKey)
        }
    }
    
    private func loadNutritionDataInBackground(for restaurantName: String, restaurantID: String) async -> RestaurantNutritionData? {
        print("Background loading nutrition data for \(restaurantName) with ID \(restaurantID)")
        
        if let cachedParsedData = csvParsingCache[restaurantID] {
            return await processPreParsedCSV(cachedParsedData, restaurantName: restaurantName, restaurantID: restaurantID)
        }
        
        guard let fileContent = await loadCSVFile(restaurantID: restaurantID) else {
            print("Failed to load nutrition data file for \(restaurantName) (ID: \(restaurantID))")
            return nil
        }
        
        let nutritionItems = await withCheckedContinuation { continuation in
            backgroundQueue.async {
                let parsedLines = fileContent.components(separatedBy: .newlines)
                self.csvParsingCache[restaurantID] = parsedLines
                
                let items = self.parseNutritionCSV(lines: parsedLines, restaurantName: restaurantName)
                continuation.resume(returning: items)
            }
        }
        
        guard !nutritionItems.isEmpty else {
            print("No valid nutrition items found for \(restaurantName)")
            return nil
        }
        
        let restaurantData = RestaurantNutritionData(
            restaurantName: restaurantName,
            items: nutritionItems
        )
        
        cache.cacheNutritionData(restaurantData, for: restaurantName)
        print("Loaded and cached \(nutritionItems.count) nutrition items for \(restaurantName)")
        
        return restaurantData
    }
    
    private func processPreParsedCSV(_ lines: [String], restaurantName: String, restaurantID: String) async -> RestaurantNutritionData? {
        let nutritionItems = await withCheckedContinuation { continuation in
            backgroundQueue.async {
                let items = self.parseNutritionCSV(lines: lines, restaurantName: restaurantName)
                continuation.resume(returning: items)
            }
        }
        
        guard !nutritionItems.isEmpty else { return nil }
        
        return RestaurantNutritionData(
            restaurantName: restaurantName,
            items: nutritionItems
        )
    }
    
    private func loadCSVFile(restaurantID: String) async -> String? {
        let possiblePaths = [
            Bundle.main.path(forResource: restaurantID, ofType: "csv", inDirectory: "Services/restaurant_data"),
            Bundle.main.path(forResource: restaurantID, ofType: "csv"),
            Bundle.main.path(forResource: restaurantID, ofType: "csv", inDirectory: "restaurant_data")
        ]
        
        for path in possiblePaths {
            if let validPath = path {
                do {
                    let fileContent = try String(contentsOfFile: validPath)
                    print("Successfully loaded nutrition data from: \(validPath)")
                    return fileContent
                } catch {
                    print("Failed to load from \(validPath): \(error.localizedDescription)")
                }
            }
        }
        
        return nil
    }
    
    private func parseNutritionCSV(lines: [String], restaurantName: String) -> [NutritionData] {
        var nutritionItems: [NutritionData] = []
        nutritionItems.reserveCapacity(lines.count)
        
        for (index, line) in lines.enumerated() {
            if index == 0 { continue }
            
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            let components = parseCSVLine(trimmedLine)
            guard components.count >= 10 else {
                continue
            }
            
            let item = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.isEmpty else { continue }
            
            let nutritionData = NutritionData(
                item: item,
                calories: parseDoubleOptimized(components[1]),
                fat: parseDoubleOptimized(components[2]),
                saturatedFat: parseDoubleOptimized(components[3]),
                cholesterol: parseDoubleOptimized(components[4]),
                sodium: parseDoubleOptimized(components[5]),
                carbs: parseDoubleOptimized(components[6]),
                fiber: parseDoubleOptimized(components[7]),
                sugar: parseDoubleOptimized(components[8]),
                protein: parseDoubleOptimized(components[9])
            )
            
            nutritionItems.append(nutritionData)
        }
        
        print("Parsed \(nutritionItems.count) items from CSV for \(restaurantName)")
        return nutritionItems
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        if !line.contains("\"") {
            return line.components(separatedBy: ",").map { 
                $0.trimmingCharacters(in: .whitespacesAndNewlines) 
            }
        }
        
        var components: [String] = []
        components.reserveCapacity(10)
        var currentComponent = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                components.append(currentComponent.trimmingCharacters(in: .whitespacesAndNewlines))
                currentComponent = ""
            } else {
                currentComponent.append(char)
            }
        }
        
        components.append(currentComponent.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return components
    }
    
    private func parseDoubleOptimized(_ string: String) -> Double {
        let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
        return Double(cleaned) ?? 0.0
    }
    
    private func updateMemoryCache(_ key: String, _ data: RestaurantNutritionData) {
        if memoryCache.count >= maxMemoryCacheSize {
            clearExpiredCache()
        }
        
        if memoryCache.count >= maxMemoryCacheSize {
            let oldestKey = memoryCache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let key = oldestKey {
                memoryCache.removeValue(forKey: key)
            }
        }
        
        memoryCache[key] = CachedNutritionItem(data: data, timestamp: Date())
    }
    
    private func clearExpiredCache() {
        let now = Date()
        memoryCache = memoryCache.filter { !$0.value.isExpired(at: now) }
        
        if csvParsingCache.count > 30 {
            csvParsingCache.removeAll()
        }
    }
    
    func preloadNutritionData(for restaurantName: String) {
        let cacheKey = restaurantName.lowercased()
        
        guard memoryCache[cacheKey] == nil,
              cache.getCachedNutritionData(for: restaurantName) == nil,
              loadingTasks[cacheKey] == nil else {
            return
        }
        
        guard let restaurantID = cache.getRestaurantID(for: restaurantName) else {
            return
        }
        
        let task = Task {
            return await loadNutritionDataInBackground(for: restaurantName, restaurantID: restaurantID)
        }
        
        loadingTasks[cacheKey] = task
        
        Task {
            if let result = await task.value {
                await MainActor.run {
                    self.updateMemoryCache(cacheKey, result)
                }
            }
            loadingTasks.removeValue(forKey: cacheKey)
        }
    }
    
    func getCacheInfo() -> (memoryCount: Int, persistentCount: Int) {
        let stats = cache.getCacheStats()
        return (memoryCache.count, stats.nutritionCacheSize)
    }
    
    func clearData() {
        currentRestaurantData = nil
        errorMessage = nil
    }
    
    func clearMemoryCache() {
        memoryCache.removeAll()
        csvParsingCache.removeAll()
        print("Cleared nutrition memory cache")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

private struct CachedNutritionItem {
    let data: RestaurantNutritionData
    let timestamp: Date
    
    var isExpired: Bool {
        isExpired(at: Date())
    }
    
    func isExpired(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(timestamp) > 600
    }
}
