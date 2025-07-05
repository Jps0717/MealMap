import Foundation
import VisionKit
import Vision
import UIKit
import CoreImage

// MARK: - Supporting Types
struct RawMenuItem: Identifiable {
    let id: UUID
    let name: String
    var description: String?
    let price: String?
    let textBounds: CGRect
    let confidence: Double
}

enum OCRError: Error, LocalizedError {
    case imageProcessingFailed
    case visionProcessingFailed(Error)
    case noTextFound
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process image for OCR"
        case .visionProcessingFailed(let error):
            return "Vision framework error: \(error.localizedDescription)"
        case .noTextFound:
            return "No text found in image"
        }
    }
}

@MainActor
class MenuOCRService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var lastError: Error?
    
    // MARK: - Cancellation Support
    private var currentTask: Task<Void, Never>?
    
    /// Cancel the current processing task
    func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
        progress = 0.0
    }
    
    // MARK: - Main Pipeline: AI + Nutritionix Only
    
    /// Complete image-to-menu pipeline with AI parsing + Nutritionix API integration
    func processMenuImageWithAINutritionix(_ image: UIImage) async throws -> [ValidatedMenuItem] {
        isProcessing = true
        progress = 0.0
        defer { 
            isProcessing = false
            progress = 1.0
        }
        
        // Check for cancellation
        try Task.checkCancellation()
        
        print("[MenuOCRService] 🤖🥗 Starting AI + Nutritionix pipeline...")
        
        // Step 1: Text Extraction (0-25%)
        progress = 0.0
        let textLines = try await extractTextWithVision(image)
        try Task.checkCancellation() // Check for cancellation
        progress = 0.25
        
        // Step 2: AI/LLM Menu Parsing (25-60%)
        let rawMenuText = textLines.joined(separator: "\n")
        let llmService = LLMMenuParsingService.shared
        let aiParsedItems = try await llmService.parseMenuText(rawMenuText)
        try Task.checkCancellation() // Check for cancellation
        progress = 0.6
        
        // Step 3: Nutritionix Analysis (60-95%)
        let nutritionixResults = await analyzeAIParsedItemsWithNutritionix(aiParsedItems)
        try Task.checkCancellation() // Check for cancellation
        progress = 0.95
        
        // Step 4: Create final result (95-100%)
        let validatedItems = createValidatedItemsFromAINutritionix(nutritionixResults)
        progress = 1.0
        
        print("[MenuOCRService] 🤖🥗 AI + Nutritionix pipeline complete: \(validatedItems.count) items analyzed")
        logAINutritionixSummary(validatedItems, aiItems: aiParsedItems.count)
        return validatedItems
    }
    
    // MARK: - Step 1: Text Extraction using Vision.framework
    
    private func extractTextWithVision(_ image: UIImage) async throws -> [String] {
        print("[MenuOCRService] 🔍 Starting Vision.framework text extraction...")
        
        guard let cgImage = image.cgImage else {
            throw OCRError.imageProcessingFailed
        }
        
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.recognitionLanguages = ["en_US"]
        textRequest.usesLanguageCorrection = true
        
        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([textRequest])
                    
                    let observations = textRequest.results as? [VNRecognizedTextObservation] ?? []
                    let textLines = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    
                    print("[MenuOCRService] 🔍 Vision extracted \(textLines.count) text lines")
                    continuation.resume(returning: textLines)
                } catch {
                    continuation.resume(throwing: OCRError.visionProcessingFailed(error))
                }
            }
        }
    }
    
    // MARK: - AI + Nutritionix Integration Methods
    
    private func analyzeAIParsedItemsWithNutritionix(_ aiParsedItems: [String]) async -> [NutritionixNutritionResult] {
        print("[MenuOCRService] 🤖🥗 Starting Nutritionix analysis for \(aiParsedItems.count) AI-parsed items...")
        
        let nutritionixService = NutritionixAPIService.shared
        var results: [NutritionixNutritionResult] = []
        
        // Process all AI-parsed items (they should already be clean)
        for (index, item) in aiParsedItems.enumerated() {
            // Check for cancellation before processing each item
            if Task.isCancelled {
                print("[MenuOCRService] 🤖🥗 Analysis cancelled by user")
                break
            }
            
            // Update progress (60-95% range)
            let progressRange = 0.6...0.95
            let itemProgress = Double(index) / Double(aiParsedItems.count)
            progress = progressRange.lowerBound + (itemProgress * (progressRange.upperBound - progressRange.lowerBound))
            
            print("[MenuOCRService] 🤖🥗 Analyzing AI item \(index + 1)/\(aiParsedItems.count): '\(item)'")
            
            do {
                let result = try await nutritionixService.analyzeMenuItem(item)
                results.append(result)
                
                if result.isSuccess {
                    print("[MenuOCRService] 🤖🥗 ✅ Success: '\(item)' → \(result.nutrition.displayCalories) cal, \(result.nutrition.displayProtein) protein, \(result.nutrition.fiber ?? 0) fiber")
                } else {
                    print("[MenuOCRService] 🤖🥗 ❌ Failed: '\(item)' - \(result.errorMessage ?? "Unknown error")")
                }
            } catch {
                print("[MenuOCRService] 🤖🥗 ⚠️ Error analyzing '\(item)': \(error)")
                
                // Create a failure result
                let failureResult = NutritionixNutritionResult(
                    originalQuery: item,
                    matchedFoodName: item,
                    brandName: nil,
                    servingDescription: "Unknown",
                    nutrition: NutritionixNutritionData(
                        calories: 0, protein: 0, carbs: 0, fat: 0,
                        fiber: nil, sodium: 0, sugar: nil,
                        saturatedFat: nil, cholesterol: nil, potassium: nil
                    ),
                    confidence: 0.0,
                    source: .unknown,
                    isSuccess: false,
                    errorMessage: error.localizedDescription
                )
                results.append(failureResult)
            }
            
            // Rate limiting - Nutritionix enforces this
            try? await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds
        }
        
        let successCount = results.filter { $0.isSuccess }.count
        print("[MenuOCRService] 🤖🥗 AI + Nutritionix analysis complete: \(successCount)/\(results.count) successful")
        
        return results
    }
    
    private func createValidatedItemsFromAINutritionix(_ nutritionixResults: [NutritionixNutritionResult]) -> [ValidatedMenuItem] {
        return nutritionixResults.map { result in
            // Convert Nutritionix nutrition data to NutritionInfo if successful
            let nutritionInfo: NutritionInfo? = result.isSuccess ? NutritionInfo(
                calories: result.nutrition.calories,
                protein: result.nutrition.protein,
                carbs: result.nutrition.carbs,
                fat: result.nutrition.fat,
                fiber: result.nutrition.fiber,
                sodium: result.nutrition.sodium,
                sugar: result.nutrition.sugar
            ) : nil
            
            return ValidatedMenuItem(
                originalLine: result.originalQuery,
                validatedName: result.isSuccess ? result.matchedFoodName : result.originalQuery,
                spoonacularId: 0, // Not applicable for Nutritionix
                imageUrl: nil,
                nutritionInfo: nutritionInfo,
                isValid: result.isSuccess
            )
        }
    }
    
    // MARK: - AI + Nutritionix Analysis Summary Logging
    
    private func logAINutritionixSummary(_ validatedItems: [ValidatedMenuItem], aiItems: Int) {
        let successCount = validatedItems.filter { $0.isValid }.count
        let failureCount = validatedItems.filter { !$0.isValid }.count
        
        // Calculate nutrition stats for successful items
        let successfulItems = validatedItems.filter { $0.isValid && $0.nutritionInfo != nil }
        let avgCalories = successfulItems.isEmpty ? 0 : Int(successfulItems.compactMap { $0.nutritionInfo?.calories }.reduce(0, +) / Double(successfulItems.count))
        let avgProtein = successfulItems.isEmpty ? 0 : Int(successfulItems.compactMap { $0.nutritionInfo?.protein }.reduce(0, +) / Double(successfulItems.count))
        
        print("[MenuOCRService] \n\n🤖🥗 AI + NUTRITIONIX PIPELINE SUMMARY:\nAI Parsing Results: \(aiItems) menu items extracted\nNutritionix Analysis: \(validatedItems.count) items processed\n\nRESULTS:\n✅ Successful nutrition analysis: \(successCount) items\n❌ Failed nutrition analysis: \(failureCount) items\n📊 Average calories: \(avgCalories) kcal\n🥩 Average protein: \(avgProtein)g\n\nSUCCESS RATE: \(Int(Double(successCount) / Double(validatedItems.count) * 100))%\n\nPIPELINE FEATURES:\n🤖 AI-powered menu structure parsing\n🥗 High-accuracy Nutritionix nutrition analysis\n📊 Natural language food understanding\n🎯 Intelligent menu item extraction\n⚡ Real-time nutrition data\n💾 Complete nutrition profiles saved\n")
        
        // Log sample successful items
        if !successfulItems.isEmpty {
            print("[MenuOCRService] 🎯 SAMPLE SUCCESSFUL ANALYSES:")
            for item in successfulItems.prefix(3) {
                if let nutrition = item.nutritionInfo {
                    print("   • \(item.validatedName): \(Int(nutrition.calories ?? 0)) cal, \(String(format: "%.1f", nutrition.protein ?? 0))g protein")
                }
            }
        }
    }
    
    // MARK: - Legacy Methods for Backward Compatibility
    
    /// Legacy method that now redirects to AI + Nutritionix pipeline
    func analyzeMenuImage(_ image: UIImage) async throws -> MenuAnalysisResult {
        print("[MenuOCRService] 🔄 Legacy analyzeMenuImage called - redirecting to AI + Nutritionix pipeline...")
        
        let validatedItems = try await processMenuImageWithAINutritionix(image)
        
        // Convert ValidatedMenuItem to AnalyzedMenuItem for compatibility
        let analyzedItems = validatedItems.map { item in
            // Create proper Nutritionix result for conversion
            let nutritionixResult = NutritionixNutritionResult(
                originalQuery: item.originalLine,
                matchedFoodName: item.validatedName,
                brandName: nil,
                servingDescription: "1 serving",
                nutrition: NutritionixNutritionData(
                    calories: item.nutritionInfo?.calories ?? 0,
                    protein: item.nutritionInfo?.protein ?? 0,
                    carbs: item.nutritionInfo?.carbs ?? 0,
                    fat: item.nutritionInfo?.fat ?? 0,
                    fiber: item.nutritionInfo?.fiber,
                    sodium: item.nutritionInfo?.sodium ?? 0,
                    sugar: item.nutritionInfo?.sugar,
                    saturatedFat: nil,
                    cholesterol: nil,
                    potassium: nil
                ),
                confidence: item.isValid ? 0.8 : 0.0,
                source: item.isValid ? .restaurant : .unknown,
                isSuccess: item.isValid,
                errorMessage: item.isValid ? nil : "Analysis failed"
            )
            
            return item.isValid ? 
                AnalyzedMenuItem.createWithNutritionix(
                    name: item.validatedName,
                    description: item.originalLine != item.validatedName ? item.originalLine : nil,
                    price: nil,
                    nutritionixResult: nutritionixResult,
                    textBounds: nil
                ) :
                AnalyzedMenuItem.createUnavailable(
                    name: item.validatedName,
                    description: item.originalLine,
                    price: nil,
                    textBounds: nil
                )
        }
        
        return MenuAnalysisResult(
            restaurantName: nil,
            location: nil,
            menuItems: analyzedItems,
            analysisDate: Date(),
            imageData: image.jpegData(compressionQuality: 0.8),
            confidence: calculateOverallConfidence(analyzedItems)
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateOverallConfidence(_ items: [AnalyzedMenuItem]) -> Double {
        guard !items.isEmpty else { return 0.0 }
        return items.map { $0.confidence }.reduce(0, +) / Double(items.count)
    }
}