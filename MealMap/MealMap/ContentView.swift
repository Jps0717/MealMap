import SwiftUI
import CoreLocation
import Combine

struct ContentView: View {
    @State private var isBottomTabExpanded = false
    @State private var bottomSheetOffset: CGFloat = 0
    @State private var hasTriggeredHaptic = false
    @State private var isAnimating = false
    @State private var scrollOffset: CGFloat = 0
    @State private var canDismissSheet = true
    @State private var currentLocationName = ""
    @State private var showingSearchView = false

    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var mapViewModel = MapViewModel()

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
                MapScreen(viewModel: mapViewModel)
                    .ignoresSafeArea()

                if !shouldShowLocationScreens {
                    // Smooth bottom sheet with persistent state
                    VStack(spacing: 0) {
                        Spacer()

                        VStack(spacing: 0) {
                            // Header that shows current position - always draggable
                            continuousHeader(
                                currentOffset: bottomSheetOffset,
                                collapsedOffset: collapsedOffset,
                                expandedOffset: expandedOffset
                            )
                            
                            // Content that appears based on current position
                            AppMenuContent(
                                expandedHeight: expandedHeight,
                                currentOffset: bottomSheetOffset,
                                collapsedOffset: collapsedOffset,
                                expandedOffset: expandedOffset,
                                scrollOffset: $scrollOffset,
                                canDismissSheet: $canDismissSheet,
                                onDismiss: {
                                    dismissSheet(
                                        collapsedOffset: collapsedOffset,
                                        expandedOffset: expandedOffset
                                    )
                                }
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
                        )
                        .offset(y: bottomSheetOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if !isAnimating {
                                        // Only respond to drag if it's not a scroll gesture inside content
                                        let translation = value.translation.height
                                        let horizontalMovement = abs(value.translation.width)
                                        let verticalMovement = abs(translation)
                                        
                                        // Allow drag if primarily vertical movement OR if sheet is collapsed
                                        if verticalMovement > horizontalMovement || !isBottomTabExpanded {
                                            handleContinuousDrag(
                                                value: value,
                                                collapsedOffset: collapsedOffset,
                                                expandedOffset: expandedOffset,
                                                maxDragDistance: maxDragDistance
                                            )
                                        }
                                    }
                                }
                                .onEnded { value in
                                    if !isAnimating {
                                        let translation = value.translation.height
                                        let horizontalMovement = abs(value.translation.width)
                                        let verticalMovement = abs(translation)
                                        
                                        // Only handle drag end if it was primarily vertical OR sheet is collapsed
                                        if verticalMovement > horizontalMovement || !isBottomTabExpanded {
                                            handleContinuousDragEnd(
                                                value: value,
                                                collapsedOffset: collapsedOffset,
                                                expandedOffset: expandedOffset,
                                                maxDragDistance: maxDragDistance
                                            )
                                            hasTriggeredHaptic = false
                                        }
                                    }
                                }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: safeAreaHeight)
                    }
                    .onAppear {
                        // Set initial position immediately when geometry is available
                        if bottomSheetOffset == 0 {
                            bottomSheetOffset = collapsedOffset
                            isBottomTabExpanded = false
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onReceive(locationManager.$lastLocation) { location in
            if let location = location {
                updateLocationName(for: location.coordinate)
            }
        }
        .sheet(isPresented: $showingSearchView) {
            RestaurantSearchView(
                isPresented: $showingSearchView,
                mapViewModel: mapViewModel
            )
        }
        .onChange(of: mapViewModel.showSearchResults) { oldValue, newValue in
            if newValue {
                // Close the bottom sheet when search results are displayed
                closeBottomSheet()
            }
        }
    }

    // MARK: - Continuous Control

    private func dismissSheet(collapsedOffset: CGFloat, expandedOffset: CGFloat) {
        isAnimating = true

        withAnimation(.easeOut(duration: 0.3)) {
            bottomSheetOffset = collapsedOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isBottomTabExpanded = false
            isAnimating = false
            canDismissSheet = true
            scrollOffset = 0
        }

        mediumFeedback.impactOccurred()
    }

    private func closeBottomSheet() {
        if isBottomTabExpanded {
            let geometry = UIScreen.main.bounds
            let safeAreaHeight = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
            let screenHeight = geometry.height
            let expandedHeight = screenHeight * 0.6
            let maxDragDistance = expandedHeight - bottomTabCollapsedHeight
            let collapsedOffset = maxDragDistance - collapsedBottomPadding + safeAreaHeight * 0.2
            let expandedOffset: CGFloat = 0
            
            dismissSheet(collapsedOffset: collapsedOffset, expandedOffset: expandedOffset)
        }
    }

    private func handleContinuousDrag(
        value: DragGesture.Value,
        collapsedOffset: CGFloat,
        expandedOffset: CGFloat,
        maxDragDistance: CGFloat
    ) {
        let translation = value.translation.height

        let startOffset = isBottomTabExpanded ? expandedOffset : collapsedOffset
        let newOffset = startOffset + translation

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

        isAnimating = true
        let targetOffset = shouldExpand ? expandedOffset : collapsedOffset

        // Smooth animation to final position from current position
        withAnimation(.easeOut(duration: 0.3)) {
            bottomSheetOffset = targetOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isBottomTabExpanded = shouldExpand
            isAnimating = false
            if shouldExpand {
                canDismissSheet = true
            }
        }

        if shouldExpand != isBottomTabExpanded {
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
            // Dynamic drag indicator with better positioning
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(.secondary.opacity(0.3 + progress * 0.3))
                .frame(
                    width: 36 + progress * 8,
                    height: 4
                )
                .padding(.top, 10)
                .padding(.bottom, 8)

            // Header content with improved spacing and alignment
            HStack(alignment: .center, spacing: 14) {
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

                // Center content with location only
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text(currentLocationName.isEmpty ? "Getting location..." : currentLocationName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity)

                // Profile button with consistent sizing
                Button(action: {
                    mediumFeedback.impactOccurred()
                    // Profile action
                }) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("SL")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(height: bottomTabCollapsedHeight)
    }

    // MARK: - App Menu Content
    private func AppMenuContent(
        expandedHeight: CGFloat,
        currentOffset: CGFloat,
        collapsedOffset: CGFloat,
        expandedOffset: CGFloat,
        scrollOffset: Binding<CGFloat>,
        canDismissSheet: Binding<Bool>,
        onDismiss: @escaping () -> Void
    ) -> some View {
        let maxDistance = collapsedOffset - expandedOffset
        let progress = maxDistance > 0 ? max(0, min(1, (collapsedOffset - currentOffset) / maxDistance)) : 0
        
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Welcome header
                    VStack(spacing: 8) {
                        Text("Explore MealMap")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Discover, plan, and enjoy great food experiences")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .opacity(progress)
                    
                    // Quick Actions Section
                    AppMenuSection(
                        title: "Quick Actions",
                        items: [
                            AppMenuItem(
                                icon: "magnifyingglass",
                                title: "Find Restaurants",
                                subtitle: "Search nearby places",
                                color: .blue,
                                action: { showingSearchView = true }
                            ),
                            AppMenuItem(
                                icon: "heart.fill",
                                title: "Favorites",
                                subtitle: "Your saved places",
                                color: .red,
                                action: { print("Favorites tapped") }
                            ),
                            AppMenuItem(
                                icon: "clock.fill",
                                title: "Recent",
                                subtitle: "Recently visited",
                                color: .orange,
                                action: { print("Recent tapped") }
                            )
                        ],
                        progress: progress
                    )
                    
                    // Tools Section
                    AppMenuSection(
                        title: "Tools",
                        items: [
                            AppMenuItem(
                                icon: "gearshape.fill",
                                title: "Settings",
                                subtitle: "App preferences",
                                color: .gray,
                                action: { print("Settings tapped") }
                            )
                        ],
                        progress: progress
                    )
                    
                    // Add some extra space at the bottom for better scrolling
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset.wrappedValue = value
                canDismissSheet.wrappedValue = value <= 10
            }
            .gesture(
                // Pull-to-dismiss gesture that only works when scrolled to top
                DragGesture()
                    .onChanged { value in
                        if canDismissSheet.wrappedValue &&
                           value.translation.height > 20 &&
                           value.translation.height > abs(value.translation.width) * 1.5 {
                            onDismiss()
                        }
                    }
            )
        }
        .frame(height: expandedHeight - bottomTabCollapsedHeight)
        .clipped()
    }
    
    // MARK: - Helper Methods
    private func updateLocationName(for coordinate: CLLocationCoordinate2D) {
        Task {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    await MainActor.run {
                        currentLocationName = placemark.locality ??
                                            placemark.subLocality ??
                                            placemark.administrativeArea ??
                                            "Unknown Location"
                    }
                }
            } catch {
                await MainActor.run {
                    currentLocationName = "Location unavailable"
                }
            }
        }
    }
}

// MARK: - Scroll Offset Tracking

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: -geo.frame(in: .named("scroll")).minY
                        )
                }
            )
    }
}

// MARK: - Menu Components

struct AppMenuItem {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
}

struct AppMenuSection: View {
    let title: String
    let items: [AppMenuItem]
    let progress: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 4)
            .opacity(max(0, progress * 1.5 - 0.3))
            .modifier(ScrollOffsetModifier())

            // Menu items
            VStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    AppMenuItemRow(item: item)
                        .opacity(max(0, progress * 1.8 - 0.4 - Double(index) * 0.1))
                }
            }
        }
    }
}

struct AppMenuItemRow: View {
    let item: AppMenuItem
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            item.action()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(item.color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(item.color)
                }

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            .shadow(color: .black.opacity(0.02), radius: 1, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
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
