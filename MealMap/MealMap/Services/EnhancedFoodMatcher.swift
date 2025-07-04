import Foundation

// MARK: - Enhanced Food Matcher with Dictionary-Based Matching

@MainActor
class EnhancedFoodMatcher: ObservableObject {
    static let shared = EnhancedFoodMatcher()
    
    // MARK: - Food Keyword Dictionary
    private let foodKeywordDictionary: [String: String] = [
        // Proteins
        "grilled chicken": "grilled chicken",
        "fried chicken": "fried chicken", 
        "chicken breast": "chicken breast",
        "chicken thigh": "chicken thigh",
        "chicken sandwich": "chicken sandwich",
        "chicken burger": "chicken burger",
        "chicken wings": "chicken wings",
        "chicken tenders": "chicken tenders",
        "grilled shrimp": "grilled shrimp",
        "fried shrimp": "fried shrimp",
        "fresh turkey": "fresh turkey",
        "turkey sandwich": "turkey sandwich",
        "turkey breast": "turkey breast",
        "grilled salmon": "grilled salmon",
        "baked salmon": "baked salmon",
        "grilled fish": "grilled fish",
        "fried fish": "fried fish",
        "fish sandwich": "fish sandwich",
        "fish tacos": "fish tacos",
        "beef burger": "beef burger",
        "ground beef": "ground beef",
        "steak": "steak",
        "ribeye": "ribeye steak",
        "sirloin": "sirloin steak",
        "pork chops": "pork chops",
        "bacon": "bacon",
        "ham": "ham",
        "sausage": "sausage",
        
        // Salads & Vegetables
        "caesar salad": "caesar salad",
        "greek salad": "greek salad",
        "garden salad": "garden salad",
        "house salad": "house salad",
        "spinach salad": "spinach salad",
        "arugula salad": "arugula salad",
        "mixed greens": "mixed greens",
        "lettuce": "lettuce",
        "spinach": "spinach",
        "arugula": "arugula",
        "tomatoes": "tomatoes",
        "cucumbers": "cucumbers",
        "onions": "onions",
        "peppers": "peppers",
        "mushrooms": "mushrooms",
        "avocado": "avocado",
        "broccoli": "broccoli",
        "carrots": "carrots",
        
        // Dairy & Cheese
        "cheese": "cheese",
        "cheddar cheese": "cheddar cheese",
        "mozzarella": "mozzarella cheese",
        "parmesan": "parmesan cheese",
        "goat cheese": "goat cheese",
        "feta cheese": "feta cheese",
        "swiss cheese": "swiss cheese",
        "blue cheese": "blue cheese",
        "cream cheese": "cream cheese",
        "ricotta": "ricotta cheese",
        "yogurt": "yogurt",
        "greek yogurt": "greek yogurt",
        
        // Grains & Starches  
        "rice": "rice",
        "brown rice": "brown rice",
        "white rice": "white rice",
        "wild rice": "wild rice",
        "pasta": "pasta",
        "spaghetti": "spaghetti",
        "penne": "penne pasta",
        "fettuccine": "fettuccine",
        "linguine": "linguine",
        "bread": "bread",
        "white bread": "white bread",
        "wheat bread": "wheat bread",
        "sourdough": "sourdough bread",
        "bagel": "bagel",
        "roll": "bread roll",
        "bun": "hamburger bun",
        "tortilla": "tortilla",
        "wrap": "tortilla wrap",
        "potato": "potato",
        "sweet potato": "sweet potato",
        "fries": "french fries",
        "french fries": "french fries",
        "mashed potatoes": "mashed potatoes",
        "baked potato": "baked potato",
        "quinoa": "quinoa",
        "couscous": "couscous",
        "bulgur": "bulgur",
        
        // Prepared Foods
        "sandwich": "sandwich",
        "burger": "hamburger",
        "hamburger": "hamburger",
        "cheeseburger": "cheeseburger",
        "pizza": "pizza",
        "margherita pizza": "margherita pizza",
        "pepperoni pizza": "pepperoni pizza",
        "soup": "soup",
        "chicken soup": "chicken soup",
        "tomato soup": "tomato soup",
        "vegetable soup": "vegetable soup",
        "minestrone": "minestrone soup",
        "bowl": "bowl",
        "burrito": "burrito",
        "burrito bowl": "burrito bowl",
        "taco": "taco",
        "quesadilla": "quesadilla",
        "enchilada": "enchilada",
        "nachos": "nachos",
        
        // Appetizers & Sides
        "hummus": "hummus",
        "guacamole": "guacamole",
        "salsa": "salsa",
        "chips": "chips",
        "tortilla chips": "tortilla chips",
        "crackers": "crackers",
        "breadsticks": "breadsticks",
        "mozzarella sticks": "mozzarella sticks",
        "onion rings": "onion rings",
        "wings": "chicken wings",
        "buffalo wings": "buffalo wings",
        
        // Desserts
        "tiramisu": "tiramisu",
        "cheesecake": "cheesecake",
        "chocolate cake": "chocolate cake",
        "ice cream": "ice cream",
        "gelato": "gelato",
        "cookies": "cookies",
        "brownies": "brownies",
        "pie": "pie",
        "apple pie": "apple pie",
        "tart": "tart",
        "crostatine": "tart",  // Alias mapping
        "tiramisu tradizionale": "tiramisu",  // Alias mapping
        
        // Beverages
        "coffee": "coffee",
        "espresso": "espresso",
        "cappuccino": "cappuccino",
        "latte": "latte",
        "tea": "tea",
        "green tea": "green tea",
        "iced tea": "iced tea",
        "juice": "juice",
        "orange juice": "orange juice",
        "apple juice": "apple juice",
        "soda": "soda",
        "water": "water",
        "sparkling water": "sparkling water"
    ]
    
    // MARK: - Junk Tokens to Ignore
    private let junkTokens: Set<String> = [
        // Prefixes
        "w/", "with", "includes", "served with", "comes with", "topped with",
        "add", "extra", "side of", "choice of", "fresh", "hot", "cold",
        "new", "signature", "house", "chef's", "daily", "special",
        
        // Suffixes  
        "ing", "ddar", "tion", "xxx", "yyy", "zzz",
        
        // Numbers and measurements
        "25", "28", "30", "12", "16", "oz", "lb", "g", "ml",
        
        // Non-food terms
        "menu", "item", "dish", "plate", "order", "entree", "appetizer",
        "main", "course", "dinner", "lunch", "breakfast", "brunch"
    ]
    
    // MARK: - Price/Quantity Patterns
    private let pricePatterns = [
        #"\$\d+\.?\d*"#,           // $12.99, $12
        #"\b\d{1,2}\b"#,           // 25, 28 (standalone numbers)
        #"\d+\s*oz\b"#,            // 8 oz, 12oz  
        #"\d+\s*g\b"#,             // 100g, 500g
        #"\b\d{1,3}\.\d{2}\b"#     // 12.99, 25.50
    ]
    
    private init() {}
    
    // MARK: - Main Food Matching Function
    
    /// Enhanced food matching with dictionary-based keyword extraction and USDA-first fallback
    func findNutritionMatch(for rawMenuItem: String) async throws -> AnalyzedMenuItem {
        debugLog("🔍 Enhanced Matcher: Starting analysis for '\(rawMenuItem)'")
        
        // Step 1: Extract food keywords using dictionary
        let extractedKeywords = extractFoodKeywords(from: rawMenuItem)
        
        guard !extractedKeywords.isEmpty else {
            debugLog("🔍 No food keywords found in '\(rawMenuItem)'")
            return AnalyzedMenuItem.createUnavailable(
                name: rawMenuItem,
                description: nil,
                price: nil,
                textBounds: nil
            )
        }
        
        // Step 2: Clean search terms and remove duplicates
        let cleanedTerms = cleanSearchTerms(extractedKeywords)
        let uniqueTerms = Array(Set(cleanedTerms)) // Only search once per unique term
        
        debugLog("🔍 Extracted keywords: \(extractedKeywords)")
        debugLog("🔍 Cleaned unique terms: \(uniqueTerms)")
        
        // Step 3: Try USDA first for each cleaned term
        for searchTerm in uniqueTerms {
            if let usdaResult = try? await attemptUSDALookup(searchTerm: searchTerm, originalName: rawMenuItem) {
                debugLog("🔍 ✅ USDA success for term '\(searchTerm)'")
                return usdaResult
            }
        }
        
        // Step 4: Fallback to Open Food Facts with strict confidence threshold
        for searchTerm in uniqueTerms {
            if let offResult = try? await attemptOFFLookup(searchTerm: searchTerm, originalName: rawMenuItem) {
                debugLog("🔍 ✅ OFF fallback success for term '\(searchTerm)'")
                return offResult
            }
        }
        
        // Step 5: No high-confidence matches found
        debugLog("🔍 ❌ No high-confidence matches found for '\(rawMenuItem)'")
        return AnalyzedMenuItem.createUnavailable(
            name: rawMenuItem,
            description: nil,
            price: nil,
            textBounds: nil
        )
    }
    
    // MARK: - Food Keyword Extraction
    
    private func extractFoodKeywords(from text: String) -> [String] {
        let lowercaseText = text.lowercased()
        var foundKeywords: [String] = []
        
        // Sort dictionary keys by length (longest first) to match compound terms first
        let sortedKeys = foodKeywordDictionary.keys.sorted { $0.count > $1.count }
        
        for keyword in sortedKeys {
            if lowercaseText.contains(keyword) {
                // Use the standardized value from dictionary
                if let standardizedTerm = foodKeywordDictionary[keyword] {
                    foundKeywords.append(standardizedTerm)
                }
            }
        }
        
        return foundKeywords
    }
    
    // MARK: - Search Term Cleaning
    
    private func cleanSearchTerms(_ terms: [String]) -> [String] {
        var cleanedTerms: [String] = []
        
        for term in terms {
            if let cleaned = cleanSingleTerm(term) {
                cleanedTerms.append(cleaned)
            }
        }
        
        return cleanedTerms
    }
    
    private func cleanSingleTerm(_ term: String) -> String? {
        var cleaned = term.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Step 1: Remove price/quantity patterns
        for pattern in pricePatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Step 2: Handle composite items (e.g., "w/Hummus 25 | w/Chicken 28")
        let components = cleaned.components(separatedBy: CharacterSet(charactersIn: "|/&"))
        var bestComponent = ""
        
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            let withoutPrefixes = removePrefixes(from: trimmed)
            
            // Keep the longest meaningful component
            if withoutPrefixes.count > bestComponent.count && !isJunkTerm(withoutPrefixes) {
                bestComponent = withoutPrefixes
            }
        }
        
        cleaned = bestComponent.isEmpty ? cleaned : bestComponent
        
        // Step 3: Remove prefixes and suffixes
        cleaned = removePrefixes(from: cleaned)
        cleaned = removeSuffixes(from: cleaned)
        
        // Step 4: Final validation
        guard isValidFoodTerm(cleaned) else {
            debugLog("🔍 Rejected invalid term: '\(cleaned)'")
            return nil
        }
        
        return cleaned.lowercased()
    }
    
    private func removePrefixes(from text: String) -> String {
        let prefixes = ["w/", "with ", "includes ", "served with ", "comes with ", "topped with ", "add ", "extra ", "side of ", "choice of ", "fresh "]
        var result = text.lowercased()
        
        for prefix in prefixes {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return result
    }
    
    private func removeSuffixes(from text: String) -> String {
        let suffixes = [" ing", " ddar", " tion"]
        var result = text.lowercased()
        
        for suffix in suffixes {
            if result.hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return result
    }
    
    private func isJunkTerm(_ term: String) -> Bool {
        let lowercaseTerm = term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return junkTokens.contains(lowercaseTerm) || lowercaseTerm.count < 3
    }
    
    private func isValidFoodTerm(_ term: String) -> Bool {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must be at least 3 characters
        guard trimmed.count >= 3 else { return false }
        
        // Must contain letters
        guard trimmed.rangeOfCharacter(from: .letters) != nil else { return false }
        
        // Must not be a junk term
        guard !isJunkTerm(trimmed) else { return false }
        
        // Must not be only numbers or special characters
        let alphanumericSet = CharacterSet.alphanumerics
        guard trimmed.rangeOfCharacter(from: alphanumericSet) != nil else { return false }
        
        return true
    }
    
    // MARK: - USDA Lookup (Primary)
    
    private func attemptUSDALookup(searchTerm: String, originalName: String) async throws -> AnalyzedMenuItem? {
        debugLog("🔍 Attempting USDA lookup for: '\(searchTerm)'")
        
        do {
            let intelligentResult = try await USDAIntelligentMatcher.shared.findBestNutritionMatch(for: searchTerm)
            
            // Only accept high-confidence USDA matches
            if intelligentResult.isAvailable && intelligentResult.estimatedNutrition.confidence >= 0.65 {
                debugLog("🔍 USDA SUCCESS: '\(searchTerm)' → confidence: \(Int(intelligentResult.estimatedNutrition.confidence * 100))%")
                return AnalyzedMenuItem.createWithIntelligentUSDA(
                    name: originalName,
                    description: nil,
                    price: nil,
                    intelligentResult: intelligentResult,
                    textBounds: nil
                )
            } else if intelligentResult.isAvailable {
                debugLog("🔍 USDA LOW CONFIDENCE: '\(searchTerm)' → \(Int(intelligentResult.estimatedNutrition.confidence * 100))% (need 65%+)")
            } else {
                debugLog("🔍 USDA NO MATCH: '\(searchTerm)'")
            }
        } catch {
            debugLog("🔍 USDA ERROR for '\(searchTerm)': \(error)")
        }
        
        return nil
    }
    
    // MARK: - Open Food Facts Lookup (Fallback)
    
    private func attemptOFFLookup(searchTerm: String, originalName: String) async throws -> AnalyzedMenuItem? {
        debugLog("🔍 Attempting OFF fallback for: '\(searchTerm)'")
        
        do {
            let offResult = try await OpenFoodFactsService.shared.findNutritionMatch(for: searchTerm)
            
            // STRICT 60% minimum confidence threshold for OFF
            if offResult.isAvailable && offResult.confidence >= 0.60 {
                debugLog("🔍 OFF SUCCESS: '\(searchTerm)' → '\(offResult.matchedProductName)' confidence: \(Int(offResult.confidence * 100))%")
                return AnalyzedMenuItem.createWithOpenFoodFacts(
                    name: originalName,
                    description: nil,
                    price: nil,
                    offResult: offResult,
                    textBounds: nil
                )
            } else if offResult.isAvailable {
                debugLog("🔍 OFF REJECTED: '\(searchTerm)' → \(Int(offResult.confidence * 100))% (need 60%+)")
            } else {
                debugLog("🔍 OFF NO MATCH: '\(searchTerm)'")
            }
        } catch {
            debugLog("🔍 OFF ERROR for '\(searchTerm)': \(error)")
        }
        
        return nil
    }
}

// MARK: - Enhanced Menu Item Analysis Extensions

extension AnalyzedMenuItem {
    
    /// Create analyzed menu item using enhanced food matcher
    static func createWithEnhancedMatcher(
        name: String,
        description: String?,
        price: String?,
        textBounds: CGRect?
    ) async -> AnalyzedMenuItem {
        
        do {
            return try await EnhancedFoodMatcher.shared.findNutritionMatch(for: name)
        } catch {
            debugLog("🔍 Enhanced matcher failed for '\(name)': \(error)")
            return AnalyzedMenuItem.createUnavailable(
                name: name,
                description: description,
                price: price,
                textBounds: textBounds
            )
        }
    }
}