import SwiftUI

struct SavedMenuDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let savedMenu: SavedMenuAnalysis
    
    @State private var selectedItems: Set<UUID>
    @State private var showingDeleteAlert = false
    
    init(savedMenu: SavedMenuAnalysis) {
        self.savedMenu = savedMenu
        self._selectedItems = State(initialValue: savedMenu.selectedItemIds)
    }
    
    // Calculate nutrition for currently selected items
    private var currentNutrition: NutritionInfo {
        let selectedValidItems = savedMenu.items.filter { 
            selectedItems.contains($0.id) && $0.isValid && $0.nutritionInfo != nil 
        }
        
        let totalCalories = selectedValidItems.compactMap { $0.nutritionInfo?.calories }.reduce(0, +)
        let totalProtein = selectedValidItems.compactMap { $0.nutritionInfo?.protein }.reduce(0, +)
        let totalCarbs = selectedValidItems.compactMap { $0.nutritionInfo?.carbs }.reduce(0, +)
        let totalFat = selectedValidItems.compactMap { $0.nutritionInfo?.fat }.reduce(0, +)
        
        return NutritionInfo(
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fiber: nil,
            sodium: nil,
            sugar: nil
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header stats
                headerStatsView
                
                // Menu items list
                menuItemsList
            }
            .navigationTitle(savedMenu.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Share Menu") {
                            shareMenu()
                        }
                        
                        Button("Delete Menu", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Delete Saved Menu", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    SavedMenuManager.shared.deleteMenu(savedMenu)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete '\(savedMenu.name)'? This action cannot be undone.")
            }
        }
    }
    
    private var headerStatsView: some View {
        VStack(spacing: 16) {
            // Menu info
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saved on \(savedMenu.formattedDate)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(savedMenu.items.count) items analyzed • \(savedMenu.successRate)% success")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            // Current meal nutrition
            mealNutritionSection
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var mealNutritionSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(.purple)
                Text("Your Meal Nutrition")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                Spacer()
            }
            
            HStack(spacing: 16) {
                SavedMenuNutritionStat(label: "Cal", value: "\(Int(currentNutrition.calories ?? 0))", color: .red)
                SavedMenuNutritionStat(label: "Protein", value: "\(Int(currentNutrition.protein ?? 0))g", color: .blue)
                SavedMenuNutritionStat(label: "Carbs", value: "\(Int(currentNutrition.carbs ?? 0))g", color: .orange)
                SavedMenuNutritionStat(label: "Fat", value: "\(Int(currentNutrition.fat ?? 0))g", color: .green)
            }
        }
    }
    
    private var menuItemsList: some View {
        List {
            ForEach(savedMenu.items) { item in
                SavedMenuItemRow(
                    item: item,
                    isSelected: selectedItems.contains(item.id),
                    onToggleSelection: {
                        if selectedItems.contains(item.id) {
                            selectedItems.remove(item.id)
                        } else {
                            selectedItems.insert(item.id)
                        }
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func shareMenu() {
        let summary = """
        \(savedMenu.name)
        
        📊 Menu Analysis:
        • \(savedMenu.items.count) items scanned
        • \(selectedItems.count) items in meal
        • \(Int(currentNutrition.calories ?? 0)) calories total
        • \(Int(currentNutrition.protein ?? 0))g protein
        
        Analyzed with MealMap
        """
        
        print("Sharing menu: \(summary)")
    }
}

struct SavedMenuItemRow: View {
    let item: ValidatedMenuItem
    let isSelected: Bool
    let onToggleSelection: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection circle - only show if item has nutrition data
            if item.isValid {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .green : .gray)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Empty space for failed items
                Circle()
                    .fill(Color.clear)
                    .frame(width: 24, height: 24)
            }
            
            // Content
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.validatedName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if !item.isValid {
                            Text("No nutrition data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Nutrition preview for valid items
                if item.isValid, let nutrition = item.nutritionInfo {
                    HStack(spacing: 16) {
                        if let calories = nutrition.calories {
                            SavedMenuNutritionPreview(label: "Cal", value: "\(Int(calories))", color: .red)
                        }
                        if let protein = nutrition.protein {
                            SavedMenuNutritionPreview(label: "Protein", value: "\(String(format: "%.1f", protein))g", color: .blue)
                        }
                        if let carbs = nutrition.carbs {
                            SavedMenuNutritionPreview(label: "Carbs", value: "\(String(format: "%.1f", carbs))g", color: .orange)
                        }
                        if let fat = nutrition.fat {
                            SavedMenuNutritionPreview(label: "Fat", value: "\(String(format: "%.1f", fat))g", color: .green)
                        }
                        Spacer()
                    }
                    .padding(.leading, 16)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct SavedMenuNutritionPreview: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct SavedMenuNutritionStat: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SavedMenuDetailView(savedMenu: SavedMenuAnalysis(
        id: UUID(),
        name: "Sample Menu",
        dateCreated: Date(),
        items: [],
        selectedItemIds: Set()
    ))
}