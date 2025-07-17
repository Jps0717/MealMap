import SwiftUI

struct RestaurantPin: View {
    let restaurant: Restaurant
    let isSelected: Bool
    let onTap: () -> Void
    
    @StateObject private var scoringService = RestaurantMapScoringService.shared
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Enhanced background without scoring colors
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [restaurant.pinBackgroundColor, restaurant.pinBackgroundColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                    )
                    .shadow(color: restaurant.pinBackgroundColor.opacity(0.4), radius: isSelected ? 6 : 3, y: isSelected ? 3 : 2)
                
                VStack(spacing: 1) {
                    // Restaurant emoji (using basic emoji, not scoring-enhanced)
                    Text(restaurant.emoji)
                        .font(.system(size: isSelected ? 16 : 12))
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                    
                    // Simple nutrition data indicator (no score display)
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
        .onAppear {
            // Run a timer that runs every 60 seconds
            // Trigger scoring calculation when pin appears
            if restaurant.hasNutritionData && restaurant.mapScore == nil {
                Task {
                    await scoringService.calculateScoreForRestaurant(restaurant)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        Text("Restaurant Pins Without Scoring")
            .font(.title2)
            .fontWeight(.semibold)
        
        HStack(spacing: 24) {
            VStack(spacing: 8) {
                RestaurantPin(
                    restaurant: Restaurant(id: 1, name: "McDonald's", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                    isSelected: false,
                    onTap: { }
                )
                Text("McDonald's")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                RestaurantPin(
                    restaurant: Restaurant(id: 2, name: "Subway", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                    isSelected: true,
                    onTap: { }
                )
                Text("Subway")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                RestaurantPin(
                    restaurant: Restaurant(id: 3, name: "Panera Bread", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                    isSelected: false,
                    onTap: { }
                )
                Text("Panera Bread")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        VStack(spacing: 16) {
            Text("Pin Legend")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack {
                    Text("🍔 Has Nutrition Data")
                        .font(.caption)
                    Spacer()
                    Circle().fill(Color.green).frame(width: 12, height: 12)
                }
                
                HStack {
                    Text("🏪 No Nutrition Data")
                        .font(.caption)
                    Spacer()
                    Circle().fill(Color.gray).frame(width: 12, height: 12)
                }
            }
        }
    }
    .padding(32)
    .background(Color(.systemGray6))
}