import SwiftUI
import MapKit
import CoreLocation

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Binding var isPresented: Bool
    @State private var animateIn = false
    @State private var selectedTab: DetailTab = .nutrition
    @State private var hasNutritionData: Bool = false
    @StateObject private var nutritionManager = NutritionDataManager()
    
    enum DetailTab: String, CaseIterable {
        case info = "Info"
        case nutrition = "Nutrition"
        case directions = "Directions"
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .directions: return "location.fill"
            case .nutrition: return "leaf.fill"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background blur
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissView()
                    }
                
                // Main content card
                VStack(spacing: 0) {
                    // Header with restaurant name and close button
                    HStack {
                        VStack(alignment: .leading, spacing: adaptiveSpacing(base: 4, geometry: geometry)) {
                            Text(restaurant.name)
                                .font(.system(size: adaptiveFontSize(base: 24, geometry: geometry), weight: .bold))
                                .foregroundColor(.primary)
                            
                            if let cuisine = restaurant.cuisine {
                                Text(cuisine.capitalized)
                                    .font(.system(size: adaptiveFontSize(base: 16, geometry: geometry)))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: dismissView) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: adaptiveFontSize(base: 24, geometry: geometry)))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(adaptivePadding(base: 20, geometry: geometry))
                    
                    // Tab selector
                    HStack(spacing: 0) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Button(action: {
                                selectedTab = tab
                                if tab == .nutrition {
                                    nutritionManager.loadNutritionData(for: restaurant.name)
                                }
                            }) {
                                HStack(spacing: adaptiveSpacing(base: 8, geometry: geometry)) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: adaptiveFontSize(base: 14, geometry: geometry)))
                                    Text(tab.rawValue)
                                        .font(.system(size: adaptiveFontSize(base: 14, geometry: geometry), weight: .medium))
                                }
                                .foregroundColor(selectedTab == tab ? .blue : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, adaptivePadding(base: 12, geometry: geometry))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .background(Color(.systemGray6))
                    .overlay(
                        GeometryReader { tabGeometry in
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: 2)
                                .frame(width: tabGeometry.size.width / CGFloat(DetailTab.allCases.count))
                                .offset(x: tabIndicatorOffset(tabGeometry: tabGeometry))
                                .animation(.easeInOut(duration: 0.2), value: selectedTab)
                        },
                        alignment: .bottom
                    )
                    
                    // Tab content
                    ScrollView {
                        VStack(spacing: adaptiveSpacing(base: 20, geometry: geometry)) {
                            switch selectedTab {
                            case .info:
                                RestaurantInfoView(restaurant: restaurant, geometry: geometry)
                            case .nutrition:
                                RestaurantNutritionView(
                                    restaurant: restaurant,
                                    nutritionManager: nutritionManager,
                                    geometry: geometry
                                )
                            case .directions:
                                RestaurantDirectionsView(restaurant: restaurant, geometry: geometry)
                            }
                        }
                        .padding(adaptivePadding(base: 20, geometry: geometry))
                    }
                    .frame(maxHeight: adaptiveHeight(base: 300, geometry: geometry))
                    
                    // Action buttons
                    actionButtons(geometry: geometry)
                }
                .frame(width: min(geometry.size.width - adaptivePadding(base: 40, geometry: geometry), 400))
                .background(
                    RoundedRectangle(cornerRadius: adaptiveCornerRadius(base: 20, geometry: geometry))
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                )
                .scaleEffect(animateIn ? 1.0 : 0.8)
                .opacity(animateIn ? 1.0 : 0.0)
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateIn = true
            }
            
            if selectedTab == .nutrition {
                nutritionManager.loadNutritionData(for: restaurant.name)
            }
        }
    }
    
    // MARK: - Adaptive Sizing Functions
    
    private func adaptiveFontSize(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.85), 1.15)
    }
    
    private func adaptiveSpacing(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.7), 1.3)
    }
    
    private func adaptivePadding(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.8), 1.2)
    }
    
    private func adaptiveHeight(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        let scaleFactor = screenHeight / 844.0
        return base * min(max(scaleFactor, 0.8), 1.2)
    }
    
    private func adaptiveCornerRadius(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.8), 1.1)
    }
    
    private func tabIndicatorOffset(tabGeometry: GeometryProxy) -> CGFloat {
        let tabWidth = tabGeometry.size.width / CGFloat(DetailTab.allCases.count)
        let selectedIndex = DetailTab.allCases.firstIndex(of: selectedTab) ?? 0
        return CGFloat(selectedIndex) * tabWidth
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private func actionButtons(geometry: GeometryProxy) -> some View {
        let availableButtons = [
            restaurant.phone != nil,
            true, // Directions always available
            restaurant.website != nil
        ].filter { $0 }.count
        
        let cardWidth = min(geometry.size.width - adaptivePadding(base: 40, geometry: geometry), 400)
        let buttonSpacing = adaptiveSpacing(base: 12, geometry: geometry)
        let totalSpacing = CGFloat(availableButtons - 1) * buttonSpacing
        let horizontalPadding = adaptivePadding(base: 40, geometry: geometry) // 20 on each side
        let availableWidth = cardWidth - horizontalPadding - totalSpacing
        let buttonWidth = availableWidth / CGFloat(availableButtons)
        
        let baseFontSize: CGFloat = min(adaptiveFontSize(base: 16, geometry: geometry), buttonWidth / 8)
        
        HStack(spacing: buttonSpacing) {
            // Call button
            if let phone = restaurant.phone {
                Button(action: {
                    if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: adaptiveSpacing(base: 6, geometry: geometry)) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: baseFontSize * 0.9))
                        Text("Call")
                            .font(.system(size: baseFontSize, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundColor(.white)
                    .frame(width: buttonWidth)
                    .padding(.vertical, adaptivePadding(base: 14, geometry: geometry))
                    .background(Color.green)
                    .cornerRadius(adaptiveCornerRadius(base: 12, geometry: geometry))
                }
            }
            
            // Directions button
            Button(action: openInMaps) {
                HStack(spacing: adaptiveSpacing(base: 6, geometry: geometry)) {
                    Image(systemName: "location.fill")
                        .font(.system(size: baseFontSize * 0.9))
                    Text("Directions")
                        .font(.system(size: baseFontSize, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundColor(.white)
                .frame(width: buttonWidth)
                .padding(.vertical, adaptivePadding(base: 14, geometry: geometry))
                .background(Color.blue)
                .cornerRadius(adaptiveCornerRadius(base: 12, geometry: geometry))
            }
            
            // Website button
            if let website = restaurant.website {
                Button(action: {
                    if let url = URL(string: website) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: adaptiveSpacing(base: 6, geometry: geometry)) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: baseFontSize * 0.9))
                        Text("Website")
                            .font(.system(size: baseFontSize, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundColor(.white)
                    .frame(width: buttonWidth)
                    .padding(.vertical, adaptivePadding(base: 14, geometry: geometry))
                    .background(Color.orange)
                    .cornerRadius(adaptiveCornerRadius(base: 12, geometry: geometry))
                }
            }
        }
        .padding(.horizontal, adaptivePadding(base: 20, geometry: geometry))
        .padding(.bottom, adaptivePadding(base: 20, geometry: geometry))
    }
    
    private func dismissView() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            animateIn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
    
    private func openInMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = restaurant.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - Info Tab Content
struct RestaurantInfoView: View {
    let restaurant: Restaurant
    let geometry: GeometryProxy
    
    var body: some View {
        VStack(alignment: .leading, spacing: adaptiveSpacing(base: 16, geometry: geometry)) {
            if let address = restaurant.address {
                InfoRow(icon: "location.fill", title: "Address", value: address, geometry: geometry)
            }
            
            if let cuisine = restaurant.cuisine {
                InfoRow(icon: "fork.knife", title: "Cuisine", value: cuisine.capitalized, geometry: geometry)
            }
            
            if let hours = restaurant.openingHours {
                InfoRow(icon: "clock.fill", title: "Hours", value: hours, geometry: geometry)
            } else {
                InfoRow(icon: "clock.fill", title: "Hours", value: "Hours not available", geometry: geometry)
            }
            
            if let phone = restaurant.phone {
                InfoRow(icon: "phone.fill", title: "Phone", value: phone, geometry: geometry)
            }
            
            InfoRow(icon: "mappin.circle.fill", title: "Coordinates", 
                   value: "\(String(format: "%.4f", restaurant.latitude)), \(String(format: "%.4f", restaurant.longitude))", 
                   geometry: geometry)
        }
    }
    
    // MARK: - Adaptive Functions
    private func adaptiveSpacing(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.7), 1.3)
    }
}

// MARK: - Directions Tab Content
struct RestaurantDirectionsView: View {
    let restaurant: Restaurant
    let geometry: GeometryProxy
    @State private var userLocation: CLLocation?
    @State private var distance: String = "Calculating..."
    
    var body: some View {
        VStack(alignment: .leading, spacing: adaptiveSpacing(base: 16, geometry: geometry)) {
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: adaptiveSize(base: 24, geometry: geometry)))
                VStack(alignment: .leading, spacing: adaptiveSpacing(base: 4, geometry: geometry)) {
                    Text("Distance")
                        .font(.system(size: adaptiveSize(base: 18, geometry: geometry), weight: .semibold))
                    Text(distance)
                        .font(.system(size: adaptiveSize(base: 14, geometry: geometry)))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: adaptiveSpacing(base: 8, geometry: geometry)) {
                Text("Restaurant Location")
                    .font(.system(size: adaptiveSize(base: 18, geometry: geometry), weight: .semibold))
                HStack {
                    Text("Latitude:")
                        .foregroundColor(.secondary)
                        .font(.system(size: adaptiveSize(base: 14, geometry: geometry)))
                    Text(String(format: "%.6f", restaurant.latitude))
                        .font(.system(size: adaptiveSize(base: 14, geometry: geometry)))
                }
                HStack {
                    Text("Longitude:")
                        .foregroundColor(.secondary)
                        .font(.system(size: adaptiveSize(base: 14, geometry: geometry)))
                    Text(String(format: "%.6f", restaurant.longitude))
                        .font(.system(size: adaptiveSize(base: 14, geometry: geometry)))
                }
            }
            
            Divider()
            
            Text("Tap 'Directions' below to open in Maps app for turn-by-turn navigation.")
                .font(.system(size: adaptiveSize(base: 12, geometry: geometry)))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            calculateDistance()
        }
    }
    
    // MARK: - Adaptive Functions
    private func adaptiveSpacing(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.7), 1.3)
    }
    
    private func adaptiveSize(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.85), 1.15)
    }
    
    private func calculateDistance() {
        let locationManager = CLLocationManager()
        if let userLoc = locationManager.location {
            let restaurantLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
            let distanceInMeters = userLoc.distance(from: restaurantLocation)
            let distanceInMiles = distanceInMeters / 1609.34
            
            if distanceInMiles < 1 {
                distance = String(format: "%.0f ft", distanceInMeters * 3.28084)
            } else {
                distance = String(format: "%.1f miles", distanceInMiles)
            }
        }
    }
}

// MARK: - Restaurant Nutrition View
struct RestaurantNutritionView: View {
    let restaurant: Restaurant
    @ObservedObject var nutritionManager: NutritionDataManager
    let geometry: GeometryProxy
    @State private var showingFullMenu = false
    
    var body: some View {
        VStack(spacing: adaptiveSpacing(base: 16, geometry: geometry)) {
            if nutritionManager.isLoading {
                VStack(spacing: adaptiveSpacing(base: 12, geometry: geometry)) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading nutrition data...")
                        .font(.system(size: adaptiveFontSize(base: 16, geometry: geometry)))
                        .foregroundColor(.secondary)
                }
                .frame(minHeight: adaptiveHeight(base: 100, geometry: geometry))
            } else if let errorMessage = nutritionManager.errorMessage {
                VStack(spacing: adaptiveSpacing(base: 12, geometry: geometry)) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: adaptiveFontSize(base: 30, geometry: geometry)))
                        .foregroundColor(.orange)
                    
                    Text("No Nutrition Data Available")
                        .font(.system(size: adaptiveFontSize(base: 18, geometry: geometry), weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(errorMessage)
                        .font(.system(size: adaptiveFontSize(base: 14, geometry: geometry)))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(minHeight: adaptiveHeight(base: 100, geometry: geometry))
            } else if let restaurantData = nutritionManager.currentRestaurantData {
                VStack(spacing: adaptiveSpacing(base: 16, geometry: geometry)) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Menu Items")
                                .font(.system(size: adaptiveFontSize(base: 18, geometry: geometry), weight: .bold))
                            Text("\(restaurantData.items.count) items available")
                                .font(.system(size: adaptiveFontSize(base: 14, geometry: geometry)))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("View All") {
                            showingFullMenu = true
                        }
                        .font(.system(size: adaptiveFontSize(base: 14, geometry: geometry), weight: .semibold))
                        .foregroundColor(.blue)
                    }
                    
                    // Preview of first few items
                    VStack(spacing: 8) {
                        ForEach(restaurantData.items.prefix(3)) { item in
                            CompactMenuItemRow(item: item, geometry: geometry)
                        }
                        
                        if restaurantData.items.count > 3 {
                            Button("+ \(restaurantData.items.count - 3) more items") {
                                showingFullMenu = true
                            }
                            .font(.system(size: adaptiveFontSize(base: 14, geometry: geometry)))
                            .foregroundColor(.blue)
                            .padding(.top, 8)
                        }
                    }
                }
            } else {
                VStack(spacing: adaptiveSpacing(base: 12, geometry: geometry)) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: adaptiveFontSize(base: 30, geometry: geometry)))
                        .foregroundColor(.green)
                    
                    Text("Tap to Load Nutrition Data")
                        .font(.system(size: adaptiveFontSize(base: 16, geometry: geometry)))
                        .foregroundColor(.secondary)
                    
                    Button("Load Menu") {
                        nutritionManager.loadNutritionData(for: restaurant.name)
                    }
                    .font(.system(size: adaptiveFontSize(base: 14, geometry: geometry), weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .frame(minHeight: adaptiveHeight(base: 100, geometry: geometry))
            }
        }
        .sheet(isPresented: $showingFullMenu) {
            if let restaurantData = nutritionManager.currentRestaurantData {
                NutritionMenuView(restaurantData: restaurantData)
            }
        }
    }
    
    private func adaptiveSpacing(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.7), 1.3)
    }
    
    private func adaptiveFontSize(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.85), 1.15)
    }
    
    private func adaptiveHeight(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        let scaleFactor = screenHeight / 844.0
        return base * min(max(scaleFactor, 0.8), 1.2)
    }
}

struct CompactMenuItemRow: View {
    let item: NutritionData
    let geometry: GeometryProxy
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.item)
                    .font(.system(size: adaptiveFontSize(base: 14, geometry: geometry), weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(Int(item.calories)) cal")
                        .font(.system(size: adaptiveFontSize(base: 12, geometry: geometry)))
                        .foregroundColor(.orange)
                    
                    Text("\(formatNumber(item.fat))g fat")
                        .font(.system(size: adaptiveFontSize(base: 12, geometry: geometry)))
                        .foregroundColor(.blue)
                    
                    Text("\(formatNumber(item.protein))g protein")
                        .font(.system(size: adaptiveFontSize(base: 12, geometry: geometry)))
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Text("\(Int(item.calories))")
                .font(.system(size: adaptiveFontSize(base: 16, geometry: geometry), weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    private func adaptiveFontSize(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.85), 1.15)
    }
}

// MARK: - Helper Views
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let geometry: GeometryProxy
    
    var body: some View {
        HStack(alignment: .top, spacing: adaptiveSpacing(base: 12, geometry: geometry)) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: adaptiveSize(base: 20, geometry: geometry))
                .font(.system(size: adaptiveSize(base: 16, geometry: geometry)))
            
            VStack(alignment: .leading, spacing: adaptiveSpacing(base: 2, geometry: geometry)) {
                Text(title)
                    .font(.system(size: adaptiveSize(base: 14, geometry: geometry), weight: .medium))
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.system(size: adaptiveSize(base: 14, geometry: geometry)))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Adaptive Functions
    private func adaptiveSpacing(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.7), 1.3)
    }
    
    private func adaptiveSize(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.85), 1.15)
    }
}

#Preview {
    RestaurantDetailView(
        restaurant: Restaurant(
            id: 1,
            name: "McDonald's",
            latitude: 37.7749,
            longitude: -122.4194,
            address: "123 Main St",
            cuisine: "fast_food",
            openingHours: "6:00 AM - 11:00 PM",
            phone: "+1-555-123-4567",
            website: "https://mcdonalds.com",
            type: "node"
        ),
        isPresented: .constant(true)
    )
}
