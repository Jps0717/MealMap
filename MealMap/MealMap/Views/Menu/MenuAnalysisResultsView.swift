import SwiftUI

struct MenuAnalysisResultsView: View {
    @Environment(\.dismiss) private var dismiss
    let validatedItems: [ValidatedMenuItem]
    
    @State private var searchText = ""
    @State private var showingNutritionDetails = false
    @State private var selectedItem: ValidatedMenuItem?
    @State private var selectedItems: Set<UUID> = [] // Track selected items for meal
    @State private var showingSaveAlert = false
    @State private var showingScoreLegend = false
    @State private var menuName = ""
    
    // Scoring functionality
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var itemScores: [UUID: MenuItemScore] = [:]
    @State private var isCalculatingScores = false
    
    var filteredItems: [ValidatedMenuItem] {
        if searchText.isEmpty {
            return validatedItems
        } else {
            return validatedItems.filter { item in
                item.validatedName.localizedCaseInsensitiveContains(searchText) ||
                item.originalLine.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Calculate nutrition for selected items only
    private var selectedItemsNutrition: NutritionInfo? {
        let selectedValidItems = validatedItems.filter { 
            selectedItems.contains($0.id) && $0.isValid && $0.nutritionInfo != nil 
        }
        guard !selectedValidItems.isEmpty else { return nil }
        
        let totalCalories = selectedValidItems.compactMap { $0.nutritionInfo?.calories }.reduce(0, +)
        let totalProtein = selectedValidItems.compactMap { $0.nutritionInfo?.protein }.reduce(0, +)
        let totalCarbs = selectedValidItems.compactMap { $0.nutritionInfo?.carbs }.reduce(0, +)
        let totalFat = selectedValidItems.compactMap { $0.nutritionInfo?.fat }.reduce(0, +)
        
        return NutritionInfo(
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fiber: nil,
            sodium: nil,
            sugar: nil
        )
    }
    
    // Calculate average score for selected items
    private var selectedItemsScore: Double {
        let selectedValidItems = validatedItems.filter { 
            selectedItems.contains($0.id) && $0.isValid 
        }
        guard !selectedValidItems.isEmpty else { return 0 }
        
        let scores = selectedValidItems.compactMap { itemScores[$0.id]?.overallScore }
        return scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Stats
                headerStatsView
                
                // Results List
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    resultsListView
                }
            }
            .navigationTitle("Menu Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Save Analysis") {
                            showingSaveAlert = true
                        }
                        
                        if shouldShowScoring {
                            Button("Scoring Guide") {
                                showingScoreLegend = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search menu items...")
            .sheet(item: $selectedItem) { item in
                ValidatedMenuItemDetailView(item: item, itemScore: itemScores[item.id])
            }
            .sheet(isPresented: $showingScoreLegend) {
                DietaryRatingLegendView()
            }
            .alert("Save Menu Analysis", isPresented: $showingSaveAlert) {
                TextField("Menu name", text: $menuName)
                Button("Save") {
                    saveMenuAnalysis()
                }
                Button("Cancel", role: .cancel) {
                    menuName = ""
                }
            } message: {
                Text("Enter a name for this menu analysis to save it to your device.")
            }
            .onAppear {
                calculateScoresIfNeeded()
            }
        }
    }
    
    private var shouldShowScoring: Bool {
        authService.isAuthenticated && !validatedItems.filter { $0.isValid }.isEmpty
    }
    
    private func calculateScoresIfNeeded() {
        guard shouldShowScoring && itemScores.isEmpty && !isCalculatingScores else { return }
        
        isCalculatingScores = true
        
        // Get current user
        let currentUser = authService.currentUser
        
        // Calculate scores for all valid items
        Task {
            var scores: [UUID: MenuItemScore] = [:]
            
            for item in validatedItems.filter({ $0.isValid }) {
                // Convert ValidatedMenuItem to AnalyzedMenuItem for scoring
                let analyzedItem = convertToAnalyzedMenuItem(item)
                let score = MenuItemScoringService.shared.calculatePersonalizedScore(
                    for: analyzedItem,
                    user: currentUser
                )
                scores[item.id] = score
            }
            
            await MainActor.run {
                itemScores = scores
                isCalculatingScores = false
            }
        }
    }
    
    private func convertToAnalyzedMenuItem(_ item: ValidatedMenuItem) -> AnalyzedMenuItem {
        // Convert ValidatedMenuItem to AnalyzedMenuItem for scoring
        let nutritionEstimate = NutritionEstimate(
            calories: NutritionRange(min: item.nutritionInfo?.calories ?? 0, max: item.nutritionInfo?.calories ?? 0, unit: "kcal"),
            carbs: NutritionRange(min: item.nutritionInfo?.carbs ?? 0, max: item.nutritionInfo?.carbs ?? 0, unit: "g"),
            protein: NutritionRange(min: item.nutritionInfo?.protein ?? 0, max: item.nutritionInfo?.protein ?? 0, unit: "g"),
            fat: NutritionRange(min: item.nutritionInfo?.fat ?? 0, max: item.nutritionInfo?.fat ?? 0, unit: "g"),
            fiber: item.nutritionInfo?.fiber != nil ? NutritionRange(min: item.nutritionInfo!.fiber!, max: item.nutritionInfo!.fiber!, unit: "g") : nil,
            sodium: item.nutritionInfo?.sodium != nil ? NutritionRange(min: item.nutritionInfo!.sodium!, max: item.nutritionInfo!.sodium!, unit: "mg") : nil,
            sugar: item.nutritionInfo?.sugar != nil ? NutritionRange(min: item.nutritionInfo!.sugar!, max: item.nutritionInfo!.sugar!, unit: "g") : nil,
            confidence: 0.85,
            estimationSource: .nutritionix,
            sourceDetails: "Menu analysis",
            estimatedPortionSize: "1 serving",
            portionConfidence: 0.8
        )
        
        return AnalyzedMenuItem(
            name: item.validatedName,
            description: item.originalLine,
            price: nil,
            ingredients: [],
            nutritionEstimate: nutritionEstimate,
            dietaryTags: generateDietaryTags(for: item),
            confidence: 0.85,
            textBounds: nil,
            estimationTier: .nutritionix,
            isGeneralizedEstimate: false
        )
    }
    
    private func generateDietaryTags(for item: ValidatedMenuItem) -> [DietaryTag] {
        guard let nutrition = item.nutritionInfo else { return [] }
        
        var tags: [DietaryTag] = []
        
        // High protein
        if let protein = nutrition.protein, protein >= 20 {
            tags.append(.highProtein)
        }
        
        // Low carb
        if let carbs = nutrition.carbs, carbs <= 15 {
            tags.append(.lowCarb)
        }
        
        // High carb
        if let carbs = nutrition.carbs, carbs >= 45 {
            tags.append(.highCarb)
        }
        
        // Low sodium
        if let sodium = nutrition.sodium, sodium <= 600 {
            tags.append(.lowSodium)
        }
        
        // High fiber
        if let fiber = nutrition.fiber, fiber >= 5 {
            tags.append(.highFiber)
        }
        
        // Healthy (based on overall nutrition profile)
        if let calories = nutrition.calories, 
           let protein = nutrition.protein,
           let sodium = nutrition.sodium,
           calories <= 500 && protein >= 15 && sodium <= 800 {
            tags.append(.healthy)
        }
        
        return tags
    }
    
    // MARK: - Header Stats View
    
    private var headerStatsView: some View {
        VStack(spacing: 16) {
            mainStatsRow
            
            // Scoring section (if available)
            if shouldShowScoring {
                scoringSection
            }
            
            // Always show meal nutrition section
            mealNutritionSection()
            
            searchStatusSection
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var scoringSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Personalized Nutrition Scores")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Guide") {
                    showingScoreLegend = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if isCalculatingScores {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Calculating scores...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 16) {
                    let avgScore = calculateAverageScore()
                    let selectedScore = selectedItemsScore
                    
                    ScoreStatView(
                        title: "Menu Average",
                        score: avgScore,
                        subtitle: "\(itemScores.count) items"
                    )
                    
                    if selectedScore > 0 {
                        ScoreStatView(
                            title: "Selected Items",
                            score: selectedScore,
                            subtitle: "\(selectedItems.count) items"
                        )
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func calculateAverageScore() -> Double {
        let scores = itemScores.values.map { $0.overallScore }
        return scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
    }
    
    private var mainStatsRow: some View {
        HStack(spacing: 24) {
            StatView(
                value: "\(validatedItems.count)",
                label: "Total Items",
                color: .blue
            )
            
            StatView(
                value: "\(validatedItems.filter { $0.isValid }.count)",
                label: "With Nutrition",
                color: .green
            )
            
            let successRate = validatedItems.isEmpty ? 0 : Int(Double(validatedItems.filter { $0.isValid }.count) / Double(validatedItems.count) * 100)
            StatView(
                value: "\(successRate)%",
                label: "Success Rate",
                color: .orange
            )
        }
    }
    
    private var searchStatusSection: some View {
        Group {
            if !searchText.isEmpty && filteredItems.count != validatedItems.count {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                    Text("Showing \(filteredItems.count) of \(validatedItems.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Results List View
    
    private var resultsListView: some View {
        List {
            ForEach(filteredItems) { item in
                ValidatedMenuItemRow(
                    item: item,
                    itemScore: itemScores[item.id],
                    isSelected: selectedItems.contains(item.id),
                    onTap: {
                        selectedItem = item
                        showingNutritionDetails = true
                    },
                    onToggleSelection: {
                        if selectedItems.contains(item.id) {
                            selectedItems.remove(item.id)
                        } else {
                            selectedItems.insert(item.id)
                        }
                    },
                    convertToAnalyzed: convertToAnalyzedMenuItem
                )
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No items match your search")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Try adjusting your search terms")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("Clear Search") {
                searchText = ""
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func mealNutritionSection() -> some View {
        let mealNutrition = selectedItemsNutrition ?? NutritionInfo(
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            fiber: nil,
            sodium: nil,
            sugar: nil
        )
        
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(.purple)
                Text("Nutrition In Your Meal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                Spacer()
            }
            
            HStack(spacing: 16) {
                NutritionQuickStat(label: "Cal", value: "\(Int(mealNutrition.calories ?? 0))", color: .red)
                NutritionQuickStat(label: "Protein", value: "\(Int(mealNutrition.protein ?? 0))g", color: .blue)
                NutritionQuickStat(label: "Carbs", value: "\(Int(mealNutrition.carbs ?? 0))g", color: .orange)
                NutritionQuickStat(label: "Fat", value: "\(Int(mealNutrition.fat ?? 0))g", color: .green)
                
                // Show meal score if available
                if selectedItemsScore > 0 {
                    VStack(spacing: 2) {
                        Text("\(Int(selectedItemsScore))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(getScoreColor(selectedItemsScore))
                        Text("Score")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func getScoreColor(_ score: Double) -> Color {
        switch score {
        case 90...: return .green
        case 80..<90: return Color(red: 0.6, green: 0.8, blue: 0.2)
        case 70..<80: return .blue
        case 60..<70: return .orange
        default: return .red
        }
    }
    
    private func saveMenuAnalysis() {
        guard !menuName.isEmpty else { return }
        
        let savedMenu = SavedMenuAnalysis(
            id: UUID(),
            name: menuName,
            dateCreated: Date(),
            items: validatedItems,
            selectedItemIds: selectedItems
        )
        
        SavedMenuManager.shared.saveMenu(savedMenu)
        menuName = ""
        
        // Show success feedback
        print("Menu analysis saved: \(savedMenu.name)")
    }
}

struct ScoreStatView: View {
    let title: String
    let score: Double
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(score))")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(getScoreColor(score))
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func getScoreColor(_ score: Double) -> Color {
        switch score {
        case 90...: return .green
        case 80..<90: return Color(red: 0.6, green: 0.8, blue: 0.2)
        case 70..<80: return .blue
        case 60..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - Supporting Views

struct StatView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NutritionQuickStat: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ValidatedMenuItemRow: View {
    let item: ValidatedMenuItem
    let itemScore: MenuItemScore?
    let isSelected: Bool
    let onTap: () -> Void
    let onToggleSelection: () -> Void
    let convertToAnalyzed: (ValidatedMenuItem) -> AnalyzedMenuItem
    
    @State private var showingDietaryChat = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection circle (on the left) - only show if item has nutrition data
            if item.isValid {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .green : .gray)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Empty space for failed items
                Circle()
                    .fill(Color.clear)
                    .frame(width: 24, height: 24)
            }
            
            // Content (tappable for details)
            Button(action: onTap) {
                VStack(spacing: 8) {
                    itemHeaderRow
                    
                    // Nutrition Preview (if available)
                    if item.isValid, let nutrition = item.nutritionInfo {
                        nutritionPreviewRow(nutrition)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Score badge (if available)
            if let score = itemScore {
                VStack(spacing: 2) {
                    Text("\(Int(score.overallScore))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(score.scoreColor)
                    
                    Circle()
                        .fill(score.scoreColor)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(score.scoreColor.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Chat button
            Button(action: {
                showingDietaryChat = true
            }) {
                Image(systemName: "message.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .sheet(isPresented: $showingDietaryChat) {
                let analyzedItem = convertToAnalyzed(item)
                DietaryChatView(initialItem: analyzedItem)
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var itemHeaderRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.validatedName)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Show status as text instead of icon
            if !item.isValid {
                Text("No nutrition data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func nutritionPreviewRow(_ nutrition: NutritionInfo) -> some View {
        HStack(spacing: 16) {
            if let calories = nutrition.calories {
                NutritionPreviewItem(label: "Cal", value: "\(Int(calories))", color: .red)
            }
            if let protein = nutrition.protein {
                NutritionPreviewItem(label: "Protein", value: "\(String(format: "%.1f", protein))g", color: .blue)
            }
            if let carbs = nutrition.carbs {
                NutritionPreviewItem(label: "Carbs", value: "\(String(format: "%.1f", carbs))g", color: .orange)
            }
            if let fat = nutrition.fat {
                NutritionPreviewItem(label: "Fat", value: "\(String(format: "%.1f", fat))g", color: .green)
            }
            Spacer()
        }
        .padding(.leading, 16) // Indent nutrition info
    }
}

struct ValidatedMenuItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: ValidatedMenuItem
    let itemScore: MenuItemScore?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    itemHeaderSection
                    
                    // Score section (if available)
                    if let score = itemScore {
                        // Removed MenuItemScoreView definition
                    }
                    
                    // Nutrition Information
                    if item.isValid, let nutrition = item.nutritionInfo {
                        NutritionInfoSectionView(nutrition: nutrition)
                    } else {
                        noNutritionInfoSection
                    }
                }
                .padding()
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Share Item") {
                            shareItem()
                        }
                        
                        if item.isValid {
                            Button("Save to Health") {
                                saveToHealth()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func convertToAnalyzedMenuItem(_ item: ValidatedMenuItem) -> AnalyzedMenuItem {
        // This is a simplified conversion for the score view
        // The main view has a more detailed one
        let nutritionEstimate = NutritionEstimate(
            calories: NutritionRange(min: item.nutritionInfo?.calories ?? 0, max: item.nutritionInfo?.calories ?? 0, unit: "kcal"),
            carbs: NutritionRange(min: item.nutritionInfo?.carbs ?? 0, max: item.nutritionInfo?.carbs ?? 0, unit: "g"),
            protein: NutritionRange(min: item.nutritionInfo?.protein ?? 0, max: item.nutritionInfo?.protein ?? 0, unit: "g"),
            fat: NutritionRange(min: item.nutritionInfo?.fat ?? 0, max: item.nutritionInfo?.fat ?? 0, unit: "g"),
            fiber: nil,
            sodium: nil,
            sugar: nil,
            confidence: 0.8,
            estimationSource: .nutritionix,
            sourceDetails: "Menu Analysis",
            estimatedPortionSize: "1 serving",
            portionConfidence: 0.8
        )
        
        return AnalyzedMenuItem(
            name: item.validatedName,
            description: nil,
            price: nil,
            ingredients: [],
            nutritionEstimate: nutritionEstimate,
            dietaryTags: [],
            confidence: 0.8,
            textBounds: nil
        )
    }
    
    private var itemHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.validatedName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if item.originalLine != item.validatedName {
                        Text("Original: \(item.originalLine)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Analysis Status
            HStack {
                if item.isValid {
                    Label("Analysis Complete", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("Analysis Failed", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
            .background(item.isValid ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var noNutritionInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundColor(.orange)
                
                Text("Analysis Failed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("This menu item could not be successfully analyzed. This could be due to unclear text recognition, an item not in the database, or processing limitations.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func shareItem() {
        // TODO: Implement sharing functionality
        print("Sharing item: \(item.validatedName)")
    }
    
    private func saveToHealth() {
        // TODO: Implement HealthKit integration
        print("Saving to Health: \(item.validatedName)")
    }
}

struct NutritionCard: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            
            VStack(spacing: 2) {
                HStack {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct NutritionMiniCard: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct NutritionPreviewItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct NutritionInfoSectionView: View {
    let nutrition: NutritionInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Nutrition Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Main macros grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                if let calories = nutrition.calories {
                    NutritionCard(label: "Calories", value: "\(Int(calories))", unit: "kcal", color: .red, icon: "flame.fill")
                }
                if let protein = nutrition.protein {
                    NutritionCard(label: "Protein", value: String(format: "%.1f", protein), unit: "g", color: .blue, icon: "figure.strengthtraining.traditional")
                }
                if let carbs = nutrition.carbs {
                    NutritionCard(label: "Carbs", value: String(format: "%.1f", carbs), unit: "g", color: .orange, icon: "leaf.fill")
                }
                if let fat = nutrition.fat {
                    NutritionCard(label: "Fat", value: String(format: "%.1f", fat), unit: "g", color: .green, icon: "drop.fill")
                }
            }
            
            // Additional nutrients (if available)
            if nutrition.fiber != nil || nutrition.sodium != nil || nutrition.sugar != nil {
                additionalNutrientsSection(nutrition)
            }
            
            // Source information
            dataSourceSection
        }
    }
    
    private func additionalNutrientsSection(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Nutrients")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                if let fiber = nutrition.fiber {
                    NutritionMiniCard(label: "Fiber", value: String(format: "%.1f", fiber), unit: "g", color: .purple)
                }
                if let sodium = nutrition.sodium {
                    NutritionMiniCard(label: "Sodium", value: "\(Int(sodium))", unit: "mg", color: .pink)
                }
                if let sugar = nutrition.sugar {
                    NutritionMiniCard(label: "Sugar", value: String(format: "%.1f", sugar), unit: "g", color: .yellow)
                }
            }
        }
    }
    
    private var dataSourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Data Source")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text("This nutrition information was obtained through menu analysis and comprehensive food database lookup, providing accurate macro and micronutrient data.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview
struct MenuAnalysisResultsView_Previews: PreviewProvider {
    static var previews: some View {
        MenuAnalysisResultsView(validatedItems: [
            ValidatedMenuItem(
                originalLine: "grilled chicken",
                validatedName: "Grilled Chicken Breast",
                spoonacularId: 0,
                imageUrl: nil,
                nutritionInfo: NutritionInfo(
                    calories: 231,
                    protein: 43.5,
                    carbs: 0,
                    fat: 5.0,
                    fiber: 0,
                    sodium: 104,
                    sugar: 0
                ),
                isValid: true
            ),
            ValidatedMenuItem(
                originalLine: "caesar salad",
                validatedName: "Caesar Salad",
                spoonacularId: 0,
                imageUrl: nil,
                nutritionInfo: NutritionInfo(
                    calories: 470,
                    protein: 13.4,
                    carbs: 25.5,
                    fat: 35.2,
                    fiber: 4.1,
                    sodium: 1456,
                    sugar: 6.3
                ),
                isValid: true
            ),
            ValidatedMenuItem(
                originalLine: "unknown item",
                validatedName: "Unknown Item",
                spoonacularId: 0,
                imageUrl: nil,
                nutritionInfo: nil,
                isValid: false
            )
        ])
    }
}