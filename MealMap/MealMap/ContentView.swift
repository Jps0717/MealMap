import SwiftUI

struct ContentView: View {
    @State private var isBottomTabExpanded = false
    @GestureState private var bottomDragOffset: CGFloat = 0
    
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    // Pull tab configuration
    private let bottomTabCollapsedHeight: CGFloat = 80
    private let collapsedBottomPadding: CGFloat = 20
    
    private var shouldShowLocationScreens: Bool {
        if let _ = locationManager.locationError {
            return true
        } else if !hasValidLocation {
            return true
        } else if !networkMonitor.isConnected {
            return true
        }
        return false
    }
    
    private var hasValidLocation: Bool {
        locationManager.lastLocation != nil &&
        (locationManager.authorizationStatus == .authorizedWhenInUse ||
         locationManager.authorizationStatus == .authorizedAlways)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let quarterScreenHeight = geometry.size.height * 0.5
            let expandedHeight = max(quarterScreenHeight, 200) // Minimum 200pts
            
            ZStack {
                // Main Map Screen - always visible
                MapScreen()
                    .ignoresSafeArea()
                
                if !shouldShowLocationScreens {
                    // Bottom Pull Tab - entire tab moves as one unit
                    VStack(spacing: 0) {
                        Spacer()
                        
                        VStack(spacing: 0) {
                            // Always visible bottom tab header
                            bottomTabHeader
                            
                            // Expanded content - limited to 1/4 screen height
                            bottomExpandedContent(expandedHeight: expandedHeight)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                        )
                        .offset(y: bottomDragOffset + (isBottomTabExpanded ? 0 : expandedHeight - bottomTabCollapsedHeight - collapsedBottomPadding))
                        .gesture(
                            DragGesture()
                                .updating($bottomDragOffset) { value, state, _ in
                                    let translation = value.translation.height
                                    
                                    if isBottomTabExpanded {
                                        // When expanded, allow dragging down with some resistance
                                        state = max(-20, min(100, translation))
                                    } else {
                                        // When collapsed, allow dragging up with some resistance
                                        state = max(-100, min(20, translation))
                                    }
                                }
                                .onEnded { value in
                                    handleBottomDragEnd(value)
                                }
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: isBottomTabExpanded)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Bottom Pull Tab Header
    private var bottomTabHeader: some View {
        VStack(spacing: 0) {
            // Pull indicator
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
            
            // Header content
            HStack {
                // Menu button
                Button(action: {
                    // Menu action
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                // Center content
                HStack(spacing: 8) {
                    Text("FOR YOU")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text("NEW YORK")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Profile button
                Button(action: {
                    // Profile action
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)
                        
                        Text("SL")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(height: bottomTabCollapsedHeight)
    }
    
    // MARK: - Bottom Expanded Content
    private func bottomExpandedContent(expandedHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Content area that appears when expanded
            if isBottomTabExpanded {
                VStack(spacing: 16) {
                    Text("Restaurant List")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Browse restaurants in your area")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // Restaurant list placeholder - limited height
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(0..<5, id: \.self) { index in
                                CompactRestaurantRow(name: "Restaurant \(index + 1)", cuisine: "Cuisine Type", distance: "\(index + 1).2 mi")
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: expandedHeight - bottomTabCollapsedHeight - 120) // Leave space for text and padding
                }
                .padding(.top, 16)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Spacer(minLength: 0)
        }
        .frame(height: expandedHeight - bottomTabCollapsedHeight)
    }

    // MARK: - Gesture Handling
    private func handleBottomDragEnd(_ value: DragGesture.Value) {
        let dragAmount = value.translation.height
        let velocity = value.velocity.height
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            if isBottomTabExpanded {
                // Currently expanded - check if we should collapse
                // Snap to collapsed if dragged down more than 30pts or fast downward velocity
                if dragAmount > 30 || velocity > 200 {
                    isBottomTabExpanded = false
                } else {
                    // Snap back to expanded
                    isBottomTabExpanded = true
                }
            } else {
                // Currently collapsed - check if we should expand
                // Snap to expanded if dragged up more than 30pts or fast upward velocity
                if dragAmount < -30 || velocity < -200 {
                    isBottomTabExpanded = true
                } else {
                    // Snap back to collapsed
                    isBottomTabExpanded = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct CompactRestaurantRow: View {
    let name: String
    let cuisine: String
    let distance: String
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "fork.knife")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(cuisine)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(distance)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

// Keep the original RestaurantRow for other uses
struct RestaurantRow: View {
    let name: String
    let cuisine: String
    let distance: String
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "fork.knife")
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(cuisine)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(distance)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

#Preview {
    ContentView()
}
