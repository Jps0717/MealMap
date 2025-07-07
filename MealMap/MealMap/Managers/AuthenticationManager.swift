import SwiftUI
import Foundation

// MARK: - Authentication Manager with Firebase REST API
@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let hasSeenOnboardingKey = "hasSeenOnboarding"
    private let lastUserEmailKey = "lastUserEmail"
    private let firebaseTokenKey = "firebaseToken"
    private let firebaseUserIdKey = "firebaseUserId"
    
    private let authService = FirebaseAuthService.shared
    private let firestoreService = FirebaseFirestoreService.shared
    
    var hasSeenOnboarding: Bool {
        get { userDefaults.bool(forKey: hasSeenOnboardingKey) }
        set { userDefaults.set(newValue, forKey: hasSeenOnboardingKey) }
    }
    
    var shouldShowOnboarding: Bool {
        return !isAuthenticated && !hasSeenOnboarding
    }
    
    private init() {
        checkExistingAuth()
    }
    
    // MARK: - Check for existing authentication
    private func checkExistingAuth() {
        if let savedToken = userDefaults.string(forKey: firebaseTokenKey),
           let savedUserId = userDefaults.string(forKey: firebaseUserIdKey),
           let savedEmail = userDefaults.string(forKey: lastUserEmailKey) {
            
            // Try to load user from Firestore
            Task {
                do {
                    if let user = try await firestoreService.getUser(userId: savedUserId, idToken: savedToken) {
                        self.currentUser = user
                        self.isAuthenticated = true
                    } else {
                        // User document doesn't exist, create a basic user
                        let user = User(id: savedUserId, email: savedEmail, displayName: "User")
                        self.currentUser = user
                        self.isAuthenticated = true
                    }
                } catch {
                    // Token might be expired, clear and require re-login
                    self.clearStoredAuth()
                }
            }
        }
    }
    
    // MARK: - Sign Up with Firebase
    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create Firebase Auth account
            let authResponse = try await authService.signUp(email: email, password: password)
            
            // Create user object
            let user = User(
                id: authResponse.localId,
                email: authResponse.email,
                displayName: displayName
            )
            
            // Save to Firestore
            try await firestoreService.createUser(user, idToken: authResponse.idToken)
            
            // Update local state
            currentUser = user
            isAuthenticated = true
            hasSeenOnboarding = true
            
            // Store credentials
            userDefaults.set(authResponse.email, forKey: lastUserEmailKey)
            userDefaults.set(authResponse.idToken, forKey: firebaseTokenKey)
            userDefaults.set(authResponse.localId, forKey: firebaseUserIdKey)
            
        } catch {
            if let firebaseError = error as? FirebaseError {
                errorMessage = firebaseError.localizedDescription
            } else {
                errorMessage = "Sign up failed: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Sign In with Firebase
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sign in with Firebase
            let authResponse = try await authService.signIn(email: email, password: password)
            
            // Load user from Firestore
            if let user = try await firestoreService.getUser(userId: authResponse.localId, idToken: authResponse.idToken) {
                currentUser = user
            } else {
                // Create basic user if document doesn't exist
                let user = User(id: authResponse.localId, email: authResponse.email, displayName: "User")
                currentUser = user
                try await firestoreService.createUser(user, idToken: authResponse.idToken)
            }
            
            isAuthenticated = true
            
            // Store credentials
            userDefaults.set(authResponse.email, forKey: lastUserEmailKey)
            userDefaults.set(authResponse.idToken, forKey: firebaseTokenKey)
            userDefaults.set(authResponse.localId, forKey: firebaseUserIdKey)
            
        } catch {
            if let firebaseError = error as? FirebaseError {
                errorMessage = firebaseError.localizedDescription
            } else {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Update User Profile with Firebase
    func updateUserProfile(_ profile: UserProfile, preferences: UserPreferences) async {
        guard var user = currentUser,
              let token = userDefaults.string(forKey: firebaseTokenKey) else { return }
        
        isLoading = true
        
        user.profile = profile
        user.preferences = preferences
        
        do {
            // Update in Firestore
            try await firestoreService.updateUser(user, idToken: token)
            
            // Update local state
            currentUser = user
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        clearStoredAuth()
    }
    
    // MARK: - Reset (for testing)
    func resetOnboarding() {
        hasSeenOnboarding = false
        signOut()
    }
    
    // MARK: - Helper Methods
    private func clearStoredAuth() {
        userDefaults.removeObject(forKey: lastUserEmailKey)
        userDefaults.removeObject(forKey: firebaseTokenKey)
        userDefaults.removeObject(forKey: firebaseUserIdKey)
    }
}