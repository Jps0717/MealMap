import Foundation

// MARK: - USDA API Example Queries and Demo
struct USDAExampleQueries {
    
    /// Example query for "Chocolate Chip Cookie"
    static func demonstrateChocolateChipCookieQuery() {
        let example = """
        
        🍪 USDA API Example: Chocolate Chip Cookie
        
        1. SEARCH REQUEST:
        GET https://api.nal.usda.gov/fdc/v1/foods/search?query=chocolate%20chip%20cookie&dataType=Foundation,SR%20Legacy&pageSize=10&api_key=DEMO_KEY
        
        2. SEARCH RESPONSE (Sample):
        {
          "foods": [
            {
              "fdcId": 167512,
              "description": "Cookies, chocolate chip, commercially prepared, regular, higher fat, enriched",
              "dataType": "SR Legacy",
              "score": 847.3
            },
            {
              "fdcId": 168192,
              "description": "Cookies, chocolate chip, prepared from recipe, made with butter",
              "dataType": "SR Legacy", 
              "score": 832.1
            },
            {
              "fdcId": 168193,
              "description": "Cookies, chocolate chip, prepared from recipe, made with margarine",
              "dataType": "SR Legacy",
              "score": 810.2
            }
          ],
          "totalHits": 18,
          "currentPage": 1,
          "totalPages": 2
        }
        
        3. DETAILED NUTRITION REQUEST:
        GET https://api.nal.usda.gov/fdc/v1/food/167512?api_key=DEMO_KEY
        
        4. NUTRITION RESPONSE (Key nutrients):
        {
          "fdcId": 167512,
          "description": "Cookies, chocolate chip, commercially prepared, regular, higher fat, enriched",
          "foodNutrients": [
            {
              "nutrient": {"id": 1008, "number": "208", "name": "Energy"},
              "amount": 488.0,
              "unitName": "kcal"
            },
            {
              "nutrient": {"id": 1005, "number": "205", "name": "Carbohydrate, by difference"},
              "amount": 68.29,
              "unitName": "g"
            },
            {
              "nutrient": {"id": 1003, "number": "203", "name": "Protein"},
              "amount": 5.85,
              "unitName": "g"
            },
            {
              "nutrient": {"id": 1004, "number": "204", "name": "Total lipid (fat)"},
              "amount": 20.73,
              "unitName": "g"
            },
            {
              "nutrient": {"id": 1079, "number": "291", "name": "Fiber, total dietary"},
              "amount": 2.4,
              "unitName": "g"
            },
            {
              "nutrient": {"id": 2000, "number": "269", "name": "Sugars, total including NLEA"},
              "amount": 36.58,
              "unitName": "g"
            },
            {
              "nutrient": {"id": 1093, "number": "307", "name": "Sodium, Na"},
              "amount": 366.0,
              "unitName": "mg"
            }
          ]
        }
        
        5. FINAL ESTIMATION RESULT:
        - Calories: 488-510 kcal (range from 3 matches)
        - Carbs: 65-70g
        - Protein: 5-7g  
        - Fat: 19-23g
        - Fiber: 2-3g
        - Sugar: 35-40g
        - Sodium: 350-400mg
        - Confidence: 70% (3 USDA matches)
        - Source: "Estimated from USDA database"
        - Warning: ⚠️ (generalized estimate)
        
        """
        
        print(example)
    }
    
    /// Example of system flow for menu item analysis
    static func demonstrateSystemFlow() {
        let example = """
        
        🔄 Three-Tier Nutrition Estimation System Flow
        
        MENU ITEM: "Tiramisu Tradizionale"
        
        TIER 1 - INGREDIENT ANALYSIS:
        ❌ OCR Text: "Tiramisu Tradizionale" 
        ❌ No clear ingredients identified in text
        ❌ Confidence < 50% → Move to Tier 2
        
        TIER 2 - USDA FALLBACK:
        📊 Normalize name: "tiramisu tradizionale" → "tiramisu"
        📊 USDA Search: Found 3 matches
           - "Desserts, tiramisu, prepared-from-recipe"
           - "Restaurant, Italian, tiramisu"  
           - "Tiramisu, commercial"
        📊 Nutrition range calculated from 3 matches
        ✅ Confidence: 60% → Success!
        
        RESULT:
        🍰 Name: "Tiramisu Tradizionale"
        ⚠️ Source: USDA Database (3 matches)
        📊 Calories: 240-280 kcal (est.)
        📊 Carbs: 25-30g (est.)
        📊 Protein: 4-6g (est.)
        📊 Fat: 15-18g (est.)
        🏷️ Tags: [Indulgent, High Carb]
        
        UI DISPLAY:
        - Warning icon ⚠️ next to item name
        - "Estimated from USDA database" label
        - Nutrition ranges instead of single values
        - User feedback options available
        
        """
        
        print(example)
    }
    
    /// Example of failed analysis
    static func demonstrateFailureCase() {
        let example = """
        
        ❌ Tier 3 - No Nutrition Available Example
        
        MENU ITEM: "Chef's Special Mystery Dish"
        
        TIER 1 - INGREDIENT ANALYSIS:
        ❌ No identifiable ingredients in OCR text
        
        TIER 2 - USDA FALLBACK:  
        ❌ Normalized: "chef special mystery dish"
        ❌ USDA Search: No matches found
        ❌ Too generic/unique for database lookup
        
        TIER 3 - UNAVAILABLE:
        📝 Create item with no nutrition data
        
        RESULT:
        🍽️ Name: "Chef's Special Mystery Dish"
        🚫 Source: Nutrition Unavailable
        ⚠️ "Nutrition information not available"
        🎯 User can still mark dietary preferences manually
        
        """
        
        print(example)
    }
}

// MARK: - Integration Example
extension MenuOCRService {
    
    /// Demo function showing the complete integration
    func demonstrateUSDAIntegration() async {
        print("🚀 Starting USDA Integration Demo...")
        
        // Create sample raw menu items
        let sampleItems = [
            RawMenuItem(
                name: "Chocolate Chip Cookie",
                description: "Fresh baked with premium chocolate",
                price: "$3.99",
                section: "Desserts",
                bounds: CGRect.zero,
                confidence: 0.8
            ),
            RawMenuItem(
                name: "Tiramisu Tradizionale", 
                description: "Classic Italian dessert",
                price: "$8.99",
                section: "Desserts",
                bounds: CGRect.zero,
                confidence: 0.7
            ),
            RawMenuItem(
                name: "Chef's Mysterious Special",
                description: "Ask your server",
                price: "Market Price",
                section: "Specials",
                bounds: CGRect.zero,
                confidence: 0.6
            )
        ]
        
        print("📋 Processing \(sampleItems.count) sample menu items...")
        
        do {
            let analyzedItems = try await analyzeMenuItemsBatch(sampleItems)
            
            print("\n📊 ANALYSIS RESULTS:")
            for item in analyzedItems {
                print("""
                
                🍽️ \(item.name)
                📍 Tier: \(item.estimationTier.displayName)
                🎯 Confidence: \(Int(item.confidence * 100))%
                🥗 Calories: \(item.nutritionEstimate.calories.displayString)
                📋 Tags: \(item.dietaryTags.map { $0.displayName }.joined(separator: ", "))
                """)
            }
            
        } catch {
            print("❌ Demo failed: \(error)")
        }
    }
}