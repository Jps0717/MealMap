import Foundation
import os.log

// MARK: - Simplified Analytics Service (No Firebase)
class AnalyticsService {
    static let shared = AnalyticsService()
    
    private let logger = Logger(subsystem: "com.jacksonshell.MealMap", category: "Analytics")
    
    private var eventCount = 0
    private var lastEventTime = Date()
    
    private init() {
        logger.info("📊 AnalyticsService initialized (local logging only)")
    }
    
    // MARK: - Restaurant Website Tracking
    func trackRestaurantWebsiteClick(
        restaurantName: String,
        website: String,
        source: String = "unknown",
        hasNutritionData: Bool = false,
        cuisine: String? = nil
    ) {
        let parameters: [String: Any] = [
            "restaurant_name": restaurantName,
            "website_url": website,
            "source": source,
            "has_nutrition_data": hasNutritionData,
            "cuisine": cuisine ?? "unknown",
            "user_session": generateSessionId(),
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        logEvent("restaurant_website_click", parameters: parameters)
    }
    
    // MARK: - Restaurant Interaction Tracking
    func trackRestaurantView(
        restaurantName: String,
        source: String,
        hasNutritionData: Bool,
        cuisine: String? = nil
    ) {
        let parameters: [String: Any] = [
            "restaurant_name": restaurantName,
            "source": source,
            "has_nutrition_data": hasNutritionData,
            "cuisine": cuisine ?? "unknown",
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        logEvent("restaurant_view", parameters: parameters)
    }
    
    func trackPhoneCall(restaurantName: String, phoneNumber: String) {
        let parameters: [String: Any] = [
            "restaurant_name": restaurantName,
            "phone_number": phoneNumber,
            "source": "restaurant_detail_view",
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        logEvent("restaurant_phone_call", parameters: parameters)
    }
    
    func trackDirections(restaurantName: String, address: String) {
        let parameters: [String: Any] = [
            "restaurant_name": restaurantName,
            "address": address,
            "source": "restaurant_detail_view",
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        logEvent("restaurant_directions", parameters: parameters)
    }
    
    // MARK: - Menu Analytics
    func trackMenuItemView(restaurantName: String, itemName: String, calories: Int) {
        let parameters: [String: Any] = [
            "restaurant_name": restaurantName,
            "item_name": itemName,
            "calories": calories,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        logEvent("menu_item_view", parameters: parameters)
    }
    
    func trackMenuScannerUsage(
        restaurantName: String? = nil,
        source: String,
        hasNutritionData: Bool = false,
        cuisine: String? = nil
    ) {
        var parameters: [String: Any] = [
            "source": source,
            "timestamp": Int(Date().timeIntervalSince1970),
            "session_id": generateSessionId()
        ]
        
        if let restaurant = restaurantName {
            parameters["restaurant_name"] = restaurant
            parameters["restaurant_has_nutrition"] = hasNutritionData
            parameters["restaurant_cuisine"] = cuisine ?? "unknown"
        }
        
        logEvent("menu_scanner_usage", parameters: parameters)
    }
    
    // MARK: - Nutrition Data Usage Tracking
    func trackNutritionDataUsage(
        restaurantName: String,
        source: String,
        itemCount: Int? = nil,
        cuisine: String? = nil
    ) {
        var parameters: [String: Any] = [
            "restaurant_name": restaurantName,
            "source": source,
            "cuisine": cuisine ?? "unknown",
            "timestamp": Int(Date().timeIntervalSince1970),
            "session_id": generateSessionId()
        ]
        
        if let count = itemCount {
            parameters["menu_item_count"] = count
        }
        
        logEvent("nutrition_data_usage", parameters: parameters)
    }
    
    // MARK: - User Behavior Analytics
    func trackMapInteraction(action: String, restaurantCount: Int? = nil) {
        var parameters: [String: Any] = [
            "action": action,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        if let count = restaurantCount {
            parameters["restaurant_count"] = count
        }
        
        logEvent("map_interaction", parameters: parameters)
    }
    
    func trackSearch(query: String, resultCount: Int, source: String) {
        let parameters: [String: Any] = [
            "search_term": query,
            "result_count": resultCount,
            "source": source,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        logEvent("search", parameters: parameters)
    }
    
    // MARK: - App Lifecycle Events
    func trackAppLaunch() {
        logEvent("app_launch", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "session_id": generateSessionId()
        ])
    }
    
    func trackAppBackground() {
        logEvent("app_background", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "session_duration": Int(Date().timeIntervalSince(lastEventTime))
        ])
    }
    
    // MARK: - Local Logging Implementation
    private func logEvent(_ eventName: String, parameters: [String: Any]) {
        eventCount += 1
        lastEventTime = Date()
        
        logger.info("📊 Event #\(self.eventCount): \(eventName)")
        for (key, value) in parameters {
            logger.info("   \(key): \(String(describing: value))")
        }
    }
    
    // MARK: - Helper Methods
    private func generateSessionId() -> String {
        return "session_\(Int(Date().timeIntervalSince1970))"
    }
}