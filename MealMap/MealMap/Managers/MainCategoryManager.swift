import SwiftUI
import Foundation

@MainActor
class MainCategoryManager: ObservableObject {
    static let shared = MainCategoryManager()
    
    @Published var myCategories: [UserCategory] = []
    
    private let userDefaults = UserDefaults.standard
    private let myCategoriesKey = "myCategories"
    
    // Available categories that users can add to "My Categories"
    let availableCategories = [
        AvailableCategory(id: "fastFood", name: "Fast Food", icon: "🍔", type: .main),
        AvailableCategory(id: "healthy", name: "Healthy", icon: "🥗", type: .main),
        AvailableCategory(id: "highProtein", name: "High Protein", icon: "🥩", type: .main),
        AvailableCategory(id: "vegan", name: "Vegan", icon: "🌱", type: .additional),
        AvailableCategory(id: "lowCarb", name: "Low Carb", icon: "🥩", type: .additional),
        AvailableCategory(id: "glutenFree", name: "Gluten-Free", icon: "🌾", type: .additional),
        AvailableCategory(id: "keto", name: "Keto", icon: "🥑", type: .additional)
    ]
    
    private init() {
        loadMyCategories()
        
        // If no categories exist, start with the main 3
        if myCategories.isEmpty {
            setupDefaultCategories()
        }
    }
    
    private func setupDefaultCategories() {
        myCategories = [
            UserCategory(id: "fastFood", name: "Fast Food", icon: "🍔", type: .main, order: 0),
            UserCategory(id: "healthy", name: "Healthy", icon: "🥗", type: .main, order: 1),
            UserCategory(id: "highProtein", name: "High Protein", icon: "🥩", type: .main, order: 2)
        ]
        saveMyCategories()
    }
    
    func addCategory(_ availableCategory: AvailableCategory) {
        guard myCategories.count < 3 else { return }
        
        let newOrder = myCategories.count
        let userCategory = UserCategory(
            id: availableCategory.id,
            name: availableCategory.name,
            icon: availableCategory.icon,
            type: availableCategory.type,
            order: newOrder
        )
        
        myCategories.append(userCategory)
        saveMyCategories()
        
        // Notify HomeScreen to update
        NotificationCenter.default.post(name: .myCategoriesChanged, object: nil)
    }
    
    func removeCategory(_ categoryId: String) {
        print("🗑️ MainCategoryManager: Attempting to remove category with ID: \(categoryId)")
        print("🗑️ MainCategoryManager: Current categories count: \(myCategories.count)")
        print("🗑️ MainCategoryManager: Current categories: \(myCategories.map { $0.name })")
        
        guard myCategories.count > 1 else { 
            print("🗑️ MainCategoryManager: Cannot remove - only \(myCategories.count) category remaining")
            return 
        }
        
        let originalCount = myCategories.count
        myCategories.removeAll { $0.id == categoryId }
        
        print("🗑️ MainCategoryManager: After removal - count: \(myCategories.count)")
        
        // Check if removal actually happened
        if myCategories.count == originalCount {
            print("🗑️ MainCategoryManager: WARNING - No category was removed. ID '\(categoryId)' not found.")
            return
        }
        
        // Reorder remaining categories
        for (index, _) in myCategories.enumerated() {
            myCategories[index].order = index
        }
        
        print("🗑️ MainCategoryManager: Reordered categories: \(myCategories.map { "\($0.name) (order: \($0.order))" })")
        
        saveMyCategories()
        
        // Force UI update
        objectWillChange.send()
        
        // Notify HomeScreen to update
        NotificationCenter.default.post(name: .myCategoriesChanged, object: nil)
        
        print("🗑️ MainCategoryManager: Category removal completed successfully")
    }
    
    func addCustomCategory(name: String, icon: String, filters: [String]) {
        guard myCategories.count < 3 else { return }
        
        let customId = "custom_\(UUID().uuidString)"
        let newOrder = myCategories.count
        let customCategory = UserCategory(
            id: customId,
            name: name,
            icon: icon,
            type: .custom,
            order: newOrder,
            customFilters: filters
        )
        
        myCategories.append(customCategory)
        saveMyCategories()
        
        // Notify HomeScreen to update
        NotificationCenter.default.post(name: .myCategoriesChanged, object: nil)
    }
    
    func getAvailableCategoriesNotInMy() -> [AvailableCategory] {
        let myIds = Set(myCategories.map { $0.id })
        return availableCategories.filter { !myIds.contains($0.id) }
    }
    
    private func saveMyCategories() {
        if let encoded = try? JSONEncoder().encode(myCategories) {
            userDefaults.set(encoded, forKey: myCategoriesKey)
            print("💾 MainCategoryManager: Saved \(myCategories.count) categories to UserDefaults")
        } else {
            print("❌ MainCategoryManager: Failed to encode categories for saving")
        }
    }
    
    private func loadMyCategories() {
        if let data = userDefaults.data(forKey: myCategoriesKey),
           let decoded = try? JSONDecoder().decode([UserCategory].self, from: data) {
            myCategories = decoded.sorted { $0.order < $1.order }
            print("📂 MainCategoryManager: Loaded \(myCategories.count) categories from UserDefaults")
        } else {
            print("📂 MainCategoryManager: No saved categories found, will use defaults")
        }
    }
}

// MARK: - Models

struct UserCategory: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    let type: CategoryType
    var order: Int
    let customFilters: [String]?
    
    init(id: String, name: String, icon: String, type: CategoryType, order: Int, customFilters: [String]? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.type = type
        self.order = order
        self.customFilters = customFilters
    }
}

struct AvailableCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let type: CategoryType
}

enum CategoryType: String, Codable, CaseIterable {
    case main = "main"
    case additional = "additional"
    case custom = "custom"
}

extension Notification.Name {
    static let myCategoriesChanged = Notification.Name("myCategoriesChanged")
}