import SwiftUI

struct OpenAIAPIKeySetupView: View {
    @StateObject private var chatService = ChatGPTDietaryService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Service Status
                    serviceStatusSection
                    
                    // Usage Information
                    usageSection
                    
                    // Features
                    featuresSection
                }
                .padding()
            }
            .navigationTitle("Chat Service")
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
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("AI Dietary Assistant")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text("Your personalized nutrition expert powered by ChatGPT-4o is ready to help you make smarter food choices.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var serviceStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ready to Chat")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    Text("AI assistant is configured and ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage Today")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tokens Used:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(chatService.dailyTokenUsage) / 50,000")
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: Double(chatService.dailyTokenUsage), total: 50000)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                
                Text("Generous daily limit for unlimited conversations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What I Can Help With")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                FeatureRow(
                    icon: "fork.knife.circle.fill",
                    title: "Menu Analysis",
                    description: "Get personalized recommendations for any restaurant menu item"
                )
                
                FeatureRow(
                    icon: "chart.bar.fill",
                    title: "Nutrition Tracking",
                    description: "Track calories, macros, and nutrients against your daily goals"
                )
                
                FeatureRow(
                    icon: "heart.fill",
                    title: "Dietary Guidance",
                    description: "Personalized advice based on your health goals and restrictions"
                )
                
                FeatureRow(
                    icon: "location.fill",
                    title: "Restaurant Suggestions",
                    description: "Find the best dining options that match your nutritional needs"
                )
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    OpenAIAPIKeySetupView()
}