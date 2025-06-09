import SwiftUI
import MapKit

struct ClusterAnnotationView: View {
    let count: Int
    let nutritionDataCount: Int
    let noNutritionDataCount: Int
    
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var individualPinOffsets: [CGSize] = []
    @State private var showingSplitAnimation = false
    
    var body: some View {
        ZStack {
            // Main cluster view
            mainClusterView
                .scaleEffect(scale)
                .opacity(opacity)
            
            if showingSplitAnimation {
                ForEach(0..<min(count, 8), id: \.self) { index in
                    Circle()
                        .fill(index < nutritionDataCount ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                        .offset(individualPinOffsets.indices.contains(index) ? individualPinOffsets[index] : .zero)
                        .opacity(0.7)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.05), value: individualPinOffsets)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .onChange(of: count) { oldValue, newValue in
            if oldValue != newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scale = 1.1
                }
                withAnimation(.easeInOut(duration: 0.2).delay(0.1)) {
                    scale = 1.0
                }
            }
        }
    }
    
    private var mainClusterView: some View {
        ZStack {
            // Large background circle for the main cluster pin
            Circle()
                .fill(Color.blue)
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            
            VStack(spacing: 4) {
                // Total count of restaurants in the cluster
                Text("\(count)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                // Horizontal stack for smaller pins
                HStack(spacing: 4) {
                    if nutritionDataCount > 0 {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("\(nutritionDataCount)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    if noNutritionDataCount > 0 {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("\(noNutritionDataCount)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
        }
    }
    
    func startSplitAnimation() {
        showingSplitAnimation = true
        
        // Generate random offsets for individual pins
        individualPinOffsets = (0..<min(count, 8)).map { index in
            let angle = Double(index) * (2 * .pi / Double(min(count, 8)))
            let radius: CGFloat = 40
            return CGSize(
                width: cos(angle) * radius,
                height: sin(angle) * radius
            )
        }
        
        // Fade out cluster after pins appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                scale = 0.1
                opacity = 0.0
            }
        }
    }
    
    func startMergeAnimation() {
        showingSplitAnimation = false
        individualPinOffsets = []
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        VStack(spacing: 8) {
            ClusterAnnotationView(count: 10, nutritionDataCount: 7, noNutritionDataCount: 3)
            Text("Mixed Data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        VStack(spacing: 8) {
            ClusterAnnotationView(count: 5, nutritionDataCount: 5, noNutritionDataCount: 0)
            Text("All with Nutrition Data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        VStack(spacing: 8) {
            ClusterAnnotationView(count: 3, nutritionDataCount: 0, noNutritionDataCount: 3)
            Text("No Nutrition Data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color(red: 0.9, green: 0.9, blue: 0.9))
}
