import SwiftUI
import MapKit

struct RestaurantAnnotationView: View {
    let restaurant: Restaurant
    let hasNutritionData: Bool
    let isSelected: Bool
    let onTap: (Restaurant) -> Void
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: isSelected ? 32 : 28, height: isSelected ? 32 : 28)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            
            Image(systemName: "fork.knife")
                .font(.system(size: isSelected ? 14 : 12, weight: .medium))
                .foregroundColor(.white)
            
            if hasNutritionData {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .offset(x: 10, y: -10)
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        .scaleEffect(scale)
        .opacity(opacity)
        .onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            withAnimation(.easeInOut(duration: 0.08)) {
                scale = 1.15
            }
            withAnimation(.easeInOut(duration: 0.08).delay(0.08)) {
                scale = 1.0
            }
            
            onTap(restaurant)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double.random(in: 0...0.1))) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    func animateFromCluster() {
        scale = 0.8
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
    VStack(spacing: 32) {
        HStack(spacing: 32) {
            VStack(spacing: 8) {
                RestaurantAnnotationView(
                    restaurant: Restaurant(id: 1, name: "McDonald's", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                    hasNutritionData: true,
                    isSelected: false,
                    onTap: { _ in }
                )
                Text("With Nutrition")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                RestaurantAnnotationView(
                    restaurant: Restaurant(id: 2, name: "Local Cafe", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                    hasNutritionData: false,
                    isSelected: false,
                    onTap: { _ in }
                )
                Text("No Nutrition")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        HStack(spacing: 32) {
            VStack(spacing: 8) {
                RestaurantAnnotationView(
                    restaurant: Restaurant(id: 3, name: "Burger King", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                    hasNutritionData: true,
                    isSelected: true,
                    onTap: { _ in }
                )
                Text("Selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                RestaurantAnnotationView(
                    restaurant: Restaurant(id: 4, name: "Pizza Place", latitude: 0, longitude: 0, address: nil, cuisine: nil, openingHours: nil, phone: nil, website: nil, type: "node"),
                    hasNutritionData: false,
                    isSelected: true,
                    onTap: { _ in }
                )
                Text("Selected (No Data)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    .padding(32)
    .background(Color(.systemGray6))
}
