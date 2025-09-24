import SwiftUI
import Foundation

// MARK: - Simplified Authentication Manager (No Firebase)
@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private init() {
        // Automatically sign in as a guest user
        signInAsGuest()
    }
    
    private func signInAsGuest() {
        isLoading = true
        
        // Create a default guest user using the correct initializers
        let guestProfile = UserProfile(
            fullName: "Guest",
            healthGoals: [.improveHealth]
        )
        
        let guestPreferences = UserPreferences(
            dailyCalorieGoal: 2000,
            dailyProteinGoal: 150,
            dailyCarbGoal: 250,
            dailyFatGoal: 70,
            dailyFiberGoal: 25,
            dailySodiumLimit: 2300
        )

        let guestUser = User(
            id: "guest-user",
            profile: guestProfile,
            preferences: guestPreferences
        )
        
        self.currentUser = guestUser
        self.isAuthenticated = true
        self.isLoading = false
        
        print("✅ Signed in as guest user")
    }
    
    // MARK: - Sign Out (Placeholder)
    func signOut() {
        // In a non-guest setup, you would clear user data here
        // For now, we'll just re-authenticate as guest
        currentUser = nil
        isAuthenticated = false
        signInAsGuest()
    }
    
    // MARK: - Update User Profile (Placeholder)
    func updateUserProfile(_ profile: UserProfile, preferences: UserPreferences) async {
        guard var user = currentUser else { return }
        
        isLoading = true
        
        user.profile = profile
        user.preferences = preferences
        
        // Update local state
        currentUser = user
        
        isLoading = false
        print("✅ Updated guest user profile locally")
    }
}