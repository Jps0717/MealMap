import SwiftUI
import MapKit
import CoreLocation

/// High-performance Apple Maps-style view with incremental loading
struct AppleMapView: View {
    @StateObject private var mapController = AppleMapController()
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var selectedRestaurant: AppleMapRestaurant?
    @State private var showingBottomSheet = false
    @State private var searchText = ""
    @State private var isSearching = false
    
    var body: some View {
        ZStack {
            // Main map view using existing EnhancedMapView
            VStack {
                // Simple header
                HStack {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search restaurants...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                clearSearch()
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Home button
                    Button("Home") {
                        dismissToHome()
                    }
                    .padding(.trailing)
                }
                .padding(.top)
                .background(Color(.systemBackground))
                
                // Map content
                AppleMapContentView(
                    controller: mapController,
                    selectedRestaurant: $selectedRestaurant,
                    onRestaurantTap: { restaurant in
                        selectedRestaurant = restaurant
                        showingBottomSheet = true
                    }
                )
            }
        }
        .sheet(isPresented: $showingBottomSheet) {
            if let restaurant = selectedRestaurant {
                AppleMapRestaurantSheet(
                    restaurant: restaurant,
                    isPresented: $showingBottomSheet
                )
            }
        }
        .onAppear {
            setupInitialLocation()
        }
    }
    
    private func setupInitialLocation() {
        if let location = locationManager.lastLocation?.coordinate {
            mapController.setInitialRegion(center: location)
        } else {
            // Default to user's area or major city
            let defaultLocation = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060) // NYC
            mapController.setInitialRegion(center: defaultLocation)
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        
        Task {
            await mapController.searchRestaurants(query: searchText)
            await MainActor.run {
                isSearching = false
            }
        }
    }
    
    private func clearSearch() {
        searchText = ""
        mapController.clearSearch()
        isSearching = false
    }
    
    private func dismissToHome() {
        // Post notification to dismiss to home screen
        NotificationCenter.default.post(name: NSNotification.Name("DismissMapToHome"), object: nil)
    }
}

/// Simple map content view
struct AppleMapContentView: View {
    @ObservedObject var controller: AppleMapController
    @Binding var selectedRestaurant: AppleMapRestaurant?
    let onRestaurantTap: (AppleMapRestaurant) -> Void
    
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    
    var body: some View {
        Map(
            coordinateRegion: $region,
            interactionModes: .all,
            showsUserLocation: false,
            annotationItems: mapAnnotationItems,
            annotationContent: { item in
                MapAnnotation(coordinate: item.coordinate) {
                    switch item {
                    case .userLocation:
                        UserLocationAnnotationView()
                    case .restaurant(let restaurant):
                        Button(action: {
                            // Convert Restaurant to AppleMapRestaurant for callback
                            let appleRestaurant = AppleMapRestaurant(
                                id: "\(restaurant.id)",
                                name: restaurant.name,
                                coordinate: restaurant.coordinate,
                                category: restaurant.amenityType ?? "restaurant",
                                phoneNumber: restaurant.phone,
                                url: URL(string: restaurant.website ?? ""),
                                mapItem: nil
                            )
                            onRestaurantTap(appleRestaurant)
                        }) {
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.title2)
                                .foregroundColor(restaurant.hasNutritionData ? .green : .orange)
                        }
                    case .cluster:
                        // Simple cluster view
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 30, height: 30)
                    }
                }
            }
        )
        .mapStyle(.standard(pointsOfInterest: []))
        .onAppear {
            if let location = LocationManager.shared.lastLocation?.coordinate {
                controller.setInitialRegion(center: location)
            }
            region = controller.currentRegion
        }
        .onReceive(controller.$currentRegion) { newRegion in
            region = newRegion
        }
    }
    
    private var mapAnnotationItems: [MapItem] {
        var items: [MapItem] = []
        
        // Add user location
        if let userLocation = LocationManager.shared.lastLocation?.coordinate {
            items.append(.userLocation(userLocation))
        }
        
        // Convert AppleMapRestaurant to Restaurant for MapItem compatibility
        let restaurantItems = controller.visibleRestaurants.map { appleRestaurant in
            let restaurant = Restaurant(
                id: Int(appleRestaurant.id.hashValue),
                name: appleRestaurant.name,
                latitude: appleRestaurant.coordinate.latitude,
                longitude: appleRestaurant.coordinate.longitude,
                address: nil,
                cuisine: appleRestaurant.category,
                openingHours: nil,
                phone: appleRestaurant.phoneNumber,
                website: appleRestaurant.url?.absoluteString,
                type: "node"
            )
            return MapItem.restaurant(restaurant)
        }
        items.append(contentsOf: restaurantItems)
        
        return items
    }
}

/// Simple restaurant detail sheet
struct AppleMapRestaurantSheet: View {
    let restaurant: AppleMapRestaurant
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(restaurant.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                if restaurant.hasNutritionData {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Nutrition data available")
                            .foregroundColor(.green)
                    }
                }
                
                Text("Category: \(restaurant.category)")
                    .foregroundColor(.secondary)
                
                if let phone = restaurant.phoneNumber {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text(phone)
                    }
                }
                
                if let url = restaurant.url {
                    Link("Visit Website", destination: url)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Restaurant Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

/// High-performance map controller for incremental loading
@MainActor
final class AppleMapController: ObservableObject {
    @Published var visibleRestaurants: [AppleMapRestaurant] = []
    @Published var currentRegion = MKCoordinateRegion()
    @Published var isLoading = false
    
    private var loadedRegions: Set<RegionKey> = []
    private var allRestaurants: [RegionKey: [AppleMapRestaurant]] = [:]
    private var searchResults: [AppleMapRestaurant] = []
    private var isSearchMode = false
    
    private let localSearch = MKLocalSearch.self
    private var currentSearchTask: Task<Void, Never>?
    
    func setInitialRegion(center: CLLocationCoordinate2D) {
        currentRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        Task {
            await loadRestaurantsForRegion(currentRegion)
        }
    }
    
    func onRegionChanged(_ newRegion: MKCoordinateRegion) {
        currentRegion = newRegion
        
        // Debounce region changes to avoid excessive loading
        currentSearchTask?.cancel()
        currentSearchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            if !Task.isCancelled {
                await loadRestaurantsIncrementally(for: newRegion)
            }
        }
    }
    
    /// INCREMENTAL LOADING: Only load new areas, keep existing pins
    private func loadRestaurantsIncrementally(for region: MKCoordinateRegion) async {
        let currentZoomLevel = getZoomLevel(for: region)
        let regionKeys = getRegionKeys(for: region, zoomLevel: currentZoomLevel)
        
        let newRegionKeys = regionKeys.filter { !loadedRegions.contains($0) }
        
        guard !newRegionKeys.isEmpty else { return }
        
        debugLog("🔄 INCREMENTAL: Loading \(newRegionKeys.count) new regions")
        
        // Load new regions in background
        await withTaskGroup(of: Void.self) { group in
            for regionKey in newRegionKeys {
                group.addTask { [weak self] in
                    await self?.loadRestaurantsForRegionKey(regionKey)
                }
            }
        }
        
        // Update visible restaurants without replacing existing ones
        updateVisibleRestaurants()
    }
    
    private func loadRestaurantsForRegion(_ region: MKCoordinateRegion) async {
        let zoomLevel = getZoomLevel(for: region)
        let regionKeys = getRegionKeys(for: region, zoomLevel: zoomLevel)
        
        debugLog("🗺️ Loading \(regionKeys.count) regions for zoom level \(zoomLevel)")
        
        await withTaskGroup(of: Void.self) { group in
            for regionKey in regionKeys {
                if !loadedRegions.contains(regionKey) {
                    group.addTask { [weak self] in
                        await self?.loadRestaurantsForRegionKey(regionKey)
                    }
                }
            }
        }
        
        updateVisibleRestaurants()
    }
    
    private func loadRestaurantsForRegionKey(_ regionKey: RegionKey) async {
        let searchRegion = MKCoordinateRegion(
            center: regionKey.center,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005) // Small search area
        )
        
        do {
            let restaurants = try await searchAppleMapsFoodAndDrinks(in: searchRegion)
            
            await MainActor.run {
                allRestaurants[regionKey] = restaurants
                loadedRegions.insert(regionKey)
                debugLog("✅ Loaded \(restaurants.count) restaurants for region \(regionKey)")
            }
        } catch {
            debugLog("❌ Failed to load restaurants for region \(regionKey): \(error)")
        }
    }
    
    /// Apple Maps food & drink search using MKLocalSearch
    private func searchAppleMapsFoodAndDrinks(in region: MKCoordinateRegion) async throws -> [AppleMapRestaurant] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurants food drinks coffee"
        request.region = region
        request.resultTypes = [.pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        return response.mapItems.compactMap { mapItem in
            guard let coordinate = mapItem.placemark.location?.coordinate,
                  let name = mapItem.name else { return nil }
            
            return AppleMapRestaurant(
                id: "\(mapItem.hashValue)",
                name: name,
                coordinate: coordinate,
                category: mapItem.pointOfInterestCategory?.rawValue ?? "restaurant",
                phoneNumber: mapItem.phoneNumber,
                url: mapItem.url,
                mapItem: mapItem
            )
        }
    }
    
    func searchRestaurants(query: String) async {
        isSearchMode = true
        isLoading = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = currentRegion
        request.resultTypes = [.pointOfInterest]
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            let results = response.mapItems.compactMap { mapItem -> AppleMapRestaurant? in
                guard let coordinate = mapItem.placemark.location?.coordinate,
                      let name = mapItem.name else { return nil }
                
                return AppleMapRestaurant(
                    id: "\(mapItem.hashValue)_search",
                    name: name,
                    coordinate: coordinate,
                    category: mapItem.pointOfInterestCategory?.rawValue ?? "restaurant",
                    phoneNumber: mapItem.phoneNumber,
                    url: mapItem.url,
                    mapItem: mapItem
                )
            }
            
            searchResults = results
            updateVisibleRestaurants()
            isLoading = false
            
            debugLog("🔍 Search found \(results.count) results for '\(query)'")
        } catch {
            debugLog("❌ Search failed: \(error)")
            isLoading = false
        }
    }
    
    func clearSearch() {
        isSearchMode = false
        searchResults = []
        updateVisibleRestaurants()
    }
    
    private func updateVisibleRestaurants() {
        if isSearchMode {
            visibleRestaurants = searchResults
        } else {
            // Combine all loaded restaurants
            let allLoaded = allRestaurants.values.flatMap { $0 }
            visibleRestaurants = Array(Set(allLoaded)) // Remove duplicates
        }
        
        debugLog("👁️ Visible restaurants: \(visibleRestaurants.count)")
    }
    
    // MARK: - Helper Methods
    
    private func getZoomLevel(for region: MKCoordinateRegion) -> Int {
        let span = region.span.latitudeDelta
        
        if span > 0.1 { return 1 } // City level
        if span > 0.05 { return 2 } // District level  
        if span > 0.01 { return 3 } // Neighborhood level
        return 4 // Street level
    }
    
    private func getRegionKeys(for region: MKCoordinateRegion, zoomLevel: Int) -> Set<RegionKey> {
        let gridSize: Double
        
        switch zoomLevel {
        case 1: gridSize = 0.1
        case 2: gridSize = 0.05
        case 3: gridSize = 0.01
        default: gridSize = 0.005
        }
        
        let centerLat = region.center.latitude
        let centerLon = region.center.longitude
        let spanLat = region.span.latitudeDelta
        let spanLon = region.span.longitudeDelta
        
        var regionKeys: Set<RegionKey> = []
        
        let minLat = centerLat - spanLat / 2
        let maxLat = centerLat + spanLat / 2
        let minLon = centerLon - spanLon / 2
        let maxLon = centerLon + spanLon / 2
        
        var lat = minLat
        while lat <= maxLat {
            var lon = minLon
            while lon <= maxLon {
                let regionCenter = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                regionKeys.insert(RegionKey(center: regionCenter, gridSize: gridSize))
                lon += gridSize
            }
            lat += gridSize
        }
        
        return regionKeys
    }
}

/// Apple Maps restaurant model
struct AppleMapRestaurant: Identifiable, Hashable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: String
    let phoneNumber: String?
    let url: URL?
    let mapItem: MKMapItem?
    
    var hasNutritionData: Bool {
        RestaurantData.hasNutritionData(for: name)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppleMapRestaurant, rhs: AppleMapRestaurant) -> Bool {
        lhs.id == rhs.id
    }
}

/// Region key for incremental loading
struct RegionKey: Hashable {
    let center: CLLocationCoordinate2D
    let gridSize: Double
    
    init(center: CLLocationCoordinate2D, gridSize: Double) {
        // Snap to grid for consistent keys
        let gridLat = round(center.latitude / gridSize) * gridSize
        let gridLon = round(center.longitude / gridSize) * gridSize
        
        self.center = CLLocationCoordinate2D(latitude: gridLat, longitude: gridLon)
        self.gridSize = gridSize
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(center.latitude)
        hasher.combine(center.longitude)
        hasher.combine(gridSize)
    }
    
    static func == (lhs: RegionKey, rhs: RegionKey) -> Bool {
        abs(lhs.center.latitude - rhs.center.latitude) < 0.0001 &&
        abs(lhs.center.longitude - rhs.center.longitude) < 0.0001 &&
        lhs.gridSize == rhs.gridSize
    }
}

#Preview {
    AppleMapView()
}