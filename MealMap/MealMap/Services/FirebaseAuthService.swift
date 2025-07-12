import Foundation

// MARK: - Firebase Authentication via REST API
class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    
    private let apiKey = "AIzaSyAKpkyvytO4kRE3TUhXc7Tamdin9poQyOA"
    private let projectId = "meal-map-c6d4e"
    
    // MARK: - Authentication State
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var idToken: String?
    @Published var refreshToken: String?
    
    private init() {
        // Load stored authentication state
        loadAuthenticationState()
    }
    
    // MARK: - Authentication State Management
    private func loadAuthenticationState() {
        if let storedToken = UserDefaults.standard.string(forKey: "firebase_id_token"),
           let storedRefreshToken = UserDefaults.standard.string(forKey: "firebase_refresh_token"),
           let userData = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            
            self.idToken = storedToken
            self.refreshToken = storedRefreshToken
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    private func saveAuthenticationState() {
        if let token = idToken {
            UserDefaults.standard.set(token, forKey: "firebase_id_token")
        }
        if let refreshToken = refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "firebase_refresh_token")
        }
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "current_user")
        }
        UserDefaults.standard.set(isAuthenticated, forKey: "is_authenticated")
    }
    
    private func clearAuthenticationState() {
        UserDefaults.standard.removeObject(forKey: "firebase_id_token")
        UserDefaults.standard.removeObject(forKey: "firebase_refresh_token")
        UserDefaults.standard.removeObject(forKey: "current_user")
        UserDefaults.standard.removeObject(forKey: "is_authenticated")
        
        idToken = nil
        refreshToken = nil
        currentUser = nil
        isAuthenticated = false
    }
    
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
            
            // Create user profile
            let user = User(
                id: authResponse.localId,
                email: authResponse.email,
                displayName: authResponse.email.components(separatedBy: "@").first ?? "User"
            )
            
            // Update authentication state
            await MainActor.run {
                self.idToken = authResponse.idToken
                self.refreshToken = authResponse.refreshToken
                self.currentUser = user
                self.isAuthenticated = true
                self.saveAuthenticationState()
            }
            
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
            
            // Create or load user profile
            let user = User(
                id: authResponse.localId,
                email: authResponse.email,
                displayName: authResponse.email.components(separatedBy: "@").first ?? "User"
            )
            
            // Update authentication state
            await MainActor.run {
                self.idToken = authResponse.idToken
                self.refreshToken = authResponse.refreshToken
                self.currentUser = user
                self.isAuthenticated = true
                self.saveAuthenticationState()
            }
            
            return authResponse
        } else {
            let errorResponse = try JSONDecoder().decode(FirebaseErrorResponse.self, from: data)
            throw FirebaseError.authError(errorResponse.error.message)
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        Task {
            await MainActor.run {
                clearAuthenticationState()
            }
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
    
    // MARK: - Update User Profile
    func updateUserProfile(_ user: User) {
        Task {
            await MainActor.run {
                self.currentUser = user
                self.saveAuthenticationState()
            }
        }
    }
    
    // MARK: - Refresh Token
    func refreshToken() async throws {
        guard let refreshToken = refreshToken else {
            throw FirebaseError.authError("No refresh token available")
        }
        
        let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(apiKey)")!
        
        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
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
            let tokenResponse = try JSONDecoder().decode(FirebaseTokenResponse.self, from: data)
            
            await MainActor.run {
                self.idToken = tokenResponse.idToken
                self.refreshToken = tokenResponse.refreshToken
                self.saveAuthenticationState()
            }
        } else {
            throw FirebaseError.authError("Token refresh failed")
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

struct FirebaseTokenResponse: Codable {
    let idToken: String
    let refreshToken: String
    let expiresIn: String
    let tokenType: String
    let projectId: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case projectId = "project_id"
        case userId = "user_id"
    }
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