import SwiftUI
import MapKit
import CoreLocation

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Binding var isPresented: Bool
    let selectedCategory: RestaurantCategory?
    @State private var animateIn = false
    @State private var hasNutritionData: Bool = false
    @ObservedObject private var nutritionManager = NutritionDataManager.shared
    @State private var viewState: ViewState = .initializing
    @State private var searchText = ""
    @State private var selectedMenuCategory: MenuCategory = .all
    @State private var showingMenuScanner = false

    enum MenuCategory: String, CaseIterable {
        case all = "All"
        case food = "Food"
        case drinks = "Drinks"
        case desserts = "Desserts"
    }

    enum ViewState {
        case initializing
        case loading
        case loaded
        case noData
        case error(String)
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    restaurantHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .background(Color(.systemBackground))

                    contentView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(restaurant.name)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                }
            }
        }
        .onAppear { setupView() }
        .onChange(of: nutritionManager.isLoading) { _, _ in updateViewState() }
        .onChange(of: nutritionManager.currentRestaurantData) { _, _ in updateViewState() }
        .onChange(of: nutritionManager.errorMessage) { _, _ in updateViewState() }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewState {
        case .initializing, .loading:
            LoadingView(
                title: "Loading Menu...",
                subtitle: "Getting nutrition data for \(restaurant.name)",
                progress: nil,
                style: .fullScreen
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))

        case .loaded:
            if let restaurantData = nutritionManager.currentRestaurantData {
                fullMenuContent(restaurantData)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

        case .noData:
            noDataView
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

        case .error(let message):
            errorView(message: message)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private func setupView() {
        hasNutritionData = RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
        debugLog("🍽️ Opening '\(restaurant.name)' – has nutrition: \(hasNutritionData)")

        if hasNutritionData {
            viewState = .loading
            debugLog("🔄 Loading nutrition for \(restaurant.name)")
            nutritionManager.loadNutritionData(for: restaurant.name)
        } else {
            viewState = .noData
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            animateIn = true
        }
    }

    private func updateViewState() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let error = nutritionManager.errorMessage {
                viewState = .error(error)
            } else if nutritionManager.isLoading {
                viewState = .loading
            } else if nutritionManager.currentRestaurantData != nil {
                viewState = .loaded
            } else if hasNutritionData {
                viewState = .loading
            } else {
                viewState = .noData
            }
        }
    }

    private var restaurantHeader: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 60, height: 60)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    if let cuisine = restaurant.cuisine {
                        Text(cuisine.capitalized)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        if hasNutritionData {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text("Nutrition data available")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("No nutrition data")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
                Spacer()
            }

            if let category = selectedCategory {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(category.color)
                    Text("Filtering by \(category.rawValue)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(category.color)
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(category.color.opacity(0.1)))
            }
        }
    }

    private var noDataView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "info.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("No Nutrition Data")
                .font(.system(size: 24, weight: .bold))
            Text("We don't have detailed nutrition for \(restaurant.name).")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            // ENHANCED: Add Scan Menu button
            VStack(spacing: 16) {
                Button {
                    showingMenuScanner = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan Menu")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Take a photo to analyze nutrition")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)], 
                            startPoint: .leading, 
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                
                Text("✨ Get instant nutrition analysis for any menu item")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                
                // Restaurant info cards
                VStack(spacing: 12) {
                    if let address = restaurant.address {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(address)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    }
                    if let phone = restaurant.phone {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.green)
                            Text(phone)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    }
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .sheet(isPresented: $showingMenuScanner) {
            MenuPhotoCaptureView()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Unable to Load Menu")
                .font(.system(size: 24, weight: .bold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Button {
                viewState = .loading
                nutritionManager.loadNutritionData(for: restaurant.name)
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .padding()
                .background(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            Spacer()
        }
    }

    private func fullMenuContent(_ data: RestaurantNutritionData) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Picker("Menu Category", selection: $selectedMenuCategory) {
                    ForEach(MenuCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search menu items...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            List(filteredItems(from: data.items)) { item in
                NavigationLink {
                    MenuItemDetailView(item: item)
                } label: {
                    MenuItemCard(item: item, category: selectedCategory)
                        .padding(.vertical, 4)
                }
                .listRowBackground(Color(.systemBackground))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func filteredItems(from items: [NutritionData]) -> [NutritionData] {
        var list = items
        
        list = filterByMenuCategory(list, category: selectedMenuCategory)
        
        if let cat = selectedCategory {
            list = filterItemsByCategory(list, category: cat)
        }
        if !searchText.isEmpty {
            list = list.filter { $0.item.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }

    private func filterByMenuCategory(_ items: [NutritionData], category: MenuCategory) -> [NutritionData] {
        switch category {
        case .all:
            return items
        case .food:
            return items.filter { !isDrink($0) && !isDessert($0) }
        case .drinks:
            return items.filter { isDrink($0) }
        case .desserts:
            return items.filter { isDessert($0) }
        }
    }
    
    private func isDrink(_ item: NutritionData) -> Bool {
        let drinkKeywords = ["coffee", "latte", "cappuccino", "espresso", "tea", "smoothie", "shake", 
                           "juice", "soda", "cola", "drink", "water", "milk", "hot chocolate", 
                           "frappuccino", "refresher", "iced", "cold brew", "macchiato", "mocha"]
        let itemLower = item.item.lowercased()
        return drinkKeywords.contains { itemLower.contains($0) }
    }
    
    private func isDessert(_ item: NutritionData) -> Bool {
        let dessertKeywords = ["cookie", "cake", "pie", "donut", "doughnut", "muffin", "brownie", 
                             "ice cream", "sundae", "froyo", "parfait", "cheesecake", "cupcake",
                             "danish", "pastry", "scone", "cinnamon roll", "sweet", "dessert",
                             "chocolate chip", "fudge", "caramel", "vanilla", "strawberry"]
        let itemLower = item.item.lowercased()
        return dessertKeywords.contains { itemLower.contains($0) }
    }

    private func filterItemsByCategory(_ items: [NutritionData], category: RestaurantCategory) -> [NutritionData] {
        switch category {
        case .fastFood: return items
        case .healthy: return items.filter { $0.sodium <= 600 && $0.fiber >= 3 && $0.calories <= 500 }
        case .highProtein: return items.filter { $0.protein >= 20 }
        case .lowCarb: return items.filter { $0.carbs <= 15 }
        }
    }
}

// MARK: - Menu Item Card

struct MenuItemCard: View {
    let item: NutritionData
    let category: RestaurantCategory?

    private var isHighCalories: Bool { item.calories > 800 }
    private var isHighSodium:  Bool { item.sodium  > 1000 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.item)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                    Text("\(Int(item.calories)) calories")
                        .foregroundColor(isHighCalories ? .red : .secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(item.calories))")
                        .bold()
                        .foregroundColor(isHighCalories ? .red : .primary)
                    Text("cal").font(.caption)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    NutritionBadge(
                        value: "\(Int(item.sodium))mg sodium",
                        highlighted: isHighSodium
                    )
                    NutritionBadge(value: "\(format(item.fat))g fat")
                    NutritionBadge(value: "\(format(item.protein))g protein")
                    NutritionBadge(value: "\(format(item.carbs))g carbs")
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        )
    }

    private func format(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

// MARK: - Nutrition Badge

struct NutritionBadge: View {
    let value: String
    let highlighted: Bool

    init(value: String, highlighted: Bool = false) {
        self.value = value
        self.highlighted = highlighted
    }

    var body: some View {
        Text(value)
            .font(.caption2)
            .foregroundColor(highlighted ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(highlighted ? Color.red : Color.gray.opacity(0.2))
            .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    RestaurantDetailView(
        restaurant: Restaurant(
            id: 1,
            name: "Krispy Kreme",
            latitude: 37.7749,
            longitude: -122.4194,
            address: "123 Main St",
            cuisine: "Donut",
            openingHours: "6:00 AM - 11:00 PM",
            phone: "+1-555-123-4567",
            website: "https://krispykreme.com",
            type: "node"
        ),
        isPresented: .constant(true),
        selectedCategory: .fastFood
    )
}