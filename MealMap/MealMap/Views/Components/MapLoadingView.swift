import SwiftUI

struct MapLoadingView: View {
    let progress: Double?
    @State private var showSlowLoadingTip = false
    @State private var animationRotation: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            // IMPROVED: Animated loading indicator
            Image(systemName: "map.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(animationRotation))
                .onAppear {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        animationRotation = 360
                    }
                }
            
            VStack(spacing: 8) {
                Text("Loading Map")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Preparing restaurant locations for you...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // IMPROVED: Progress indicator
            if let progress = progress {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .frame(width: 200)
                        .tint(.blue)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.blue)
            }
            
            // IMPROVED: Slow loading tip
            if showSlowLoadingTip {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text("Taking longer than expected?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("The map should load automatically. If it doesn't, please check your internet connection and location permissions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding()
        .onAppear {
            // IMPROVED: Show tip after 3 seconds
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSlowLoadingTip = true
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        MapLoadingView(progress: 0.7)
        MapLoadingView(progress: nil)
    }
}
