import Foundation

// MARK: - Ingredient Database
struct IngredientDatabase {
    
    // MARK: - Ingredient Matching
    static func findIngredients(in text: String) -> [IngredientMatch] {
        let lowercaseText = text.lowercased()
        var matches: [IngredientMatch] = []
        
        // Search through ingredient database
        for ingredient in ingredientList {
            for keyword in ingredient.keywords {
                if lowercaseText.contains(keyword) {
                    let confidence = calculateConfidence(keyword: keyword, in: lowercaseText, ingredient: ingredient)
                    let match = IngredientMatch(
                        name: ingredient.name,
                        category: ingredient.category,
                        confidence: confidence
                    )
                    matches.append(match)
                    break // Only add once per ingredient
                }
            }
        }
        
        return matches.sorted { $0.confidence > $1.confidence }
    }
    
    static func getNutritionData(for ingredientName: String) -> NutritionContribution? {
        return nutritionDatabase[ingredientName.lowercased()]
    }
    
    // MARK: - Confidence Calculation
    private static func calculateConfidence(keyword: String, in text: String, ingredient: IngredientInfo) -> Double {
        var confidence: Double = 0.5 // Base confidence
        
        // Exact match gets highest confidence
        if text.contains(" \(keyword) ") || text.hasPrefix("\(keyword) ") || text.hasSuffix(" \(keyword)") {
            confidence = 0.9
        } else if text.contains(keyword) {
            confidence = 0.7
        }
        
        // Adjust based on keyword specificity
        if keyword.count >= 6 { // Longer keywords are more specific
            confidence += 0.1
        }
        
        // Category-based adjustments
        switch ingredient.category {
        case .protein:
            if text.contains("protein") || text.contains("meat") {
                confidence += 0.1
            }
        case .vegetable:
            if text.contains("fresh") || text.contains("organic") {
                confidence += 0.1
            }
        case .carbohydrate:
            if text.contains("bread") || text.contains("pasta") {
                confidence += 0.1
            }
        default:
            break
        }
        
        return min(confidence, 1.0)
    }
}

// MARK: - Data Models
struct IngredientMatch {
    let name: String
    let category: IngredientCategory
    let confidence: Double
}

struct IngredientInfo {
    let name: String
    let category: IngredientCategory
    let keywords: [String]
    let commonNames: [String]
}

// MARK: - Ingredient Database
extension IngredientDatabase {
    
    static let ingredientList: [IngredientInfo] = [
        // Proteins
        IngredientInfo(name: "chicken", category: .protein, keywords: ["chicken", "poultry", "grilled chicken", "fried chicken"], commonNames: ["chicken breast", "chicken thigh"]),
        IngredientInfo(name: "beef", category: .protein, keywords: ["beef", "steak", "ground beef", "burger", "patty"], commonNames: ["sirloin", "ribeye", "ground chuck"]),
        IngredientInfo(name: "pork", category: .protein, keywords: ["pork", "bacon", "ham", "sausage", "pork chop"], commonNames: ["pork loin", "pork belly"]),
        IngredientInfo(name: "fish", category: .protein, keywords: ["fish", "salmon", "tuna", "cod", "tilapia", "mahi"], commonNames: ["grilled fish", "fried fish"]),
        IngredientInfo(name: "shrimp", category: .protein, keywords: ["shrimp", "prawns", "scampi"], commonNames: ["grilled shrimp", "fried shrimp"]),
        IngredientInfo(name: "eggs", category: .protein, keywords: ["egg", "eggs", "scrambled", "fried egg", "omelette"], commonNames: ["whole eggs", "egg whites"]),
        IngredientInfo(name: "tofu", category: .protein, keywords: ["tofu", "soy", "tempeh"], commonNames: ["silken tofu", "firm tofu"]),
        IngredientInfo(name: "beans", category: .protein, keywords: ["beans", "black beans", "kidney beans", "chickpeas", "lentils"], commonNames: ["pinto beans", "navy beans"]),
        
        // Vegetables
        IngredientInfo(name: "lettuce", category: .vegetable, keywords: ["lettuce", "greens", "salad", "mixed greens"], commonNames: ["romaine", "iceberg"]),
        IngredientInfo(name: "tomato", category: .vegetable, keywords: ["tomato", "tomatoes", "cherry tomatoes"], commonNames: ["roma tomato", "beefsteak tomato"]),
        IngredientInfo(name: "onion", category: .vegetable, keywords: ["onion", "onions", "red onion", "white onion"], commonNames: ["yellow onion", "sweet onion"]),
        IngredientInfo(name: "bell pepper", category: .vegetable, keywords: ["pepper", "bell pepper", "peppers"], commonNames: ["red pepper", "green pepper"]),
        IngredientInfo(name: "mushrooms", category: .vegetable, keywords: ["mushroom", "mushrooms", "shiitake", "portobello"], commonNames: ["white mushroom", "cremini"]),
        IngredientInfo(name: "spinach", category: .vegetable, keywords: ["spinach", "baby spinach"], commonNames: ["fresh spinach", "wilted spinach"]),
        IngredientInfo(name: "broccoli", category: .vegetable, keywords: ["broccoli"], commonNames: ["steamed broccoli", "roasted broccoli"]),
        IngredientInfo(name: "carrots", category: .vegetable, keywords: ["carrot", "carrots"], commonNames: ["baby carrots", "shredded carrots"]),
        IngredientInfo(name: "cucumber", category: .vegetable, keywords: ["cucumber", "cucumbers"], commonNames: ["english cucumber", "pickle"]),
        IngredientInfo(name: "avocado", category: .fat, keywords: ["avocado", "avocados", "guacamole"], commonNames: ["fresh avocado", "sliced avocado"]),
        
        // Carbohydrates
        IngredientInfo(name: "bread", category: .carbohydrate, keywords: ["bread", "bun", "roll", "baguette", "sourdough"], commonNames: ["whole wheat", "white bread"]),
        IngredientInfo(name: "pasta", category: .carbohydrate, keywords: ["pasta", "spaghetti", "penne", "linguine", "fettuccine"], commonNames: ["angel hair", "rigatoni"]),
        IngredientInfo(name: "rice", category: .carbohydrate, keywords: ["rice", "brown rice", "white rice", "jasmine rice"], commonNames: ["basmati rice", "wild rice"]),
        IngredientInfo(name: "potato", category: .carbohydrate, keywords: ["potato", "potatoes", "fries", "mashed potatoes"], commonNames: ["russet potato", "sweet potato"]),
        IngredientInfo(name: "quinoa", category: .grain, keywords: ["quinoa"], commonNames: ["tri-color quinoa", "red quinoa"]),
        IngredientInfo(name: "tortilla", category: .carbohydrate, keywords: ["tortilla", "wrap", "flour tortilla"], commonNames: ["corn tortilla", "whole wheat tortilla"]),
        
        // Dairy
        IngredientInfo(name: "cheese", category: .dairy, keywords: ["cheese", "cheddar", "mozzarella", "parmesan", "swiss"], commonNames: ["aged cheese", "fresh cheese"]),
        IngredientInfo(name: "milk", category: .dairy, keywords: ["milk", "cream", "half and half"], commonNames: ["whole milk", "skim milk"]),
        IngredientInfo(name: "yogurt", category: .dairy, keywords: ["yogurt", "greek yogurt"], commonNames: ["plain yogurt", "vanilla yogurt"]),
        IngredientInfo(name: "butter", category: .fat, keywords: ["butter", "garlic butter"], commonNames: ["unsalted butter", "herb butter"]),
        
        // Fruits
        IngredientInfo(name: "apple", category: .fruit, keywords: ["apple", "apples"], commonNames: ["granny smith", "red apple"]),
        IngredientInfo(name: "banana", category: .fruit, keywords: ["banana", "bananas"], commonNames: ["ripe banana", "green banana"]),
        IngredientInfo(name: "berries", category: .fruit, keywords: ["berry", "berries", "strawberry", "blueberry", "raspberry"], commonNames: ["mixed berries", "fresh berries"]),
        IngredientInfo(name: "orange", category: .fruit, keywords: ["orange", "oranges", "citrus"], commonNames: ["navel orange", "blood orange"]),
        
        // Fats/Oils
        IngredientInfo(name: "olive oil", category: .fat, keywords: ["olive oil", "evoo", "extra virgin"], commonNames: ["virgin olive oil", "light olive oil"]),
        IngredientInfo(name: "vegetable oil", category: .fat, keywords: ["oil", "vegetable oil", "canola oil"], commonNames: ["cooking oil", "neutral oil"]),
        IngredientInfo(name: "nuts", category: .fat, keywords: ["nuts", "almonds", "walnuts", "pecans", "peanuts"], commonNames: ["mixed nuts", "chopped nuts"]),
        
        // Sauces/Condiments
        IngredientInfo(name: "marinara", category: .sauce, keywords: ["marinara", "tomato sauce", "pasta sauce"], commonNames: ["red sauce", "pizza sauce"]),
        IngredientInfo(name: "mayo", category: .sauce, keywords: ["mayo", "mayonnaise", "aioli"], commonNames: ["light mayo", "garlic aioli"]),
        IngredientInfo(name: "mustard", category: .sauce, keywords: ["mustard", "dijon"], commonNames: ["yellow mustard", "whole grain mustard"]),
        IngredientInfo(name: "ketchup", category: .sauce, keywords: ["ketchup", "catsup"], commonNames: ["tomato ketchup", "organic ketchup"]),
        IngredientInfo(name: "ranch", category: .sauce, keywords: ["ranch", "ranch dressing"], commonNames: ["buttermilk ranch", "light ranch"]),
        IngredientInfo(name: "vinaigrette", category: .sauce, keywords: ["vinaigrette", "balsamic", "italian dressing"], commonNames: ["house vinaigrette", "herb vinaigrette"]),
        
        // Spices/Seasonings
        IngredientInfo(name: "salt", category: .spice, keywords: ["salt", "sea salt", "kosher salt"], commonNames: ["table salt", "himalayan salt"]),
        IngredientInfo(name: "pepper", category: .spice, keywords: ["pepper", "black pepper"], commonNames: ["white pepper", "cracked pepper"]),
        IngredientInfo(name: "garlic", category: .spice, keywords: ["garlic", "garlic powder", "minced garlic"], commonNames: ["fresh garlic", "roasted garlic"]),
        IngredientInfo(name: "herbs", category: .spice, keywords: ["herbs", "basil", "oregano", "thyme", "rosemary", "parsley"], commonNames: ["fresh herbs", "dried herbs"])
    ]
    
    // MARK: - Nutrition Database
    static let nutritionDatabase: [String: NutritionContribution] = [
        // Proteins (per 4oz serving)
        "chicken": NutritionContribution(calories: 185, carbs: 0, protein: 35, fat: 4, confidence: 0.8),
        "beef": NutritionContribution(calories: 250, carbs: 0, protein: 26, fat: 15, confidence: 0.8),
        "pork": NutritionContribution(calories: 220, carbs: 0, protein: 25, fat: 12, confidence: 0.8),
        "fish": NutritionContribution(calories: 150, carbs: 0, protein: 30, fat: 3, confidence: 0.8),
        "shrimp": NutritionContribution(calories: 120, carbs: 1, protein: 23, fat: 1.5, confidence: 0.8),
        "eggs": NutritionContribution(calories: 70, carbs: 0.5, protein: 6, fat: 5, confidence: 0.9),
        "tofu": NutritionContribution(calories: 80, carbs: 2, protein: 8, fat: 4.5, confidence: 0.8),
        "beans": NutritionContribution(calories: 110, carbs: 20, protein: 8, fat: 0.5, confidence: 0.8),
        
        // Vegetables (per cup)
        "lettuce": NutritionContribution(calories: 10, carbs: 2, protein: 1, fat: 0, confidence: 0.9),
        "tomato": NutritionContribution(calories: 30, carbs: 7, protein: 1.5, fat: 0, confidence: 0.9),
        "onion": NutritionContribution(calories: 40, carbs: 9, protein: 1, fat: 0, confidence: 0.9),
        "bell pepper": NutritionContribution(calories: 25, carbs: 6, protein: 1, fat: 0, confidence: 0.9),
        "mushrooms": NutritionContribution(calories: 15, carbs: 3, protein: 2, fat: 0, confidence: 0.9),
        "spinach": NutritionContribution(calories: 7, carbs: 1, protein: 1, fat: 0, confidence: 0.9),
        "broccoli": NutritionContribution(calories: 25, carbs: 5, protein: 3, fat: 0, confidence: 0.9),
        "carrots": NutritionContribution(calories: 50, carbs: 12, protein: 1, fat: 0, confidence: 0.9),
        "cucumber": NutritionContribution(calories: 15, carbs: 4, protein: 1, fat: 0, confidence: 0.9),
        "avocado": NutritionContribution(calories: 320, carbs: 17, protein: 4, fat: 29, confidence: 0.9),
        
        // Carbohydrates (per serving)
        "bread": NutritionContribution(calories: 80, carbs: 15, protein: 3, fat: 1, confidence: 0.8),
        "pasta": NutritionContribution(calories: 220, carbs: 44, protein: 8, fat: 1, confidence: 0.8),
        "rice": NutritionContribution(calories: 205, carbs: 45, protein: 4, fat: 0.5, confidence: 0.8),
        "potato": NutritionContribution(calories: 160, carbs: 37, protein: 4, fat: 0, confidence: 0.8),
        "quinoa": NutritionContribution(calories: 220, carbs: 39, protein: 8, fat: 4, confidence: 0.8),
        "tortilla": NutritionContribution(calories: 150, carbs: 26, protein: 4, fat: 4, confidence: 0.8),
        
        // Dairy (per serving)
        "cheese": NutritionContribution(calories: 110, carbs: 1, protein: 7, fat: 9, confidence: 0.8),
        "milk": NutritionContribution(calories: 150, carbs: 12, protein: 8, fat: 8, confidence: 0.9),
        "yogurt": NutritionContribution(calories: 100, carbs: 6, protein: 17, fat: 0, confidence: 0.8),
        "butter": NutritionContribution(calories: 100, carbs: 0, protein: 0, fat: 11, confidence: 0.9),
        
        // Fruits (per medium fruit)
        "apple": NutritionContribution(calories: 95, carbs: 25, protein: 0.5, fat: 0, confidence: 0.9),
        "banana": NutritionContribution(calories: 105, carbs: 27, protein: 1, fat: 0, confidence: 0.9),
        "berries": NutritionContribution(calories: 60, carbs: 15, protein: 1, fat: 0.5, confidence: 0.8),
        "orange": NutritionContribution(calories: 65, carbs: 16, protein: 1, fat: 0, confidence: 0.9),
        
        // Fats/Oils (per tablespoon)
        "olive oil": NutritionContribution(calories: 120, carbs: 0, protein: 0, fat: 14, confidence: 0.9),
        "vegetable oil": NutritionContribution(calories: 120, carbs: 0, protein: 0, fat: 14, confidence: 0.9),
        "nuts": NutritionContribution(calories: 160, carbs: 6, protein: 6, fat: 14, confidence: 0.8),
        
        // Sauces (per tablespoon)
        "marinara": NutritionContribution(calories: 20, carbs: 4, protein: 1, fat: 0, confidence: 0.7),
        "mayo": NutritionContribution(calories: 90, carbs: 0, protein: 0, fat: 10, confidence: 0.9),
        "mustard": NutritionContribution(calories: 5, carbs: 1, protein: 0, fat: 0, confidence: 0.9),
        "ketchup": NutritionContribution(calories: 15, carbs: 4, protein: 0, fat: 0, confidence: 0.9),
        "ranch": NutritionContribution(calories: 70, carbs: 1, protein: 0, fat: 7, confidence: 0.8),
        "vinaigrette": NutritionContribution(calories: 45, carbs: 2, protein: 0, fat: 4, confidence: 0.7)
    ]
}