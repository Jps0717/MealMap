import Foundation

// MARK: - Nutritionix API Data Models

struct NutritionixRequest: Codable {
    let query: String
    let timezone: String = "US/Eastern"
    let num_servings: Int = 1
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

// MARK: - Nutritionix Result Models

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
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?
    let sodium: Double
    let sugar: Double?
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
    case branded = "branded"
    case common = "common"
    case restaurant = "restaurant"
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

// MARK: - Validation Models

struct APIKeyValidationResult {
    let isValid: Bool
    let errorType: ValidationErrorType?
    let message: String
}

enum ValidationErrorType: String {
    case invalidFormat = "Invalid format"
    case unauthorized = "Unauthorized"
    case forbidden = "Forbidden"
    case rateLimited = "Rate limited"
    case timeout = "Timeout"
    case networkError = "Network error"
    case serverError = "Server error"
    case unknown = "Unknown"
}

// MARK: - Nutritionix API Service

@MainActor
class NutritionixAPIService: ObservableObject {
    static let shared = NutritionixAPIService()
    
    // MARK: - Configuration
    private let baseURL = "https://trackapi.nutritionix.com/v2"
    
    // MARK: - API Credentials Management
    private let userDefaults = UserDefaults.standard
    private let appIdStorageKey = "NutritionixAppID"
    private let apiKeyStorageKey = "NutritionixAPIKey"
    
    var isAPIKeyConfigured: Bool {
        return isAPICredentialsConfigured
    }
    
    var isAPICredentialsConfigured: Bool {
        return userAppID != nil && !userAppID!.isEmpty && 
               userAPIKey != nil && !userAPIKey!.isEmpty
    }
    
    var userAppID: String? {
        get {
            return userDefaults.string(forKey: appIdStorageKey)
        }
        set {
            if let newValue = newValue, !newValue.isEmpty {
                userDefaults.set(newValue, forKey: appIdStorageKey)
                nutritionixDebugLog("✅ Nutritionix App ID configured and saved")
            } else {
                userDefaults.removeObject(forKey: appIdStorageKey)
                nutritionixDebugLog("🗑️ Nutritionix App ID removed")
            }
        }
    }
    
    var userAPIKey: String? {
        get {
            return userDefaults.string(forKey: apiKeyStorageKey)
        }
        set {
            if let newValue = newValue, !newValue.isEmpty {
                userDefaults.set(newValue, forKey: apiKeyStorageKey)
                nutritionixDebugLog("✅ Nutritionix API key configured and saved")
            } else {
                userDefaults.removeObject(forKey: apiKeyStorageKey)
                nutritionixDebugLog("🗑️ Nutritionix API key removed")
            }
        }
    }
    
    // MARK: - Rate Limiting
    private var lastRequestTime: Date = Date.distantPast
    private let minimumRequestInterval: TimeInterval = 1.0
    
    // MARK: - Daily Usage Tracking
    private let dailyLimit = 150
    private let usageCountKey = "NutritionixDailyUsageCount"
    private let lastResetDateKey = "NutritionixLastResetDate"
    
    var currentDailyUsage: Int {
        resetDailyCounterIfNeeded()
        return userDefaults.integer(forKey: usageCountKey)
    }
    
    var remainingDailyRequests: Int {
        return max(0, dailyLimit - currentDailyUsage)
    }
    
    var dailyUsageString: String {
        return "\(currentDailyUsage)/\(dailyLimit)"
    }
    
    var hasReachedDailyLimit: Bool {
        return currentDailyUsage >= dailyLimit
    }
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var requestCount = 0
    @Published var lastError: Error?
    @Published var showingAPIKeySetup = false
    
    private init() {
        if isAPICredentialsConfigured {
            nutritionixDebugLog("✅ Nutritionix API service initialized with user-configured credentials")
        } else {
            nutritionixDebugLog("⚠️ No Nutritionix API credentials configured. User will need to set up their App ID and API key.")
        }
    }
    
    // MARK: - API Credentials Management
    
    func validateAPICredentials(_ appId: String, _ apiKey: String) async throws -> APIKeyValidationResult {
        nutritionixDebugLog("🔑 Validating API credentials - App ID: \(String(appId.prefix(8))), API Key: \(String(apiKey.prefix(8)))...")
        
        // Basic format validation
        guard !appId.isEmpty && appId.count >= 8 else {
            return APIKeyValidationResult(isValid: false, errorType: .invalidFormat, message: "App ID must be at least 8 characters long")
        }
        
        guard !apiKey.isEmpty && apiKey.count >= 20 else {
            return APIKeyValidationResult(isValid: false, errorType: .invalidFormat, message: "API key must be at least 20 characters long")
        }
        
        // Character validation
        let validCharacterSet = CharacterSet.alphanumerics
        guard appId.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }) else {
            return APIKeyValidationResult(isValid: false, errorType: .invalidFormat, message: "App ID can only contain letters and numbers")
        }
        
        guard apiKey.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }) else {
            return APIKeyValidationResult(isValid: false, errorType: .invalidFormat, message: "API key can only contain letters and numbers")
        }
        
        // API validation
        guard let url = URL(string: "\(baseURL)/natural/nutrients") else {
            throw NutritionixAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(appId, forHTTPHeaderField: "x-app-id")
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-app-key")
        urlRequest.timeoutInterval = 15.0
        
        let testRequest = NutritionixRequest(query: "apple")
        let requestData = try JSONEncoder().encode(testRequest)
        urlRequest.httpBody = requestData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    do {
                        let nutritionResponse = try JSONDecoder().decode(NutritionixResponse.self, from: data)
                        if !nutritionResponse.foods.isEmpty {
                            return APIKeyValidationResult(isValid: true, errorType: nil, message: "API credentials validated successfully")
                        } else {
                            return APIKeyValidationResult(isValid: true, errorType: nil, message: "API credentials valid (no test data returned)")
                        }
                    } catch {
                        return APIKeyValidationResult(isValid: true, errorType: nil, message: "API credentials valid (response format changed)")
                    }
                case 401:
                    return APIKeyValidationResult(isValid: false, errorType: .unauthorized, message: "Invalid App ID or API Key combination")
                case 403:
                    return APIKeyValidationResult(isValid: false, errorType: .forbidden, message: "API credentials do not have required permissions")
                case 429:
                    return APIKeyValidationResult(isValid: false, errorType: .rateLimited, message: "Rate limit exceeded. Please try again in a few minutes")
                case 500...599:
                    return APIKeyValidationResult(isValid: false, errorType: .serverError, message: "Nutritionix server temporarily unavailable")
                default:
                    return APIKeyValidationResult(isValid: false, errorType: .unknown, message: "Unexpected response from server (Code: \(httpResponse.statusCode))")
                }
            }
        } catch {
            if error.localizedDescription.contains("timeout") {
                return APIKeyValidationResult(isValid: false, errorType: .timeout, message: "Request timed out. Please check your internet connection")
            } else {
                return APIKeyValidationResult(isValid: false, errorType: .networkError, message: "Network error: \(error)")
            }
        }
        
        return APIKeyValidationResult(isValid: false, errorType: .unknown, message: "Unknown validation error")
    }
    
    func saveAPICredentials(_ appId: String, _ apiKey: String) async throws {
        let validationResult = try await validateAPICredentials(appId, apiKey)
        
        if validationResult.isValid {
            userAppID = appId
            userAPIKey = apiKey
            showingAPIKeySetup = false
            nutritionixDebugLog("✅ API credentials validated and saved successfully")
        } else {
            switch validationResult.errorType {
            case .invalidFormat:
                throw NutritionixAPIError.invalidAPIKeyFormat
            case .unauthorized:
                throw NutritionixAPIError.invalidAPIKey
            case .forbidden:
                throw NutritionixAPIError.apiKeyForbidden
            case .rateLimited:
                throw NutritionixAPIError.rateLimitExceeded
            case .timeout:
                throw NutritionixAPIError.validationTimeout
            case .networkError:
                throw NutritionixAPIError.networkError
            case .serverError:
                throw NutritionixAPIError.serverError
            default:
                throw NutritionixAPIError.validationFailed(validationResult.message)
            }
        }
    }
    
    func clearAPICredentials() {
        userAppID = nil
        userAPIKey = nil
        nutritionixDebugLog("🗑️ API credentials cleared")
    }
    
    func showAPIKeySetup() {
        showingAPIKeySetup = true
    }
    
    // MARK: - Public API
    
    func analyzeMenuItem(_ itemName: String) async throws -> NutritionixNutritionResult {
        nutritionixDebugLog("🥗 Analyzing menu item with Nutritionix: '\(itemName)'")
        
        guard isAPICredentialsConfigured else {
            nutritionixDebugLog("❌ No API credentials configured - showing setup")
            showingAPIKeySetup = true
            throw NutritionixAPIError.noAPIKeyConfigured
        }
        
        try checkDailyLimit()
        await enforceRateLimit()
        
        isLoading = true
        requestCount += 1
        defer { isLoading = false }
        
        do {
            let request = NutritionixRequest(query: itemName)
            let response = try await performNutritionixRequest(request)
            
            incrementDailyUsage()
            
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
    
    // MARK: - Private Methods
    
    private func performNutritionixRequest(_ request: NutritionixRequest) async throws -> NutritionixResponse {
        guard let appId = userAppID, !appId.isEmpty,
              let apiKey = userAPIKey, !apiKey.isEmpty else {
            throw NutritionixAPIError.noAPIKeyConfigured
        }
        
        guard let url = URL(string: "\(baseURL)/natural/nutrients") else {
            throw NutritionixAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(appId, forHTTPHeaderField: "x-app-id")
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-app-key")
        urlRequest.timeoutInterval = 15.0
        
        nutritionixDebugLog("🔑 Making request with App ID: \(String(appId.prefix(8))) and API Key: \(String(apiKey.prefix(8)))...")
        
        let requestData = try JSONEncoder().encode(request)
        urlRequest.httpBody = requestData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        if let httpResponse = response as? HTTPURLResponse {
            nutritionixDebugLog("📥 Response Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 {
                nutritionixDebugLog("🚫 401 Unauthorized - API credentials may be invalid!")
                throw NutritionixAPIError.invalidAPIKey
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                if let errorData = try? JSONDecoder().decode(NutritionixError.self, from: data) {
                    nutritionixDebugLog("❌ API Error: \(errorData.message)")
                    throw NutritionixAPIError.apiError(errorData.message)
                } else {
                    nutritionixDebugLog("❌ HTTP Error \(httpResponse.statusCode)")
                    throw NutritionixAPIError.httpError(httpResponse.statusCode)
                }
            }
        }
        
        do {
            let nutritionResponse = try JSONDecoder().decode(NutritionixResponse.self, from: data)
            nutritionixDebugLog("✅ Successfully decoded response with \(nutritionResponse.foods.count) foods")
            return nutritionResponse
        } catch {
            nutritionixDebugLog("🥗 JSON decode error: \(error)")
            throw NutritionixAPIError.decodingError(error)
        }
    }
    
    private func convertToNutritionResult(
        originalQuery: String,
        nutritionixFood: NutritionixFood
    ) -> NutritionixNutritionResult {
        // Debug: Log the actual food_name from Nutritionix API
        nutritionixDebugLog("🔍 DEBUG: Nutritionix returned food_name: '\(nutritionixFood.food_name)' for query: '\(originalQuery)'")
        
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
        
        let result = NutritionixNutritionResult(
            originalQuery: originalQuery,
            matchedFoodName: nutritionixFood.food_name,
            brandName: nutritionixFood.brand_name ?? nutritionixFood.nix_brand_name,
            servingDescription: servingDescription,
            nutrition: nutritionData,
            confidence: source.confidence,
            source: source,
            isSuccess: true,
            errorMessage: nil
        )
        
        // Debug: Log the final result
        nutritionixDebugLog("🔍 DEBUG: Final result - matchedFoodName: '\(result.matchedFoodName)' for originalQuery: '\(originalQuery)'")
        
        return result
    }
    
    private func determineNutritionixSource(_ food: NutritionixFood) -> NutritionixSource {
        if food.nix_brand_name != nil || food.brand_name != nil {
            return .restaurant
        }
        if food.upc != nil || food.nix_item_id != nil {
            return .branded
        }
        if food.ndb_no != nil {
            return .common
        }
        return .unknown
    }
    
    private func createFailureResult(
        originalQuery: String,
        errorMessage: String
    ) -> NutritionixNutritionResult {
        let emptyNutrition = NutritionixNutritionData(
            calories: 0, protein: 0, carbs: 0, fat: 0,
            fiber: nil, sodium: 0, sugar: nil,
            saturatedFat: nil, cholesterol: nil, potassium: nil
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
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
    
    private func resetDailyCounterIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastResetDate = userDefaults.object(forKey: lastResetDateKey) as? Date ?? Date.distantPast
        let lastResetDay = Calendar.current.startOfDay(for: lastResetDate)
        
        if today > lastResetDay {
            userDefaults.set(0, forKey: usageCountKey)
            userDefaults.set(today, forKey: lastResetDateKey)
        }
    }
    
    private func incrementDailyUsage() {
        resetDailyCounterIfNeeded()
        let currentCount = userDefaults.integer(forKey: usageCountKey)
        userDefaults.set(currentCount + 1, forKey: usageCountKey)
    }
    
    private func checkDailyLimit() throws {
        resetDailyCounterIfNeeded()
        
        if hasReachedDailyLimit {
            throw NutritionixAPIError.dailyLimitReached
        }
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
    case invalidAPIKeyFormat
    case apiKeyForbidden
    case noAPIKeyConfigured
    case dailyLimitReached
    case validationFailed(String)
    case validationTimeout
    case networkError
    case serverError

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
            return "Rate limit exceeded. Please try again in a few minutes."
        case .invalidAPIKey:
            return "Invalid App ID or API Key combination. Please check both values."
        case .dailyLimitReached:
            return "Daily limit of 150 nutrition analyses reached. Resets at midnight."
        case .noAPIKeyConfigured:
            return "Nutritionix credentials not configured. Please set up your App ID and API key."
        case .invalidAPIKeyFormat:
            return "API credentials format is invalid. Please check that you copied both values completely."
        case .apiKeyForbidden:
            return "API credentials do not have the required permissions for nutrition data access."
        case .validationTimeout:
            return "Validation request timed out. Please check your internet connection."
        case .networkError:
            return "Network error occurred during validation. Please check your connection."
        case .serverError:
            return "Nutritionix server is temporarily unavailable. Please try again later."
        case .validationFailed(let message):
            return message
        }
    }
}

// MARK: - Extensions

extension NutritionixNutritionResult {
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