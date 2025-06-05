import SwiftUI

struct LeftView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Left Tab")
                .font(.title)
                .foregroundColor(.gray)
            Spacer()
        }
    }
}
#Preview {
    LeftView()
}