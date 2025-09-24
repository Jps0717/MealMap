import SwiftUI

struct DietaryChatView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "hourglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Coming Soon")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            Text("This feature is under construction.")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
        .navigationTitle("Meal Map AI")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        DietaryChatView()
    }
}