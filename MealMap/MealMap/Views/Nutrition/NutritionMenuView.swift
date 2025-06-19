import SwiftUI

struct NutritionMenuView: View {
    let restaurantData: RestaurantNutritionData
    let selectedCategory: RestaurantCategory?
    @State private var searchText = ""
    @State private var selectedItem: NutritionData?
    @State private var showingItemDetail = false
    @State private var showCategoryFilterOnly = true
    @State private var isProcessingFilter = false
    
    // UPDATE: Enhanced filtering with category support
    private var filteredItems: [NutritionData] {
        var items = restaurantData.items
        
        // Apply category filter if enabled
        if showCategoryFilterOnly, let category = selectedCategory {
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
        case .vegan:
            return items.filter { item in
                let itemName = item.item.lowercased()
                let nonVeganKeywords = ["chicken", "beef", "bacon", "cheese", "mayo", "milk", "egg", "butter", "cream"]
                return !nonVeganKeywords.contains { itemName.contains($0) }
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
                if let category = selectedCategory {
                    VStack(spacing: 12) {
                        HStack {
                            Toggle(isOn: Binding(
                                get: { showCategoryFilterOnly },
                                set: { newValue in
                                    isProcessingFilter = true
                                    showCategoryFilterOnly = newValue
                                    
                                    // Add small delay to show processing
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        isProcessingFilter = false
                                    }
                                }
                            )) {
                                HStack(spacing: 8) {
                                    Image(systemName: category.icon)
                                        .foregroundColor(category.color)
                                    Text("Show only \(category.rawValue.lowercased()) items")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: category.color))
                        }
                        .padding(.horizontal)
                        
                        if isProcessingFilter {
                            LoadingView(
                                title: "Filtering items...",
                                style: .compact
                            )
                            .padding(.horizontal)
                        } else if showCategoryFilterOnly {
                            HStack {
                                Text("\(filteredItems.count) items match \(category.rawValue.lowercased()) criteria")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search menu items...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                .padding(.top, selectedCategory == nil ? 16 : 8)
                
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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.item)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // UPDATE: Category-specific nutrition highlights
                HStack(spacing: 16) {
                    Label("\(Int(item.calories))", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    // Show relevant nutrition based on category
                    switch category {
                    case .highProtein:
                        Label("\(formatNumber(item.protein))g protein", systemImage: "figure.strengthtraining.traditional")
                            .font(.caption)
                            .foregroundColor(item.protein >= 20 ? .green : .secondary)
                            .fontWeight(item.protein >= 20 ? .bold : .regular)
                        
                    case .lowCarb:
                        Label("\(formatNumber(item.carbs))g carbs", systemImage: "minus.circle.fill")
                            .font(.caption)
                            .foregroundColor(item.carbs <= 15 ? .green : .red)
                            .fontWeight(item.carbs <= 15 ? .bold : .regular)
                        
                    case .healthy:
                        Label("\(formatNumber(item.fiber))g fiber", systemImage: "leaf.fill")
                            .font(.caption)
                            .foregroundColor(item.fiber >= 3 ? .green : .secondary)
                            .fontWeight(item.fiber >= 3 ? .bold : .regular)
                            
                        Label("\(Int(item.sodium))mg sodium", systemImage: "drop.fill")
                            .font(.caption)
                            .foregroundColor(item.sodium <= 600 ? .green : .red)
                            .fontWeight(item.sodium <= 600 ? .bold : .regular)
                        
                    case .vegan:
                        Label("\(formatNumber(item.fiber))g fiber", systemImage: "leaf.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            
                        Label("\(formatNumber(item.protein))g protein", systemImage: "figure.strengthtraining.traditional")
                            .font(.caption)
                            .foregroundColor(.mint)
                        
                    default:
                        Label("\(formatNumber(item.fat))g fat", systemImage: "drop.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Label("\(formatNumber(item.protein))g protein", systemImage: "figure.strengthtraining.traditional")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            // UPDATE: Show category-relevant main metric
            VStack(alignment: .trailing) {
                switch category {
                case .highProtein:
                    Text("\(formatNumber(item.protein))g")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(item.protein >= 20 ? .green : .primary)
                    Text("protein")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                case .lowCarb:
                    Text("\(formatNumber(item.carbs))g")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(item.carbs <= 15 ? .green : .red)
                    Text("carbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                default:
                    Text("\(Int(item.calories))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.1f", value)
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
