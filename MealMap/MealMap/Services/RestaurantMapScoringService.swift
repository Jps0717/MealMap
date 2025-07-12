import Foundation
import SwiftUI
import Combine

/// Service for calculating restaurant scores on the map for restaurants with nutrition data
class RestaurantMapScoringService: ObservableObject {
    static let shared = RestaurantMapScoringService()
    
    @Published var restaurantScores: [Int: RestaurantMapScore] = [:]
    @Published var isCalculatingScores = false
    
    private let nutritionManager = NutritionDataManager.shared
    private let menuItemScoringService = MenuItemScoringService.shared
    private let authService = FirebaseAuthService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAuthObserver()
    }
    
    // MARK: - Authentication Observer
    private func setupAuthObserver() {
        authService.$currentUser
            .dropFirst()
            .sink { [weak self] _ in
                // Clear scores when user changes (different preferences)
                self?.clearAllScores()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Main Scoring Functions
    
    /// Calculate scores for a batch of restaurants (map viewport)
    func calculateScoresForRestaurants(_ restaurants: [Restaurant]) async {
        let nutritionRestaurants = restaurants.filter { $0.hasNutritionData }
        
        guard !nutritionRestaurants.isEmpty else {
            debugLog("📊 No nutrition restaurants to score")
            return
        }
        
        await MainActor.run {
            isCalculatingScores = true
        }
        
        debugLog("📊 Calculating scores for \(nutritionRestaurants.count) restaurants")
        
        // Process restaurants in batches to avoid overwhelming the system
        let batchSize = 5
        for batch in nutritionRestaurants.chunked(into: batchSize) {
            await processBatch(batch)
            
            // Small delay between batches to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        await MainActor.run {
            isCalculatingScores = false
        }
        
        debugLog("📊 Finished calculating scores. Total scored: \(restaurantScores.count)")
    }
    
    /// Calculate score for a single restaurant
    func calculateScoreForRestaurant(_ restaurant: Restaurant) async -> RestaurantMapScore? {
        guard restaurant.hasNutritionData else {
            debugLog("📊 Restaurant \(restaurant.name) has no nutrition data")
            return nil
        }
        
        // Check if we already have a score
        if let existingScore = restaurantScores[restaurant.id] {
            debugLog("📊 Using cached score for \(restaurant.name)")
            return existingScore
        }
        
        debugLog("📊 Calculating new score for \(restaurant.name)")
        
        // Load nutrition data
        let nutritionData = await loadNutritionData(for: restaurant)
        guard let nutritionData = nutritionData else {
            debugLog("📊 Failed to load nutrition data for \(restaurant.name)")
            return nil
        }
        
        // Calculate menu item scores
        let menuScores = calculateMenuItemScores(from: nutritionData)
        
        // Calculate overall restaurant score
        let restaurantScore = calculateRestaurantScore(from: menuScores, restaurant: restaurant)
        
        // Store the score
        await MainActor.run {
            restaurantScores[restaurant.id] = restaurantScore
        }
        
        debugLog("📊 Calculated score for \(restaurant.name): \(Int(restaurantScore.overallScore))")
        return restaurantScore
    }
    
    /// Get cached score for a restaurant
    func getScoreForRestaurant(_ restaurant: Restaurant) -> RestaurantMapScore? {
        return restaurantScores[restaurant.id]
    }
    
    /// Clear all cached scores
    func clearAllScores() {
        restaurantScores.removeAll()
        debugLog("📊 Cleared all restaurant scores")
    }
    
    // MARK: - Private Helper Methods
    
    private func processBatch(_ restaurants: [Restaurant]) async {
        await withTaskGroup(of: Void.self) { group in
            for restaurant in restaurants {
                group.addTask {
                    await self.calculateScoreForRestaurant(restaurant)
                }
            }
        }
    }
    
    private func loadNutritionData(for restaurant: Restaurant) async -> RestaurantNutritionData? {
        // Try to get existing data first
        if let existingData = await nutritionManager.currentRestaurantData,
           existingData.restaurantName.lowercased() == restaurant.name.lowercased() {
            return existingData
        }
        
        // Load fresh data
        return await withCheckedContinuation { continuation in
            Task {
                // Load nutrition data on background thread
                await nutritionManager.loadNutritionData(for: restaurant.name)
                
                // Wait for data to load (with timeout)
                for _ in 0..<20 { // 2 second timeout
                    if let data = await nutritionManager.currentRestaurantData,
                       data.restaurantName.lowercased().contains(restaurant.name.lowercased()) {
                        continuation.resume(returning: data)
                        return
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
                
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func calculateMenuItemScores(from restaurantData: RestaurantNutritionData) -> [String: MenuItemScore] {
        var scores: [String: MenuItemScore] = [:]
        let currentUser = authService.currentUser
        
        for item in restaurantData.items {
            let analyzedItem = convertNutritionDataToAnalyzedMenuItem(item)
            let score = menuItemScoringService.calculatePersonalizedScore(
                for: analyzedItem,
                user: currentUser
            )
            scores[item.item] = score
        }
        
        return scores
    }
    
    private func convertNutritionDataToAnalyzedMenuItem(_ item: NutritionData) -> AnalyzedMenuItem {
        let nutritionEstimate = NutritionEstimate(
            calories: NutritionRange(min: item.calories, max: item.calories, unit: "kcal"),
            carbs: NutritionRange(min: item.carbs, max: item.carbs, unit: "g"),
            protein: NutritionRange(min: item.protein, max: item.protein, unit: "g"),
            fat: NutritionRange(min: item.fat, max: item.fat, unit: "g"),
            fiber: NutritionRange(min: item.fiber, max: item.fiber, unit: "g"),
            sodium: NutritionRange(min: item.sodium, max: item.sodium, unit: "mg"),
            sugar: NutritionRange(min: item.sugar, max: item.sugar, unit: "g"),
            confidence: 0.95,
            estimationSource: .nutritionix,
            sourceDetails: "Restaurant nutrition database",
            estimatedPortionSize: "1 serving",
            portionConfidence: 0.9
        )
        
        return AnalyzedMenuItem(
            name: item.item,
            description: nil,
            price: nil,
            ingredients: [],
            nutritionEstimate: nutritionEstimate,
            dietaryTags: generateDietaryTags(for: item),
            confidence: 0.95,
            textBounds: nil,
            estimationTier: .nutritionix,
            isGeneralizedEstimate: false
        )
    }
    
    private func generateDietaryTags(for item: NutritionData) -> [DietaryTag] {
        var tags: [DietaryTag] = []
        
        if item.protein >= 20 {
            tags.append(.highProtein)
        }
        
        if item.carbs <= 15 {
            tags.append(.lowCarb)
        }
        
        if item.carbs >= 45 {
            tags.append(.highCarb)
        }
        
        if item.sodium <= 600 {
            tags.append(.lowSodium)
        }
        
        if item.fiber >= 5 {
            tags.append(.highFiber)
        }
        
        if item.calories <= 500 && item.protein >= 15 && item.sodium <= 800 && item.saturatedFat <= 10 {
            tags.append(.healthy)
        }
        
        if item.calories >= 800 || item.fat >= 30 || item.sugar >= 25 {
            tags.append(.indulgent)
        }
        
        return tags
    }
    
    private func calculateRestaurantScore(from menuScores: [String: MenuItemScore], restaurant: Restaurant) -> RestaurantMapScore {
        let scores = Array(menuScores.values.map { $0.overallScore })
        
        guard !scores.isEmpty else {
            return RestaurantMapScore(
                restaurantId: restaurant.id,
                restaurantName: restaurant.name,
                overallScore: 0,
                menuItemCount: 0,
                scoredItemCount: 0,
                averageScore: 0,
                topRatedItems: [],
                scoreGrade: ScoreGrade.fromScore(0),
                isPersonalized: authService.currentUser != nil,
                calculatedAt: Date()
            )
        }
        
        let averageScore = scores.reduce(0, +) / Double(scores.count)
        let topRatedItems = getTopRatedItems(from: menuScores)
        
        return RestaurantMapScore(
            restaurantId: restaurant.id,
            restaurantName: restaurant.name,
            overallScore: averageScore,
            menuItemCount: menuScores.count,
            scoredItemCount: scores.count,
            averageScore: averageScore,
            topRatedItems: topRatedItems,
            scoreGrade: ScoreGrade.fromScore(averageScore),
            isPersonalized: authService.currentUser != nil,
            calculatedAt: Date()
        )
    }
    
    private func getTopRatedItems(from menuScores: [String: MenuItemScore]) -> [String] {
        return menuScores
            .sorted { $0.value.overallScore > $1.value.overallScore }
            .prefix(3)
            .map { $0.key }
    }
}

// MARK: - Restaurant Map Score Model
struct RestaurantMapScore: Identifiable {
    let id = UUID()
    let restaurantId: Int
    let restaurantName: String
    let overallScore: Double
    let menuItemCount: Int
    let scoredItemCount: Int
    let averageScore: Double
    let topRatedItems: [String]
    let scoreGrade: ScoreGrade
    let isPersonalized: Bool
    let calculatedAt: Date
    
    var scoreColor: Color {
        scoreGrade.color
    }
    
    var scoreEmoji: String {
        scoreGrade.emoji
    }
    
    var shortDescription: String {
        if isPersonalized {
            return "Personalized: \(scoreGrade.rawValue)"
        } else {
            return "Health Score: \(scoreGrade.rawValue)"
        }
    }
    
    var detailedDescription: String {
        return "\(scoredItemCount) items scored • Average: \(Int(averageScore))"
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}