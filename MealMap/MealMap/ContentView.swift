import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var mapViewModel = MapViewModel()

    private var shouldShowLocationScreens: Bool {
        if let _ = locationManager.locationError {
            return true
        } else if !hasValidLocation {
            return true
        } else if !networkMonitor.isConnected {
            return true
        }
        return false
    }

    private var hasValidLocation: Bool {
        locationManager.lastLocation != nil &&
        (locationManager.authorizationStatus == .authorizedWhenInUse ||
         locationManager.authorizationStatus == .authorizedAlways)
    }

    var body: some View {
        ZStack {
            if shouldShowLocationScreens {
                // Show location/network error screens
                if let locationError = locationManager.locationError {
                    NoLocationView(
                        title: "Location Access Required",
                        subtitle: locationError,
                        buttonText: "Enable Location",
                        onRetry: {
                            locationManager.requestLocationPermission()
                        }
                    )
                } else if !hasValidLocation {
                    NoLocationView(
                        title: "No Location Found",
                        subtitle: "MealMap needs your location to find restaurants near you.",
                        buttonText: "Request Location",
                        onRetry: {
                            locationManager.requestLocationPermission()
                        }
                    )
                } else if !networkMonitor.isConnected {
                    NoLocationView(
                        title: "No Network Connection",
                        subtitle: "Please check your internet connection and try again.",
                        buttonText: "Try Again",
                        onRetry: {
                            locationManager.restart()
                        }
                    )
                }
            } else {
                HomeScreen()
                    .environmentObject(locationManager)
                    .environmentObject(mapViewModel)
            }
        }
        .ignoresSafeArea()
        // FORCED: Always use light appearance at the app level
        .preferredColorScheme(.light)
    }
}


// Preview
#Preview {
    ContentView()
}
