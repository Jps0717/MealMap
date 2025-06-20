import SwiftUI
import MapKit

// MARK: - Ultra-Optimized Pin View
struct UltraOptimizedPin: View {
    let restaurant: Restaurant
    let hasNutritionData: Bool
    let isSelected: Bool
    let onTap: (Restaurant) -> Void
    
    var body: some View {
        Button(action: { onTap(restaurant) }) {
            Circle()
                .fill(pinColor)
                .frame(width: isSelected ? 18 : 12, height: isSelected ? 18 : 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: .black.opacity(0.15), radius: isSelected ? 2 : 1, y: isSelected ? 1 : 0)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
    
    private var pinColor: Color {
        if hasNutritionData {
            return restaurant.amenityType == "fast_food" ? .orange : .blue
        } else {
            return restaurant.amenityType == "fast_food" ? .red : .gray
        }
    }
}

// MARK: - Performance-Optimized Restaurant Annotation
struct RestaurantAnnotationView: View {
    let restaurant: Restaurant
    let hasNutritionData: Bool
    let isSelected: Bool
    let onTap: (Restaurant) -> Void
    
    // Remove @State animations for better performance
    private var restaurantCategory: RestaurantCategory? {
        for category in RestaurantCategory.allCases {
            if restaurant.matchesCategory(category) {
                return category
            }
        }
        return nil
    }
    
    private var pinColor: Color {
        if let category = restaurantCategory {
            return category.color
        }
        return hasNutritionData ? .orange : .blue
    }
    
    private var pinIcon: String {
        if let category = restaurantCategory {
            return category.icon
        }
        return restaurant.amenityType == "fast_food" ? "f.square.fill" : "fork.knife"
    }
    
    var body: some View {
        Button(action: { onTap(restaurant) }) {
            ZStack {
                // Simplified pin shape
                Circle()
                    .fill(pinColor)
                    .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                
                // Icon (only for selected or important restaurants)
                if isSelected || hasNutritionData {
                    Image(systemName: pinIcon)
                        .font(.system(size: isSelected ? 12 : 8, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Nutrition indicator - simplified
                if hasNutritionData {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .offset(x: 8, y: -8)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                                .frame(width: 6, height: 6)
                                .offset(x: 8, y: -8)
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Clustered Pin View for Zoom Out
struct ClusteredPinView: View {
    let count: Int
    let coordinate: CLLocationCoordinate2D
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: clusterSize, height: clusterSize)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                
                Text("\(count)")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var clusterSize: CGFloat {
        switch count {
        case 1...5: return 24
        case 6...15: return 32
        case 16...50: return 40
        default: return 48
        }
    }
    
    private var fontSize: CGFloat {
        switch count {
        case 1...5: return 10
        case 6...15: return 12
        case 16...50: return 14
        default: return 16
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        HStack(spacing: 32) {
            VStack(spacing: 8) {
                UltraOptimizedPin(
                    restaurant: Restaurant(id: 1, name: "McDonald's", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                    hasNutritionData: true,
                    isSelected: false,
                    onTap: { _ in }
                )
                Text("Ultra Optimized")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                RestaurantAnnotationView(
                    restaurant: Restaurant(id: 2, name: "Sweetgreen", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                    hasNutritionData: false,
                    isSelected: false,
                    onTap: { _ in }
                )
                Text("Optimized")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        HStack(spacing: 32) {
            VStack(spacing: 8) {
                ClusteredPinView(
                    count: 5,
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    onTap: { }
                )
                Text("Cluster")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    .padding(32)
    .background(Color(.systemGray6))
}
