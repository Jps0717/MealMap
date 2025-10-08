import Foundation

// MARK: - Simplified estimation enums for backward compatibility

enum EstimationSource: String, Codable, CaseIterable {
    case database = "database"
    case fallback = "fallback"
    case unavailable = "unavailable"
    
    var displayName: String {
        switch self {
        case .database: return "Database"
        case .fallback: return "Fallback"
        case .unavailable: return "Unavailable"
        }
    }
    
    var confidence: Double {
        switch self {
        case .database: return 0.95
        case .fallback: return 0.75
        case .unavailable: return 0.0
        }
    }
}

enum EstimationTier: String, Codable, CaseIterable {
    case database = "database"
    case fallback = "fallback" 
    case unavailable = "unavailable"
    
    var displayName: String {
        switch self {
        case .database: return "Database"
        case .fallback: return "Fallback"
        case .unavailable: return "Unavailable"
        }
    }
    
    var confidence: Double {
        switch self {
        case .database: return 0.95
        case .fallback: return 0.75
        case .unavailable: return 0.0
        }
    }
}