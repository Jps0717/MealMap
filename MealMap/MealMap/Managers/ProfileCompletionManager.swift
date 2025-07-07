import SwiftUI

@MainActor
class ProfileCompletionManager: ObservableObject {
    static let shared = ProfileCompletionManager()
    
    @Published var shouldShowProfilePrompt = false
    @Published var hasShownPromptThisSession = false
    
    private let userDefaults = UserDefaults.standard
    private let hasShownProfilePromptKey = "hasShownProfilePrompt"
    private let lastPromptTimeKey = "lastPromptTime"
    private let profileCompletedKey = "profileCompleted"
    
    private var reminderTimer: Timer?
    private let reminderInterval: TimeInterval = 35 * 60 // 35 minutes
    
    private init() {}
    
    func checkProfileCompletion(for user: User?) {
        guard let user = user else { return }
        
        let hasHealthGoals = !user.profile.healthGoals.isEmpty
        let hasDietaryRestrictions = !user.profile.dietaryRestrictions.isEmpty
        let hasBasicInfo = !user.profile.firstName.isEmpty || !user.profile.lastName.isEmpty
        
        let isProfileComplete = hasHealthGoals && hasDietaryRestrictions
        
        // Mark profile as completed if it is
        if isProfileComplete {
            userDefaults.set(true, forKey: profileCompletedKey)
            stopReminderTimer()
            return
        }
        
        // If profile is not complete, check if we should show prompt
        let profileCompleted = userDefaults.bool(forKey: profileCompletedKey)
        if !profileCompleted {
            checkAndShowPrompt()
            startReminderTimer()
        }
    }
    
    private func checkAndShowPrompt() {
        let lastPromptTime = userDefaults.double(forKey: lastPromptTimeKey)
        let currentTime = Date().timeIntervalSince1970
        
        // Show prompt if it's been more than 35 minutes since last prompt, or if never shown
        if lastPromptTime == 0 || (currentTime - lastPromptTime) >= reminderInterval {
            shouldShowProfilePrompt = true
        }
    }
    
    private func startReminderTimer() {
        // Stop any existing timer
        stopReminderTimer()
        
        // Start new timer for 35-minute intervals
        reminderTimer = Timer.scheduledTimer(withTimeInterval: reminderInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndShowPrompt()
            }
        }
    }
    
    private func stopReminderTimer() {
        reminderTimer?.invalidate()
        reminderTimer = nil
    }
    
    func markPromptAsShown() {
        hasShownPromptThisSession = true
        userDefaults.set(Date().timeIntervalSince1970, forKey: lastPromptTimeKey)
        shouldShowProfilePrompt = false
    }
    
    func dismissPrompt() {
        shouldShowProfilePrompt = false
        hasShownPromptThisSession = true
        userDefaults.set(Date().timeIntervalSince1970, forKey: lastPromptTimeKey)
    }
    
    func markProfileAsCompleted() {
        userDefaults.set(true, forKey: profileCompletedKey)
        stopReminderTimer()
        shouldShowProfilePrompt = false
    }
    
    func resetPromptStatus() {
        userDefaults.removeObject(forKey: hasShownProfilePromptKey)
        userDefaults.removeObject(forKey: lastPromptTimeKey)
        userDefaults.removeObject(forKey: profileCompletedKey)
        hasShownPromptThisSession = false
        stopReminderTimer()
    }
    
    deinit {
        reminderTimer?.invalidate()
    }
}