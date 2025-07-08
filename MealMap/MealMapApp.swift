import SwiftUI
// import FirebaseCore // Will add when Firebase package is installed
// import FirebaseAnalytics

@main
struct MealMapApp: App {
    init() {
        // FirebaseApp.configure() // Will uncomment when Firebase is added
        debugLog("🚀 MealMap app initialized")
        
        // Track app launch
        AnalyticsService.shared.trackAppLaunch()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Track when app goes to background
                    AnalyticsService.shared.trackAppBackground()
                }
        }
    }
}