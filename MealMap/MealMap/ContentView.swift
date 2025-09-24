import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var mapViewModel = MapViewModel()

    private var shouldShowNetworkError: Bool {
        !networkMonitor.isConnected
    }
    
    private var shouldShowLocationError: Bool {
        guard networkMonitor.isConnected else { return false }
        
        return locationManager.authorizationStatus == .denied ||
               locationManager.authorizationStatus == .restricted ||
               (locationManager.locationError != nil && !locationManager.usingFallbackLocation)
    }

    var body: some View {
        ZStack {
            if shouldShowNetworkError {
                noNetworkView
            } else if shouldShowLocationError {
                locationErrorView
            } else {
                HomeScreen()
                    .environmentObject(locationManager)
                    .environmentObject(mapViewModel)
            }
        }
        .ignoresSafeArea()
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
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager.shared)
}