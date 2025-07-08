import SwiftUI

struct NutritionMenuView: View {
    let restaurantData: RestaurantNutritionData
    let selectedCategory: RestaurantCategory?
    @State private var searchText = ""
    @State private var selectedItem: NutritionData?
    @State private var showingItemDetail = false
    
    // Simplified filtering - removed category filter toggle
    private var filteredItems: [NutritionData] {
        var items = restaurantData.items
        
        // Apply category filter automatically if category is selected
        if let category = selectedCategory {
            items = filterItemsByCategory(items, category: category)
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                item.item.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items
    }
    
    private func filterItemsByCategory(_ items: [NutritionData], category: RestaurantCategory) -> [NutritionData] {
        switch category {
        case .fastFood:
            return items
        case .healthy:
            return items.filter { item in
                item.sodium <= 600 && item.fiber >= 3 && item.calories <= 500
            }
        case .highProtein:
            return items.filter { item in
                item.protein >= 20
            }
        case .lowCarb:
            return items.filter { item in
                item.carbs <= 15
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search menu items...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Menu items list
                List(filteredItems) { item in
                    MenuItemRow(item: item, category: selectedCategory)
                        .onTapGesture {
                            selectedItem = item
                            showingItemDetail = true
                        }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle(restaurantData.restaurantName)
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingItemDetail) {
            if let item = selectedItem {
                NutritionDetailView(item: item)
            }
        }
    }
}

struct MenuItemRow: View {
    let item: NutritionData
    let category: RestaurantCategory?
    
    // Health scoring for highlighting harmful vs healthy items
    private var healthScore: HealthScore {
        calculateHealthScore(for: item)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.item)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Health indicator using symbols instead of emojis
                    Image(systemName: healthScore.symbolName)
                        .foregroundColor(healthScore.color)
                        .font(.system(size: 16, weight: .semibold))
                    
                    // Simplified health badge - only for concerning items
                    if healthScore == .veryUnhealthy || healthScore == .unhealthy {
                        Text(healthScore.label)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(healthScore.color.opacity(0.2))
                            .foregroundColor(healthScore.color)
                            .cornerRadius(6)
                    }
                }
                
                // Only show noteworthy nutrition metrics (good or concerning)
                HStack(spacing: 16) {
                    ForEach(getNoteworthyMetrics(for: item, category: category), id: \.text) { metric in
                        Label(metric.text, systemImage: metric.icon)
                            .font(.caption)
                            .foregroundColor(metric.color)
                            .fontWeight(metric.isHighlighted ? .bold : .regular)
                    }
                }
            }
            
            Spacer()
            
            // Main metric display - always calories
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(item.calories))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(getCalorieColor(item.calories))
                Text("cal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
        .background(
            // Very subtle background highlighting for very unhealthy items
            healthScore == .veryUnhealthy ? 
            Color.red.opacity(0.03) : Color.clear
        )
        .cornerRadius(6)
    }
    
    // Get only noteworthy nutrition metrics (good or bad, skip neutral)
    private func getNoteworthyMetrics(for item: NutritionData, category: RestaurantCategory?) -> [NutritionMetric] {
        var metrics: [NutritionMetric] = []
        
        // High sodium (concerning)
        if item.sodium > 1500 {
            metrics.append(NutritionMetric(
                text: "\(Int(item.sodium))mg sodium",
                icon: "exclamationmark.triangle.fill",
                color: .red,
                isHighlighted: true
            ))
        } else if item.sodium > 1000 {
            metrics.append(NutritionMetric(
                text: "\(Int(item.sodium))mg sodium",
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                isHighlighted: true
            ))
        } else if item.sodium <= 400 {
            // Low sodium (good)
            metrics.append(NutritionMetric(
                text: "\(Int(item.sodium))mg sodium",
                icon: "checkmark.circle.fill",
                color: .green,
                isHighlighted: true
            ))
        }
        
        // High saturated fat (concerning)
        if item.saturatedFat > 15 {
            metrics.append(NutritionMetric(
                text: "\(formatNumber(item.saturatedFat))g sat fat",
                icon: "exclamationmark.triangle.fill",
                color: .red,
                isHighlighted: true
            ))
        } else if item.saturatedFat > 10 {
            metrics.append(NutritionMetric(
                text: "\(formatNumber(item.saturatedFat))g sat fat",
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                isHighlighted: true
            ))
        } else if item.saturatedFat <= 3 {
            // Low saturated fat (good)
            metrics.append(NutritionMetric(
                text: "\(formatNumber(item.saturatedFat))g sat fat",
                icon: "checkmark.circle.fill",
                color: .green,
                isHighlighted: true
            ))
        }
        
        // High protein (good)
        if item.protein >= 25 {
            metrics.append(NutritionMetric(
                text: "\(formatNumber(item.protein))g protein",
                icon: "checkmark.circle.fill",
                color: .green,
                isHighlighted: true
            ))
        } else if item.protein >= 20 && category == .highProtein {
            metrics.append(NutritionMetric(
                text: "\(formatNumber(item.protein))g protein",
                icon: "checkmark.circle",
                color: .green,
                isHighlighted: true
            ))
        }
        
        // High fiber (good)
        if item.fiber >= 5 {
            metrics.append(NutritionMetric(
                text: "\(formatNumber(item.fiber))g fiber",
                icon: "leaf.fill",
                color: .green,
                isHighlighted: true
            ))
        } else if item.fiber >= 3 && category == .healthy {
            metrics.append(NutritionMetric(
                text: "\(formatNumber(item.fiber))g fiber",
                icon: "leaf.fill",
                color: .green,
                isHighlighted: true
            ))
        }
        
        // High sugar (concerning)
        if item.sugar > 30 {
            metrics.append(NutritionMetric(
                text: "\(formatNumber(item.sugar))g sugar",
                icon: "exclamationmark.triangle.fill",
                color: .red,
                isHighlighted: true
            ))
        } else if item.sugar > 20 {
            metrics.append(NutritionMetric(
                text: "\(formatNumber(item.sugar))g sugar",
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                isHighlighted: true
            ))
        } else if item.sugar <= 5 {
            // Low sugar (good)
            metrics.append(NutritionMetric(
                text: "\(formatNumber(item.sugar))g sugar",
                icon: "checkmark.circle.fill",
                color: .green,
                isHighlighted: true
            ))
        }
        
        // Limit to 2 most important metrics to avoid clutter
        return Array(metrics.prefix(2))
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    // Health scoring system
    private func calculateHealthScore(for item: NutritionData) -> HealthScore {
        var unhealthyPoints = 0
        var healthyPoints = 0
        
        // Unhealthy factors
        if item.calories > 800 { unhealthyPoints += 2 }
        else if item.calories > 600 { unhealthyPoints += 1 }
        
        if item.sodium > 1500 { unhealthyPoints += 3 }
        else if item.sodium > 1000 { unhealthyPoints += 2 }
        else if item.sodium > 600 { unhealthyPoints += 1 }
        
        if item.saturatedFat > 15 { unhealthyPoints += 2 }
        else if item.saturatedFat > 10 { unhealthyPoints += 1 }
        
        if item.sugar > 30 { unhealthyPoints += 2 }
        else if item.sugar > 20 { unhealthyPoints += 1 }
        
        // Healthy factors
        if item.fiber >= 5 { healthyPoints += 2 }
        else if item.fiber >= 3 { healthyPoints += 1 }
        
        if item.protein >= 25 { healthyPoints += 2 }
        else if item.protein >= 15 { healthyPoints += 1 }
        
        if item.calories < 400 { healthyPoints += 1 }
        
        // Determine score
        let netScore = healthyPoints - unhealthyPoints
        
        if unhealthyPoints >= 5 { return .veryUnhealthy }
        else if unhealthyPoints >= 3 { return .unhealthy }
        else if netScore >= 2 { return .healthy }
        else if netScore >= 1 { return .somewhatHealthy }
        else { return .neutral }
    }
    
    // Color coding functions
    private func getCalorieColor(_ calories: Double) -> Color {
        if calories > 800 { return .red }
        else if calories > 600 { return .orange }
        else if calories < 400 { return .green }
        else { return .primary }
    }
}

// Helper struct for nutrition metrics
struct NutritionMetric {
    let text: String
    let icon: String
    let color: Color
    let isHighlighted: Bool
}

// Health scoring enum
enum HealthScore: Equatable {
    case veryUnhealthy
    case unhealthy
    case neutral
    case somewhatHealthy
    case healthy
    
    var color: Color {
        switch self {
        case .veryUnhealthy: return .red
        case .unhealthy: return .orange
        case .neutral: return .gray
        case .somewhatHealthy: return .green
        case .healthy: return .green
        }
    }
    
    var label: String {
        switch self {
        case .veryUnhealthy: return "AVOID"
        case .unhealthy: return "LIMIT"
        case .neutral: return ""
        case .somewhatHealthy: return ""
        case .healthy: return ""
        }
    }
    
    var symbolName: String {
        switch self {
        case .veryUnhealthy: return "xmark.circle.fill"
        case .unhealthy: return "exclamationmark.triangle.fill"
        case .neutral: return "minus.circle"
        case .somewhatHealthy: return "checkmark.circle"
        case .healthy: return "checkmark.circle.fill"
        }
    }
}

#Preview {
    let sampleData = RestaurantNutritionData(
        restaurantName: "McDonald's",
        items: [
            NutritionData(
                item: "Big Mac",
                calories: 550,
                fat: 30,
                saturatedFat: 10,
                cholesterol: 80,
                sodium: 1010,
                carbs: 44,
                fiber: 3,
                sugar: 9,
                protein: 25
            ),
            NutritionData(
                item: "McChicken",
                calories: 400,
                fat: 21,
                saturatedFat: 3.5,
                cholesterol: 40,
                sodium: 560,
                carbs: 40,
                fiber: 2,
                sugar: 5,
                protein: 14
            )
        ]
    )
    
    NutritionMenuView(restaurantData: sampleData, selectedCategory: .highProtein)
}