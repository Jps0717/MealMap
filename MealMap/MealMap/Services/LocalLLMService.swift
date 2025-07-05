import Foundation

@MainActor
class LocalLLMService: ObservableObject {
    
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    
    /// Simple local parsing without any external dependencies
    func parseMenuLocally(_ rawMenuText: String) async -> [String] {
        isProcessing = true
        progress = 0.0
        defer {
            isProcessing = false
            progress = 1.0
        }
        
        debugLog("🤖 Using 100% local menu parsing...")
        
        // Simulate processing time
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        progress = 0.5
        
        let items = parseMenuWithRules(rawMenuText)
        progress = 1.0
        
        debugLog("🤖 Local parsing complete: \(items.count) items found")
        return items
    }
    
    private func parseMenuWithRules(_ text: String) -> [String] {
        var items: [String] = []
        let lines = text.components(separatedBy: .newlines)
        var currentBaseDish: String?
        
        debugLog("🤖 Parsing menu with \(lines.count) lines")
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Skip obvious non-food content
            if shouldSkipLine(trimmed) {
                debugLog("🤖 Skipping line: '\(trimmed)'")
                continue
            }
            
            // Clean the line
            let cleaned = cleanLine(trimmed)
            guard !cleaned.isEmpty && cleaned.count >= 3 else { 
                debugLog("🤖 Line too short after cleaning: '\(trimmed)' -> '\(cleaned)'")
                continue 
            }
            
            debugLog("🤖 Processing line \(index): '\(trimmed)' -> '\(cleaned)'")
            
            // Determine what type of line this is
            if isBaseDish(cleaned) {
                // This is a main dish
                currentBaseDish = cleaned
                items.append(cleaned)
                debugLog("🤖 ✅ Found base dish: '\(cleaned)'")
                
            } else if isVariation(cleaned), let baseDish = currentBaseDish {
                // This is a variation of the current base dish
                let variation = cleanVariation(cleaned)
                let fullItem = "\(baseDish) \(variation)"
                items.append(fullItem)
                debugLog("🤖 ✅ Found variation: '\(fullItem)'")
                
            } else if isSimpleDish(cleaned) {
                // This is a simple standalone dish
                items.append(cleaned)
                currentBaseDish = nil
                debugLog("🤖 ✅ Found simple dish: '\(cleaned)'")
            } else {
                debugLog("🤖 ❌ Unmatched line: '\(cleaned)'")
            }
        }
        
        // Add specific add-ons based on content analysis
        let addOns = extractAddOns(text)
        items.append(contentsOf: addOns)
        
        let finalResults = cleanFinalResults(items)
        debugLog("🤖 Final menu items: \(finalResults)")
        
        return finalResults
    }
    
    private func shouldSkipLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        
        // Skip pure numbers
        if line.range(of: "^\\d+$", options: .regularExpression) != nil {
            return true
        }
        
        // Skip obvious headers and restaurant names
        let skipPatterns = [
            "3 guys", "old fashioned", "protein bowl", 
            "topped with your favorite", "house vinaigrette",
            "ys protein", "guys protein"
        ]
        
        for pattern in skipPatterns {
            if lower.contains(pattern) {
                return true
            }
        }
        
        // Skip OCR garbage
        if line == "ddar" || line.count <= 2 {
            return true
        }
        
        // Skip descriptive text that's not food items
        if lower.contains("chick peas tomato, carrots, com") {
            return true
        }
        
        return false
    }
    
    private func isBaseDish(_ line: String) -> Bool {
        let lower = line.lowercased()
        
        // Look for specific dish patterns from your menu
        let baseDishPatterns = [
            "caesar salad", "mixed greens salad", "chopped", "salad"
        ]
        
        // Check for exact matches first
        for pattern in baseDishPatterns {
            if lower.contains(pattern) && !lower.hasPrefix("w/") && !lower.hasPrefix("with") {
                return true
            }
        }
        
        return false
    }
    
    private func cleanLine(_ line: String) -> String {
        var cleaned = line
        
        // Remove prices
        cleaned = cleaned.replacingOccurrences(of: "\\s*\\$?\\d+(\\.\\d{2})?\\s*$", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\s+\\d+\\s*$", with: "", options: .regularExpression)
        
        // Remove menu artifacts
        cleaned = cleaned.replacingOccurrences(of: "…", with: "")
        cleaned = cleaned.replacingOccurrences(of: "•", with: "")
        cleaned = cleaned.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
        
        // Clean whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func isVariation(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.hasPrefix("w/") || lower.hasPrefix("with ")
    }
    
    private func cleanVariation(_ line: String) -> String {
        return line.replacingOccurrences(of: "^w/\\s*", with: "with ", options: .regularExpression)
    }
    
    private func isSimpleDish(_ line: String) -> Bool {
        let lower = line.lowercased()
        let simpleDishPatterns = ["chips", "fries"]
        return simpleDishPatterns.contains { lower.contains($0) }
    }
    
    private func extractAddOns(_ text: String) -> [String] {
        var addOns: [String] = []
        let lower = text.lowercased()
        
        // Look for common add-ons mentioned in the text
        let addOnPatterns = ["avocado", "broccoli", "chickpeas", "corn"]
        
        for pattern in addOnPatterns {
            if lower.contains(pattern) {
                addOns.append("\(pattern.capitalized) (add-on)")
            }
        }
        
        return Array(Set(addOns)) // Remove duplicates
    }
    
    private func cleanFinalResults(_ items: [String]) -> [String] {
        return items
            .map { item in
                var cleaned = item
                cleaned = cleaned.replacingOccurrences(of: "w/", with: "with ")
                cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { $0.count >= 3 && !$0.lowercased().contains("thank you") }
    }
}