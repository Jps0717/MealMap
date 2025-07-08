import Foundation
import os.log

// MARK: - Analytics Service (Firebase Analytics Optional)
class AnalyticsService {
    static let shared = AnalyticsService()
    
    private let logger = Logger(subsystem: "com.jacksonshell.MealMap", category: "Analytics")
    
    private init() {}
    
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
            "timestamp": Date().timeIntervalSince1970,
            "user_session": generateSessionId()
        ]
        
        logEvent("restaurant_website_click", parameters: parameters)
        logEvent("select_content", parameters: [
            "content_type": "restaurant_website",
            "item_id": restaurantName.lowercased().replacingOccurrences(of: " ", with: "_"),
            "item_name": restaurantName,
            "item_category": cuisine ?? "restaurant"
        ])
        logEvent("website_conversion", parameters: [
            "event_category": "engagement",
            "event_action": "website_click",
            "event_label": restaurantName,
            "value": 1
        ])
        
        logger.info("📊 Analytics: Website click tracked - \(restaurantName)")
    }
    
    // MARK: - Restaurant Interaction Tracking
    func trackRestaurantView(
        restaurantName: String,
        source: String,
        hasNutritionData: Bool,
        cuisine: String? = nil
    ) {
        logEvent("restaurant_view", parameters: [
            "restaurant_name": restaurantName,
            "source": source,
            "has_nutrition_data": hasNutritionData,
            "cuisine": cuisine ?? "unknown",
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackPhoneCall(restaurantName: String, phoneNumber: String) {
        logEvent("restaurant_phone_call", parameters: [
            "restaurant_name": restaurantName,
            "phone_number": phoneNumber,
            "source": "restaurant_detail_view",
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackDirections(restaurantName: String, address: String) {
        logEvent("restaurant_directions", parameters: [
            "restaurant_name": restaurantName,
            "address": address,
            "source": "restaurant_detail_view",
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Menu Analytics
    func trackMenuItemView(restaurantName: String, itemName: String, calories: Int) {
        logEvent("menu_item_view", parameters: [
            "restaurant_name": restaurantName,
            "item_name": itemName,
            "calories": calories,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackMenuScan(restaurantName: String, source: String) {
        logEvent("menu_scan_initiated", parameters: [
            "restaurant_name": restaurantName,
            "source": source,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - User Behavior Analytics
    func trackMapInteraction(action: String, restaurantCount: Int? = nil) {
        var parameters: [String: Any] = [
            "action": action,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let count = restaurantCount {
            parameters["restaurant_count"] = count
        }
        
        logEvent("map_interaction", parameters: parameters)
    }
    
    func trackSearch(query: String, resultCount: Int, source: String) {
        logEvent("search", parameters: [
            "search_term": query,
            "result_count": resultCount,
            "source": source,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Conversion Funnel Tracking
    func trackUserJourney(step: String, restaurantName: String? = nil) {
        var parameters: [String: Any] = [
            "journey_step": step,
            "timestamp": Date().timeIntervalSince1970,
            "session_id": generateSessionId()
        ]
        
        if let restaurant = restaurantName {
            parameters["restaurant_name"] = restaurant
        }
        
        logEvent("user_journey", parameters: parameters)
    }
    
    // MARK: - Custom Metrics
    func trackWebsiteClickRate(restaurantName: String, viewsCount: Int, clicksCount: Int) {
        let clickRate = clicksCount > 0 ? Double(clicksCount) / Double(viewsCount) : 0.0
        
        logEvent("website_click_rate", parameters: [
            "restaurant_name": restaurantName,
            "views": viewsCount,
            "clicks": clicksCount,
            "click_rate": clickRate,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Private Event Logging
    private func logEvent(_ eventName: String, parameters: [String: Any]) {
        // Log to console for now (Firebase Analytics can be added later)
        logger.info("📊 Event: \(eventName)")
        for (key, value) in parameters {
            logger.info("   \(key): \(String(describing: value))")
        }
        
        // TODO: When Firebase Analytics is added, uncomment this:
        // Analytics.logEvent(eventName, parameters: parameters)
    }
    
    // MARK: - Helper Methods
    private func generateSessionId() -> String {
        return "session_\(Int(Date().timeIntervalSince1970))"
    }
    
    // MARK: - Batch Analytics for Reports
    func getWebsiteAnalytics() {
        logger.info("📊 Website click analytics are being tracked in Firebase")
    }
}

// MARK: - Analytics Extensions
extension AnalyticsService {
    // Quick access methods for common events
    func quickTrackWebsiteClick(restaurant: Restaurant, source: String = "restaurant_detail") {
        guard let website = restaurant.website else { return }
        
        trackRestaurantWebsiteClick(
            restaurantName: restaurant.name,
            website: website,
            source: source,
            hasNutritionData: restaurant.hasNutritionData,
            cuisine: restaurant.cuisine
        )
    }
    
    func quickTrackRestaurantInteraction(restaurant: Restaurant, action: String, source: String) {
        switch action {
        case "phone_call":
            if let phone = restaurant.phone {
                trackPhoneCall(restaurantName: restaurant.name, phoneNumber: phone)
            }
        case "directions":
            if let address = restaurant.address {
                trackDirections(restaurantName: restaurant.name, address: address)
            }
        case "website_click":
            quickTrackWebsiteClick(restaurant: restaurant, source: source)
        default:
            trackUserJourney(step: action, restaurantName: restaurant.name)
        }
    }
}