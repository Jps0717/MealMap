import SwiftUI
import MapKit

struct ClusterAnnotationView: View {
    let count: Int
    let nutritionDataCount: Int
    let noNutritionDataCount: Int
    
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: clusterSize, height: clusterSize)
                .overlay(
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                )
            
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: badgeSize, height: badgeSize)
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                
                Text("\(count)")
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .onChange(of: count) { oldValue, newValue in
            if oldValue != newValue {
                withAnimation(.easeInOut(duration: 0.15)) {
                    scale = 1.05
                }
                withAnimation(.easeInOut(duration: 0.15).delay(0.1)) {
                    scale = 1.0
                }
            }
        }
    }
    
    private var clusterSize: CGFloat {
        switch count {
        case 1...5: return 40
        case 6...15: return 48
        case 16...30: return 56
        default: return 64
        }
    }
    
    private var badgeSize: CGFloat {
        switch count {
        case 1...5: return 24
        case 6...15: return 28
        case 16...30: return 32
        default: return 36
        }
    }
    
    private var fontSize: CGFloat {
        switch count {
        case 1...5: return 12
        case 6...15: return 14
        case 16...30: return 16
        default: return 18
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        HStack(spacing: 32) {
            VStack(spacing: 8) {
                ClusterAnnotationView(count: 3, nutritionDataCount: 3, noNutritionDataCount: 0)
                Text("Small (3)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ClusterAnnotationView(count: 12, nutritionDataCount: 8, noNutritionDataCount: 4)
                Text("Medium (12)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        HStack(spacing: 32) {
            VStack(spacing: 8) {
                ClusterAnnotationView(count: 25, nutritionDataCount: 15, noNutritionDataCount: 10)
                Text("Large (25)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ClusterAnnotationView(count: 50, nutritionDataCount: 30, noNutritionDataCount: 20)
                Text("Extra Large (50)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    .padding(32)
    .background(Color(.systemGray6))
}
