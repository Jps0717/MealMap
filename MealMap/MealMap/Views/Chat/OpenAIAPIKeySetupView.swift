import SwiftUI

struct OpenAIAPIKeySetupView: View {
    @StateObject private var chatService = ChatGPTDietaryService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var validationMessage = ""
    @State private var showingInstructions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // API Key Input
                    apiKeyInputSection
                    
                    // Instructions
                    instructionsSection
                    
                    // Current Status
                    statusSection
                }
                .padding()
            }
            .navigationTitle("OpenAI API Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            apiKey = chatService.userAPIKey ?? ""
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("OpenAI API Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text("Configure your OpenAI API key to enable personalized dietary chat powered by ChatGPT-3.5.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var apiKeyInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                SecureField("sk-proj-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                HStack {
                    Text("Enter your OpenAI API key starting with 'sk-proj-' or 'sk-'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            
            if !validationMessage.isEmpty {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundColor(validationMessage.contains("✅") ? .green : .red)
                    .padding(.top, 4)
            }
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: {
                showingInstructions.toggle()
            }) {
                HStack {
                    Text("How to get an OpenAI API Key")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Image(systemName: showingInstructions ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            if showingInstructions {
                VStack(alignment: .leading, spacing: 12) {
                    InstructionStep(
                        number: 1,
                        title: "Create OpenAI Account",
                        description: "Go to platform.openai.com and create an account or sign in"
                    )
                    
                    InstructionStep(
                        number: 2,
                        title: "Navigate to API Keys",
                        description: "Click on your profile → 'View API keys' or go to platform.openai.com/api-keys"
                    )
                    
                    InstructionStep(
                        number: 3,
                        title: "Create New Key",
                        description: "Click '+ Create new secret key', name it (e.g., 'MealMap'), and copy the key"
                    )
                    
                    InstructionStep(
                        number: 4,
                        title: "Add Billing Information",
                        description: "Add payment method in Billing settings. ChatGPT-3.5 is very affordable (~$0.002 per request)"
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Cost Information:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("• ChatGPT-3.5-turbo: ~$0.002 per message\n• Daily limit: 10,000 tokens (~$0.02/day)\n• Monthly cost: <$1 for typical usage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingInstructions)
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: chatService.isAPIKeyConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(chatService.isAPIKeyConfigured ? .green : .red)
                
                Text(chatService.isAPIKeyConfigured ? "API Key Configured" : "No API Key")
                    .font(.body)
                    .foregroundColor(chatService.isAPIKeyConfigured ? .green : .red)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Token Usage Today: \(chatService.dailyTokenUsage)/10,000")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: Double(chatService.dailyTokenUsage), total: 10000)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            
            if chatService.isAPIKeyConfigured {
                Button("Clear API Key") {
                    clearAPIKey()
                }
                .foregroundColor(.red)
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty else {
            validationMessage = "❌ Please enter an API key"
            return
        }
        
        guard trimmedKey.hasPrefix("sk-") else {
            validationMessage = "❌ API key should start with 'sk-'"
            return
        }
        
        chatService.saveAPIKey(trimmedKey)
        validationMessage = "✅ API key saved successfully"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    private func clearAPIKey() {
        chatService.clearAPIKey()
        apiKey = ""
        validationMessage = "API key cleared"
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OpenAIAPIKeySetupView()
}