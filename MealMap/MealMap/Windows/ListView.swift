import SwiftUI

struct ListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedSortOption: SortOption = .distance
    @State private var isRefreshing: Bool = false
    
    enum SortOption: String, CaseIterable {
        case mealMapAI = "MealMapAI"
        case distance = "Distance"
        case rating = "Rating"
        case price = "Price"
        case popularity = "Popularity"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Sort Header
                VStack(spacing: 12) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("Search restaurants...", text: $searchText)
                            .font(.system(size: 16))
                            .disableAutocorrection(true)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    searchText = ""
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                    )
                    
                    // Sort Options
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    withAnimation {
                                        selectedSortOption = option
                                    }
                                }) {
                                    Text(option.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(selectedSortOption == option ? .white : .blue)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(selectedSortOption == option ? .blue : .blue.opacity(0.1))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))
                
                // Restaurant List
                ScrollView {
                    VStack(spacing: 24) {
                        // Empty State
                        VStack(spacing: 16) {
                            Image(systemName: "fork.knife.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("No Restaurants Found")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Try adjusting your filters or search terms")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .refreshable {
                    // Placeholder for refresh action
                    isRefreshing = true
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    isRefreshing = false
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Restaurants")
                        .font(.system(size: 18, weight: .bold))
                }
            }
        }
    }
}

struct RestaurantCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Restaurant Image
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 160)
                .cornerRadius(12)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                )
            
            // Restaurant Info
            VStack(alignment: .leading, spacing: 8) {
                // Name and Rating
                HStack {
                    Text("Restaurant Name")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("4.5")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                
                // Cuisine and Price
                HStack {
                    Text("Cuisine Type")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text("$$")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                // Distance and Status
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text("0.5 mi")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text("Open Now")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
    }
}

#Preview {
    ListView()
} 