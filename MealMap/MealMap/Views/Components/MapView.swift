import SwiftUI
import MapKit
import CoreLocation

// MARK: - Simplified Map View - Show All Restaurants
struct MapView: View {
    @Binding var region: MKCoordinateRegion
    let restaurants: [Restaurant]
    let userLocation: CLLocationCoordinate2D?
    let selectedRestaurant: Restaurant?
    let onRestaurantTap: (Restaurant) -> Void
    
    // SIMPLIFIED: Just show all restaurants without any filtering or clustering
    private var displayedRestaurants: [Restaurant] {
        debugLog("🔍 MapView - Total restaurants to display: \(restaurants.count)")
        
        // Print all restaurants for debugging
        for (index, restaurant) in restaurants.enumerated() {
            debugLog("🔍 MapView - Restaurant \(index + 1): \(restaurant.name) at (\(restaurant.latitude), \(restaurant.longitude))")
        }
        
        return restaurants // Show ALL restaurants
    }
    
    private var mapAnnotationItems: [MapItem] {
        var items: [MapItem] = []
        
        // Add user location
        if let userLoc = userLocation {
            items.append(.userLocation(userLoc))
            debugLog("🔍 MapView - Added user location pin at (\(userLoc.latitude), \(userLoc.longitude))")
        }
        
        // Add ALL restaurant pins without any clustering or filtering
        let restaurantItems = displayedRestaurants.map { MapItem.restaurant($0) }
        items.append(contentsOf: restaurantItems)
        debugLog("🔍 MapView - Added \(restaurantItems.count) restaurant pins")
        
        debugLog("🔍 MapView - Total map items: \(items.count)")
        return items
    }

    var body: some View {
        Map(
            coordinateRegion: $region,
            interactionModes: .all,
            showsUserLocation: false,
            annotationItems: mapAnnotationItems,
            annotationContent: { item in
                MapAnnotation(coordinate: item.coordinate) {
                    switch item {
                    case .userLocation:
                        UserLocationAnnotationView()

                    case .restaurant(let restaurant):
                        // Simple pin for all restaurants
                        UltraOptimizedPin(
                            restaurant: restaurant,
                            hasNutritionData: restaurant.hasNutritionData,
                            isSelected: selectedRestaurant?.id == restaurant.id,
                            onTap: { _ in 
                                debugLog("🔍 MapView - Restaurant pin tapped: \(restaurant.name)")
                                onRestaurantTap(restaurant) 
                            }
                        )
                        
                    case .cluster:
                        // No clustering - this case shouldn't happen
                        EmptyView()
                    }
                }
            }
        )
        .mapStyle(.standard(pointsOfInterest: []))
        .onAppear {
            debugLog("🔍 MapView - OnAppear: \(restaurants.count) restaurants available")
        }
    }
}
