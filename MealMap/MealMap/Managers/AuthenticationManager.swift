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
        // Use a safer initialization approach
        Task {
            await checkExistingAuthSafely()
        }
    }
    
    // MARK: - Safer authentication checking
    private func checkExistingAuthSafely() async {
        do {
            if let savedToken = userDefaults.string(forKey: firebaseTokenKey),
               let savedUserId = userDefaults.string(forKey: firebaseUserIdKey),
               let savedEmail = userDefaults.string(forKey: lastUserEmailKey) {
                
                // Try to load user from Firestore with timeout
                let user = try await withTimeout(3.0) {
                    try await self.firestoreService.getUser(userId: savedUserId, idToken: savedToken)
                }
                
                if let user = user {
                    self.currentUser = user
                    self.isAuthenticated = true
                } else {
                    // User document doesn't exist, create a basic user
                    let user = User(id: savedUserId, email: savedEmail, displayName: "User")
                    self.currentUser = user
                    self.isAuthenticated = true
                }
            }
        } catch {
            // Token might be expired or network issue, clear and require re-login
            print("⚠️ Auth check failed: \(error)")
            self.clearStoredAuth()
        }
    }
    
    // MARK: - Safe timeout wrapper
    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    struct TimeoutError: Error {}
    
    // MARK: - Sign Up with Firebase
    func signUp(email: String, password: String, displayName: String) async {
        guard !isLoading else { return } // Prevent multiple simultaneous requests
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create Firebase Auth account
            let authResponse = try await self.authService.signUp(email: email, password: password)
            
            // Create user object
            let user = User(
                id: authResponse.localId,
                email: authResponse.email,
                displayName: displayName
            )
            
            // Save to Firestore with timeout
            try await withTimeout(5.0) {
                try await self.firestoreService.createUser(user, idToken: authResponse.idToken)
            }
            
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
            } else if error is TimeoutError {
                errorMessage = "Request timed out. Please try again."
            } else {
                errorMessage = "Sign up failed: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Sign In with Firebase
    func signIn(email: String, password: String) async {
        guard !isLoading else { return } // Prevent multiple simultaneous requests
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Sign in with Firebase
            let authResponse = try await self.authService.signIn(email: email, password: password)
            
            // Load user from Firestore with timeout
            let user = try await withTimeout(5.0) {
                try await self.firestoreService.getUser(userId: authResponse.localId, idToken: authResponse.idToken)
            }
            
            if let user = user {
                currentUser = user
            } else {
                // Create basic user if document doesn't exist
                let user = User(id: authResponse.localId, email: authResponse.email, displayName: "User")
                currentUser = user
                try await withTimeout(5.0) {
                    try await self.firestoreService.createUser(user, idToken: authResponse.idToken)
                }
            }
            
            isAuthenticated = true
            
            // Store credentials
            userDefaults.set(authResponse.email, forKey: lastUserEmailKey)
            userDefaults.set(authResponse.idToken, forKey: firebaseTokenKey)
            userDefaults.set(authResponse.localId, forKey: firebaseUserIdKey)
            
        } catch {
            if let firebaseError = error as? FirebaseError {
                errorMessage = firebaseError.localizedDescription
            } else if error is TimeoutError {
                errorMessage = "Request timed out. Please try again."
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
        
        guard !isLoading else { return } // Prevent multiple simultaneous requests
        
        isLoading = true
        
        user.profile = profile
        user.preferences = preferences
        
        do {
            // Update in Firestore with timeout
            try await withTimeout(5.0) {
                try await self.firestoreService.updateUser(user, idToken: token)
            }
            
            // Update local state
            currentUser = user
        } catch {
            if error is TimeoutError {
                errorMessage = "Request timed out. Please try again."
            } else {
                errorMessage = "Failed to update profile: \(error.localizedDescription)"
            }
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