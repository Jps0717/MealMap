import SwiftUI

struct MenuAnalysisResultsView: View {
    let result: MenuAnalysisResult
    @State private var selectedFilter: DietaryTag?
    @State private var showingItemDetail: AnalyzedMenuItem?
    @Environment(\.dismiss) private var dismiss
    
    private var filteredItems: [AnalyzedMenuItem] {
        guard let filter = selectedFilter else { return result.menuItems }
        return result.menuItems.filter { $0.dietaryTags.contains(filter) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Filter Tags
                filterScrollView
                
                // Results List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            MenuAnalysisItemCard(item: item) {
                                showingItemDetail = item
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Menu Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $showingItemDetail) { item in
            AnalyzedMenuItemView(item: item)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    if let restaurantName = result.restaurantName {
                        Text(restaurantName)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    Text("\(result.totalItems) items analyzed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(Int(result.confidence * 100))%")
                            .fontWeight(.semibold)
                    }
                    Text("Confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if filteredItems.count != result.totalItems {
                Text("\(filteredItems.count) of \(result.totalItems) items match filter")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
    
    private var filterScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All items button
                FilterChip(
                    title: "All Items",
                    emoji: "📋",
                    isSelected: selectedFilter == nil,
                    count: result.totalItems
                ) {
                    selectedFilter = nil
                }
                
                // Dietary filter chips
                ForEach(availableFilters, id: \.self) { tag in
                    let count = result.menuItems.filter { $0.dietaryTags.contains(tag) }.count
                    if count > 0 {
                        FilterChip(
                            title: tag.displayName,
                            emoji: tag.emoji,
                            isSelected: selectedFilter == tag,
                            count: count
                        ) {
                            selectedFilter = selectedFilter == tag ? nil : tag
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var availableFilters: [DietaryTag] {
        DietaryTag.allCases.filter { tag in
            result.menuItems.contains { $0.dietaryTags.contains(tag) }
        }
    }
}

struct MenuAnalysisItemCard: View {
    let item: AnalyzedMenuItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with USDA-only indicators
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                            
                            // USDA-only warning indicator
                            if item.estimationTier != .unavailable {
                                Text("⚠️")
                                    .font(.caption)
                                    .help("USDA database estimate")
                            }
                        }
                        
                        if let description = item.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        // USDA source indicator
                        if item.estimationTier != .unavailable {
                            HStack(spacing: 4) {
                                Text("📊")
                                Text("USDA Database")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                if let details = item.nutritionEstimate.sourceDetails {
                                    Text("• \(details)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        if let price = item.price {
                            Text(price)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        USDAOnlyConfidenceBadge(
                            confidence: item.confidence,
                            isAvailable: item.estimationTier != .unavailable
                        )
                    }
                }
                
                // Nutrition Summary - USDA ranges only
                if item.estimationTier != .unavailable {
                    HStack(spacing: 12) {
                        USDAOnlyNutritionPill(
                            label: "Cal",
                            range: item.nutritionEstimate.calories,
                            color: .orange
                        )
                        
                        USDAOnlyNutritionPill(
                            label: "Carb",
                            range: item.nutritionEstimate.carbs,
                            color: .blue
                        )
                        
                        USDAOnlyNutritionPill(
                            label: "Protein",
                            range: item.nutritionEstimate.protein,
                            color: .red
                        )
                        
                        USDAOnlyNutritionPill(
                            label: "Fat",
                            range: item.nutritionEstimate.fat,
                            color: .purple
                        )
                        
                        if let sugar = item.nutritionEstimate.sugar, sugar.average > 0 {
                            USDAOnlyNutritionPill(
                                label: "Sugar",
                                range: sugar,
                                color: .orange
                            )
                        }
                        
                        Spacer()
                    }
                } else {
                    // No nutrition available
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("No USDA database match found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Simplified dietary tags (macro-based only)
                if !item.dietaryTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(item.dietaryTags.prefix(3)), id: \.self) { tag in
                                DietaryTagBadge(tag: tag)
                            }
                        }
                    }
                }
                
                // USDA-only disclaimer
                if item.estimationTier != .unavailable {
                    HStack {
                        Text("💡")
                            .font(.caption2)
                        Text("Nutrition estimated from USDA database food matching (no ingredient analysis)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct USDAOnlyNutritionPill: View {
    let label: String
    let range: NutritionRange
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            if range.min != range.max && range.max > 0 {
                Text(range.displayString)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            } else if range.average > 0 {
                Text("\(Int(range.average))\(range.unit)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            } else {
                Text("0\(range.unit)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct USDAOnlyConfidenceBadge: View {
    let confidence: Double
    let isAvailable: Bool
    
    private var color: Color {
        guard isAvailable else { return .gray }
        
        switch confidence {
        case 0.7...:
            return .green
        case 0.5..<0.7:
            return .blue
        case 0.3..<0.5:
            return .orange
        default:
            return .red
        }
    }
    
    private var text: String {
        guard isAvailable else { return "N/A" }
        
        switch confidence {
        case 0.7...:
            return "Good"
        case 0.5..<0.7:
            return "USDA"
        case 0.3..<0.5:
            return "Low"
        default:
            return "Poor"
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

struct FilterChip: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("(\(count))")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

struct DietaryTagBadge: View {
    let tag: DietaryTag
    
    var body: some View {
        HStack(spacing: 2) {
            Text(tag.emoji)
                .font(.caption2)
            Text(tag.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(hex: tag.color).opacity(0.2))
        .foregroundColor(Color(hex: tag.color))
        .cornerRadius(6)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    MenuAnalysisResultsView(result: MenuAnalysisResult(
        restaurantName: "Sample Restaurant",
        location: nil,
        menuItems: [],
        analysisDate: Date(),
        imageData: nil,
        confidence: 0.85
    ))
}