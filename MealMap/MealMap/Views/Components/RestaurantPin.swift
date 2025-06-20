import SwiftUI

struct RestaurantPin: View {
    let restaurant: Restaurant
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(pinColor)
                .frame(width: isSelected ? 24 : 16, height: isSelected ? 24 : 16)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.3), radius: isSelected ? 4 : 2, y: 1)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var pinColor: Color {
        let hasNutrition = RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
        return hasNutrition ? .blue : .gray
    }
}