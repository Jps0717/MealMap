import Foundation
import CoreLocation
import MapKit

@MainActor
class SearchManager: ObservableObject {
    @Published var searchResults: [Restaurant] = []
    @Published var isSearching = false
    @Published var searchError: String?
    @Published var hasActiveSearch = false
    
    // Search for restaurants by name or cuisine type
    func search(
        query: String,
        in restaurants: [Restaurant],
        userLocation: CLLocation?,
        maxDistance: Double? = nil
    ) -> SearchResult {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .noQuery
        }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let restaurantsToSearch = applyDistanceFilter(restaurants, userLocation: userLocation, maxDistance: maxDistance)
        
        // Search by exact name match first
        let exactNameMatches = restaurantsToSearch.filter { restaurant in
            restaurant.name.lowercased() == trimmedQuery
        }
        
        // Search by name contains
        let nameMatches = restaurantsToSearch.filter { restaurant in
            restaurant.name.lowercased().contains(trimmedQuery)
        }
        
        // Search by cuisine type
        let cuisineMatches = restaurantsToSearch.filter { restaurant in
            restaurant.cuisine?.lowercased().contains(trimmedQuery) == true
        }
        
        // Combine and prioritize results
        var allMatches = Set<Restaurant>()
        
        // Add exact matches first (highest priority)
        exactNameMatches.forEach { allMatches.insert($0) }
        
        // Add partial name matches
        nameMatches.forEach { allMatches.insert($0) }
        
        // Add cuisine matches
        cuisineMatches.forEach { allMatches.insert($0) }
        
        let results = Array(allMatches)
        
        guard !results.isEmpty else {
            return .noResults(query: query)
        }
        
        // Determine search result type
        if exactNameMatches.count == 1 {
            // Single exact match - zoom to this restaurant
            return .singleResult(restaurant: exactNameMatches[0])
        } else if !exactNameMatches.isEmpty || (!nameMatches.isEmpty && isLikelyChainRestaurant(query: trimmedQuery)) {
            // Multiple exact matches or chain restaurant - find closest
            let matchesToConsider = !exactNameMatches.isEmpty ? exactNameMatches : nameMatches
            if let closest = findClosestRestaurant(in: matchesToConsider, to: userLocation) {
                return .chainResult(restaurant: closest, totalCount: matchesToConsider.count)
            }
        } else if !cuisineMatches.isEmpty {
            // Cuisine type search - show all matching restaurants
            return .cuisineResults(restaurants: sortByDistance(cuisineMatches, from: userLocation), cuisine: trimmedQuery)
        } else if !nameMatches.isEmpty {
            // Partial name matches - find closest
            if let closest = findClosestRestaurant(in: nameMatches, to: userLocation) {
                return .partialNameResult(restaurant: closest, matches: nameMatches)
            }
        }
        
        return .noResults(query: query)
    }
    
    private func isLikelyChainRestaurant(query: String) -> Bool {
        let chainKeywords = [
            "mcdonald", "burger king", "subway", "starbucks", "kfc", "pizza hut",
            "domino", "taco bell", "wendy", "dunkin", "chipotle", "panda express",
            "olive garden", "applebee", "chili", "outback", "red lobster"
        ]
        
        return chainKeywords.contains { query.contains($0) }
    }
    
    private func findClosestRestaurant(in restaurants: [Restaurant], to userLocation: CLLocation?) -> Restaurant? {
        guard let userLocation = userLocation else {
            return restaurants.first
        }
        
        return restaurants.min { restaurant1, restaurant2 in
            let location1 = CLLocation(latitude: restaurant1.latitude, longitude: restaurant1.longitude)
            let location2 = CLLocation(latitude: restaurant2.latitude, longitude: restaurant2.longitude)
            
            let distance1 = userLocation.distance(from: location1)
            let distance2 = userLocation.distance(from: location2)
            
            return distance1 < distance2
        }
    }
    
    private func sortByDistance(_ restaurants: [Restaurant], from userLocation: CLLocation?) -> [Restaurant] {
        guard let userLocation = userLocation else {
            return restaurants
        }
        
        return restaurants.sorted { restaurant1, restaurant2 in
            let location1 = CLLocation(latitude: restaurant1.latitude, longitude: restaurant1.longitude)
            let location2 = CLLocation(latitude: restaurant2.latitude, longitude: restaurant2.longitude)
            
            let distance1 = userLocation.distance(from: location1)
            let distance2 = userLocation.distance(from: location2)
            
            return distance1 < distance2
        }
    }
    
    private func applyDistanceFilter(_ restaurants: [Restaurant], userLocation: CLLocation?, maxDistance: Double?) -> [Restaurant] {
        guard let userLocation = userLocation, let maxDistance = maxDistance else {
            return restaurants
        }
        
        let maxDistanceInMeters = maxDistance * 1609.34 // Convert miles to meters
        
        return restaurants.filter { restaurant in
            let restaurantLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
            let distance = userLocation.distance(from: restaurantLocation)
            return distance <= maxDistanceInMeters
        }
    }
}

enum SearchResult {
    case noQuery
    case noResults(query: String)
    case singleResult(restaurant: Restaurant)
    case chainResult(restaurant: Restaurant, totalCount: Int)
    case cuisineResults(restaurants: [Restaurant], cuisine: String)
    case partialNameResult(restaurant: Restaurant, matches: [Restaurant])
    
    var hasResults: Bool {
        switch self {
        case .noQuery, .noResults:
            return false
        default:
            return true
        }
    }
    
    var shouldZoomToLocation: Bool {
        switch self {
        case .singleResult, .chainResult, .partialNameResult:
            return true
        default:
            return false
        }
    }
    
    var restaurants: [Restaurant] {
        switch self {
        case .singleResult(let restaurant):
            return [restaurant]
        case .chainResult(let restaurant, _):
            return [restaurant]
        case .cuisineResults(let restaurants, _):
            return restaurants
        case .partialNameResult(let restaurant, _):
            return [restaurant]
        default:
            return []
        }
    }
}
