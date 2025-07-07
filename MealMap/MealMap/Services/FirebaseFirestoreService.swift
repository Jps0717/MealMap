import Foundation

// MARK: - Firebase Firestore via REST API
class FirebaseFirestoreService: ObservableObject {
    static let shared = FirebaseFirestoreService()
    
    private let projectId = "meal-map-c6d4e"
    private let baseURL = "https://firestore.googleapis.com/v1/projects/meal-map-c6d4e/databases/(default)/documents"
    
    // MARK: - Create User Document
    func createUser(_ user: User, idToken: String) async throws {
        let url = URL(string: "\(baseURL)/users/\(user.id)")!
        
        let firestoreUser = FirestoreUser(
            email: FirestoreValue.string(user.email),
            displayName: FirestoreValue.string(user.displayName),
            createdAt: FirestoreValue.timestamp(user.createdAt.toFirestoreTimestamp()),
            dietaryRestrictions: FirestoreValue.array(user.profile.dietaryRestrictions.map { .string($0.rawValue) }),
            healthGoals: FirestoreValue.array(user.profile.healthGoals.map { .string($0.rawValue) }),
            firstName: FirestoreValue.string(user.profile.firstName),
            lastName: FirestoreValue.string(user.profile.lastName)
        )
        
        let body = [
            "fields": firestoreUser.toDictionary()
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirebaseError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw FirebaseError.networkError("Failed to create user document")
        }
    }
    
    // MARK: - Get User Document
    func getUser(userId: String, idToken: String) async throws -> User? {
        let url = URL(string: "\(baseURL)/users/\(userId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirebaseError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            return nil // User document doesn't exist
        }
        
        if httpResponse.statusCode == 200 {
            let firestoreDoc = try JSONDecoder().decode(FirestoreDocument.self, from: data)
            return firestoreDoc.toUser()
        } else {
            throw FirebaseError.networkError("Failed to get user document")
        }
    }
    
    // MARK: - Update User Document
    func updateUser(_ user: User, idToken: String) async throws {
        try await createUser(user, idToken: idToken) // Same as create for updates
    }
}

// MARK: - Firestore Data Models
struct FirestoreUser {
    let email: FirestoreValue
    let displayName: FirestoreValue
    let createdAt: FirestoreValue
    let dietaryRestrictions: FirestoreValue
    let healthGoals: FirestoreValue
    let firstName: FirestoreValue
    let lastName: FirestoreValue
    
    func toDictionary() -> [String: Any] {
        return [
            "email": email.toDictionary(),
            "displayName": displayName.toDictionary(),
            "createdAt": createdAt.toDictionary(),
            "dietaryRestrictions": dietaryRestrictions.toDictionary(),
            "healthGoals": healthGoals.toDictionary(),
            "firstName": firstName.toDictionary(),
            "lastName": lastName.toDictionary()
        ]
    }
}

enum FirestoreValue {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case timestamp(String)
    case array([FirestoreValue])
    
    func toDictionary() -> [String: Any] {
        switch self {
        case .string(let value):
            return ["stringValue": value]
        case .integer(let value):
            return ["integerValue": String(value)]
        case .double(let value):
            return ["doubleValue": value]
        case .boolean(let value):
            return ["booleanValue": value]
        case .timestamp(let value):
            return ["timestampValue": value]
        case .array(let values):
            return ["arrayValue": ["values": values.map { $0.toDictionary() }]]
        }
    }
}

struct FirestoreDocument: Codable {
    let name: String
    let fields: [String: FirestoreFieldValue]
    let createTime: String
    let updateTime: String
    
    func toUser() -> User {
        let id = String(name.split(separator: "/").last ?? "")
        let email = fields["email"]?.stringValue ?? ""
        let displayName = fields["displayName"]?.stringValue ?? ""
        let _ = Date() // TODO: Parse timestamp - replaced unused variable
        
        var user = User(id: id, email: email, displayName: displayName)
        
        // Update profile
        user.profile.firstName = fields["firstName"]?.stringValue ?? ""
        user.profile.lastName = fields["lastName"]?.stringValue ?? ""
        
        // Parse dietary restrictions
        if let dietaryArray = fields["dietaryRestrictions"]?.arrayValue?.values {
            user.profile.dietaryRestrictions = dietaryArray.compactMap { fieldValue in
                guard let stringValue = fieldValue.stringValue else { return nil }
                return DietaryRestriction(rawValue: stringValue)
            }
        }
        
        // Parse health goals
        if let goalsArray = fields["healthGoals"]?.arrayValue?.values {
            user.profile.healthGoals = goalsArray.compactMap { fieldValue in
                guard let stringValue = fieldValue.stringValue else { return nil }
                return HealthGoal(rawValue: stringValue)
            }
        }
        
        return user
    }
}

struct FirestoreFieldValue: Codable {
    let stringValue: String?
    let integerValue: String?
    let doubleValue: Double?
    let booleanValue: Bool?
    let timestampValue: String?
    let arrayValue: FirestoreArrayValue?
}

struct FirestoreArrayValue: Codable {
    let values: [FirestoreFieldValue]?
}

// MARK: - Date Extensions
extension Date {
    func toFirestoreTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}