import Foundation

// MARK: - LLM Response Models
struct LLMMenuResponse: Codable {
    let items: [String]
}

enum LLMError: Error, LocalizedError {
    case invalidPrompt
    case networkError(Error)
    case invalidResponse
    case jsonParsingFailed(Error)
    case noItemsFound
    
    var errorDescription: String? {
        switch self {
        case .invalidPrompt:
            return "Invalid prompt provided"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from LLM"
        case .jsonParsingFailed(let error):
            return "Failed to parse JSON response: \(error.localizedDescription)"
        case .noItemsFound:
            return "No menu items found in response"
        }
    }
}

enum LLMProvider {
    case huggingFace(model: String)
    case local(model: String)
    case openAI(model: String)
    
    var apiEndpoint: String {
        switch self {
        case .huggingFace(let model):
            return "https://api-inference.huggingface.co/models/\(model)"
        case .local(_):
            return "http://localhost:8080/v1/completions" // llama.cpp server
        case .openAI(_):
            return "https://api.openai.com/v1/completions"
        }
    }
}

@MainActor
class LLMMenuParsingService: ObservableObject {
    
    // MARK: - Configuration
    private let provider: LLMProvider
    private let maxRetries: Int = 3
    private let timeoutInterval: TimeInterval = 15.0
    private let hfToken: String? // Add HF token support
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var lastError: Error?
    
    // MARK: - Shared Instance
    static let shared = LLMMenuParsingService(
        provider: .huggingFace(model: "meta-llama/Llama-2-7b-chat-hf"),
        hfToken: nil // Add your token here: "hf_your_token_here"
    )
    
    init(provider: LLMProvider = .huggingFace(model: "meta-llama/Llama-2-7b-chat-hf"), hfToken: String? = nil) {
        self.provider = provider
        self.hfToken = hfToken
    }
    
    // MARK: - Main Menu Parsing Function
    
    /// Parse raw menu text using local parsing (more reliable than LLM for menus)
    func parseMenuText(_ rawMenuText: String) async throws -> [String] {
        isProcessing = true
        progress = 0.0
        defer {
            isProcessing = false
            progress = 1.0
        }
        
        debugLog("🤖 Starting menu parsing for text: \(rawMenuText.prefix(100))...")
        
        // Use local parsing as primary method (more reliable for menu structure)
        progress = 0.1
        let localService = LocalLLMService()
        let localItems = await localService.parseMenuLocally(rawMenuText)
        progress = 0.9
        
        // If local parsing fails or returns very few items, try enhanced fallback
        if localItems.count < 2 {
            debugLog("🤖 Local parsing returned few items, trying enhanced fallback...")
            let fallbackItems = performEnhancedFallback(rawMenuText)
            progress = 1.0
            return fallbackItems.isEmpty ? localItems : fallbackItems
        }
        
        progress = 1.0
        debugLog("🤖 Local parsing complete: \(localItems.count) items found")
        return localItems
    }
    
    // MARK: - Enhanced Fallback for Complex Menus
    
    private func performEnhancedFallback(_ rawMenuText: String) -> [String] {
        debugLog("🤖 Using enhanced fallback parsing...")
        
        let lines = rawMenuText.components(separatedBy: .newlines)
        var items: [String] = []
        var currentBaseDish: String?
        
        // Process each line more intelligently
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty && !shouldSkipLineFallback(trimmed) else { continue }
            
            let cleaned = cleanLineAdvanced(trimmed)
            guard !cleaned.isEmpty && cleaned.count >= 3 else { continue }
            
            debugLog("🤖 Processing: '\(trimmed)' -> '\(cleaned)'")
            
            // Detect base dishes (main menu items)
            if isMainDish(cleaned) {
                currentBaseDish = cleaned
                items.append(cleaned)
                debugLog("🤖 Base dish: '\(cleaned)'")
                
            } else if isModifier(cleaned), let baseDish = currentBaseDish {
                // This is a variation/modifier of the base dish
                let modifier = processModifier(cleaned)
                let combinedItem = "\(baseDish) \(modifier)"
                items.append(combinedItem)
                debugLog("🤖 Variation: '\(combinedItem)'")
                
            } else if isStandaloneItemFallback(cleaned) {
                // Standalone item
                items.append(cleaned)
                currentBaseDish = nil // Reset for new section
                debugLog("🤖 Standalone: '\(cleaned)'")
            }
        }
        
        // Extract add-ons from the full text
        let addOns = extractAddOnsAdvanced(rawMenuText)
        items.append(contentsOf: addOns)
        
        return items.filter { $0.count >= 3 }
    }
    
    private func shouldSkipLineFallback(_ line: String) -> Bool {
        let lower = line.lowercased()
        
        // Skip pure numbers or prices
        if line.range(of: "^[\\d\\$\\s\\.]+$", options: .regularExpression) != nil {
            return true
        }
        
        // Skip OCR garbage and short lines
        if line.count <= 2 || line == "ddar" {
            return true
        }
        
        // Skip obvious headers/footers
        let skipWords = ["guys", "old fashioned", "protein bowl", "topped with your favorite", "house vinaigrette"]
        for word in skipWords {
            if lower.contains(word) && line.count < 50 {
                return true
            }
        }
        
        return false
    }
    
    private func cleanLineAdvanced(_ line: String) -> String {
        var cleaned = line
        
        // Remove pricing (more aggressive)
        cleaned = cleaned.replacingOccurrences(of: "\\s*\\$?\\d+(\\.\\d{2})?\\s*$", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\s+\\d+\\s*$", with: "", options: .regularExpression)
        
        // Remove common menu artifacts
        cleaned = cleaned.replacingOccurrences(of: "…", with: "")
        cleaned = cleaned.replacingOccurrences(of: "•", with: "")
        
        // Handle parentheses more carefully - remove content but preserve main text
        cleaned = cleaned.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
        
        // Normalize whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func isMainDish(_ line: String) -> Bool {
        let lower = line.lowercased()
        
        // Look for dish indicators
        let dishPatterns = ["salad", "bowl", "burger", "sandwich", "soup", "pizza", "pasta"]
        
        // Must contain a dish pattern and not be a modifier
        return dishPatterns.contains { lower.contains($0) } && 
               !lower.hasPrefix("w/") && 
               !lower.hasPrefix("with ") &&
               line.count > 5
    }
    
    private func isModifier(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.hasPrefix("w/") || lower.hasPrefix("with ")
    }
    
    private func processModifier(_ line: String) -> String {
        var modifier = line
        
        // Convert "w/" to "with "
        modifier = modifier.replacingOccurrences(of: "^w/\\s*", with: "with ", options: .regularExpression)
        
        return modifier
    }
    
    private func isStandaloneItemFallback(_ line: String) -> Bool {
        let lower = line.lowercased()
        let standalonePatterns = ["chips", "fries", "bread", "appetizer"]
        
        return standalonePatterns.contains { lower.contains($0) } && line.count >= 4
    }
    
    private func extractAddOnsAdvanced(_ text: String) -> [String] {
        var addOns: [String] = []
        let lower = text.lowercased()
        
        // Look for add-on patterns in the text
        let addOnItems = ["avocado", "broccoli", "chickpeas", "corn", "edamame", "tomato", "carrots"]
        
        for item in addOnItems {
            if lower.contains(item) {
                addOns.append("\(item.capitalized) (add-on)")
            }
        }
        
        return Array(Set(addOns)) // Remove duplicates
    }
    
    // MARK: - Alternative LLM Providers
    
    /// Switch to a different LLM provider
    func switchProvider(to newProvider: LLMProvider) -> LLMMenuParsingService {
        return LLMMenuParsingService(provider: newProvider, hfToken: hfToken)
    }
    
    /// Get available free models for testing
    static func getRecommendedFreeModels() -> [LLMProvider] {
        return [
            // Instruction-tuned models (best for structured tasks)
            .huggingFace(model: "google/flan-t5-large"),
            .huggingFace(model: "google/flan-t5-xl"),
            .huggingFace(model: "google/flan-ul2"),
            
            // Alternative good models
            .huggingFace(model: "microsoft/DialoGPT-medium"),
            .huggingFace(model: "facebook/blenderbot-400M-distill"),
            
            // Local options
            .local(model: "llama-2-7b-chat.gguf"),
            .local(model: "vicuna-7b-v1.5.gguf")
        ]
    }
    
    /// Switch to a more reliable model for menu parsing
    static func createWithBestModel() -> LLMMenuParsingService {
        return LLMMenuParsingService(provider: .huggingFace(model: "google/flan-t5-large"))
    }
}

// MARK: - Helper Extensions

extension LLMMenuParsingService {
    
    /// Test the LLM with a sample menu
    func testWithSampleMenu() async {
        let sampleMenu = """
        3 GUYS
        OLD FASHIONED SALADS
        Chopped Mixed Greens Salad … $12.99
        w/Grilled Chicken … $15.99
        w/Fresh Turkey … $14.99
        
        MAIN COURSES
        Classic Burger … $13.99
        Fish & Chips … $16.99
        Chicken Parmesan … $18.99
        """
        
        do {
            let result = try await parseMenuText(sampleMenu)
            debugLog("🤖 Test result: \(result)")
        } catch {
            debugLog("🤖 Test failed: \(error)")
        }
    }
}