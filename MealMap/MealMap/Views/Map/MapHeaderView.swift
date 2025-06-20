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
        VStack(spacing: 16) {
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
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            )
            .padding(.horizontal, 16)
            
            // Control buttons
            HStack(spacing: 16) {
                Button(action: onDismiss) {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Home")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                }
                
                Spacer()
                
                MapStatusIndicators(viewModel: viewModel, isSearching: isSearching)
                
                Button(action: onCenterLocation) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(22)
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 75)
    }
}

struct MapStatusIndicators: View {
    let viewModel: MapViewModel
    let isSearching: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Nutrition only indicator
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                Text("Nutrition Only")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.green.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(.green.opacity(0.3), lineWidth: 1)
                    )
            )
            
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
        }
    }
}