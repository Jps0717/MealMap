import SwiftUI

struct ProfileCompletionPopup: View {
    @Binding var isPresented: Bool
    let onEditProfile: () -> Void
    let onSkipForNow: () -> Void
    
    @State private var showAnimation = false
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            // Popup content
            VStack(spacing: 0) {
                // Header with icon
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.blue)
                    }
                    .scaleEffect(showAnimation ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showAnimation)
                    
                    VStack(spacing: 8) {
                        Text("Complete Your Profile")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Help us personalize your MealMap experience")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("We'll remind you every 35 minutes until completed")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
                
                // Features list
                VStack(spacing: 16) {
                    ProfileFeatureRow(
                        icon: "heart.fill",
                        color: .red,
                        title: "Health Goals",
                        description: "Set your fitness and wellness objectives"
                    )
                    
                    ProfileFeatureRow(
                        icon: "leaf.fill",
                        color: .green,
                        title: "Dietary Preferences",
                        description: "Filter restaurants based on your dietary needs"
                    )
                    
                    ProfileFeatureRow(
                        icon: "chart.bar.fill",
                        color: .blue,
                        title: "Better Recommendations",
                        description: "Get personalized nutrition suggestions"
                    )
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        dismissPopup()
                        HapticsManager.shared.navigationTap()
                        onEditProfile()
                    }) {
                        Text("Complete Profile")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .onTapGesture {
                        HapticService.shared.buttonPress()
                    }
                    
                    Button(action: {
                        dismissPopup()
                        HapticsManager.shared.buttonTap()
                        onSkipForNow()
                    }) {
                        Text("Skip for Now")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .onTapGesture {
                        HapticService.shared.lightImpact()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
            .scaleEffect(showAnimation ? 1.0 : 0.9)
            .opacity(showAnimation ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showAnimation)
        }
        .onAppear {
            showAnimation = true
        }
    }
    
    private func dismissPopup() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showAnimation = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

struct ProfileFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(color)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    ProfileCompletionPopup(
        isPresented: .constant(true),
        onEditProfile: {},
        onSkipForNow: {}
    )
}