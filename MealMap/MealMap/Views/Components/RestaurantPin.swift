import SwiftUI

struct RestaurantPin: View {
    let restaurant: Restaurant
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Enhanced background with restaurant-specific color
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [restaurant.pinColor, restaurant.pinColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                    )
                    .shadow(color: restaurant.pinColor.opacity(0.4), radius: isSelected ? 6 : 3, y: isSelected ? 3 : 2)
                
                VStack(spacing: 1) {
                    // Restaurant emoji
                    Text(restaurant.emoji)
                        .font(.system(size: isSelected ? 14 : 11))
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                    
                    // Nutrition data indicator
                    if restaurant.hasNutritionData {
                        Circle()
                            .fill(Color.white)
                            .frame(width: isSelected ? 4 : 3, height: isSelected ? 4 : 3)
                            .overlay(
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: isSelected ? 3 : 2, height: isSelected ? 3 : 2)
                            )
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    HStack(spacing: 32) {
        VStack(spacing: 16) {
            Text("Restaurant Pins")
                .font(.headline)
            
            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    RestaurantPin(
                        restaurant: Restaurant(id: 1, name: "McDonald's", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                        isSelected: false,
                        onTap: { }
                    )
                    Text("McDonald's")
                        .font(.caption)
                }
                
                VStack(spacing: 8) {
                    RestaurantPin(
                        restaurant: Restaurant(id: 2, name: "Pizza Hut", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                        isSelected: true,
                        onTap: { }
                    )
                    Text("Pizza Hut")
                        .font(.caption)
                }
                
                VStack(spacing: 8) {
                    RestaurantPin(
                        restaurant: Restaurant(id: 3, name: "Starbucks", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                        isSelected: false,
                        onTap: { }
                    )
                    Text("Starbucks")
                        .font(.caption)
                }
            }
        }
    }
    .padding(32)
    .background(Color(.systemGray6))
}
