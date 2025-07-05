import SwiftUI

// MARK: - Menu Analysis Progress Observable Object

class MenuAnalysisProgress: ObservableObject {
    @Published var totalItems: Int = 0
    @Published var analyzedItems: [AnalyzedMenuItem] = []
    @Published var isAnalyzing: Bool = false
    @Published var analysisError: Error?
    @Published var currentItem: String = ""
    
    // Progress tracking
    var progress: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(analyzedItems.count) / Double(totalItems)
    }
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var itemsWithNutrition: Int {
        analyzedItems.filter { $0.estimationTier != .unavailable }.count
    }
    
    var successRate: Double {
        guard !analyzedItems.isEmpty else { return 0.0 }
        return Double(itemsWithNutrition) / Double(analyzedItems.count)
    }
    
    var detailedStats: AnalysisStats {
        let nutritionixCount = analyzedItems.filter { $0.estimationTier == .nutritionix }.count
        let unavailableCount = analyzedItems.filter { $0.estimationTier == .unavailable }.count
        
        return AnalysisStats(
            total: analyzedItems.count,
            withNutrition: itemsWithNutrition,
            nutritionixCount: nutritionixCount,
            unavailableCount: unavailableCount,
            successRate: successRate
        )
    }
    
    func startAnalysis(totalItems: Int) {
        DispatchQueue.main.async {
            self.totalItems = totalItems
            self.analyzedItems = []
            self.isAnalyzing = true
            self.analysisError = nil
            self.currentItem = ""
        }
    }
    
    func addAnalyzedItem(_ item: AnalyzedMenuItem) {
        DispatchQueue.main.async {
            self.analyzedItems.append(item)
            self.currentItem = item.name
        }
    }
    
    func completeAnalysis() {
        DispatchQueue.main.async {
            self.isAnalyzing = false
            self.currentItem = ""
        }
    }
    
    func setError(_ error: Error) {
        DispatchQueue.main.async {
            self.analysisError = error
            self.isAnalyzing = false
        }
    }
    
    func reset() {
        DispatchQueue.main.async {
            self.totalItems = 0
            self.analyzedItems = []
            self.isAnalyzing = false
            self.analysisError = nil
            self.currentItem = ""
        }
    }
}

// MARK: - Supporting Types for Analysis Stats

struct AnalysisStats {
    let total: Int
    let withNutrition: Int
    let nutritionixCount: Int
    let unavailableCount: Int
    let successRate: Double
    
    var successPercentage: Int {
        Int(successRate * 100)
    }
}