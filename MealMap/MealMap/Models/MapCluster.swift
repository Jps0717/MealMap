import Foundation
import CoreLocation
import MapKit

struct MapCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let restaurants: [Restaurant]
    
    var count: Int {
        restaurants.count
    }
    
    var hasNutritionData: Bool {
        restaurants.contains { restaurant in
            RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
        }
    }
    
    var allHaveNutritionData: Bool {
        restaurants.allSatisfy { restaurant in
            RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
        }
    }
    
    static func calculateViewRadius(span: MKCoordinateSpan) -> Double {
        // Convert latitude delta to miles (approximately)
        // 1 degree of latitude is approximately 69 miles
        let latMiles = span.latitudeDelta * 69.0
        // Convert longitude delta to miles (approximately)
        // 1 degree of longitude varies with latitude, but we'll use an average
        let lonMiles = span.longitudeDelta * 69.0 * cos(span.latitudeDelta * .pi / 180)
        // Return the larger of the two to get the radius
        return max(latMiles, lonMiles) / 2.0
    }
    
    static func createClusters(from restaurants: [Restaurant], zoomLevel: Double, span: MKCoordinateSpan, center: CLLocationCoordinate2D) -> [MapCluster] {
        // Define a threshold for showing individual pins (very zoomed in)
        let individualPinThreshold = 0.008 // Example: Show individual pins when latitudeDelta is less than this
        let maxIndividualPins = 100 // Limit the number of individual pins shown
        
        // If zoomed in very close, return individual restaurants as single-item clusters, limited by distance
        if zoomLevel < individualPinThreshold {
            let mapCenter = CLLocation(latitude: center.latitude, longitude: center.longitude)

            // Create a temporary structure with restaurant and its distance
            let restaurantsWithDistance = restaurants.map { restaurant in
                let loc = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
                return (restaurant: restaurant, distance: loc.distance(from: mapCenter))
            }
            
            // Sort by distance and take the top N
            let closestRestaurants = restaurantsWithDistance.sorted { $0.distance < $1.distance }
                .prefix(maxIndividualPins)
                .map { $0.restaurant }
            
            return closestRestaurants.map { restaurant in
                MapCluster(
                    coordinate: CLLocationCoordinate2D(
                        latitude: restaurant.latitude,
                        longitude: restaurant.longitude
                    ),
                    restaurants: [restaurant]
                )
            }
        }
        
        // Otherwise, always perform clustering
        // Adjust grid size based on the current zoom level (span.latitudeDelta)
        let clusteringFactor = 0.02 // Adjust this factor to control clustering density
        let gridSize = zoomLevel * clusteringFactor
        
        // Ensure gridSize has a reasonable minimum to avoid too many clusters even when somewhat zoomed in
        let minGridSize = 0.02 // Minimum grid size to ensure some clustering
        let effectiveGridSize = max(gridSize, minGridSize)

        var clusters: [String: [Restaurant]] = [:]
        
        for restaurant in restaurants {
            let gridX = Int(restaurant.latitude / effectiveGridSize)
            let gridY = Int(restaurant.longitude / effectiveGridSize)
            let key = "\(gridX),\(gridY)"
            
            if clusters[key] == nil {
                clusters[key] = []
            }
            clusters[key]?.append(restaurant)
        }
        
        // Create cluster objects
        return clusters.map { (_, restaurants) in
            let centerLat = restaurants.map { $0.latitude }.reduce(0, +) / Double(restaurants.count)
            let centerLon = restaurants.map { $0.longitude }.reduce(0, +) / Double(restaurants.count)
            
            return MapCluster(
                coordinate: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                restaurants: restaurants
            )
        }
    }
} 