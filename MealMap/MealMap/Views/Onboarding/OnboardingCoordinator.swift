import SwiftUI

// MARK: - Onboarding Coordinator
struct OnboardingCoordinator: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var currentStep: OnboardingStep = .welcome
    
    enum OnboardingStep {
        case welcome
        case authentication
        case profileSetup
    }
    
    var body: some View {
        ZStack {
            // Clean white background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // Content
            switch currentStep {
            case .welcome:
                WelcomeScreen {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentStep = .authentication
                    }
                }
                
            case .authentication:
                AuthenticationScreen(
                    onSignUpSuccess: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            currentStep = .profileSetup
                        }
                    },
                    onSignInSuccess: {
                        // Existing user - skip profile setup
                        authManager.hasSeenOnboarding = true
                    }
                )
                
            case .profileSetup:
                ProfileSetupScreen(onComplete: {
                    authManager.hasSeenOnboarding = true
                })
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Welcome Screen
struct WelcomeScreen: View {
    let onContinue: () -> Void
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // App Logo - Clean map symbol only
            VStack(spacing: 32) {
                ZStack {
                    // Background circle with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                        .scaleEffect(animateIcon ? 1.05 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                            value: animateIcon
                        )
                    
                    // Simple map symbol
                    Image(systemName: "map.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 16) {
                    Text("Welcome to")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("MealMap")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Navigate meals with ease")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
            
            // Get Started button only (removed swipe hint)
            VStack(spacing: 20) {
                Button(action: {
                    HapticService.shared.buttonPress()
                    onContinue()
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 60)
        }
        .background(Color(.systemBackground))
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 {
                        HapticService.shared.navigate()
                        onContinue()
                    }
                }
        )
        .onAppear {
            animateIcon = true
        }
    }
}

// MARK: - Authentication Screen  
struct AuthenticationScreen: View {
    let onSignUpSuccess: () -> Void
    let onSignInSuccess: () -> Void
    
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 80)
                    
                    // Header - consistent with app style
                    VStack(spacing: 16) {
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(isSignUp ? "Join MealMap to track your nutrition journey" : "Sign in to continue your nutrition journey")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Form using consistent styling
                    VStack(spacing: 20) {
                        if isSignUp {
                            EnhancedTextField(
                                title: "Display Name",
                                text: $displayName,
                                keyboardType: .default
                            )
                        }
                        
                        EnhancedTextField(
                            title: "Email",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        
                        EnhancedTextField(
                            title: "Password",
                            text: $password,
                            isSecure: true
                        )
                        
                        if isSignUp {
                            EnhancedTextField(
                                title: "Confirm Password",
                                text: $confirmPassword,
                                isSecure: true
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Error message
                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 24)
                    }
                    
                    // Action button using app style
                    Button(action: {
                        HapticService.shared.buttonPress()
                        handleAuthAction()
                    }) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: authManager.isLoading ? [Color.gray, Color.gray.opacity(0.8)] : [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: authManager.isLoading ? .clear : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        .disabled(authManager.isLoading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    
                    // Toggle auth mode
                    Button(action: {
                        HapticService.shared.toggle()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSignUp.toggle()
                            authManager.errorMessage = nil
                        }
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Need an account? Sign Up")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .background(Color(.systemBackground))
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            if newValue {
                if isSignUp {
                    onSignUpSuccess()
                } else {
                    onSignInSuccess()
                }
            }
        }
    }
    
    private func handleAuthAction() {
        Task {
            if isSignUp {
                if password != confirmPassword {
                    authManager.errorMessage = "Passwords don't match"
                    return
                }
                await authManager.signUp(email: email, password: password, displayName: displayName)
            } else {
                await authManager.signIn(email: email, password: password)
            }
        }
    }
}

// MARK: - Enhanced Text Field (updated to match app style)
struct EnhancedTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !text.isEmpty || isFocused {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            }
            
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .font(.body)
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
            )
            .keyboardType(keyboardType)
            .focused($isFocused)
            .autocapitalization(.none)
            .disableAutocorrection(true)
        }
    }
}

// MARK: - Floating Text Field (legacy compatibility)
struct FloatingTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    var body: some View {
        EnhancedTextField(
            title: title,
            text: $text,
            keyboardType: keyboardType,
            isSecure: isSecure
        )
    }
}

#Preview {
    OnboardingCoordinator()
}