import SwiftUI
import MapKit
import CoreLocation

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Binding var isPresented: Bool
    @State private var animateIn = false
    @State private var selectedTab: DetailTab = .info
    @State private var hasNutritionData: Bool = false
    
    enum DetailTab: String, CaseIterable {
        case info = "Info"
        case directions = "Directions"
        case nutrition = "Nutrition"
        
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
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if let cuisine = restaurant.cuisine {
                            Text(cuisine.capitalized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: dismissView) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Nutrition data badge
                if hasNutritionData {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                        Text("Nutrition data available")
                            .font(.caption)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 16, weight: .medium))
                                Text(tab.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(selectedTab == tab ? .blue : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .background(Color(.systemGray6))
                .overlay(
                    // Tab indicator
                    Rectangle()
                        .fill(Color.blue)
                        .frame(height: 2)
                        .offset(x: tabIndicatorOffset)
                        .animation(.easeInOut(duration: 0.2), value: selectedTab),
                    alignment: .bottom
                )
                
                // Tab content
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .info:
                            RestaurantInfoView(restaurant: restaurant)
                        case .directions:
                            RestaurantDirectionsView(restaurant: restaurant)
                        case .nutrition:
                            RestaurantNutritionView(restaurant: restaurant, hasData: hasNutritionData)
                        }
                    }
                    .padding(20)
                }
                .frame(maxHeight: 300)
                
                // Action buttons
                HStack(spacing: 12) {
                    // Call button
                    if let phone = restaurant.phone {
                        Button(action: {
                            if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "phone.fill")
                                Text("Call")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Directions button
                    Button(action: openInMaps) {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Directions")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Website button
                    if let website = restaurant.website {
                        Button(action: {
                            if let url = URL(string: website) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "safari.fill")
                                Text("Website")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            )
            .padding(.horizontal, 20)
            .scaleEffect(animateIn ? 1.0 : 0.8)
            .opacity(animateIn ? 1.0 : 0.0)
        }
        .onAppear {
            hasNutritionData = RestaurantData.restaurantsWithNutritionData.contains(restaurant.name)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animateIn = true
            }
        }
    }
    
    private var tabIndicatorOffset: CGFloat {
        let tabWidth = UIScreen.main.bounds.width / CGFloat(DetailTab.allCases.count)
        let selectedIndex = DetailTab.allCases.firstIndex(of: selectedTab) ?? 0
        return CGFloat(selectedIndex) * tabWidth - (UIScreen.main.bounds.width - 40) / 2 + tabWidth / 2
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let address = restaurant.address {
                InfoRow(icon: "location.fill", title: "Address", value: address)
            }
            
            if let cuisine = restaurant.cuisine {
                InfoRow(icon: "fork.knife", title: "Cuisine", value: cuisine.capitalized)
            }
            
            if let hours = restaurant.openingHours {
                InfoRow(icon: "clock.fill", title: "Hours", value: hours)
            } else {
                InfoRow(icon: "clock.fill", title: "Hours", value: "Hours not available")
            }
            
            if let phone = restaurant.phone {
                InfoRow(icon: "phone.fill", title: "Phone", value: phone)
            }
            
            InfoRow(icon: "mappin.circle.fill", title: "Coordinates", 
                   value: "\(String(format: "%.4f", restaurant.latitude)), \(String(format: "%.4f", restaurant.longitude))")
        }
    }
}

// MARK: - Directions Tab Content
struct RestaurantDirectionsView: View {
    let restaurant: Restaurant
    @State private var userLocation: CLLocation?
    @State private var distance: String = "Calculating..."
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Distance")
                        .font(.headline)
                    Text(distance)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Restaurant Location")
                    .font(.headline)
                HStack {
                    Text("Latitude:")
                        .foregroundColor(.secondary)
                    Text(String(format: "%.6f", restaurant.latitude))
                }
                HStack {
                    Text("Longitude:")
                        .foregroundColor(.secondary)
                    Text(String(format: "%.6f", restaurant.longitude))
                }
            }
            
            Divider()
            
            Text("Tap 'Directions' below to open in Maps app for turn-by-turn navigation.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
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

// MARK: - Nutrition Tab Content
struct RestaurantNutritionView: View {
    let restaurant: Restaurant
    let hasData: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if hasData {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                        Text("Nutrition Data Available")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    Text("This restaurant provides detailed nutrition information for their menu items.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Placeholder for actual nutrition data
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Popular Items:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ForEach(["Most Popular Item", "Healthy Option", "Low Calorie Choice"], id: \.self) { item in
                            HStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 8, height: 8)
                                Text(item)
                                    .font(.caption)
                                Spacer()
                                Text("View Details")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 32))
                    
                    Text("No Nutrition Data")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("This restaurant doesn't provide detailed nutrition information in our database.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("You may find nutrition information on their website or by calling the restaurant directly.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - Helper Views
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
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