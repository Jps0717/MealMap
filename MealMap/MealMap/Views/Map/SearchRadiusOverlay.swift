import SwiftUI
import MapKit
import CoreLocation

struct SearchRadiusOverlay: View {
    let center: CLLocationCoordinate2D
    let radiusInMiles: Double
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            ZStack {
                // Calculate radius in degrees (approximately)
                let radiusInDegrees = radiusInMiles / 69.0 // Rough conversion: 1 degree ≈ 69 miles
                
                // Search area circle border - simplified
                Circle()
                    .stroke(Color.blue.opacity(0.7), lineWidth: 2)
                    .frame(width: radiusInDegrees * 200, height: radiusInDegrees * 200)
                
                // Center dot
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
            }
            .animation(.easeInOut(duration: 0.2), value: isVisible)
        }
    }
}

// MARK: - Optimized MapKit Search Radius Overlay  
struct MapSearchRadiusOverlay: View {
    let userLocation: CLLocationCoordinate2D
    let radiusInMiles: Double
    let mapRegion: MKCoordinateRegion
    let isVisible: Bool
    
    // Cache expensive calculations
    @State private var cachedOverlaySize: CGSize = CGSize(width: 100, height: 100)
    @State private var cachedOffset: CGPoint = .zero
    @State private var lastRegion: MKCoordinateRegion?
    @State private var lastRadius: Double = 0
    
    var body: some View {
        if isVisible && radiusInMiles > 0 {
            ZStack {
                // Simplified radius indicator - no mask, much better performance
                OptimizedRadiusIndicator(
                    radius: radiusInMiles,
                    size: cachedOverlaySize
                )
                .offset(x: cachedOffset.x, y: cachedOffset.y)
            }
            .onAppear {
                updateCachedValues()
            }
            .onChange(of: mapRegion.center.latitude) { _, _ in
                updateCachedValuesIfNeeded()
            }
            .onChange(of: mapRegion.center.longitude) { _, _ in
                updateCachedValuesIfNeeded()
            }
            .onChange(of: mapRegion.span.latitudeDelta) { _, _ in
                updateCachedValuesIfNeeded()
            }
            .onChange(of: radiusInMiles) { _, _ in
                updateCachedValues()
            }
            .animation(.easeOut(duration: 0.15), value: isVisible)
        }
    }
    
    private func updateCachedValuesIfNeeded() {
        // Only update if significant change to reduce computation
        guard let lastRegion = lastRegion else {
            updateCachedValues()
            return
        }
        
        let centerDistance = abs(mapRegion.center.latitude - lastRegion.center.latitude) + 
                           abs(mapRegion.center.longitude - lastRegion.center.longitude)
        let spanChange = abs(mapRegion.span.latitudeDelta - lastRegion.span.latitudeDelta)
        
        if centerDistance > 0.001 || spanChange > 0.001 {
            updateCachedValues()
        }
    }
    
    private func updateCachedValues() {
        // Cache the expensive calculations
        cachedOverlaySize = calculateOverlaySize()
        cachedOffset = calculateOffset()
        lastRegion = mapRegion
        lastRadius = radiusInMiles
    }
    
    private func calculateOverlaySize() -> CGSize {
        let metersPerMile = 1609.344
        let radiusInMeters = radiusInMiles * metersPerMile
        let metersPerDegree = 111_319.9 * cos(userLocation.latitude * .pi / 180)
        let radiusInDegrees = radiusInMeters / metersPerDegree
        
        let screenRatio = (radiusInDegrees * 2) / mapRegion.span.latitudeDelta
        let size = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * screenRatio
        return CGSize(width: max(size, 50), height: max(size, 50))
    }
    
    private func calculateOffset() -> CGPoint {
        let latOffset = (userLocation.latitude - mapRegion.center.latitude) / mapRegion.span.latitudeDelta
        let lonOffset = (userLocation.longitude - mapRegion.center.longitude) / mapRegion.span.longitudeDelta
        
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        return CGPoint(
            x: lonOffset * screenWidth,
            y: -latOffset * screenHeight
        )
    }
}

// MARK: - Optimized Radius Indicator (Dark Outside, Clear Inside)
struct OptimizedRadiusIndicator: View {
    let radius: Double
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Dark overlay that covers everything OUTSIDE the circle
            GeometryReader { geometry in
                ZStack {
                    // Full screen dark overlay
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(
                            width: max(UIScreen.main.bounds.width * 2, geometry.size.width * 2),
                            height: max(UIScreen.main.bounds.height * 2, geometry.size.height * 2)
                        )
                        .clipped()
                    
                    // Clear circle cut-out in the middle
                    Circle()
                        .fill(Color.black)
                        .frame(width: size.width, height: size.height)
                        .blendMode(.destinationOut)
                }
                .compositingGroup() // This makes the blend mode work properly
            }
            .allowsHitTesting(false)
            
            // Main circle border
            Circle()
                .stroke(Color.blue.opacity(0.8), lineWidth: 2)
                .frame(width: size.width, height: size.height)
            
            // Center point
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
            
            // Distance label
            VStack {
                Spacer()
                Text(formatDistance(radius))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                    .offset(y: -(size.height / 2 + 20))
            }
        }
        .allowsHitTesting(false)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance == floor(distance) {
            return "\(Int(distance))mi"
        } else {
            return String(format: "%.1fmi", distance)
        }
    }
}

#Preview {
    ZStack {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
        
        MapSearchRadiusOverlay(
            userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radiusInMiles: 5.0,
            mapRegion: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ),
            isVisible: true
        )
    }
}
