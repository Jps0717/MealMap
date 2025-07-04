import Foundation

// MARK: - MealMap Nutrition Engine
@MainActor
class MealMapNutritionEngine: ObservableObject {
    static let shared = MealMapNutritionEngine()
    
    private let apiService = MealMapAPIService.shared
    private let cache = MealMapNutritionEngineCache()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Main entry point: Process raw menu item and return MealMap-based nutrition
    func analyzeMenuItem(_ rawName: String) async throws -> MealMapMenuItemResult {
        debugLog("🔍 Analyzing menu item with MealMap: '\(rawName)'")
        
        // Step 1: Check cache first
        let cacheKey = rawName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = await cache.getCachedResult(for: cacheKey) {
            debugLog("💾 Cache hit for: '\(rawName)'")
            return cached
        }
        
        // Step 2: Use MealMap API to find nutrition match
        do {
            let nutritionResult = try await apiService.findNutritionMatch(for: rawName)
            
            if nutritionResult.isAvailable {
                // Create available result
                let result = MealMapMenuItemResult(
                    originalName: rawName,
                    cleanedName: nutritionResult.cleanedName,
                    matchedEntry: nutritionResult.matchedEntry,
                    extractedID: nutritionResult.extractedID,
                    matchScore: nutritionResult.matchScore,
                    confidence: nutritionResult.confidence,
                    isGeneralEstimate: true,
                    isAvailable: true,
                    nutritionData: nil // Will be populated when we get the follow-up API
                )
                
                // Cache the result
                await cache.cacheResult(result, for: cacheKey)
                
                debugLog("✅ MealMap match found for '\(rawName)': '\(nutritionResult.matchedEntry)' (ID: \(nutritionResult.extractedID))")
                return result
            } else {
                // Create unavailable result
                let result = MealMapMenuItemResult.unavailable(originalName: rawName)
                await cache.cacheResult(result, for: cacheKey)
                return result
            }
        } catch {
            debugLog("❌ MealMap analysis failed for '\(rawName)': \(error)")
            
            // Create unavailable result on error
            let result = MealMapMenuItemResult.unavailable(originalName: rawName)
            await cache.cacheResult(result, for: cacheKey)
            return result
        }
    }
    
    /// Enhanced menu item analysis that integrates with AnalyzedMenuItem format
    func analyzeMenuItemForOCR(_ rawName: String) async throws -> AnalyzedMenuItem {
        debugLog("🔍 Analyzing menu item for OCR integration: '\(rawName)'")
        
        let mealMapResult = try await analyzeMenuItem(rawName)
        
        if mealMapResult.isAvailable {
            return AnalyzedMenuItem.createWithMealMapAPI(
                name: rawName,
                description: nil,
                price: nil,
                mealMapResult: mealMapResult,
                textBounds: nil
            )
        } else {
            return AnalyzedMenuItem.createUnavailable(
                name: rawName,
                description: nil,
                price: nil,
                textBounds: nil
            )
        }
    }
    
    // MARK: - Statistics and Debugging
    
    func getEngineStatistics() async throws -> MealMapEngineStatistics {
        let apiStats = try await apiService.getFoodListStatistics()
        let cacheStats = await cache.getCacheStatistics()
        
        return MealMapEngineStatistics(
            apiStatistics: apiStats,
            cacheStatistics: cacheStats
        )
    }
    
    /// Test the engine with sample food names
    func runEngineTests() async throws {
        debugLog("🧪 Running MealMap Nutrition Engine tests...")
        
        let testCases = [
            "grilled chicken",
            "hummus with tahini",
            "cheddar cheese", 
            "grilled shrimp",
            "salmon fish",
            "invalid food name",
            "chocolate chip cookie"
        ]
        
        for testCase in testCases {
            do {
                let result = try await analyzeMenuItem(testCase)
                if result.isAvailable {
                    debugLog("✅ Test '\(testCase)' → Match: '\(result.matchedEntry)' (ID: \(result.extractedID), confidence: \(String(format: "%.2f", result.confidence)))")
                } else {
                    debugLog("❌ Test '\(testCase)' → No match found")
                }
            } catch {
                debugLog("💥 Test '\(testCase)' → Error: \(error)")
            }
        }
    }
}

// MARK: - Data Models

struct MealMapMenuItemResult: Codable {
    let originalName: String
    let cleanedName: String
    let matchedEntry: String
    let extractedID: String
    let matchScore: Double
    let confidence: Double
    let isGeneralEstimate: Bool
    let isAvailable: Bool
    let nutritionData: MealMapNutritionData? // For future use when we get nutrition endpoint
    let timestamp: Date = Date()
    
    static func unavailable(originalName: String) -> MealMapMenuItemResult {
        return MealMapMenuItemResult(
            originalName: originalName,
            cleanedName: "",
            matchedEntry: "",
            extractedID: "",
            matchScore: 0.0,
            confidence: 0.0,
            isGeneralEstimate: false,
            isAvailable: false,
            nutritionData: nil
        )
    }
}

// Placeholder for future nutrition data structure
struct MealMapNutritionData: Codable {
    let calories: Double?
    let carbs: Double?
    let protein: Double?
    let fat: Double?
    let fiber: Double?
    let sodium: Double?
    let sugar: Double?
    
    static let empty = MealMapNutritionData(
        calories: nil,
        carbs: nil,
        protein: nil,
        fat: nil,
        fiber: nil,
        sodium: nil,
        sugar: nil
    )
}

struct MealMapEngineStatistics {
    let apiStatistics: MealMapAPIStatistics
    let cacheStatistics: MealMapCacheStatistics
}

struct MealMapCacheStatistics {
    let totalCachedItems: Int
    let cacheHitRate: Double
    let oldestCacheEntry: Date?
    let newestCacheEntry: Date?
}

// MARK: - Engine Cache

actor MealMapNutritionEngineCache {
    private let cacheDirectory: URL
    private let cacheExpiry: TimeInterval = 24 * 60 * 60 // 24 hours
    private var hitCount = 0
    private var missCount = 0
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("MealMapEngineCache")
        
        // Create cache directory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getCachedResult(for key: String) -> MealMapMenuItemResult? {
        let fileName = sanitizeFileName(key) + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: fileURL),
              let result = try? JSONDecoder().decode(MealMapMenuItemResult.self, from: data) else {
            missCount += 1
            return nil
        }
        
        // Check expiry
        if Date().timeIntervalSince(result.timestamp) > cacheExpiry {
            try? FileManager.default.removeItem(at: fileURL)
            missCount += 1
            return nil
        }
        
        hitCount += 1
        return result
    }
    
    func cacheResult(_ result: MealMapMenuItemResult, for key: String) {
        let fileName = sanitizeFileName(key) + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? JSONEncoder().encode(result) else { return }
        try? data.write(to: fileURL)
    }
    
    func getCacheStatistics() -> MealMapCacheStatistics {
        let totalRequests = hitCount + missCount
        let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
        
        // Get cache file timestamps
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        
        let timestamps = files.compactMap { fileURL in
            try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        }
        
        return MealMapCacheStatistics(
            totalCachedItems: files.count,
            cacheHitRate: hitRate,
            oldestCacheEntry: timestamps.min(),
            newestCacheEntry: timestamps.max()
        )
    }
    
    func clearExpiredCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        
        let expiredFiles = files.filter { fileURL in
            guard let attributes = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modificationDate = attributes.contentModificationDate else { return false }
            
            return Date().timeIntervalSince(modificationDate) > cacheExpiry
        }
        
        for file in expiredFiles {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    private func sanitizeFileName(_ fileName: String) -> String {
        return fileName.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
    }
}

// MARK: - AnalyzedMenuItem Extension

extension AnalyzedMenuItem {
    /// Create AnalyzedMenuItem with MealMap API data
    static func createWithMealMapAPI(
        name: String,
        description: String?,
        price: String?,
        mealMapResult: MealMapMenuItemResult,
        textBounds: CGRect?
    ) -> AnalyzedMenuItem {
        // Create a basic nutrition estimate structure
        // For now, we'll create a placeholder since we don't have actual nutrition values yet
        let nutritionEstimate = NutritionEstimate(
            calories: NutritionRange(min: 0, max: 0, unit: "kcal"), // Placeholder
            carbs: NutritionRange(min: 0, max: 0, unit: "g"),
            protein: NutritionRange(min: 0, max: 0, unit: "g"),
            fat: NutritionRange(min: 0, max: 0, unit: "g"),
            fiber: nil,
            sodium: nil,
            sugar: nil,
            confidence: mealMapResult.confidence,
            estimationSource: .mealMapAPI,
            sourceDetails: "MealMap database match: '\(mealMapResult.matchedEntry)' (ID: \(mealMapResult.extractedID))",
            estimatedPortionSize: "1 serving",
            portionConfidence: 0.6
        )
        
        // Generate basic dietary tags (placeholder logic)
        let dietaryTags: [DietaryTag] = [] // Will be populated once we have nutrition data
        
        return AnalyzedMenuItem(
            name: name,
            description: description,
            price: price,
            ingredients: [], // No ingredient analysis with MealMap approach
            nutritionEstimate: nutritionEstimate,
            dietaryTags: dietaryTags,
            confidence: mealMapResult.confidence,
            textBounds: textBounds,
            estimationTier: .mealMapAPI,
            usdaEstimate: nil, // Not applicable for MealMap
            isGeneralizedEstimate: true
        )
    }
}