import Foundation

// MARK: - Saved Menu Analysis Models

struct SavedMenuAnalysis: Codable, Identifiable {
    let id: UUID
    let name: String
    let dateCreated: Date
    let items: [ValidatedMenuItem]
    private let selectedItemIdsArray: [UUID] // Store as array for Codable
    
    // Computed property for Set<UUID>
    var selectedItemIds: Set<UUID> {
        get { Set(selectedItemIdsArray) }
    }
    
    init(id: UUID, name: String, dateCreated: Date, items: [ValidatedMenuItem], selectedItemIds: Set<UUID>) {
        self.id = id
        self.name = name
        self.dateCreated = dateCreated
        self.items = items
        self.selectedItemIdsArray = Array(selectedItemIds)
    }
    
    var selectedItems: [ValidatedMenuItem] {
        return items.filter { selectedItemIds.contains($0.id) }
    }
    
    var totalCalories: Double {
        return selectedItems.compactMap { $0.nutritionInfo?.calories }.reduce(0, +)
    }
    
    var totalProtein: Double {
        return selectedItems.compactMap { $0.nutritionInfo?.protein }.reduce(0, +)
    }
    
    var totalCarbs: Double {
        return selectedItems.compactMap { $0.nutritionInfo?.carbs }.reduce(0, +)
    }
    
    var totalFat: Double {
        return selectedItems.compactMap { $0.nutritionInfo?.fat }.reduce(0, +)
    }
    
    var itemCount: Int {
        return selectedItems.count
    }
    
    var successRate: Int {
        guard !items.isEmpty else { return 0 }
        let validItems = items.filter { $0.isValid }.count
        return Int(Double(validItems) / Double(items.count) * 100)
    }
}

// MARK: - Saved Menu Manager

class SavedMenuManager: ObservableObject {
    static let shared = SavedMenuManager()
    
    @Published var savedMenus: [SavedMenuAnalysis] = []
    
    private let userDefaults = UserDefaults.standard
    private let savedMenusKey = "SavedMenuAnalyses"
    
    private init() {
        loadSavedMenus()
    }
    
    func saveMenu(_ menu: SavedMenuAnalysis) {
        savedMenus.append(menu)
        saveToDisk()
        print("✅ Menu analysis saved: '\(menu.name)' with \(menu.itemCount) selected items")
    }
    
    func deleteMenu(_ menu: SavedMenuAnalysis) {
        savedMenus.removeAll { $0.id == menu.id }
        saveToDisk()
        print("🗑️ Menu analysis deleted: '\(menu.name)'")
    }
    
    func deleteMenu(at indexSet: IndexSet) {
        let menusToDelete = indexSet.map { savedMenus[$0] }
        for menu in menusToDelete {
            print("🗑️ Menu analysis deleted: '\(menu.name)'")
        }
        savedMenus.remove(atOffsets: indexSet)
        saveToDisk()
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(savedMenus)
            userDefaults.set(data, forKey: savedMenusKey)
            print("💾 Saved \(savedMenus.count) menu analyses to disk")
        } catch {
            print("❌ Failed to save menus to disk: \(error)")
        }
    }
    
    private func loadSavedMenus() {
        guard let data = userDefaults.data(forKey: savedMenusKey) else {
            print("📁 No saved menu analyses found")
            return
        }
        
        do {
            savedMenus = try JSONDecoder().decode([SavedMenuAnalysis].self, from: data)
            print("📁 Loaded \(savedMenus.count) saved menu analyses from disk")
        } catch {
            print("❌ Failed to load saved menus: \(error)")
            savedMenus = []
        }
    }
    
    func clearAllMenus() {
        savedMenus = []
        userDefaults.removeObject(forKey: savedMenusKey)
        print("🗑️ All saved menu analyses cleared")
    }
}

// MARK: - Menu Analysis Extensions

extension SavedMenuAnalysis {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateCreated)
    }
    
    var displaySummary: String {
        return "\(itemCount) items • \(Int(totalCalories)) cal • \(successRate)% success"
    }
}