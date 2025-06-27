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
    @Published var usingFallbackLocation = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.headingFilter = 5 // Update heading every 5 degrees
        
        authorizationStatus = locationManager.authorizationStatus
        
        debugLog("📍 LocationManager initialized with status: \(authorizationStatusString)")
    }
    
    private var authorizationStatusString: String {
        switch authorizationStatus {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        case .authorizedAlways: return "authorizedAlways"
        @unknown default: return "unknown"
        }
    }
    
    func requestLocationPermission() {
        debugLog("📍 Requesting location permission (current status: \(authorizationStatusString))")
        locationManager.requestWhenInUseAuthorization()
    }
    
    // IMPROVED: Add fallback location support
    func setFallbackLocation(_ location: CLLocation) {
        lastLocation = location
        usingFallbackLocation = true
        locationError = nil
        debugLog("📍 Using fallback location: \(location.coordinate)")
    }
    
    func clearFallbackLocation() {
        usingFallbackLocation = false
        // Restart location services if authorized
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    // NEW: Force a fresh location update
    func refreshCurrentLocation() {
        debugLog("📍 FORCE REFRESH: Getting fresh current location")
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            debugLog("❌ Cannot refresh location - not authorized (status: \(authorizationStatusString))")
            return
        }
        
        // Stop and restart location services to get fresh location
        locationManager.stopUpdatingLocation()
        
        // Brief delay then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            debugLog("📍 Restarting location services for fresh location")
            self.locationManager.startUpdatingLocation()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let oldStatus = authorizationStatus
        authorizationStatus = manager.authorizationStatus
        
        debugLog("📍 Location authorization changed: \(authorizationStatusString(for: oldStatus)) → \(authorizationStatusString)")
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            debugLog("📍 Starting location updates...")
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
            locationError = nil
            usingFallbackLocation = false
        case .denied:
            debugLog("❌ Location access denied")
            locationError = "Location access was denied. Please enable location access in Settings to find restaurants near you."
        case .restricted:
            debugLog("❌ Location access restricted")
            locationError = "Location access is restricted on this device. Please check your device settings."
        case .notDetermined:
            debugLog("⏳ Location access not determined")
            locationError = nil // Don't show error for undetermined state
        @unknown default:
            debugLog("❓ Unknown location authorization status")
            locationError = "Unknown location authorization status."
        }
    }
    
    private func authorizationStatusString(for status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        case .authorizedAlways: return "authorizedAlways"
        @unknown default: return "unknown"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        debugLog("📍 NEW LOCATION RECEIVED:")
        debugLog("   ↳ Coordinates: (\(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude))")
        debugLog("   ↳ Accuracy: \(newLocation.horizontalAccuracy)m")
        debugLog("   ↳ Timestamp: \(newLocation.timestamp)")
        debugLog("   ↳ Age: \(abs(newLocation.timestamp.timeIntervalSinceNow))s ago")
        
        // Only use recent locations (within last 30 seconds)
        if abs(newLocation.timestamp.timeIntervalSinceNow) < 30 {
            let oldLocation = lastLocation
            lastLocation = newLocation
            locationError = nil
            usingFallbackLocation = false
            
            if let old = oldLocation {
                let distance = newLocation.distance(from: old)
                debugLog("📍 Location updated - moved \(String(format: "%.0f", distance))m from previous location")
            } else {
                debugLog("📍 First location acquired!")
            }
        } else {
            debugLog("⚠️ Ignoring old location (age: \(abs(newLocation.timestamp.timeIntervalSinceNow))s)")
        }
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
        debugLog("📍 RESTART: Restarting location services")
        locationError = nil
        
        // Only start updating if we have permission
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            debugLog("📍 Have authorization - starting location updates")
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        case .notDetermined:
            debugLog("📍 No authorization - requesting permission")
            requestLocationPermission()
        case .denied, .restricted:
            debugLog("❌ Location denied/restricted")
            locationError = "Location access is required to find restaurants near you. Please enable it in Settings."
        @unknown default:
            debugLog("❓ Unknown authorization status")
            locationError = "Unknown location authorization status."
        }
    }
}
