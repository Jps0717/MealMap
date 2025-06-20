import SwiftUI
import CoreLocation

struct LocationErrorView: View {
    @StateObject private var locationManager = LocationManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            VStack(spacing: 12) {
                Text("Location Access Needed")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(locationErrorMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                if locationManager.authorizationStatus == .notDetermined {
                    Button("Enable Location") {
                        locationManager.requestLocationPermission()
                    }
                    .buttonStyle(.borderedProminent)
                } else if locationManager.authorizationStatus == .denied {
                    Button("Open Settings") {
                        openSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // IMPROVED: Fallback option
                Button("Continue with Default Location") {
                    useDefaultLocation()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    private var locationErrorMessage: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "MealMap needs access to your location to show nearby restaurants. Please enable location access to continue."
        case .denied:
            return "Location access is disabled. Please enable location services in Settings to see restaurants near you."
        case .restricted:
            return "Location access is restricted on this device. Please check your device settings."
        default:
            return "Unable to access your location. Please check your location settings and try again."
        }
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    private func useDefaultLocation() {
        // IMPROVED: Use a default location (New York City) as fallback
        let defaultLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        locationManager.setFallbackLocation(defaultLocation)
    }
}

#Preview {
    LocationErrorView()
}
