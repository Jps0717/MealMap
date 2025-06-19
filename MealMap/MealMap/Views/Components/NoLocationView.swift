import SwiftUI

struct NoLocationView: View {
    let title: String
    let subtitle: String
    let buttonText: String
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            // UPDATED: Match HomeScreen background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) { // Increased spacing for better layout
                Spacer()
                
                // UPDATED: More prominent icon with consistent styling
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "location.slash")
                        .font(.system(size: 48, weight: .medium)) // More consistent with HomeScreen
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded)) // Match HomeScreen font style
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary) // Use primary color for better readability
                        .padding(.horizontal)
                        
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded)) // Match HomeScreen font style
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                }
                
                // UPDATED: Match HomeScreen button styling
                Button(action: onRetry) {
                    Text(buttonText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded)) // Match HomeScreen button font
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(20) // Match HomeScreen button corner radius
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4) // Match HomeScreen shadow
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    NoLocationView(
        title: "Location Access Required",
        subtitle: "MealMap needs your location to find restaurants near you.",
        buttonText: "Enable Location",
        onRetry: { }
    )
}