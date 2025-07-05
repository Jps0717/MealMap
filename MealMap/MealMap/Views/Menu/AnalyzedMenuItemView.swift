import SwiftUI

struct AnalyzedMenuItemView: View {
    let item: AnalyzedMenuItem
    @State private var showingUserCorrections = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Nutrition Overview
                    nutritionOverviewSection
                    
                    // Detailed Nutrition
                    detailedNutritionSection
                    
                    // Ingredients
                    ingredientsSection
                    
                    // Dietary Tags
                    dietaryTagsSection
                    
                    // Confidence & Corrections
                    confidenceSection
                }
                .padding()
            }
            .navigationTitle("Menu Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Correct") {
                        showingUserCorrections = true
                    }
                    .foregroundColor(.blue)
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
                    Text(item.userCorrectedName ?? item.name)
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Portion Size
            if let portionSize = item.nutritionEstimate.estimatedPortionSize {
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundColor(.orange)
                    Text(portionSize)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Portion confidence: \(Int(item.nutritionEstimate.portionConfidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var nutritionOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MenuNutritionCard(
                    title: "Calories",
                    value: item.nutritionEstimate.calories.displayString,
                    color: .orange,
                    icon: "flame"
                )
                
                MenuNutritionCard(
                    title: "Carbs",
                    value: item.nutritionEstimate.carbs.displayString,
                    color: .blue,
                    icon: "leaf"
                )
                
                MenuNutritionCard(
                    title: "Protein",
                    value: item.nutritionEstimate.protein.displayString,
                    color: .red,
                    icon: "bolt"
                )
                
                MenuNutritionCard(
                    title: "Fat",
                    value: item.nutritionEstimate.fat.displayString,
                    color: .purple,
                    icon: "drop"
                )
            }
        }
    }
    
    private var detailedNutritionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Nutrition")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                if let fiber = item.nutritionEstimate.fiber {
                    MenuNutritionRow(label: "Fiber", value: fiber.displayString, icon: "leaf.arrow.circlepath")
                }
                
                if let sodium = item.nutritionEstimate.sodium {
                    MenuNutritionRow(label: "Sodium", value: sodium.displayString, icon: "saltshaker")
                }
                
                if let sugar = item.nutritionEstimate.sugar {
                    MenuNutritionRow(label: "Sugar", value: sugar.displayString, icon: "cube")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Identified Ingredients")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(item.ingredients) { ingredient in
                    MenuIngredientChip(ingredient: ingredient)
                }
            }
            
            if item.ingredients.isEmpty {
                Text("No specific ingredients identified")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
            }
        }
    }
    
    private var dietaryTagsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dietary Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !item.dietaryTags.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(item.dietaryTags, id: \.self) { tag in
                        MenuDietaryTagCard(tag: tag)
                    }
                }
            } else {
                Text("No specific dietary tags identified")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
            }
        }
    }
    
    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis Confidence")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                MenuConfidenceRow(
                    label: "Overall Accuracy",
                    confidence: item.confidence,
                    description: getConfidenceDescription(item.confidence)
                )
                
                MenuConfidenceRow(
                    label: "Nutrition Estimate",
                    confidence: item.nutritionEstimate.confidence,
                    description: "Based on identified ingredients"
                )
                
                MenuConfidenceRow(
                    label: "Portion Size",
                    confidence: item.nutritionEstimate.portionConfidence,
                    description: "Estimated from menu description"
                )
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            
            Text("See something wrong? Tap 'Correct' to help improve accuracy.")
                .font(.caption)
                .foregroundColor(.blue)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
    
    private func getConfidenceDescription(_ confidence: Double) -> String {
        switch confidence {
        case 0.8...:
            return "High confidence - Clear text recognition"
        case 0.6..<0.8:
            return "Medium confidence - Some interpretation needed"
        default:
            return "Lower confidence - Manual review recommended"
        }
    }
}

struct MenuNutritionCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            HStack {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Spacer()
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct MenuNutritionRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(label)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
        }
    }
}

struct MenuIngredientChip: View {
    let ingredient: IdentifiedIngredient
    
    var body: some View {
        HStack(spacing: 6) {
            Text(ingredient.category.emoji)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(ingredient.category.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(confidenceColor(ingredient.confidence))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.7...:
            return .green
        case 0.5..<0.7:
            return .orange
        default:
            return .red
        }
    }
}

struct MenuDietaryTagCard: View {
    let tag: DietaryTag
    
    var body: some View {
        HStack {
            Text(tag.emoji)
                .font(.title3)
            
            Text(tag.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding()
        .background(tag.color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct MenuConfidenceRow: View {
    let label: String
    let confidence: Double
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(confidence * 100))%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(confidenceColor)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(confidenceColor)
                        .frame(width: geometry.size.width * confidence, height: 4)
                }
            }
            .frame(height: 4)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

#Preview {
    AnalyzedMenuItemView(item: AnalyzedMenuItem(
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
            estimationSource: .nutritionix,
            sourceDetails: "Based on AI + Nutritionix analysis",
            estimatedPortionSize: "Large salad",
            portionConfidence: 0.7
        ),
        dietaryTags: [.highProtein, .lowCarb, .healthy],
        confidence: 0.85,
        textBounds: nil
    ))
}