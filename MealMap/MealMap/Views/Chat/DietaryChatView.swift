import SwiftUI

struct DietaryChatView: View {
    @StateObject private var chatService = ChatGPTDietaryService.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Optional item to start chat with
    var initialItem: AnalyzedMenuItem?
    
    @State private var messageText = ""
    @State private var showingAPIKeySetup = false
    @State private var scrollToBottom = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat Messages
                if let conversation = chatService.currentConversation {
                    chatMessagesView(conversation: conversation)
                } else {
                    emptyChatView
                }
                
                // Message Input - only show if authenticated AND API key is configured
                if authManager.isAuthenticated && chatService.isAPIKeyConfigured {
                    messageInputView
                } else if authManager.isAuthenticated && !chatService.isAPIKeyConfigured {
                    // Show API key required prompt for signed-in users
                    apiKeyRequiredPrompt
                } else {
                    // Show sign-in prompt for non-authenticated users
                    authenticationPrompt
                }
            }
            .navigationTitle("Dietary Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                // Only show menu with API settings if user is authenticated
                if authManager.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("New Conversation") {
                                startNewConversation()
                            }
                            
                            Button("API Settings") {
                                showingAPIKeySetup = true
                            }
                            
                            if !chatService.conversations.isEmpty {
                                Divider()
                                ForEach(chatService.conversations.prefix(5)) { conversation in
                                    Button(conversation.title) {
                                        chatService.selectConversation(conversation)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAPIKeySetup) {
            // Only show API key setup if user is authenticated
            if authManager.isAuthenticated {
                OpenAIAPIKeySetupView()
            }
        }
        .onAppear {
            setupInitialConversation()
            
            // Chat about initial item if provided
            if let item = initialItem {
                chatAboutInitialItem(item)
            }
        }
        .onChange(of: chatService.currentConversation?.messages.count) { _, _ in
            scrollToBottomOfChat()
        }
    }
    
    // MARK: - No Network View has been removed, and location access view has been removed
    
    private var emptyChatView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "message.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("Welcome to Dietary Chat!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Get personalized nutrition advice based on your dietary goals and restrictions.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Only show API key warning in empty chat if user is authenticated but no API key
            if authManager.isAuthenticated && !chatService.isAPIKeyConfigured {
                VStack(spacing: 16) {
                    Text("⚠️ OpenAI API Key Required")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Button("Setup API Key") {
                        showingAPIKeySetup = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    // MARK: - API Key Required Prompt (for authenticated users only)
    private var apiKeyRequiredPrompt: some View {
        VStack(spacing: 16) {
            Text("OpenAI API Key Required")
                .font(.headline)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
            
            Text("Configure your OpenAI API key to start chatting about nutrition and dietary advice.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Setup API Key") {
                showingAPIKeySetup = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding()
    }
    
    private var authenticationPrompt: some View {
        VStack(spacing: 16) {
            Text("Sign in to get personalized dietary advice")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Your dietary chat will be tailored to your specific goals and restrictions")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Sign In") {
                // Navigate to sign in - would typically use navigation
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            // Error message
            if let errorMessage = chatService.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button("Dismiss") {
                        chatService.errorMessage = nil
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }
            
            // Input field
            HStack(spacing: 12) {
                TextField("Ask about nutrition, meals, or dietary choices...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .disabled(chatService.isLoading || !chatService.isAPIKeyConfigured)
                
                Button(action: sendMessage) {
                    Image(systemName: chatService.isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSendMessage ? .blue : .gray)
                }
                .disabled(!canSendMessage)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private func chatMessagesView(conversation: DietaryConversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Welcome message
                    if conversation.messages.isEmpty {
                        welcomeMessageView
                    }
                    
                    // Chat messages
                    ForEach(conversation.messages) { message in
                        ChatMessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    // Loading indicator
                    if chatService.isLoading {
                        ChatLoadingBubble()
                    }
                }
                .padding()
            }
            .onChange(of: scrollToBottom) { _, _ in
                if let lastMessage = conversation.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var welcomeMessageView: some View {
        VStack(spacing: 16) {
            if let user = authManager.currentUser {
                VStack(spacing: 12) {
                    Text(" Hi \(user.profile.firstName.isEmpty ? "there" : user.profile.firstName)!")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("I'm your personal nutrition assistant. I know about:")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if !user.profile.dietaryRestrictions.isEmpty {
                                HStack {
                                    Text(" ")
                                    Text("Your dietary restrictions: \(user.profile.dietaryRestrictions.map { $0.rawValue }.joined(separator: ", "))")
                                }
                                .font(.caption)
                            }
                            
                            if !user.profile.healthGoals.isEmpty {
                                HStack {
                                    Text(" ")
                                    Text("Your health goals: \(user.profile.healthGoals.map { $0.rawValue }.joined(separator: ", "))")
                                }
                                .font(.caption)
                            }
                            
                            HStack {
                                Text(" ")
                                Text("Your daily targets: \(user.preferences.dailyCalorieGoal) cal, \(user.preferences.dailyProteinGoal)g protein")
                            }
                            .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Text("Ask me anything about nutrition, menu choices, or meal planning!")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Quick action buttons
            quickActionButtons
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var quickActionButtons: some View {
        VStack(spacing: 8) {
            Text("Quick Questions:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                QuickActionButton(
                    icon: "fork.knife",
                    title: "Meal Ideas",
                    color: .blue,
                    action: {
                        sendQuickMessage("Can you suggest some meal ideas that fit my dietary goals?")
                    }
                )
                
                QuickActionButton(
                    icon: "building.2",
                    title: "Restaurant Tips",
                    color: .green,
                    action: {
                        sendQuickMessage("What should I look for when eating out with my dietary restrictions?")
                    }
                )
                
                QuickActionButton(
                    icon: "chart.pie",
                    title: "Macro Balance",
                    color: .orange,
                    action: {
                        sendQuickMessage("How can I better balance my macronutrients throughout the day?")
                    }
                )
                
                QuickActionButton(
                    icon: "arrow.triangle.swap",
                    title: "Healthy Swaps",
                    color: .purple,
                    action: {
                        sendQuickMessage("What are some healthy ingredient swaps I can make?")
                    }
                )
            }
        }
    }
    
    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !chatService.isLoading &&
        chatService.isAPIKeyConfigured &&
        authManager.isAuthenticated
    }
    
    private func sendMessage() {
        guard canSendMessage,
              let user = authManager.currentUser else { return }
        
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        
        Task {
            await chatService.sendMessage(message, user: user)
        }
    }
    
    private func sendQuickMessage(_ message: String) {
        guard let user = authManager.currentUser else { return }
        
        Task {
            await chatService.sendMessage(message, user: user)
        }
    }
    
    private func startNewConversation() {
        guard let user = authManager.currentUser else { return }
        chatService.startNewConversation(for: user)
    }
    
    private func setupInitialConversation() {
        if chatService.currentConversation == nil,
           let user = authManager.currentUser {
            chatService.startNewConversation(for: user)
        }
    }
    
    private func chatAboutInitialItem(_ item: AnalyzedMenuItem) {
        guard let user = authManager.currentUser else { return }
        
        Task {
            await chatService.chatAboutMenuItem(item, user: user)
        }
    }
    
    private func scrollToBottomOfChat() {
        scrollToBottom.toggle()
    }
    
    struct ChatMessageBubble: View {
        let message: ChatMessage
        
        var body: some View {
            HStack {
                if message.role == .user {
                    Spacer(minLength: 60)
                }
                
                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(message.role == .user ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(message.role == .user ? .blue : Color(.systemGray5))
                        )
                    
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                
                if message.role == .assistant {
                    Spacer(minLength: 60)
                }
            }
        }
        
        private func formatTimestamp(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    struct ChatLoadingBubble: View {
        @State private var animationPhase = 0
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 8, height: 8)
                                .opacity(animationPhase == index ? 1.0 : 0.4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemGray5))
                    )
                    
                    Text("Thinking...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                
                Spacer(minLength: 60)
            }
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        animationPhase = (animationPhase + 1) % 3
                    }
                }
            }
        }
    }
    
    #if DEBUG
    struct Preview: PreviewProvider {
        static var previews: some View {
            DietaryChatView()
        }
    }
    #endif
}