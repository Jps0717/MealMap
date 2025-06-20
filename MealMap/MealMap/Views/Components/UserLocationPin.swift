import SwiftUI

struct UserLocationPin: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 20, height: 20)
                .scaleEffect(isPulsing ? 2.0 : 1.0)
                .opacity(isPulsing ? 0.0 : 0.6)
                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
            
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        }
        .onAppear { isPulsing = true }
    }
}