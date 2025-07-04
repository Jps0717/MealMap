import SwiftUI

struct UserCorrectionsView: View {
    let item: AnalyzedMenuItem
    @State private var correctedName: String
    @State private var correctedIngredients: String
    @State private var selectedDietaryTags: Set<DietaryTag>
    @State private var isVegan = false
    @State private var isGlutenFree = false
    @State private var hasNutAllergy = false
    @Environment(\.dismiss) private var dismiss
    
    init(item: AnalyzedMenuItem) {
        self.item = item
        self._correctedName = State(initialValue: item.userCorrectedName ?? item.name)
        self._correctedIngredients = State(initialValue: item.userCorrectedIngredients?.joined(separator: ", ") ?? item.ingredients.map { $0.name }.joined(separator: ", "))
        self._selectedDietaryTags = State(initialValue: Set(item.userDietaryFlags ?? item.dietaryTags))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Menu Item Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Item name", text: $correctedName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Section("Ingredients") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ingredients (comma separated)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("chicken, lettuce, tomato, cheese...", text: $correctedIngredients, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                    
                    Text("Help us improve ingredient recognition by listing what you see in this dish.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Dietary Information") {
                    Toggle("Contains dairy/eggs (not vegan)", isOn: .constant(!isVegan))
                        .onChange(of: isVegan) { _, newValue in
                            if newValue {
                                selectedDietaryTags.insert(.vegan)
                                selectedDietaryTags.insert(.vegetarian)
                            } else {
                                selectedDietaryTags.remove(.vegan)
                            }
                        }
                    
                    Toggle("Contains gluten", isOn: .constant(!isGlutenFree))
                        .onChange(of: isGlutenFree) { _, newValue in
                            if newValue {
                                selectedDietaryTags.insert(.glutenFree)
                            } else {
                                selectedDietaryTags.remove(.glutenFree)
                            }
                        }
                    
                    Toggle("Contains nuts", isOn: $hasNutAllergy)
                }
                
                Section("Dietary Tags") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(DietaryTag.allCases, id: \.self) { tag in
                            DietaryTagToggle(
                                tag: tag,
                                isSelected: selectedDietaryTags.contains(tag)
                            ) { isSelected in
                                if isSelected {
                                    selectedDietaryTags.insert(tag)
                                } else {
                                    selectedDietaryTags.remove(tag)
                                }
                            }
                        }
                    }
                }
                
                Section("Nutrition Feedback") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Does this nutrition estimate seem accurate?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 16) {
                            VStack {
                                Text("Calories")
                                    .font(.caption)
                                Text(item.nutritionEstimate.calories.displayString)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack {
                                Text("Carbs")
                                    .font(.caption)
                                Text(item.nutritionEstimate.carbs.displayString)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack {
                                Text("Protein")
                                    .font(.caption)
                                Text(item.nutritionEstimate.protein.displayString)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack {
                                Text("Fat")
                                    .font(.caption)
                                Text(item.nutritionEstimate.fat.displayString)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        HStack {
                            Button("Too Low") {
                                // Submit feedback that nutrition is underestimated
                                submitNutritionFeedback(.tooLow)
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button("About Right") {
                                // Submit feedback that nutrition is accurate
                                submitNutritionFeedback(.accurate)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Spacer()
                            
                            Button("Too High") {
                                // Submit feedback that nutrition is overestimated
                                submitNutritionFeedback(.tooHigh)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Correct Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCorrections()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveCorrections() {
        // In a real app, this would save to the user's corrections database
        // and help train the ML model for better future predictions
        
        let corrections = UserCorrections(
            itemId: item.id,
            correctedName: correctedName != item.name ? correctedName : nil,
            correctedIngredients: getCorrectedIngredients(),
            correctedDietaryTags: Array(selectedDietaryTags),
            submissionDate: Date()
        )
        
        // Save corrections to UserDefaults for now (in production, save to server)
        UserCorrectionsManager.shared.saveCorrections(corrections)
        
        debugLog("💾 Saved user corrections for: \(item.name)")
    }
    
    private func getCorrectedIngredients() -> [String]? {
        let ingredients = correctedIngredients
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let originalIngredients = item.ingredients.map { $0.name }
        return ingredients != originalIngredients ? ingredients : nil
    }
    
    private func submitNutritionFeedback(_ feedback: NutritionFeedback) {
        let nutritionFeedback = NutritionFeedbackData(
            itemId: item.id,
            originalEstimate: item.nutritionEstimate,
            userFeedback: feedback,
            submissionDate: Date()
        )
        
        UserCorrectionsManager.shared.saveNutritionFeedback(nutritionFeedback)
        debugLog("📊 Nutrition feedback submitted: \(feedback)")
    }
}

struct DietaryTagToggle: View {
    let tag: DietaryTag
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onToggle(!isSelected)
        }) {
            HStack(spacing: 6) {
                Text(tag.emoji)
                    .font(.caption)
                
                Text(tag.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(8)
        }
    }
}

// MARK: - User Corrections Data Models
struct UserCorrections: Codable {
    let itemId: UUID
    let correctedName: String?
    let correctedIngredients: [String]?
    let correctedDietaryTags: [DietaryTag]
    let submissionDate: Date
}

struct NutritionFeedbackData: Codable {
    let itemId: UUID
    let originalEstimate: NutritionEstimate
    let userFeedback: NutritionFeedback
    let submissionDate: Date
}

enum NutritionFeedback: String, Codable {
    case tooLow = "too_low"
    case accurate = "accurate"
    case tooHigh = "too_high"
}

// MARK: - User Corrections Manager
class UserCorrectionsManager: ObservableObject {
    static let shared = UserCorrectionsManager()
    
    private let correctionsKey = "user_corrections"
    private let nutritionFeedbackKey = "nutrition_feedback"
    
    private init() {}
    
    func saveCorrections(_ corrections: UserCorrections) {
        var existingCorrections = getStoredCorrections()
        existingCorrections.append(corrections)
        
        if let data = try? JSONEncoder().encode(existingCorrections) {
            UserDefaults.standard.set(data, forKey: correctionsKey)
        }
    }
    
    func saveNutritionFeedback(_ feedback: NutritionFeedbackData) {
        var existingFeedback = getStoredNutritionFeedback()
        existingFeedback.append(feedback)
        
        if let data = try? JSONEncoder().encode(existingFeedback) {
            UserDefaults.standard.set(data, forKey: nutritionFeedbackKey)
        }
    }
    
    private func getStoredCorrections() -> [UserCorrections] {
        guard let data = UserDefaults.standard.data(forKey: correctionsKey),
              let corrections = try? JSONDecoder().decode([UserCorrections].self, from: data) else {
            return []
        }
        return corrections
    }
    
    private func getStoredNutritionFeedback() -> [NutritionFeedbackData] {
        guard let data = UserDefaults.standard.data(forKey: nutritionFeedbackKey),
              let feedback = try? JSONDecoder().decode([NutritionFeedbackData].self, from: data) else {
            return []
        }
        return feedback
    }
}

#Preview {
    UserCorrectionsView(item: AnalyzedMenuItem(
        name: "Grilled Chicken Caesar Salad",
        description: "Fresh romaine lettuce, grilled chicken breast, parmesan cheese, croutons, and our signature caesar dressing",
        price: "$14.99",
        ingredients: [],
        nutritionEstimate: NutritionEstimate(
            calories: NutritionRange(min: 450, max: 550, unit: "kcal"),
            carbs: NutritionRange(min: 15, max: 25, unit: "g"),
            protein: NutritionRange(min: 35, max: 45, unit: "g"),
            fat: NutritionRange(min: 20, max: 30, unit: "g"),
            fiber: NutritionRange(min: 4, max: 8, unit: "g"),
            sodium: NutritionRange(min: 800, max: 1200, unit: "mg"),
            sugar: NutritionRange(min: 3, max: 6, unit: "g"),
            confidence: 0.85,
            estimationSource: .ingredients,
            sourceDetails: "Based on identified ingredients",
            estimatedPortionSize: "Large salad",
            portionConfidence: 0.7
        ),
        dietaryTags: [.highProtein, .lowCarb, .healthy],
        confidence: 0.85,
        textBounds: nil
    ))
}