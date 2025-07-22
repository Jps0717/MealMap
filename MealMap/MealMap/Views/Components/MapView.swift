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
    
    @State private var mapPosition: MapCameraPosition
    
    // Initialize map position based on region
    init(region: Binding<MKCoordinateRegion>, restaurants: [Restaurant], userLocation: CLLocationCoordinate2D?, selectedRestaurant: Restaurant?, onRestaurantTap: @escaping (Restaurant) -> Void) {
        self._region = region
        self.restaurants = restaurants
        self.userLocation = userLocation
        self.selectedRestaurant = selectedRestaurant
        self.onRestaurantTap = onRestaurantTap
        self._mapPosition = State(initialValue: .region(region.wrappedValue))
    }
    
    // SIMPLIFIED: Just show all restaurants without any filtering or clustering
    private var displayedRestaurants: [Restaurant] {
        debugLog("🔍 MapView - Total restaurants to display: \(restaurants.count)")
        
        // Print all restaurants for debugging
        for (index, restaurant) in restaurants.enumerated() {
            debugLog("🔍 MapView - Restaurant \(index + 1): \(restaurant.name) at (\(restaurant.latitude), \(restaurant.longitude))")
        }
        
        return restaurants // Show ALL restaurants
    }

    var body: some View {
        ZStack {
            // Use the simple Map API
            Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true, annotationItems: displayedRestaurants) { restaurant in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)) {
                    UltraOptimizedPin(
                        restaurant: restaurant,
                        hasNutritionData: restaurant.hasNutritionData,
                        isSelected: selectedRestaurant?.id == restaurant.id,
                        onTap: { _ in 
                            debugLog("🔍 MapView - Restaurant pin tapped: \(restaurant.name)")
                            onRestaurantTap(restaurant) 
                        }
                    )
                }
            }
            .mapStyle(.standard(pointsOfInterest: []))
        }
        .onAppear {
            debugLog("🔍 MapView - OnAppear: \(restaurants.count) restaurants available")
        }
    }
}