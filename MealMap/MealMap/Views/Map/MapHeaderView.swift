import SwiftUI
import MapKit
import CoreLocation

struct MapHeaderView: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    let viewModel: MapViewModel
    let onSearch: () -> Void
    let onClearSearch: () -> Void
    let onDismiss: () -> Void
    let onCenterLocation: () -> Void
    
    @State private var showingScoringLegend = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))

                TextField("Search restaurants, cuisines...", text: $searchText)
                    .font(.system(size: 16, design: .rounded))
                    .disableAutocorrection(true)
                    .onSubmit {
                        onSearch()
                    }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                } else if !searchText.isEmpty {
                    Button(action: onClearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            )
            .padding(.horizontal, 16)
            
            // SIMPLIFIED: Control buttons without filters
            HStack(spacing: 16) {
                // Home button
                Button(action: {
                    debugLog("🏠 Home button tapped - returning to home screen")
                    onDismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Home")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: .green.opacity(0.4), radius: 10, y: 5)
                }
                .accessibilityLabel("Return to Home Screen")
                .accessibilityHint("Tap to go back to the home screen")
                
                Spacer()
                
                MapStatusIndicators(viewModel: viewModel, isSearching: isSearching)
                
                // Scoring Legend Button
                if viewModel.restaurants.contains(where: { $0.hasNutritionData }) {
                    Button(action: {
                        showingScoringLegend = true
                    }) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                }
                
                // Center on location button
                Button(action: onCenterLocation) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 70) 
        .sheet(isPresented: $showingScoringLegend) {
            RestaurantScoringLegendView()
        }
    }
}

struct MapStatusIndicators: View {
    let viewModel: MapViewModel
    let isSearching: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Restaurant count indicator (simplified)
            if !viewModel.restaurants.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                    
                    let totalCount = viewModel.restaurants.count
                    let nutritionCount = viewModel.restaurants.filter { $0.hasNutritionData }.count
                    
                    Text("\(totalCount) restaurants")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                    
                    if nutritionCount > 0 {
                        Text("• \(nutritionCount) with nutrition")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.green)
                    }
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(.systemBackground).opacity(0.9))
                        .overlay(
                            Capsule()
                                .stroke(.gray.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Search results indicator
            if viewModel.showSearchResults {
                HStack(spacing: 6) {
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                    }
                    
                    let searchCount = viewModel.filteredRestaurants.count
                    Text(isSearching ? "Searching..." : "\(searchCount) found")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.blue.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
}