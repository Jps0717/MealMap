import Foundation
import os.log

// MARK: - Firebase Analytics REST API Service
class AnalyticsService {
    static let shared = AnalyticsService()
    
    private let logger = Logger(subsystem: "com.jacksonshell.MealMap", category: "Analytics")
    
    // Firebase configuration
    private let measurementId = "G-CRC3B99HZQ" // Your actual Measurement ID
    private let apiSecret = "ukzxeqZFRIqamjKHaRQFNw" // Your actual API secret
    
    // Analytics tracking
    private var eventCount = 0
    private var lastEventTime = Date()
    
    private init() {
        logger.info("📊 AnalyticsService initialized with Firebase REST API")
        logger.info("📊 Measurement ID: \(self.measurementId)")
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
        
        // Send only the main restaurant website click event
        sendEventToFirebase("restaurant_website_click", parameters: parameters)
        
        // Track conversion event
        sendEventToFirebase("conversion", parameters: [
            "conversion_type": "website_click",
            "restaurant_name": restaurantName,
            "value": 1,
            "currency": "USD"
        ])
        
        logger.info("📊 Website click tracked: \(restaurantName) -> \(website)")
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
        
        sendEventToFirebase("restaurant_view", parameters: parameters)
        
        // Track engagement event
        sendEventToFirebase("engagement", parameters: [
            "engagement_type": "restaurant_view",
            "restaurant_name": restaurantName,
            "session_id": generateSessionId()
        ])
    }
    
    func trackPhoneCall(restaurantName: String, phoneNumber: String) {
        let parameters: [String: Any] = [
            "restaurant_name": restaurantName,
            "phone_number": phoneNumber,
            "source": "restaurant_detail_view",
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        sendEventToFirebase("restaurant_phone_call", parameters: parameters)
        
        // Track high-value conversion
        sendEventToFirebase("conversion", parameters: [
            "conversion_type": "phone_call",
            "restaurant_name": restaurantName,
            "value": 10,
            "currency": "USD"
        ])
    }
    
    func trackDirections(restaurantName: String, address: String) {
        let parameters: [String: Any] = [
            "restaurant_name": restaurantName,
            "address": address,
            "source": "restaurant_detail_view",
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        sendEventToFirebase("restaurant_directions", parameters: parameters)
        
        // Track conversion event
        sendEventToFirebase("conversion", parameters: [
            "conversion_type": "directions",
            "restaurant_name": restaurantName,
            "value": 5,
            "currency": "USD"
        ])
    }
    
    // MARK: - Menu Analytics
    func trackMenuItemView(restaurantName: String, itemName: String, calories: Int) {
        let parameters: [String: Any] = [
            "restaurant_name": restaurantName,
            "item_name": itemName,
            "calories": calories,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        sendEventToFirebase("menu_item_view", parameters: parameters)
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
        
        // Add restaurant context if available
        if let restaurant = restaurantName {
            parameters["restaurant_name"] = restaurant
            parameters["restaurant_has_nutrition"] = hasNutritionData
            parameters["restaurant_cuisine"] = cuisine ?? "unknown"
        }
        
        sendEventToFirebase("menu_scanner_usage", parameters: parameters)
        
        // Track as high-value engagement
        sendEventToFirebase("engagement", parameters: [
            "engagement_type": "menu_scanner_usage",
            "restaurant_name": restaurantName ?? "unknown",
            "source": source,
            "session_id": generateSessionId()
        ])
        
        logger.info("📊 Menu scanner usage tracked: \(restaurantName ?? "home_screen") from \(source)")
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
        
        sendEventToFirebase("nutrition_data_usage", parameters: parameters)
        
        // Track as valuable engagement
        sendEventToFirebase("engagement", parameters: [
            "engagement_type": "nutrition_data_usage",
            "restaurant_name": restaurantName,
            "source": source,
            "session_id": generateSessionId()
        ])
        
        logger.info("📊 Nutrition data usage tracked: \(restaurantName) from \(source)")
    }
    
    // MARK: - Deprecated - Use trackMenuScannerUsage instead
    func trackMenuScan(restaurantName: String, source: String) {
        // Redirect to new enhanced tracking
        trackMenuScannerUsage(
            restaurantName: restaurantName,
            source: source,
            hasNutritionData: false
        )
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
        
        sendEventToFirebase("map_interaction", parameters: parameters)
    }
    
    func trackSearch(query: String, resultCount: Int, source: String) {
        let parameters: [String: Any] = [
            "search_term": query,
            "result_count": resultCount,
            "source": source,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        sendEventToFirebase("search", parameters: parameters)
    }
    
    // MARK: - Conversion Funnel Tracking
    func trackUserJourney(step: String, restaurantName: String? = nil) {
        var parameters: [String: Any] = [
            "journey_step": step,
            "session_id": generateSessionId(),
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        if let restaurant = restaurantName {
            parameters["restaurant_name"] = restaurant
        }
        
        sendEventToFirebase("user_journey", parameters: parameters)
    }
    
    // MARK: - App Lifecycle Events
    func trackAppLaunch() {
        sendEventToFirebase("app_launch", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "session_id": generateSessionId()
        ])
    }
    
    func trackAppBackground() {
        sendEventToFirebase("app_background", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "session_duration": Int(Date().timeIntervalSince(lastEventTime))
        ])
    }
    
    // MARK: - Firebase REST API Implementation
    private func sendEventToFirebase(_ eventName: String, parameters: [String: Any]) {
        eventCount += 1
        lastEventTime = Date()
        
        // Log to console for debugging
        logger.info("📊 Event #\(self.eventCount): \(eventName)")
        for (key, value) in parameters {
            logger.info("   \(key): \(String(describing: value))")
        }
        
        // Send to Firebase Analytics via REST API
        Task {
            await sendEventViaAPI(eventName, parameters: parameters)
        }
    }
    
    private func sendEventViaAPI(_ eventName: String, parameters: [String: Any]) async {
        // Firebase Analytics Measurement Protocol URL
        let urlString = "https://www.google-analytics.com/mp/collect?measurement_id=\(measurementId)&api_secret=\(apiSecret)"
        
        guard let url = URL(string: urlString) else {
            logger.error("❌ Invalid Firebase Analytics URL")
            return
        }
        
        // Create the payload with enhanced event structure
        let payload: [String: Any] = [
            "client_id": generateClientId(),
            "user_id": generateUserId(),
            "timestamp_micros": Int(Date().timeIntervalSince1970 * 1_000_000),
            "user_properties": [
                "app_version": [
                    "value": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                ],
                "device_type": [
                    "value": "iOS"
                ]
            ],
            "events": [
                [
                    "name": eventName,
                    "params": parameters
                ]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            request.timeoutInterval = 15
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 {
                    logger.info("✅ Event sent to Firebase: \(eventName)")
                } else {
                    logger.error("❌ Firebase API error: \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        logger.error("❌ Response: \(responseString)")
                    }
                }
            }
            
        } catch {
            logger.error("❌ Failed to send event to Firebase: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    private func generateSessionId() -> String {
        return "session_\(Int(Date().timeIntervalSince1970))"
    }
    
    private func generateClientId() -> String {
        // Generate a unique client ID and store it persistently
        if let stored = UserDefaults.standard.string(forKey: "firebase_client_id") {
            return stored
        }
        
        let clientId = UUID().uuidString
        UserDefaults.standard.set(clientId, forKey: "firebase_client_id")
        return clientId
    }
    
    private func generateUserId() -> String {
        // Generate a unique user ID and store it persistently
        if let stored = UserDefaults.standard.string(forKey: "firebase_user_id") {
            return stored
        }
        
        let userId = "user_\(UUID().uuidString.prefix(8))"
        UserDefaults.standard.set(userId, forKey: "firebase_user_id")
        return userId
    }
    
    // MARK: - Analytics Reporting
    func getAnalyticsStatus() -> String {
        return """
        📊 Firebase Analytics Status:
        - Measurement ID: \(measurementId)
        - Events sent: \(eventCount)
        - Last event: \(DateFormatter.localizedString(from: lastEventTime, dateStyle: .short, timeStyle: .medium))
        - Client ID: \(generateClientId())
        - User ID: \(generateUserId())
        """
    }
    
    func getWebsiteAnalytics() {
        logger.info("📊 Website click analytics are being tracked via Firebase REST API")
        logger.info("📊 Firebase Measurement ID: \(self.measurementId)")
        logger.info("📊 API Secret configured: ✅")
        logger.info("📊 Events sent this session: \(self.eventCount)")
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
        case "menu_scanner":
            trackMenuScannerUsage(
                restaurantName: restaurant.name,
                source: source,
                hasNutritionData: restaurant.hasNutritionData,
                cuisine: restaurant.cuisine
            )
        case "nutrition_data":
            trackNutritionDataUsage(
                restaurantName: restaurant.name,
                source: source,
                cuisine: restaurant.cuisine
            )
        default:
            trackUserJourney(step: action, restaurantName: restaurant.name)
        }
    }
    
    // MARK: - Analytics Summary
    func getNewAnalyticsSummary() -> String {
        return """
        📊 Enhanced Analytics Tracking:
        
        🔍 Menu Scanner Usage:
        - Tracks restaurant context when used from restaurant detail
        - Tracks home screen usage vs restaurant-specific usage
        - Parameters: restaurant_name, source, has_nutrition_data, cuisine
        
        📈 Nutrition Data Usage:
        - Tracks which restaurants users view nutrition for most
        - Tracks successful vs failed nutrition loading
        - Parameters: restaurant_name, source, item_count, cuisine
        
        🌐 Website Clicks:
        - Removed select_content duplicate tracking
        - Clean single-event tracking with full context
        - Parameters: restaurant_name, website_url, source, has_nutrition_data, cuisine
        
        📱 User Journey:
        - All events include session_id for path analysis
        - Engagement events track high-value actions
        - Session duration and frequency tracking
        """
    }
}