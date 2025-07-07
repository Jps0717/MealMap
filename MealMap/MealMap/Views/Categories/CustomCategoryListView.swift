import SwiftUI

struct CustomCategoryListView: View {
    let userCategory: UserCategory
    @Binding var isPresented: Bool
    
    @StateObject private var mapViewModel = MapViewModel()
    @State private var restaurants: [Restaurant] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading restaurants...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if restaurants.isEmpty {
                VStack(spacing: 16) {
                    Text(userCategory.icon)
                        .font(.system(size: 60))
                    
                    Text("No restaurants found")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Try adjusting your filters or check back later")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(restaurants) { restaurant in
                    NavigationLink(destination: RestaurantDetailView(
                        restaurant: restaurant,
                        isPresented: .constant(true),
                        selectedCategory: nil
                    )) {
                        RestaurantRow(restaurant: restaurant)
                    }
                }
            }
        }
        .navigationTitle(userCategory.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadRestaurants()
        }
    }
    
    private func loadRestaurants() {
        // Simulate loading restaurants based on custom filters
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // For now, return empty array. In real implementation,
            // this would filter restaurants based on userCategory.customFilters
            restaurants = []
            isLoading = false
        }
    }
}

struct RestaurantRow: View {
    let restaurant: Restaurant
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(restaurant.cuisine ?? "Restaurant")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(restaurant.address ?? "Address not available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        CustomCategoryListView(
            userCategory: UserCategory(
                id: "sample",
                name: "Sample Category",
                icon: "🍕",
                type: .custom,
                order: 0,
                customFilters: ["Under 500 calories"]
            ),
            isPresented: .constant(true)
        )
    }
}