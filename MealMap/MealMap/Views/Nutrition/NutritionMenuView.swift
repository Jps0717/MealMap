import SwiftUI

struct NutritionMenuView: View {
    let restaurantData: RestaurantNutritionData
    @State private var searchText = ""
    @State private var selectedItem: NutritionData?
    @State private var showingItemDetail = false
    
    private var filteredItems: [NutritionData] {
        if searchText.isEmpty {
            return restaurantData.items
        } else {
            return restaurantData.items.filter { item in
                item.item.localizedCaseInsensitiveContains(searchText)
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
                .padding(.top)
                
                // Menu items list
                List(filteredItems) { item in
                    MenuItemRow(item: item)
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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.item)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    Label("\(Int(item.calories))", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Label("\(formatNumber(item.fat))g fat", systemImage: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Label("\(formatNumber(item.protein))g protein", systemImage: "figure.strengthtraining.traditional")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(item.calories))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("calories")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    
    NutritionMenuView(restaurantData: sampleData)
}