import Foundation

/// Static nutrition data as emergency fallback when all APIs fail
struct StaticNutritionData {
    
    /// Get static nutrition data for popular restaurants
    static func getStaticNutritionData(for restaurantName: String) -> RestaurantNutritionData? {
        let normalizedName = RestaurantData.normalizeRestaurantName(restaurantName)
        
        switch normalizedName {
        case "mcdonalds":
            return RestaurantNutritionData(
                restaurantName: "McDonald's",
                items: [
                    NutritionData(item: "Big Mac", calories: 550, fat: 33, saturatedFat: 11, cholesterol: 80, sodium: 1010, carbs: 45, fiber: 3, sugar: 9, protein: 25),
                    NutritionData(item: "Quarter Pounder with Cheese", calories: 520, fat: 26, saturatedFat: 13, cholesterol: 90, sodium: 1120, carbs: 42, fiber: 3, sugar: 10, protein: 30),
                    NutritionData(item: "Chicken McNuggets (10 piece)", calories: 420, fat: 25, saturatedFat: 4, cholesterol: 65, sodium: 900, carbs: 25, fiber: 1, sugar: 0, protein: 23),
                    NutritionData(item: "Medium French Fries", calories: 320, fat: 15, saturatedFat: 2, cholesterol: 0, sodium: 230, carbs: 43, fiber: 4, sugar: 0, protein: 4),
                    NutritionData(item: "McChicken", calories: 400, fat: 22, saturatedFat: 4, cholesterol: 40, sodium: 590, carbs: 40, fiber: 2, sugar: 5, protein: 14),
                    NutritionData(item: "Filet-O-Fish", calories: 380, fat: 18, saturatedFat: 4, cholesterol: 40, sodium: 580, carbs: 38, fiber: 2, sugar: 5, protein: 15),
                    NutritionData(item: "Egg McMuffin", calories: 300, fat: 12, saturatedFat: 6, cholesterol: 245, sodium: 760, carbs: 30, fiber: 2, sugar: 3, protein: 17),
                    NutritionData(item: "Hotcakes (3 piece)", calories: 320, fat: 7, saturatedFat: 2, cholesterol: 20, sodium: 590, carbs: 60, fiber: 2, sugar: 14, protein: 8),
                    NutritionData(item: "Apple Pie", calories: 230, fat: 10, saturatedFat: 5, cholesterol: 0, sodium: 100, carbs: 32, fiber: 4, sugar: 13, protein: 2),
                    NutritionData(item: "Vanilla Cone", calories: 200, fat: 5, saturatedFat: 3, cholesterol: 20, sodium: 80, carbs: 32, fiber: 0, sugar: 26, protein: 5)
                ]
            )
            
        case "subway":
            return RestaurantNutritionData(
                restaurantName: "Subway",
                items: [
                    NutritionData(item: "Turkey Breast (6\")", calories: 280, fat: 3.5, saturatedFat: 1, cholesterol: 20, sodium: 810, carbs: 46, fiber: 5, sugar: 8, protein: 18),
                    NutritionData(item: "Italian BMT (6\")", calories: 410, fat: 16, saturatedFat: 6, cholesterol: 55, sodium: 1260, carbs: 44, fiber: 5, sugar: 8, protein: 19),
                    NutritionData(item: "Meatball Marinara (6\")", calories: 480, fat: 18, saturatedFat: 8, cholesterol: 45, sodium: 1560, carbs: 61, fiber: 7, sugar: 13, protein: 21),
                    NutritionData(item: "Chicken Teriyaki (6\")", calories: 370, fat: 5, saturatedFat: 1.5, cholesterol: 50, sodium: 1110, carbs: 59, fiber: 5, sugar: 16, protein: 25),
                    NutritionData(item: "Tuna (6\")", calories: 480, fat: 25, saturatedFat: 4.5, cholesterol: 40, sodium: 610, carbs: 44, fiber: 5, sugar: 8, protein: 20),
                    NutritionData(item: "Veggie Delite (6\")", calories: 230, fat: 2.5, saturatedFat: 0.5, cholesterol: 0, sodium: 280, carbs: 44, fiber: 5, sugar: 8, protein: 8),
                    NutritionData(item: "Steak & Cheese (6\")", calories: 380, fat: 10, saturatedFat: 5, cholesterol: 50, sodium: 1120, carbs: 45, fiber: 5, sugar: 8, protein: 23),
                    NutritionData(item: "Chicken & Bacon Ranch (6\")", calories: 540, fat: 31, saturatedFat: 10, cholesterol: 90, sodium: 1100, carbs: 46, fiber: 5, sugar: 8, protein: 25),
                    NutritionData(item: "Cold Cut Combo (6\")", calories: 340, fat: 12, saturatedFat: 4.5, cholesterol: 35, sodium: 1240, carbs: 45, fiber: 5, sugar: 8, protein: 14),
                    NutritionData(item: "Roast Beef (6\")", calories: 320, fat: 5, saturatedFat: 2, cholesterol: 30, sodium: 700, carbs: 45, fiber: 5, sugar: 8, protein: 19)
                ]
            )
            
        case "starbucks":
            return RestaurantNutritionData(
                restaurantName: "Starbucks",
                items: [
                    NutritionData(item: "Pike Place Roast (Grande)", calories: 5, fat: 0, saturatedFat: 0, cholesterol: 0, sodium: 10, carbs: 0, fiber: 0, sugar: 0, protein: 1),
                    NutritionData(item: "Caffe Latte (Grande)", calories: 190, fat: 7, saturatedFat: 4.5, cholesterol: 25, sodium: 150, carbs: 18, fiber: 0, sugar: 17, protein: 13),
                    NutritionData(item: "Caramel Macchiato (Grande)", calories: 250, fat: 7, saturatedFat: 4.5, cholesterol: 25, sodium: 150, carbs: 34, fiber: 0, sugar: 32, protein: 10),
                    NutritionData(item: "Frappuccino Coffee (Grande)", calories: 240, fat: 3, saturatedFat: 2, cholesterol: 5, sodium: 110, carbs: 50, fiber: 0, sugar: 47, protein: 4),
                    NutritionData(item: "Cappuccino (Grande)", calories: 120, fat: 4, saturatedFat: 2.5, cholesterol: 15, sodium: 95, carbs: 12, fiber: 0, sugar: 10, protein: 8),
                    NutritionData(item: "Americano (Grande)", calories: 15, fat: 0, saturatedFat: 0, cholesterol: 0, sodium: 10, carbs: 3, fiber: 0, sugar: 0, protein: 1),
                    NutritionData(item: "Green Tea Latte (Grande)", calories: 240, fat: 7, saturatedFat: 4.5, cholesterol: 25, sodium: 150, carbs: 32, fiber: 1, sugar: 31, protein: 13),
                    NutritionData(item: "Mocha (Grande)", calories: 290, fat: 8, saturatedFat: 5, cholesterol: 20, sodium: 150, carbs: 42, fiber: 2, sugar: 35, protein: 14),
                    NutritionData(item: "Vanilla Latte (Grande)", calories: 250, fat: 6, saturatedFat: 4, cholesterol: 25, sodium: 150, carbs: 37, fiber: 0, sugar: 35, protein: 12),
                    NutritionData(item: "Iced Coffee (Grande)", calories: 80, fat: 0, saturatedFat: 0, cholesterol: 0, sodium: 10, carbs: 20, fiber: 0, sugar: 16, protein: 2)
                ]
            )
            
        case "dunkin", "dunkindonuts":
            return RestaurantNutritionData(
                restaurantName: "Dunkin'",
                items: [
                    NutritionData(item: "Original Glazed Donut", calories: 260, fat: 14, saturatedFat: 6, cholesterol: 5, sodium: 330, carbs: 31, fiber: 1, sugar: 12, protein: 4),
                    NutritionData(item: "Boston Kreme Donut", calories: 300, fat: 16, saturatedFat: 7, cholesterol: 25, sodium: 360, carbs: 36, fiber: 1, sugar: 16, protein: 4),
                    NutritionData(item: "Chocolate Frosted Donut", calories: 280, fat: 16, saturatedFat: 7, cholesterol: 5, sodium: 350, carbs: 31, fiber: 2, sugar: 14, protein: 4),
                    NutritionData(item: "Hot Coffee (Medium)", calories: 5, fat: 0, saturatedFat: 0, cholesterol: 0, sodium: 5, carbs: 0, fiber: 0, sugar: 0, protein: 0),
                    NutritionData(item: "Iced Coffee (Medium)", calories: 15, fat: 0, saturatedFat: 0, cholesterol: 0, sodium: 5, carbs: 2, fiber: 0, sugar: 0, protein: 1),
                    NutritionData(item: "Latte (Medium)", calories: 120, fat: 6, saturatedFat: 4, cholesterol: 25, sodium: 115, carbs: 10, fiber: 0, sugar: 9, protein: 6),
                    NutritionData(item: "Cappuccino (Medium)", calories: 80, fat: 4, saturatedFat: 2.5, cholesterol: 15, sodium: 80, carbs: 7, fiber: 0, sugar: 6, protein: 4),
                    NutritionData(item: "Blueberry Muffin", calories: 460, fat: 15, saturatedFat: 3, cholesterol: 55, sodium: 520, carbs: 76, fiber: 2, sugar: 42, protein: 6),
                    NutritionData(item: "Everything Bagel", calories: 300, fat: 2, saturatedFat: 0.5, cholesterol: 0, sodium: 530, carbs: 59, fiber: 3, sugar: 8, protein: 12),
                    NutritionData(item: "Bacon Egg & Cheese Croissant", calories: 520, fat: 33, saturatedFat: 16, cholesterol: 215, sodium: 1090, carbs: 39, fiber: 2, sugar: 5, protein: 19)
                ]
            )
            
        case "tacobell":
            return RestaurantNutritionData(
                restaurantName: "Taco Bell",
                items: [
                    NutritionData(item: "Crunchy Taco", calories: 170, fat: 9, saturatedFat: 3.5, cholesterol: 25, sodium: 310, carbs: 13, fiber: 3, sugar: 1, protein: 8),
                    NutritionData(item: "Soft Taco", calories: 180, fat: 8, saturatedFat: 3.5, cholesterol: 25, sodium: 500, carbs: 18, fiber: 2, sugar: 2, protein: 9),
                    NutritionData(item: "Crunchwrap Supreme", calories: 540, fat: 21, saturatedFat: 7, cholesterol: 35, sodium: 1210, carbs: 71, fiber: 6, sugar: 6, protein: 16),
                    NutritionData(item: "Quesadilla (Cheese)", calories: 450, fat: 26, saturatedFat: 12, cholesterol: 50, sodium: 920, carbs: 40, fiber: 3, sugar: 4, protein: 17),
                    NutritionData(item: "Burrito Supreme", calories: 390, fat: 13, saturatedFat: 7, cholesterol: 40, sodium: 1090, carbs: 51, fiber: 8, sugar: 4, protein: 17),
                    NutritionData(item: "Chalupa Supreme", calories: 360, fat: 22, saturatedFat: 7, cholesterol: 35, sodium: 590, carbs: 30, fiber: 4, sugar: 5, protein: 13),
                    NutritionData(item: "Mexican Pizza", calories: 540, fat: 31, saturatedFat: 10, cholesterol: 45, sodium: 1040, carbs: 47, fiber: 7, sugar: 4, protein: 20),
                    NutritionData(item: "Nacho Fries", calories: 320, fat: 18, saturatedFat: 2.5, cholesterol: 0, sodium: 840, carbs: 35, fiber: 4, sugar: 0, protein: 5),
                    NutritionData(item: "Bean Burrito", calories: 350, fat: 9, saturatedFat: 3.5, cholesterol: 10, sodium: 1190, carbs: 54, fiber: 9, sugar: 4, protein: 14),
                    NutritionData(item: "Cinnamon Twists", calories: 170, fat: 7, saturatedFat: 1, cholesterol: 0, sodium: 200, carbs: 26, fiber: 1, sugar: 12, protein: 1)
                ]
            )
            
        case "chipotle":
            return RestaurantNutritionData(
                restaurantName: "Chipotle",
                items: [
                    NutritionData(item: "Chicken Burrito Bowl", calories: 630, fat: 24, saturatedFat: 8, cholesterol: 125, sodium: 1370, carbs: 40, fiber: 15, sugar: 4, protein: 58),
                    NutritionData(item: "Steak Burrito Bowl", calories: 650, fat: 25, saturatedFat: 9, cholesterol: 90, sodium: 1380, carbs: 40, fiber: 15, sugar: 4, protein: 58),
                    NutritionData(item: "Chicken Burrito", calories: 1040, fat: 35, saturatedFat: 13, cholesterol: 125, sodium: 2240, carbs: 123, fiber: 19, sugar: 4, protein: 63),
                    NutritionData(item: "Carnitas Burrito Bowl", calories: 620, fat: 23, saturatedFat: 8, cholesterol: 100, sodium: 1310, carbs: 40, fiber: 15, sugar: 4, protein: 54),
                    NutritionData(item: "Barbacoa Burrito Bowl", calories: 625, fat: 23, saturatedFat: 8, cholesterol: 105, sodium: 1530, carbs: 40, fiber: 15, sugar: 4, protein: 56),
                    NutritionData(item: "Sofritas Burrito Bowl", calories: 550, fat: 21, saturatedFat: 3, cholesterol: 0, sodium: 1110, carbs: 67, fiber: 20, sugar: 9, protein: 20),
                    NutritionData(item: "Chicken Tacos (3)", calories: 570, fat: 21, saturatedFat: 7, cholesterol: 125, sodium: 1370, carbs: 42, fiber: 3, sugar: 4, protein: 58),
                    NutritionData(item: "Guacamole", calories: 230, fat: 22, saturatedFat: 3, cholesterol: 0, sodium: 370, carbs: 8, fiber: 6, sugar: 1, protein: 3),
                    NutritionData(item: "Chips", calories: 570, fat: 27, saturatedFat: 4, cholesterol: 0, sodium: 420, carbs: 73, fiber: 8, sugar: 1, protein: 8),
                    NutritionData(item: "Brown Rice", calories: 210, fat: 4, saturatedFat: 1, cholesterol: 0, sodium: 310, carbs: 36, fiber: 4, sugar: 1, protein: 4)
                ]
            )
            
        case "pizzahut":
            return RestaurantNutritionData(
                restaurantName: "Pizza Hut",
                items: [
                    NutritionData(item: "Pepperoni Personal Pan Pizza", calories: 150, fat: 7, saturatedFat: 3, cholesterol: 15, sodium: 340, carbs: 14, fiber: 1, sugar: 1, protein: 6),
                    NutritionData(item: "Cheese Personal Pan Pizza", calories: 140, fat: 6, saturatedFat: 2.5, cholesterol: 10, sodium: 310, carbs: 15, fiber: 1, sugar: 2, protein: 6),
                    NutritionData(item: "Supreme Personal Pan Pizza", calories: 160, fat: 8, saturatedFat: 3, cholesterol: 20, sodium: 380, carbs: 15, fiber: 1, sugar: 2, protein: 7),
                    NutritionData(item: "Meat Lovers Personal Pan Pizza", calories: 180, fat: 10, saturatedFat: 4, cholesterol: 25, sodium: 440, carbs: 14, fiber: 1, sugar: 1, protein: 8),
                    NutritionData(item: "Veggie Lovers Personal Pan Pizza", calories: 130, fat: 5, saturatedFat: 2, cholesterol: 10, sodium: 300, carbs: 16, fiber: 1, sugar: 2, protein: 6),
                    NutritionData(item: "Buffalo Chicken Personal Pan Pizza", calories: 150, fat: 6, saturatedFat: 2.5, cholesterol: 20, sodium: 390, carbs: 15, fiber: 1, sugar: 2, protein: 8),
                    NutritionData(item: "Breadsticks (1 piece)", calories: 140, fat: 4, saturatedFat: 1, cholesterol: 0, sodium: 260, carbs: 23, fiber: 1, sugar: 2, protein: 4),
                    NutritionData(item: "Chicken Wings (2 pieces)", calories: 110, fat: 7, saturatedFat: 2, cholesterol: 50, sodium: 200, carbs: 1, fiber: 0, sugar: 0, protein: 11),
                    NutritionData(item: "Cinnamon Sticks (2 pieces)", calories: 170, fat: 4, saturatedFat: 1, cholesterol: 0, sodium: 340, carbs: 30, fiber: 1, sugar: 9, protein: 4),
                    NutritionData(item: "Garlic Parmesan Breadsticks", calories: 160, fat: 6, saturatedFat: 2, cholesterol: 5, sodium: 370, carbs: 22, fiber: 1, sugar: 2, protein: 6)
                ]
            )
            
        default:
            return nil
        }
    }
    
    /// Get list of restaurants that have static nutrition data
    static var availableRestaurants: [String] {
        return [
            "McDonald's",
            "Subway", 
            "Starbucks",
            "Dunkin'",
            "Taco Bell",
            "Chipotle",
            "Pizza Hut"
        ]
    }
    
    /// Check if a restaurant has static nutrition data available
    static func hasStaticData(for restaurantName: String) -> Bool {
        return getStaticNutritionData(for: restaurantName) != nil
    }
}