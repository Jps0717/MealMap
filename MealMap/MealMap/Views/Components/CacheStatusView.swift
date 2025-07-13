import SwiftUI

/// Simplified debug view (no longer needed with simple caching)
struct CacheStatusView: View {
    let regionCount: Int
    let restaurantCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "externaldrive.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("Simple Cache")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(regionCount) regions")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            HStack(spacing: 16) {
                Text("Restaurants: \(restaurantCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// Preview
#Preview {
    CacheStatusView(regionCount: 3, restaurantCount: 45)
        .padding()
}