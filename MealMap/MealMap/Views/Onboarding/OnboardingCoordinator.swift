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
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.green.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
    @State private var showSwipeHint = true
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // App Icon/Logo
            VStack(spacing: 24) {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text("🍽️")
                            .font(.system(size: 60))
                    )
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                
                VStack(spacing: 12) {
                    Text("Welcome to")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("MealMap")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Discover nutrition information\nfor restaurants near you")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            // Swipe hint
            VStack(spacing: 16) {
                if showSwipeHint {
                    HStack(spacing: 8) {
                        Text("Swipe right to begin")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "arrow.right")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .offset(x: showSwipeHint ? 0 : 10)
                            .animation(
                                Animation.easeInOut(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                value: showSwipeHint
                            )
                    }
                }
                
                Button(action: onContinue) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                .onTapGesture {
                    HapticService.shared.buttonPress()
                }
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 50)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 {
                        onContinue()
                    }
                }
        )
        .onAppear {
            // Hide swipe hint after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSwipeHint = false
                }
            }
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
                    Spacer(minLength: 60)
                    
                    // Header
                    VStack(spacing: 16) {
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(isSignUp ? "Join MealMap to enjoy meals with ease" : "Sign in to continue your journey")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Form
                    VStack(spacing: 20) {
                        if isSignUp {
                            FloatingTextField(
                                title: "Display Name",
                                text: $displayName,
                                keyboardType: .default
                            )
                        }
                        
                        FloatingTextField(
                            title: "Email",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        
                        FloatingTextField(
                            title: "Password",
                            text: $password,
                            isSecure: true
                        )
                        
                        if isSignUp {
                            FloatingTextField(
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
                    }
                    
                    // Action button
                    Button(action: handleAuthAction) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(16)
                        .disabled(authManager.isLoading)
                    }
                    .padding(.horizontal, 24)
                    .onTapGesture {
                        HapticService.shared.buttonPress()
                    }
                    
                    // Toggle auth mode
                    Button(action: {
                        HapticsManager.shared.toggleChange()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSignUp.toggle()
                            authManager.errorMessage = nil
                        }
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Need an account? Sign Up")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .onTapGesture {
                        HapticService.shared.toggle()
                    }
                    
                    Spacer(minLength: 100)
                }
            }
        }
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

// MARK: - Floating Text Field
struct FloatingTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !text.isEmpty || isFocused {
                Text(title)
                    .font(.caption)
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
            .keyboardType(keyboardType)
            .focused($isFocused)
            .autocapitalization(.none)
            .disableAutocorrection(true)
        }
    }
}

#Preview {
    OnboardingCoordinator()
}