import Foundation

// MARK: - User Data Models
struct User: Identifiable, Codable {
    let id: String
    let email: String
    let displayName: String
    var profile: UserProfile
    var preferences: UserPreferences
    let createdAt: Date
    
    init(id: String, email: String, displayName: String) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.profile = UserProfile()
        self.preferences = UserPreferences()
        self.createdAt = Date()
    }
    
    init(id: String, profile: UserProfile, preferences: UserPreferences) {
        self.id = id
        self.email = ""
        self.displayName = ""
        self.profile = profile
        self.preferences = preferences
        self.createdAt = Date()
    }
}

extension User {
    /// Creates a default user for guests who aren't signed in
    static func defaultUser() -> User {
        let defaultProfile = UserProfile(
            fullName: "Guest User",
            height: 68, // 5'8"
            weight: 150,
            activityLevel: .moderate,
            dietaryRestrictions: [],
            healthGoals: [.maintainWeight]
        )
        
        let defaultPreferences = UserPreferences(
            dailyCalorieGoal: 2000,
            dailyProteinGoal: 100,
            dailyCarbGoal: 250,
            dailyFatGoal: 67,
            dailyFiberGoal: 25,
            dailySodiumLimit: 2300
        )
        
        return User(
            id: "guest-user",
            profile: defaultProfile,
            preferences: defaultPreferences
        )
    }
}

// MARK: - User Profile
struct UserProfile: Codable {
    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date?
    var height: Int? // inches
    var weight: Int? // pounds
    var activityLevel: ActivityLevel = .moderate
    var healthGoals: [HealthGoal] = []
    var dietaryRestrictions: [DietaryRestriction] = []
    
    var fullName: String {
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    init(
        fullName: String = "",
        height: Int? = nil,
        weight: Int? = nil,
        activityLevel: ActivityLevel = .moderate,
        dietaryRestrictions: [DietaryRestriction] = [],
        healthGoals: [HealthGoal] = []
    ) {
        let names = fullName.components(separatedBy: " ")
        if names.count >= 2 {
            self.firstName = names.first ?? ""
            self.lastName = names.last ?? ""
        } else {
            self.firstName = fullName
            self.lastName = ""
        }
        
        self.height = height
        self.weight = weight
        self.activityLevel = activityLevel
        self.healthGoals = healthGoals
        self.dietaryRestrictions = dietaryRestrictions
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    // Nutrition Goals
    var dailyCalorieGoal: Int = 2000
    var dailyProteinGoal: Int = 150 // grams
    var dailyCarbGoal: Int = 250 // grams
    var dailyFatGoal: Int = 65 // grams
    var dailyFiberGoal: Int = 25 // grams
    var dailySodiumLimit: Int = 2300 // mg
    
    // Dietary Restriction Thresholds
    var lowCarbThreshold: Double = 30     // grams (default)
    var lowSodiumThreshold: Double = 500  // mg (default)
    var diabeticFriendlyCarbThreshold: Double = 30 // grams (default)
    
    // App Preferences
    var enableNotifications: Bool = true
    var enableLocationTracking: Bool = true
    var preferredUnits: MeasurementUnit = .imperial
    var searchRadius: Double = 5.0 // miles
    
    // Privacy
    var shareDataWithFriends: Bool = false
    var allowAnalytics: Bool = true
    
    init(
        dailyCalorieGoal: Int = 2000,
        dailyProteinGoal: Int = 150,
        dailyCarbGoal: Int = 250,
        dailyFatGoal: Int = 65,
        dailyFiberGoal: Int = 25,
        dailySodiumLimit: Int = 2300
    ) {
        self.dailyCalorieGoal = dailyCalorieGoal
        self.dailyProteinGoal = dailyProteinGoal
        self.dailyCarbGoal = dailyCarbGoal
        self.dailyFatGoal = dailyFatGoal
        self.dailyFiberGoal = dailyFiberGoal
        self.dailySodiumLimit = dailySodiumLimit
    }
}

enum MeasurementUnit: String, Codable {
    case imperial = "Imperial"
    case metric = "Metric"
}

struct UserNotificationSettings: Codable {
    var enablePushNotifications: Bool = true
    var enableEmailNotifications: Bool = false
    
    init() {}
}

// MARK: - Supporting Enums
enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary = "Sedentary"
    case light = "Lightly Active"
    case moderate = "Moderately Active"
    case very = "Very Active"
    case extreme = "Extremely Active"
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .very: return 1.725
        case .extreme: return 1.9
        }
    }
}

enum HealthGoal: String, CaseIterable, Codable {
    case weightLoss = "Weight Loss"
    case weightGain = "Weight Gain"
    case maintainWeight = "Maintain Weight"
    case buildMuscle = "Build Muscle"
    case improveHealth = "Improve Health"
    case increaseEnergy = "Increase Energy"
    
    var emoji: String {
        switch self {
        case .weightLoss: return "📉"
        case .weightGain: return "📈"
        case .maintainWeight: return "⚖️"
        case .buildMuscle: return "💪"
        case .improveHealth: return "❤️"
        case .increaseEnergy: return "⚡"
        }
    }
}

enum DietaryRestriction: String, CaseIterable, Codable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case glutenFree = "Gluten-Free"
    case dairyFree = "Dairy-Free"
    case nutFree = "Nut-Free"
    case lowCarb = "Low Carb"
    case keto = "Keto"
    case paleo = "Paleo"
    case lowSodium = "Low Sodium"
    case diabetic = "Diabetic-Friendly"
    
    var emoji: String {
        switch self {
        case .vegetarian: return "🥬"
        case .vegan: return "🌱"
        case .glutenFree: return "🌾"
        case .dairyFree: return "🥛"
        case .nutFree: return "🥜"
        case .lowCarb: return "🥩"
        case .keto: return "🧈"
        case .paleo: return "🦴"
        case .lowSodium: return "🧂"
        case .diabetic: return "🍎"
        }
    }
}