import Foundation
import SwiftUI

enum ScoreGrade: String, CaseIterable, Codable {
    case excellent = "Excellent"
    case veryGood = "Very Good"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case veryPoor = "Very Poor"
    
    var color: Color {
        switch self {
        case .excellent:
            return .green
        case .veryGood:
            return Color(red: 0.6, green: 0.8, blue: 0.2)
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return Color(red: 0.9, green: 0.5, blue: 0.1)
        case .veryPoor:
            return .red
        }
    }
    
    var emoji: String {
        switch self {
        case .excellent:
            return "🌟"
        case .veryGood:
            return "✅"
        case .good:
            return "👍"
        case .fair:
            return "😐"
        case .poor:
            return "👎"
        case .veryPoor:
            return "❌"
        }
    }
    
    var description: String {
        switch self {
        case .excellent:
            return "High in nutrients and low in less healthy components"
        case .veryGood:
            return "Generally healthy with minor drawbacks"
        case .good:
            return "Balanced mix of nutrients and less healthy components"
        case .fair:
            return "Some nutritional value but significant drawbacks"
        case .poor:
            return "Low in nutrients and high in unhealthy components"
        case .veryPoor:
            return "Very low in nutrients and high in very unhealthy components"
        }
    }
    
    static func fromScore(_ score: Double) -> ScoreGrade {
        switch score {
        case 90...:
            return .excellent
        case 80..<90:
            return .veryGood
        case 70..<80:
            return .good
        case 60..<70:
            return .fair
        case 50..<60:
            return .poor
        default:
            return .veryPoor
        }
    }
}