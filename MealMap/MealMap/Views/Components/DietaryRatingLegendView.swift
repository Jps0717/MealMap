import SwiftUI

struct DietaryRatingLegendView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Score Grades
                    scoreGradesSection
                    
                    // Scoring Categories
                    scoringCategoriesSection
                    
                    // Personalization
                    personalizationSection
                    
                    // Tips
                    tipsSection
                }
                .padding()
            }
            .navigationTitle("Nutrition Scoring")
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
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How Menu Items Are Scored")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Our scoring system evaluates menu items based on established nutrition guidelines (USDA, WHO) and your personal dietary goals. Each item receives a score from 0-100 with personalized recommendations.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var scoreGradesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Score Ranges")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(ScoreGrade.allCases, id: \.self) { grade in
                    ScoreGradeLegendRow(grade: grade)
                }
            }
        }
    }
    
    private var scoringCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scoring Categories")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ScoringCategoryCard(
                    category: .nutrition,
                    weight: "35%",
                    description: "Evaluates calories, macronutrients (protein, carbs, fat), and micronutrients (fiber, sodium, sugar) against recommended daily values."
                )
                
                ScoringCategoryCard(
                    category: .goals,
                    weight: "30%",
                    description: "Assesses how well the item aligns with your health goals (weight loss, muscle building, general health, etc.)."
                )
                
                ScoringCategoryCard(
                    category: .restrictions,
                    weight: "25%",
                    description: "Checks compliance with your dietary restrictions (vegan, gluten-free, low-carb, etc.). Violations result in significant point deductions."
                )
                
                ScoringCategoryCard(
                    category: .portion,
                    weight: "10%",
                    description: "Evaluates if the portion size is appropriate for your daily caloric goals and activity level."
                )
            }
        }
    }
    
    private var personalizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personalization")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                PersonalizationCard(
                    title: "Health Goals",
                    description: "Scores are adjusted based on your specific goals like weight loss, muscle building, or general health improvement.",
                    icon: "target",
                    color: .green
                )
                
                PersonalizationCard(
                    title: "Dietary Restrictions",
                    description: "Items that violate your dietary restrictions receive lower scores or zero points for safety.",
                    icon: "exclamationmark.shield.fill",
                    color: .red
                )
                
                PersonalizationCard(
                    title: "Daily Targets",
                    description: "Nutrition scores consider your daily calorie, protein, and other nutrient targets.",
                    icon: "chart.bar.fill",
                    color: .blue
                )
            }
        }
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tips for Better Scores")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                TipCard(
                    tip: "Look for items with high protein content (≥20g) if you're building muscle",
                    emoji: "💪"
                )
                
                TipCard(
                    tip: "Choose items with moderate calories (400-600) for balanced nutrition",
                    emoji: "⚖️"
                )
                
                TipCard(
                    tip: "Avoid items with high sodium (>1500mg) for heart health",
                    emoji: "❤️"
                )
                
                TipCard(
                    tip: "Prioritize items with high fiber (≥5g) for digestive health",
                    emoji: "🌾"
                )
                
                TipCard(
                    tip: "Check that items comply with your dietary restrictions",
                    emoji: "✅"
                )
            }
        }
    }
}

// MARK: - Supporting Views
struct ScoreGradeLegendRow: View {
    let grade: ScoreGrade
    
    var body: some View {
        HStack {
            Text(grade.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(grade.rawValue)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(grade.color)
                
                Text(scoreRangeText(for: grade))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(descriptionText(for: grade))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding()
        .background(grade.color.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func scoreRangeText(for grade: ScoreGrade) -> String {
        switch grade {
        case .excellent: return "90-100 points"
        case .veryGood: return "80-89 points"
        case .good: return "70-79 points"
        case .fair: return "60-69 points"
        case .poor: return "50-59 points"
        case .veryPoor: return "0-49 points"
        }
    }
    
    private func descriptionText(for grade: ScoreGrade) -> String {
        switch grade {
        case .excellent: return "Outstanding choice"
        case .veryGood: return "Very good choice"
        case .good: return "Good choice"
        case .fair: return "Acceptable choice"
        case .poor: return "Poor choice"
        case .veryPoor: return "Avoid if possible"
        }
    }
}

struct ScoringCategoryCard: View {
    let category: ScoreCategory
    let weight: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                
                Text(category.rawValue)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(weight)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category.color.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(category.color.opacity(0.05))
        .cornerRadius(10)
    }
}

struct PersonalizationCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(10)
    }
}

struct TipCard: View {
    let tip: String
    let emoji: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.title2)
            
            Text(tip)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    DietaryRatingLegendView()
}