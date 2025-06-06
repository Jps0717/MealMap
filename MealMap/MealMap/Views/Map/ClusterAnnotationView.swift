import SwiftUI
import MapKit

struct ClusterAnnotationView: View {
    let count: Int
    let hasNutritionData: Bool
    let allHaveNutritionData: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(allHaveNutritionData ? Color.blue : Color.gray.opacity(0.7))
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            
            // Count
            Text("\(count)")
                .font(.system(size: 16, weight: .bold))
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
                    .offset(x: 14, y: -14)
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        VStack(spacing: 8) {
            ClusterAnnotationView(count: 5, hasNutritionData: true, allHaveNutritionData: true)
            Text("All with Nutrition Data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        VStack(spacing: 8) {
            ClusterAnnotationView(count: 3, hasNutritionData: true, allHaveNutritionData: false)
            Text("Some with Nutrition Data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        VStack(spacing: 8) {
            ClusterAnnotationView(count: 2, hasNutritionData: false, allHaveNutritionData: false)
            Text("No Nutrition Data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color(red: 0.9, green: 0.9, blue: 0.9))
} 