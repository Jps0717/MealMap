import Foundation

// MARK: - MealMap API System Example Usage
class MealMapExampleUsage {
    
    /// Demo the complete MealMap API system workflow (updated for R-code priority)
    static func runCompleteDemo() async {
        debugLog("🎬 Starting MealMap API System Demo (R-code Priority)")
        
        // Step 1: Test API Service directly
        await testAPIService()
        
        // Step 2: Test Food Matcher with R-code priority  
        await testFoodMatcher()
        
        // Step 3: Test ID Extraction (now handles R-codes)
        testIDExtraction()
        
        // Step 4: Test Nutrition Engine
        await testNutritionEngine()
        
        // Step 5: Demo R-code priority system
        await demonstrateRCodePriority()
        
        debugLog("✅ Demo complete - MealMap system prioritizes restaurant nutrition data (R-codes)!")
    }
    
    // MARK: - API Service Testing
    
    private static func testAPIService() async {
        debugLog("📡 Testing MealMap API Service...")
        
        do {
            // Test getting food list statistics
            let stats = try await MealMapAPIService.shared.getFoodListStatistics()
            debugLog("📊 API Statistics:")
            debugLog("  Total entries: \(stats.totalEntries)")
            debugLog("  🏪 Restaurant entries (R-codes): \(stats.restaurantEntries)")
            debugLog("  🥗 Generic food entries: \(stats.genericFoodEntries)")
            debugLog("  Sample R-codes: \(stats.sampleRestaurantEntries.prefix(3).joined(separator: ", "))")
            
            // Test finding nutrition matches (prioritize restaurants)
            let testFoods = [
                "mcdonalds", // Should match R0056
                "subway", // Should match R0083
                "grilled chicken", // Should match generic
                "invalid food name"
            ]
            
            for food in testFoods {
                let result = try await MealMapAPIService.shared.findNutritionMatch(for: food)
                if result.isAvailable {
                    let typeIcon = result.dataType.emoji
                    debugLog("✅ \(typeIcon) '\(food)' → '\(result.matchedEntry)' (ID: \(result.extractedID), score: \(String(format: "%.3f", result.matchScore)), type: \(result.dataType.displayName))")
                } else {
                    debugLog("❌ '\(food)' → No match found")
                }
            }
            
        } catch {
            debugLog("❌ API Service test failed: \(error)")
        }
    }
    
    // MARK: - Food Matcher Testing (Enhanced for R-codes)
    
    private static func testFoodMatcher() async {
        debugLog("🔍 Testing MealMap Food Matcher (R-code Priority)...")
        
        // Get sample food entries including R-codes
        let sampleEntries = [
            // Restaurant R-codes (PRIORITY)
            "R0056", // McDonald's
            "R0083", // Subway
            "R0034", // Firehouse Subs
            "R0084", // TGI Friday's
            "R0048", // KFC
            "R0081", // Starbucks
            
            // Generic food entries
            "chicken,_breast,_boneless,_skinless,_raw_2646170",
            "fish,_salmon,_sockeye,_wild_caught,_raw_2684440",
            "hummus,_homemade_3891025",
            "beef,_ground,_85%_lean_meat_/_15%_fat,_raw_1678234",
            "cheese,_cheddar,_sharp_4982736",
            "shrimp,_cooked,_moist_heat_8273642"
        ]
        
        let matcher = MealMapFoodMatcher(foodEntries: sampleEntries)
        
        // Show matcher statistics
        let stats = matcher.getStatistics()
        debugLog("📊 Matcher Statistics:")
        debugLog(stats.summary)
        
        let testCases = [
            ("mcdonalds", "Should match R0056 (McDonald's)"),
            ("subway sandwich", "Should match R0083 (Subway)"),
            ("firehouse subs", "Should match R0034 (Firehouse Subs)"),
            ("kfc chicken", "Should match R0048 (KFC)"),
            ("starbucks coffee", "Should match R0081 (Starbucks)"),
            ("grilled chicken breast", "Should match generic chicken"),
            ("hummus with tahini", "Should match generic hummus"),
            ("invalid food item", "Should not match anything")
        ]
        
        for (testCase, expectation) in testCases {
            if let match = matcher.findBestMatch(for: testCase) {
                let typeIcon = match.isRestaurantMatch ? "🏪" : "🥗"
                let priorityTag = match.isRestaurantMatch ? "PRIORITY" : "generic"
                debugLog("✅ \(typeIcon) '\(testCase)' → '\(match.matchedEntry)' (score: \(String(format: "%.3f", match.score)), \(priorityTag)) - \(expectation)")
            } else {
                debugLog("❌ '\(testCase)' → No match found - \(expectation)")
            }
        }
        
        // Test top matches for debugging
        debugLog("🔬 Top matches for 'chicken' (should prioritize R-codes):")
        let topMatches = matcher.findTopMatches(for: "chicken", limit: 5)
        for (index, match) in topMatches.enumerated() {
            let typeIcon = match.isRestaurantMatch ? "🏪" : "🥗"
            debugLog("  \(index + 1). \(typeIcon) '\(match.matchedEntry)' (score: \(String(format: "%.3f", match.score)))")
        }
    }
    
    // MARK: - ID Extraction Testing (Updated for R-codes)
    
    private static func testIDExtraction() {
        debugLog("🔧 Testing MealMap ID Extraction (R-code Priority)...")
        
        // Run built-in tests
        MealMapIDExtractor.runTests()
        
        // Test with real-world examples prioritizing R-codes
        let realWorldExamples = [
            // PRIORITY: Restaurant R-codes
            "R0034", // Firehouse Subs
            "R0056", // McDonald's  
            "R0083", // Subway
            "R0084", // TGI Friday's
            
            // Generic food entries
            "chicken,_breast,_boneless,_skinless,_raw_2646170",
            "fish,_salmon,_sockeye,_wild_caught,_raw_2684440", 
            "hummus,_homemade_3891025",
            
            // Invalid entries
            "invalid_entry_no_id",
            "R999", // Invalid R-code format
        ]
        
        debugLog("🌍 Real-world extraction examples (R-code priority):")
        let results = MealMapIDExtractor.extractIDs(from: realWorldExamples)
        
        debugLog("🏪 Restaurant IDs (R-codes) - PRIORITY:")
        for (entry, id) in results.restaurantIDs {
            debugLog("  ✅ '\(entry)' → ID: '\(id)' (Has CSV nutrition data)")
        }
        
        debugLog("🥗 Generic Food IDs:")
        for (entry, id) in results.genericFoodIDs {
            debugLog("  ✅ '\(entry)' → ID: '\(id)' (Generic food data)")
        }
        
        debugLog("❌ Invalid Entries:")
        for entry in results.invalidEntries {
            debugLog("  ❌ '\(entry)' → No ID extracted")
        }
        
        // Analysis
        let analysis = MealMapIDExtractor.analyzeEntries(realWorldExamples)
        debugLog("📈 Analysis Summary:")
        debugLog(analysis.summary)
    }
    
    // MARK: - Nutrition Engine Testing
    
    private static func testNutritionEngine() async {
        debugLog("🏭 Testing MealMap Nutrition Engine...")
        
        do {
            // Test engine statistics
            let stats = try await MealMapNutritionEngine.shared.getEngineStatistics()
            debugLog("📊 Engine Statistics:")
            debugLog("  API entries: \(stats.apiStatistics.totalEntries)")
            debugLog("  🏪 Restaurant entries: \(stats.apiStatistics.restaurantEntries)")
            debugLog("  Cache hit rate: \(String(format: "%.1f", stats.cacheStatistics.cacheHitRate * 100))%")
            
            // Test menu item analysis (should prioritize restaurants)
            let testItems = [
                ("mcdonalds big mac", "Should match McDonald's R0056"),
                ("subway turkey sandwich", "Should match Subway R0083"),
                ("grilled chicken breast", "Should match generic chicken"),
                ("unknown menu item", "Should be unavailable")
            ]
            
            for (item, expectation) in testItems {
                let result = try await MealMapNutritionEngine.shared.analyzeMenuItem(item)
                if result.isAvailable {
                    let typeIcon = result.extractedID.hasPrefix("R") ? "🏪" : "🥗"
                    debugLog("✅ \(typeIcon) '\(item)' → Match: '\(result.matchedEntry)' (ID: \(result.extractedID)) - \(expectation)")
                } else {
                    debugLog("❌ '\(item)' → Analysis unavailable - \(expectation)")
                }
            }
            
            // Test OCR integration
            debugLog("🔗 Testing OCR integration...")
            let ocrResult = try await MealMapNutritionEngine.shared.analyzeMenuItemForOCR("subway sandwich")
            let typeIcon = ocrResult.estimationTier == .mealMapAPI ? "🏪" : "🥗"
            debugLog("📄 \(typeIcon) OCR Result: \(ocrResult.name) → Tier: \(ocrResult.estimationTier.displayName)")
            
        } catch {
            debugLog("❌ Nutrition Engine test failed: \(error)")
        }
    }
    
    // MARK: - R-code Priority Demonstration
    
    private static func demonstrateRCodePriority() async {
        debugLog("🎯 Demonstrating R-code Priority System...")
        
        let priorityTestCases = [
            ("mcdonalds", "R0056", "McDonald's has CSV nutrition data"),
            ("subway", "R0083", "Subway has CSV nutrition data"),
            ("kfc", "R0048", "KFC has CSV nutrition data"),
            ("taco bell", "R0085", "Taco Bell has CSV nutrition data"),
            ("starbucks", "R0081", "Starbucks has CSV nutrition data")
        ]
        
        do {
            for (query, expectedRCode, description) in priorityTestCases {
                let result = try await MealMapAPIService.shared.findNutritionMatch(for: query)
                
                if result.isAvailable && result.extractedID == expectedRCode {
                    debugLog("✅ 🏪 '\(query)' → \(result.extractedID) (\(description))")
                    debugLog("    Confidence: \(String(format: "%.1f", result.confidence * 100))% | Score: \(String(format: "%.3f", result.matchScore))")
                } else if result.isAvailable {
                    debugLog("⚠️ '\(query)' → \(result.extractedID) (expected \(expectedRCode))")
                } else {
                    debugLog("❌ '\(query)' → No match (expected \(expectedRCode))")
                }
            }
        } catch {
            debugLog("❌ R-code priority test failed: \(error)")
        }
    }
    
    // MARK: - Example Match Flow Documentation (Updated)
    
    static func demonstrateMatchFlow() {
        debugLog("""
        
        🎯 MealMap API Match Flow (R-code Priority):
        
        Input: "mcdonalds"
        ↓
        1. CLEAN INPUT:
           "mcdonalds" → tokens: ["mcdonalds"]
        ↓  
        2. FETCH FOOD LIST:
           GET https://meal-map-api-njio.onrender.com/restaurants
           → 500+ entries (R-codes + generic foods)
        ↓
        3. PRIORITY MATCHING:
           PRIORITY 1: Restaurant entries (R-codes)
           - "R0056" → "McDonald's" → EXACT MATCH!
           Score: 1.0 (perfect match)
           
           PRIORITY 2: Generic food entries
           - (Skipped - restaurant match found)
        ↓
        4. EXTRACT ID:
           "R0056" → ID: "R0056" (Restaurant nutrition data)
        ↓
        5. CREATE RESULT:
           {
             originalName: "mcdonalds",
             matchedEntry: "R0056",
             extractedID: "R0056",
             matchScore: 1.0,
             confidence: 0.9,
             dataType: "restaurant_nutrition",
             isAvailable: true
           }
        ↓
        6. NUTRITION LOOKUP:
           R0056 → CSV file R0056.csv (McDonald's nutrition data)
        
        ✅ Result: Direct access to restaurant nutrition CSV data!
        
        KEY BENEFITS:
        🏪 R-codes have complete nutrition data from CSV files
        🥗 Generic foods provide basic nutrition estimates
        ⚡ Restaurant matches get priority and higher confidence
        📊 CSV data is more accurate than generic estimates
        """)
    }
    
    // MARK: - Performance Benchmarks
    
    static func runPerformanceBenchmarks() async {
        debugLog("⚡ Running MealMap Performance Benchmarks (R-code Priority)...")
        
        let testItems = [
            // Restaurant queries (should be fast and accurate)
            ("mcdonalds", "Restaurant"),
            ("subway", "Restaurant"),
            ("kfc", "Restaurant"),
            ("taco bell", "Restaurant"),
            ("starbucks", "Restaurant"),
            
            // Generic food queries
            ("chicken breast", "Generic"),
            ("salmon fillet", "Generic"),
            ("caesar salad", "Generic"),
            ("chocolate cake", "Generic"),
            ("ground beef", "Generic")
        ]
        
        let startTime = Date()
        var restaurantMatches = 0
        var genericMatches = 0
        var noMatches = 0
        
        for (index, (item, expectedType)) in testItems.enumerated() {
            let itemStart = Date()
            
            do {
                let result = try await MealMapAPIService.shared.findNutritionMatch(for: item)
                let itemTime = Date().timeIntervalSince(itemStart)
                
                if result.isAvailable {
                    if result.isRestaurantNutrition {
                        restaurantMatches += 1
                        debugLog("⚡ \(index + 1): 🏪 '\(item)' → \(String(format: "%.3f", itemTime))s ✅ (R-code: \(result.extractedID))")
                    } else {
                        genericMatches += 1
                        debugLog("⚡ \(index + 1): 🥗 '\(item)' → \(String(format: "%.3f", itemTime))s ✅ (Generic: \(result.extractedID))")
                    }
                } else {
                    noMatches += 1
                    debugLog("⚡ \(index + 1): ❌ '\(item)' → \(String(format: "%.3f", itemTime))s ❌")
                }
            } catch {
                let itemTime = Date().timeIntervalSince(itemStart)
                noMatches += 1
                debugLog("⚡ \(index + 1): 💥 '\(item)' → \(String(format: "%.3f", itemTime))s 💥")
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let avgTime = totalTime / Double(testItems.count)
        
        debugLog("📊 Performance Summary:")
        debugLog("  Total time: \(String(format: "%.2f", totalTime))s")
        debugLog("  Average per item: \(String(format: "%.3f", avgTime))s")
        debugLog("  Items per second: \(String(format: "%.1f", 1.0 / avgTime))")
        debugLog("  🏪 Restaurant matches: \(restaurantMatches)")
        debugLog("  🥗 Generic matches: \(genericMatches)")
        debugLog("  ❌ No matches: \(noMatches)")
        debugLog("  Success rate: \(String(format: "%.1f", Double(restaurantMatches + genericMatches) / Double(testItems.count) * 100))%")
    }
}

// MARK: - Usage Instructions

extension MealMapExampleUsage {
    
    static func printUsageInstructions() {
        debugLog("""
        
        📚 MealMap API System Usage Instructions (R-code Priority):
        
        🔧 SETUP:
        1. The system automatically fetches food entries from:
           https://meal-map-api-njio.onrender.com/restaurants
        2. Data includes R-codes (restaurant nutrition) + generic foods
        3. R-codes are prioritized for matching (they have CSV nutrition data)
        4. Data is cached locally for 24 hours
        
        💡 BASIC USAGE:
        
        // Simple nutrition matching (prioritizes restaurants)
        let result = try await MealMapAPIService.shared.findNutritionMatch(for: "mcdonalds")
        
        // Check match type and access nutrition data
        if result.isAvailable {
            print("Match: \\(result.matchedEntry)")
            print("ID: \\(result.extractedID)")
            print("Type: \\(result.dataType.displayName)")
            
            if result.isRestaurantNutrition {
                print("🏪 Restaurant data - has CSV nutrition file!")
            } else {
                print("🥗 Generic food data - estimated nutrition")
            }
        }
        
        // Get multiple matches with priority ranking
        let topMatches = try await MealMapAPIService.shared.findTopMatches(for: "chicken", limit: 5)
        
        📱 OCR INTEGRATION:
        
        // Use with menu analysis (prioritizes restaurant matches)
        let menuResult = try await MealMapNutritionEngine.shared.analyzeMenuItemForOCR("subway sandwich")
        
        // Restaurant matches get MealMap tier
        if menuResult.estimationTier == .mealMapAPI {
            print("🏪 Restaurant match with CSV nutrition data")
        }
        
        🧪 TESTING:
        
        // Run complete system demo with R-code priority
        await MealMapExampleUsage.runCompleteDemo()
        
        // Run performance benchmarks
        await MealMapExampleUsage.runPerformanceBenchmarks()
        
        // Show R-code priority demonstration
        await MealMapExampleUsage.demonstrateRCodePriority()
        
        🔍 R-CODE SYSTEM:
        
        // R-codes represent restaurant nutrition data
        R0056 = McDonald's (has R0056.csv with all menu items)
        R0083 = Subway (has R0083.csv with all menu items)
        R0034 = Firehouse Subs (has R0034.csv with all menu items)
        
        // System prioritizes these because they have complete nutrition data
        
        🎯 PRIORITY SYSTEM:
        
        1. HIGHEST: Restaurant matches (R-codes) - complete CSV nutrition data
        2. LOWER: Generic food matches - estimated nutrition data
        
        ⚠️ BENEFITS OF R-CODES:
        
        1. ✅ Complete nutrition data from CSV files  
        2. ✅ Accurate portion sizes and ingredients
        3. ✅ Restaurant-specific menu items
        4. ✅ Higher confidence scores (up to 90%)
        5. ✅ No estimation required - real data
        
        vs. Generic Foods:
        1. ⚠️ Estimated nutrition data only
        2. ⚠️ Generic portion sizes
        3. ⚠️ Lower confidence scores (max 70%)
        4. ⚠️ Requires nutrition estimation
        
        🔮 NEXT STEPS:
        
        1. Integrate CSV nutrition file loading for R-codes
        2. Build restaurant menu item lookup system
        3. Enhance portion size detection for restaurant items
        4. Add restaurant-specific dietary tags and filters
        
        """)
    }
    
    static func printSystemArchitecture() {
        debugLog("""
        
        🏗️ MealMap API System Architecture (R-code Priority):
        
        ┌─────────────────────────────────────────────────────────────┐
        │                    MenuOCRService                           │
        │                 (Menu Analysis)                             │
        └─────────────────────┬───────────────────────────────────────┘
                              │
                              v
        ┌─────────────────────────────────────────────────────────────┐
        │               MealMapNutritionEngine                        │
        │              (High-level Analysis)                          │
        └─────────────────────┬───────────────────────────────────────┘
                              │
                              v
        ┌─────────────────────────────────────────────────────────────┐
        │                MealMapAPIService                            │
        │         (API Communication + R-code Priority)              │
        └─────────────────────┬───────────────────────────────────────┘
                              │
                              v
        ┌─────────────────────────────────────────────────────────────┐
        │               MealMapFoodMatcher                            │
        │         (Fuzzy Matching with R-code Priority)              │
        └─────────────────────┬───────────────────────────────────────┘
                              │
                              v
        ┌─────────────────────────────────────────────────────────────┐
        │               MealMapIDExtractor                            │
        │         (ID Parsing: R-codes + Generic IDs)                │
        └─────────────────────────────────────────────────────────────┘
        
        📡 DATA FLOW (R-code Priority):
        
        1. MenuOCRService extracts menu items from photos
        2. MealMapNutritionEngine processes each menu item
        3. MealMapAPIService fetches food database (R-codes + generic)
        4. MealMapFoodMatcher prioritizes restaurant matches (R-codes)
        5. MealMapIDExtractor extracts R-codes or generic IDs
        6. Results flow back with data type classification
        
        🏪 R-CODE PROCESSING:
        
        Input: "mcdonalds" 
        ↓ Restaurant Matcher: "R0056" (McDonald's)
        ↓ ID Extractor: "R0056" 
        ↓ Data Type: restaurant_nutrition
        ↓ Confidence Boost: +20% (has CSV data)
        ↓ Result: Ready for CSV nutrition lookup
        
        🥗 GENERIC FOOD PROCESSING:
        
        Input: "grilled chicken"
        ↓ Generic Matcher: "chicken,_breast,_raw_2646170"
        ↓ ID Extractor: "2646170"
        ↓ Data Type: generic_food  
        ↓ Confidence Cap: max 70% (estimated)
        ↓ Result: Ready for nutrition estimation
        
        💾 CACHING LAYERS:
        
        - API Service: 24-hour food list cache (R-codes + generic)
        - Nutrition Engine: Match result cache by type
        - ID Extractor: R-code validation cache
        - Each component maintains type-aware caches
        
        🔧 ENHANCED CONFIGURATION:
        
        - API Base URL: https://meal-map-api-njio.onrender.com
        - R-code Priority: Restaurant matches get +20% confidence
        - Match Threshold: 0.3 minimum score
        - Restaurant Boost: R-codes get priority in ranking
        - Max Results: 10 per query with type distribution
        
        """)
    }
}

// MARK: - Demo Integration

extension MealMapExampleUsage {
    
    /// Integration point for HomeScreen quick demo (updated for R-codes)
    static func runQuickDemo() async {
        debugLog("🚀 Running MealMap Quick Demo (R-code Priority)...")
        
        let sampleItems = [
            ("mcdonalds", "Should match R0056"),
            ("subway", "Should match R0083"),
            ("grilled chicken", "Should match generic food")
        ]
        
        for (item, expectation) in sampleItems {
            do {
                let result = try await MealMapAPIService.shared.findNutritionMatch(for: item)
                if result.isAvailable {
                    let typeIcon = result.dataType.emoji
                    debugLog("✅ \(typeIcon) '\(item)' → Match found (ID: \(result.extractedID), score: \(String(format: "%.2f", result.matchScore))) - \(expectation)")
                } else {
                    debugLog("❌ '\(item)' → No match - \(expectation)")
                }
            } catch {
                debugLog("💥 '\(item)' → Error: \(error.localizedDescription)")
            }
        }
        
        debugLog("🎯 Quick demo complete! R-codes prioritized for restaurant nutrition data.")
    }
}