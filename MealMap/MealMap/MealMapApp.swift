import SwiftUI

@main
struct MealMapApp: App {
    @StateObject private var authManager = AuthenticationManager.shared

    init() {
        debugLog("🚀 MealMap app initialized")
        
        // Initialize crash reporting first
        _ = CrashReportingService.shared
        
        // Track app launch
        AnalyticsService.shared.trackAppLaunch()
    }
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
            } else {
                // In a real app, you might show a loading screen
                // For now, we'll just show a simple text view
                Text("Loading...")
            }
        }
    }
}