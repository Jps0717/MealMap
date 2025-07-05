import SwiftUI

struct CustomAPIKeyErrorPopup: View {
    @Binding var isPresented: Bool
    let onSetupAPIKey: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            // Popup content
            VStack(spacing: 24) {
                // Error icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "key.slash")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.red)
                }
                
                // Title and message
                VStack(spacing: 12) {
                    Text("API Key Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Please set up your Nutritionix API Key to scan menus and analyze nutrition data.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                        // Small delay to let the popup close before showing setup
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onSetupAPIKey()
                        }
                    }) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Set up API Key")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                        .cornerRadius(12)
                    }
                    
                    Button("Cancel") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 40)
            .scaleEffect(isPresented ? 1.0 : 0.8)
            .opacity(isPresented ? 1.0 : 0.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
        }
    }
}

// MARK: - Animated Entry/Exit

extension CustomAPIKeyErrorPopup {
    static func show(isPresented: Binding<Bool>, onSetupAPIKey: @escaping () -> Void) -> some View {
        CustomAPIKeyErrorPopup(isPresented: isPresented, onSetupAPIKey: onSetupAPIKey)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            Text("Menu Analysis Screen")
                .font(.title)
                .padding()
            
            Spacer()
        }
        
        CustomAPIKeyErrorPopup(isPresented: .constant(true)) {
            print("Setup API Key tapped")
        }
    }
}