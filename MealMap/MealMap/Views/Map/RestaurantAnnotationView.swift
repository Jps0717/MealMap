import SwiftUI
import MapKit

struct RestaurantAnnotationView: View {
    let restaurant: Restaurant
    let hasNutritionData: Bool
    let isSelected: Bool
    let onTap: (Restaurant) -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var animatedFromCluster = false
    
    var body: some View {
        ZStack {
            // Background circle - CHANGE: Made smaller
            Circle()
                .fill(hasNutritionData ? Color.blue : Color.gray.opacity(0.7))
                .frame(width: isSelected ? 32 : 26, height: isSelected ? 32 : 26)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            
            // Restaurant icon - CHANGE: Made smaller
            Image(systemName: "fork.knife")
                .font(.system(size: isSelected ? 14 : 12, weight: .medium))
                .foregroundColor(.white)
            
            // Nutrition data indicator - CHANGE: Made smaller
            if hasNutritionData {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.white)
                    )
                    .offset(x: 9, y: -9)
            } else {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Image(systemName: "questionmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 9, y: -9)
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .scaleEffect(scale)
        .opacity(opacity)
        .onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            withAnimation(.easeInOut(duration: 0.1)) {
                scale = 1.2
            }
            withAnimation(.easeInOut(duration: 0.1).delay(0.1)) {
                scale = 1.0
            }
            
            onTap(restaurant)
        }
        .onAppear {
            let delay = animatedFromCluster ? Double.random(in: 0...0.3) : 0
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    func animateFromCluster() {
        animatedFromCluster = true
        scale = 0.5
        opacity = 0.0
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double.random(in: 0...0.2))) {
            scale = 1.0
            opacity = 1.0
        }
    }
    
    func animateToCluster() {
        withAnimation(.easeInOut(duration: 0.3).delay(Double.random(in: 0...0.1))) {
            scale = 0.1
            opacity = 0.0
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        VStack(spacing: 8) {
            RestaurantAnnotationView(
                restaurant: Restaurant(id: 1, name: "Test Restaurant", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                hasNutritionData: true,
                isSelected: false,
                onTap: { _ in }
            )
            Text("With Nutrition Data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        VStack(spacing: 8) {
            RestaurantAnnotationView(
                restaurant: Restaurant(id: 2, name: "Test Restaurant 2", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                hasNutritionData: true,
                isSelected: true,
                onTap: { _ in }
            )
            Text("With Nutrition Data (Selected)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        VStack(spacing: 8) {
            RestaurantAnnotationView(
                restaurant: Restaurant(id: 3, name: "Test Restaurant 3", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                hasNutritionData: false,
                isSelected: false,
                onTap: { _ in }
            )
            Text("Without Nutrition Data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        VStack(spacing: 8) {
            RestaurantAnnotationView(
                restaurant: Restaurant(id: 4, name: "Test Restaurant 4", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                hasNutritionData: false,
                isSelected: true,
                onTap: { _ in }
            )
            Text("Without Nutrition Data (Selected)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color(red: 0.9, green: 0.9, blue: 0.9))
}
