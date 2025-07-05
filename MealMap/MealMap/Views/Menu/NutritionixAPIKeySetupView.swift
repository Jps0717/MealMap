import SwiftUI

struct NutritionixAPIKeySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var nutritionixService = NutritionixAPIService.shared
    
    @State private var appId: String = ""
    @State private var apiKey: String = ""
    @State private var isValidating: Bool = false
    @State private var validationError: String? = nil
    @State private var showingHelpSheet: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("Nutritionix API Setup")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Enter your Nutritionix API key to enable detailed nutrition analysis for menu items")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 10)
                    
                    // API Credentials Input Section
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Nutritionix Credentials", systemImage: "key")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            // App ID Input
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Application ID")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                TextField("Enter your Nutritionix App ID", text: $appId)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                
                                Text("Format: 8-character alphanumeric string")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            // API Key Input
                            VStack(alignment: .leading, spacing: 6) {
                                Text("API Key")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                SecureField("Enter your Nutritionix API key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .onSubmit {
                                        if !appId.isEmpty && !apiKey.isEmpty {
                                            Task {
                                                await validateAndSaveAPICredentials()
                                            }
                                        }
                                    }
                                
                                Text("Format: 32-character alphanumeric string")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let error = validationError {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Instructions - Made more compact
                    VStack(alignment: .leading, spacing: 12) {
                        Label("How to get your API key:", systemImage: "info.circle")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            instructionStep(
                                number: "1",
                                title: "Create Nutritionix Account",
                                description: "Sign up at developer.nutritionix.com"
                            )
                            
                            instructionStep(
                                number: "2",
                                title: "Get Your Credentials",
                                description: "Find both your App ID and API Key in your dashboard under 'API Credentials'"
                            )
                            
                            instructionStep(
                                number: "3",
                                title: "Free Tier Available",
                                description: "Get 200 nutrition lookups per day for free"
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons - Made more compact
                    VStack(spacing: 10) {
                        Button(action: {
                            Task {
                                await validateAndSaveAPICredentials()
                            }
                        }) {
                            HStack {
                                if isValidating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                }
                                Text(isValidating ? "Validating..." : "Save Credentials")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(appId.isEmpty || apiKey.isEmpty || isValidating)
                        
                        HStack(spacing: 16) {
                            Button("Get API Key") {
                                if let url = URL(string: "https://developer.nutritionix.com/") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Help & FAQ") {
                                showingHelpSheet = true
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Add bottom padding to ensure content is not cut off
                    Spacer(minLength: 30)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("API Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingHelpSheet) {
            NutritionixHelpView()
        }
    }
    
    private func instructionStep(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 24, height: 24)
                
                Text(number)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
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
    }
    
    private func validateAndSaveAPICredentials() async {
        guard !appId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = "Please enter your App ID"
            return
        }
        
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = "Please enter your API key"
            return
        }
        
        isValidating = true
        validationError = nil
        
        do {
            try await nutritionixService.saveAPICredentials(
                appId.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            validationError = error.localizedDescription
        }
        
        isValidating = false
    }
}

// MARK: - Help View

struct NutritionixHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // FAQ Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Frequently Asked Questions")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        faqItem(
                            question: "Is the Nutritionix API free?",
                            answer: "Yes! Nutritionix offers 200 free nutrition lookups per day. This is perfect for casual menu scanning. If you need more, they offer paid plans starting at $49/month."
                        )
                        
                        faqItem(
                            question: "What credentials do I need?",
                            answer: "You need both your Application ID (App ID) and API Key from your Nutritionix developer account. Both must be from the same account to work together."
                        )
                        
                        faqItem(
                            question: "Where do I find my credentials?",
                            answer: "After creating your Nutritionix developer account, go to your dashboard and look for 'API Credentials' section. You'll see both your App ID and API Key listed there."
                        )
                        
                        faqItem(
                            question: "Is my API key secure?",
                            answer: "Yes, your API key is stored securely on your device using iOS's secure storage. It's never shared with anyone and only used to make nutrition requests to Nutritionix."
                        )
                        
                        faqItem(
                            question: "What data does MealMap access?",
                            answer: "MealMap only sends menu item names to Nutritionix to get nutrition information. No personal data, photos, or location information is shared."
                        )
                        
                        faqItem(
                            question: "Can I change my API key later?",
                            answer: "Yes! You can update your API key anytime in the app settings. Just go to Settings > Nutritionix API Key."
                        )
                        
                        faqItem(
                            question: "Why do I need my own API key?",
                            answer: "Using your own API key ensures you get the full 200 daily requests and keeps your usage separate from other users. It also helps keep the app free!"
                        )
                    }
                    
                    Divider()
                    
                    // Links Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Useful Links")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        linkItem(
                            title: "Nutritionix Developer Portal",
                            url: "https://developer.nutritionix.com/",
                            description: "Sign up and get your API key"
                        )
                        
                        linkItem(
                            title: "API Documentation",
                            url: "https://docs.google.com/document/d/1_q-K-ObMTZvO0qUEAxROrN3bwMujwAN25sLHwJzliK0/edit",
                            description: "Learn more about the Nutritionix API"
                        )
                        
                        linkItem(
                            title: "Pricing Information",
                            url: "https://www.nutritionix.com/business/api",
                            description: "View pricing for higher usage tiers"
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Help & FAQ")
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
    
    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(answer)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func linkItem(title: String, url: String, description: String) -> some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Preview

#Preview {
    NutritionixAPIKeySetupView()
}

#Preview("Help View") {
    NutritionixHelpView()
}