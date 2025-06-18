import SwiftUI
import CoreLocation

struct CategoryListView: View {
    let category: RestaurantCategory
    let restaurants: [Restaurant]
    @Binding var isPresented: Bool
    
    @StateObject private var locationManager = LocationManager.shared
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    
    // PERFORMANCE: Cache sorted restaurants
    @State private var sortedRestaurants: [Restaurant] = []
    
    // Haptic feedback
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    
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
                
                VStack(spacing: 0) {
                    // Header with category info
                    categoryHeader
                    
                    if sortedRestaurants.isEmpty {
                        // Empty state
                        emptyStateView
                    } else {
                        // PERFORMANCE: Use LazyVStack for better scrolling
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(sortedRestaurants, id: \.id) { restaurant in
                                    CategoryRestaurantCard(
                                        restaurant: restaurant,
                                        category: category
                                    ) {
                                        selectRestaurant(restaurant)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // FORCED: Always use light appearance
            .preferredColorScheme(.light)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showingRestaurantDetail) {
            if let restaurant = selectedRestaurant {
                RestaurantDetailView(
                    restaurant: restaurant,
                    isPresented: $showingRestaurantDetail
                )
                .preferredColorScheme(.light) // Force light mode in restaurant detail
            }
        }
        .onAppear {
            // PERFORMANCE: Sort restaurants once when view appears
            sortRestaurants()
        }
    }
    
    // MARK: - Category Header
    private var categoryHeader: some View {
        VStack(spacing: 16) {
            HStack {
                // Category icon and info
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(category.color.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(category.color)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.rawValue)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("\(sortedRestaurants.count) restaurant\(sortedRestaurants.count == 1 ? "" : "s") found")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    if !sortedRestaurants.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            
                            Text("Sorted by distance")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Category description
            Text(getCategoryDescription(category))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: category.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(category.color.opacity(0.6))
            }
            
            VStack(spacing: 12) {
                Text("No \(category.rawValue) Found")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("We couldn't find any \(category.rawValue.lowercased()) restaurants in your area. Try expanding your search radius or check back later.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    private func selectRestaurant(_ restaurant: Restaurant) {
        mediumFeedback.impactOccurred()
        selectedRestaurant = restaurant
        showingRestaurantDetail = true
    }
    
    // PERFORMANCE: Sort restaurants once instead of computing every time
    private func sortRestaurants() {
        guard let userLocation = locationManager.lastLocation else {
            sortedRestaurants = restaurants
            return
        }
        
        sortedRestaurants = restaurants.sorted { restaurant1, restaurant2 in
            let distance1 = calculateDistance(
                from: userLocation.coordinate,
                to: CLLocationCoordinate2D(latitude: restaurant1.latitude, longitude: restaurant1.longitude)
            )
            let distance2 = calculateDistance(
                from: userLocation.coordinate,
                to: CLLocationCoordinate2D(latitude: restaurant2.latitude, longitude: restaurant2.longitude)
            )
            return distance1 < distance2
        }
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    private func getCategoryDescription(_ category: RestaurantCategory) -> String {
        switch category {
        case .fastFood:
            return "Quick service restaurants with nutrition data available"
        case .healthy:
            return "Restaurants focused on fresh, nutritious options"
        case .vegan:
            return "Plant-based and vegan-friendly dining options"
        case .highProtein:
            return "Restaurants specializing in protein-rich meals"
        case .lowCarb:
            return "Low-carb and keto-friendly dining options"
        }
    }
}

// MARK: - Category Restaurant Card
struct CategoryRestaurantCard: View {
    let restaurant: Restaurant
    let category: RestaurantCategory
    let action: () -> Void
    
    @StateObject private var locationManager = LocationManager.shared
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Restaurant image placeholder with category color
                RoundedRectangle(cornerRadius: 16)
                    .fill(category.color.opacity(0.1))
                    .frame(width: 70, height: 70)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(category.color)
                            
                            if RestaurantData.restaurantsWithNutritionData.contains(restaurant.name) {
                                HStack(spacing: 2) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.green)
                                    Text("Nutrition")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(restaurant.name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let cuisine = restaurant.cuisine {
                        Text(cuisine.capitalized)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 16) {
                        // Distance
                        if let userLocation = locationManager.lastLocation {
                            let distance = calculateDistance(
                                from: userLocation.coordinate,
                                to: CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
                            )
                            
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                
                                Text(formatDistance(distance))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Category relevance indicator
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12))
                                .foregroundColor(category.color)
                            
                            Text(category.rawValue)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(category.color)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(category.color.opacity(0.1))
                        )
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        let miles = distance / 1609.34
        if miles < 0.1 {
            return "< 0.1 mi"
        } else if miles < 1.0 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.1f mi", miles)
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
