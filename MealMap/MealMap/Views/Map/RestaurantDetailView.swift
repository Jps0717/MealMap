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
    @State private var scrollOffset: CGFloat = 0
    @State private var viewState: ViewState = .initializing
    
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
                // Background
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Restaurant Header
                    restaurantHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .background(Color(.systemBackground))
                    
                    // Content based on view state
                    contentView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isPresented = false
                    }) {
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
        .onAppear {
            setupView()
        }
        .onChange(of: nutritionManager.isLoading) { oldValue, newValue in
            updateViewState()
        }
        .onChange(of: nutritionManager.currentRestaurantData) { oldValue, newValue in
            updateViewState()
        }
        .onChange(of: nutritionManager.errorMessage) { oldValue, newValue in
            updateViewState()
        }
    }
    
    // MARK: - Content View
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
                menuContent(restaurantData)
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
    
    // MARK: - Setup and State Management
    private func setupView() {
        hasNutritionData = RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
        
        if hasNutritionData {
            viewState = .loading
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
            if let errorMessage = nutritionManager.errorMessage {
                viewState = .error(errorMessage)
            } else if nutritionManager.isLoading {
                viewState = .loading
            } else if let _ = nutritionManager.currentRestaurantData {
                viewState = .loaded
            } else if hasNutritionData {
                viewState = .loading // Still waiting for data
            } else {
                viewState = .noData
            }
        }
    }
    
    // MARK: - Restaurant Header
    private var restaurantHeader: some View {
        VStack(spacing: 16) {
            HStack {
                // Restaurant Icon
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
                    
                    // Nutrition availability indicator
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
            
            // Category filter indicator if applicable
            if let category = selectedCategory {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .font(.system(size: 14))
                            .foregroundColor(category.color)
                        
                        Text("Filtering by \(category.rawValue)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(category.color)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(category.color.opacity(0.1))
                    )
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - No Data View
    private var noDataView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "info.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("No Nutrition Data")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Unfortunately, we don't have detailed nutrition information for \(restaurant.name) yet.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Text("You can still view restaurant details and location information.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Restaurant info section
            VStack(spacing: 16) {
                if let address = restaurant.address {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        
                        Text(address)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                
                if let phone = restaurant.phone {
                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                        
                        Text(phone)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            VStack(spacing: 12) {
                Text("Unable to Load Menu")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewState = .loading
                }
                nutritionManager.loadNutritionData(for: restaurant.name)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Menu Content
    private func menuContent(_ restaurantData: RestaurantNutritionData) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Menu header with item count
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Menu Items")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            let totalItems = restaurantData.items.count
                            let filteredCount = getFilteredItems(restaurantData.items).count
                            
                            if let category = selectedCategory, filteredCount != totalItems {
                                Text("\(filteredCount) \(category.rawValue.lowercased()) items of \(totalItems) total")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(totalItems) items available")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // View full menu button
                        NavigationLink(destination: NutritionMenuView(
                            restaurantData: restaurantData,
                            selectedCategory: selectedCategory
                        )) {
                            HStack(spacing: 6) {
                                Text("View All")
                                    .font(.system(size: 14, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.blue.opacity(0.1))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Menu items preview
                let itemsToShow = getFilteredItems(restaurantData.items).prefix(10)
                
                if itemsToShow.isEmpty && selectedCategory != nil {
                    // No items match category
                    VStack(spacing: 16) {
                        Image(systemName: selectedCategory?.icon ?? "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(selectedCategory?.color ?? .gray)
                        
                        Text("No \(selectedCategory?.rawValue ?? "Matching") Items")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("This restaurant doesn't have menu items that match the \(selectedCategory?.rawValue.lowercased() ?? "selected") criteria.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        NavigationLink(destination: NutritionMenuView(
                            restaurantData: restaurantData,
                            selectedCategory: nil
                        )) {
                            Text("View All Items")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.blue.opacity(0.1))
                                )
                        }
                    }
                    .padding(.vertical, 40)
                } else {
                    ForEach(Array(itemsToShow), id: \.id) { item in
                        MenuItemCard(item: item, category: selectedCategory)
                            .padding(.horizontal, 20)
                    }
                    
                    // Show more button if there are more items
                    if getFilteredItems(restaurantData.items).count > 10 {
                        NavigationLink(destination: NutritionMenuView(
                            restaurantData: restaurantData,
                            selectedCategory: selectedCategory
                        )) {
                            HStack(spacing: 8) {
                                Text("View \(getFilteredItems(restaurantData.items).count - 10) more items")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.blue)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.blue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                }
                
                // Bottom padding
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 40)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getFilteredItems(_ items: [NutritionData]) -> [NutritionData] {
        guard let category = selectedCategory else { return items }
        
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
}

// MARK: - Menu Item Card
struct MenuItemCard: View {
    let item: NutritionData
    let category: RestaurantCategory?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Item name and calories
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.item)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text("\(Int(item.calories)) calories")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Main metric based on category
                VStack(alignment: .trailing, spacing: 2) {
                    switch category {
                    case .highProtein:
                        Text("\(formatNumber(item.protein))g")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(item.protein >= 20 ? .green : .primary)
                        Text("protein")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            
                    case .lowCarb:
                        Text("\(formatNumber(item.carbs))g")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(item.carbs <= 15 ? .green : .red)
                        Text("carbs")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            
                    default:
                        Text("\(Int(item.calories))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        Text("calories")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Nutrition highlights
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Show relevant nutrition based on category
                    switch category {
                    case .highProtein:
                        NutritionBadge(value: "\(formatNumber(item.protein))g protein", color: .green, highlighted: item.protein >= 20)
                        NutritionBadge(value: "\(formatNumber(item.fat))g fat", color: .orange)
                        
                    case .lowCarb:
                        NutritionBadge(value: "\(formatNumber(item.carbs))g carbs", color: .red, highlighted: item.carbs <= 15)
                        NutritionBadge(value: "\(formatNumber(item.protein))g protein", color: .green)
                        
                    case .healthy:
                        NutritionBadge(value: "\(formatNumber(item.fiber))g fiber", color: .green, highlighted: item.fiber >= 3)
                        NutritionBadge(value: "\(Int(item.sodium))mg sodium", color: .red, highlighted: item.sodium <= 600)
                        
                    case .vegan:
                        NutritionBadge(value: "\(formatNumber(item.fiber))g fiber", color: .green)
                        NutritionBadge(value: "\(formatNumber(item.protein))g protein", color: .mint)
                        
                    default:
                        NutritionBadge(value: "\(formatNumber(item.fat))g fat", color: .orange)
                        NutritionBadge(value: "\(formatNumber(item.protein))g protein", color: .green)
                        NutritionBadge(value: "\(formatNumber(item.carbs))g carbs", color: .blue)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        )
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// Extension for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Nutrition Badge Component
struct NutritionBadge: View {
    let value: String
    let color: Color
    let highlighted: Bool
    
    init(value: String, color: Color, highlighted: Bool = false) {
        self.value = value
        self.color = color
        self.highlighted = highlighted
    }
    
    var body: some View {
        Text(value)
            .font(.system(size: 12, weight: highlighted ? .bold : .medium))
            .foregroundColor(highlighted ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(highlighted ? color : color.opacity(0.1))
            .cornerRadius(6)
            .shadow(color: highlighted ? color.opacity(0.3) : .clear, radius: highlighted ? 2 : 0)
    }
}

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
