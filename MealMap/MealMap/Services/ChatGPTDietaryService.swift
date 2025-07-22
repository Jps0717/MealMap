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

// MARK: - AI Memory System
struct UserAIMemory: Codable {
    let userId: String
    var userProfile: UserProfile
    var userPreferences: UserPreferences
    var conversationHistory: [ConversationSummary]
    var personalizedInsights: [PersonalizedInsight]
    var favoriteRestaurants: [String] // Restaurant names
    var preferredMeals: [String] // Menu items the user likes
    var lastUpdated: Date
    
    init(user: User) {
        self.userId = user.id
        self.userProfile = user.profile
        self.userPreferences = user.preferences
        self.conversationHistory = []
        self.personalizedInsights = []
        self.favoriteRestaurants = []
        self.preferredMeals = []
        self.lastUpdated = Date()
    }
    
    mutating func updateUserData(_ user: User) {
        self.userProfile = user.profile
        self.userPreferences = user.preferences
        self.lastUpdated = Date()
    }
    
    mutating func addConversationSummary(_ summary: ConversationSummary) {
        conversationHistory.append(summary)
        // Keep only last 50 conversation summaries
        if conversationHistory.count > 50 {
            conversationHistory.removeFirst()
        }
        self.lastUpdated = Date()
    }
    
    mutating func addInsight(_ insight: PersonalizedInsight) {
        personalizedInsights.append(insight)
        // Keep only last 20 insights
        if personalizedInsights.count > 20 {
            personalizedInsights.removeFirst()
        }
        self.lastUpdated = Date()
    }
}

struct ConversationSummary: Codable {
    let date: Date
    let topic: String
    let keyPoints: [String]
    let userGoals: [String]
    let recommendations: [String]
}

struct PersonalizedInsight: Codable {
    let date: Date
    let category: InsightCategory
    let insight: String
    let actionItem: String?
}

enum InsightCategory: String, Codable, CaseIterable {
    case nutrition = "Nutrition"
    case restaurants = "Restaurants"
    case habits = "Eating Habits"
    case goals = "Health Goals"
    case preferences = "Food Preferences"
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
    static let model = "gpt-4o-mini"
    static let maxTokens = 1500
    static let temperature = 0.7
    
    // Use your API key here
    static let sharedAPIKey = "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"
}

// MARK: - AI Memory Manager
@MainActor
class AIMemoryManager: ObservableObject {
    static let shared = AIMemoryManager()
    
    @Published var userMemory: UserAIMemory?
    private let userDefaults = UserDefaults.standard
    private let memoryKey = "UserAIMemory_"
    
    private init() {
        // Load memory when initialized
    }
    
    func loadMemory(for user: User) {
        let key = memoryKey + user.id
        
        if let data = userDefaults.data(forKey: key),
           let memory = try? JSONDecoder().decode(UserAIMemory.self, from: data) {
            self.userMemory = memory
            print("✅ Loaded AI memory for user: \(user.profile.fullName)")
        } else {
            // Create new memory for user
            self.userMemory = UserAIMemory(user: user)
            saveMemory()
            print("🆕 Created new AI memory for user: \(user.profile.fullName)")
        }
    }
    
    func saveMemory() {
        guard let memory = userMemory else { return }
        
        let key = memoryKey + memory.userId
        
        if let data = try? JSONEncoder().encode(memory) {
            userDefaults.set(data, forKey: key)
            print("💾 Saved AI memory to local storage")
        } else {
            print("❌ Failed to save AI memory")
        }
    }
    
    func updateUserData(_ user: User) {
        userMemory?.updateUserData(user)
        saveMemory()
    }
    
    func addConversationSummary(topic: String, keyPoints: [String], recommendations: [String]) {
        let summary = ConversationSummary(
            date: Date(),
            topic: topic,
            keyPoints: keyPoints,
            userGoals: userMemory?.userProfile.healthGoals.map { $0.rawValue } ?? [],
            recommendations: recommendations
        )
        userMemory?.addConversationSummary(summary)
        saveMemory()
    }
    
    func addPersonalizedInsight(category: InsightCategory, insight: String, actionItem: String? = nil) {
        let personalizedInsight = PersonalizedInsight(
            date: Date(),
            category: category,
            insight: insight,
            actionItem: actionItem
        )
        userMemory?.addInsight(personalizedInsight)
        saveMemory()
    }
    
    func generateMemoryContext() -> String {
        guard let memory = userMemory else { return "" }
        
        var context = """
        
        USER MEMORY CONTEXT:
        ====================
        
        PERSONAL PROFILE:
        - Name: \(memory.userProfile.fullName.isEmpty ? "User" : memory.userProfile.fullName)
        """
        
        if let height = memory.userProfile.height, let weight = memory.userProfile.weight {
            context += "\n- Physical: \(height)\" tall, \(weight) lbs"
        }
        
        context += "\n- Activity Level: \(memory.userProfile.activityLevel.rawValue)"
        
        if !memory.userProfile.healthGoals.isEmpty {
            context += "\n- Goals: \(memory.userProfile.healthGoals.map { $0.rawValue }.joined(separator: ", "))"
        }
        
        if !memory.userProfile.dietaryRestrictions.isEmpty {
            context += "\n- Restrictions: \(memory.userProfile.dietaryRestrictions.map { $0.rawValue }.joined(separator: ", "))"
        }
        
        context += """
        
        NUTRITION TARGETS:
        - Daily Calories: \(memory.userPreferences.dailyCalorieGoal)
        - Protein: \(memory.userPreferences.dailyProteinGoal)g
        - Carbs: \(memory.userPreferences.dailyCarbGoal)g  
        - Fat: \(memory.userPreferences.dailyFatGoal)g
        - Fiber: \(memory.userPreferences.dailyFiberGoal)g
        - Sodium Limit: \(memory.userPreferences.dailySodiumLimit)mg
        """
        
        if !memory.favoriteRestaurants.isEmpty {
            context += "\n\nFAVORITE RESTAURANTS:\n- \(memory.favoriteRestaurants.joined(separator: "\n- "))"
        }
        
        if !memory.preferredMeals.isEmpty {
            context += "\n\nPREFERRED MEALS:\n- \(memory.preferredMeals.joined(separator: "\n- "))"
        }
        
        // Add recent conversation summaries
        let recentConversations = memory.conversationHistory.suffix(5)
        if !recentConversations.isEmpty {
            context += "\n\nRECENT CONVERSATION TOPICS:"
            for conv in recentConversations {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                context += "\n- \(formatter.string(from: conv.date)): \(conv.topic)"
                if !conv.recommendations.isEmpty {
                    context += "\n  Recommendations: \(conv.recommendations.joined(separator: ", "))"
                }
            }
        }
        
        // Add recent insights
        let recentInsights = memory.personalizedInsights.suffix(3)
        if !recentInsights.isEmpty {
            context += "\n\nRECENT INSIGHTS:"
            for insight in recentInsights {
                context += "\n- [\(insight.category.rawValue)] \(insight.insight)"
            }
        }
        
        context += "\n===================="
        
        return context
    }
}

// MARK: - ChatGPT Dietary Service
@MainActor
class ChatGPTDietaryService: ObservableObject {
    static let shared = ChatGPTDietaryService()
    
    @Published var conversations: [DietaryConversation] = []
    @Published var currentConversation: DietaryConversation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Memory system
    private let aiMemory = AIMemoryManager.shared
    
    // API key is always configured now with the shared key
    var isAPIKeyConfigured: Bool {
        return true
    }
    
    @Published var dailyTokenUsage = 0
    private let dailyTokenLimit = 50000
    
    private init() {
        loadConversations()
    }
    
    func initializeForUser(_ user: User) {
        // Load user's AI memory
        aiMemory.loadMemory(for: user)
        
        // Update memory with current user data to ensure it's always fresh
        aiMemory.updateUserData(user)
        
        print("🧠 AI Memory initialized for \(user.profile.fullName)")
        print("📊 Nutrition Goals: \(user.preferences.dailyCalorieGoal) kcal, \(user.preferences.dailyProteinGoal)g protein")
    }
    
    private func generateEnhancedCustomGPTPrompt(for user: User) -> String {
        // Update memory with latest user data
        aiMemory.updateUserData(user)
        
        var prompt = """
        You are the Meal Map AI assistant - a specialized nutritionist and dietary advisor with PERFECT MEMORY of this user.
        
        MEAL MAP CONTEXT:
        - You are integrated into a restaurant discovery app that shows nearby restaurants with nutrition data
        - Users can ask about restaurant nutrition facts, healthy menu suggestions, or meal options
        - You help with counting calories, managing dietary needs, and making informed food choices
        - You remember EVERYTHING about this user from previous conversations
        """
        
        // Add the user's memory context
        prompt += aiMemory.generateMemoryContext()
        
        prompt += """
        
        MEMORY INSTRUCTIONS:
        - Reference previous conversations naturally ("Last time we talked about...")
        - Remember their preferences, restrictions, and goals
        - Build on previous recommendations
        - Track their progress toward goals
        - Suggest restaurants and meals based on their history
        - Be encouraging about their journey
        
        RESPONSE STYLE:
        - Personal and conversational (use their name when appropriate)
        - Reference their specific situation and history
        - Provide actionable, restaurant-specific advice
        - Keep responses 150-250 words for mobile readability
        - Always consider their current goals and restrictions
        
        Remember: You have a perfect memory of this user's journey, preferences, and our entire conversation history.
        """
        
        return prompt
    }
    
    func sendMessage(_ messageContent: String, user: User) async {
        print("🤖 DEBUG: sendMessage called with: '\(messageContent)'")
        
        // Ensure memory is initialized
        if aiMemory.userMemory?.userId != user.id {
            aiMemory.loadMemory(for: user)
        }
        
        guard dailyTokenUsage < dailyTokenLimit else {
            errorMessage = "Daily token limit reached. Please try again tomorrow."
            return
        }
        
        if currentConversation == nil {
            currentConversation = startNewConversation(for: user)
        }
        
        guard var conversation = currentConversation else { 
            print("❌ No conversation available")
            return 
        }
        
        let userMessage = ChatMessage(role: .user, content: messageContent)
        conversation.addMessage(userMessage)
        currentConversation = conversation
        updateConversationInList(conversation)
        
        isLoading = true
        errorMessage = nil
        
        print("🤖 Starting enhanced AI call with memory for: \(user.profile.fullName)")
        
        // Use enhanced prompt with memory
        await sendMessageWithMemory(messageContent, user: user, conversation: conversation)
        
        isLoading = false
        saveConversations()
    }
    
    private func sendMessageWithMemory(_ message: String, user: User, conversation: DietaryConversation) async {
        let apiKey = "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"
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            await MainActor.run {
                self.errorMessage = "Invalid API URL"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        // Build messages with enhanced memory context
        var messages: [[String: String]] = []
        
        // System prompt with memory
        let enhancedSystemPrompt = generateEnhancedCustomGPTPrompt(for: user)
        messages.append(["role": "system", "content": enhancedSystemPrompt])
        
        // Add recent conversation context (last 6 messages for context)
        let recentMessages = conversation.messages.suffix(6)
        for msg in recentMessages {
            messages.append([
                "role": msg.role.rawValue,
                "content": msg.content
            ])
        }
        
        let requestBody = [
            "model": "gpt-3.5-turbo",
            "messages": messages,
            "max_tokens": 600,
            "temperature": 0.7
        ] as [String: Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("🤖 Request with memory context created")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🤖 HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let aiMessage = firstChoice["message"] as? [String: Any],
                       let content = aiMessage["content"] as? String {
                        
                        let assistantMessage = ChatMessage(role: .assistant, content: content.trimmingCharacters(in: .whitespacesAndNewlines))
                        
                        await MainActor.run {
                            var updatedConversation = self.currentConversation
                            updatedConversation?.addMessage(assistantMessage)
                            self.currentConversation = updatedConversation
                            if let conv = updatedConversation {
                                self.updateConversationInList(conv)
                            }
                            print("✅ Successfully added AI response with memory")
                        }
                        
                        // Extract and save insights from the conversation
                        await extractAndSaveInsights(userMessage: message, aiResponse: content, user: user)
                        
                        return
                    }
                } else {
                    let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ API Error \(httpResponse.statusCode): \(errorBody)")
                    await MainActor.run {
                        self.errorMessage = "API Error \(httpResponse.statusCode): \(errorBody)"
                    }
                }
            }
            
        } catch {
            print("❌ Network/JSON error: \(error)")
            await MainActor.run {
                self.errorMessage = "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    private func extractAndSaveInsights(userMessage: String, aiResponse: String, user: User) async {
        // Extract key information to save as insights
        let userLower = userMessage.lowercased()
        
        // Detect conversation topics and save relevant insights
        if userLower.contains("mcdonald") || userLower.contains("burger king") || userLower.contains("restaurant") {
            aiMemory.addPersonalizedInsight(
                category: .restaurants,
                insight: "User asked about fast food options",
                actionItem: "Continue providing healthier fast food alternatives"
            )
        }
        
        if userLower.contains("weight loss") || userLower.contains("lose weight") {
            aiMemory.addPersonalizedInsight(
                category: .goals,
                insight: "User is focused on weight loss goals",
                actionItem: "Prioritize lower calorie, high satiety recommendations"
            )
        }
        
        if userLower.contains("protein") || userLower.contains("muscle") {
            aiMemory.addPersonalizedInsight(
                category: .nutrition,
                insight: "User is interested in high-protein options",
                actionItem: "Emphasize protein-rich menu items and restaurants"
            )
        }
        
        // Save conversation summary
        let topic = extractTopicFromMessage(userMessage)
        let recommendations = extractRecommendationsFromAI(aiResponse)
        
        aiMemory.addConversationSummary(
            topic: topic,
            keyPoints: [userMessage],
            recommendations: recommendations
        )
    }
    
    private func extractTopicFromMessage(_ message: String) -> String {
        let lower = message.lowercased()
        
        if lower.contains("mcdonald") { return "McDonald's nutrition advice" }
        if lower.contains("weight loss") { return "Weight loss guidance" }
        if lower.contains("protein") { return "Protein recommendations" }
        if lower.contains("vegetarian") || lower.contains("vegan") { return "Plant-based options" }
        if lower.contains("keto") || lower.contains("low carb") { return "Low-carb meal planning" }
        if lower.contains("restaurant") { return "Restaurant recommendations" }
        
        return "General nutrition advice"
    }
    
    private func extractRecommendationsFromAI(_ response: String) -> [String] {
        // Simple extraction - look for key recommendations
        var recommendations: [String] = []
        
        let sentences = response.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("recommend") || trimmed.contains("suggest") || trimmed.contains("try") {
                recommendations.append(trimmed)
            }
        }
        
        return Array(recommendations.prefix(3)) // Keep top 3 recommendations
    }
    
    // MARK: - Conversation Management
    func startNewConversation(for user: User, title: String = "Meal Map Chat") -> DietaryConversation {
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
    
    private func saveConversations() {
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: "DietaryConversations")
        }
    }
    
    private func loadConversations() {
        if let data = UserDefaults.standard.data(forKey: "DietaryConversations"),
           let loadedConversations = try? JSONDecoder().decode([DietaryConversation].self, from: data) {
            conversations = loadedConversations
        }
    }
    
    private func updateConversationInList(_ updatedConversation: DietaryConversation) {
        if let index = conversations.firstIndex(where: { $0.id == updatedConversation.id }) {
            conversations[index] = updatedConversation
        }
    }
    
    func testAPIConnection() async {
        print("🧪 Testing OpenAI API connection...")
        
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(OpenAIConfiguration.sharedAPIKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🧪 API Test - Status Code: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🧪 API Test - Response: \(responseString.prefix(200))...")
            }
            
        } catch {
            print("❌ API Test Failed: \(error)")
        }
    }
    
    func chatAboutMenuItem(_ item: AnalyzedMenuItem, user: User) async {
        let menuContext = """
        I'm looking at this menu item and need your advice:
        
        MENU ITEM: "\(item.name)"
        \(item.description.map { "Description: \($0)" } ?? "")
        \(item.price.map { "Price: \($0)" } ?? "")
        
        NUTRITION INFO:
        • Calories: \(item.nutritionEstimate.calories.displayString)
        • Protein: \(item.nutritionEstimate.protein.displayString)
        • Carbs: \(item.nutritionEstimate.carbs.displayString)
        • Fat: \(item.nutritionEstimate.fat.displayString)
        \(item.nutritionEstimate.fiber.map { "• Fiber: \($0.displayString)" } ?? "")
        \(item.nutritionEstimate.sodium.map { "• Sodium: \($0.displayString)" } ?? "")
        
        Questions:
        1. How does this fit with my daily nutrition goals?
        2. Any suggestions for modifications to make it healthier?
        3. What would be better alternatives if this doesn't work?
        """
        
        await sendMessage(menuContext, user: user)
    }
}

// MARK: - Test Message Types for Custom GPT Testing
enum TestMessageType: CaseIterable {
    case greeting
    case menuAdvice
    case nutritionQuery
    case dietaryRestriction
    case calorieCount
    
    var message: String {
        switch self {
        case .greeting:
            return "Hi! I'm looking for healthy restaurant options near me. Can you help?"
        case .menuAdvice:
            return "I'm at McDonald's - what's the healthiest thing I can order that fits my goals?"
        case .nutritionQuery:
            return "How many calories are in a Big Mac and fries? Does it fit my daily targets?"
        case .dietaryRestriction:
            return "I'm vegetarian and trying to get more protein. What restaurants should I look for?"
        case .calorieCount:
            return "I have 600 calories left for dinner. What are some good options?"
        }
    }
    
    var title: String {
        switch self {
        case .greeting:
            return "General Greeting"
        case .menuAdvice:
            return "Menu Advice"
        case .nutritionQuery:
            return "Nutrition Query"
        case .dietaryRestriction:
            return "Dietary Restriction"
        case .calorieCount:
            return "Calorie Planning"
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