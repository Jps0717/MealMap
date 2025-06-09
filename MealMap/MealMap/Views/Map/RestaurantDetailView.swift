import SwiftUI
import MapKit
import CoreLocation

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Binding var isPresented: Bool
    @State private var animateIn = false
    @State private var selectedTab: DetailTab = .nutrition
    @State private var hasNutritionData: Bool = false
    
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(restaurant.name)
                                .font(.system(size: adaptiveSize(base: 20, geometry: geometry), weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            if let cuisine = restaurant.cuisine {
                                Text(cuisine.capitalized)
                                    .font(.system(size: adaptiveSize(base: 14, geometry: geometry)))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: dismissView) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: adaptiveSize(base: 24, geometry: geometry)))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, adaptivePadding(base: 20, geometry: geometry))
                    .padding(.top, adaptivePadding(base: 20, geometry: geometry))
                    .padding(.bottom, adaptivePadding(base: 16, geometry: geometry))
                    
                    // Nutrition data badge
                    if hasNutritionData {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(.green)
                                .font(.system(size: adaptiveSize(base: 12, geometry: geometry)))
                            Text("Nutrition data available")
                                .font(.system(size: adaptiveSize(base: 12, geometry: geometry)))
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(.horizontal, adaptivePadding(base: 20, geometry: geometry))
                        .padding(.bottom, adaptivePadding(base: 16, geometry: geometry))
                    }
                    
                    // Tab selector
                    HStack(spacing: 0) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            }) {
                                VStack(spacing: adaptiveSpacing(base: 6, geometry: geometry)) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: adaptiveSize(base: 16, geometry: geometry), weight: .medium))
                                    Text(tab.rawValue)
                                        .font(.system(size: adaptiveSize(base: 10, geometry: geometry)))
                                        .fontWeight(.medium)
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
                    
                    // Tab content - CHANGE: Keep switch cases matching the new tab order
                    ScrollView {
                        VStack(spacing: adaptiveSpacing(base: 20, geometry: geometry)) {
                            switch selectedTab {
                            case .info:
                                RestaurantInfoView(restaurant: restaurant, geometry: geometry)
                            case .nutrition:
                                RestaurantNutritionView(restaurant: restaurant, hasData: hasNutritionData, geometry: geometry)
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
            hasNutritionData = RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animateIn = true
            }
        }
    }
    
    // MARK: - Adaptive Sizing Functions
    
    private func adaptiveSize(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.85), 1.15)
    }
    
    private func adaptivePadding(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.8), 1.2)
    }
    
    private func adaptiveSpacing(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.7), 1.3)
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
        
        let baseFontSize: CGFloat = min(adaptiveSize(base: 16, geometry: geometry), buttonWidth / 8)
        
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

// MARK: - Nutrition Tab Content
struct RestaurantNutritionView: View {
    let restaurant: Restaurant
    let hasData: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        VStack(spacing: adaptiveSpacing(base: 16, geometry: geometry)) {
            if hasData {
                VStack(alignment: .leading, spacing: adaptiveSpacing(base: 12, geometry: geometry)) {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                            .font(.system(size: adaptiveSize(base: 16, geometry: geometry)))
                        Text("Nutrition Data Available")
                            .font(.system(size: adaptiveSize(base: 18, geometry: geometry), weight: .semibold))
                            .foregroundColor(.green)
                    }
                    
                    Text("This restaurant provides detailed nutrition information for their menu items.")
                        .font(.system(size: adaptiveSize(base: 14, geometry: geometry)))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: adaptiveSpacing(base: 8, geometry: geometry)) {
                        Text("Popular Items:")
                            .font(.system(size: adaptiveSize(base: 14, geometry: geometry), weight: .semibold))
                        
                        ForEach(["Most Popular Item", "Healthy Option", "Low Calorie Choice"], id: \.self) { item in
                            HStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: adaptiveSize(base: 8, geometry: geometry), height: adaptiveSize(base: 8, geometry: geometry))
                                Text(item)
                                    .font(.system(size: adaptiveSize(base: 12, geometry: geometry)))
                                Spacer()
                                Text("View Details")
                                    .font(.system(size: adaptiveSize(base: 12, geometry: geometry)))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(adaptivePadding(base: 16, geometry: geometry))
                    .background(Color(.systemGray6))
                    .cornerRadius(adaptiveCornerRadius(base: 8, geometry: geometry))
                }
            } else {
                VStack(spacing: adaptiveSpacing(base: 12, geometry: geometry)) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: adaptiveSize(base: 32, geometry: geometry)))
                    
                    Text("No Nutrition Data")
                        .font(.system(size: adaptiveSize(base: 18, geometry: geometry), weight: .semibold))
                        .foregroundColor(.orange)
                    
                    Text("This restaurant doesn't provide detailed nutrition information in our database.")
                        .font(.system(size: adaptiveSize(base: 14, geometry: geometry)))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("You may find nutrition information on their website or by calling the restaurant directly.")
                        .font(.system(size: adaptiveSize(base: 12, geometry: geometry)))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
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
    
    private func adaptivePadding(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.8), 1.2)
    }
    
    private func adaptiveCornerRadius(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let scaleFactor = screenWidth / 390.0
        return base * min(max(scaleFactor, 0.8), 1.1)
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
