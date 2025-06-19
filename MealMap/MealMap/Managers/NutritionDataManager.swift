import Foundation
import UIKit

@MainActor
class NutritionDataManager: ObservableObject {
    @Published var isLoading = false
    @Published var currentRestaurantData: RestaurantNutritionData?
    @Published var errorMessage: String?
    
    // MARK: - API Configuration
    private let baseURL = "https://meal-map-api.onrender.com"
    private let session = URLSession.shared
    
    // MARK: - Cache Properties
    private var nutritionCache = NutritionCache()
    private var loadingTasks: [String: Task<RestaurantNutritionData?, Never>] = [:]
    private var availableRestaurantIDs: [String] = []
    
    // MARK: - Performance Tracking
    private var cacheHits = 0
    private var cacheMisses = 0
    
    init() {
        print("🍽️ NutritionDataManager initialized with Meal Map API")
        Task {
            await loadAvailableRestaurants()
        }
    }
    
    // MARK: - API Methods
    private func loadAvailableRestaurants() async {
        guard let url = URL(string: "\(baseURL)/restaurants") else {
            print("❌ Invalid API URL")
            return
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            let restaurantIDs = try JSONDecoder().decode([String].self, from: data)
            self.availableRestaurantIDs = restaurantIDs
            print("✅ Loaded \(restaurantIDs.count) available restaurant IDs from API")
        } catch {
            print("❌ Failed to load available restaurants: \(error)")
        }
    }
    
    private func fetchRestaurantFromAPI(restaurantId: String) async -> RestaurantNutritionData? {
        guard let url = URL(string: "\(baseURL)/restaurants/\(restaurantId)") else {
            print("❌ Invalid restaurant API URL for \(restaurantId)")
            return nil
        }
        
        do {
            print("🌐 Fetching \(restaurantId) from API...")
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 API Response for \(restaurantId): \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    print("❌ API returned status \(httpResponse.statusCode) for \(restaurantId)")
                    return nil
                }
            }
            
            let restaurantJSON = try JSONDecoder().decode(RestaurantJSON.self, from: data)
            
            // Convert to our internal format
            let nutritionItems = restaurantJSON.menu.map { menuItem in
                NutritionData(
                    item: menuItem.Item,
                    calories: menuItem.Calories,
                    fat: menuItem.Fat_g,
                    saturatedFat: menuItem.Saturated_Fat_g,
                    cholesterol: menuItem.Cholesterol_mg,
                    sodium: menuItem.Sodium_mg,
                    carbs: menuItem.Carbs_g,
                    fiber: menuItem.Fiber_g,
                    sugar: menuItem.Sugar_g,
                    protein: menuItem.Protein_g
                )
            }
            
            print("✅ Fetched \(nutritionItems.count) items for \(restaurantJSON.restaurant_name) from API")
            
            return RestaurantNutritionData(
                restaurantName: restaurantJSON.restaurant_name,
                items: nutritionItems
            )
            
        } catch {
            print("❌ Failed to fetch \(restaurantId) from API: \(error)")
            return nil
        }
    }
    
    // MARK: - Public API
    func loadNutritionData(for restaurantName: String) {
        let cacheKey = restaurantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        print("🍽️ Loading nutrition data for restaurant: '\(restaurantName)'")
        
        // Check cache first (super fast)
        if let cachedData = nutritionCache.getRestaurant(named: restaurantName) {
            print("⚡ Cache hit for \(restaurantName)")
            cacheHits += 1
            isLoading = false
            currentRestaurantData = cachedData
            errorMessage = nil
            return
        }
        
        // Check if already loading
        if let existingTask = loadingTasks[cacheKey] {
            print("⏳ Already loading \(restaurantName), waiting for completion...")
            isLoading = true
            errorMessage = nil
            
            Task {
                if let result = await existingTask.value {
                    self.isLoading = false
                    self.currentRestaurantData = result
                }
            }
            return
        }
        
        cacheMisses += 1
        print("🔍 Cache miss for \(restaurantName), loading from API...")
        
        isLoading = true
        errorMessage = nil
        
        let task = Task {
            return await loadFromAPI(restaurantName: restaurantName)
        }
        
        loadingTasks[cacheKey] = task
        
        Task {
            if let result = await task.value {
                self.isLoading = false
                self.currentRestaurantData = result
                
                // Store in cache for future use
                self.nutritionCache.store(restaurant: result)
            } else {
                self.isLoading = false
                self.errorMessage = "No nutrition data available for \(restaurantName)"
            }
            loadingTasks.removeValue(forKey: cacheKey)
        }
    }
    
    // MARK: - API Data Loading
    private func loadFromAPI(restaurantName: String) async -> RestaurantNutritionData? {
        // First try to find exact match by looking through restaurant mapping
        let possibleMatch = findRestaurantIdForName(restaurantName)
        
        if let restaurantId = possibleMatch {
            return await fetchRestaurantFromAPI(restaurantId: restaurantId)
        }
        
        // If no exact match, try searching through available restaurant IDs
        return await findBestFuzzyMatchFromAPI(for: restaurantName)
    }
    
    private func findBestFuzzyMatchFromAPI(for restaurantName: String) async -> RestaurantNutritionData? {
        // For now, skip fuzzy matching to avoid too many API calls
        // Could be implemented later with a search endpoint
        print("❌ No exact match found for \(restaurantName) in API")
        return nil
    }
    
    // Enhanced restaurant name matching (same as before but with R0018 added)
    private func findRestaurantIdForName(_ restaurantName: String) -> String? {
        // Create a clean mapping based on RestaurantData.restaurantsWithNutritionData  
        let restaurantMapping: [String: String] = [
            // 7-Eleven variants
            "7 eleven": "R0000",
            "7-eleven": "R0000", 
            "seven eleven": "R0000",
            
            // Applebee's variants
            "applebees": "R0001",
            "applebee": "R0001", 
            
            // Arby's variants
            "arbys": "R0002",
            "arby": "R0002",
            
            // Auntie Anne's variants
            "auntie annes": "R0003",
            
            // BJ's variants
            "bjs restaurant": "R0004",
            "bjs": "R0004",
            
            // Baskin Robbins variants
            "baskin robbins": "R0005",
            "baskin-robbins": "R0005",
            
            // Bob Evans
            "bob evans": "R0006", 
            
            // Bojangles
            "bojangles": "R0007",
            
            // Bonefish Grill
            "bonefish grill": "R0008",
            
            // Boston Market
            "boston market": "R0009",
            
            // Burger King
            "burger king": "R0010",
            
            // California Pizza Kitchen variants
            "california pizza kitchen": "R0011",
            "cpk": "R0011",
            
            // Captain D's variants
            "captain ds": "R0012",
            
            // Carl's Jr variants
            "carls jr": "R0013",
            
            // Carrabba's variants
            "carrabbas": "R0014",
            
            // Casey's variants
            "caseys": "R0015",
            
            // Checker's/Rally's variants
            "checkers": "R0016",
            "rallys": "R0016",
            
            // Chick-fil-A variants (R0017 has more comprehensive menu)
            "chick-fil-a": "R0017",
            "chick fil a": "R0017",
            "chickfila": "R0017",
            
            // Chili's variants
            "chilis": "R0019",
            "chili": "R0019",
            
            // Chipotle variants
            "chipotle": "R0020",
            "chipotle mexican grill": "R0020",
            
            // Chuck E. Cheese variants
            "chuck e cheese": "R0021",
            
            // Church's Chicken variants
            "churchs chicken": "R0022",
            
            // CiCi's Pizza variants
            "cicis pizza": "R0023",
            
            // Culver's variants
            "culvers": "R0024",
            
            // Dairy Queen variants
            "dairy queen": "R0025",
            "dq": "R0025",
            
            // Del Taco
            "del taco": "R0026",
            
            // Denny's variants
            "dennys": "R0027",
            
            // Dickey's variants
            "dickeys": "R0028",
            
            // Domino's variants
            "dominos": "R0029",
            "dominos pizza": "R0029",
            
            // Dunkin' variants
            "dunkin donuts": "R0030",
            "dunkin": "R0030",
            
            // Einstein Bros variants
            "einstein bros": "R0031",
            "einstein brothers": "R0031",
            
            // El Pollo Loco
            "el pollo loco": "R0032",
            
            // Famous Dave's variants
            "famous daves": "R0033",
            
            // Firehouse Subs
            "firehouse subs": "R0034",
            
            // Five Guys
            "five guys": "R0035",
            
            // Friendly's variants
            "friendlys": "R0036",
            
            // Frisch's variants
            "frischs": "R0037",
            
            // Golden Corral
            "golden corral": "R0038",
            
            // Hardee's variants
            "hardees": "R0039",
            
            // Hooters
            "hooters": "R0040",
            
            // IHOP variants
            "ihop": "R0041",
            "international house of pancakes": "R0041",
            
            // In-N-Out variants
            "in-n-out burger": "R0042",
            "in n out": "R0042",
            "innout": "R0042",
            
            // Jack in the Box
            "jack in the box": "R0043",
            
            // Jamba Juice
            "jamba juice": "R0044",
            
            // Jason's Deli variants
            "jasons deli": "R0045",
            
            // Jersey Mike's variants
            "jersey mikes": "R0046",
            
            // Joe's Crab Shack variants
            "joes crab shack": "R0047",
            
            // KFC variants
            "kfc": "R0048",
            "kentucky fried chicken": "R0048",
            
            // Krispy Kreme
            "krispy kreme": "R0049",
            
            // Krystal
            "krystal": "R0050",
            
            // Little Caesars variants
            "little caesars": "R0051",
            
            // Long John Silver's variants
            "long john silvers": "R0052",
            
            // Longhorn Steakhouse
            "longhorn steakhouse": "R0053",
            
            // Marco's Pizza variants
            "marcos pizza": "R0054",
            
            // McAlister's Deli variants
            "mcalisters deli": "R0055",
            
            // McDonald's variants
            "mcdonalds": "R0056",
            "mcd": "R0056",
            
            // Moe's variants
            "moes": "R0057",
            
            // Noodles & Company variants
            "noodles and company": "R0058",
            
            // O'Charley's variants
            "ocharleys": "R0059",
            
            // Olive Garden
            "olive garden": "R0060",
            
            // Outback variants
            "outback steakhouse": "R0061",
            "outback": "R0061",
            
            // P.F. Chang's variants
            "pf changs": "R0062",
            
            // Panda Express
            "panda express": "R0063",
            
            // Panera variants
            "panera bread": "R0064",
            "panera": "R0064",
            
            // Papa John's variants
            "papa johns": "R0065",
            
            // Papa Murphy's variants
            "papa murphys": "R0066",
            
            // Perkins
            "perkins": "R0067",
            
            // Pizza Hut
            "pizza hut": "R0068",
            
            // Popeyes variants
            "popeyes": "R0069",
            
            // Potbelly variants
            "potbelly sandwich shop": "R0070",
            "potbelly": "R0070",
            
            // Qdoba
            "qdoba": "R0071",
            
            // Quiznos
            "quiznos": "R0072",
            
            // Red Lobster
            "red lobster": "R0073",
            
            // Red Robin
            "red robin": "R0074",
            
            // Romano's variants
            "romanos": "R0075",
            
            // Round Table Pizza
            "round table pizza": "R0076",
            
            // Ruby Tuesday
            "ruby tuesday": "R0077",
            
            // Sbarro
            "sbarro": "R0078",
            
            // Sheetz
            "sheetz": "R0079",
            
            // Sonic variants
            "sonic": "R0080",
            "sonic drive-in": "R0080",
            
            // Starbucks
            "starbucks": "R0081",
            
            // Steak 'n Shake variants
            "steak n shake": "R0082",
            
            // Subway
            "subway": "R0083",
            
            // TGI Friday's variants
            "tgi fridays": "R0084",
            "fridays": "R0084",
            
            // Taco Bell
            "taco bell": "R0085",
            
            // The Capital Grille variants
            "capital grille": "R0086",
            
            // Tim Hortons
            "tim hortons": "R0087",
            
            // Wawa
            "wawa": "R0088",
            
            // Wendy's variants
            "wendys": "R0089",
            
            // Whataburger
            "whataburger": "R0090",
            
            // White Castle
            "white castle": "R0091",
            
            // Wingstop
            "wingstop": "R0092",
            
            // Yard House
            "yard house": "R0093",
            
            // Zaxby's variants
            "zaxbys": "R0094"
        ]
        
        let lowercased = restaurantName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
        
        // Try exact match first
        if let restaurantId = restaurantMapping[lowercased] {
            return restaurantId
        }
        
        // Try partial matches
        for (name, id) in restaurantMapping {
            if name.contains(lowercased) || lowercased.contains(name) {
                return id
            }
        }
        
        return nil
    }
    
    // MARK: - Utility Methods
    func getAvailableRestaurants() -> [String] {
        return nutritionCache.restaurantNames.sorted()
    }
    
    func hasNutritionData(for restaurantName: String) -> Bool {
        return nutritionCache.contains(restaurantName: restaurantName) ||
               findRestaurantIdForName(restaurantName) != nil
    }
    
    func clearData() {
        currentRestaurantData = nil
        errorMessage = nil
    }
    
    // MARK: - Performance Monitoring
    func getCacheStats() -> (hits: Int, misses: Int, hitRate: Double) {
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        return (cacheHits, cacheMisses, hitRate)
    }
    
    func printPerformanceStats() {
        let stats = getCacheStats()
        print("📊 NutritionDataManager Performance:")
        print("   Cache Hits: \(stats.hits)")
        print("   Cache Misses: \(stats.misses)")
        print("   Hit Rate: \(String(format: "%.1f", stats.hitRate * 100))%")
        print("   Available Restaurants: \(getAvailableRestaurants().count)")
        print("   API Restaurant IDs: \(availableRestaurantIDs.count)")
    }
    
    deinit {
        // Cancel any pending tasks
        for (_, task) in loadingTasks {
            task.cancel()
        }
        loadingTasks.removeAll()
        print("🍽️ NutritionDataManager deinitalized")
    }
}

// MARK: - JSON Data Models for the API format (same as before)
struct RestaurantJSON: Codable {
    let restaurant_id: String
    let restaurant_name: String
    let menu: [MenuItemJSON]
}

struct MenuItemJSON: Codable {
    let Item: String
    let Calories: Double
    let Fat_g: Double
    let Saturated_Fat_g: Double
    let Cholesterol_mg: Double
    let Sodium_mg: Double
    let Carbs_g: Double
    let Fiber_g: Double
    let Sugar_g: Double
    let Protein_g: Double
    
    enum CodingKeys: String, CodingKey {
        case Item
        case Calories
        case Fat_g = "Fat (g)"
        case Saturated_Fat_g = "Saturated Fat (g)"
        case Cholesterol_mg = "Cholesterol (mg)"
        case Sodium_mg = "Sodium (mg)"
        case Carbs_g = "Carbs (g)"
        case Fiber_g = "Fiber (g)"
        case Sugar_g = "Sugar (g)"
        case Protein_g = "Protein (g)"
    }
}
