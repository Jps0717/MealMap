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
    @State private var scrollOffset: CGFloat = 0
    
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
        ZStack {
            // Full-screen map background
            MapStyleBackground()
                .ignoresSafeArea(.all)
            
            // Gradient overlay for better readability
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.1),
                    Color.clear,
                    Color.white.opacity(0.8),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)
            
            // Main content
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero header section
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60) // Status bar padding
                            
                            // Close button
                            HStack {
                                Button(action: dismissView) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .frame(width: 44, height: 44)
                                        )
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            // Restaurant pin and info
                            VStack(spacing: 20) {
                                // Large restaurant pin
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.red)
                                    .background(
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 70, height: 70)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                                
                                // Restaurant name and cuisine
                                VStack(spacing: 8) {
                                    Text(restaurant.name)
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                                    
                                    if let cuisine = restaurant.cuisine {
                                        Text(cuisine.capitalized)
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(.ultraThinMaterial)
                                            )
                                    }
                                }
                            }
                            
                            Spacer().frame(height: 40)
                        }
                        .frame(height: 400)
                        
                        // Content card section
                        VStack(spacing: 0) {
                            // Tab selector
                            HStack(spacing: 0) {
                                ForEach(DetailTab.allCases, id: \.self) { tab in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedTab = tab
                                        }
                                        if tab == .nutrition {
                                            nutritionManager.loadNutritionData(for: restaurant.name)
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: tab.icon)
                                                .font(.system(size: 20))
                                            Text(tab.rawValue)
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(selectedTab == tab ? .white : .gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                        .background(
                                            selectedTab == tab ? 
                                            Color.blue : Color.clear
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .background(Color(.systemGray6))
                            .cornerRadius(16, corners: [.topLeft, .topRight])
                            
                            // Tab content
                            VStack(spacing: 24) {
                                switch selectedTab {
                                case .info:
                                    FullScreenRestaurantInfoView(restaurant: restaurant)
                                case .nutrition:
                                    FullScreenRestaurantNutritionView(
                                        restaurant: restaurant,
                                        nutritionManager: nutritionManager
                                    )
                                case .directions:
                                    FullScreenRestaurantDirectionsView(restaurant: restaurant)
                                }
                            }
                            .padding(24)
                            .background(Color(.systemBackground))
                            .frame(minHeight: geometry.size.height * 0.6)
                            
                            // Action buttons
                            fullScreenActionButtons()
                                .padding(.horizontal, 24)
                                .padding(.bottom, 100)
                                .background(Color(.systemBackground))
                        }
                    }
                }
                .ignoresSafeArea(.all)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(false)
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(.all)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animateIn = true
            }
            
            if selectedTab == .nutrition {
                nutritionManager.loadNutritionData(for: restaurant.name)
            }
        }
    }
    
    @ViewBuilder
    private func fullScreenActionButtons() -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Call button
                if let phone = restaurant.phone {
                    Button(action: {
                        if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 18))
                            Text("Call")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                
                // Directions button
                Button(action: openInMaps) {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 18))
                        Text("Directions")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
            
            // Website button (full width if available)
            if let website = restaurant.website {
                Button(action: {
                    if let url = URL(string: website) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 18))
                        Text("Visit Website")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func dismissView() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            animateIn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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

// MARK: - Full Screen Content Views

struct FullScreenRestaurantInfoView: View {
    let restaurant: Restaurant
    
    var body: some View {
        VStack(spacing: 20) {
            if let address = restaurant.address {
                InfoCard(icon: "location.fill", title: "Address", value: address, color: .blue)
            }
            
            if let cuisine = restaurant.cuisine {
                InfoCard(icon: "fork.knife", title: "Cuisine", value: cuisine.capitalized, color: .green)
            }
            
            if let hours = restaurant.openingHours {
                InfoCard(icon: "clock.fill", title: "Hours", value: hours, color: .orange)
            } else {
                InfoCard(icon: "clock.fill", title: "Hours", value: "Hours not available", color: .gray)
            }
            
            if let phone = restaurant.phone {
                InfoCard(icon: "phone.fill", title: "Phone", value: phone, color: .red)
            }
            
            InfoCard(
                icon: "mappin.circle.fill", 
                title: "Coordinates", 
                value: "\(String(format: "%.4f", restaurant.latitude)), \(String(format: "%.4f", restaurant.longitude))",
                color: .purple
            )
        }
    }
}

struct FullScreenRestaurantNutritionView: View {
    let restaurant: Restaurant
    @ObservedObject var nutritionManager: NutritionDataManager
    @State private var showingFullMenu = false
    
    var body: some View {
        VStack(spacing: 20) {
            if nutritionManager.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading nutrition data...")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .frame(minHeight: 150)
            } else if let errorMessage = nutritionManager.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("No Nutrition Data Available")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(errorMessage)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(minHeight: 200)
            } else if let restaurantData = nutritionManager.currentRestaurantData {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Menu Items")
                                .font(.system(size: 24, weight: .bold))
                            Text("\(restaurantData.items.count) items available")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("View All") {
                            showingFullMenu = true
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    // Preview of menu items
                    VStack(spacing: 12) {
                        ForEach(restaurantData.items.prefix(5)) { item in
                            FullScreenMenuItemRow(item: item)
                        }
                        
                        if restaurantData.items.count > 5 {
                            Button("+ \(restaurantData.items.count - 5) more items") {
                                showingFullMenu = true
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.top, 8)
                        }
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Tap to Load Nutrition Data")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    
                    Button("Load Menu") {
                        nutritionManager.loadNutritionData(for: restaurant.name)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .frame(minHeight: 200)
            }
        }
        .sheet(isPresented: $showingFullMenu) {
            if let restaurantData = nutritionManager.currentRestaurantData {
                NutritionMenuView(restaurantData: restaurantData)
            }
        }
    }
}

struct FullScreenRestaurantDirectionsView: View {
    let restaurant: Restaurant
    @State private var userLocation: CLLocation?
    @State private var distance: String = "Calculating..."
    
    var body: some View {
        VStack(spacing: 24) {
            // Distance card
            VStack(spacing: 16) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text("Distance from You")
                        .font(.system(size: 20, weight: .semibold))
                    Text(distance)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(16)
            
            // Location details
            VStack(spacing: 16) {
                Text("Restaurant Location")
                    .font(.system(size: 20, weight: .semibold))
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Latitude:")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                        Spacer()
                        Text(String(format: "%.6f", restaurant.latitude))
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    HStack {
                        Text("Longitude:")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                        Spacer()
                        Text(String(format: "%.6f", restaurant.longitude))
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Text("Tap 'Directions' below to open in Maps app for turn-by-turn navigation.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .onAppear {
            calculateDistance()
        }
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

// MARK: - Helper Views

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FullScreenMenuItemRow: View {
    let item: NutritionData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.item)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    NutritionBadge(value: "\(Int(item.calories)) cal", color: .orange)
                    NutritionBadge(value: "\(formatNumber(item.fat))g fat", color: .blue)
                    NutritionBadge(value: "\(formatNumber(item.protein))g protein", color: .green)
                }
            }
            
            Spacer()
            
            Text("\(Int(item.calories))")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.1f", value)
        }
    }
}

struct NutritionBadge: View {
    let value: String
    let color: Color
    
    var body: some View {
        Text(value)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(6)
    }
}

// Extension for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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
