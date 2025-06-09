import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    @Published var heading: Double = 0
    @Published var locationError: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.headingFilter = 5 // Update heading every 5 degrees
        
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
            locationError = nil
        case .denied:
            locationError = "Location access was denied. Please enable location access in Settings to find restaurants near you."
        case .restricted:
            locationError = "Location access is restricted on this device. Please check your device settings."
        case .notDetermined:
            locationError = nil // Don't show error for undetermined state
        @unknown default:
            locationError = "Unknown location authorization status."
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
        locationError = nil // Clear any previous errors when we get a location
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = "Location access was denied. Please enable location access in Settings to find restaurants near you."
            case .locationUnknown:
                locationError = "Unable to determine your location. Please make sure location services are enabled and try again."
            case .network:
                locationError = "Network error while getting location. Please check your internet connection."
            default:
                locationError = "Failed to get your location: \(error.localizedDescription)"
            }
        } else {
            locationError = "Failed to get your location: \(error.localizedDescription)"
        }
    }
    
    func restart() {
        locationError = nil
        
        // Only start updating if we have permission
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        case .notDetermined:
            requestLocationPermission()
        case .denied, .restricted:
            locationError = "Location access is required to find restaurants near you. Please enable it in Settings."
        @unknown default:
            locationError = "Unknown location authorization status."
        }
    }
}
