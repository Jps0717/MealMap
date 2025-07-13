import SwiftUI

/// Simple placeholder view for dietary chat functionality
struct DietaryChatView: View {
    let initialItem: AnalyzedMenuItem?
    
    init(initialItem: AnalyzedMenuItem? = nil) {
        self.initialItem = initialItem
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "message.circle")
                .font(.system(size: 50))
                .foregroundColor(.purple)
            
            VStack(spacing: 12) {
                Text("Dietary Chat")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Coming Soon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Get personalized nutrition advice and meal recommendations")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let item = initialItem {
                Text("Selected: \(item.name)")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .navigationTitle("Dietary Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        DietaryChatView()
    }
}