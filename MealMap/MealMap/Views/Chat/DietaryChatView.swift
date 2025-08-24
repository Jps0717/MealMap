import SwiftUI

struct DietaryChatView: View {
    let initialItem: AnalyzedMenuItem?
    
    @StateObject private var chatService = ChatGPTDietaryService.shared
    @StateObject private var authManager = AuthenticationManager.shared
    
    @State private var messageText = ""
    @State private var showingQuickActions = false
    @FocusState private var isTextFieldFocused: Bool
    
    private let maxCharacterLimit = 150
    
    init(initialItem: AnalyzedMenuItem? = nil) {
        self.initialItem = initialItem
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if let conversation = chatService.currentConversation {
                chatMessagesView(conversation: conversation)
            } else {
                welcomeView
            }
            
            inputSection
        }
        .sheet(isPresented: $showingQuickActions) {
            QuickTestActionsView()
        }
        .onAppear {
            setupInitialChat()
        }
    }
    
    private var headerView: some View {
        HStack {
            Spacer()
            Text("Meal Map AI")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(alignment: .trailing) {
            Menu {
                Button("Quick Test Actions") { showingQuickActions = true }
                if chatService.currentConversation != nil {
                    Button("New Conversation", role: .destructive) { startNewConversation() }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .padding()
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Welcome to Meal Map AI")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your intelligent nutrition companion. Ask anything about menus, restaurants, or your diet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Limited to 150 characters per message")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            Button("Start a New Chat") {
                startNewConversation()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
    
    private func chatMessagesView(conversation: DietaryConversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Welcome message for first-time conversations
                    if conversation.messages.isEmpty {
                        welcomeMessageView
                    }
                    
                    ForEach(conversation.messages) { message in
                        ChatMessageBubble(message: message)
                            .id(message.id)
                    }
                    if chatService.isLoading {
                        ProgressView()
                            .padding()
                    }
                }
                .padding()
            }
            .onChange(of: conversation.messages.count) {
                if let lastMessage = conversation.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var welcomeMessageView: some View {
        let currentUser = authManager.currentUser ?? User.defaultUser()
        let isGuest = !authManager.isAuthenticated
        
        let profileName = currentUser.profile.fullName.trimmingCharacters(in: .whitespaces)
        let displayNameFromUser = currentUser.displayName.trimmingCharacters(in: .whitespaces)

        var finalName = "User" // Default
        if isGuest {
            finalName = "Guest"
        } else {
            if !profileName.isEmpty {
                finalName = profileName
            } else if !displayNameFromUser.isEmpty {
                finalName = displayNameFromUser
            }
        }
        
        return VStack {
            Text("Hey, \(finalName)!")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(isGuest ? "You're using Meal Map as a guest." : "Welcome back!")
                .font(.subheadline)
            
            Text("Limited to 150 characters per message")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical)
    }
    
    private var inputSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            if let errorMessage = chatService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
            
            if !messageText.isEmpty {
                HStack {
                    Spacer()
                    Text("\(messageText.count)/\(maxCharacterLimit)")
                        .font(.caption)
                        .foregroundColor(messageText.count > maxCharacterLimit ? .red : .secondary)
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                TextField("Ask about nutrition (max 150 chars)...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onChange(of: messageText) { _, newValue in
                        if newValue.count > maxCharacterLimit {
                            messageText = String(newValue.prefix(maxCharacterLimit))
                        }
                    }
                
                Button(action: sendCurrentMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                }
                .disabled(messageText.isEmpty || chatService.isLoading || messageText.count > maxCharacterLimit)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    private func setupInitialChat() {
        if let item = initialItem {
            let currentUser = authManager.currentUser ?? User.defaultUser()
            Task {
                await chatService.chatAboutMenuItem(item, user: currentUser)
            }
        } else if chatService.currentConversation == nil {
            startNewConversation()
        }
    }
    
    private func sendCurrentMessage() {
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty || message.count > maxCharacterLimit { return }
        
        sendMessage(message)
    }
    
    private func sendMessage(_ message: String) {
        let currentUser = authManager.currentUser ?? User.defaultUser()
        
        messageText = ""
        isTextFieldFocused = false
        
        Task {
            await chatService.sendMessage(message, user: currentUser)
        }
    }
    
    private func startNewConversation() {
        let currentUser = authManager.currentUser ?? User.defaultUser()
        _ = chatService.startNewConversation(for: currentUser)
    }
}

// MARK: - Supporting Views
struct ChatFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
}

struct QuickStartButton: View {
    let text: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(color.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: false)
    }
}

struct QuickActionChip: View {
    let text: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundColor(.accentColor)
                
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ChatMessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                HStack {
                    if message.role == .assistant {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: 16, height: 16)
                    }
                    
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(message.role == .user ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    message.role == .user 
                                        ? LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Color(.systemGray5), Color(.systemGray4).opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                    
                    if message.role == .user {
                        AsyncImage(url: URL(string: "https://via.placeholder.com/32x32/007AFF/FFFFFF?text=U")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(.blue)
                                .overlay(
                                    Text("U")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                    }
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, message.role == .assistant ? 20 : 8)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }
}

struct ChatLoadingIndicator: View {
    @State private var animationAmount = 0.0
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("Meal Map AI is thinking...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.blue)
                }
                
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 8, height: 8)
                            .scaleEffect(animationAmount == Double(index) ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: animationAmount
                            )
                    }
                }
                .padding(.leading, 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(.systemGray6), Color(.systemGray5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            
            Spacer(minLength: 40)
        }
        .onAppear {
            animationAmount = 1.0
        }
    }
}

// MARK: - Quick Test Actions Sheet
struct QuickTestActionsView: View {
    @StateObject private var chatService = ChatGPTDietaryService.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(TestMessageType.allCases, id: \.self) { testType in
                Button(testType.title) {
                    Task {
                        let currentUser = authManager.currentUser ?? User.defaultUser()
                        if chatService.currentConversation == nil {
                            chatService.startNewConversation(for: currentUser)
                        }
                        await chatService.sendMessage(testType.message, user: currentUser)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Quick Tests")
        }
    }
}

#Preview {
    NavigationView {
        DietaryChatView()
    }
}