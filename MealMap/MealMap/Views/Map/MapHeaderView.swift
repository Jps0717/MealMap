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
    
    @State private var showingFilters = false
    
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
            
            // ENHANCED: Control buttons with prominent Home button
            HStack(spacing: 16) {
                // ENHANCED: Prominent Home button that clearly indicates it goes to home screen
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
                
                // HIDDEN: Filter button - commented out
                /*
                Button(action: {
                    showingFilters = true
                }) {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(
                        colors: hasActiveFilters ? [Color.orange, Color.orange.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(24)
                .shadow(color: (hasActiveFilters ? Color.orange : Color.gray).opacity(0.3), radius: 8, y: 4)
                .accessibilityLabel(hasActiveFilters ? "Active Filters" : "No Filters")
                .accessibilityHint("Tap to open filter options")
                */
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 70) 
        .sheet(isPresented: $showingFilters) {
            RestaurantFilterView(
                filter: Binding(
                    get: { viewModel.currentFilter },
                    set: { viewModel.currentFilter = $0 }
                ),
                isPresented: $showingFilters,
                availableRestaurants: viewModel.restaurants,
                userLocation: viewModel.userLocation
            )
        }
    }
    
    private var hasActiveFilters: Bool {
        !viewModel.currentFilter.isEmpty
    }
}

struct MapStatusIndicators: View {
    let viewModel: MapViewModel
    let isSearching: Bool
    
    var body: some View {
        HStack(spacing: 8) {
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
                    
                    let totalCount = viewModel.restaurantsWithinSearchRadius.count
                    Text(isSearching ? "Searching..." : "\(totalCount) found")
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
            
            // ENHANCED: Nutrition data indicator
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                
                Text("Nutrition Data")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.green.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(.green.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}