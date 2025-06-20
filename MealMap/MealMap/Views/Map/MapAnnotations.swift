import SwiftUI
import MapKit
import CoreLocation

struct UserLocationAnnotationView: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 20, height: 20)
                .scaleEffect(isPulsing ? 2.0 : 1.0)
                .opacity(isPulsing ? 0.0 : 0.6)
                .animation(
                    .easeOut(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: isPulsing
                )
            
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        }
        .frame(width: 40, height: 40)
        .position(x: 20, y: 20)
        .onAppear {
            isPulsing = true
        }
    }
}

struct OptimizedRestaurantAnnotationView: View {
    let restaurant: Restaurant
    let hasNutritionData: Bool
    let isSelected: Bool
    let onTap: (Restaurant) -> Void
    
    var body: some View {
        Button(action: { onTap(restaurant) }) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                    )
                    .shadow(color: .black.opacity(0.3), radius: isSelected ? 6 : 3, y: isSelected ? 3 : 1)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        if hasNutritionData {
            return restaurant.amenityType == "fast_food" ? .orange : .blue
        } else {
            return restaurant.amenityType == "fast_food" ? .red : .gray
        }
    }
}

// MARK: - Restaurant Cluster
struct RestaurantCluster: Identifiable {
    let id = UUID()
    let restaurants: [Restaurant]
    let center: CLLocationCoordinate2D
    let count: Int
    
    init(restaurants: [Restaurant]) {
        self.restaurants = restaurants
        self.count = restaurants.count
        
        // Calculate center point
        let avgLat = restaurants.map { $0.latitude }.reduce(0, +) / Double(restaurants.count)
        let avgLon = restaurants.map { $0.longitude }.reduce(0, +) / Double(restaurants.count)
        self.center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }
}

// MARK: - Enhanced MapItem enum
enum MapItem: Identifiable {
    case userLocation(CLLocationCoordinate2D)
    case restaurant(Restaurant)
    case cluster(RestaurantCluster)

    var id: AnyHashable {
        switch self {
        case .userLocation(let coordinate): 
            return "user_\(coordinate.latitude)_\(coordinate.longitude)"
        case .restaurant(let r): 
            return r.id
        case .cluster(let cluster):
            return cluster.id
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .userLocation(let coordinate): 
            return coordinate
        case .restaurant(let r): 
            return CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude)
        case .cluster(let cluster):
            return cluster.center
        }
    }
}
