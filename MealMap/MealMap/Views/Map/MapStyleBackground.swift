import SwiftUI

struct MapStyleBackground: View {
    var body: some View {
        ZStack {
            // Base map-like gradient
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 0.92),  // Light greenish (like land)
                    Color(red: 0.88, green: 0.94, blue: 0.98)   // Light blue (like water)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Street-like lines
            VStack(spacing: 80) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { col in
                            Rectangle()
                                .fill(Color.white.opacity(0.7))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                                .offset(x: CGFloat(row % 2) * 40, y: CGFloat(col % 2) * 20)
                        }
                    }
                }
            }
            .rotationEffect(.degrees(15))
            
            // Additional cross streets
            HStack(spacing: 120) {
                ForEach(0..<4, id: \.self) { col in
                    VStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { row in
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                                .offset(x: CGFloat(col % 2) * 20, y: CGFloat(row % 2) * 30)
                        }
                    }
                }
            }
            .rotationEffect(.degrees(-15))
            
            // Map-like blocks/buildings
            VStack(spacing: 60) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: 80) {
                        ForEach(0..<4, id: \.self) { col in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                                .frame(
                                    width: CGFloat.random(in: 20...40),
                                    height: CGFloat.random(in: 15...30)
                                )
                                .offset(
                                    x: CGFloat.random(in: -10...10),
                                    y: CGFloat.random(in: -10...10)
                                )
                        }
                    }
                }
            }
            
            // Restaurant pin in center
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                        .background(
                            Circle()
                                .fill(.white)
                                .frame(width: 28, height: 28)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

#Preview {
    MapStyleBackground()
}