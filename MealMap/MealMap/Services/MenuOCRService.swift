import Foundation
import VisionKit
import Vision
import UIKit
import CoreImage

@MainActor
class MenuOCRService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var lastError: Error?
    
    // MARK: - OCR Processing
    func analyzeMenuImage(_ image: UIImage) async throws -> MenuAnalysisResult {
        isProcessing = true
        progress = 0.0
        defer { 
            isProcessing = false
            progress = 1.0
        }
        
        debugLog(" Starting menu image analysis...")
        
        // Step 1: Preprocess image (20% progress)
        let processedImage = preprocessImage(image)
        progress = 0.2
        
        // Step 2: Extract text using Vision (40% progress)
        let textObservations = try await extractTextFromImage(processedImage)
        progress = 0.4
        
        // Step 3: Parse menu structure (60% progress)
        let menuItems = try await parseMenuStructure(textObservations, image: processedImage)
        progress = 0.6
        
        // Step 4: Analyze ingredients and nutrition (80% progress)
        let analyzedItems = try await analyzeMenuItems(menuItems)
        progress = 0.8
        
        // Step 5: Create final result (100% progress)
        let result = MenuAnalysisResult(
            restaurantName: detectRestaurantName(from: textObservations),
            location: nil, // Could be filled from current location
            menuItems: analyzedItems,
            analysisDate: Date(),
            imageData: image.jpegData(compressionQuality: 0.8),
            confidence: calculateOverallConfidence(analyzedItems)
        )
        
        progress = 1.0
        debugLog(" Menu analysis complete: \(result.menuItems.count) items found")
        return result
    }
    
    // MARK: - Image Preprocessing
    private func preprocessImage(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let context = CIContext()
        
        // Apply filters to improve OCR accuracy
        let filters: [CIFilter] = [
            // Enhance contrast
            CIFilter(name: "CIColorControls", parameters: [
                kCIInputImageKey: ciImage,
                "inputContrast": 1.2,
                "inputBrightness": 0.1
            ]),
            
            // Sharpen text
            CIFilter(name: "CISharpenLuminance", parameters: [
                "inputSharpness": 0.4
            ])
        ].compactMap { $0 }
        
        var outputImage = ciImage
        for filter in filters {
            filter.setValue(outputImage, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                outputImage = output
            }
        }
        
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Text Extraction
    private func extractTextFromImage(_ image: UIImage) async throws -> [VNRecognizedTextObservation] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                continuation.resume(returning: observations)
            }
            
            // Configure for menu text recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Menu Structure Parsing
    private func parseMenuStructure(
        _ observations: [VNRecognizedTextObservation],
        image: UIImage
    ) async throws -> [RawMenuItem] {
        
        var rawItems: [RawMenuItem] = []
        var currentSection: String?
        var pendingName: String?
        var pendingBounds: CGRect?
        
        // Sort observations by position (top to bottom, left to right)
        let sortedObservations = observations.sorted { obs1, obs2 in
            let rect1 = obs1.boundingBox
            let rect2 = obs2.boundingBox
            
            // First sort by Y position (top to bottom)
            if abs(rect1.minY - rect2.minY) > 0.05 {
                return rect1.minY > rect2.minY // Vision coordinates are flipped
            }
            // Then by X position (left to right)
            return rect1.minX < rect2.minX
        }
        
        for observation in sortedObservations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            let confidence = topCandidate.confidence
            
            if text.isEmpty || confidence < 0.3 { continue }
            
            let bounds = observation.boundingBox
            
            // Detect section headers (ALL CAPS, centered, etc.)
            if isLikelySectionHeader(text) {
                currentSection = text
                continue
            }
            
            // Detect prices
            if let price = extractPrice(from: text) {
                // If we have a pending name, create menu item
                if let name = pendingName, let nameBounds = pendingBounds {
                    let item = RawMenuItem(
                        name: name,
                        description: nil,
                        price: price,
                        section: currentSection,
                        bounds: combineBounds(nameBounds, bounds),
                        confidence: Double(confidence)
                    )
                    rawItems.append(item)
                    pendingName = nil
                    pendingBounds = nil
                }
                continue
            }
            
            // Detect descriptions (longer text, specific patterns)
            if isLikelyDescription(text) {
                // Update last item's description if it exists
                if !rawItems.isEmpty {
                    rawItems[rawItems.count - 1].description = text
                }
                continue
            }
            
            // Detect menu item names
            if isLikelyMenuItemName(text) {
                // Save previous pending item without price if exists
                if let name = pendingName {
                    let item = RawMenuItem(
                        name: name,
                        description: nil,
                        price: nil,
                        section: currentSection,
                        bounds: pendingBounds ?? bounds,
                        confidence: Double(confidence)
                    )
                    rawItems.append(item)
                }
                
                pendingName = text
                pendingBounds = bounds
            }
        }
        
        // Add final pending item
        if let name = pendingName {
            let item = RawMenuItem(
                name: name,
                description: nil,
                price: nil,
                section: currentSection,
                bounds: pendingBounds ?? CGRect.zero,
                confidence: Double(0.5)
            )
            rawItems.append(item)
        }
        
        debugLog(" Parsed \(rawItems.count) raw menu items")
        return rawItems
    }
    
    // MARK: - Menu Item Analysis
    private func analyzeMenuItems(_ rawItems: [RawMenuItem]) async throws -> [AnalyzedMenuItem] {
        var analyzedItems: [AnalyzedMenuItem] = []
        
        for rawItem in rawItems {
            let analyzedItem = try await createUSDAOnlyAnalyzedItem(from: rawItem)
            analyzedItems.append(analyzedItem)
            
            // Add small delay to avoid overwhelming USDA API
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }
        
        debugLog("🍽️ Analyzed \(analyzedItems.count) menu items with enhanced fallback system")
        return analyzedItems
    }
    
    // MARK: - Helper Methods
    private func isLikelySectionHeader(_ text: String) -> Bool {
        // Check for common section patterns
        let sectionKeywords = ["appetizer", "entree", "main", "dessert", "beverage", "drink", "side", "salad", "soup", "pizza", "burger", "sandwich"]
        let lowercaseText = text.lowercased()
        
        return text.count > 3 && 
               text.count < 30 &&
               (text.uppercased() == text || sectionKeywords.contains { lowercaseText.contains($0) })
    }
    
    private func extractPrice(from text: String) -> String? {
        let priceRegex = try! NSRegularExpression(pattern: #"\$\d+(\.\d{2})?"#)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = priceRegex.firstMatch(in: text, range: range) {
            return String(text[Range(match.range, in: text)!])
        }
        return nil
    }
    
    private func isLikelyDescription(_ text: String) -> Bool {
        return text.count > 30 || 
               text.contains(",") ||
               text.lowercased().contains("served with") ||
               text.lowercased().contains("includes")
    }
    
    private func isLikelyMenuItemName(_ text: String) -> Bool {
        return text.count >= 3 && 
               text.count <= 50 && 
               !text.contains("$") &&
               !isLikelyDescription(text)
    }
    
    private func combineBounds(_ rect1: CGRect, _ rect2: CGRect) -> CGRect {
        return rect1.union(rect2)
    }
    
    private func detectRestaurantName(from observations: [VNRecognizedTextObservation]) -> String? {
        // Look for restaurant name in top portion of image
        let topObservations = observations.filter { $0.boundingBox.minY > 0.7 } // Top 30%
        
        for observation in topObservations {
            if let text = observation.topCandidates(1).first?.string {
                let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanText.count > 3 && cleanText.count < 30 {
                    return cleanText
                }
            }
        }
        return nil
    }
    
    private func calculateOverallConfidence(_ items: [AnalyzedMenuItem]) -> Double {
        guard !items.isEmpty else { return 0.0 }
        return items.map { $0.confidence }.reduce(0, +) / Double(items.count)
    }
    
    private func createUSDAOnlyAnalyzedItem(from rawItem: RawMenuItem) async throws -> AnalyzedMenuItem {
        debugLog("🍽️ Processing menu item: '\(rawItem.name)'")
        
        // Get USDA-only nutrition analysis 
        let usdaItem = try await USDANutritionEngine.shared.analyzeMenuItem(rawItem.name)
        
        if usdaItem.isAvailable {
            // Create item with USDA data
            return AnalyzedMenuItem.createUSDAOnly(
                name: rawItem.name,
                description: rawItem.description,
                price: rawItem.price,
                usdaItem: usdaItem,
                textBounds: rawItem.bounds
            )
        } else {
            // Create unavailable item
            return AnalyzedMenuItem.createUnavailable(
                name: rawItem.name,
                description: rawItem.description,
                price: rawItem.price,
                textBounds: rawItem.bounds
            )
        }
    }
}

extension MenuOCRService {
    
    /// USDA-Only menu analysis - completely removes ingredient analysis
    func analyzeMenuUSDAOnly(image: UIImage) async throws -> MenuAnalysisResult {
        debugLog("🔍 Starting USDA-only menu analysis...")
        
        // Step 1: OCR extraction (unchanged)
        let ocrResults = try await extractTextFromImage(image)
        let rawMenuItems = try await parseMenuStructure(ocrResults, image: image)
        
        debugLog("📄 OCR found \(rawMenuItems.count) potential menu items")
        
        // Step 2: USDA-only analysis (NO ingredient analysis)
        let analyzedItems = try await analyzeMenuItemsUSDAOnly(rawMenuItems)
        
        // Step 3: Calculate overall confidence
        let overallConfidence = calculateOverallConfidence(analyzedItems)
        
        let result = MenuAnalysisResult(
            restaurantName: detectRestaurantName(from: ocrResults),
            location: nil,
            menuItems: analyzedItems,
            analysisDate: Date(),
            imageData: image.pngData(),
            confidence: overallConfidence
        )
        
        logUSDAOnlyAnalysisSummary(result)
        return result
    }
    
    // MARK: - USDA-Only Analysis (NO Ingredients)
    private func analyzeMenuItemsUSDAOnly(_ rawItems: [RawMenuItem]) async throws -> [AnalyzedMenuItem] {
        var analyzedItems: [AnalyzedMenuItem] = []
        
        for rawItem in rawItems {
            let analyzedItem = try await createUSDAOnlyAnalyzedItem(from: rawItem)
            analyzedItems.append(analyzedItem)
            
            // Rate limiting for USDA API
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }
        
        debugLog("✅ Analyzed \(analyzedItems.count) menu items with USDA-only system")
        return analyzedItems
    }
    
    private func logUSDAOnlyAnalysisSummary(_ result: MenuAnalysisResult) {
        let availableCount = result.menuItems.filter { $0.estimationTier != .unavailable }.count
        let unavailableCount = result.menuItems.filter { $0.estimationTier == .unavailable }.count
        
        debugLog("""
        
        📊 USDA-ONLY ANALYSIS SUMMARY:
        🍽️ Total Items: \(result.totalItems)
        🎯 Overall Confidence: \(Int(result.confidence * 100))%
        
        USDA RESULTS:
        ✅ Available: \(availableCount) items
        ❌ Unavailable: \(unavailableCount) items
        
        SUCCESS RATE: \(Int(Double(availableCount) / Double(result.totalItems) * 100))%
        """)
    }
}

// MARK: - Supporting Types
struct RawMenuItem {
    let name: String
    var description: String?
    let price: String?
    let section: String?
    let bounds: CGRect
    let confidence: Double
}

enum OCRError: Error, LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image provided"
        case .noTextFound:
            return "No text could be detected in the image"
        case .processingFailed:
            return "Failed to process the menu image"
        }
    }
}