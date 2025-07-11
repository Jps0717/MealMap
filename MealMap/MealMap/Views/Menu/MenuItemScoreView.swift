import SwiftUI

struct MenuItemScoreView: View {
    let score: MenuItemScoringService.MenuItemScore
    let item: AnalyzedMenuItem
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Overall Score Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dietary Match")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Text(score.matchLevel.rawValue)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(colorForMatchLevel(score.matchLevel))
                }
                
                Spacer()
                
                // Score Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: score.overallScore / 100)
                        .stroke(colorForMatchLevel(score.matchLevel), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: score.overallScore)
                    
                    Text("\(Int(score.overallScore))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(colorForMatchLevel(score.matchLevel))
                }
            }
            
            // Quick Score Breakdown
            if !score.categoryScores.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(score.categoryScores.sorted(by: { $0.key < $1.key }), id: \.key) { category, categoryScore in
                        CategoryScoreRow(category: category, score: categoryScore)
                    }
                }
            }
            
            // Violations (if any)
            if !score.violations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text("Considerations")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    
                    ForEach(Array(score.violations.prefix(2)), id: \.self) { violation in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "minus")
                                .foregroundColor(.orange)
                                .font(.system(size: 10))
                                .padding(.top, 2)
                            
                            Text(violation)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    if score.violations.count > 2 {
                        Button("View all \(score.violations.count) considerations") {
                            showingDetails = true
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Recommendations (if any)
            if !score.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        Text("Recommendations")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    
                    ForEach(Array(score.recommendations.prefix(2)), id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "plus")
                                .foregroundColor(.blue)
                                .font(.system(size: 10))
                                .padding(.top, 2)
                            
                            Text(recommendation)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    if score.recommendations.count > 2 {
                        Button("View all \(score.recommendations.count) recommendations") {
                            showingDetails = true
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Detail Button
            Button(action: { showingDetails = true }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12))
                    Text("View Detailed Analysis")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(.primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .sheet(isPresented: $showingDetails) {
            MenuItemScoreDetailView(score: score, item: item)
        }
    }
    
    private func colorForMatchLevel(_ level: MenuItemScoringService.MatchLevel) -> Color {
        switch level {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .avoid: return .red
        }
    }
}

struct CategoryScoreRow: View {
    let category: String
    let score: Double
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForCategory(category))
                .font(.system(size: 12))
                .foregroundColor(colorForScore(score))
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayNameForCategory(category))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                
                // Score bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorForScore(score))
                            .frame(width: geometry.size.width * (score / 100), height: 4)
                            .animation(.easeInOut(duration: 0.5), value: score)
                    }
                }
                .frame(height: 4)
            }
            
            Text("\(Int(score))")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(colorForScore(score))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "macros": return "scale.3d"
        case "health": return "heart.fill"
        case "quality": return "star.fill"
        case "calories": return "flame.fill"
        case "restrictions": return "checkmark.shield.fill"
        default: return "circle.fill"
        }
    }
    
    private func displayNameForCategory(_ category: String) -> String {
        switch category {
        case "macros": return "Macros"
        case "health": return "Health Goals"
        case "quality": return "Quality"
        case "calories": return "Calories"
        case "restrictions": return "Restrictions"
        default: return category.capitalized
        }
    }
    
    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 90...100: return .green
        case 75..<90: return .blue
        case 60..<75: return .yellow
        case 30..<60: return .orange
        default: return .red
        }
    }
}

struct MenuItemScoreDetailView: View {
    let score: MenuItemScoringService.MenuItemScore
    let item: AnalyzedMenuItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        
                        HStack {
                            Text(score.matchLevel.rawValue)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(colorForMatchLevel(score.matchLevel))
                            
                            Spacer()
                            
                            Text("\(Int(score.overallScore))/100")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(colorForMatchLevel(score.matchLevel))
                        }
                    }
                    
                    Divider()
                    
                    // Category Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Score Breakdown")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        
                        ForEach(score.categoryScores.sorted(by: { $0.key < $1.key }), id: \.key) { category, categoryScore in
                            CategoryDetailRow(category: category, score: categoryScore)
                        }
                    }
                    
                    if !score.violations.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Considerations")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(.orange)
                            
                            ForEach(score.violations, id: \.self) { violation in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 14))
                                    
                                    Text(violation)
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    
                    if !score.recommendations.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommendations")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(.blue)
                            
                            ForEach(score.recommendations, id: \.self) { recommendation in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 14))
                                    
                                    Text(recommendation)
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    
                    // Nutrition Summary
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition Summary")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        
                        NutritionSummaryGrid(nutrition: item.nutritionEstimate)
                    }
                }
                .padding()
            }
            .navigationTitle("Dietary Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func colorForMatchLevel(_ level: MenuItemScoringService.MatchLevel) -> Color {
        switch level {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .avoid: return .red
        }
    }
}

struct CategoryDetailRow: View {
    let category: String
    let score: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayNameForCategory(category))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                
                ProgressView(value: score, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: colorForScore(score)))
            }
            
            Spacer()
            
            Text("\(Int(score))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(colorForScore(score))
        }
        .padding(.vertical, 4)
    }
    
    private func displayNameForCategory(_ category: String) -> String {
        switch category {
        case "macros": return "Macro Goals Alignment"
        case "health": return "Health Goals Support"
        case "quality": return "Nutritional Quality"
        case "calories": return "Calorie Alignment"
        case "restrictions": return "Dietary Restrictions"
        default: return category.capitalized
        }
    }
    
    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 90...100: return .green
        case 75..<90: return .blue
        case 60..<75: return .yellow
        case 30..<60: return .orange
        default: return .red
        }
    }
}

struct NutritionSummaryGrid: View {
    let nutrition: NutritionEstimate
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            NutritionFactRow(label: "Calories", value: nutrition.calories.displayString, icon: "flame.fill")
            NutritionFactRow(label: "Protein", value: nutrition.protein.displayString, icon: "scalemass.fill")
            NutritionFactRow(label: "Carbs", value: nutrition.carbs.displayString, icon: "leaf.fill")
            NutritionFactRow(label: "Fat", value: nutrition.fat.displayString, icon: "drop.fill")
            
            if let fiber = nutrition.fiber {
                NutritionFactRow(label: "Fiber", value: fiber.displayString, icon: "leaf.arrow.circlepath")
            }
            
            if let sodium = nutrition.sodium {
                NutritionFactRow(label: "Sodium", value: sodium.displayString, icon: "saltshaker.fill")
            }
        }
    }
}

struct NutritionFactRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

#Preview {
    // Create sample data for preview
    let sampleNutrition = NutritionEstimate(
        calories: NutritionRange(min: 350, max: 400, unit: "kcal"),
        carbs: NutritionRange(min: 45, max: 55, unit: "g"),
        protein: NutritionRange(min: 25, max: 30, unit: "g"),
        fat: NutritionRange(min: 12, max: 18, unit: "g"),
        fiber: NutritionRange(min: 5, max: 8, unit: "g"),
        sodium: NutritionRange(min: 650, max: 800, unit: "mg"),
        sugar: NutritionRange(min: 8, max: 12, unit: "g"),
        confidence: 0.85,
        estimationSource: .nutritionix,
        sourceDetails: "Nutritionix API",
        estimatedPortionSize: "1 serving",
        portionConfidence: 0.8
    )
    
    let sampleItem = AnalyzedMenuItem(
        name: "Grilled Chicken Salad",
        description: "Mixed greens with grilled chicken breast, cherry tomatoes, and balsamic vinaigrette",
        price: "$12.99",
        ingredients: [],
        nutritionEstimate: sampleNutrition,
        dietaryTags: [.highProtein, .lowCarb],
        confidence: 0.85,
        textBounds: nil
    )
    
    let sampleScore = MenuItemScoringService.MenuItemScore(
        overallScore: 85,
        categoryScores: [
            "macros": 90,
            "health": 85,
            "quality": 80,
            "calories": 85
        ],
        violations: ["High sodium content"],
        recommendations: ["Great protein source for muscle building"],
        matchLevel: .good
    )
    
    MenuItemScoreView(score: sampleScore, item: sampleItem)
        .padding()
}