import Foundation
import SwiftUI
import Combine

/// Service for calculating restaurant scores on the map for restaurants with nutrition data
class RestaurantMapScoringService: ObservableObject {
    static let shared = RestaurantMapScoringService()
    
    @Published var restaurantScores: [Int: RestaurantMapScore] = [:]
    @Published var chainScores: [String: ChainScore] = [:]
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
    
    /// Calculate scores for a batch of restaurants (map viewport) - OPTIMIZED FOR CHAINS
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
        
        // Group restaurants by chain name for efficient processing
        let chainGroups = Dictionary(grouping: nutritionRestaurants) { restaurant in
            getChainName(for: restaurant)
        }
        
        debugLog("📊 Processing \(chainGroups.count) unique chains")
        
        // Process each chain once
        for (chainName, chainRestaurants) in chainGroups {
            await processChain(chainName: chainName, restaurants: chainRestaurants)
            
            // Small delay between chains to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        await MainActor.run {
            isCalculatingScores = false
        }
        
        debugLog("📊 Finished calculating scores. Chains: \(chainScores.count), Individual: \(restaurantScores.count)")
    }
    
    /// Get score for a restaurant - checks chain cache first, then individual cache
    func getScoreForRestaurant(_ restaurant: Restaurant) -> RestaurantMapScore? {
        let chainName = getChainName(for: restaurant)
        
        // Check if we have a chain score
        if let chainScore = chainScores[chainName] {
            return RestaurantMapScore(
                restaurantId: restaurant.id,
                restaurantName: restaurant.name,
                overallScore: chainScore.overallScore,
                menuItemCount: chainScore.menuItemCount,
                scoredItemCount: chainScore.scoredItemCount,
                averageScore: chainScore.averageScore,
                topRatedItems: chainScore.topRatedItems,
                scoreGrade: chainScore.scoreGrade,
                isPersonalized: chainScore.isPersonalized,
                calculatedAt: chainScore.calculatedAt,
                isChainScore: true,
                chainName: chainName
            )
        }
        
        // Fall back to individual restaurant score
        return restaurantScores[restaurant.id]
    }
    
    /// Calculate score for a single restaurant - uses chain optimization
    func calculateScoreForRestaurant(_ restaurant: Restaurant) async -> RestaurantMapScore? {
        guard restaurant.hasNutritionData else {
            debugLog("📊 Restaurant \(restaurant.name) has no nutrition data")
            return nil
        }
        
        let chainName = getChainName(for: restaurant)
        
        // Check if we already have a chain score
        if let chainScore = chainScores[chainName] {
            debugLog("📊 Using cached chain score for \(restaurant.name) (\(chainName))")
            return RestaurantMapScore(
                restaurantId: restaurant.id,
                restaurantName: restaurant.name,
                overallScore: chainScore.overallScore,
                menuItemCount: chainScore.menuItemCount,
                scoredItemCount: chainScore.scoredItemCount,
                averageScore: chainScore.averageScore,
                topRatedItems: chainScore.topRatedItems,
                scoreGrade: chainScore.scoreGrade,
                isPersonalized: chainScore.isPersonalized,
                calculatedAt: chainScore.calculatedAt,
                isChainScore: true,
                chainName: chainName
            )
        }
        
        debugLog("📊 Calculating new chain score for \(chainName)")
        
        // Calculate chain score (will be reused for all locations)
        return await calculateChainScore(chainName: chainName, representative: restaurant)
    }
    
    /// Clear all cached scores
    func clearAllScores() {
        restaurantScores.removeAll()
        chainScores.removeAll()
        debugLog("📊 Cleared all restaurant and chain scores")
    }
    
    // MARK: - Chain Processing Methods
    
    private func processChain(chainName: String, restaurants: [Restaurant]) async {
        // Check if we already have a chain score
        if chainScores[chainName] != nil {
            debugLog("📊 Using cached chain score for \(chainName)")
            return
        }
        
        // Use first restaurant as representative for the chain
        guard let representative = restaurants.first else { return }
        
        await calculateChainScore(chainName: chainName, representative: representative)
    }
    
    @discardableResult
    private func calculateChainScore(chainName: String, representative: Restaurant) async -> RestaurantMapScore? {
        debugLog("📊 Calculating new chain score for \(chainName)")
        
        // Load nutrition data for the chain
        let nutritionData = await loadNutritionData(for: representative)
        guard let nutritionData = nutritionData else {
            debugLog("📊 Failed to load nutrition data for \(chainName)")
            return nil
        }
        
        // Calculate menu item scores
        let menuScores = calculateMenuItemScores(from: nutritionData)
        
        // Calculate chain score
        let chainScore = calculateChainScore(from: menuScores, chainName: chainName)
        
        // Store the chain score
        await MainActor.run {
            chainScores[chainName] = chainScore
        }
        
        debugLog("📊 Calculated chain score for \(chainName): \(Int(chainScore.overallScore))")
        
        // Return as restaurant map score
        return RestaurantMapScore(
            restaurantId: representative.id,
            restaurantName: representative.name,
            overallScore: chainScore.overallScore,
            menuItemCount: chainScore.menuItemCount,
            scoredItemCount: chainScore.scoredItemCount,
            averageScore: chainScore.averageScore,
            topRatedItems: chainScore.topRatedItems,
            scoreGrade: chainScore.scoreGrade,
            isPersonalized: chainScore.isPersonalized,
            calculatedAt: chainScore.calculatedAt,
            isChainScore: true,
            chainName: chainName
        )
    }
    
    private func getChainName(for restaurant: Restaurant) -> String {
        // Use the restaurant name as the chain identifier
        // This works because our nutrition data is organized by chain name
        return restaurant.name
    }
    
    private func calculateChainScore(from menuScores: [String: MenuItemScore], chainName: String) -> ChainScore {
        let scores = Array(menuScores.values.map { $0.overallScore })
        
        guard !scores.isEmpty else {
            return ChainScore(
                chainName: chainName,
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
        
        return ChainScore(
            chainName: chainName,
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
    
    // MARK: - Private Helper Methods (unchanged)
    
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
    
    private func getTopRatedItems(from menuScores: [String: MenuItemScore]) -> [String] {
        return menuScores
            .sorted { $0.value.overallScore > $1.value.overallScore }
            .prefix(3)
            .map { $0.key }
    }
}

// MARK: - Chain Score Model
struct ChainScore: Identifiable {
    let id = UUID()
    let chainName: String
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
}

// MARK: - Enhanced Restaurant Map Score Model
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
    let isChainScore: Bool
    let chainName: String?
    
    // Legacy initializer for backward compatibility
    init(restaurantId: Int, restaurantName: String, overallScore: Double, menuItemCount: Int, scoredItemCount: Int, averageScore: Double, topRatedItems: [String], scoreGrade: ScoreGrade, isPersonalized: Bool, calculatedAt: Date) {
        self.restaurantId = restaurantId
        self.restaurantName = restaurantName
        self.overallScore = overallScore
        self.menuItemCount = menuItemCount
        self.scoredItemCount = scoredItemCount
        self.averageScore = averageScore
        self.topRatedItems = topRatedItems
        self.scoreGrade = scoreGrade
        self.isPersonalized = isPersonalized
        self.calculatedAt = calculatedAt
        self.isChainScore = false
        self.chainName = nil
    }
    
    // New initializer with chain support
    init(restaurantId: Int, restaurantName: String, overallScore: Double, menuItemCount: Int, scoredItemCount: Int, averageScore: Double, topRatedItems: [String], scoreGrade: ScoreGrade, isPersonalized: Bool, calculatedAt: Date, isChainScore: Bool, chainName: String?) {
        self.restaurantId = restaurantId
        self.restaurantName = restaurantName
        self.overallScore = overallScore
        self.menuItemCount = menuItemCount
        self.scoredItemCount = scoredItemCount
        self.averageScore = averageScore
        self.topRatedItems = topRatedItems
        self.scoreGrade = scoreGrade
        self.isPersonalized = isPersonalized
        self.calculatedAt = calculatedAt
        self.isChainScore = isChainScore
        self.chainName = chainName
    }
    
    var scoreColor: Color {
        scoreGrade.color
    }
    
    var scoreEmoji: String {
        scoreGrade.emoji
    }
    
    var shortDescription: String {
        let baseDescription = isPersonalized ? "Personalized: \(scoreGrade.rawValue)" : "Health Score: \(scoreGrade.rawValue)"
        return isChainScore ? "Chain: \(baseDescription)" : baseDescription
    }
    
    var detailedDescription: String {
        let baseDescription = "\(scoredItemCount) items scored • Average: \(Int(averageScore))"
        return isChainScore ? "Chain-wide: \(baseDescription)" : baseDescription
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