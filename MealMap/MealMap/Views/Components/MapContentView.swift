import SwiftUI
import MapKit

/// Enhanced MapContentView with immediate restaurant detail on pin tap
struct MapContentView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    let cachedRestaurants: [Restaurant]
    let onDismiss: () -> Void
    let onSearch: () -> Void
    let onClearSearch: () -> Void
    
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    
    var body: some View {
        // Use the new enhanced map view with real-time loading
        // FIXED: Use correct parameter order for EnhancedMapView
        ZStack {
            EnhancedMapView(
                viewModel: viewModel,
                searchText: $searchText,
                isSearching: $isSearching,
                onSearch: onSearch,
                onClearSearch: onClearSearch,
                onDismiss: onDismiss
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingRestaurantDetail) {
            if let restaurant = selectedRestaurant {
                RestaurantDetailView(
                    restaurant: restaurant,
                    isPresented: $showingRestaurantDetail,
                    selectedCategory: nil
                )
            }
        }
    }
    
    private func selectRestaurant(_ restaurant: Restaurant) {
        debugLog(" MapContentView: Restaurant selected - \(restaurant.name)")
        selectedRestaurant = restaurant
        showingRestaurantDetail = true
    }
}

// MARK: - Preview
#Preview {
    MapContentView(
        viewModel: MapViewModel(),
        searchText: .constant(""),
        isSearching: .constant(false),
        cachedRestaurants: [],
        onDismiss: {},
        onSearch: {},
        onClearSearch: {}
    )
}
