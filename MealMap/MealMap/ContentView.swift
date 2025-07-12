import SwiftUI
import CoreLocation

struct ContentView: View {
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var mapViewModel = MapViewModel()
    @ObservedObject private var authManager = AuthenticationManager.shared

    // MARK: - Simplified Access Checks to prevent blocking auth
    private var shouldShowNetworkError: Bool {
        // Only show network error for authenticated users trying to use features
        authManager.isAuthenticated && !networkMonitor.isConnected
    }
    
    private var shouldShowLocationError: Bool {
        // Only show location error for authenticated users trying to use features
        guard authManager.isAuthenticated && networkMonitor.isConnected else { return false }
        
        return locationManager.authorizationStatus == .denied ||
               locationManager.authorizationStatus == .restricted ||
               (locationManager.locationError != nil && !locationManager.usingFallbackLocation)
    }

    private var hasValidLocation: Bool {
        locationManager.lastLocation != nil &&
        (locationManager.authorizationStatus == .authorizedWhenInUse ||
         locationManager.authorizationStatus == .authorizedAlways)
    }

    var body: some View {
        ZStack {
            // MARK: - Prioritize Authentication Flow
            if authManager.shouldShowOnboarding {
                // 1. Onboarding (First Priority - don't block with network/location)
                OnboardingCoordinator()
            } else if shouldShowNetworkError {
                // 2. Network Error (Only for authenticated users)
                noNetworkView
            } else if shouldShowLocationError {
                // 3. Location Error (Only for authenticated users)
                locationErrorView
            } else {
                // 4. Main App (All requirements satisfied or user not authenticated yet)
                HomeScreen()
                    .environmentObject(locationManager)
                    .environmentObject(mapViewModel)
            }
        }
        .ignoresSafeArea()
        // FORCED: Always use light appearance at the app level
        .preferredColorScheme(.light)
    }
    
    // MARK: - Network Error View
    private var noNetworkView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Network Error Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 16) {
                Text("No Internet Connection")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                Text("MealMap requires an internet connection to find restaurants and provide nutrition information.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                // Trigger a network check - NetworkMonitor will auto-update
                HapticService.shared.buttonPress()
            }) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(25)
            }
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Location Error View
    private var locationErrorView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Location Error Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: locationErrorIconName)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 16) {
                Text(locationErrorTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                Text(locationErrorMessage)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
            }
            
            // Primary Action Button only
            Button(action: primaryLocationAction) {
                Text(primaryLocationButtonText)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(25)
            }
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Location Error Computed Properties
    private var locationErrorIconName: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return "location.slash.fill"
        case .notDetermined:
            return "location.circle"
        default:
            return "location.slash"
        }
    }
    
    private var locationErrorTitle: String {
        switch locationManager.authorizationStatus {
        case .denied:
            return "Location Access Denied"
        case .restricted:
            return "Location Access Restricted"
        case .notDetermined:
            return "Location Access Required"
        default:
            if locationManager.locationError != nil {
                return "Location Error"
            }
            return "Unable to Get Location"
        }
    }
    
    private var locationErrorMessage: String {
        switch locationManager.authorizationStatus {
        case .denied:
            return "MealMap needs access to your location to find restaurants near you. Please enable location access in Settings."
        case .restricted:
            return "Location access is restricted on this device. Please check your device settings and parental controls."
        case .notDetermined:
            return "MealMap uses your location to find the best restaurants and dining options near you."
        default:
            if let error = locationManager.locationError {
                return error
            }
            return "We're having trouble getting your current location. Please make sure location services are enabled."
        }
    }
    
    private var primaryLocationButtonText: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return "Open Settings"
        case .notDetermined:
            return "Enable Location"
        default:
            return "Try Again"
        }
    }
    
    private var showSecondaryLocationAction: Bool {
        // Removed secondary action - always false
        false
    }
    
    // MARK: - Location Action Functions
    private func primaryLocationAction() {
        HapticService.shared.buttonPress()
        
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            openSettings()
        case .notDetermined:
            locationManager.requestLocationPermission()
        default:
            locationManager.restart()
        }
    }
    
    private func secondaryLocationAction() {
        // Removed - no longer used
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// Preview
#Preview {
    ContentView()
}