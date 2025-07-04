import Foundation

// MARK: - Open Food Facts API Response Models

struct OpenFoodFactsSearchResponse: Codable {
    let products: [OpenFoodFactsProduct]
    let count: Int
    let page: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case products
        case count
        case page
        case pageSize = "page_size"
    }
}

struct OpenFoodFactsProduct: Codable {
    let id: String?
    let code: String? // Barcode
    let productName: String?
    let nutriments: OpenFoodFactsNutriments?
    
    enum CodingKeys: String, CodingKey {
        case id
        case code
        case productName = "product_name"
        case nutriments
    }
}

struct OpenFoodFactsNutriments: Codable {
    let energyKcal100g: Double?
    let carbohydrates100g: Double?
    let sugars100g: Double?
    let proteins100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sodium100g: Double?
    
    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case sugars100g = "sugars_100g"
        case proteins100g = "proteins_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sodium100g = "sodium_100g"
    }
}

// MARK: - Result Models

struct OpenFoodFactsResult: Codable {
    let originalName: String
    let cleanedQuery: String
    let matchedProductName: String
    let productId: String?
    let barcode: String?
    let nutrition: OpenFoodFactsNutrition
    let matchScore: Double
    let confidence: Double
    let isAvailable: Bool
    let isGeneralEstimate: Bool
    let source: String
    let timestamp: Date
    
    init(originalName: String, cleanedQuery: String, matchedProductName: String, productId: String?, barcode: String?, nutrition: OpenFoodFactsNutrition, matchScore: Double, confidence: Double, isAvailable: Bool, isGeneralEstimate: Bool, source: String) {
        self.originalName = originalName
        self.cleanedQuery = cleanedQuery
        self.matchedProductName = matchedProductName
        self.productId = productId
        self.barcode = barcode
        self.nutrition = nutrition
        self.matchScore = matchScore
        self.confidence = confidence
        self.isAvailable = isAvailable
        self.isGeneralEstimate = isGeneralEstimate
        self.source = source
        self.timestamp = Date()
    }
    
    static func unavailable(originalName: String) -> OpenFoodFactsResult {
        return OpenFoodFactsResult(
            originalName: originalName,
            cleanedQuery: "",
            matchedProductName: "",
            productId: nil,
            barcode: nil,
            nutrition: OpenFoodFactsNutrition.empty,
            matchScore: 0.0,
            confidence: 0.0,
            isAvailable: false,
            isGeneralEstimate: false,
            source: "Open Food Facts"
        )
    }
}

struct OpenFoodFactsNutrition: Codable {
    let calories: Double
    let carbs: Double
    let sugar: Double?
    let protein: Double
    let fat: Double
    let fiber: Double?
    let sodium: Double? // in mg
    let completenessScore: Double
    let per100g: Bool // Always true for OFF data
    
    static let empty = OpenFoodFactsNutrition(
        calories: 0,
        carbs: 0,
        sugar: nil,
        protein: 0,
        fat: 0,
        fiber: nil,
        sodium: nil,
        completenessScore: 0.0,
        per100g: true
    )
    
    // Convert to typical serving size (rough estimate)
    func toServingSize(estimatedServingGrams: Double = 100) -> OpenFoodFactsNutrition {
        let multiplier = estimatedServingGrams / 100.0
        
        return OpenFoodFactsNutrition(
            calories: calories * multiplier,
            carbs: carbs * multiplier,
            sugar: sugar != nil ? sugar! * multiplier : nil,
            protein: protein * multiplier,
            fat: fat * multiplier,
            fiber: fiber != nil ? fiber! * multiplier : nil,
            sodium: sodium != nil ? sodium! * multiplier : nil,
            completenessScore: completenessScore,
            per100g: false
        )
    }
}

// MARK: - Caching

actor OpenFoodFactsCache {
    private let cacheDirectory: URL
    private let cacheExpiry: TimeInterval = 24 * 60 * 60 * 7 // 7 days
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("OpenFoodFactsCache")
        
        // Create cache directory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getCachedResult(for key: String) -> OpenFoodFactsResult? {
        let fileName = sanitizeFileName(key) + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let result = try? JSONDecoder().decode(OpenFoodFactsResult.self, from: data) else { return nil }
        
        // Check expiry
        if Date().timeIntervalSince(result.timestamp) > cacheExpiry {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        
        return result
    }
    
    func cacheResult(_ result: OpenFoodFactsResult, for key: String) {
        let fileName = sanitizeFileName(key) + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? JSONEncoder().encode(result) else { return }
        try? data.write(to: fileURL)
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
    
    private func sanitizeFileName(_ key: String) -> String {
        return key.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
    }
}

// MARK: - Example Usage and Testing

extension OpenFoodFactsService {
    
    /// Test the service with sample inputs
    func testSampleInputs() async {
        let testInputs = [
            "chips",
            "turkey sandwich", 
            "cheddar cheese",
            "grilled shrimp",
            "tiramisu",
            "caesar salad"
        ]
        
        debugLog(" Testing Open Food Facts service with sample inputs...")
        
        for input in testInputs {
            do {
                let result = try await findNutritionMatch(for: input)
                
                if result.isAvailable {
                    debugLog("""
                    SUCCESS: '\(input)'
                       → Matched: '\(result.matchedProductName)'
                       → Confidence: \(Int(result.confidence * 100))%
                       → Calories: \(Int(result.nutrition.calories)) kcal/100g
                       → Protein: \(Int(result.nutrition.protein))g/100g
                       → Score: \(String(format: "%.2f", result.matchScore))
                    """)
                } else {
                    debugLog("FAILED: '\(input)' - No match found")
                }
            } catch {
                debugLog("ERROR: '\(input)' - \(error)")
            }
            
            // Add delay between tests to respect rate limiting
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
}