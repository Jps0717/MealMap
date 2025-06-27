import SwiftUI
import CoreLocation

struct CategoryListView: View {
    let category: RestaurantCategory
    let restaurants: [Restaurant]
    @Binding var isPresented: Bool
    
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    @State private var isLoadingView = true
    @State private var isSearching = false
    @State private var searchText = ""
    
    // UPDATED: Simple alphabetical sorting with search filter only
    private var filteredRestaurants: [Restaurant] {
        var result = restaurants
        
        // Apply search text filter
        if !searchText.isEmpty {
            result = result.filter { restaurant in
                restaurant.name.localizedCaseInsensitiveContains(searchText) ||
                (restaurant.cuisine?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // UPDATED: Sort alphabetically by restaurant name
        return result.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if isLoadingView {
                    CategoryLoadingView(category: category)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    mainContent
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .navigationTitle(category.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoadingView {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: category.color))
                    } else {
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingRestaurantDetail) {
            if let restaurant = selectedRestaurant {
                RestaurantDetailView(
                    restaurant: restaurant,
                    isPresented: $showingRestaurantDetail,
                    selectedCategory: category
                )
                .preferredColorScheme(.light)
            }
        }
        .onAppear {
            setupCategoryView()
        }
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty && oldValue.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSearching = true
                }
                
                // Simulate search processing time
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSearching = false
                    }
                }
            } else if newValue.isEmpty {
                isSearching = false
            }
        }
    }
    
    // MARK: - Setup
    private func setupCategoryView() {
        // Simulate loading time for smooth UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoadingView = false
            }
        }
    }
    
    // MARK: - Main Content - SIMPLIFIED: No filters, just search and alphabetical list
    private var mainContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                // Search bar only
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                    
                    TextField("Search \(category.rawValue.lowercased()) restaurants...", text: $searchText)
                        .font(.system(size: 16))
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: category.color))
                    } else if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color(.systemBackground))
            
            // UPDATED: Simple results count (no filter indicators)
            HStack {
                if isSearching {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .progressViewStyle(CircularProgressViewStyle(tint: category.color))
                        Text("Searching...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(category.color)
                    }
                } else {
                    Text("\(filteredRestaurants.count) restaurants")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if !searchText.isEmpty {
                        Text("• Sorted A-Z")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            // UPDATED: Simple restaurant list - no complex loading states
            if restaurants.isEmpty {
                LoadingView(
                    title: "Loading \(category.rawValue)",
                    subtitle: "Finding restaurants...",
                    progress: nil,
                    style: .fullScreen
                )
            } else if filteredRestaurants.isEmpty && !searchText.isEmpty {
                // Simple empty search results
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(category.color.opacity(0.6))
                    
                    VStack(spacing: 8) {
                        Text("No matches found")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Try searching for a different restaurant name.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                }
            } else {
                List(filteredRestaurants, id: \.id) { restaurant in
                    SimpleCategoryRestaurantRow(
                        restaurant: restaurant,
                        action: {
                            selectedRestaurant = restaurant
                            showingRestaurantDetail = true
                        },
                        category: category
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

// UPDATED: Simplified restaurant row with consistent category styling
struct SimpleCategoryRestaurantRow: View {
    let restaurant: Restaurant
    let action: () -> Void
    let category: RestaurantCategory  // Use this for consistent styling
    
    @ObservedObject private var nutritionManager = NutritionDataManager.shared
    @State private var isPressed = false
    @State private var isPreloading = false
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(spacing: 16) {
                // UPDATED: All restaurants in category use same icon and colors
                RoundedRectangle(cornerRadius: 12)
                    .fill(category.color.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        VStack(spacing: 2) {
                            Image(systemName: category.icon)
                                .font(.system(size: 16))
                                .foregroundColor(category.color)
                            
                            if RestaurantData.hasNutritionData(for: restaurant.name) {
                                if isPreloading {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(category.color, lineWidth: 2)
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(restaurant.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // UPDATED: All restaurants show same category badge
                        Text(category.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(category.color)
                            )
                    }
                    
                    if let cuisine = restaurant.cuisine {
                        Text(cuisine.capitalized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // UPDATED: Simple nutrition indicator only (no distance)
                    HStack(spacing: 8) {
                        if RestaurantData.hasNutritionData(for: restaurant.name) {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                Text(isPreloading ? "Loading..." : "Nutrition")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    if isPreloading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    
                    // UPDATED: All restaurants show same category color dot
                    Circle()
                        .fill(category.color)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
            .overlay(
                HStack {
                    // UPDATED: All restaurants show same category color accent
                    RoundedRectangle(cornerRadius: 2)
                        .fill(category.color)
                        .frame(width: 4)
                    Spacer()
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isPreloading ? 0.8 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isPreloading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing && !isPreloading
            }
        }, perform: {})
        .onChange(of: nutritionManager.isLoading) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                isPreloading = newValue
            }
        }
    }
}

#Preview {
    CategoryListView(
        category: .fastFood,
        restaurants: [],
        isPresented: .constant(true)
    )
}
