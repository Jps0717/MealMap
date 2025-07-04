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
    
    // MARK: - OCR Processing
    func analyzeMenuImage(_ image: UIImage) async throws -> MenuAnalysisResult {
        isProcessing = true
        progress = 0.0
        defer { 
            isProcessing = false
            progress = 1.0
        }
        
        debugLog("🔍 Starting menu image analysis...")
        
        // Preprocess image - handle optional return
        let preprocessedImage = preprocessImageForOCR(image) ?? image
        
        // Step 1: Preprocess image (20% progress)
        let processedImage = preprocessImage(preprocessedImage)
        progress = 0.2
        
        // Step 2: Extract text using Vision (40% progress)
        let textObservations = try await extractTextFromImage(processedImage)
        progress = 0.4
        
        // Step 3: Parse menu structure (60% progress)
        let menuItems = try await parseMenuStructure(textObservations, image: processedImage)
        progress = 0.6
        
        // Step 4: Analyze ingredients and nutrition using Enhanced Matcher (80% progress)
        let analyzedItems = try await analyzeMenuItemsWithEnhancedMatcher(menuItems)
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
        debugLog("🔍 Menu analysis complete: \(result.menuItems.count) items found")
        logEnhancedAnalysisSummary(result)
        return result
    }
    
    // MARK: - Image Preprocessing
    private func preprocessImageForOCR(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let context = CIContext()
        var processedImage = ciImage
        
        // Step 1: Convert to grayscale
        guard let grayscaleFilter = CIFilter(name: "CIColorMonochrome") else { return nil }
        grayscaleFilter.setValue(processedImage, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(CIColor.white, forKey: "inputColor")
        grayscaleFilter.setValue(1.0, forKey: "inputIntensity")
        
        guard let grayscaleOutput = grayscaleFilter.outputImage else { return nil }
        processedImage = grayscaleOutput
        
        debugLog("🔍 Applied grayscale conversion")
        
        // Step 2: Apply adaptive thresholding for contrast
        guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return nil }
        exposureFilter.setValue(processedImage, forKey: kCIInputImageKey)
        exposureFilter.setValue(0.5, forKey: "inputEV") // Increase exposure slightly
        
        guard let exposureOutput = exposureFilter.outputImage else { return nil }
        processedImage = exposureOutput
        
        // Step 3: Enhance contrast
        guard let contrastFilter = CIFilter(name: "CIColorControls") else { return nil }
        contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.4, forKey: "inputContrast") // Increase contrast
        contrastFilter.setValue(0.1, forKey: "inputBrightness")
        
        guard let contrastOutput = contrastFilter.outputImage else { return nil }
        processedImage = contrastOutput
        
        debugLog("🔍 Applied contrast enhancement")
        
        // Step 4: Noise reduction
        guard let noiseReductionFilter = CIFilter(name: "CINoiseReduction") else { return nil }
        noiseReductionFilter.setValue(processedImage, forKey: kCIInputImageKey)
        noiseReductionFilter.setValue(0.02, forKey: "inputNoiseLevel")
        noiseReductionFilter.setValue(0.4, forKey: "inputSharpness")
        
        guard let denoiseOutput = noiseReductionFilter.outputImage else { return nil }
        processedImage = denoiseOutput
        
        debugLog("🔍 Applied noise reduction")
        
        // Convert back to UIImage
        guard let finalCGImage = context.createCGImage(processedImage, from: processedImage.extent) else { return nil }
        
        let finalImage = UIImage(cgImage: finalCGImage)
        debugLog("🔍 Image preprocessing complete")
        
        return finalImage
    }
    
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
    func extractTextFromImage(_ image: UIImage) async throws -> [VNRecognizedTextObservation] {
        progress = 0.1
        isProcessing = true
        
        debugLog("🔍 Starting Vision.framework OCR with preprocessing...")
        
        // Step 1: Preprocess the image
        guard let preprocessedImage = preprocessImageForOCR(image) else {
            throw OCRError.imageProcessingFailed
        }
        
        progress = 0.3
        
        // Step 2: Convert to CGImage for Vision
        guard let cgImage = preprocessedImage.cgImage else {
            throw OCRError.imageProcessingFailed
        }
        
        progress = 0.4
        
        // Step 3: Create and configure Vision request
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.recognitionLanguages = ["en-US"]
        textRequest.usesLanguageCorrection = true
        textRequest.automaticallyDetectsLanguage = false
        
        progress = 0.5
        
        // Step 4: Perform OCR
        let observations = try await performVisionOCR(cgImage: cgImage, request: textRequest)
        
        progress = 0.8
        
        debugLog("🔍 Vision OCR found \(observations.count) text observations")
        
        progress = 1.0
        isProcessing = false
        
        return observations
    }
    
    func parseMenuStructure(_ observations: [VNRecognizedTextObservation], image: UIImage) async throws -> [RawMenuItem] {
        debugLog("🔍 Starting menu structure parsing with advanced text processing...")
        
        // Step 1: Extract and clean text from observations
        let cleanedTexts = processTextObservations(observations)
        
        // Step 2: Fuzzy match against food keywords
        let foodItems = fuzzyMatchFoodItems(cleanedTexts)
        
        // Step 3: Convert to RawMenuItem objects
        let rawItems = foodItems.enumerated().map { index, text in
            RawMenuItem(
                id: UUID(),
                name: text,
                description: nil,
                price: nil,
                textBounds: CGRect.zero, // We could extract bounds if needed
                confidence: 0.8 // Base confidence for Vision OCR
            )
        }
        
        debugLog("🔍 Parsed \(rawItems.count) potential menu items from \(observations.count) observations")
        return rawItems
    }
    
    // MARK: - Vision OCR Execution
    
    private func performVisionOCR(cgImage: CGImage, request: VNRecognizeTextRequest) async throws -> [VNRecognizedTextObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    
                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    continuation.resume(returning: observations)
                } catch {
                    continuation.resume(throwing: OCRError.visionProcessingFailed(error))
                }
            }
        }
    }
    
    // MARK: - Advanced Text Processing
    
    private func processTextObservations(_ observations: [VNRecognizedTextObservation]) -> [String] {
        var cleanedTexts: [String] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            let rawText = topCandidate.string
            
            // Step 3a: Trim whitespace and punctuation
            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            
            // Step 3b: Strip price data and parentheses
            let priceStripped = stripPricesAndParentheses(trimmed)
            
            // Step 3c: Remove prefixes
            let prefixRemoved = removePrefixes(priceStripped)
            
            // Step 3d: Discard lines containing digits after cleanup
            if containsDigitsAfterCleanup(prefixRemoved) {
                continue
            }
            
            // Step 3e: Normalize case and remove diacritics
            let normalized = normalizeText(prefixRemoved)
            
            // Only keep non-empty, meaningful text
            if !normalized.isEmpty && normalized.count >= 3 {
                cleanedTexts.append(normalized)
            }
        }
        
        debugLog("🔍 Text processing: \(observations.count) observations → \(cleanedTexts.count) cleaned texts")
        return cleanedTexts
    }
    
    private func stripPricesAndParentheses(_ text: String) -> String {
        // Regex pattern to match prices and parentheses content
        let pricePattern = #"\s*\(.*?\)|\s*\$?\d+(\.\d{2})?"#
        
        do {
            let regex = try NSRegularExpression(pattern: pricePattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            let cleaned = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            debugLog("🔍 Regex error in price stripping: \(error)")
            return text
        }
    }
    
    private func removePrefixes(_ text: String) -> String {
        let prefixes = ["w/", "with", "add", "extra", "side of", "choice of"]
        var result = text.lowercased()
        
        for prefix in prefixes {
            if result.hasPrefix(prefix + " ") {
                result = String(result.dropFirst(prefix.count + 1))
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func containsDigitsAfterCleanup(_ text: String) -> Bool {
        // Check if text contains any digits after all cleanup
        return text.rangeOfCharacter(from: .decimalDigits) != nil
    }
    
    private func normalizeText(_ text: String) -> String {
        // Convert to lowercase and remove diacritics
        let normalized = text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any remaining special characters except spaces and hyphens
        let cleaned = normalized.replacingOccurrences(
            of: #"[^a-z\s\-']"#,
            with: "",
            options: .regularExpression
        )
        
        // Clean up multiple spaces
        let finalCleaned = cleaned.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return finalCleaned
    }
    
    // MARK: - Fuzzy Food Matching
    
    private func fuzzyMatchFoodItems(_ texts: [String]) -> [String] {
        var matchedItems: [String] = []
        
        for text in texts {
            if isFoodItem(text) {
                matchedItems.append(text)
            }
        }
        
        debugLog("🔍 Fuzzy matching: \(texts.count) texts → \(matchedItems.count) food items")
        return matchedItems
    }
    
    private func isFoodItem(_ text: String) -> Bool {
        let words = text.components(separatedBy: .whitespaces)
        
        // Check if any word matches our food keywords
        for word in words {
            for keyword in foodKeywords {
                // Exact match
                if word == keyword {
                    return true
                }
                
                // Fuzzy match (allowing for minor OCR errors)
                if isCloseMatch(word, keyword) {
                    return true
                }
            }
        }
        
        // Check for common food patterns
        if containsFoodPatterns(text) {
            return true
        }
        
        return false
    }
    
    private func isCloseMatch(_ word: String, _ keyword: String) -> Bool {
        // Allow up to 2 character differences for words longer than 4 characters
        guard word.count >= 4 && keyword.count >= 4 else {
            return word == keyword
        }
        
        let distance = levenshteinDistance(word, keyword)
        return distance <= 2
    }
    
    private func containsFoodPatterns(_ text: String) -> Bool {
        let foodPatterns = [
            #"\w+ (burger|sandwich|pizza|salad|soup|wrap|bowl|plate)"#,
            #"(grilled|fried|baked|roasted) \w+"#,
            #"\w+ (chicken|beef|fish|pork)"#,
            #"(breakfast|lunch|dinner) \w+"#
        ]
        
        for pattern in foodPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: text.utf16.count)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return true
                }
            } catch {
                continue
            }
        }
        
        return false
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        
        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count {
            matrix[i][0] = i
        }
        
        for j in 0...b.count {
            matrix[0][j] = j
        }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = Swift.min(
                        matrix[i-1][j] + 1,     // deletion
                        matrix[i][j-1] + 1,     // insertion
                        matrix[i-1][j-1] + 1    // substitution
                    )
                }
            }
        }
        
        return matrix[a.count][b.count]
    }
    
    // MARK: - USDA Integration Methods
    
    func createUSDAOnlyAnalyzedItem(from rawItem: RawMenuItem) async throws -> AnalyzedMenuItem {
        debugLog("🔍 Creating USDA-only analyzed item for: '\(rawItem.name)'")
        
        do {
            // Use USDA Nutrition Engine for analysis
            let usdaResult = try await USDANutritionEngine.shared.analyzeMenuItem(rawItem.name)
            
            if usdaResult.isAvailable {
                debugLog("🔍 USDA analysis successful for '\(rawItem.name)'")
                // Convert USDAEngineMenuItem to USDANutritionEstimate
                let usdaEstimate = USDANutritionEstimate(
                    originalItemName: usdaResult.originalName,
                    calories: usdaResult.nutrition.calories,
                    carbs: usdaResult.nutrition.carbs,
                    protein: usdaResult.nutrition.protein,
                    fat: usdaResult.nutrition.fat,
                    fiber: nil,
                    sugar: usdaResult.nutrition.sugar.min > 0 ? usdaResult.nutrition.sugar : nil,
                    sodium: nil,
                    confidence: usdaResult.confidence,
                    estimationSource: .usda,
                    matchCount: usdaResult.matchCount,
                    isGeneralizedEstimate: usdaResult.isGeneralEstimate
                )
                
                return AnalyzedMenuItem.createWithUSDA(
                    name: rawItem.name,
                    description: rawItem.description,
                    price: rawItem.price,
                    usdaEstimate: usdaEstimate,
                    textBounds: rawItem.textBounds
                )
            } else {
                debugLog("🔍 No USDA data found for '\(rawItem.name)'")
                return AnalyzedMenuItem.createUnavailable(
                    name: rawItem.name,
                    description: rawItem.description,
                    price: rawItem.price,
                    textBounds: rawItem.textBounds
                )
            }
        } catch {
            debugLog("🔍 USDA analysis failed for '\(rawItem.name)': \(error)")
            return AnalyzedMenuItem.createUnavailable(
                name: rawItem.name,
                description: rawItem.description,
                price: rawItem.price,
                textBounds: rawItem.textBounds
            )
        }
    }
    
    func detectRestaurantName(from observations: [VNRecognizedTextObservation]) -> String? {
        // Look for restaurant name in the first few text observations (usually at top)
        let topObservations = Array(observations.prefix(5))
        
        for observation in topObservations {
            guard let text = observation.topCandidates(1).first?.string else { continue }
            
            // Check if this looks like a restaurant name
            if isLikelyRestaurantName(text) {
                return text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            }
        }
        
        return nil
    }
    
    private func isLikelyRestaurantName(_ text: String) -> Bool {
        let restaurantKeywords = ["restaurant", "cafe", "diner", "grill", "kitchen", "bar", "bistro", "house"]
        let text_lower = text.lowercased()
        
        // Check for restaurant keywords
        for keyword in restaurantKeywords {
            if text_lower.contains(keyword) {
                return true
            }
        }
        
        // Check for known chain names
        let knownChains = ["mcdonald", "burger king", "subway", "kfc", "taco bell", "wendy", "chipotle", "starbucks"]
        for chain in knownChains {
            if text_lower.contains(chain) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Enhanced Menu Item Analysis
    private func analyzeMenuItemsWithEnhancedMatcher(_ rawItems: [RawMenuItem]) async throws -> [AnalyzedMenuItem] {
        debugLog("🔍 Starting Enhanced Matcher analysis for \(rawItems.count) items...")
        var analyzedItems: [AnalyzedMenuItem] = []
        
        for (index, rawItem) in rawItems.enumerated() {
            debugLog("🔍 Processing item \(index + 1)/\(rawItems.count): '\(rawItem.name)'")
            
            // Use the new enhanced food matcher
            let analyzedItem = try await createEnhancedAnalyzedItem(from: rawItem)
            analyzedItems.append(analyzedItem)
            
            // Rate limiting to avoid overwhelming APIs
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }
        
        debugLog("🔍 Enhanced analysis complete: \(analyzedItems.count) items analyzed")
        return analyzedItems
    }
    
    private func createEnhancedAnalyzedItem(from rawItem: RawMenuItem) async throws -> AnalyzedMenuItem {
        debugLog("🔍 Creating enhanced analyzed item for: '\(rawItem.name)'")
        
        do {
            // Use the new EnhancedFoodMatcher for intelligent analysis
            var result = try await EnhancedFoodMatcher.shared.findNutritionMatch(for: rawItem.name)
            
            // Update the result with raw item details - create a new instance with updated values
            result = AnalyzedMenuItem(
                name: rawItem.name,
                description: rawItem.description ?? result.description,
                price: rawItem.price ?? result.price,
                ingredients: result.ingredients,
                nutritionEstimate: result.nutritionEstimate,
                dietaryTags: result.dietaryTags,
                confidence: result.confidence,
                textBounds: rawItem.textBounds,
                estimationTier: result.estimationTier,
                usdaEstimate: result.usdaEstimate,
                isGeneralizedEstimate: result.isGeneralizedEstimate
            )
            
            return result
            
        } catch {
            debugLog("🔍 Enhanced matcher failed for '\(rawItem.name)': \(error)")
            return AnalyzedMenuItem.createUnavailable(
                name: rawItem.name,
                description: rawItem.description,
                price: rawItem.price,
                textBounds: rawItem.textBounds
            )
        }
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
    
    private func calculateOverallConfidence(_ items: [AnalyzedMenuItem]) -> Double {
        guard !items.isEmpty else { return 0.0 }
        return items.map { $0.confidence }.reduce(0, +) / Double(items.count)
    }
    
    private let foodKeywords = [
        // Proteins
        "chicken", "beef", "pork", "fish", "salmon", "tuna", "turkey", "bacon", "ham", "sausage",
        "shrimp", "crab", "lobster", "egg", "tofu", "beans", "lentils",
        
        // Dishes
        "burger", "sandwich", "pizza", "pasta", "salad", "soup", "stew", "curry", "stir", "fry",
        "wrap", "taco", "burrito", "quesadilla", "bowl", "plate", "platter",
        
        // Cooking methods
        "grilled", "fried", "baked", "roasted", "steamed", "sauteed", "broiled", "blackened",
        
        // Cuisines
        "italian", "mexican", "chinese", "thai", "indian", "american", "mediterranean",
        
        // Common foods
        "rice", "noodles", "bread", "cheese", "mushroom", "avocado", "tomato", "onion",
        "pepper", "garlic", "spinach", "broccoli", "carrot", "potato", "fries"
    ]
    
    // MARK: - Analysis Summary Logging
    
    private func logEnhancedAnalysisSummary(_ result: MenuAnalysisResult) {
        let availableCount = result.menuItems.filter { $0.estimationTier != .unavailable }.count
        let unavailableCount = result.menuItems.filter { $0.estimationTier == .unavailable }.count
        let usdaCount = result.menuItems.filter { $0.estimationTier == .usda }.count
        let offCount = result.menuItems.filter { $0.estimationTier == .openFoodFacts }.count
        
        debugLog("""
        
        🔍 ENHANCED MATCHER ANALYSIS SUMMARY:
        Total Items: \(result.totalItems)
        Overall Confidence: \(Int(result.confidence * 100))%
        
        RESULTS BY SOURCE:
        USDA Database: \(usdaCount) items
        Open Food Facts: \(offCount) items  
        Unavailable: \(unavailableCount) items
        
        SUCCESS RATE: \(Int(Double(availableCount) / Double(result.totalItems) * 100))%
        
        ENHANCED FEATURES USED:
        Food keyword dictionary matching
        Advanced junk token filtering
        USDA-first, OFF-fallback strategy
        60% minimum confidence threshold for OFF
        Unique term search optimization
        """)
    }
}