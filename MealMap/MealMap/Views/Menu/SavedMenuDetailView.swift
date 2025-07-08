import SwiftUI

struct SavedMenuDetailView: View {
    let savedMenu: SavedMenuAnalysis
    @Environment(\.dismiss) private var dismiss
    @StateObject private var savedMenuManager = SavedMenuManager.shared
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header info
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(savedMenu.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(savedMenu.displaySummary)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("Saved \(savedMenu.formattedDate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(savedMenu.successRate)%")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(savedMenu.successRate > 80 ? .green : savedMenu.successRate > 50 ? .orange : .red)
                                
                                Text("Success Rate")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Stats row
                        HStack(spacing: 20) {
                            SavedStatView(title: "Items", value: "\(savedMenu.items.count)")
                            SavedStatView(title: "Selected", value: "\(savedMenu.itemCount)")
                            SavedStatView(title: "Calories", value: "\(Int(savedMenu.totalCalories))")
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Menu items
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Menu Items")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(savedMenu.selectedItems) { item in
                                SavedMenuItemDetailRow(item: item)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 32)
                }
                .padding(.vertical)
            }
            .navigationTitle("Menu Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .alert("Delete Menu Analysis", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                savedMenuManager.deleteMenu(savedMenu)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this menu analysis? This action cannot be undone.")
        }
    }
}

struct SavedStatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SavedMenuItemDetailRow: View {
    let item: ValidatedMenuItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.validatedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Spacer()
                
                if item.isValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                }
            }
            
            if item.isValid, let nutrition = item.nutritionInfo {
                HStack(spacing: 16) {
                    SavedNutritionBadge(label: "Cal", value: "\(Int(nutrition.calories ?? 0))")
                    SavedNutritionBadge(label: "Protein", value: "\(Int(nutrition.protein ?? 0))g")
                    SavedNutritionBadge(label: "Carbs", value: "\(Int(nutrition.carbs ?? 0))g")
                    SavedNutritionBadge(label: "Fat", value: "\(Int(nutrition.fat ?? 0))g")
                    
                    Spacer()
                }
            } else {
                Text("Analysis failed")
                    .font(.caption)
                    .foregroundColor(.red)
                    .italic()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
}

struct SavedNutritionBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    SavedMenuDetailView(
        savedMenu: SavedMenuAnalysis(
            id: UUID(),
            name: "Sample Menu",
            dateCreated: Date(),
            items: [],
            selectedItemIds: Set<UUID>()
        )
    )
}