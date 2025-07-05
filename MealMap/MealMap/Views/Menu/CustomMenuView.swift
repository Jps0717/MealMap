import SwiftUI

struct CustomMenuView: View {
    @ObservedObject var analysisResult: MenuAnalysisProgress
    @State private var restaurantName: String = ""
    @State private var showingEditMode = false
    @State private var selectedItems: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with restaurant name
                headerSection
                
                // Real-time analysis progress
                if analysisResult.isAnalyzing {
                    analysisProgressSection
                }
                
                // Menu items list
                menuItemsSection
            }
            .navigationTitle("AI + Nutritionix Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !analysisResult.analyzedItems.isEmpty {
                        Button(showingEditMode ? "Done" : "Edit") {
                            showingEditMode.toggle()
                        }
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Restaurant name input
            HStack {
                Image(systemName: "building.2")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                TextField("Restaurant Name", text: $restaurantName)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)
            }
            .padding(.horizontal)
            
            // Analysis summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analysisResult.totalItems)")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Analyzed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analysisResult.analyzedItems.count)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("With Nutrition")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analysisResult.itemsWithNutrition)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // AI + Nutritionix indicator
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.purple)
                Text("Powered by AI + Nutritionix")
                    .font(.caption)
                    .foregroundColor(.purple)
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
    
    private var analysisProgressSection: some View {
        VStack(spacing: 12) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text("Analyzing menu items with AI + Nutritionix...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(analysisResult.analyzedItems.count)/\(analysisResult.totalItems)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: analysisResult.progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .background(Color.blue.opacity(0.05))
    }
    
    private var menuItemsSection: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(analysisResult.analyzedItems) { item in
                    CustomMenuItemRow(
                        item: item,
                        isSelected: selectedItems.contains(item.id),
                        isEditMode: showingEditMode
                    ) {
                        if showingEditMode {
                            if selectedItems.contains(item.id) {
                                selectedItems.remove(item.id)
                            } else {
                                selectedItems.insert(item.id)
                            }
                        }
                    }
                }
                
                // Real-time loading indicator for new items
                if analysisResult.isAnalyzing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Processing more items...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
}

// MARK: - Custom Menu Item Row

struct CustomMenuItemRow: View {
    let item: AnalyzedMenuItem
    let isSelected: Bool
    let isEditMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator in edit mode
                if isEditMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                }
                
                // Nutrition source indicator
                Image(systemName: sourceIcon)
                    .foregroundColor(sourceColor)
                    .font(.title3)
                
                // Item details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if let price = item.price {
                            Text(price)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Nutrition summary or source info
                    if item.estimationTier != .unavailable {
                        HStack {
                            Text("\(Int(item.nutritionEstimate.calories.average)) cal")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(item.nutritionEstimate.protein.average))g protein")
                                .font(.caption)
                            
                            if item.isGeneralizedEstimate {
                                Text("⚠️")
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            Text("\(Int(item.confidence * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(sourceColor)
                        }
                    } else {
                        Text("No nutrition data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Dietary tags
                    if !item.dietaryTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(item.dietaryTags.prefix(3), id: \.self) { tag in
                                    Text(tag.emoji + tag.displayName)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(tag.color.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                // Confidence indicator
                if !isEditMode {
                    VStack {
                        Circle()
                            .fill(confidenceColor)
                            .frame(width: 8, height: 8)
                        
                        Text(confidenceText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var sourceIcon: String {
        switch item.estimationTier {
        case .nutritionix: return "brain"
        case .unavailable: return "questionmark.circle"
        }
    }
    
    private var sourceColor: Color {
        switch item.estimationTier {
        case .nutritionix: return .blue
        case .unavailable: return .gray
        }
    }
    
    private var confidenceColor: Color {
        if item.confidence >= 0.75 {
            return .green
        } else if item.confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var confidenceText: String {
        if item.confidence >= 0.75 {
            return "High"
        } else if item.confidence >= 0.5 {
            return "Med"
        } else {
            return "Low"
        }
    }
}