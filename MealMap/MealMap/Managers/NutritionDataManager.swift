import Foundation

class NutritionDataManager: ObservableObject {
    @Published var isLoading = false
    @Published var currentRestaurantData: RestaurantNutritionData?
    @Published var errorMessage: String?
    
    private let cache = CacheManager.shared
    
    // In-memory cache for immediate access
    private var memoryCache: [String: RestaurantNutritionData] = [:]
    private var loadingTasks: [String: Task<RestaurantNutritionData?, Never>] = [:]
    
    init() {
        print("NutritionDataManager initialized with caching system")
    }
    
    func loadNutritionData(for restaurantName: String) {
        // Check memory cache first (fastest)
        if let memoryData = memoryCache[restaurantName] {
            print("Using memory cached nutrition data for \(restaurantName)")
            self.isLoading = false
            self.currentRestaurantData = memoryData
            self.errorMessage = nil
            return
        }
        
        // Check persistent cache
        if let cachedData = cache.getCachedNutritionData(for: restaurantName) {
            print("Using persistent cached nutrition data for \(restaurantName)")
            self.isLoading = false
            self.currentRestaurantData = cachedData
            self.errorMessage = nil
            // Also store in memory cache for even faster future access
            memoryCache[restaurantName] = cachedData
            return
        }
        
        // Check if already loading to prevent duplicate requests
        if let existingTask = loadingTasks[restaurantName] {
            print("Already loading \(restaurantName), waiting for completion...")
            isLoading = true
            errorMessage = nil
            
            Task {
                if let result = await existingTask.value {
                    await MainActor.run {
                        self.isLoading = false
                        self.currentRestaurantData = result
                        self.memoryCache[restaurantName] = result
                    }
                }
                loadingTasks.removeValue(forKey: restaurantName)
            }
            return
        }
        
        // Get restaurant ID from cache manager
        guard let restaurantID = cache.getRestaurantID(for: restaurantName) else {
            print("No nutrition data available for \(restaurantName)")
            errorMessage = "No nutrition data available for \(restaurantName)"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Create loading task to prevent duplicates
        let task = Task {
            return await loadNutritionDataInBackground(for: restaurantName, restaurantID: restaurantID)
        }
        
        loadingTasks[restaurantName] = task
        
        Task {
            if let result = await task.value {
                await MainActor.run {
                    self.isLoading = false
                    self.currentRestaurantData = result
                    self.memoryCache[restaurantName] = result
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to load nutrition data for \(restaurantName)"
                }
            }
            loadingTasks.removeValue(forKey: restaurantName)
        }
    }
    
    // Background loading with automatic caching
    private func loadNutritionDataInBackground(for restaurantName: String, restaurantID: String) async -> RestaurantNutritionData? {
        print("Background loading nutrition data for \(restaurantName) with ID \(restaurantID)")
        
        // Try different bundle paths for CSV files
        var content: String?
        let possiblePaths = [
            Bundle.main.path(forResource: restaurantID, ofType: "csv", inDirectory: "Services/restaurant_data"),
            Bundle.main.path(forResource: restaurantID, ofType: "csv"),
            Bundle.main.path(forResource: restaurantID, ofType: "csv", inDirectory: "restaurant_data")
        ]
        
        for path in possiblePaths {
            if let validPath = path {
                do {
                    let fileContent = try String(contentsOfFile: validPath)
                    content = fileContent
                    print("Successfully loaded nutrition data from: \(validPath)")
                    break
                } catch {
                    print("Failed to load from \(validPath): \(error.localizedDescription)")
                }
            }
        }
        
        guard let fileContent = content else {
            print("Failed to load nutrition data file for \(restaurantName) (ID: \(restaurantID))")
            return nil
        }
        
        // Parse CSV content
        let nutritionItems = parseNutritionCSV(content: fileContent, restaurantName: restaurantName)
        
        guard !nutritionItems.isEmpty else {
            print("No valid nutrition items found for \(restaurantName)")
            return nil
        }
        
        let restaurantData = RestaurantNutritionData(
            restaurantName: restaurantName,
            items: nutritionItems
        )
        
        // Cache the data immediately
        cache.cacheNutritionData(restaurantData, for: restaurantName)
        print("Loaded and cached \(nutritionItems.count) nutrition items for \(restaurantName)")
        
        return restaurantData
    }
    
    private func parseNutritionCSV(content: String, restaurantName: String) -> [NutritionData] {
        let lines = content.components(separatedBy: .newlines)
        var nutritionItems: [NutritionData] = []
        
        // Skip header line and process data
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip header
            
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            // Handle CSV parsing with potential commas in quoted fields
            let components = parseCSVLine(line)
            guard components.count >= 10 else {
                print("Skipping line \(index) for \(restaurantName): insufficient columns (\(components.count))")
                continue
            }
            
            let item = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.isEmpty else { continue }
            
            // Parse numeric values with error handling
            let calories = parseDouble(components[1]) ?? 0.0
            let fat = parseDouble(components[2]) ?? 0.0
            let saturatedFat = parseDouble(components[3]) ?? 0.0
            let cholesterol = parseDouble(components[4]) ?? 0.0
            let sodium = parseDouble(components[5]) ?? 0.0
            let carbs = parseDouble(components[6]) ?? 0.0
            let fiber = parseDouble(components[7]) ?? 0.0
            let sugar = parseDouble(components[8]) ?? 0.0
            let protein = parseDouble(components[9]) ?? 0.0
            
            let nutritionData = NutritionData(
                item: item,
                calories: calories,
                fat: fat,
                saturatedFat: saturatedFat,
                cholesterol: cholesterol,
                sodium: sodium,
                carbs: carbs,
                fiber: fiber,
                sugar: sugar,
                protein: protein
            )
            
            nutritionItems.append(nutritionData)
        }
        
        print("Parsed \(nutritionItems.count) items from CSV for \(restaurantName)")
        return nutritionItems
    }
    
    // Helper function to parse CSV lines that might contain quoted fields
    private func parseCSVLine(_ line: String) -> [String] {
        var components: [String] = []
        var currentComponent = ""
        var insideQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                components.append(currentComponent.trimmingCharacters(in: .whitespacesAndNewlines))
                currentComponent = ""
            } else {
                currentComponent.append(char)
            }
            
            i = line.index(after: i)
        }
        
        // Add the last component
        components.append(currentComponent.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return components
    }
    
    // Helper function to safely parse double values
    private func parseDouble(_ string: String) -> Double? {
        let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
        return Double(cleaned)
    }
    
    // Preload nutrition data for a restaurant without updating UI
    func preloadNutritionData(for restaurantName: String) {
        guard memoryCache[restaurantName] == nil,
              cache.getCachedNutritionData(for: restaurantName) == nil,
              loadingTasks[restaurantName] == nil else {
            return // Already cached or loading
        }
        
        guard let restaurantID = cache.getRestaurantID(for: restaurantName) else {
            return
        }
        
        let task = Task {
            return await loadNutritionDataInBackground(for: restaurantName, restaurantID: restaurantID)
        }
        
        loadingTasks[restaurantName] = task
        
        Task {
            if let result = await task.value {
                await MainActor.run {
                    self.memoryCache[restaurantName] = result
                }
            }
            loadingTasks.removeValue(forKey: restaurantName)
        }
    }
    
    // Get cache statistics
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
        print("Cleared nutrition memory cache")
    }
}
