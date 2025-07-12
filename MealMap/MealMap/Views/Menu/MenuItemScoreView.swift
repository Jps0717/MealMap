import SwiftUI

// MARK: - Score Card Component
struct MenuItemScoreCard: View {
    let score: MenuItemScore
    let compact: Bool
    @State private var showingDetails = false
    
    init(score: MenuItemScore, compact: Bool = false) {
        self.score = score
        self.compact = compact
    }
    
    var body: some View {
        if compact {
            compactScoreView
        } else {
            fullScoreView
        }
    }
    
    private var compactScoreView: some View {
        HStack(spacing: 8) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(score.scoreColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: score.overallScore / 100)
                    .stroke(score.scoreColor, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: score.overallScore)
                
                Text("\(Int(score.overallScore))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(score.scoreColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(score.scoreGrade.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(score.scoreColor)
                
                if score.isPersonalized {
                    Text("Personalized")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(score.scoreGrade.emoji)
                .font(.title3)
        }
        .padding(8)
        .background(score.scoreColor.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            MenuItemScoreDetailView(score: score)
        }
    }
    
    private var fullScoreView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nutrition Score")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if score.isPersonalized {
                        Text("Personalized for your goals")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Details") {
                    showingDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Main score display
            HStack(spacing: 20) {
                // Overall score circle
                ZStack {
                    Circle()
                        .stroke(score.scoreColor.opacity(0.3), lineWidth: 6)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: score.overallScore / 100)
                        .stroke(score.scoreColor, lineWidth: 6)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: score.overallScore)
                    
                    VStack(spacing: 2) {
                        Text("\(Int(score.overallScore))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(score.scoreColor)
                        
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Score breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text(score.scoreGrade.rawValue)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(score.scoreColor)
                    
                    Text(score.scoreGrade.emoji)
                        .font(.title)
                    
                    if score.isPersonalized {
                        Label("Personalized", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            
            // Quick breakdown
            if !compact {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ScoreBreakdownItem(
                        label: "Nutrition",
                        score: score.nutritionScore,
                        color: .blue,
                        icon: "chart.bar.fill"
                    )
                    
                    ScoreBreakdownItem(
                        label: "Goals",
                        score: score.goalAlignmentScore,
                        color: .green,
                        icon: "target"
                    )
                    
                    ScoreBreakdownItem(
                        label: "Restrictions",
                        score: score.restrictionScore,
                        color: .red,
                        icon: "exclamationmark.shield.fill"
                    )
                    
                    ScoreBreakdownItem(
                        label: "Portion",
                        score: score.portionScore,
                        color: .orange,
                        icon: "scalemass.fill"
                    )
                }
            }
        }
        .padding()
        .background(score.scoreColor.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(score.scoreColor.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $showingDetails) {
            MenuItemScoreDetailView(score: score)
        }
    }
}

// MARK: - Score Breakdown Item
struct ScoreBreakdownItem: View {
    let label: String
    let score: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            HStack {
                Text("\(Int(score))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Spacer()
                
                // Mini progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(color.opacity(0.2))
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(color)
                            .frame(width: geometry.size.width * (score / 100), height: 2)
                    }
                }
                .frame(height: 2)
            }
        }
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Score Detail View
struct MenuItemScoreDetailView: View {
    let score: MenuItemScore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Score Breakdown
                    scoreBreakdownSection
                    
                    // Explanations
                    explanationsSection
                    
                    // Scoring Legend
                    scoringLegendSection
                }
                .padding()
            }
            .navigationTitle("Score Details")
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
        VStack(spacing: 16) {
            // Overall score
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overall Score")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("\(Int(score.overallScore))")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(score.scoreColor)
                        
                        Text("/ 100")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(score.scoreGrade.rawValue)
                        .font(.title3)
                        .foregroundColor(score.scoreColor)
                }
                
                Spacer()
                
                VStack {
                    Text(score.scoreGrade.emoji)
                        .font(.system(size: 60))
                    
                    if score.isPersonalized {
                        Label("Personalized", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(score.scoreColor.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Score Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ScoreBreakdownRow(
                    category: "Nutrition",
                    score: score.nutritionScore,
                    color: .blue,
                    icon: "chart.bar.fill",
                    description: "Calories, macros, and micronutrients"
                )
                
                ScoreBreakdownRow(
                    category: "Goal Alignment",
                    score: score.goalAlignmentScore,
                    color: .green,
                    icon: "target",
                    description: "How well this fits your health goals"
                )
                
                ScoreBreakdownRow(
                    category: "Dietary Restrictions",
                    score: score.restrictionScore,
                    color: .red,
                    icon: "exclamationmark.shield.fill",
                    description: "Compliance with your dietary restrictions"
                )
                
                ScoreBreakdownRow(
                    category: "Portion Size",
                    score: score.portionScore,
                    color: .orange,
                    icon: "scalemass.fill",
                    description: "Appropriate portion for your daily goals"
                )
            }
        }
    }
    
    private var explanationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Why This Score?")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(score.explanations) { explanation in
                    ScoreExplanationRow(explanation: explanation)
                }
            }
        }
    }
    
    private var scoringLegendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scoring Guide")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(ScoreGrade.allCases, id: \.self) { grade in
                    HStack {
                        Text(grade.emoji)
                            .font(.title3)
                        
                        Text(grade.rawValue)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(grade.color)
                        
                        Spacer()
                        
                        Text(scoreRangeText(for: grade))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func scoreRangeText(for grade: ScoreGrade) -> String {
        switch grade {
        case .excellent: return "90-100"
        case .veryGood: return "80-89"
        case .good: return "70-79"
        case .fair: return "60-69"
        case .poor: return "50-59"
        case .veryPoor: return "0-49"
        }
    }
}

// MARK: - Score Breakdown Row
struct ScoreBreakdownRow: View {
    let category: String
    let score: Double
    let color: Color
    let icon: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(category)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(score))")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (score / 100), height: 6)
                        .cornerRadius(3)
                        .animation(.easeInOut(duration: 0.8), value: score)
                }
            }
            .frame(height: 6)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Score Explanation Row
struct ScoreExplanationRow: View {
    let explanation: ScoreExplanation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: explanation.impact.icon)
                .foregroundColor(explanation.impact.color)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(explanation.category.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(explanation.category.color)
                    
                    Spacer()
                    
                    Text("\(explanation.points > 0 ? "+" : "")\(explanation.points)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(explanation.impact.color)
                }
                
                Text(explanation.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(explanation.impact.color.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    MenuItemScoreCard(
        score: MenuItemScore(
            overallScore: 85,
            nutritionScore: 80,
            goalAlignmentScore: 90,
            restrictionScore: 100,
            portionScore: 75,
            explanations: [
                ScoreExplanation(
                    category: .nutrition,
                    impact: .positive,
                    points: 15,
                    reason: "High protein content supports muscle building goals"
                ),
                ScoreExplanation(
                    category: .restrictions,
                    impact: .positive,
                    points: 0,
                    reason: "Meets all dietary restrictions"
                )
            ],
            personalizedFor: nil,
            confidence: 0.85,
            calculatedAt: Date()
        )
    )
}