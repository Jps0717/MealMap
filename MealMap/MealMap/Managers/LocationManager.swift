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
        case .denied, .restricted:
            locationError = "Location access is required to find restaurants near you. Please enable it in Settings."
        case .notDetermined:
            locationError = "Please allow location access to find restaurants near you."
        @unknown default:
            locationError = "Unknown location authorization status."
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = "Location access is required to find restaurants near you. Please enable it in Settings."
            case .locationUnknown:
                // Temporary error, don't show to user
                break
            default:
                locationError = error.localizedDescription
            }
        } else {
            locationError = error.localizedDescription
        }
    }
    
    func restart() {
        locationError = nil
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
} 
