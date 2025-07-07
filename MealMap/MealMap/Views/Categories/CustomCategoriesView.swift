import SwiftUI

struct CustomCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var mainCategoryManager = MainCategoryManager.shared
    
    @State private var showingAddCategory = false
    @State private var isEditingMy = false
    
    private let maxCategories = 3
    
    var body: some View {
        NavigationView {
            List {
                myCategoriesSection
                additionalCategoriesSection
                addCategorySection
            }
            .navigationTitle("More Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticService.shared.sheetDismiss()
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySelectionView(
                isPresented: $showingAddCategory,
                onAddPreset: { availableCategory in
                    mainCategoryManager.addCategory(availableCategory)
                },
                onAddCustom: { name, icon, filters in
                    mainCategoryManager.addCustomCategory(name: name, icon: icon, filters: filters)
                }
            )
        }
    }
    
    private var myCategoriesSection: some View {
        Section {
            ForEach(mainCategoryManager.myCategories) { category in
                MyCategoryRow(
                    category: category,
                    isEditing: isEditingMy,
                    canDelete: mainCategoryManager.myCategories.count > 1,
                    onDelete: {
                        print("🔴 CustomCategoriesView: Delete button tapped for category: \(category.name) (ID: \(category.id))")
                        HapticService.shared.delete()
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            mainCategoryManager.removeCategory(category.id)
                        }
                    }
                )
            }
        } header: {
            HStack {
                Text("My Categories")
                Spacer()
                Button(isEditingMy ? "Done" : "Edit") {
                    HapticService.shared.toggle()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditingMy.toggle()
                    }
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            }
        } footer: {
            if isEditingMy {
                Text("These are your main categories shown on the home screen (maximum \(maxCategories)). You must keep at least one category.")
            } else {
                Text("Your personalized categories for quick access.")
            }
        }
    }
    
    private var additionalCategoriesSection: some View {
        Group {
            let availableToAdd = mainCategoryManager.getAvailableCategoriesNotInMy()
            if !availableToAdd.isEmpty {
                Section("Available Categories") {
                    ForEach(availableToAdd) { category in
                        AvailableCategoryRow(
                            category: category,
                            isEditing: isEditingMy,
                            canAdd: mainCategoryManager.myCategories.count < maxCategories,
                            onAdd: {
                                HapticService.shared.create()
                                mainCategoryManager.addCategory(category)
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var addCategorySection: some View {
        Section {
            if mainCategoryManager.myCategories.count < maxCategories && !isEditingMy {
                Button(action: {
                    HapticService.shared.create()
                    showingAddCategory = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Create Custom Category")
                            .foregroundColor(.blue)
                    }
                }
            } else if mainCategoryManager.myCategories.count >= maxCategories && !isEditingMy {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Maximum \(maxCategories) categories reached")
                        .foregroundColor(.secondary)
                }
            } else if isEditingMy && mainCategoryManager.myCategories.count < maxCategories {
                Button(action: {
                    HapticService.shared.create()
                    showingAddCategory = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.purple)
                        Text("Create Custom Category")
                            .foregroundColor(.purple)
                    }
                }
            }
        } footer: {
            if isEditingMy {
                Text("Use the green + buttons above to add preset categories, or create a custom category here.")
            } else if mainCategoryManager.myCategories.count < maxCategories {
                Text("Add preset categories or create custom ones based on your preferences.")
            } else {
                Text("Remove a category to add a new one.")
            }
        }
    }
}

// MARK: - Row Views

struct MyCategoryRow: View {
    let category: UserCategory
    let isEditing: Bool
    let canDelete: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(category.icon)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(categoryTypeDescription)
                    .font(.caption)
                    .foregroundColor(categoryTypeColor)
            }
            
            Spacer()
            
            if isEditing && canDelete {
                Button(action: {
                    print("🔴 MyCategoryRow: Minus button tapped for \(category.name)")
                    onDelete()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            } else if isEditing && !canDelete {
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title2)
            } else if !isEditing {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                HapticService.shared.cardTap()
                // Navigate to category view
            }
        }
    }
    
    private var categoryTypeDescription: String {
        switch category.type {
        case .main:
            return "Main category"
        case .additional:
            return "Added category"
        case .custom:
            return "Custom category"
        }
    }
    
    private var categoryTypeColor: Color {
        switch category.type {
        case .main:
            return .blue
        case .additional:
            return .green
        case .custom:
            return .purple
        }
    }
}

struct AvailableCategoryRow: View {
    let category: AvailableCategory
    let isEditing: Bool
    let canAdd: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            Text(category.icon)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if isEditing && canAdd {
                    Text("Tap to add")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if isEditing && !canAdd {
                    Text("Remove a category first")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("Available to add")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isEditing && canAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            } else if isEditing && !canAdd {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing && canAdd {
                onAdd()
            } else if !isEditing {
                HapticService.shared.cardTap()
                // Navigate to category view
            }
        }
    }
}

// MARK: - Add Category Selection View

struct AddCategorySelectionView: View {
    @Binding var isPresented: Bool
    let onAddPreset: (AvailableCategory) -> Void
    let onAddCustom: (String, String, [String]) -> Void
    
    @State private var showingCustomCategory = false
    @StateObject private var mainCategoryManager = MainCategoryManager.shared
    
    var body: some View {
        NavigationView {
            List {
                let availableCategories = mainCategoryManager.getAvailableCategoriesNotInMy()
                
                if !availableCategories.isEmpty {
                    Section("Preset Categories") {
                        ForEach(availableCategories) { category in
                            Button(action: {
                                HapticService.shared.create()
                                onAddPreset(category)
                                isPresented = false
                            }) {
                                HStack {
                                    Text(category.icon)
                                        .font(.title2)
                                        .frame(width: 40, height: 40)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(10)
                                    
                                    Text(category.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section("Custom Category") {
                    Button(action: {
                        HapticService.shared.create()
                        showingCustomCategory = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.purple)
                            Text("Create Custom Category")
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingCustomCategory) {
            CustomCategoryCreationView(
                isPresented: $showingCustomCategory,
                onSave: { name, icon, filters in
                    onAddCustom(name, icon, filters)
                    isPresented = false
                }
            )
        }
    }
}

// MARK: - Custom Category Creation View

struct CustomCategoryCreationView: View {
    @Binding var isPresented: Bool
    let onSave: (String, String, [String]) -> Void
    
    @State private var categoryName = ""
    @State private var selectedIcon = "🍽️"
    @State private var selectedFilters: [String] = []
    
    private let availableIcons = ["🍽️", "🍕", "🌮", "🍜", "🍱", "🥗", "🍰", "☕", "🥤", "🍔", "🌶️", "🥘"]
    private let availableFilters = [
        "Under 500 calories",
        "High fiber",
        "Low sodium",
        "Dairy-free",
        "Spicy",
        "Breakfast",
        "Lunch",
        "Dinner",
        "Dessert",
        "Beverage"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                categoryNameSection
                iconSelectionSection
                filtersSection
            }
            .navigationTitle("Custom Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(categoryName, selectedIcon, selectedFilters)
                        HapticService.shared.create()
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
        }
    }
    
    private var categoryNameSection: some View {
        Section {
            TextField("Category Name", text: $categoryName)
        } header: {
            Text("Name")
        } footer: {
            Text("Give your category a descriptive name")
        }
    }
    
    private var iconSelectionSection: some View {
        Section("Icon") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(availableIcons, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                        HapticService.shared.selectionChanged()
                    }) {
                        Text(icon)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var filtersSection: some View {
        Section {
            ForEach(availableFilters, id: \.self) { filter in
                HStack {
                    Text(filter)
                    Spacer()
                    if selectedFilters.contains(filter) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedFilters.contains(filter) {
                        selectedFilters.removeAll { $0 == filter }
                        HapticService.shared.lightImpact()
                    } else {
                        selectedFilters.append(filter)
                        HapticService.shared.selectionChanged()
                    }
                }
            }
        } header: {
            Text("Filters")
        } footer: {
            Text("Select criteria to filter restaurants and menu items")
        }
    }
}

#Preview {
    CustomCategoriesView()
}