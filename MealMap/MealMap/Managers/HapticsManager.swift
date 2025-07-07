import UIKit

final class HapticsManager {
    static let shared = HapticsManager()
    
    private init() {}
    
    // MARK: - Impact Feedback
    func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Notification Feedback
    func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - Custom Convenience Methods
    func buttonTap() {
        lightImpact()
    }
    
    func navigationTap() {
        mediumImpact()
    }
    
    func cardTap() {
        lightImpact()
    }
    
    func toggleChange() {
        selection()
    }
    
    func pullRefresh() {
        mediumImpact()
    }
    
    func longPress() {
        heavyImpact()
    }
    
    func deleteAction() {
        mediumImpact()
    }
    
    func saveAction() {
        success()
    }
}