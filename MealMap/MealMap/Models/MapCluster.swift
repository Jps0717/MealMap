import Foundation
import CoreLocation
import MapKit
import SwiftUI

struct MapCluster: Identifiable, Hashable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let restaurants: [Restaurant]
    
    var count: Int {
        restaurants.count
    }
    
    var nutritionDataCount: Int {
        restaurants.filter { RestaurantData.restaurantsWithNutritionData.contains($0.name) }.count
    }
    
    var noNutritionDataCount: Int {
        count - nutritionDataCount
    }
    
    var hasNutritionData: Bool {
        nutritionDataCount > 0
    }
    
    var allHaveNutritionData: Bool {
        nutritionDataCount == count
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MapCluster, rhs: MapCluster) -> Bool {
        lhs.id == rhs.id
    }
    
    static func createStableID(coordinate: CLLocationCoordinate2D) -> String {
        let lat = round(coordinate.latitude * 10000) / 10000
        let lon = round(coordinate.longitude * 10000) / 10000
        return "cluster_\(lat)_\(lon)"
    }
    
    static func calculateViewRadius(span: MKCoordinateSpan) -> Double {
        let latMiles = span.latitudeDelta * 69.0
        let lonMiles = span.longitudeDelta * 69.0 * cos(span.latitudeDelta * .pi / 180)
        return max(latMiles, lonMiles) / 2.0
    }
    
    static func createCacheKey(restaurantCount: Int, zoomLevel: Double, center: CLLocationCoordinate2D) -> String {
        let roundedZoom = round(zoomLevel * 1000) / 1000
        let roundedLat = round(center.latitude * 100) / 100
        let roundedLon = round(center.longitude * 100) / 100
        return "\(restaurantCount)_\(roundedZoom)_\(roundedLat)_\(roundedLon)"
    }
    
    static func createClusters(from restaurants: [Restaurant], zoomLevel: Double, span: MKCoordinateSpan, center: CLLocationCoordinate2D) -> [MapCluster] {
        // Early return for empty data
        guard !restaurants.isEmpty else { return [] }
        
        let individualPinThreshold = 0.008
        let maxIndividualPins = 50
        
        // Show individual pins when zoomed in
        if zoomLevel < individualPinThreshold {
            return createIndividualClusters(
                restaurants: restaurants,
                center: center,
                maxPins: maxIndividualPins
            )
        }
        
        // Use grid-based clustering for zoomed out views
        return createGridClusters(
            restaurants: restaurants,
            zoomLevel: zoomLevel,
            span: span
        )
    }
    
    private static func createIndividualClusters(
        restaurants: [Restaurant],
        center: CLLocationCoordinate2D,
        maxPins: Int
    ) -> [MapCluster] {
        let mapCenter = CLLocation(latitude: center.latitude, longitude: center.longitude)
        
        // Pre-calculate distances and sort efficiently
        let sortedRestaurants = restaurants.lazy
            .map { restaurant -> (restaurant: Restaurant, distanceSquared: Double) in
                let deltaLat = restaurant.latitude - center.latitude
                let deltaLon = restaurant.longitude - center.longitude
                return (restaurant, deltaLat * deltaLat + deltaLon * deltaLon)
            }
            .sorted { $0.distanceSquared < $1.distanceSquared }
            .prefix(maxPins)
            .map { $0.restaurant }
        
        return sortedRestaurants.map { restaurant in
            MapCluster(
                id: "restaurant_\(restaurant.id)",
                coordinate: CLLocationCoordinate2D(
                    latitude: restaurant.latitude,
                    longitude: restaurant.longitude
                ),
                restaurants: [restaurant]
            )
        }
    }
    
    private static func createGridClusters(
        restaurants: [Restaurant],
        zoomLevel: Double,
        span: MKCoordinateSpan
    ) -> [MapCluster] {
        // Dynamic grid size based on zoom level and density
        let baseFactor = 0.015
        let gridSize = max(zoomLevel * baseFactor, 0.01)
        
        // Use dictionary for faster grouping
        var clusters: [String: [Restaurant]] = [:]
        clusters.reserveCapacity(restaurants.count / 4) // Estimate capacity
        
        for restaurant in restaurants {
            let gridX = Int(restaurant.latitude / gridSize)
            let gridY = Int(restaurant.longitude / gridSize)
            let key = "\(gridX),\(gridY)"
            
            clusters[key, default: []].append(restaurant)
        }
        
        // Filter out single-restaurant clusters at higher zoom levels
        let shouldFilterSingles = zoomLevel > 0.05
        
        return clusters.compactMap { (gridKey, restaurantGroup) in
            // Skip single restaurants at high zoom levels to reduce clutter
            if shouldFilterSingles && restaurantGroup.count == 1 {
                return nil
            }
            
            // Calculate center more efficiently
            let centerLat = restaurantGroup.reduce(0.0) { $0 + $1.latitude } / Double(restaurantGroup.count)
            let centerLon = restaurantGroup.reduce(0.0) { $0 + $1.longitude } / Double(restaurantGroup.count)
            
            return MapCluster(
                id: "grid_\(gridKey)",
                coordinate: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                restaurants: restaurantGroup
            )
        }
    }
}

enum ClusterTransitionState {
    case stable
    case splittingToIndividual
    case mergingToClusters
}

@MainActor
class ClusterManager: ObservableObject {
    @Published var clusters: [MapCluster] = []
    @Published var transitionState: ClusterTransitionState = .stable
    
    private var clusterCache: [String: CachedClusterData] = [:]
    private var lastUpdateTask: Task<Void, Never>?
    private var lastClusteringData: ClusteringData?
    
    private var isUpdating = false
    private var wasShowingClusters = true
    
    private let maxCacheSize = 20 // Increased for better coverage
    private let cacheExpiryTime: TimeInterval = 300
    private let minUpdateInterval: TimeInterval = 0.05 // Very responsive
    private var lastUpdateTime = Date.distantPast
    
    func updateClusters(
        restaurants: [Restaurant],
        zoomLevel: Double,
        span: MKCoordinateSpan,
        center: CLLocationCoordinate2D,
        debounceDelay: TimeInterval = 0.1
    ) {
        // FIXED: Early return for empty restaurants to prevent unnecessary processing
        guard !restaurants.isEmpty else { return }
        
        // Minimal throttling for smoothness
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) < minUpdateInterval {
            return
        }
        
        guard !isUpdating else { return }
        
        let newData = ClusteringData(
            restaurants: restaurants,
            zoomLevel: zoomLevel,
            span: span,
            center: center
        )
        
        // More lenient similarity check for responsiveness
        if let lastData = lastClusteringData,
           lastData.isSimilar(to: newData, threshold: 0.003) {
            return
        }
        
        lastUpdateTask?.cancel()
        lastUpdateTime = now
        
        lastUpdateTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            
            if !Task.isCancelled {
                await updateClustersInternal(data: newData)
            }
        }
    }
    
    private func updateClustersInternal(data: ClusteringData) async {
        isUpdating = true
        lastClusteringData = data
        
        let cacheKey = data.cacheKey
        
        // INSTANT: Check cache first for immediate response
        if let cached = clusterCache[cacheKey], !cached.isExpired {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.clusters = cached.clusters
                }
                self.isUpdating = false
            }
            return
        }
        
        let willShowClusters = data.zoomLevel >= 0.015
        let shouldAnimate = wasShowingClusters != willShowClusters
        
        if shouldAnimate {
            await MainActor.run {
                transitionState = willShowClusters ? .mergingToClusters : .splittingToIndividual
            }
        }
        
        // Background clustering for smooth performance
        let newClusters = await Task.detached {
            MapCluster.createClusters(
                from: data.restaurants,
                zoomLevel: data.zoomLevel,
                span: data.span,
                center: data.center
            )
        }.value
        
        // Cache results immediately
        clusterCache[cacheKey] = CachedClusterData(
            clusters: newClusters,
            timestamp: Date()
        )
        
        // Periodic cache cleaning
        if clusterCache.count > maxCacheSize {
            cleanCache()
        }
        
        // INSTANT: Update UI immediately
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.clusters = newClusters
            }
            
            if shouldAnimate {
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // Minimal delay
                    await MainActor.run {
                        self.transitionState = .stable
                    }
                }
            }
            
            self.wasShowingClusters = willShowClusters
            self.isUpdating = false
        }
    }

    private func cleanCache() {
        // Remove expired entries
        clusterCache = clusterCache.filter { !$0.value.isExpired }
        
        // Remove oldest entries if needed
        if clusterCache.count > maxCacheSize {
            let sortedKeys = clusterCache.keys.sorted { key1, key2 in
                clusterCache[key1]?.timestamp ?? Date.distantPast <
                clusterCache[key2]?.timestamp ?? Date.distantPast
            }
            
            let keysToRemove = sortedKeys.prefix(clusterCache.count - maxCacheSize)
            keysToRemove.forEach { clusterCache.removeValue(forKey: $0) }
        }
    }
    
    func clearCache() {
        clusterCache.removeAll()
        lastClusteringData = nil
        transitionState = .stable
        lastUpdateTask?.cancel()
    }
}

private struct ClusteringData {
    let restaurants: [Restaurant]
    let zoomLevel: Double
    let span: MKCoordinateSpan
    let center: CLLocationCoordinate2D
    
    var cacheKey: String {
        let roundedZoom = round(zoomLevel * 1000) / 1000
        let roundedLat = round(center.latitude * 100) / 100
        let roundedLon = round(center.longitude * 100) / 100
        return "\(restaurants.count)_\(roundedZoom)_\(roundedLat)_\(roundedLon)"
    }
    
    func isSimilar(to other: ClusteringData, threshold: Double) -> Bool {
        restaurants.count == other.restaurants.count &&
        abs(zoomLevel - other.zoomLevel) < threshold &&
        abs(center.latitude - other.center.latitude) < threshold &&
        abs(center.longitude - other.center.longitude) < threshold
    }
}

private struct CachedClusterData {
    let clusters: [MapCluster]
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300
    }
}
