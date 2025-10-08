import SwiftUI
import MapKit

struct FoodTypeCategoryView: View {
    let foodType: FoodType
    @ObservedObject var mapViewModel: MapViewModel
    
    @StateObject private var locationManager = LocationManager.shared
    @State private var restaurants: [Restaurant] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedRestaurant: Restaurant?
    @State private var hasAttemptedLoad = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(foodType.emoji)
                        .font(.system(size: DynamicSizing.iconSize(32)))
                    
                    VStack(alignment: .leading, spacing: DynamicSizing.spacing(4, geometry: geometry)) {
                        Text(foodType.name)
                            .dynamicFont(24, weight: .bold)
                        
                        Text("\(restaurants.count) restaurants near you")
                            .dynamicFont(14)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, DynamicSizing.spacing(20, geometry: geometry))
                .padding(.vertical, DynamicSizing.spacing(16, geometry: geometry))
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                
                // Restaurant list
                if isLoading {
                    VStack(spacing: DynamicSizing.spacing(16, geometry: geometry)) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Finding \(foodType.name) restaurants...")
                            .dynamicFont(16)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else if let errorMessage = errorMessage {
                    VStack(spacing: DynamicSizing.spacing(16, geometry: geometry)) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: DynamicSizing.iconSize(50)))
                            .foregroundColor(.orange)
                        
                        Text("Error Loading Restaurants")
                            .dynamicFont(18, weight: .semibold)
                        
                        Text(errorMessage)
                            .dynamicFont(14)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            loadRestaurants()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(DynamicSizing.spacing(20, geometry: geometry))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else if restaurants.isEmpty {
                    VStack(spacing: DynamicSizing.spacing(16, geometry: geometry)) {
                        Text(foodType.emoji)
                            .font(.system(size: DynamicSizing.iconSize(60)))
                        
                        Text("No \(foodType.name) restaurants found nearby")
                            .dynamicFont(18, weight: .semibold)
                        
                        Text("Try expanding your search radius or check back later")
                            .dynamicFont(14)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Search Again") {
                            loadRestaurants()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(DynamicSizing.spacing(20, geometry: geometry))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(restaurants, id: \.id) { restaurant in
                            Button(action: {
                                selectedRestaurant = restaurant
                            }) {
                                RestaurantRowView(restaurant: restaurant, geometry: geometry)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color(.systemBackground))
                        }
                    }
                    .listStyle(.plain)
                    .background(Color(.systemGroupedBackground))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if !hasAttemptedLoad {
                hasAttemptedLoad = true
                loadRestaurants()
            }
        }
        .sheet(item: $selectedRestaurant) { restaurant in
            NavigationView {
                RestaurantDetailView(
                    restaurant: restaurant,
                    isPresented: .constant(true),
                    selectedCategory: nil
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func loadRestaurants() {
        errorMessage = nil
        isLoading = true
        
        // Check location permission first
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            errorMessage = "Location access is required to find restaurants near you. Please enable it in Settings."
            isLoading = false
            return
        case .notDetermined:
            locationManager.requestLocationPermission()
            // Give a moment for permission to be granted
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.locationManager.authorizationStatus == .authorizedWhenInUse || 
                   self.locationManager.authorizationStatus == .authorizedAlways {
                    self.loadRestaurants()
                } else {
                    self.errorMessage = "Location permission required to find restaurants"
                    self.isLoading = false
                }
            }
            return
        default:
            break
        }
        
        guard let userLocation = locationManager.lastLocation?.coordinate else {
            // Try to get fresh location
            locationManager.refreshCurrentLocation()
            
            // Set timeout for location
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if self.locationManager.lastLocation == nil {
                    self.errorMessage = "Unable to get your location. Please make sure location services are enabled."
                    self.isLoading = false
                }
            }
            return
        }
        
        Task {
            do {
                print("🍽️ Loading \(foodType.name) restaurants near \(userLocation)")
                
                // Get all nearby restaurants
                let allRestaurants = try await OverpassAPIService().fetchAllNearbyRestaurants(
                    near: userLocation,
                    radius: 8.0 // Increased radius for better results
                )
                
                print("🍽️ Found \(allRestaurants.count) total restaurants")
                
                // Filter by food type with enhanced matching
                let filteredRestaurants = allRestaurants.filter { restaurant in
                    let name = restaurant.name.lowercased()
                    let cuisine = restaurant.cuisine?.lowercased() ?? ""
                    
                    // Check exact matches first
                    let hasExactMatch = foodType.searchTerms.contains { term in
                        name.contains(term) || cuisine.contains(term)
                    }
                    
                    // Also check for broader matches for better results
                    if hasExactMatch {
                        return true
                    }
                    
                    // Secondary matching for better coverage
                    switch foodType.name.lowercased() {
                    case "chinese":
                        return cuisine.contains("asian") || name.contains("wok") || name.contains("dragon") || name.contains("panda")
                    case "mexican":
                        return name.contains("taco") || name.contains("burrito") || name.contains("quesadilla") || cuisine.contains("latin")
                    case "burgers":
                        return name.contains("burger") || name.contains("grill") || cuisine.contains("american")
                    case "coffee":
                        return name.contains("coffee") || name.contains("cafe") || name.contains("starbucks") || name.contains("dunkin")
                    case "pizza":
                        return name.contains("pizza") || name.contains("pizzeria")
                    case "sushi":
                        return name.contains("sushi") || name.contains("japanese") || cuisine.contains("japanese")
                    default:
                        return false
                    }
                }
                
                print("🍽️ Filtered to \(filteredRestaurants.count) \(foodType.name) restaurants")
                
                // Sort by distance and prioritize restaurants with nutrition data
                let sortedRestaurants = filteredRestaurants.sorted { restaurant1, restaurant2 in
                    // First, prioritize restaurants with nutrition data
                    if restaurant1.hasNutritionData && !restaurant2.hasNutritionData {
                        return true
                    } else if !restaurant1.hasNutritionData && restaurant2.hasNutritionData {
                        return false
                    } else {
                        // Then sort by distance
                        let distance1 = restaurant1.distanceFrom(userLocation)
                        let distance2 = restaurant2.distanceFrom(userLocation)
                        return distance1 < distance2
                    }
                }
                
                await MainActor.run {
                    self.restaurants = Array(sortedRestaurants.prefix(50))
                    self.isLoading = false
                    self.errorMessage = nil
                    
                    print("🍽️ Final result: \(self.restaurants.count) restaurants for \(foodType.name)")
                }
                
            } catch {
                print("❌ Error loading restaurants: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load restaurants: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct RestaurantRowView: View {
    let restaurant: Restaurant
    let geometry: GeometryProxy
    
    var body: some View {
        HStack(spacing: DynamicSizing.spacing(12, geometry: geometry)) {
            // Restaurant emoji/icon
            Text(restaurant.emoji)
                .font(.system(size: DynamicSizing.iconSize(24)))
                .frame(
                    width: DynamicSizing.iconSize(40),
                    height: DynamicSizing.iconSize(40)
                )
                .background(Color(.systemGray6))
                .cornerRadius(DynamicSizing.cornerRadius(8))
            
            // Restaurant info
            VStack(alignment: .leading, spacing: DynamicSizing.spacing(4, geometry: geometry)) {
                Text(restaurant.name)
                    .dynamicFont(16, weight: .semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack {
                    if let cuisine = restaurant.cuisine {
                        Text(cuisine)
                            .dynamicFont(12)
                            .foregroundColor(.secondary)
                    }
                    
                    if restaurant.hasNutritionData {
                        Text("• Nutrition Available")
                            .dynamicFont(12)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Distance if available
            if let userLocation = LocationManager.shared.lastLocation?.coordinate {
                let distance = restaurant.distanceFrom(userLocation)
                Text(String(format: "%.1f mi", distance))
                    .dynamicFont(12, weight: .medium)
                    .foregroundColor(.secondary)
            }
            
            // Navigation arrow
            Image(systemName: "chevron.right")
                .font(.system(size: DynamicSizing.iconSize(12)))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, DynamicSizing.spacing(8, geometry: geometry))
        .padding(.horizontal, DynamicSizing.spacing(16, geometry: geometry))
        .background(Color(.systemBackground))
        .cornerRadius(DynamicSizing.cornerRadius(12))
    }
}

#Preview {
    NavigationView {
        FoodTypeCategoryView(
            foodType: FoodType(name: "Pizza", emoji: "🍕", searchTerms: ["pizza"]),
            mapViewModel: MapViewModel()
        )
    }
}