import SwiftUI

struct SearchResultRow: View {
    let restaurant: Restaurant
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Restaurant Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "fork.knife")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                }
                
                // Restaurant Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("Restaurant Address")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Cuisine and Type Info
                    HStack(spacing: 8) {
                        Text("Italian")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        
                        // Nutrition availability indicator
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("Nutrition Info")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SearchResultRow(
        restaurant: Restaurant(
            id: 1,
            name: "McDonald's",
            latitude: 40.7128,
            longitude: -74.0060,
            address: "123 Main St, New York, NY",
            cuisine: "Fast Food",
            openingHours: nil,
            phone: nil,
            website: nil,
            type: "node"
        ),
        onTap: {}
    )
    .padding()
}
