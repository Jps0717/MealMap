import SwiftUI

struct EnhancedMenuItemDetailView: View {
    let item: AnalyzedMenuItem
    @State private var showingUserCorrections = false
    @State private var userMarkedIncorrect = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Section
                    headerSection
                    
                    // Estimation Source Section
                    estimationSourceSection
                    
                    // Nutrition Section
                    if item.estimationTier != .unavailable {
                        nutritionSection
                    }
                    
                    // Dietary Tags Section
                    if !item.dietaryTags.isEmpty {
                        dietaryTagsSection
                    }
                    
                    // Ingredients Section (if available)
                    if !item.ingredients.isEmpty {
                        ingredientsSection
                    }
                    
                    // User Feedback Section
                    userFeedbackSection
                }
                .padding()
            }
            .navigationTitle("Menu Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingUserCorrections) {
            UserCorrectionsView(item: item)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = item.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let price = item.price {
                    Text(price)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var estimationSourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Estimation")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                Image(systemName: getSourceIcon())
                    .font(.title2)
                    .foregroundColor(getSourceColor())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.estimationTier.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if item.isGeneralizedEstimate {
                            Text("⚠️")
                                .font(.caption)
                        }
                    }
                    
                    Text(item.estimationTier.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let sourceDetails = item.nutritionEstimate.sourceDetails {
                        Text(sourceDetails)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                VStack {
                    Text("\(Int(item.confidence * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(getSourceColor())
                    Text("Confidence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(getSourceColor().opacity(0.1))
            .cornerRadius(12)
            
            // Nutritionix-specific information
            if item.estimationTier == .nutritionix {
                nutritionixDetailsSection()
            }
        }
    }
    
    private func nutritionixDetailsSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analysis Details")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                if let sourceDetails = item.nutritionEstimate.sourceDetails {
                    Text("• \(sourceDetails)")
                        .font(.caption)
                }
                Text("• AI-powered menu parsing with nutrition analysis")
                    .font(.caption)
                Text("• High-accuracy nutrition data from natural language analysis")
                    .font(.caption)
                Text("• Based on comprehensive food database")
                    .font(.caption)
                if let portionSize = item.nutritionEstimate.estimatedPortionSize {
                    Text("• Portion size: \(portionSize)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                NutritionDetailCard(
                    label: "Calories",
                    range: item.nutritionEstimate.calories,
                    color: .orange,
                    showRange: item.isGeneralizedEstimate
                )
                
                NutritionDetailCard(
                    label: "Carbohydrates",
                    range: item.nutritionEstimate.carbs,
                    color: .blue,
                    showRange: item.isGeneralizedEstimate
                )
                
                NutritionDetailCard(
                    label: "Protein",
                    range: item.nutritionEstimate.protein,
                    color: .red,
                    showRange: item.isGeneralizedEstimate
                )
                
                NutritionDetailCard(
                    label: "Fat",
                    range: item.nutritionEstimate.fat,
                    color: .purple,
                    showRange: item.isGeneralizedEstimate
                )
                
                if let fiber = item.nutritionEstimate.fiber {
                    NutritionDetailCard(
                        label: "Fiber",
                        range: fiber,
                        color: .green,
                        showRange: item.isGeneralizedEstimate
                    )
                }
                
                if let sodium = item.nutritionEstimate.sodium {
                    NutritionDetailCard(
                        label: "Sodium",
                        range: sodium,
                        color: .yellow,
                        showRange: item.isGeneralizedEstimate
                    )
                }
            }
            
            if item.isGeneralizedEstimate {
                Text("💡 Ranges shown reflect estimation uncertainty")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 8)
            }
        }
    }
    
    private var dietaryTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dietary Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(item.dietaryTags, id: \.self) { tag in
                    DietaryTagDetailView(tag: tag)
                }
            }
        }
    }
    
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Identified Ingredients")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                ForEach(item.ingredients) { ingredient in
                    IngredientDetailView(ingredient: ingredient)
                }
            }
        }
    }
    
    private var userFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feedback")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Button(action: {
                    userMarkedIncorrect.toggle()
                }) {
                    HStack {
                        Image(systemName: userMarkedIncorrect ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(userMarkedIncorrect ? .red : .gray)
                        Text("This information seems incorrect")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    showingUserCorrections = true
                }) {
                    HStack {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(.blue)
                        Text("Suggest corrections")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // Helper methods
    private func getSourceIcon() -> String {
        switch item.estimationTier {
        case .nutritionix: return "brain"
        case .unavailable: return "questionmark.circle"
        }
    }
    
    private func getSourceColor() -> Color {
        switch item.estimationTier {
        case .nutritionix: return .blue
        case .unavailable: return .gray
        }
    }
}

struct NutritionDetailCard: View {
    let label: String
    let range: NutritionRange
    let color: Color
    let showRange: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if showRange && range.min != range.max {
                VStack(spacing: 2) {
                    Text(range.displayString)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    Text("(estimated range)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("\(Int(range.average))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                + Text(range.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DietaryTagDetailView: View {
    let tag: DietaryTag
    
    var body: some View {
        HStack(spacing: 8) {
            Text(tag.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(tag.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(tag.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct IngredientDetailView: View {
    let ingredient: IdentifiedIngredient
    
    var body: some View {
        HStack(spacing: 12) {
            Text(ingredient.category.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(ingredient.name.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(ingredient.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text(ingredient.category.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct EnhancedMenuItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedMenuItemDetailView(item: AnalyzedMenuItem.createUnavailable(
            name: "Sample Item",
            description: "Sample description",
            price: "$12.99",
            textBounds: nil
        ))
    }
}