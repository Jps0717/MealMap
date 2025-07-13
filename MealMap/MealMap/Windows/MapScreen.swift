import SwiftUI
import MapKit
import CoreLocation

/// Enhanced MapScreen with proper modal home button navigation - NO FILTERS
struct MapScreen: View {
    // View model and managers - FIXED: Use only the passed viewModel
    @ObservedObject var viewModel: MapViewModel
    @StateObject private var locationManager = LocationManager()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var searchManager = SearchManager()
    
    // ENHANCED: Environment to handle modal dismissal
    @Environment(\.dismiss) private var dismiss
    
    // UI State
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showLocationError = false
    @State private var showingSearch = false
    @State private var showingMenuPhotoCapture = false
    
    // Sheet states
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            if showLocationError {
                LocationErrorView()
            } else {
                // ENHANCED: Map with proper home button dismissal handling
                MapContentView(
                    viewModel: viewModel,
                    searchText: $searchText,
                    isSearching: $isSearching,
                    cachedRestaurants: [],
                    onDismiss: {
                        // ENHANCED: Dismiss the modal when home button is tapped
                        debugLog(" Home button tapped - dismissing map modal")
                        dismiss()
                    },
                    onSearch: performSearch,
                    onClearSearch: clearSearch
                )
            }
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
        .sheet(isPresented: $showingMenuPhotoCapture) {
            MenuPhotoCaptureView()
        }
        .onAppear {
            setupMapView()
        }
        .onChange(of: viewModel.restaurants) { _, restaurants in
            debugLog(" Restaurants updated: \(restaurants.count) restaurants")
            debugLog(" Nutrition restaurants: \(restaurants.filter { $0.hasNutritionData }.count)")
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            debugLog(" Location authorization changed: \(status)")
            handleLocationStatusChange(status)
        }
        // ENHANCED: Hide navigation bar for clean modal presentation
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
    
    private func handleLocationStatusChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted:
            showLocationError = true
        case .notDetermined:
            locationManager.requestLocationPermission()
            showLocationError = false
        case .authorizedWhenInUse, .authorizedAlways:
            showLocationError = false
            if let location = locationManager.lastLocation {
                debugLog(" Location authorized, refreshing data for: \(location.coordinate)")
                viewModel.refreshData(for: location.coordinate)
            }
        @unknown default:
            showLocationError = true
        }
    }
    
    private func setupMapView() {
        debugLog(" Setting up enhanced modal map view...")
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            debugLog(" Requesting location permission...")
            locationManager.requestLocationPermission()
        case .denied, .restricted:
            debugLog(" Location access denied")
            showLocationError = true
        case .authorizedWhenInUse, .authorizedAlways:
            debugLog(" Location authorized")
            showLocationError = false
            if let loc = locationManager.lastLocation {
                debugLog(" Using existing location: \(loc.coordinate)")
                viewModel.refreshData(for: loc.coordinate)
            } else {
                debugLog(" No location available, using fallback...")
                // Fallback to New York
                let fallbackLocation = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
                viewModel.refreshData(for: fallbackLocation)
            }
        @unknown default:
            showLocationError = true
        }
    }
    
    private func performSearch() {
        Task { @MainActor in
            guard !searchText.isEmpty else { return }
            isSearching = true
            
            debugLog(" Performing search for: '\(searchText)'")
            await viewModel.performSearch(query: searchText)
            isSearching = false
        }
    }
    
    private func clearSearch() {
        debugLog(" Clearing search")
        searchText = ""
        viewModel.clearSearch()
        isSearching = false
    }
    
    private func selectRestaurant(_ restaurant: Restaurant) {
        debugLog(" Restaurant selected: \(restaurant.name)")
        selectedRestaurant = restaurant
        showingRestaurantDetail = true
    }
    
    private func mapHeaderView() -> some View {
        HStack {
            Spacer()
            
            Button(action: {
                showingMenuPhotoCapture = true
            }) {
                Image(systemName: "camera.metering.center.weighted")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    MapScreen(viewModel: MapViewModel())
}