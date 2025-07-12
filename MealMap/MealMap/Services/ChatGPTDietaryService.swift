import Foundation

// MARK: - ChatGPT API Models
struct ChatGPTRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let maxTokens: Int
    let temperature: Double
    let systemPrompt: String?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case systemPrompt = "system_prompt"
    }
}

struct ChatMessage: Codable, Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    var timestamp: Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case role, content, timestamp
    }
    
    init(role: MessageRole, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
}

struct ChatGPTResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let choices: [ChatChoice]
    let usage: TokenUsage?
    
    struct ChatChoice: Codable {
        let index: Int
        let message: ChatMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct TokenUsage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - Conversation Management
struct DietaryConversation: Identifiable, Codable {
    var id = UUID()
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    let userId: String
    var title: String
    
    init(userId: String, title: String = "New Conversation") {
        self.userId = userId
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()
    }
}

// MARK: - API Configuration
struct OpenAIConfiguration {
    static let baseURL = "https://api.openai.com/v1/chat/completions"
    static let model = "gpt-3.5-turbo"
    static let maxTokens = 800
    static let temperature = 0.7
}

// MARK: - ChatGPT Dietary Service
@MainActor
class ChatGPTDietaryService: ObservableObject {
    static let shared = ChatGPTDietaryService()
    
    @Published var conversations: [DietaryConversation] = []
    @Published var currentConversation: DietaryConversation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAPIKeySetup = false
    
    // API Key Management
    private let userDefaults = UserDefaults.standard
    private let apiKeyStorageKey = "OpenAI_API_Key"
    
    var isAPIKeyConfigured: Bool {
        return userAPIKey != nil && !userAPIKey!.isEmpty
    }
    
    var userAPIKey: String? {
        get {
            return userDefaults.string(forKey: apiKeyStorageKey)
        }
        set {
            if let newValue = newValue, !newValue.isEmpty {
                userDefaults.set(newValue, forKey: apiKeyStorageKey)
            } else {
                userDefaults.removeObject(forKey: apiKeyStorageKey)
            }
        }
    }
    
    // Usage Tracking
    @Published var dailyTokenUsage = 0
    private let dailyTokenLimit = 10000 // Reasonable limit for GPT-3.5
    
    private init() {
        loadConversations()
        if !isAPIKeyConfigured {
        }
    }
    
    // MARK: - API Key Management
    func saveAPIKey(_ apiKey: String) {
        userAPIKey = apiKey
        showingAPIKeySetup = false
    }
    
    func clearAPIKey() {
        userAPIKey = nil
    }
    
    func showAPIKeySetup() {
        showingAPIKeySetup = true
    }
    
    // MARK: - Conversation Management
    func startNewConversation(for user: User, title: String = "Dietary Chat") -> DietaryConversation {
        let conversation = DietaryConversation(userId: user.id, title: title)
        conversations.insert(conversation, at: 0)
        currentConversation = conversation
        saveConversations()
        return conversation
    }
    
    func selectConversation(_ conversation: DietaryConversation) {
        currentConversation = conversation
    }
    
    func deleteConversation(_ conversation: DietaryConversation) {
        conversations.removeAll { $0.id == conversation.id }
        if currentConversation?.id == conversation.id {
            currentConversation = conversations.first
        }
        saveConversations()
    }
    
    // MARK: - Chat Functionality
    func sendMessage(_ messageContent: String, user: User) async {
        guard isAPIKeyConfigured else {
            errorMessage = "OpenAI API key not configured"
            showingAPIKeySetup = true
            return
        }
        
        guard dailyTokenUsage < dailyTokenLimit else {
            errorMessage = "Daily token limit reached. Please try again tomorrow."
            return
        }
        
        // Create conversation if none exists
        if currentConversation == nil {
            currentConversation = startNewConversation(for: user)
        }
        
        guard var conversation = currentConversation else { return }
        
        // Add user message
        let userMessage = ChatMessage(role: .system, content: messageContent)
        conversation.addMessage(userMessage)
        currentConversation = conversation
        updateConversationInList(conversation)
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Generate system prompt with user context
            let systemPrompt = generateSystemPrompt(for: user)
            
            // Prepare messages for API
            var apiMessages: [ChatMessage] = [
                ChatMessage(role: .system, content: systemPrompt)
            ]
            
            // Add conversation history (last 10 messages to stay within token limits)
            let recentMessages = conversation.messages.suffix(10)
            apiMessages.append(contentsOf: recentMessages)
            
            // Call ChatGPT API
            let response = try await callChatGPTAPI(messages: apiMessages)
            
            if let assistantMessage = response.choices.first?.message {
                let responseMessage = ChatMessage(
                    role: .system,
                    content: assistantMessage.content
                )
                
                conversation.addMessage(responseMessage)
                currentConversation = conversation
                updateConversationInList(conversation)
                
                // Track token usage
                if let usage = response.usage {
                    dailyTokenUsage += usage.totalTokens
                }
            }
            
        } catch {
            errorMessage = "Failed to get response: \(error.localizedDescription)"
        }
        
        isLoading = false
        saveConversations()
    }
    
    // MARK: - Smart Context Generation
    private func generateSystemPrompt(for user: User) -> String {
        var prompt = """
        You are a knowledgeable and friendly nutritionist and dietary advisor. You're helping a user make informed food choices based on their specific dietary goals and restrictions.
        
        USER PROFILE:
        """
        
        // Add dietary restrictions
        if !user.profile.dietaryRestrictions.isEmpty {
            prompt += "\nDietary Restrictions: \(user.profile.dietaryRestrictions.map { $0.rawValue }.joined(separator: ", "))"
        }
        
        // Add health goals
        if !user.profile.healthGoals.isEmpty {
            prompt += "\nHealth Goals: \(user.profile.healthGoals.map { $0.rawValue }.joined(separator: ", "))"
        }
        
        // Add nutrition targets
        prompt += """
        \nDaily Nutrition Targets:
        - Calories: \(user.preferences.dailyCalorieGoal) kcal
        - Protein: \(user.preferences.dailyProteinGoal)g
        - Carbohydrates: \(user.preferences.dailyCarbGoal)g
        - Fat: \(user.preferences.dailyFatGoal)g
        - Fiber: \(user.preferences.dailyFiberGoal)g
        - Sodium Limit: \(user.preferences.dailySodiumLimit)mg
        """
        
        // Add activity level
        prompt += "\nActivity Level: \(user.profile.activityLevel.rawValue)"
        
        // Add guidelines
        prompt += """
        
        GUIDELINES:
        - Always consider the user's specific dietary restrictions and health goals
        - Provide practical, actionable advice
        - Suggest specific foods, restaurants, or menu modifications when relevant
        - Be encouraging and supportive
        - If asked about specific menu items, provide detailed nutritional analysis
        - Suggest alternatives that align with their goals
        - Keep responses conversational but informative (max 150 words)
        - Reference their specific targets when giving advice
        """
        
        return prompt
    }
    
    // MARK: - Menu Item Context
    func chatAboutMenuItem(_ item: AnalyzedMenuItem, user: User) async {
        let menuContext = """
        I'm looking at this menu item: "\(item.name)"
        
        Description: \(item.description ?? "No description available")
        Price: \(item.price ?? "Not specified")
        
        Nutrition (estimated):
        - Calories: \(item.nutritionEstimate.calories.displayString)
        - Protein: \(item.nutritionEstimate.protein.displayString)
        - Carbs: \(item.nutritionEstimate.carbs.displayString)
        - Fat: \(item.nutritionEstimate.fat.displayString)
        \(item.nutritionEstimate.fiber != nil ? "- Fiber: \(item.nutritionEstimate.fiber!.displayString)" : "")
        \(item.nutritionEstimate.sodium != nil ? "- Sodium: \(item.nutritionEstimate.sodium!.displayString)" : "")
        
        How does this fit with my dietary goals? Any suggestions for modifications or alternatives?
        """
        
        await sendMessage(menuContext, user: user)
    }
    
    // MARK: - API Call
    private func callChatGPTAPI(messages: [ChatMessage]) async throws -> ChatGPTResponse {
        guard let apiKey = userAPIKey else {
            throw ChatGPTError.noAPIKey
        }
        
        guard let url = URL(string: OpenAIConfiguration.baseURL) else {
            throw ChatGPTError.invalidURL
        }
        
        // Prepare request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare request body
        let requestBody = [
            "model": OpenAIConfiguration.model,
            "messages": messages.map { [
                "role": $0.role.rawValue,
                "content": $0.content
            ]},
            "max_tokens": OpenAIConfiguration.maxTokens,
            "temperature": OpenAIConfiguration.temperature
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw ChatGPTError.invalidAPIKey
                }
                throw ChatGPTError.httpError(httpResponse.statusCode)
            }
        }
        
        // Parse response
        let chatResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
        return chatResponse
    }
    
    // MARK: - Persistence
    private func saveConversations() {
        if let data = try? JSONEncoder().encode(conversations) {
            userDefaults.set(data, forKey: "DietaryConversations")
        }
    }
    
    private func loadConversations() {
        if let data = userDefaults.data(forKey: "DietaryConversations"),
           let loadedConversations = try? JSONDecoder().decode([DietaryConversation].self, from: data) {
            conversations = loadedConversations
        }
    }
    
    private func updateConversationInList(_ updatedConversation: DietaryConversation) {
        if let index = conversations.firstIndex(where: { $0.id == updatedConversation.id }) {
            conversations[index] = updatedConversation
        }
    }
}

// MARK: - Error Handling
enum ChatGPTError: Error, LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidAPIKey
    case httpError(Int)
    case decodingError(Error)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidAPIKey:
            return "Invalid API key. Please check your OpenAI API key."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError:
            return "Network error occurred"
        }
    }
}