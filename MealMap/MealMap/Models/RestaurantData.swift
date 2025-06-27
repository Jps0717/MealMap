import Foundation

struct RestaurantData {
    /// Mapping of normalized restaurant name keys to their IDs
    static let restaurantIDMapping: [String: String] = [
        "7eleven": "R0000",
        "applebees": "R0001",
        "arbys": "R0002",
        "auntieannes": "R0003",
        "bjsrestaurant&brewhouse": "R0004",
        "baskinrobbins": "R0005",
        "bobevans": "R0006",
        "bojangles": "R0007",
        "bonefishgrill": "R0008",
        "bostonmarket": "R0009",
        "burgerking": "R0010",
        "californiapizzakitchen": "R0011",
        "captainds": "R0012",
        "carlsjr": "R0013",
        "carrabbasitaliangrill": "R0014",
        "caseysgeneralstore": "R0015",
        "checkersdrivein/rallys": "R0016",
        "chickfila": "R0017",
        "chilis": "R0019",
        "chipotle": "R0020",
        "chuckecheese": "R0021",
        "churchschicken": "R0022",
        "cicispizza": "R0023",
        "culvers": "R0024",
        "dairyqueen": "R0025",
        "deltaco": "R0026",
        "dennys": "R0027",
        "dickeysbarbequepit": "R0028",
        "dominos": "R0029",
        "dunkindonuts": "R0030",
        "dunkin": "R0030",
        "einsteinbros": "R0031",
        "elpolloloco": "R0032",
        "famousdaves": "R0033",
        "firehousesubs": "R0034",
        "fiveguys": "R0035",
        "friendlys": "R0036",
        "frischsbigboy": "R0037",
        "goldencorral": "R0038",
        "hardees": "R0039",
        "hooters": "R0040",
        "ihop": "R0041",
        "innoutburger": "R0042",
        "jackinthebox": "R0043",
        "jambajuice": "R0044",
        "jasonsdeli": "R0045",
        "jerseymikessubs": "R0046",
        "joescrabshack": "R0047",
        "kfc": "R0048",
        "krispykreme": "R0049",
        "krystal": "R0050",
        "littlecaesars": "R0051",
        "longjohnsilvers": "R0052",
        "longhornsteakhouse": "R0053",
        "marcospizza": "R0054",
        "mcalistersdeli": "R0055",
        "mcdonalds": "R0056",
        "moessouthwestgrill": "R0057",
        "noodles&company": "R0058",
        "ocharleys": "R0059",
        "olivegarden": "R0060",
        "outbacksteakhouse": "R0061",
        "pfchangs": "R0062",
        "pandaexpress": "R0063",
        "panerabread": "R0064",
        "papajohns": "R0065",
        "papamurphys": "R0066",
        "perkins": "R0067",
        "pizzahut": "R0068",
        "popeyes": "R0069",
        "potbellysandwichshop": "R0070",
        "qdoba": "R0071",
        "quiznos": "R0072",
        "redlobster": "R0073",
        "redrobin": "R0074",
        "romanosmacaonigrill": "R0075",
        "roundtablepizza": "R0076",
        "rubytuesday": "R0077",
        "sbarro": "R0078",
        "sheetz": "R0079",
        "sonic": "R0080",
        "starbucks": "R0081",
        "steaknshake": "R0082",
        "subway": "R0083",
        "tgifridays": "R0084",
        "tacobell": "R0085",
        "thecapitalgrille": "R0086",
        "timhortons": "R0087",
        "wawa": "R0088",
        "wendys": "R0089",
        "whataburger": "R0090",
        "whitecastle": "R0091",
        "wingstop": "R0092",
        "yardhouse": "R0093",
        "zaxbys": "R0094"
    ]

    /// List of restaurant display names that have nutrition data
    static var restaurantsWithNutritionData: [String] {
        let displayNames = [
            "7 Eleven", "Applebee's", "Arby's", "Auntie Anne's", "BJ's Restaurant & Brewhouse",
            "Baskin Robbins", "Bob Evans", "Bojangles", "Bone Fish Grill", "Boston Market",
            "Burger King", "California Pizza Kitchen", "Captain D's", "Carl's Jr.",
            "Carrabba's Italian Grill", "Casey's General Store", "Checkers Drive-In / Rally's",
            "Chick-fil-A", "Chili's", "Chipotle", "Chuck E. Cheese", "Church's Chicken",
            "Cici's Pizza", "Culver's", "Dairy Queen", "Del Taco", "Denny's",
            "Dickey's Barbecue Pit", "Domino's", "Dunkin' Donuts", "Einstein Bros",
            "El Pollo Loco", "Famous Dave's", "Firehouse Subs", "Five Guys",
            "Friendly's", "Frisch's Big Boy", "Golden Corral", "Hardee's", "Hooters",
            "IHOP", "In-N-Out Burger", "Jack in the Box", "Jamba Juice", "Jason's Deli",
            "Jersey Mike's Subs", "Joe's Crab Shack", "KFC", "Krispy Kreme", "Krystal",
            "Little Caesars", "Long John Silver's", "LongHorn Steakhouse", "Marco's Pizza",
            "McAlister's Deli", "McDonald's", "Moe's Southwest Grill", "Noodles & Company",
            "O'Charley's", "Olive Garden", "Outback Steakhouse", "P.F. Chang's",
            "Panda Express", "Panera Bread", "Papa John's", "Papa Murphy's", "Perkins",
            "Pizza Hut", "Popeyes", "Potbelly Sandwich Shop", "Qdoba", "Quiznos",
            "Red Lobster", "Red Robin", "Romano's Macaroni Grill", "Round Table Pizza",
            "Ruby Tuesday", "Sbarro", "Sheetz", "Sonic", "Starbucks", "Steak 'n Shake",
            "Subway", "TGI Friday's", "Taco Bell", "The Capital Grille", "Tim Hortons",
            "Wawa", "Wendy's", "Whataburger", "White Castle", "Wingstop", "Yard House",
            "Zaxby's"
        ]
        return displayNames.sorted()
    }
    
    /// Helper function to normalize restaurant names for consistent matching
    static func normalizeRestaurantName(_ name: String) -> String {
        return name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "&", with: "")
    }
    
    /// Check if a restaurant has nutrition data available
    static func hasNutritionData(for restaurantName: String) -> Bool {
        let normalizedName = normalizeRestaurantName(restaurantName)
        return restaurantIDMapping[normalizedName] != nil
    }
    
    /// Get restaurant ID for a given restaurant name
    static func getRestaurantID(for restaurantName: String) -> String? {
        let normalizedName = normalizeRestaurantName(restaurantName)
        return restaurantIDMapping[normalizedName]
    }
}
