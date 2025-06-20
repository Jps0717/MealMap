import SwiftUI
import MapKit
import CoreLocation

struct MapContentView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    let cachedRestaurants: [Restaurant]
    let onDismiss: () -> Void
    let onSearch: () -> Void
    let onClearSearch: () -> Void
    
    var body: some View {
        // Use the new enhanced map view with real-time loading
        EnhancedMapView(
            viewModel: viewModel,
            searchText: $searchText,
            isSearching: $isSearching,
            onDismiss: onDismiss,
            onSearch: onSearch,
            onClearSearch: onClearSearch
        )
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
