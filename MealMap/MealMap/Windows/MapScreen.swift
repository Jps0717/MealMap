import SwiftUI
import MapKit
import CoreLocation

// Make MKCoordinateRegion Equatable so .onChange works
extension MKCoordinateRegion: Equatable {
    public static func == (
        lhs: MKCoordinateRegion,
        rhs: MKCoordinateRegion
    ) -> Bool {
        lhs.center.latitude    == rhs.center.latitude &&
        lhs.center.longitude   == rhs.center.longitude &&
        lhs.span.latitudeDelta  == rhs.span.latitudeDelta &&
        lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}

struct MapScreen: View {
    @ObservedObject var viewModel: MapViewModel
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var networkMonitor  = NetworkMonitor.shared
    @StateObject private var searchManager   = SearchManager()
    
    // UI State
    @State private var searchText           = ""
    @State private var isLoadingView        = true
    @State private var isSearching          = false
    @State private var hasInitialized       = false
    
    // Caching
    @State private var cachedFilteredRestaurants: [Restaurant] = []
    @State private var cacheTimestamp: Date = .distantPast
    
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            if !hasValidLocation {
                LocationErrorView()
            } else if isLoadingView && !hasInitialized {
                MapLoadingView(progress: viewModel.loadingProgress)
            } else {
                MapContentView(
                    viewModel: viewModel,
                    searchText: $searchText,
                    isSearching: $isSearching,
                    cachedRestaurants: cachedFilteredRestaurants,
                    onDismiss: { dismiss() },
                    onSearch:  { performSearch() },
                    onClearSearch: { clearSearch() }
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear { 
            setupMapView()
            
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                if isLoadingView && !hasInitialized {
                    debugLog("⚠️ Map loading timeout, forcing display")
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isLoadingView = false
                        hasInitialized = true
                    }
                }
            }
        }
        .onChange(of: viewModel.isLoadingRestaurants) { _, loading in
            debugLog("🔄 Restaurant loading state changed: \(loading)")
            
            // IMPROVED: Better loading state management
            if !loading {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isLoadingView = false
                        hasInitialized = true
                    }
                    debugLog("✅ Map view displayed")
                }
            }
        }
        .onChange(of: viewModel.restaurants) { _, restaurants in
            debugLog("📍 Restaurants updated: \(restaurants.count) restaurants")
            updateRestaurantCache(for: viewModel.region)
            
            // IMPROVED: Also trigger loading completion when restaurants are available
            if !restaurants.isEmpty && isLoadingView {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isLoadingView = false
                        hasInitialized = true
                    }
                    debugLog("✅ Map view displayed with \(restaurants.count) restaurants")
                }
            }
        }
        .onChange(of: viewModel.region) { _, newRegion in
            updateRestaurantCache(for: newRegion)
        }
        .onChange(of: hasValidLocation) { _, hasLocation in
            debugLog("📍 Location status changed: \(hasLocation)")
            if hasLocation && !hasInitialized {
                setupMapView()
            }
        }
    }
    
    private var hasValidLocation: Bool {
        let hasLocation = locationManager.lastLocation != nil
        let status = locationManager.authorizationStatus
        let isAuthorized = status == .authorizedWhenInUse || status == .authorizedAlways
        
        debugLog("📍 Location check - hasLocation: \(hasLocation), status: \(status), isAuthorized: \(isAuthorized)")
        return hasLocation && isAuthorized
    }
    
    private func setupMapView() {
        debugLog("🎯 Setting up map view...")
        
        // IMPROVED: Better location handling
        if locationManager.authorizationStatus == .notDetermined {
            debugLog("📍 Requesting location permission...")
            locationManager.requestLocationPermission()
        }
        
        if let loc = locationManager.lastLocation {
            debugLog("📍 Using existing location: \(loc.coordinate)")
            viewModel.refreshData(for: loc.coordinate)
        } else {
            debugLog("📍 No location available, using fallback...")
            // IMPROVED: Fallback to a default location (New York)
            let fallbackLocation = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
            viewModel.refreshData(for: fallbackLocation)
        }
    }
    
    private func performSearch() {
        Task { @MainActor in
            isSearching = true
            viewModel.performSearch(query: searchText, maxDistance: nil)
            isSearching = false
        }
    }
    
    private func clearSearch() {
        searchText = ""
        viewModel.clearSearch()
    }
    
    private func updateRestaurantCache(for region: MKCoordinateRegion) {
        let now = Date()
        guard now.timeIntervalSince(cacheTimestamp) > 2.0 else { return }
        let source = viewModel.showSearchResults
            ? viewModel.restaurantsWithinSearchRadius
            : viewModel.allAvailableRestaurants
        cachedFilteredRestaurants = Array(source.prefix(25))
        cacheTimestamp = now
    }
}
