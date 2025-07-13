import Foundation
import CoreLocation
import SwiftUI

// MARK: - Simplified Data Models

struct SimpleCacheRegion {
    let center: CLLocationCoordinate2D
    let radius: Double
    let restaurants: [Restaurant]
    let cachedAt: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(cachedAt) > 3600 // 1 hour expiry
    }
    
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distanceInMiles = centerLocation.distance(from: targetLocation) / 1609.34
        return distanceInMiles <= radius
    }
}

/// Advanced Map Caching System with spatial caching and memory management
class MapCacheManager: ObservableObject {
    static let shared = MapCacheManager()
    
    // MARK: - Cache Configuration
    private let cacheRadius: Double = 2.0 // miles
    private let maxCacheRegions = 10 // Maximum cached regions
    private let maxRestaurantsPerRegion = 100 // Reduced from 150, Memory limit per region
    
    // MARK: - Published Properties (MainActor isolated)
    @MainActor @Published var isLoading = false
    @MainActor @Published var cacheHitRate: Double = 0.0
    
    // MARK: - Cache Storage (thread-safe, not published)
    private var memoryCache: [String: SimpleCacheRegion] = [:]
    
    // MARK: - Background Processing
    private let fileManager = FileManager.default
    private var cacheDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("MapCache")
    }
    
    private init() {
        createCacheDirectory()
        setupMemoryWarningHandler()
        debugLog(" MapCacheManager initialized with \(cacheRadius) mile radius")
    }
    
    // MARK: - Main Cache Interface
    
    /// Get restaurants for a location, using cache when available
    func getRestaurants(for coordinate: CLLocationCoordinate2D, using apiService: OverpassAPIService) async -> [Restaurant] {
        let cacheKey = generateSimpleKey(for: coordinate)
        
        // Check memory cache first
        if let cachedRegion = getCachedRestaurants(for: coordinate) {
            await MainActor.run {
                self.isLoading = false
            }
            debugLog(" Cache HIT for \(coordinate) - returning \(cachedRegion.count) restaurants")
            return cachedRegion
        }
        
        await MainActor.run {
            self.isLoading = true
        }
        
        debugLog(" Cache MISS for \(coordinate) - fetching from API")
        
        do {
            // Fetch from API
            let restaurants = try await apiService.fetchAllNearbyRestaurants(
                near: coordinate,
                radius: cacheRadius
            )
            
            // Cache the results
            cacheRestaurants(restaurants, for: coordinate)
            
            await MainActor.run {
                self.isLoading = false
            }
            
            debugLog(" Cached \(restaurants.count) restaurants for \(coordinate)")
            return restaurants
            
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            
            debugLog(" Failed to fetch restaurants: \(error)")
            return []
        }
    }
    
    /// Preload restaurants for nearby areas to improve user experience
    func preloadNearbyAreas(around coordinate: CLLocationCoordinate2D, using apiService: OverpassAPIService) {
        Task.detached(priority: .background) {
            let preloadRadius = 1.0 // 1 mile preload radius
            let preloadCoordinates = await self.generatePreloadCoordinates(around: coordinate, radius: preloadRadius)
            
            for preloadCoord in preloadCoordinates {
                // Only preload if not already cached
                if await self.getCachedRestaurants(for: preloadCoord) == nil {
                    debugLog(" Preloading area: \(preloadCoord)")
                    let _ = await self.getRestaurants(for: preloadCoord, using: apiService)
                    
                    // Small delay to prevent overwhelming the API
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            }
        }
    }
    
    // MARK: - Cache Management
    
    func getCachedRestaurants(for coordinate: CLLocationCoordinate2D) -> [Restaurant]? {
        // Check if we have a cached region that contains this coordinate
        for (_, region) in memoryCache {
            if !region.isExpired && region.contains(coordinate) {
                debugLog(" Cache HIT for \(coordinate)")
                return region.restaurants
            }
        }
        
        debugLog(" Cache MISS for \(coordinate)")
        return nil
    }
    
    func cacheRestaurants(_ restaurants: [Restaurant], for coordinate: CLLocationCoordinate2D) {
        let key = generateSimpleKey(for: coordinate)
        let region = SimpleCacheRegion(
            center: coordinate,
            radius: cacheRadius,
            restaurants: restaurants,
            cachedAt: Date()
        )
        
        memoryCache[key] = region
        
        // Simple cleanup - remove oldest if over limit
        if memoryCache.count > maxCacheRegions {
            let oldestKey = memoryCache.min { $0.value.cachedAt < $1.value.cachedAt }?.key
            if let oldestKey = oldestKey {
                memoryCache.removeValue(forKey: oldestKey)
            }
        }
        
        debugLog(" Cached \(restaurants.count) restaurants")
    }
    
    // MARK: - Disk Persistence
    
    private func createCacheDirectory() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryWarningHandler() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        debugLog(" Memory warning - clearing cache")
        memoryCache.removeAll()
        debugLog(" Memory warning cleanup: kept 0 regions")
    }
    
    // MARK: - Cache Statistics
    
    func getCacheCount() -> Int {
        return memoryCache.count
    }
    
    // MARK: - Simple Helpers
    
    private func generateSimpleKey(for coordinate: CLLocationCoordinate2D) -> String {
        // Simple 2 decimal place key (roughly 1km precision)
        let lat = String(format: "%.2f", coordinate.latitude)
        let lon = String(format: "%.2f", coordinate.longitude)
        return "\(lat)_\(lon)"
    }
    
    private func generatePreloadCoordinates(around center: CLLocationCoordinate2D, radius: Double) -> [CLLocationCoordinate2D] {
        let radiusInDegrees = radius / 69.0 // Rough conversion
        
        return [
            CLLocationCoordinate2D(latitude: center.latitude + radiusInDegrees, longitude: center.longitude),
            CLLocationCoordinate2D(latitude: center.latitude - radiusInDegrees, longitude: center.longitude),
            CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude + radiusInDegrees),
            CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude - radiusInDegrees),
            CLLocationCoordinate2D(latitude: center.latitude + radiusInDegrees/2, longitude: center.longitude + radiusInDegrees/2),
            CLLocationCoordinate2D(latitude: center.latitude + radiusInDegrees/2, longitude: center.longitude - radiusInDegrees/2),
            CLLocationCoordinate2D(latitude: center.latitude - radiusInDegrees/2, longitude: center.longitude + radiusInDegrees/2),
            CLLocationCoordinate2D(latitude: center.latitude - radiusInDegrees/2, longitude: center.longitude - radiusInDegrees/2)
        ]
    }
}