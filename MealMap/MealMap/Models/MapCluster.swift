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
        let individualPinThreshold = 0.008
        let maxIndividualPins = 100
        
        if zoomLevel < individualPinThreshold {
            let mapCenter = CLLocation(latitude: center.latitude, longitude: center.longitude)

            let restaurantsWithDistance = restaurants.map { restaurant in
                let loc = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
                return (restaurant: restaurant, distance: loc.distance(from: mapCenter))
            }
            
            let closestRestaurants = restaurantsWithDistance.sorted { $0.distance < $1.distance }
                .prefix(maxIndividualPins)
                .map { $0.restaurant }
            
            return closestRestaurants.map { restaurant in
                let coordinate = CLLocationCoordinate2D(
                    latitude: restaurant.latitude,
                    longitude: restaurant.longitude
                )
                return MapCluster(
                    id: "restaurant_\(restaurant.id)",
                    coordinate: coordinate,
                    restaurants: [restaurant]
                )
            }
        }
        
        let clusteringFactor = 0.02
        let gridSize = zoomLevel * clusteringFactor
        
        let minGridSize = 0.02
        let effectiveGridSize = max(gridSize, minGridSize)

        var clusters: [String: [Restaurant]] = [:]
        
        for restaurant in restaurants {
            let gridX = Int(restaurant.latitude / effectiveGridSize)
            let gridY = Int(restaurant.longitude / effectiveGridSize)
            let key = "\(gridX),\(gridY)"
            
            if clusters[key] == nil {
                clusters[key] = []
            }
            clusters[key]?.append(restaurant)
        }
        
        return clusters.map { (gridKey, restaurants) in
            let centerLat = restaurants.map { $0.latitude }.reduce(0, +) / Double(restaurants.count)
            let centerLon = restaurants.map { $0.longitude }.reduce(0, +) / Double(restaurants.count)
            let coordinate = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
            
            return MapCluster(
                id: "grid_\(gridKey)",
                coordinate: coordinate,
                restaurants: restaurants
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
    
    private var clusterCache: [String: [MapCluster]] = [:]
    private var lastUpdateTask: Task<Void, Never>?
    private var lastClusteringData: (restaurants: [Restaurant], zoomLevel: Double, center: CLLocationCoordinate2D)?
    
    private var isUpdating = false
    private var wasShowingClusters = true // Track previous state
    
    func updateClusters(
        restaurants: [Restaurant],
        zoomLevel: Double,
        span: MKCoordinateSpan,
        center: CLLocationCoordinate2D,
        debounceDelay: TimeInterval = 0.2
    ) {
        guard !isUpdating else { return }
        
        lastUpdateTask?.cancel()
        
        if let lastData = lastClusteringData,
           lastData.restaurants.count == restaurants.count,
           abs(lastData.zoomLevel - zoomLevel) < 0.0005,
           abs(lastData.center.latitude - center.latitude) < 0.0005,
           abs(lastData.center.longitude - center.longitude) < 0.0005 {
            return
        }
        
        lastUpdateTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            
            if !Task.isCancelled {
                await updateClustersInternal(
                    restaurants: restaurants,
                    zoomLevel: zoomLevel,
                    span: span,
                    center: center
                )
            }
        }
    }
    
    private func updateClustersInternal(
        restaurants: [Restaurant],
        zoomLevel: Double,
        span: MKCoordinateSpan,
        center: CLLocationCoordinate2D
    ) async {
        isUpdating = true
        lastClusteringData = (restaurants: restaurants, zoomLevel: zoomLevel, center: center)
        
        let cacheKey = MapCluster.createCacheKey(restaurantCount: restaurants.count, zoomLevel: zoomLevel, center: center)
        
        let willShowClusters = zoomLevel >= 0.008
        let shouldAnimate = wasShowingClusters != willShowClusters
        
        if shouldAnimate {
            transitionState = willShowClusters ? .mergingToClusters : .splittingToIndividual
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if let cachedClusters = clusterCache[cacheKey] {
            withAnimation(.easeInOut(duration: shouldAnimate ? 0.4 : 0.2)) {
                self.clusters = cachedClusters
            }
            
            if shouldAnimate {
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
                transitionState = .stable
            }
            
            wasShowingClusters = willShowClusters
            isUpdating = false
            return
        }
        
        let newClusters = await Task.detached {
            return MapCluster.createClusters(
                from: restaurants,
                zoomLevel: zoomLevel,
                span: span,
                center: center
            )
        }.value
        
        withAnimation(.easeInOut(duration: shouldAnimate ? 0.4 : 0.25)) {
            if clusterCache.count > 20 {
                clusterCache.removeAll()
            }
            clusterCache[cacheKey] = newClusters
            self.clusters = newClusters
        }
        
        if shouldAnimate {
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
            transitionState = .stable
        }
        
        wasShowingClusters = willShowClusters
        isUpdating = false
    }
    
    func clearCache() {
        clusterCache.removeAll()
        lastClusteringData = nil
        transitionState = .stable
    }
}
