import Foundation

// MARK: - Firebase Authentication via REST API
class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    
    private let apiKey = "AIzaSyAKpkyvytO4kRE3TUhXc7Tamdin9poQyOA"
    private let projectId = "meal-map-c6d4e"
    
    // MARK: - Sign Up
    func signUp(email: String, password: String) async throws -> FirebaseAuthResponse {
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)")!
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirebaseError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(FirebaseAuthResponse.self, from: data)
            return authResponse
        } else {
            let errorResponse = try JSONDecoder().decode(FirebaseErrorResponse.self, from: data)
            throw FirebaseError.authError(errorResponse.error.message)
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws -> FirebaseAuthResponse {
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)")!
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirebaseError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(FirebaseAuthResponse.self, from: data)
            return authResponse
        } else {
            let errorResponse = try JSONDecoder().decode(FirebaseErrorResponse.self, from: data)
            throw FirebaseError.authError(errorResponse.error.message)
        }
    }
    
    // MARK: - Get User Info
    func getUserInfo(idToken: String) async throws -> FirebaseUserInfo {
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=\(apiKey)")!
        
        let body: [String: Any] = [
            "idToken": idToken
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirebaseError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let userResponse = try JSONDecoder().decode(FirebaseUserResponse.self, from: data)
            guard let user = userResponse.users.first else {
                throw FirebaseError.userNotFound
            }
            return user
        } else {
            throw FirebaseError.invalidResponse
        }
    }
}

// MARK: - Firebase Data Models
struct FirebaseAuthResponse: Codable {
    let idToken: String
    let email: String
    let refreshToken: String
    let expiresIn: String
    let localId: String
    let registered: Bool?
}

struct FirebaseUserInfo: Codable {
    let localId: String
    let email: String
    let emailVerified: Bool
    let displayName: String?
    let providerUserInfo: [ProviderUserInfo]
    let photoUrl: String?
    let passwordHash: String?
    let passwordUpdatedAt: Double?
    let validSince: String?
    let disabled: Bool?
    let lastLoginAt: String?
    let createdAt: String?
    let customAuth: Bool?
}

struct ProviderUserInfo: Codable {
    let providerId: String
    let displayName: String?
    let photoUrl: String?
    let federatedId: String
    let email: String?
    let rawId: String
    let screenName: String?
}

struct FirebaseUserResponse: Codable {
    let users: [FirebaseUserInfo]
}

struct FirebaseErrorResponse: Codable {
    let error: FirebaseErrorDetail
}

struct FirebaseErrorDetail: Codable {
    let code: Int
    let message: String
    let errors: [FirebaseErrorItem]?
}

struct FirebaseErrorItem: Codable {
    let message: String
    let domain: String
    let reason: String
}

// MARK: - Firebase Errors
enum FirebaseError: Error, LocalizedError {
    case invalidResponse
    case authError(String)
    case userNotFound
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Firebase"
        case .authError(let message):
            return message
        case .userNotFound:
            return "User not found"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}