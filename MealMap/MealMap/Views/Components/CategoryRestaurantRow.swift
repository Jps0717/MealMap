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
        GeometryReader { geometry in
            Button(action: onTap) {
                HStack(spacing: DynamicSizing.spacing(16, geometry: geometry)) {
                    // Restaurant icon with nutrition indicator
                    ZStack {
                        RoundedRectangle(cornerRadius: DynamicSizing.cornerRadius(12))
                            .fill(hasNutrition ? Color.green.opacity(0.1) : categoryColor.opacity(0.1))
                            .frame(
                                width: DynamicSizing.iconSize(60),
                                height: DynamicSizing.iconSize(60)
                            )
                        
                        VStack(spacing: DynamicSizing.spacing(4, geometry: geometry)) {
                            Text(restaurant.emoji)
                                .font(.system(size: DynamicSizing.iconSize(20)))
                            
                            if hasNutrition {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: DynamicSizing.iconSize(10)))
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.system(size: DynamicSizing.iconSize(8)))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: DynamicSizing.cornerRadius(12))
                            .stroke(hasNutrition ? Color.green : categoryColor, lineWidth: 2)
                    )
                    
                    // Restaurant details
                    VStack(alignment: .leading, spacing: DynamicSizing.spacing(6, geometry: geometry)) {
                        HStack {
                            Text(restaurant.name)
                                .dynamicFont(16, weight: .semibold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Distance if available
                            if let userLocation = LocationManager.shared.lastLocation?.coordinate {
                                let distance = restaurant.distanceFrom(userLocation)
                                Text(String(format: "%.1f mi", distance))
                                    .dynamicFont(12, weight: .medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let cuisine = restaurant.cuisine {
                            Text(cuisine.capitalized)
                                .dynamicFont(14, weight: .medium)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        // Status indicators
                        HStack(spacing: DynamicSizing.spacing(8, geometry: geometry)) {
                            if hasNutrition {
                                HStack(spacing: DynamicSizing.spacing(2, geometry: geometry)) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: DynamicSizing.iconSize(10)))
                                        .foregroundColor(.green)
                                    Text("Nutrition Data")
                                        .dynamicFont(12, weight: .medium)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, DynamicSizing.spacing(6, geometry: geometry))
                                .padding(.vertical, DynamicSizing.spacing(2, geometry: geometry))
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.1))
                                )
                            } else {
                                HStack(spacing: DynamicSizing.spacing(2, geometry: geometry)) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: DynamicSizing.iconSize(10)))
                                        .foregroundColor(.blue)
                                    Text("Location Only")
                                        .dynamicFont(12, weight: .medium)
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, DynamicSizing.spacing(6, geometry: geometry))
                                .padding(.vertical, DynamicSizing.spacing(2, geometry: geometry))
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                            
                            Spacer()
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: DynamicSizing.iconSize(12), weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, DynamicSizing.spacing(16, geometry: geometry))
                .padding(.vertical, DynamicSizing.spacing(12, geometry: geometry))
                .background(
                    RoundedRectangle(cornerRadius: DynamicSizing.cornerRadius(16))
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: .black.opacity(0.04), 
                            radius: DynamicSizing.spacing(8, geometry: geometry), 
                            y: DynamicSizing.spacing(2, geometry: geometry)
                        )
                )
                .overlay(
                    HStack {
                        RoundedRectangle(cornerRadius: DynamicSizing.cornerRadius(2))
                            .fill(hasNutrition ? Color.green : categoryColor)
                            .frame(width: DynamicSizing.spacing(4, geometry: geometry))
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
        }
        .listRowInsets(EdgeInsets(
            top: DynamicSizing.spacing(4),
            leading: DynamicSizing.spacing(20),
            bottom: DynamicSizing.spacing(4),
            trailing: DynamicSizing.spacing(20)
        ))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .frame(height: DynamicSizing.cardHeight(100))
    }
}