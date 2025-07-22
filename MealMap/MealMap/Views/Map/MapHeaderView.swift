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
    
    var body: some View {
        VStack(spacing: 12) {
            // ENHANCED: Search bar with updated placeholder
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))

                TextField("Search restaurants, pizza, burgers, sushi...", text: $searchText)
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
            
            // SIMPLIFIED: Only Home button and restaurant count (no search results indicator)
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
                
                // UPDATED: Only show restaurant count, not search results
                MapStatusIndicators(viewModel: viewModel, isSearching: isSearching)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 70) 
    }
}

struct MapStatusIndicators: View {
    let viewModel: MapViewModel
    let isSearching: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // UPDATED: Restaurant count indicator (works for both regular view and search results)
            if !viewModel.restaurants.isEmpty || viewModel.showSearchResults {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                    
                    // ENHANCED: Show appropriate count based on search state
                    let displayedRestaurants = viewModel.showSearchResults ? viewModel.filteredRestaurants : viewModel.restaurants
                    let totalCount = displayedRestaurants.count
                    let nutritionCount = displayedRestaurants.filter { $0.hasNutritionData }.count
                    
                    if viewModel.showSearchResults {
                        Text("\(totalCount) found")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.blue)
                    } else {
                        Text("\(totalCount) restaurants")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    
                    if nutritionCount > 0 {
                        Text("• \(nutritionCount) with nutrition")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.green)
                    }
                }
                .foregroundColor(viewModel.showSearchResults ? .blue : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(viewModel.showSearchResults ? .blue.opacity(0.1) : Color(.systemBackground).opacity(0.9))
                        .overlay(
                            Capsule()
                                .stroke(viewModel.showSearchResults ? .blue.opacity(0.3) : .gray.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
}