import SwiftUI

struct ContentView: View {
    @State private var isBottomTabExpanded = false
    @State private var bottomSheetOffset: CGFloat = 0 // Persistent offset instead of GestureState
    @State private var hasTriggeredHaptic = false
    
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    // Gentle haptic feedback
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    // Direct control constants
    private let bottomTabCollapsedHeight: CGFloat = 85
    private let collapsedBottomPadding: CGFloat = 25
    private let snapVelocityThreshold: CGFloat = 200
    private let snapPositionThreshold: CGFloat = 60
    
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
            let safeAreaHeight = geometry.safeAreaInsets.bottom
            let screenHeight = geometry.size.height
            let expandedHeight = screenHeight * 0.6
            let maxDragDistance = expandedHeight - bottomTabCollapsedHeight
            let collapsedOffset = maxDragDistance - collapsedBottomPadding + safeAreaHeight * 0.2
            let expandedOffset: CGFloat = 0
            
            ZStack {
                // Main Map Screen - always visible
                MapScreen()
                    .ignoresSafeArea()
                
                if !shouldShowLocationScreens {
                    // Smooth bottom sheet with persistent state
                    VStack(spacing: 0) {
                        Spacer()
                        
                        VStack(spacing: 0) {
                            // Header that shows current position
                            continuousHeader(
                                currentOffset: bottomSheetOffset,
                                collapsedOffset: collapsedOffset,
                                expandedOffset: expandedOffset
                            )
                            
                            // Content that appears based on current position
                            continuousContent(
                                expandedHeight: expandedHeight,
                                currentOffset: bottomSheetOffset,
                                collapsedOffset: collapsedOffset,
                                expandedOffset: expandedOffset
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
                        )
                        // CONTINUOUS: Use persistent offset that updates smoothly
                        .offset(y: bottomSheetOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    handleContinuousDrag(
                                        value: value,
                                        collapsedOffset: collapsedOffset,
                                        expandedOffset: expandedOffset,
                                        maxDragDistance: maxDragDistance
                                    )
                                }
                                .onEnded { value in
                                    handleContinuousDragEnd(
                                        value: value,
                                        collapsedOffset: collapsedOffset,
                                        expandedOffset: expandedOffset,
                                        maxDragDistance: maxDragDistance
                                    )
                                    hasTriggeredHaptic = false
                                }
                        )
                        // NO ANIMATION during interaction - only when we programmatically change it
                        
                        // Safe area padding
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: safeAreaHeight)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Set initial position
            setupInitialPosition()
        }
    }
    
    // MARK: - Continuous Control
    
    private func setupInitialPosition() {
        let safeAreaHeight = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
        let screenHeight = UIScreen.main.bounds.height
        let expandedHeight = screenHeight * 0.6
        let maxDragDistance = expandedHeight - bottomTabCollapsedHeight
        let collapsedOffset = maxDragDistance - collapsedBottomPadding + safeAreaHeight * 0.2
        
        bottomSheetOffset = collapsedOffset
    }
    
    private func handleContinuousDrag(
        value: DragGesture.Value,
        collapsedOffset: CGFloat,
        expandedOffset: CGFloat,
        maxDragDistance: CGFloat
    ) {
        let translation = value.translation.height
        let baseOffset = isBottomTabExpanded ? expandedOffset : collapsedOffset
        let newOffset = baseOffset + translation
        
        // Apply gentle resistance at extremes but allow full range
        if newOffset < expandedOffset - 50 {
            // Resistance when dragging above expanded position
            let excess = (expandedOffset - 50) - newOffset
            bottomSheetOffset = expandedOffset - 50 - excess * 0.3
        } else if newOffset > collapsedOffset + 50 {
            // Resistance when dragging below collapsed position
            let excess = newOffset - (collapsedOffset + 50)
            bottomSheetOffset = collapsedOffset + 50 + excess * 0.3
        } else {
            // Direct control in normal range
            bottomSheetOffset = newOffset
        }
        
        // Haptic feedback at snap points
        let currentProgress = (collapsedOffset - bottomSheetOffset) / maxDragDistance
        if !hasTriggeredHaptic {
            if (!isBottomTabExpanded && currentProgress > 0.3) ||
               (isBottomTabExpanded && currentProgress < 0.7) {
                lightFeedback.impactOccurred()
                hasTriggeredHaptic = true
            }
        }
    }
    
    private func handleContinuousDragEnd(
        value: DragGesture.Value,
        collapsedOffset: CGFloat,
        expandedOffset: CGFloat,
        maxDragDistance: CGFloat
    ) {
        let velocity = value.velocity.height
        let currentProgress = (collapsedOffset - bottomSheetOffset) / maxDragDistance
        
        // Determine target position based on current position and velocity
        let shouldExpand: Bool
        
        if velocity < -snapVelocityThreshold {
            // Fast upward gesture - expand
            shouldExpand = true
        } else if velocity > snapVelocityThreshold {
            // Fast downward gesture - collapse
            shouldExpand = false
        } else {
            // Based on position - if more than halfway, go to that state
            shouldExpand = currentProgress > 0.5
        }
        
        // Update state and animate to target position
        let targetOffset = shouldExpand ? expandedOffset : collapsedOffset
        isBottomTabExpanded = shouldExpand
        
        // Smooth animation to final position from current position
        withAnimation(.easeOut(duration: 0.3)) {
            bottomSheetOffset = targetOffset
        }
        
        if isBottomTabExpanded != (currentProgress > 0.5) {
            mediumFeedback.impactOccurred()
        }
    }
    
    // MARK: - Continuous Header
    private func continuousHeader(
        currentOffset: CGFloat,
        collapsedOffset: CGFloat,
        expandedOffset: CGFloat
    ) -> some View {
        let maxDistance = collapsedOffset - expandedOffset
        let progress = maxDistance > 0 ? max(0, min(1, (collapsedOffset - currentOffset) / maxDistance)) : 0
        
        return VStack(spacing: 0) {
            // Dynamic drag indicator
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(.secondary.opacity(0.3 + progress * 0.3))
                .frame(
                    width: 36 + progress * 8, 
                    height: 4
                )
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            // Header content
            HStack(alignment: .center, spacing: 16) {
                // Menu button
                Button(action: {
                    mediumFeedback.impactOccurred()
                    // Menu action
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Center content with progress indicator
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text("FOR YOU")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.blue)
                        
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue.opacity(0.6))
                            .rotationEffect(.degrees(progress * 180))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        
                        Text("NEW YORK")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Profile
                Button(action: {
                    mediumFeedback.impactOccurred()
                    // Profile action
                }) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Text("SL")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(height: bottomTabCollapsedHeight)
    }
    
    // MARK: - Continuous Content
    private func continuousContent(
        expandedHeight: CGFloat,
        currentOffset: CGFloat,
        collapsedOffset: CGFloat,
        expandedOffset: CGFloat
    ) -> some View {
        let maxDistance = collapsedOffset - expandedOffset
        let progress = maxDistance > 0 ? max(0, min(1, (collapsedOffset - currentOffset) / maxDistance)) : 0
        
        return VStack(spacing: 0) {
            // Content appears progressively
            VStack(spacing: 20) {
                // Header that fades in
                VStack(spacing: 8) {
                    Text("Nearby Restaurants")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Discover great places around you")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .opacity(progress)
                
                // Restaurant list
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(0..<12, id: \.self) { index in
                            SimpleRestaurantRow(
                                name: "Restaurant \(index + 1)", 
                                cuisine: ["Italian", "Asian", "Mexican", "American", "Mediterranean"][index % 5],
                                distance: String(format: "%.1f mi", Double(index + 1) * 0.2 + 0.1),
                                rating: 4.0 + Double(index % 10) * 0.1
                            )
                            .opacity(max(0, progress * 1.2 - 0.2))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .frame(maxHeight: expandedHeight - bottomTabCollapsedHeight - 120)
            }
            
            Spacer(minLength: 0)
        }
        .frame(height: expandedHeight - bottomTabCollapsedHeight)
        .clipped()
    }
}

// MARK: - Simple Restaurant Row
struct SimpleRestaurantRow: View {
    let name: String
    let cuisine: String
    let distance: String
    let rating: Double
    
    var body: some View {
        HStack(spacing: 12) {
            // Simple image placeholder
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.blue.opacity(0.1))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "fork.knife")
                        .foregroundColor(.blue.opacity(0.6))
                        .font(.system(size: 13, weight: .medium))
                )
            
            // Restaurant info
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(cuisine)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Simple distance
            Text(distance)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.primary.opacity(0.05), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
    }
}

// Keep supporting views for compatibility
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
