import SwiftUI
import CoreLocation

struct RestaurantSearchView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var selectedCuisine: String?
    
    // Dependencies
    @ObservedObject var mapViewModel: MapViewModel
    @StateObject private var locationManager = LocationManager.shared
    
    // Popular cuisines for quick access
    private let popularCuisines = [
        ("Pizza", "🍕", Color.red),
        ("Burger", "🍔", Color.orange),
        ("Chinese", "🥡", Color.yellow),
        ("Mexican", "🌮", Color.green),
        ("Italian", "🍝", Color.blue),
        ("Thai", "🍜", Color.purple),
        ("Indian", "🍛", Color.pink),
        ("Japanese", "🍣", Color.teal)
    ]
    
    // Recent searches (could be persisted later)
    @State private var recentSearches = ["McDonald's", "Pizza", "Starbucks", "Taco Bell"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Search Bar Section
                        searchBarSection
                        
                        // Quick Cuisine Filters
                        cuisineFiltersSection
                        
                        // Recent Searches
                        if !recentSearches.isEmpty {
                            recentSearchesSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Find Restaurants")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // MARK: - Search Bar Section
    private var searchBarSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
                
                TextField("Search restaurants, cuisines...", text: $searchText)
                    .font(.system(size: 17, design: .rounded))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            )
            
            // Search suggestions or results count
            if !searchText.isEmpty {
                HStack {
                    Text("Press Search or Enter to find restaurants")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Search") {
                        performSearch()
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Cuisine Filters
    private var cuisineFiltersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Popular Cuisines")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(Array(popularCuisines.enumerated()), id: \.offset) { index, cuisine in
                    CuisineFilterButton(
                        name: cuisine.0,
                        emoji: cuisine.1,
                        color: cuisine.2,
                        isSelected: selectedCuisine == cuisine.0,
                        onTap: {
                            selectCuisine(cuisine.0)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Recent Searches
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Searches")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Button("Clear") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        recentSearches.removeAll()
                    }
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(recentSearches, id: \.self) { search in
                    RecentSearchRow(
                        searchTerm: search,
                        onTap: {
                            searchText = search
                            performSearch()
                        },
                        onRemove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                recentSearches.removeAll { $0 == search }
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Actions
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add to recent searches
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !recentSearches.contains(trimmedSearch) {
            recentSearches.insert(trimmedSearch, at: 0)
            if recentSearches.count > 5 {
                recentSearches.removeLast()
            }
        }
        
        // Perform search with distance filter - this will trigger the search and show results
        mapViewModel.performSearch(query: searchText, maxDistance: nil) // Remove distance parameter
        
        // Dismiss the search view so user can see results on map
        isPresented = false
    }
    
    private func selectCuisine(_ cuisine: String) {
        if selectedCuisine == cuisine {
            selectedCuisine = nil
            mapViewModel.clearSearch()
        } else {
            selectedCuisine = cuisine
            searchText = cuisine
            
            if !recentSearches.contains(cuisine) {
                recentSearches.insert(cuisine, at: 0)
                if recentSearches.count > 5 {
                    recentSearches.removeLast()
                }
            }
            
            // Perform the search immediately with distance
            mapViewModel.performSearch(query: cuisine, maxDistance: nil) // Remove distance parameter
            
            // Dismiss the search view to show results
            isPresented = false
        }
    }
}

// MARK: - Supporting Views

struct CuisineFilterButton: View {
    let name: String
    let emoji: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("Search \(name.lowercased())")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.green.opacity(0.15) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.green : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentSearchRow: View {
    let searchTerm: String
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            Text(searchTerm)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    RestaurantSearchView(
        isPresented: .constant(true),
        mapViewModel: MapViewModel()
    )
}
