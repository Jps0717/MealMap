import Foundation
import UIKit

class NutritionDataManager: ObservableObject {
    @Published var isLoading = false
    @Published var currentRestaurantData: RestaurantNutritionData?
    @Published var errorMessage: String?
    
    private let enhancedCache = EnhancedCacheManager.shared
    private let legacyCache = CacheManager.shared // Keep for backward compatibility
    
    private var loadingTasks: [String: Task<RestaurantNutritionData?, Never>] = [:]
    
    // Enhanced background processing
    private let backgroundQueue = DispatchQueue(label: "nutrition.parsing", qos: .utility)
    private let preloadQueue = DispatchQueue(label: "nutrition.preload", qos: .background)
    
    // Enhanced CSV parsing cache with compression
    private var csvParsingCache: [String: [String]] = [:]
    private let maxCSVCacheSize = 100 // Increased from 30
    
    init() {
        print("NutritionDataManager initialized with enhanced caching system")
        setupMemoryManagement()
        
        // Start background prefetching of popular restaurants
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.enhancedCache.prefetchPopularRestaurantsNutrition()
        }
    }
    
    private func setupMemoryManagement() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    func loadNutritionData(for restaurantName: String) {
        let cacheKey = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        print("🍽️ Loading nutrition data for restaurant: '\(restaurantName)'")
        
        // Try enhanced cache first (fastest path)
        if let cachedData = enhancedCache.getCachedNutritionData(for: restaurantName) {
            print("🚀 Enhanced cache hit for \(restaurantName)")
            self.isLoading = false
            self.currentRestaurantData = cachedData
            self.errorMessage = nil
            return
        }
        
        // Fall back to legacy cache
        if let legacyCachedData = legacyCache.getCachedNutritionData(for: restaurantName) {
            print("💿 Legacy cache hit for \(restaurantName)")
            self.isLoading = false
            self.currentRestaurantData = legacyCachedData
            self.errorMessage = nil
            
            // Migrate to enhanced cache
            enhancedCache.cacheNutritionData(legacyCachedData, for: restaurantName)
            return
        }
        
        // Check if already loading
        if let existingTask = loadingTasks[cacheKey] {
            print("⏳ Already loading \(restaurantName), waiting for completion...")
            isLoading = true
            errorMessage = nil
            
            Task {
                if let result = await existingTask.value {
                    await MainActor.run {
                        self.isLoading = false
                        self.currentRestaurantData = result
                    }
                }
                loadingTasks.removeValue(forKey: cacheKey)
            }
            return
        }
        
        // Get restaurant ID for CSV lookup
        guard let restaurantID = legacyCache.getRestaurantID(for: restaurantName) else {
            print("❌ No nutrition data available for \(restaurantName)")
            errorMessage = "No nutrition data available for \(restaurantName)"
            return
        }
        
        print("🆔 Found restaurant ID: \(restaurantID) for \(restaurantName)")
        isLoading = true
        errorMessage = nil
        
        // Start enhanced loading task
        let task = Task {
            return await loadNutritionDataWithEnhancedCaching(for: restaurantName, restaurantID: restaurantID)
        }
        
        loadingTasks[cacheKey] = task
        
        Task {
            if let result = await task.value {
                await MainActor.run {
                    self.isLoading = false
                    self.currentRestaurantData = result
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
    
    private func loadNutritionDataWithEnhancedCaching(for restaurantName: String, restaurantID: String) async -> RestaurantNutritionData? {
        print("🔄 Enhanced loading nutrition data for \(restaurantName) with ID \(restaurantID)")
        
        // Check if CSV is already parsed and cached
        if let cachedParsedData = csvParsingCache[restaurantID] {
            print("📋 Using cached parsed CSV for \(restaurantName)")
            return await processPreParsedCSV(cachedParsedData, restaurantName: restaurantName, restaurantID: restaurantID)
        }
        
        // Load and parse CSV file
        guard let fileContent = await loadCSVFile(restaurantID: restaurantID) else {
            print("❌ Failed to load nutrition data file for \(restaurantName) (ID: \(restaurantID))")
            return nil
        }
        
        // Parse CSV in background with enhanced caching
        let nutritionItems = await withCheckedContinuation { continuation in
            backgroundQueue.async {
                let parsedLines = fileContent.components(separatedBy: .newlines)
                
                // Cache parsed lines with size management
                self.manageCsvCacheSize()
                self.csvParsingCache[restaurantID] = parsedLines
                
                let items = self.parseNutritionCSVOptimized(lines: parsedLines, restaurantName: restaurantName)
                continuation.resume(returning: items)
            }
        }
        
        guard !nutritionItems.isEmpty else {
            print("❌ No valid nutrition items found for \(restaurantName)")
            return nil
        }
        
        let restaurantData = RestaurantNutritionData(
            restaurantName: restaurantName,
            items: nutritionItems
        )
        
        // Cache with both systems
        enhancedCache.cacheNutritionData(restaurantData, for: restaurantName)
        legacyCache.cacheNutritionData(restaurantData, for: restaurantName)
        
        print("✅ Enhanced cached \(nutritionItems.count) nutrition items for \(restaurantName)")
        
        return restaurantData
    }
    
    private func processPreParsedCSV(_ lines: [String], restaurantName: String, restaurantID: String) async -> RestaurantNutritionData? {
        let nutritionItems = await withCheckedContinuation { continuation in
            backgroundQueue.async {
                let items = self.parseNutritionCSVOptimized(lines: lines, restaurantName: restaurantName)
                continuation.resume(returning: items)
            }
        }
        
        guard !nutritionItems.isEmpty else { return nil }
        
        let restaurantData = RestaurantNutritionData(
            restaurantName: restaurantName,
            items: nutritionItems
        )
        
        // Cache the result
        enhancedCache.cacheNutritionData(restaurantData, for: restaurantName)
        
        return restaurantData
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
                    print("✅ Successfully loaded nutrition data from: \(validPath)")
                    return fileContent
                } catch {
                    print("⚠️ Failed to load from \(validPath): \(error.localizedDescription)")
                }
            }
        }
        
        return nil
    }
    
    // Enhanced CSV parsing with better performance
    private func parseNutritionCSVOptimized(lines: [String], restaurantName: String) -> [NutritionData] {
        var nutritionItems: [NutritionData] = []
        nutritionItems.reserveCapacity(lines.count)
        
        // Use indices for better performance
        for index in 1..<lines.count { // Skip header
            let line = lines[index]
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            let components = parseCSVLineOptimized(trimmedLine)
            guard components.count >= 10 else { continue }
            
            let item = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.isEmpty && item.count > 2 else { continue }
            
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
        
        print("🔧 Optimized parsing: \(nutritionItems.count) items from CSV for \(restaurantName)")
        return nutritionItems
    }
    
    // Optimized CSV line parsing
    private func parseCSVLineOptimized(_ line: String) -> [String] {
        // Fast path for simple lines without quotes
        if !line.contains("\"") {
            return line.split(separator: ",", maxSplits: 10, omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        
        // Full parsing for complex lines
        var components: [String] = []
        components.reserveCapacity(12)
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
        // Fast path for common cases
        if string.isEmpty || string == "0" { return 0.0 }
        if string == "1" { return 1.0 }
        
        let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
        return Double(cleaned) ?? 0.0
    }
    
    // Enhanced preloading with batch processing
    func preloadNutritionData(for restaurantName: String) {
        let cacheKey = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip if already cached or loading
        guard enhancedCache.getCachedNutritionData(for: restaurantName) == nil,
              legacyCache.getCachedNutritionData(for: restaurantName) == nil,
              loadingTasks[cacheKey] == nil else {
            return
        }
        
        guard let restaurantID = legacyCache.getRestaurantID(for: restaurantName) else {
            return
        }
        
        // Use preload queue for background processing
        preloadQueue.async { [weak self] in
            let task = Task {
                return await self?.loadNutritionDataWithEnhancedCaching(for: restaurantName, restaurantID: restaurantID)
            }
            
            Task { [weak self] in
                _ = await task.value
                await MainActor.run {
                    self?.loadingTasks.removeValue(forKey: cacheKey)
                }
            }
        }
    }
    
    // Batch preloading for multiple restaurants
    func batchPreloadNutritionData(for restaurantNames: [String]) {
        preloadQueue.async { [weak self] in
            for (index, restaurantName) in restaurantNames.enumerated() {
                // Add delays between batch requests
                if index > 0 {
                    Thread.sleep(forTimeInterval: 0.2)
                }
                
                self?.preloadNutritionData(for: restaurantName)
            }
        }
    }
    
    // MARK: - Cache Management
    private func manageCsvCacheSize() {
        if csvParsingCache.count > maxCSVCacheSize {
            // Remove oldest entries (simple FIFO for now)
            let keysToRemove = Array(csvParsingCache.keys.prefix(csvParsingCache.count - maxCSVCacheSize + 10))
            for key in keysToRemove {
                csvParsingCache.removeValue(forKey: key)
            }
        }
    }
    
    private func handleMemoryWarning() {
        backgroundQueue.async { [weak self] in
            // Clear most of the CSV cache
            self?.csvParsingCache.removeAll()
            
            // Cancel non-essential loading tasks - fix the array conversion
            if let loadingTasks = self?.loadingTasks {
                let tasksToCancel = Array(loadingTasks.values.prefix(3))
                for task in tasksToCancel {
                    task.cancel()
                }
            }
            
            print("🚨 NutritionDataManager: Handled memory warning")
        }
    }
    
    // MARK: - Statistics and Debugging
    func getCacheInfo() -> (memoryCount: Int, persistentCount: Int, csvCacheCount: Int) {
        let enhancedStats = enhancedCache.getEnhancedCacheStats()
        return (enhancedStats.memoryNutritionItems, 0, csvParsingCache.count) // Simplified for now
    }
    
    func clearData() {
        currentRestaurantData = nil
        errorMessage = nil
    }
    
    func clearMemoryCache() {
        csvParsingCache.removeAll()
        print("🧹 Cleared nutrition memory cache")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
        // Cancel all loading tasks
        for (_, task) in loadingTasks {
            task.cancel()
        }
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
