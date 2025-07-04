import Foundation

// MARK: - USDA-Only System Examples and Testing
struct USDAOnlyExamples {
    
    // MARK: - Example 1: "w/Fresh Turkey" → "turkey"
    static func demonstrateFreshTurkeyExample() {
        let example = """
        
        EXAMPLE: "w/Fresh Turkey" → "turkey"
        
        INPUT: Raw OCR text "w/Fresh Turkey"
        
        CLEANING PIPELINE:
        1. Remove prefixes: "w/Fresh Turkey" → "Turkey" (remove "w/" and "fresh")
        2. Clean OCR errors: "Turkey" (valid, >4 chars)
        3. Apply aliases: "Turkey" → "turkey" (lowercase)
        4. Final cleaned name: "turkey"
        
        USDA API QUERY:
        GET /foods/search?query=turkey&dataType=Foundation,SR%20Legacy&pageSize=20
        
        SAMPLE USDA MATCHES:
        1. "Turkey, all classes, meat only, cooked" - 189 cal, 0g carbs, 29g protein, 7g fat
        2. "Turkey, breast, meat only, roasted" - 135 cal, 0g carbs, 30g protein, 1g fat
        3. "Turkey, ground, cooked" - 200 cal, 0g carbs, 27g protein, 8g fat
        
        FINAL RESULT:
        Original Name: "w/Fresh Turkey"
        Cleaned Name: "turkey"
        Calories: 135-200 kcal (est.)
        Carbs: 0-0g (est.)
        Sugar: 0-0g (est.)
        Protein: 27-30g (est.)
        Fat: 1-8g (est.)
        Confidence: 70% (3 USDA matches)
        isGeneralEstimate: true
        Tags: [High Protein, Low Carb]
        
        """
        print(example)
    }
    
    // MARK: - Example 2: "ddar" → Rejected
    static func demonstrateOCRGarbageExample() {
        let example = """
        
        EXAMPLE: "ddar" → REJECTED
        
        INPUT: Raw OCR text "ddar"
        
        CLEANING PIPELINE:
        1. Remove prefixes: "ddar" (no prefixes to remove)
        2. Clean OCR errors: "ddar" (valid characters)
        3. Apply aliases: "ddar" (no aliases match)
        4. Validation: "ddar" → REJECTED (OCR garbage pattern)
        
        REJECTION REASONS:
        - Matches known OCR garbage pattern "ddar"
        - Not a recognizable food name
        - Would waste USDA API call
        
        FINAL RESULT:
        Status: Nutrition Unavailable
        Reason: Invalid menu item name after cleaning
        No USDA query performed
        
        """
        print(example)
    }
    
    // MARK: - Example 3: "Crostatine" → "tart"
    static func demonstrateCrostatineExample() {
        let example = """
        
        EXAMPLE: "Crostatine" → "tart"
        
        INPUT: Raw OCR text "Crostatine"
        
        CLEANING PIPELINE:
        1. Remove prefixes: "Crostatine" (no prefixes to remove)
        2. Clean OCR errors: "crostatine" (lowercase)
        3. Apply aliases: "crostatine" → "tart" (Italian → English)
        4. Final cleaned name: "tart"
        
        USDA API QUERY:
        GET /foods/search?query=tart&dataType=Foundation,SR%20Legacy&pageSize=20
        
        SAMPLE USDA MATCHES:
        1. "Desserts, tart, fruit" - 258 cal, 37g carbs, 3g protein, 11g fat
        2. "Tart, custard, commercially prepared" - 262 cal, 33g carbs, 6g protein, 12g fat
        3. "Pastries, tart shell, baked" - 498 cal, 54g carbs, 6g protein, 28g fat
        
        FINAL RESULT:
        Original Name: "Crostatine"
        Cleaned Name: "tart"
        Calories: 258-498 kcal (est.)
        Carbs: 33-54g (est.)
        Sugar: 15-25g (est.)
        Protein: 3-6g (est.)
        Fat: 11-28g (est.)
        Confidence: 70% (3 USDA matches)
        isGeneralEstimate: true
        Tags: [High Carb, Indulgent]
        
        """
        print(example)
    }
    
    // MARK: - Example 4: "Tiramisu Tradizionale" → "tiramisu"
    static func demonstrateTiramisuExample() {
        let example = """
        
        EXAMPLE: "Tiramisu Tradizionale" → "tiramisu"
        
        INPUT: Raw OCR text "Tiramisu Tradizionale"
        
        CLEANING PIPELINE:
        1. Remove prefixes: "Tiramisu Tradizionale" (no prefixes to remove)
        2. Clean OCR errors: "tiramisu tradizionale" (lowercase)
        3. Apply aliases: "tiramisu tradizionale" → "tiramisu" (remove "tradizionale")
        4. Final cleaned name: "tiramisu"
        
        USDA API QUERY:
        GET /foods/search?query=tiramisu&dataType=Foundation,SR%20Legacy&pageSize=20
        
        SAMPLE USDA MATCHES:
        1. "Desserts, tiramisu, prepared-from-recipe" - 240 cal, 20g carbs, 4g protein, 16g fat
        2. "Restaurant, Italian, tiramisu" - 420 cal, 31g carbs, 8g protein, 30g fat
        
        FINAL RESULT:
        Original Name: "Tiramisu Tradizionale"
        Cleaned Name: "tiramisu"
        Calories: 240-420 kcal (est.)
        Carbs: 20-31g (est.)
        Sugar: 18-25g (est.)
        Protein: 4-8g (est.)
        Fat: 16-30g (est.)
        Confidence: 60% (2 USDA matches)
        isGeneralEstimate: true
        Tags: [High Carb, Indulgent]
        
        """
        print(example)
    }
    
    // MARK: - Comprehensive System Flow
    static func printUSDAOnlySystemFlow() {
        let flow = """
        
        USDA-ONLY SYSTEM FLOW (NO INGREDIENTS)
        
        Raw OCR Text
              ↓
        ┌─────────────────────┐
        │   MENU CLEANING     │
        │                     │
        │ 1. Split composite  │
        │    items (|, &)     │
        │ 2. Remove pricing   │
        │    ($12.99, 25)     │
        │ 3. Strip prefixes   │
        │    (w/, with, fresh)│
        │ 4. Clean OCR errors │
        │    (non-alphabetic) │
        │ 5. Apply aliases    │
        │    (crostatine→tart)│
        │ 6. Validate names   │
        │    (>4 chars, etc.) │
        └─────────────────────┘
              ↓
        Cleaned Name(s)
              ↓
        ┌─────────────────────┐
        │   USDA API ONLY     │
        │                     │
        │ NO INGREDIENTS     │
        │ NO PARSING         │
        │                     │
        │ Name → USDA API  │
        │ Get macros only  │
        │ Calculate ranges │
        │ Cache results    │
        └─────────────────────┘
              ↓
        ┌─────────────────────┐
        │    USDA RESULT      │
        │                     │
        │ Calories Range   │
        │ Carbs Range      │
        │ Sugar Range      │
        │ Protein Range    │
        │ Fat Range        │
        │  General Estimate│
        │ Confidence Score │
        │                     │
        │ OR                  │
        │                     │
        │ Unavailable      │
        └─────────────────────┘
              ↓
        Menu Analysis Result
        (NO ingredient data)
        
        """
        print(flow)
    }
}

// MARK: - Demo Integration
extension USDANutritionEngine {
    
    /// Demo function showing the complete USDA-only system
    func demonstrateUSDAOnlySystem() async {
        print("USDA-Only System Demo (NO INGREDIENTS)")
        print(String(repeating: "=", count: 50))
        
        let testItems = [
            "w/Fresh Turkey",      // Should clean to "turkey"
            "ddar",                // Should be rejected
            "Crostatine",          // Should map to "tart"
            "Tiramisu Tradizionale", // Should map to "tiramisu"
            "w/Hummus 25 | w/Chicken 28", // Should split and process
            "ing"                  // Should be rejected (OCR garbage)
        ]
        
        for item in testItems {
            print("\nTesting: '\(item)'")
            print(String(repeating: "-", count: 30))
            
            do {
                let result = try await analyzeMenuItem(item)
                
                if result.isAvailable {
                    print("SUCCESS:")
                    print("   Original: '\(result.originalName)'")
                    print("   Cleaned: '\(result.cleanedName)'")
                    print("   Calories: \(result.nutrition.calories.displayString)")
                    print("   Carbs: \(result.nutrition.carbs.displayString)")
                    print("   Protein: \(result.nutrition.protein.displayString)")
                    print("   Fat: \(result.nutrition.fat.displayString)")
                    print("   Confidence: \(Int(result.confidence * 100))%")
                    print("   USDA Matches: \(result.matchCount)")
                } else {
                    print("UNAVAILABLE:")
                    print("   Original: '\(result.originalName)'")
                    print("   Reason: No valid food name after cleaning")
                }
                
            } catch {
                print("ERROR: \(error.localizedDescription)")
            }
        }
        
        print("\nDemo Complete!")
        print("\nSUMMARY:")
        print("- NO ingredient analysis performed")
        print("- Nutrition based purely on USDA food names")
        print("- Intelligent name cleaning and aliases")
        print("- Clear visual indicators for estimates")
        print("- Robust error handling for invalid names")
    }
}