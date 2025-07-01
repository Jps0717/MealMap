import SwiftUI
import MapKit

// MARK: - Enhanced Pin View with Emojis and Colors
struct UltraOptimizedPin: View {
    let restaurant: Restaurant
    let hasNutritionData: Bool // Keep for backward compatibility but not used
    let isSelected: Bool
    let onTap: (Restaurant) -> Void
    
    var body: some View {
        Button(action: { onTap(restaurant) }) {
            ZStack {
                // Background circle with restaurant-specific color
                Circle()
                    .fill(restaurant.pinBackgroundColor)
                    .frame(width: isSelected ? 32 : 24, height: isSelected ? 32 : 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                    )
                    .shadow(color: restaurant.pinColor.opacity(0.4), radius: isSelected ? 4 : 2, y: isSelected ? 2 : 1)
                
                // Restaurant emoji
                Text(restaurant.emoji)
                    .font(.system(size: isSelected ? 14 : 12))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Enhanced Restaurant Annotation with Rich Visual Design
struct RestaurantAnnotationView: View {
    let restaurant: Restaurant
    let hasNutritionData: Bool // Keep for backward compatibility but not used
    let isSelected: Bool
    let onTap: (Restaurant) -> Void
    
    var body: some View {
        Button(action: { onTap(restaurant) }) {
            ZStack {
                // Main pin background
                RoundedRectangle(cornerRadius: isSelected ? 16 : 12)
                    .fill(restaurant.pinBackgroundColor)
                    .frame(width: isSelected ? 48 : 36, height: isSelected ? 48 : 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: isSelected ? 16 : 12)
                            .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                    )
                    .shadow(color: restaurant.pinColor.opacity(0.5), radius: isSelected ? 6 : 3, y: isSelected ? 3 : 2)
                
                VStack(spacing: 2) {
                    // Restaurant emoji
                    Text(restaurant.emoji)
                        .font(.system(size: isSelected ? 16 : 12))
                    
                    // Optional nutrition indicator
                    if restaurant.hasNutritionData {
                        Circle()
                            .fill(Color.green)
                            .frame(width: isSelected ? 6 : 4, height: isSelected ? 6 : 4)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Enhanced Clustered Pin View
struct ClusteredPinView: View {
    let count: Int
    let coordinate: CLLocationCoordinate2D
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Main cluster background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [clusterColor, clusterColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: clusterSize, height: clusterSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: clusterColor.opacity(0.4), radius: 4, y: 2)
                
                VStack(spacing: 1) {
                    // Cluster emoji
                    Text("🍽️")
                        .font(.system(size: clusterEmojiSize))
                    
                    // Count
                    Text("\(count)")
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count)
    }
    
    private var clusterSize: CGFloat {
        switch count {
        case 1...5: return 32
        case 6...15: return 40
        case 16...50: return 48
        default: return 56
        }
    }
    
    private var fontSize: CGFloat {
        switch count {
        case 1...5: return 8
        case 6...15: return 10
        case 16...50: return 12
        default: return 14
        }
    }
    
    private var clusterEmojiSize: CGFloat {
        switch count {
        case 1...5: return 12
        case 6...15: return 14
        case 16...50: return 16
        default: return 18
        }
    }
    
    private var clusterColor: Color {
        switch count {
        case 1...5: return .blue
        case 6...15: return .orange
        case 16...50: return .purple
        default: return .red
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        Text("Enhanced Restaurant Pins with Emojis")
            .font(.title2)
            .fontWeight(.semibold)
        
        HStack(spacing: 24) {
            VStack(spacing: 8) {
                UltraOptimizedPin(
                    restaurant: Restaurant(id: 1, name: "McDonald's", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                    hasNutritionData: true,
                    isSelected: false,
                    onTap: { _ in }
                )
                Text("McDonald's")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                UltraOptimizedPin(
                    restaurant: Restaurant(id: 2, name: "Starbucks", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                    hasNutritionData: false,
                    isSelected: false,
                    onTap: { _ in }
                )
                Text("Starbucks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                RestaurantAnnotationView(
                    restaurant: Restaurant(id: 3, name: "Sushi Restaurant", latitude: 0, longitude: 0, address: nil, cuisine: "sushi", openingHours: nil, phone: nil, website: nil, type: "node"),
                    hasNutritionData: true,
                    isSelected: true,
                    onTap: { _ in }
                )
                Text("Sushi Place")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        HStack(spacing: 24) {
            VStack(spacing: 8) {
                ClusteredPinView(
                    count: 5,
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    onTap: { }
                )
                Text("Small Cluster")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ClusteredPinView(
                    count: 25,
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    onTap: { }
                )
                Text("Large Cluster")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    .padding(32)
    .background(Color(.systemGray6))
}
