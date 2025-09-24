import SwiftUI
import CoreLocation

// MARK: - Unified Category Restaurant Row
struct CategoryRestaurantRow: View {
    let restaurant: Restaurant
    let category: Any? // Can be RestaurantCategory or UserCategory
    let hasNutrition: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var categoryColor: Color {
        if let restCategory = category as? RestaurantCategory {
            return restCategory.color
        } else if let userCategory = category as? UserCategory {
            return getUserCategoryColor(userCategory.id)
        }
        return .blue
    }
    
    private func getUserCategoryColor(_ id: String) -> Color {
        switch id {
        case "fastFood": return .orange
        case "healthy": return .green
        case "highProtein": return .red
        case "vegan": return .green
        case "glutenFree": return .orange
        case "lowCarb", "keto": return .purple
        default: return .blue
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Restaurant icon with nutrition indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(hasNutrition ? Color.green.opacity(0.1) : categoryColor.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 4) {
                        Text(restaurant.emoji)
                            .font(.system(size: 20))
                        
                        if hasNutrition {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(hasNutrition ? Color.green : categoryColor, lineWidth: 2)
                )
                
                // Restaurant details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(restaurant.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Distance if available
                        if let userLocation = LocationManager.shared.lastLocation?.coordinate {
                            let distance = restaurant.distanceFrom(userLocation)
                            Text(String(format: "%.1f mi", distance))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let cuisine = restaurant.cuisine {
                        Text(cuisine.capitalized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Status indicators
                    HStack(spacing: 8) {
                        if hasNutrition {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                Text("Nutrition Data")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.1))
                            )
                        } else {
                            HStack(spacing: 2) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text("Location Only")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                        
                        Spacer()
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
            .overlay(
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(hasNutrition ? Color.green : categoryColor)
                        .frame(width: 4)
                    Spacer()
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
