import Foundation

class NutritionDataManager: ObservableObject {
    @Published var isLoading = false
    @Published var currentRestaurantData: RestaurantNutritionData?
    @Published var errorMessage: String?
    
    private let restaurantMapping: [String: String] = [
        "7 Eleven": "R0000",
        "Applebee's": "R0001",
        "Arby's": "R0002",
        "Auntie Anne's": "R0003",
        "BJ's Restaurant & Brewhouse": "R0004",
        "Baskin Robbins": "R0005",
        "Bob Evans": "R0006",
        "Bojangles": "R0007",
        "Bonefish Grill": "R0008",
        "Boston Market": "R0009",
        "Burger King": "R0010",
        "California Pizza Kitchen": "R0011",
        "Captain D's": "R0012",
        "Carl's Jr.": "R0013",
        "Carrabba's Italian Grill": "R0014",
        "Casey's General Store": "R0015",
        "Checker's Drive-In/Rallys": "R0016",
        "Chick-Fil-A": "R0017",
        "Chick-fil-A": "R0018",
        "Chili's": "R0019",
        "Chipotle": "R0020",
        "Chuck E. Cheese": "R0021",
        "Church's Chicken": "R0022",
        "Ci Ci's Pizza": "R0023",
        "Culver's": "R0024",
        "Dairy Queen": "R0025",
        "Del Taco": "R0026",
        "Denny's": "R0027",
        "Dickey's Barbeque Pit": "R0028",
        "Domino's": "R0029",
        "Dunkin'": "R0030",
        "Einstein Bros": "R0031",
        "El Pollo Loco": "R0032",
        "Famous Dave's": "R0033",
        "Firehouse Subs": "R0034",
        "Five Guys": "R0035",
        "Friendly's": "R0036",
        "Frisch's Big Boy": "R0037",
        "Golden Corral": "R0038",
        "Hardee's": "R0039",
        "Hooters": "R0040",
        "IHOP": "R0041",
        "In-N-Out Burger": "R0042",
        "Jack in the Box": "R0043",
        "Jamba Juice": "R0044",
        "Jason's Deli": "R0045",
        "Jersey Mike's Subs": "R0046",
        "Joe's Crab Shack": "R0047",
        "KFC": "R0048",
        "Krispy Kreme": "R0049",
        "Krystal": "R0050",
        "Little Caesars": "R0051",
        "Long John Silver's": "R0052",
        "LongHorn Steakhouse": "R0053",
        "Marco's Pizza": "R0054",
        "McAlister's Deli": "R0055",
        "McDonald's": "R0056",
        "Moe's Southwest Grill": "R0057",
        "Noodles & Company": "R0058",
        "O'Charley's": "R0059",
        "Olive Garden": "R0060",
        "Outback Steakhouse": "R0061",
        "PF Chang's": "R0062",
        "Panda Express": "R0063",
        "Panera Bread": "R0064",
        "Papa John's": "R0065",
        "Papa Murphy's": "R0066",
        "Perkins": "R0067",
        "Pizza Hut": "R0068",
        "Popeyes": "R0069",
        "Potbelly Sandwich Shop": "R0070",
        "Qdoba": "R0071",
        "Quiznos": "R0072",
        "Red Lobster": "R0073",
        "Red Robin": "R0074",
        "Romano's Macaroni Grill": "R0075",
        "Round Table Pizza": "R0076",
        "Ruby Tuesday": "R0077",
        "Sbarro": "R0078",
        "Sheetz": "R0079",
        "Sonic": "R0080",
        "Starbucks": "R0081",
        "Steak 'N Shake": "R0082",
        "Subway": "R0083",
        "TGI Friday's": "R0084",
        "Taco Bell": "R0085",
        "The Capital Grille": "R0086",
        "Tim Hortons": "R0087",
        "Wawa": "R0088",
        "Wendy's": "R0089",
        "Whataburger": "R0090",
        "White Castle": "R0091",
        "Wingstop": "R0092",
        "Yard House": "R0093",
        "Zaxby's": "R0094"
    ]
    
    init() {
        print("Loaded \(restaurantMapping.count) restaurant mappings")
    }
    
    func loadNutritionData(for restaurantName: String) {
        guard let restaurantID = restaurantMapping[restaurantName] else {
            print("No nutrition data available for \(restaurantName)")
            errorMessage = "No nutrition data available for \(restaurantName)"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadNutritionDataAsync(restaurantName: restaurantName, restaurantID: restaurantID)
        }
    }
    
    private func loadNutritionDataAsync(restaurantName: String, restaurantID: String) {
        print("Attempting to load nutrition data for \(restaurantName) with ID \(restaurantID)")
        
        if let bundlePath = Bundle.main.resourcePath {
            print("Bundle path: \(bundlePath)")
            let fileManager = FileManager.default
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: bundlePath)
                print("Bundle contents: \(contents.prefix(5))")
            } catch {
                print("Could not list bundle contents: \(error)")
            }
        }
        
        // For now, let's hardcode McDonald's data as a test
        if restaurantName == "McDonald's" {
            let hardcodedItems = [
                NutritionData(
                    item: "Big Mac",
                    calories: 550,
                    fat: 30,
                    saturatedFat: 10,
                    cholesterol: 80,
                    sodium: 1010,
                    carbs: 44,
                    fiber: 3,
                    sugar: 9,
                    protein: 25
                ),
                NutritionData(
                    item: "McChicken",
                    calories: 400,
                    fat: 21,
                    saturatedFat: 3.5,
                    cholesterol: 40,
                    sodium: 560,
                    carbs: 40,
                    fiber: 2,
                    sugar: 5,
                    protein: 14
                ),
                NutritionData(
                    item: "Fries (Medium)",
                    calories: 320,
                    fat: 15,
                    saturatedFat: 2,
                    cholesterol: 0,
                    sodium: 260,
                    carbs: 44,
                    fiber: 4,
                    sugar: 0,
                    protein: 4
                ),
                NutritionData(
                    item: "Quarter Pounder with Cheese",
                    calories: 520,
                    fat: 26,
                    saturatedFat: 12,
                    cholesterol: 75,
                    sodium: 1120,
                    carbs: 42,
                    fiber: 3,
                    sugar: 10,
                    protein: 26
                ),
                NutritionData(
                    item: "Chicken McNuggets (10 pc)",
                    calories: 440,
                    fat: 27,
                    saturatedFat: 4.5,
                    cholesterol: 65,
                    sodium: 840,
                    carbs: 27,
                    fiber: 2,
                    sugar: 0,
                    protein: 22
                )
            ]
            
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
                self?.currentRestaurantData = RestaurantNutritionData(
                    restaurantName: restaurantName,
                    items: hardcodedItems
                )
                print("Loaded hardcoded McDonald's data with \(hardcodedItems.count) items")
            }
            return
        }
        
        var content: String?
        
        if let path = Bundle.main.path(forResource: restaurantID, ofType: "csv", inDirectory: "Services/restaurant_data") {
            content = try? String(contentsOfFile: path)
            print("Loaded from Services/restaurant_data: \(path)")
        }
        
        if content == nil, let path = Bundle.main.path(forResource: restaurantID, ofType: "csv") {
            content = try? String(contentsOfFile: path)
            print("Loaded from main bundle: \(path)")
        }
        
        if content == nil, let path = Bundle.main.path(forResource: restaurantID, ofType: "csv", inDirectory: "restaurant_data") {
            content = try? String(contentsOfFile: path)
            print("Loaded from restaurant_data: \(path)")
        }
        
        guard let fileContent = content else {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
                self?.errorMessage = "Could not load nutrition data file for \(restaurantName) (ID: \(restaurantID))"
                print("Failed to load nutrition data for \(restaurantName) - tried all bundle paths")
            }
            return
        }
        
        let lines = fileContent.components(separatedBy: .newlines)
        var nutritionItems: [NutritionData] = []
        
        for line in lines.dropFirst() { 
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            let components = line.components(separatedBy: ",")
            guard components.count >= 10 else { continue }
            
            let item = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            
            let calories = Double(components[1]) ?? 0.0
            let fat = Double(components[2]) ?? 0.0
            let saturatedFat = Double(components[3]) ?? 0.0
            let cholesterol = Double(components[4]) ?? 0.0
            let sodium = Double(components[5]) ?? 0.0
            let carbs = Double(components[6]) ?? 0.0
            let fiber = Double(components[7]) ?? 0.0
            let sugar = Double(components[8]) ?? 0.0
            let protein = Double(components[9]) ?? 0.0
            
            let nutritionData = NutritionData(
                item: item,
                calories: calories,
                fat: fat,
                saturatedFat: saturatedFat,
                cholesterol: cholesterol,
                sodium: sodium,
                carbs: carbs,
                fiber: fiber,
                sugar: sugar,
                protein: protein
            )
            
            nutritionItems.append(nutritionData)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.currentRestaurantData = RestaurantNutritionData(
                restaurantName: restaurantName,
                items: nutritionItems
            )
            print("Loaded \(nutritionItems.count) nutrition items for \(restaurantName)")
        }
    }
    
    func clearData() {
        currentRestaurantData = nil
        errorMessage = nil
    }
}
