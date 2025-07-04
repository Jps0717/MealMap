import Foundation

// MARK: - MealMap Fuzzy Food Matcher (Enhanced for R-code Priority)
class MealMapFoodMatcher {
    private let foodEntries: [String]
    private let restaurantEntries: [(original: String, cleaned: String, tokens: Set<String>)]
    private let genericFoodEntries: [(original: String, cleaned: String, tokens: Set<String>)]
    
    // Configuration
    private let minScoreThreshold: Double = 0.3
    private let stopWords = Set(["with", "and", "or", "the", "a", "an", "in", "on", "at", "to", "for", "of", "from", "includes", "served", "raw", "cooked"])
    
    init(foodEntries: [String]) {
        self.foodEntries = foodEntries
        
        // Separate restaurant entries (R-codes) from generic food entries
        var restaurantList: [(String, String, Set<String>)] = []
        var genericFoodList: [(String, String, Set<String>)] = []
        
        for entry in foodEntries {
            if entry.hasPrefix("R") && MealMapIDExtractor.isValidRCode(entry) {
                // Restaurant nutrition entry (R-code) - map to restaurant name
                if let restaurantName = Self.getRestaurantNameForRCode(entry) {
                    let cleaned = Self.cleanFoodName(restaurantName)
                    let tokens = Set(Self.tokenize(cleaned))
                    restaurantList.append((original: entry, cleaned: cleaned, tokens: tokens))
                }
            } else if !entry.hasPrefix("R") {
                // Generic food entry
                let cleaned = Self.cleanFoodName(entry)
                let tokens = Set(Self.tokenize(cleaned))
                genericFoodList.append((original: entry, cleaned: cleaned, tokens: tokens))
            }
        }
        
        self.restaurantEntries = restaurantList
        self.genericFoodEntries = genericFoodList
        
        debugLog("🍽️ Preprocessed entries: \(restaurantEntries.count) restaurants (R-codes), \(genericFoodEntries.count) generic foods")
    }
    
    // MARK: - Public API
    
    func findBestMatch(for inputName: String) -> MealMapMatchResult? {
        let cleanedInput = Self.cleanFoodName(inputName)
        let inputTokens = Set(Self.tokenize(cleanedInput))
        
        debugLog("🔍 Finding match for: '\(inputName)' cleaned: '\(cleanedInput)' tokens: \(inputTokens)")
        
        guard !inputTokens.isEmpty else {
            debugLog("❌ No valid tokens found in input")
            return nil
        }
        
        // PRIORITY 1: Try to match against restaurant entries (R-codes) first
        if let restaurantMatch = findBestMatchInCategory(
            inputTokens: inputTokens,
            cleanedInput: cleanedInput,
            originalInput: inputName,
            entries: restaurantEntries,
            categoryName: "Restaurant"
        ) {
            debugLog("🏪 Found restaurant match: '\(restaurantMatch.matchedEntry)' (score: \(String(format: "%.3f", restaurantMatch.score)))")
            return restaurantMatch
        }
        
        // PRIORITY 2: Try to match against generic food entries
        if let genericMatch = findBestMatchInCategory(
            inputTokens: inputTokens,
            cleanedInput: cleanedInput,
            originalInput: inputName,
            entries: genericFoodEntries,
            categoryName: "Generic Food"
        ) {
            debugLog("🥗 Found generic food match: '\(genericMatch.matchedEntry)' (score: \(String(format: "%.3f", genericMatch.score)))")
            return genericMatch
        }
        
        debugLog("❌ No match found above threshold (\(minScoreThreshold))")
        return nil
    }
    
    private func findBestMatchInCategory(
        inputTokens: Set<String>,
        cleanedInput: String,
        originalInput: String,
        entries: [(original: String, cleaned: String, tokens: Set<String>)],
        categoryName: String
    ) -> MealMapMatchResult? {
        
        var bestMatch: MealMapMatchResult?
        var bestScore: Double = 0.0
        
        // Try different matching strategies in order of precision
        let strategies: [(String, (Set<String>, (original: String, cleaned: String, tokens: Set<String>)) -> Double)] = [
            ("Exact Match", exactMatchStrategy),
            ("Substring Match", substringMatchStrategy),
            ("Token Overlap", tokenOverlapStrategy),
            ("Fuzzy Similarity", fuzzySimilarityStrategy)
        ]
        
        for (strategyName, strategy) in strategies {
            for entry in entries {
                let score = strategy(inputTokens, entry)
                
                if score > bestScore && score >= minScoreThreshold {
                    bestScore = score
                    bestMatch = MealMapMatchResult(
                        originalInput: originalInput,
                        cleanedInput: cleanedInput,
                        matchedEntry: entry.original,
                        score: score,
                        strategy: "\(categoryName) - \(strategyName)"
                    )
                }
            }
            
            // If we found a high-confidence match with this strategy, we can stop
            if bestScore > 0.8 {
                break
            }
        }
        
        return bestMatch
    }
    
    // MARK: - Matching Strategies
    
    private func exactMatchStrategy(inputTokens: Set<String>, entry: (original: String, cleaned: String, tokens: Set<String>)) -> Double {
        // Check for exact cleaned name match
        if inputTokens == entry.tokens {
            return 1.0
        }
        
        // Check for exact subset match (all input tokens present)
        if inputTokens.isSubset(of: entry.tokens) {
            return 0.9
        }
        
        return 0.0
    }
    
    private func substringMatchStrategy(inputTokens: Set<String>, entry: (original: String, cleaned: String, tokens: Set<String>)) -> Double {
        let inputString = Array(inputTokens).joined(separator: " ")
        let entryString = Array(entry.tokens).joined(separator: " ")
        
        // Check if cleaned input is a substring of the entry
        if entryString.contains(inputString) {
            return 0.8
        }
        
        // Check if any input token is a substantial substring
        for inputToken in inputTokens {
            if inputToken.count >= 4 {
                for entryToken in entry.tokens {
                    if entryToken.contains(inputToken) || inputToken.contains(entryToken) {
                        return 0.6
                    }
                }
            }
        }
        
        return 0.0
    }
    
    private func tokenOverlapStrategy(inputTokens: Set<String>, entry: (original: String, cleaned: String, tokens: Set<String>)) -> Double {
        let intersection = inputTokens.intersection(entry.tokens)
        let union = inputTokens.union(entry.tokens)
        
        guard !union.isEmpty else { return 0.0 }
        
        // Jaccard similarity
        let jaccardScore = Double(intersection.count) / Double(union.count)
        
        // Boost score for important matches
        var boostedScore = jaccardScore
        
        // Check for restaurant name matches (high importance for R-codes)
        let restaurantTokens = Set(["mcdonalds", "subway", "starbucks", "kfc", "pizza", "burger", "taco", "chicken", "dunkin"])
        let restaurantIntersection = inputTokens.intersection(restaurantTokens).intersection(entry.tokens)
        if !restaurantIntersection.isEmpty {
            boostedScore += 0.3
        }
        
        // Check for protein matches (high importance)
        let proteinTokens = Set(["chicken", "beef", "fish", "salmon", "turkey", "pork", "shrimp", "lamb"])
        let proteinIntersection = inputTokens.intersection(proteinTokens).intersection(entry.tokens)
        if !proteinIntersection.isEmpty {
            boostedScore += 0.2
        }
        
        // Check for preparation method matches
        let preparationTokens = Set(["grilled", "fried", "baked", "roasted", "steamed", "raw", "cooked"])
        let preparationIntersection = inputTokens.intersection(preparationTokens).intersection(entry.tokens)
        if !preparationIntersection.isEmpty {
            boostedScore += 0.1
        }
        
        return min(boostedScore, 1.0)
    }
    
    private func fuzzySimilarityStrategy(inputTokens: Set<String>, entry: (original: String, cleaned: String, tokens: Set<String>)) -> Double {
        let inputString = Array(inputTokens).sorted().joined(separator: " ")
        let entryString = Array(entry.tokens).sorted().joined(separator: " ")
        
        return calculateLevenshteinSimilarity(inputString, entryString)
    }
    
    // MARK: - Restaurant Name Mapping
    
    private static func getRestaurantNameForRCode(_ rCode: String) -> String? {
        // Map R-codes to restaurant names for matching
        let mapping: [String: String] = [
            "R0000": "7 Eleven",
            "R0001": "Applebees",
            "R0002": "Arbys",
            "R0003": "Auntie Annes",
            "R0004": "BJs Restaurant Brewhouse",
            "R0005": "Baskin Robbins",
            "R0006": "Bob Evans",
            "R0007": "Bojangles",
            "R0008": "Bonefish Grill",
            "R0009": "Boston Market",
            "R0010": "Burger King",
            "R0011": "California Pizza Kitchen",
            "R0012": "Captain Ds",
            "R0013": "Carls Jr",
            "R0014": "Carrabbas Italian Grill",
            "R0015": "Caseys General Store",
            "R0016": "Checkers Drive In Rallys",
            "R0017": "Chick fil A",
            "R0019": "Chilis",
            "R0020": "Chipotle",
            "R0021": "Chuck E Cheese",
            "R0022": "Churchs Chicken",
            "R0023": "Cicis Pizza",
            "R0024": "Culvers",
            "R0025": "Dairy Queen",
            "R0026": "Del Taco",
            "R0027": "Dennys",
            "R0028": "Dickeys Barbecue Pit",
            "R0029": "Dominos",
            "R0030": "Dunkin Donuts",
            "R0031": "Einstein Bros",
            "R0032": "El Pollo Loco",
            "R0033": "Famous Daves",
            "R0034": "Firehouse Subs",
            "R0035": "Five Guys",
            "R0036": "Friendlys",
            "R0037": "Frischs Big Boy",
            "R0038": "Golden Corral",
            "R0039": "Hardees",
            "R0040": "Hooters",
            "R0041": "IHOP",
            "R0042": "In N Out Burger",
            "R0043": "Jack in the Box",
            "R0044": "Jamba Juice",
            "R0045": "Jasons Deli",
            "R0046": "Jersey Mikes Subs",
            "R0047": "Joes Crab Shack",
            "R0048": "KFC",
            "R0049": "Krispy Kreme",
            "R0050": "Krystal",
            "R0051": "Little Caesars",
            "R0052": "Long John Silvers",
            "R0053": "LongHorn Steakhouse",
            "R0054": "Marcos Pizza",
            "R0055": "McAlisters Deli",
            "R0056": "McDonalds",
            "R0057": "Moes Southwest Grill",
            "R0058": "Noodles Company",
            "R0059": "OCharleys",
            "R0060": "Olive Garden",
            "R0061": "Outback Steakhouse",
            "R0062": "PF Changs",
            "R0063": "Panda Express",
            "R0064": "Panera Bread",
            "R0065": "Papa Johns",
            "R0066": "Papa Murphys",
            "R0067": "Perkins",
            "R0068": "Pizza Hut",
            "R0069": "Popeyes",
            "R0070": "Potbelly Sandwich Shop",
            "R0071": "Qdoba",
            "R0072": "Quiznos",
            "R0073": "Red Lobster",
            "R0074": "Red Robin",
            "R0075": "Romanos Macaroni Grill",
            "R0076": "Round Table Pizza",
            "R0077": "Ruby Tuesday",
            "R0078": "Sbarro",
            "R0079": "Sheetz",
            "R0080": "Sonic",
            "R0081": "Starbucks",
            "R0082": "Steak n Shake",
            "R0083": "Subway",
            "R0084": "TGI Fridays",
            "R0085": "Taco Bell",
            "R0086": "The Capital Grille",
            "R0087": "Tim Hortons",
            "R0088": "Wawa",
            "R0089": "Wendys",
            "R0090": "Whataburger",
            "R0091": "White Castle",
            "R0092": "Wingstop",
            "R0093": "Yard House",
            "R0094": "Zaxbys"
        ]
        
        return mapping[rCode]
    }
    
    // MARK: - Utility Functions
    
    private static func cleanFoodName(_ name: String) -> String {
        var cleaned = name.lowercased()
        
        // Remove ID suffix (e.g., "_2646170")
        cleaned = cleaned.replacingOccurrences(of: "_\\d+$", with: "", options: .regularExpression)
        
        // Replace underscores and commas with spaces
        cleaned = cleaned.replacingOccurrences(of: "[_,]", with: " ", options: .regularExpression)
        
        // Remove special characters except spaces
        cleaned = cleaned.replacingOccurrences(of: "[^a-z\\s]", with: "", options: .regularExpression)
        
        // Remove extra whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func tokenize(_ text: String) -> [String] {
        let stopWords = Set(["with", "and", "or", "the", "a", "an", "in", "on", "at", "to", "for", "of", "from", "includes", "served", "raw", "cooked"])
        
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && !stopWords.contains($0) && $0.count >= 2 }
    }
    
    private func calculateLevenshteinSimilarity(_ str1: String, _ str2: String) -> Double {
        let distance = levenshteinDistance(str1, str2)
        let maxLength = max(str1.count, str2.count)
        
        guard maxLength > 0 else { return 1.0 }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let a = Array(str1)
        let b = Array(str2)
        
        let m = a.count
        let n = b.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        
        for j in 0...n {
            dp[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if a[i-1] == b[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        
        return dp[m][n]
    }
    
    // MARK: - Debugging Support
    
    func findTopMatches(for inputName: String, limit: Int = 10) -> [MealMapMatchResult] {
        let cleanedInput = Self.cleanFoodName(inputName)
        let inputTokens = Set(Self.tokenize(cleanedInput))
        
        var results: [MealMapMatchResult] = []
        
        // Get top matches from both categories
        let allEntries = restaurantEntries + genericFoodEntries
        
        for entry in allEntries {
            let score = tokenOverlapStrategy(inputTokens: inputTokens, entry: entry)
            
            if score >= minScoreThreshold {
                let categoryType = entry.original.hasPrefix("R") ? "Restaurant" : "Generic Food"
                results.append(MealMapMatchResult(
                    originalInput: inputName,
                    cleanedInput: cleanedInput,
                    matchedEntry: entry.original,
                    score: score,
                    strategy: "\(categoryType) - Token Overlap"
                ))
            }
        }
        
        // Sort by score (restaurant matches get slight priority boost)
        return Array(results.sorted { result1, result2 in
            let score1 = result1.score + (result1.matchedEntry.hasPrefix("R") ? 0.1 : 0.0)
            let score2 = result2.score + (result2.matchedEntry.hasPrefix("R") ? 0.1 : 0.0)
            return score1 > score2
        }.prefix(limit))
    }
    
    func getStatistics() -> MealMapMatcherStatistics {
        return MealMapMatcherStatistics(
            totalEntries: foodEntries.count,
            restaurantEntries: restaurantEntries.count,
            genericFoodEntries: genericFoodEntries.count,
            sampleRestaurantRCodes: Array(restaurantEntries.prefix(5).map { $0.original }),
            sampleGenericFoodEntries: Array(genericFoodEntries.prefix(5).map { $0.original })
        )
    }
}

// MARK: - Data Models

struct MealMapMatchResult {
    let originalInput: String
    let cleanedInput: String
    let matchedEntry: String
    let score: Double
    let strategy: String
    
    var isRestaurantMatch: Bool {
        return matchedEntry.hasPrefix("R")
    }
    
    var isGenericFoodMatch: Bool {
        return !matchedEntry.hasPrefix("R")
    }
}

struct MealMapMatcherStatistics {
    let totalEntries: Int
    let restaurantEntries: Int
    let genericFoodEntries: Int
    let sampleRestaurantRCodes: [String]
    let sampleGenericFoodEntries: [String]
    
    var restaurantPercentage: Double {
        guard totalEntries > 0 else { return 0.0 }
        return Double(restaurantEntries) / Double(totalEntries) * 100.0
    }
    
    var summary: String {
        return """
        MealMap Matcher Statistics:
        🏪 Restaurant entries (R-codes): \(restaurantEntries) (\(String(format: "%.1f", restaurantPercentage))%)
        🥗 Generic food entries: \(genericFoodEntries) (\(String(format: "%.1f", 100.0 - restaurantPercentage))%)
        
        Priority: Restaurant matches (R-codes) have CSV nutrition data!
        """
    }
}

// MARK: - Example Usage

extension MealMapFoodMatcher {
    static func runExamples() {
        let sampleEntries = [
            // Restaurant R-codes (PRIORITY)
            "R0056", // McDonald's
            "R0083", // Subway  
            "R0034", // Firehouse Subs
            "R0084", // TGI Friday's
            
            // Generic food entries
            "chicken,_breast,_boneless,_skinless,_raw_2646170",
            "fish,_salmon,_sockeye,_wild_caught,_raw_2684440",
            "hummus,_homemade_3891025",
            "beef,_ground,_85%_lean_meat_/_15%_fat,_raw_1678234"
        ]
        
        let matcher = MealMapFoodMatcher(foodEntries: sampleEntries)
        
        let testCases = [
            "mcdonalds", // Should match R0056
            "subway sandwich", // Should match R0083
            "firehouse", // Should match R0034
            "friday's restaurant", // Should match R0084
            "grilled chicken", // Should match generic chicken
            "salmon fish" // Should match generic salmon
        ]
        
        debugLog("🧪 Running MealMapFoodMatcher examples...")
        
        for testCase in testCases {
            if let match = matcher.findBestMatch(for: testCase) {
                let type = match.isRestaurantMatch ? "🏪" : "🥗"
                debugLog("\(type) '\(testCase)' → '\(match.matchedEntry)' (score: \(String(format: "%.3f", match.score)), strategy: \(match.strategy))")
            } else {
                debugLog("❌ '\(testCase)' → No match found")
            }
        }
        
        // Show statistics
        let stats = matcher.getStatistics()
        debugLog("📊 \(stats.summary)")
    }
}