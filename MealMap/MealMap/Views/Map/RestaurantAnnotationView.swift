import SwiftUI
import MapKit

struct RestaurantAnnotationView: View {
    let hasNutritionData: Bool
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(hasNutritionData ? Color.blue : Color.gray.opacity(0.7))
                .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            
            // Restaurant icon
            Image(systemName: "fork.knife")
                .font(.system(size: isSelected ? 18 : 16, weight: .medium))
                .foregroundColor(.white)
            
            // Nutrition data indicator
            if hasNutritionData {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                    )
                    .offset(x: 12, y: -12)
            } else {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Image(systemName: "questionmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 12, y: -12)
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

#Preview {
    VStack(spacing: 40) {
        VStack(spacing: 8) {
            RestaurantAnnotationView(hasNutritionData: true, isSelected: false)
            Text("With Nutrition Data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        VStack(spacing: 8) {
            RestaurantAnnotationView(hasNutritionData: true, isSelected: true)
            Text("With Nutrition Data (Selected)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        VStack(spacing: 8) {
            RestaurantAnnotationView(hasNutritionData: false, isSelected: false)
            Text("Without Nutrition Data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        VStack(spacing: 8) {
            RestaurantAnnotationView(hasNutritionData: false, isSelected: true)
            Text("Without Nutrition Data (Selected)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color(red: 0.9, green: 0.9, blue: 0.9))
}

