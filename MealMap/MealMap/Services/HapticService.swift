import UIKit

class HapticService {
    static let shared = HapticService()
    
    private init() {}
    
    // MARK: - Impact Haptics
    
    /// Light impact for subtle interactions (button taps, toggles)
    func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    /// Medium impact for moderate interactions (selection, navigation)
    func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    /// Heavy impact for significant interactions (confirmation, completion)
    func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Notification Haptics
    
    /// Success haptic for positive feedback
    func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// Warning haptic for cautionary feedback
    func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// Error haptic for negative feedback
    func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Selection Haptics
    
    /// Selection changed haptic for picker/segmented controls
    func selectionChanged() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - Custom Interaction Haptics
    
    /// Card tap haptic
    func cardTap() {
        lightImpact()
    }
    
    /// Button press haptic
    func buttonPress() {
        mediumImpact()
    }
    
    /// Menu scan haptic
    func menuScan() {
        heavyImpact()
    }
    
    /// Profile completion haptic
    func profileComplete() {
        success()
    }
    
    /// Navigation haptic
    func navigate() {
        mediumImpact()
    }
    
    /// Sheet presentation haptic
    func sheetPresent() {
        lightImpact()
    }
    
    /// Sheet dismissal haptic
    func sheetDismiss() {
        lightImpact()
    }
    
    /// Toggle haptic
    func toggle() {
        selectionChanged()
    }
    
    /// Delete/remove haptic
    func delete() {
        warning()
    }
    
    /// Add/create haptic
    func create() {
        success()
    }
    
    /// Search haptic
    func search() {
        lightImpact()
    }
    
    /// Filter applied haptic
    func filterApplied() {
        mediumImpact()
    }
    
    /// Data loading complete haptic
    func loadingComplete() {
        lightImpact()
    }
}