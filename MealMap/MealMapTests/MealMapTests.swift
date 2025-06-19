//
//  MealMapTests.swift
//  MealMapTests
//
//  Created by Jackson Shell on 6/4/25.
//

import Testing
@testable import MealMap

struct MealMapTests {
    
    @Test func testRestaurantDataLoading() async throws {
        let nutritionManager = NutritionDataManager()
        #expect(!nutritionManager.getAvailableRestaurants().isEmpty, "Should have available restaurants")
    }
    
    @Test func testRestaurantMatching() async throws {
        let restaurant = Restaurant(
            id: 1,
            name: "McDonald's",
            latitude: 37.7749,
            longitude: -122.4194,
            address: "123 Main St",
            cuisine: "American",
            openingHours: "24/7",
            phone: nil,
            website: nil,
            type: "node"
        )
        
        #expect(restaurant.matchesCategory(.fastFood), "McDonald's should match fast food category")
        #expect(restaurant.hasNutritionData, "McDonald's should have nutrition data")
    }
}
