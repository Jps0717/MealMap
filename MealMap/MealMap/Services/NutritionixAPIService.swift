import Foundation

// MARK: - Nutritionix API Data Models

struct NutritionixRequest: Codable {
    let query: String
    let timezone: String = "US/Eastern"
    let num_servings: Int = 1
    let aggregate: String = "1 serving"
    let line_delimited: Bool = false
    let use_raw_foods: Bool = false
    let include_subrecipe: Bool = false
    let use_branded_foods: Bool = true
    let locale: String = "en_US"
}

struct NutritionixResponse: Codable {
    let foods: [NutritionixFood]
}

struct NutritionixFood: Codable {
    let food_name: String
    let brand_name: String?
    let serving_qty: Double
    let serving_unit: String
    let serving_weight_grams: Double?
    let nf_calories: Double
    let nf_total_fat: Double
    let nf_saturated_fat: Double?
    let nf_cholesterol: Double?
    let nf_sodium: Double
    let nf_total_carbohydrate: Double
    let nf_dietary_fiber: Double?
    let nf_sugars: Double?
    let nf_protein: Double
    let nf_potassium: Double?
    let nf_p: Double?
    let full_nutrients: [NutritionixNutrient]?
    let nix_brand_name: String?
    let nix_brand_id: String?
    let nix_item_name: String?
    let nix_item_id: String?
    let upc: String?
    let consumed_at: String?
    let metadata: NutritionixMetadata?
    let source: Int?
    let ndb_no: Int?
    let tags: NutritionixTags?
    let alt_measures: [NutritionixAltMeasure]?
    let lat: Double?
    let lng: Double?
    let photo: NutritionixPhoto?
    let note: String?
    let class_code: String?
    let brick_code: String?
    let tag_id: String?
}

struct NutritionixNutrient: Codable {
    let attr_id: Int
    let value: Double
}

struct NutritionixMetadata: Codable {
    let is_raw_food: Bool?
}

struct NutritionixTags: Codable {
    let item: String?
    let measure: String?
    let food_group: Int?
    let tag_id: Int?
}

struct NutritionixAltMeasure: Codable {
    let serving_weight: Double
    let measure: String
    let seq: Int?
    let qty: Double
}

struct NutritionixPhoto: Codable {
    let thumb: String?
    let highres: String?
    let is_user_uploaded: Bool?
}

struct NutritionixError: Codable {
    let message: String
    let id: String?
    let error_type: String?
}

// MARK: - Nutritionix Result Models for MenuAnalysis Integration

struct NutritionixNutritionResult {
    let originalQuery: String
    let matchedFoodName: String
    let brandName: String?
    let servingDescription: String
    let nutrition: NutritionixNutritionData
    let confidence: Double
    let source: NutritionixSource
    let isSuccess: Bool
    let errorMessage: String?
}

struct NutritionixNutritionData {
    let calories: Double
    let protein: Double      // grams
    let carbs: Double        // grams
    let fat: Double          // grams
    let fiber: Double?       // grams
    let sodium: Double       // milligrams
    let sugar: Double?       // grams
    let saturatedFat: Double?
    let cholesterol: Double?
    let potassium: Double?
    
    var displayCalories: String { "\(Int(calories))" }
    var displayProtein: String { "\(String(format: "%.1f", protein))g" }
    var displayCarbs: String { "\(String(format: "%.1f", carbs))g" }
    var displayFat: String { "\(String(format: "%.1f", fat))g" }
    var displayFiber: String { fiber != nil ? "\(String(format: "%.1f", fiber!))g" : "N/A" }
    var displaySodium: String { "\(Int(sodium))mg" }
    var displaySugar: String { sugar != nil ? "\(String(format: "%.1f", sugar!))g" : "N/A" }
}

enum NutritionixSource: String, CaseIterable {
    case branded = "branded"        // Branded/packaged foods
    case common = "common"          // USDA common foods
    case restaurant = "restaurant"  // Restaurant chain foods
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .branded: return "Branded Food"
        case .common: return "USDA Common Food"
        case .restaurant: return "Restaurant Chain"
        case .unknown: return "Unknown"
        }
    }
    
    var confidence: Double {
        switch self {
        case .restaurant: return 0.9
        case .branded: return 0.85
        case .common: return 0.75
        case .unknown: return 0.5
        }
    }
    
    var emoji: String {
        switch self {
        case .branded: return "🏷️"
        case .common: return "🥬"
        case .restaurant: return "🍽️"
        case .unknown: return "❓"
        }
    }
}

// MARK: - Nutritionix API Service

@MainActor
class NutritionixAPIService: ObservableObject {
    static let shared = NutritionixAPIService()
    
    // MARK: - Configuration
    private let baseURL = "https://trackapi.nutritionix.com/v2"
    private let appId = "11cb6e30"
    private let appKey = "7579b8993d3e284557bafdc861c742a0"
    
    // MARK: - Rate Limiting
    private var lastRequestTime: Date = Date.distantPast
    private let minimumRequestInterval: TimeInterval = 1.0 // 1 second between requests
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var requestCount = 0
    @Published var lastError: Error?
    
    private init() {
        // Validate API credentials on initialization
        if appKey == "7579b8993d3e284557bafdc861c742a0" && appKey.count > 0 {
            nutritionixDebugLog("✅ Nutritionix API service initialized with valid credentials")
        } else {
            nutritionixDebugLog("⚠️ WARNING: Nutritionix API key not configured! Please set your actual API key.")
        }
    }
    
    // MARK: - Public API
    
    /// Analyze a menu item name using Nutritionix natural language API
    func analyzeMenuItem(_ itemName: String) async throws -> NutritionixNutritionResult {
        nutritionixDebugLog("🥗 Analyzing menu item with Nutritionix: '\(itemName)'")
        
        // Rate limiting
        await enforceRateLimit()
        
        isLoading = true
        requestCount += 1
        defer { isLoading = false }
        
        do {
            let request = NutritionixRequest(query: itemName)
            let response = try await performNutritionixRequest(request)
            
            if let firstFood = response.foods.first {
                let result = convertToNutritionResult(
                    originalQuery: itemName,
                    nutritionixFood: firstFood
                )
                nutritionixDebugLog("🥗 ✅ Nutritionix analysis successful for '\(itemName)': \(result.nutrition.displayCalories) cal")
                return result
            } else {
                nutritionixDebugLog("🥗 ❌ No nutrition data found for '\(itemName)'")
                return createFailureResult(
                    originalQuery: itemName,
                    errorMessage: "No nutrition data found"
                )
            }
        } catch {
            nutritionixDebugLog("🥗 ⚠️ Nutritionix API error for '\(itemName)': \(error)")
            lastError = error
            return createFailureResult(
                originalQuery: itemName,
                errorMessage: error.localizedDescription
            )
        }
    }
    
    /// Batch analyze multiple menu items with rate limiting
    func analyzeMenuItems(_ itemNames: [String]) async -> [NutritionixNutritionResult] {
        nutritionixDebugLog("🥗 Starting batch Nutritionix analysis for \(itemNames.count) items")
        
        var results: [NutritionixNutritionResult] = []
        
        for (index, itemName) in itemNames.enumerated() {
            nutritionixDebugLog("🥗 Processing item \(index + 1)/\(itemNames.count): '\(itemName)'")
            
            do {
                let result = try await analyzeMenuItem(itemName)
                results.append(result)
            } catch {
                nutritionixDebugLog("🥗 ⚠️ Failed to analyze '\(itemName)': \(error)")
                let failureResult = createFailureResult(
                    originalQuery: itemName,
                    errorMessage: error.localizedDescription
                )
                results.append(failureResult)
            }
            
            // Progress tracking could be added here
        }
        
        let successCount = results.filter { $0.isSuccess }.count
        nutritionixDebugLog("🥗 Batch analysis complete: \(successCount)/\(itemNames.count) successful")
        
        return results
    }
    
    // MARK: - Private API Methods
    
    private func performNutritionixRequest(_ request: NutritionixRequest) async throws -> NutritionixResponse {
        // Check if API key is configured
        guard appKey == "7579b8993d3e284557bafdc861c742a0" else {
            throw NutritionixAPIError.invalidAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)/natural/nutrients") else {
            throw NutritionixAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(appId, forHTTPHeaderField: "x-app-id")
        urlRequest.addValue(appKey, forHTTPHeaderField: "x-app-key")
        urlRequest.timeoutInterval = 15.0
        
        // Debug log the headers (without exposing the full API key)
        nutritionixDebugLog("🔑 Making request with App ID: \(appId) and API Key: \(String(appKey.prefix(8)))...")
        
        // Encode request body
        let requestData = try JSONEncoder().encode(request)
        urlRequest.httpBody = requestData
        
        // Debug log the request
        nutritionixDebugLog("📤 POST \(url.absoluteString)")
        nutritionixDebugLog("📤 Headers: Content-Type: application/json, x-app-id: \(appId)")
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            nutritionixDebugLog("📥 Response Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 {
                nutritionixDebugLog("🚫 401 Unauthorized - Check your Nutritionix API credentials!")
                throw NutritionixAPIError.invalidAPIKey
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                if let errorData = try? JSONDecoder().decode(NutritionixError.self, from: data) {
                    nutritionixDebugLog("❌ API Error: \(errorData.message)")
                    throw NutritionixAPIError.apiError(errorData.message)
                } else {
                    nutritionixDebugLog("❌ HTTP Error \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        nutritionixDebugLog("❌ Response: \(responseString)")
                    }
                    throw NutritionixAPIError.httpError(httpResponse.statusCode)
                }
            }
        }
        
        // Decode response
        do {
            let nutritionResponse = try JSONDecoder().decode(NutritionixResponse.self, from: data)
            nutritionixDebugLog("✅ Successfully decoded response with \(nutritionResponse.foods.count) foods")
            return nutritionResponse
        } catch {
            nutritionixDebugLog("🥗 JSON decode error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                nutritionixDebugLog("🥗 Raw response: \(jsonString)")
            }
            throw NutritionixAPIError.decodingError(error)
        }
    }
    
    private func convertToNutritionResult(
        originalQuery: String,
        nutritionixFood: NutritionixFood
    ) -> NutritionixNutritionResult {
        let nutritionData = NutritionixNutritionData(
            calories: nutritionixFood.nf_calories,
            protein: nutritionixFood.nf_protein,
            carbs: nutritionixFood.nf_total_carbohydrate,
            fat: nutritionixFood.nf_total_fat,
            fiber: nutritionixFood.nf_dietary_fiber,
            sodium: nutritionixFood.nf_sodium,
            sugar: nutritionixFood.nf_sugars,
            saturatedFat: nutritionixFood.nf_saturated_fat,
            cholesterol: nutritionixFood.nf_cholesterol,
            potassium: nutritionixFood.nf_potassium
        )
        
        let source = determineNutritionixSource(nutritionixFood)
        let servingDescription = "\(nutritionixFood.serving_qty) \(nutritionixFood.serving_unit)"
        
        // Calculate confidence based on source and data completeness
        let baseConfidence = source.confidence
        let dataCompletenessBonus = calculateDataCompletenessBonus(nutritionData)
        let finalConfidence = min(1.0, baseConfidence + dataCompletenessBonus)
        
        return NutritionixNutritionResult(
            originalQuery: originalQuery,
            matchedFoodName: nutritionixFood.food_name,
            brandName: nutritionixFood.brand_name ?? nutritionixFood.nix_brand_name,
            servingDescription: servingDescription,
            nutrition: nutritionData,
            confidence: finalConfidence,
            source: source,
            isSuccess: true,
            errorMessage: nil
        )
    }
    
    private func determineNutritionixSource(_ food: NutritionixFood) -> NutritionixSource {
        // Check for restaurant/chain indicators
        if food.nix_brand_name != nil || food.brand_name != nil {
            return .restaurant
        }
        
        // Check for branded food indicators
        if food.upc != nil || food.nix_item_id != nil {
            return .branded
        }
        
        // Check for USDA common food indicators
        if food.ndb_no != nil {
            return .common
        }
        
        return .unknown
    }
    
    private func calculateDataCompletenessBonus(_ nutrition: NutritionixNutritionData) -> Double {
        var completeness = 0.0
        let totalFields = 6.0
        
        // Core macros (always present)
        completeness += 3.0 // calories, protein, carbs, fat
        
        // Optional but important fields
        if nutrition.fiber != nil { completeness += 1.0 }
        if nutrition.sugar != nil { completeness += 1.0 }
        if nutrition.saturatedFat != nil { completeness += 1.0 }
        
        // Bonus for completeness (max 0.15 confidence boost)
        return (completeness / totalFields) * 0.15
    }
    
    private func createFailureResult(
        originalQuery: String,
        errorMessage: String
    ) -> NutritionixNutritionResult {
        let emptyNutrition = NutritionixNutritionData(
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            fiber: nil,
            sodium: 0,
            sugar: nil,
            saturatedFat: nil,
            cholesterol: nil,
            potassium: nil
        )
        
        return NutritionixNutritionResult(
            originalQuery: originalQuery,
            matchedFoodName: originalQuery,
            brandName: nil,
            servingDescription: "Unknown",
            nutrition: emptyNutrition,
            confidence: 0.0,
            source: .unknown,
            isSuccess: false,
            errorMessage: errorMessage
        )
    }
    
    private func enforceRateLimit() async {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest < minimumRequestInterval {
            let waitTime = minimumRequestInterval - timeSinceLastRequest
            nutritionixDebugLog("🥗 Rate limiting: waiting \(String(format: "%.1f", waitTime))s")
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
}

// MARK: - Nutritionix API Errors

enum NutritionixAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case httpError(Int)
    case apiError(String)
    case decodingError(Error)
    case rateLimitExceeded
    case invalidAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Nutritionix API URL"
        case .noData:
            return "No data received from Nutritionix API"
        case .httpError(let code):
            return "Nutritionix API HTTP error: \(code)"
        case .apiError(let message):
            return "Nutritionix API error: \(message)"
        case .decodingError(let error):
            return "Failed to decode Nutritionix response: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Nutritionix API rate limit exceeded"
        case .invalidAPIKey:
            return "Invalid or missing Nutritionix API key. Please configure your API credentials in NutritionixAPIService.swift"
        }
    }
}

// MARK: - Nutritionix Integration Helpers

extension NutritionixNutritionResult {
    /// Convert to MenuAnalysis NutritionEstimate format
    func toNutritionEstimate() -> NutritionEstimate {
        return NutritionEstimate(
            calories: NutritionRange(min: nutrition.calories, max: nutrition.calories, unit: "kcal"),
            carbs: NutritionRange(min: nutrition.carbs, max: nutrition.carbs, unit: "g"),
            protein: NutritionRange(min: nutrition.protein, max: nutrition.protein, unit: "g"),
            fat: NutritionRange(min: nutrition.fat, max: nutrition.fat, unit: "g"),
            fiber: nutrition.fiber != nil ? NutritionRange(min: nutrition.fiber!, max: nutrition.fiber!, unit: "g") : nil,
            sodium: NutritionRange(min: nutrition.sodium, max: nutrition.sodium, unit: "mg"),
            sugar: nutrition.sugar != nil ? NutritionRange(min: nutrition.sugar!, max: nutrition.sugar!, unit: "g") : nil,
            confidence: confidence,
            estimationSource: .nutritionix,
            sourceDetails: "Nutritionix \(source.displayName): '\(matchedFoodName)'" + (brandName != nil ? " (\(brandName!))" : ""),
            estimatedPortionSize: servingDescription,
            portionConfidence: 0.8
        )
    }
    
    /// Generate dietary tags based on nutrition data
    func generateDietaryTags() -> [DietaryTag] {
        var tags: [DietaryTag] = []
        
        // High protein (≥20g)
        if nutrition.protein >= 20 {
            tags.append(.highProtein)
        }
        
        // Low carb (≤15g)
        if nutrition.carbs <= 15 {
            tags.append(.lowCarb)
        } else if nutrition.carbs >= 45 {
            tags.append(.highCarb)
        }
        
        // Keto-friendly (high fat, very low carb)
        let fatCalories = nutrition.fat * 9
        let carbCalories = nutrition.carbs * 4
        let proteinCalories = nutrition.protein * 4
        let totalCalories = fatCalories + carbCalories + proteinCalories
        
        if totalCalories > 0 {
            let fatRatio = fatCalories / totalCalories
            if fatRatio >= 0.7 && nutrition.carbs <= 10 {
                tags.append(.keto)
            }
        }
        
        // High fiber (≥5g)
        if let fiber = nutrition.fiber, fiber >= 5 {
            tags.append(.highFiber)
        }
        
        // Low sodium (≤600mg)
        if nutrition.sodium <= 600 {
            tags.append(.lowSodium)
        }
        
        // Low sugar (≤5g)
        if let sugar = nutrition.sugar, sugar <= 5 {
            tags.append(.lowSugar)
        }
        
        // Healthy (low calorie + low sodium)
        if nutrition.calories <= 400 && nutrition.sodium <= 600 {
            tags.append(.healthy)
        } else if nutrition.calories > 600 {
            tags.append(.indulgent)
        }
        
        return tags
    }
}

// MARK: - Debug Logging

private func nutritionixDebugLog(_ message: String) {
    print("[NutritionixAPIService] \(message)")
}