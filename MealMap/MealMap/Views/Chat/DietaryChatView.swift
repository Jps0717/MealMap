import SwiftUI

/// ENHANCED: Full-featured dietary chat with Custom GPT integration
struct DietaryChatView: View {
    let initialItem: AnalyzedMenuItem?
    
    @StateObject private var chatService = ChatGPTDietaryService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    
    @State private var messageText = ""
    @State private var showingQuickActions = false
    @FocusState private var isTextFieldFocused: Bool
    
    init(initialItem: AnalyzedMenuItem? = nil) {
        self.initialItem = initialItem
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Always show chat content - no sign-in required
            if let conversation = chatService.currentConversation {
                chatMessagesView(conversation: conversation)
            } else {
                welcomeView
            }
            
            // Input Area - always available
            inputSection
        }
        .navigationTitle("Meal Map AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Quick Test Actions") {
                        showingQuickActions = true
                    }
                    
                    if chatService.currentConversation != nil {
                        Button("New Conversation", role: .destructive) {
                            startNewConversation()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingQuickActions) {
            QuickTestActionsView()
        }
        .onAppear {
            setupInitialChat()
        }
    }
    
    // MARK: - Welcome View
    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 20)
                
                // Hero Section with improved design
                VStack(spacing: 24) {
                    // Animated AI Logo with better gradients
                    ZStack {
                        // Outer glow effect
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .blur(radius: 10)
                        
                        // Main circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 85, height: 85)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    
                    VStack(spacing: 16) {
                        Text("Meal Map AI")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Your intelligent nutrition companion")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Enhanced Features Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    FeatureCard(
                        icon: "restaurant.fill",
                        title: "Restaurant Guide",
                        description: "Smart menu recommendations",
                        color: .orange
                    )
                    
                    FeatureCard(
                        icon: "chart.bar.fill",
                        title: "Nutrition Insights",
                        description: "Detailed macro analysis",
                        color: .green
                    )
                    
                    FeatureCard(
                        icon: "person.crop.circle.fill",
                        title: "Personal Coach",
                        description: "Tailored to your goals",
                        color: .purple
                    )
                    
                    FeatureCard(
                        icon: "lightbulb.fill",
                        title: "Smart Tips",
                        description: "Healthier alternatives",
                        color: .blue
                    )
                }
                .padding(.horizontal)
                
                // Enhanced Quick Start Section
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("✨ Try asking me:")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Tap any suggestion below to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 12) {
                        QuickStartButton(
                            text: "What's healthy at McDonald's?",
                            icon: "fork.knife",
                            color: .red
                        ) {
                            sendMessage("What's the healthiest thing I can order at McDonald's that fits my goals?")
                        }
                        
                        QuickStartButton(
                            text: "I have 500 calories left for dinner",
                            icon: "speedometer",
                            color: .orange
                        ) {
                            sendMessage("I have 500 calories left in my daily budget for dinner. What are some good restaurant options?")
                        }
                        
                        QuickStartButton(
                            text: "Help me find vegetarian protein",
                            icon: "leaf.fill",
                            color: .green
                        ) {
                            sendMessage("I'm vegetarian and trying to get more protein. What restaurants and menu items should I look for?")
                        }
                        
                        QuickStartButton(
                            text: "Low carb options near me",
                            icon: "minus.circle",
                            color: .blue
                        ) {
                            sendMessage("I'm following a low-carb diet. What are some good restaurant options with low-carb meals?")
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 20)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Chat Messages View
    private func chatMessagesView(conversation: DietaryConversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(conversation.messages) { message in
                        ChatMessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if chatService.isLoading {
                        ChatLoadingIndicator()
                    }
                }
                .padding()
            }
            .onChange(of: conversation.messages.count) { _, _ in
                if let lastMessage = conversation.messages.last {
                    withAnimation(.easeOut(duration: 0.5)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 0) {
            // Enhanced divider with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color(.systemGray4), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
            
            if let errorMessage = chatService.errorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        withAnimation(.easeOut(duration: 0.2)) {
                            chatService.errorMessage = nil
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            HStack(spacing: 12) {
                // Enhanced Text Input
                HStack(spacing: 8) {
                    TextField("Ask about nutrition, restaurants, or menu items...", text: $messageText, axis: .vertical)
                        .font(.body)
                        .lineLimit(1...4)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            sendCurrentMessage()
                        }
                    
                    if !messageText.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                messageText = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(
                                    isTextFieldFocused ? Color.blue.opacity(0.5) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
                
                // Enhanced Send Button
                Button(action: sendCurrentMessage) {
                    ZStack {
                        let isEmpty = messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let buttonColor: Color = isEmpty ? .gray : .blue
                        
                        Circle()
                            .fill(buttonColor)
                            .frame(width: 44, height: 44)
                            .shadow(
                                color: isEmpty ? Color.clear : Color.blue.opacity(0.3),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                        
                        Image(systemName: chatService.isLoading ? "stop.fill" : "arrow.up")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(chatService.isLoading ? 0 : 0))
                            .animation(.easeInOut(duration: 0.2), value: chatService.isLoading)
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .scaleEffect(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: messageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(.systemBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -2)
            )
        }
    }
    
    // MARK: - Actions
    private func setupInitialChat() {
        // Create a default user if not signed in
        let currentUser = authService.currentUser ?? User.defaultUser()
        
        // Always start a new conversation since API is always available
        if chatService.currentConversation == nil {
            _ = chatService.startNewConversation(for: currentUser, title: "Meal Map Chat")
        }
        
        // Handle initial menu item if provided
        if let item = initialItem {
            Task {
                await chatService.chatAboutMenuItem(item, user: currentUser)
            }
        }
    }
    
    private func sendCurrentMessage() {
        if chatService.isLoading {
            // Stop current request (if needed)
            return
        }
        
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        sendMessage(message)
    }
    
    private func sendMessage(_ message: String) {
        let currentUser = authService.currentUser ?? User.defaultUser()
        
        if chatService.currentConversation == nil {
            _ = chatService.startNewConversation(for: currentUser)
        }
        
        messageText = ""
        isTextFieldFocused = false
        
        Task {
            await chatService.sendMessage(message, user: currentUser)
        }
    }
    
    private func startNewConversation() {
        let currentUser = authService.currentUser ?? User.defaultUser()
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
    @StateObject private var authService = FirebaseAuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Text("🧪 Test Meal Map AI")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Try these pre-built test messages to see how your AI assistant responds")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(TestMessageType.allCases, id: \.self) { testType in
                            TestActionButton(testType: testType) {
                                Task {
                                    let currentUser = authService.currentUser ?? User.defaultUser()
                                    
                                    // Ensure we have a conversation started
                                    if chatService.currentConversation == nil {
                                        chatService.startNewConversation(for: currentUser, title: "Test Chat")
                                    }
                                    
                                    await chatService.sendMessage(testType.message, user: currentUser)
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Quick Tests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TestActionButton: View {
    let testType: TestMessageType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(testType.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text(testType.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationView {
        DietaryChatView()
    }
}