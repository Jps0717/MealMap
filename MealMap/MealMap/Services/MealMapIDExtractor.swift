import Foundation

// MARK: - MealMap ID Extraction Utility
struct MealMapIDExtractor {
    
    // MARK: - Public API
    
    /// Extract ID from MealMap entry - now prioritizes R-codes (nutrition data IDs)
    /// Examples:
    /// - "R0034" → "R0034" (PRIORITY: Restaurant nutrition data)
    /// - "R0084" → "R0084" (PRIORITY: Restaurant nutrition data) 
    /// - "chicken,_breast,_boneless,_skinless,_raw_2646170" → "2646170" (Generic food)
    /// - "hummus,_homemade_3891025" → "3891025" (Generic food)
    static func extractID(from foodEntry: String) -> String? {
        debugLog("🔍 Extracting ID from: '\(foodEntry)'")
        
        // PRIORITY 1: Check for R-prefixed restaurant IDs (these have nutrition data!)
        if foodEntry.hasPrefix("R") && isValidRCode(foodEntry) {
            debugLog("✅ Found restaurant nutrition ID: '\(foodEntry)'")
            return foodEntry // Return the full R-code as the ID
        }
        
        // PRIORITY 2: Extract trailing underscore followed by digits (generic foods)
        let pattern = "_([0-9]+)$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            debugLog("❌ Failed to create regex pattern")
            return nil
        }
        
        let range = NSRange(location: 0, length: foodEntry.utf16.count)
        
        if let match = regex.firstMatch(in: foodEntry, range: range) {
            let matchRange = match.range(at: 1) // Capture group 1 (the digits)
            
            if let swiftRange = Range(matchRange, in: foodEntry) {
                let extractedID = String(foodEntry[swiftRange])
                debugLog("✅ Extracted generic food ID: '\(extractedID)'")
                return extractedID
            }
        }
        
        debugLog("❌ No ID found in: '\(foodEntry)'")
        return nil
    }
    
    /// Check if a string is a valid R-code format (e.g., R0034, R0084)
    static func isValidRCode(_ entry: String) -> Bool {
        // R followed by 4 digits (R0000 - R9999)
        let pattern = "^R[0-9]{4}$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        
        let range = NSRange(location: 0, length: entry.utf16.count)
        return regex.firstMatch(in: entry, range: range) != nil
    }
    
    /// Check if an ID represents restaurant nutrition data (R-code)
    static func isRestaurantNutritionID(_ id: String) -> Bool {
        return id.hasPrefix("R") && isValidRCode(id)
    }
    
    /// Check if an ID represents generic food data (numeric)
    static func isGenericFoodID(_ id: String) -> Bool {
        return !id.hasPrefix("R") && id.allSatisfy { $0.isNumber }
    }
    
    /// Extract IDs from multiple food entries, categorizing by type
    static func extractIDs(from foodEntries: [String]) -> MealMapIDResults {
        var restaurantIDs: [String: String] = [:]
        var genericFoodIDs: [String: String] = [:]
        var invalidEntries: [String] = []
        
        for entry in foodEntries {
            if let id = extractID(from: entry) {
                if isRestaurantNutritionID(id) {
                    restaurantIDs[entry] = id
                } else {
                    genericFoodIDs[entry] = id
                }
            } else {
                invalidEntries.append(entry)
            }
        }
        
        return MealMapIDResults(
            restaurantIDs: restaurantIDs,
            genericFoodIDs: genericFoodIDs,
            invalidEntries: invalidEntries
        )
    }
    
    /// Validate if a string contains a valid ID pattern
    static func hasValidID(_ foodEntry: String) -> Bool {
        return extractID(from: foodEntry) != nil
    }
    
    /// Remove ID suffix from food entry to get clean name
    static func removeIDSuffix(from foodEntry: String) -> String {
        // If it's an R-code, return as-is since it's a restaurant ID
        if isValidRCode(foodEntry) {
            return foodEntry
        }
        
        // Remove numeric suffix for generic foods
        let pattern = "_[0-9]+$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return foodEntry
        }
        
        let range = NSRange(location: 0, length: foodEntry.utf16.count)
        let cleanedEntry = regex.stringByReplacingMatches(
            in: foodEntry,
            range: range,
            withTemplate: ""
        )
        
        return cleanedEntry
    }
    
    // MARK: - Validation and Analysis
    
    /// Analyze a list of food entries and provide statistics
    static func analyzeEntries(_ foodEntries: [String]) -> MealMapIDAnalysis {
        let results = extractIDs(from: foodEntries)
        
        let totalEntries = foodEntries.count
        let restaurantIDCount = results.restaurantIDs.count
        let genericFoodIDCount = results.genericFoodIDs.count
        let invalidCount = results.invalidEntries.count
        
        // Sample entries for debugging
        let sampleRestaurantIDs = Array(results.restaurantIDs.keys.prefix(5))
        let sampleGenericFoodIDs = Array(results.genericFoodIDs.keys.prefix(5))
        let sampleInvalidEntries = Array(results.invalidEntries.prefix(5))
        
        return MealMapIDAnalysis(
            totalEntries: totalEntries,
            restaurantIDCount: restaurantIDCount,
            genericFoodIDCount: genericFoodIDCount,
            invalidCount: invalidCount,
            sampleRestaurantEntries: sampleRestaurantIDs,
            sampleGenericFoodEntries: sampleGenericFoodIDs,
            sampleInvalidEntries: sampleInvalidEntries,
            extractedRestaurantIDs: Array(results.restaurantIDs.values.prefix(10)),
            extractedGenericFoodIDs: Array(results.genericFoodIDs.values.prefix(10))
        )
    }
    
    // MARK: - Testing and Examples
    
    static func runTests() {
        debugLog("🧪 Running MealMapIDExtractor tests...")
        
        let testCases: [(input: String, expectedID: String?, idType: String)] = [
            ("R0034", "R0034", "restaurant"), // Firehouse Subs
            ("R0084", "R0084", "restaurant"), // TGI Friday's
            ("R0056", "R0056", "restaurant"), // McDonald's
            ("R0083", "R0083", "restaurant"), // Subway
            ("chicken,_breast,_boneless,_skinless,_raw_2646170", "2646170", "generic"),
            ("fish,_salmon,_sockeye,_wild_caught,_raw_2684440", "2684440", "generic"),
            ("hummus,_homemade_3891025", "3891025", "generic"),
            ("invalid_entry_without_id", nil, "none"),
            ("R999", nil, "none"), // Invalid R-code format
            ("RXYZ", nil, "none"), // Invalid R-code format
            ("beef,_ground,_85%_lean_meat_/_15%_fat,_raw_1678234", "1678234", "generic"),
            ("", nil, "none"), // Empty string
            ("just_text_no_numbers", nil, "none"),
            ("R0000", "R0000", "restaurant"), // Valid R-code
            ("R9999", "R9999", "restaurant") // Valid R-code
        ]
        
        var passedTests = 0
        let totalTests = testCases.count
        
        for (index, testCase) in testCases.enumerated() {
            let result = extractID(from: testCase.input)
            let passed = result == testCase.expectedID
            
            let typeIndicator = testCase.idType == "restaurant" ? "🏪" : 
                               testCase.idType == "generic" ? "🥗" : "❌"
            
            if passed {
                passedTests += 1
                debugLog("✅ Test \(index + 1): \(typeIndicator) '\(testCase.input)' → '\(result ?? "nil")' ✓")
            } else {
                debugLog("❌ Test \(index + 1): \(typeIndicator) '\(testCase.input)' → '\(result ?? "nil")' (expected: '\(testCase.expectedID ?? "nil")') ✗")
            }
        }
        
        debugLog("🏆 Tests completed: \(passedTests)/\(totalTests) passed")
        
        // Test batch processing
        let sampleEntries = testCases.map { $0.input }
        let batchResults = extractIDs(from: sampleEntries)
        debugLog("📊 Batch extraction results:")
        debugLog("  🏪 Restaurant IDs: \(batchResults.restaurantIDs.count)")
        debugLog("  🥗 Generic Food IDs: \(batchResults.genericFoodIDs.count)")
        debugLog("  ❌ Invalid entries: \(batchResults.invalidEntries.count)")
        
        // Test analysis
        let analysis = analyzeEntries(sampleEntries)
        debugLog("📈 Analysis: \(analysis.restaurantIDCount) restaurant, \(analysis.genericFoodIDCount) generic, \(analysis.invalidCount) invalid")
    }
}

// MARK: - Data Models

struct MealMapIDResults {
    let restaurantIDs: [String: String]      // Entry → R-code
    let genericFoodIDs: [String: String]     // Entry → numeric ID
    let invalidEntries: [String]             // Entries with no extractable ID
    
    var totalValidIDs: Int {
        return restaurantIDs.count + genericFoodIDs.count
    }
    
    var hasRestaurantIDs: Bool {
        return !restaurantIDs.isEmpty
    }
    
    var hasGenericFoodIDs: Bool {
        return !genericFoodIDs.isEmpty
    }
}

struct MealMapIDAnalysis {
    let totalEntries: Int
    let restaurantIDCount: Int
    let genericFoodIDCount: Int
    let invalidCount: Int
    let sampleRestaurantEntries: [String]
    let sampleGenericFoodEntries: [String]
    let sampleInvalidEntries: [String]
    let extractedRestaurantIDs: [String]
    let extractedGenericFoodIDs: [String]
    
    var totalValidIDs: Int {
        return restaurantIDCount + genericFoodIDCount
    }
    
    var validIDPercentage: Double {
        guard totalEntries > 0 else { return 0.0 }
        return Double(totalValidIDs) / Double(totalEntries) * 100.0
    }
    
    var restaurantIDPercentage: Double {
        guard totalEntries > 0 else { return 0.0 }
        return Double(restaurantIDCount) / Double(totalEntries) * 100.0
    }
    
    var summary: String {
        return """
        MealMap ID Analysis:
        Total Entries: \(totalEntries)
        
        🏪 Restaurant IDs (R-codes): \(restaurantIDCount) (\(String(format: "%.1f", restaurantIDPercentage))%)
        🥗 Generic Food IDs: \(genericFoodIDCount) (\(String(format: "%.1f", Double(genericFoodIDCount) / Double(totalEntries) * 100.0))%)
        ❌ Invalid Entries: \(invalidCount) (\(String(format: "%.1f", Double(invalidCount) / Double(totalEntries) * 100.0))%)
        
        Sample Restaurant IDs:
        \(extractedRestaurantIDs.prefix(5).joined(separator: ", "))
        
        Sample Generic Food IDs:
        \(extractedGenericFoodIDs.prefix(5).joined(separator: ", "))
        
        PRIORITY: Restaurant IDs (R-codes) contain nutrition data from CSV files!
        """
    }
}

// MARK: - Usage Examples

extension MealMapIDExtractor {
    static func demonstrateUsage() {
        debugLog("📋 MealMap ID Extractor Usage Examples (Updated for R-codes):")
        
        // Example 1: Restaurant nutrition IDs (PRIORITY)
        let restaurantExamples = ["R0034", "R0084", "R0056", "R0083"]
        debugLog("Example 1: Restaurant Nutrition IDs (🏪 PRIORITY)")
        for example in restaurantExamples {
            if let id = extractID(from: example) {
                let restaurantName = getRestaurantNameForID(id)
                debugLog("  '\(example)' → ID: '\(id)' (\(restaurantName))")
            }
        }
        
        // Example 2: Generic food IDs
        let genericExamples = [
            "chicken,_breast,_boneless,_skinless,_raw_2646170",
            "fish,_salmon,_sockeye,_wild_caught,_raw_2684440",
            "hummus,_homemade_3891025"
        ]
        debugLog("Example 2: Generic Food IDs (🥗)")
        for example in genericExamples {
            if let id = extractID(from: example) {
                debugLog("  '\(example)' → ID: '\(id)'")
            }
        }
        
        // Example 3: Batch processing with categorization
        let mixedExamples = restaurantExamples + genericExamples + ["invalid_entry"]
        let results = extractIDs(from: mixedExamples)
        
        debugLog("Example 3: Batch Processing Results")
        debugLog("  🏪 Restaurant IDs: \(results.restaurantIDs.count)")
        debugLog("  🥗 Generic Food IDs: \(results.genericFoodIDs.count)")
        debugLog("  ❌ Invalid entries: \(results.invalidEntries.count)")
        
        // Example 4: Analysis
        let analysis = analyzeEntries(mixedExamples)
        debugLog("Example 4: Analysis Summary:\n\(analysis.summary)")
    }
    
    private static func getRestaurantNameForID(_ id: String) -> String {
        // Map some common R-codes to restaurant names for demo
        let mapping = [
            "R0034": "Firehouse Subs",
            "R0084": "TGI Friday's", 
            "R0056": "McDonald's",
            "R0083": "Subway"
        ]
        return mapping[id] ?? "Unknown Restaurant"
    }
}