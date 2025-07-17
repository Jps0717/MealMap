import SwiftUI

// MARK: - Score Card Component
struct MenuItemScoreCard: View {
    let score: MenuItemScore
    let compact: Bool
    @State private var showingDetails = false
    @ObservedObject private var authManager = AuthenticationManager.shared
    
    init(score: MenuItemScore, compact: Bool = false) {
        self.score = score
        self.compact = compact
    }
    
    var body: some View {
        if !authManager.isAuthenticated {
            // Show blurred/locked state when not authenticated
            if compact {
                compactLockedView
            } else {
                fullLockedView
            }
        } else {
            // Show normal score when authenticated
            if compact {
                compactScoreView
            } else {
                fullScoreView
            }
        }
    }
    
    private var compactLockedView: some View {
        HStack(spacing: 8) {
            // Locked score circle
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .blur(radius: 2)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sign In")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text("View Score")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("🔒")
                .font(.title3)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            // Could trigger sign in flow here
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            SignInPromptView()
        }
    }
    
    private var fullLockedView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nutrition Score")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Sign in to view personalized scores")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Sign In") {
                    showingDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Blurred/locked score display
            HStack(spacing: 20) {
                // Locked score circle
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .blur(radius: 3)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("Sign In")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // Locked breakdown
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("•••")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .blur(radius: 1)
                        
                        Spacer()
                        
                        Text("🔒")
                            .font(.title2)
                    }
                    
                    Text("Unlock personalized nutrition scoring")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Locked breakdown grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                LockedScoreBreakdownItem(label: "Nutrition", icon: "chart.bar.fill")
                LockedScoreBreakdownItem(label: "Goals", icon: "target")
                LockedScoreBreakdownItem(label: "Restrictions", icon: "exclamationmark.shield.fill")
                LockedScoreBreakdownItem(label: "Portion", icon: "scalemass.fill")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            SignInPromptView()
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
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
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

// MARK: - Locked Score Breakdown Item
struct LockedScoreBreakdownItem: View {
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .font(.caption)
                
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            
            HStack {
                Text("•••")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .blur(radius: 1)
                
                Spacer()
                
                // Blurred progress bar
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 2)
                    .blur(radius: 1)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Sign In Prompt View
struct SignInPromptView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Sign In Required")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Sign in to unlock personalized nutrition scoring based on your health goals and dietary preferences.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                // Benefits
                VStack(alignment: .leading, spacing: 12) {
                    Text("With MealMap scoring, you get:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    BenefitRow(icon: "target", text: "Personalized scores based on your goals")
                    BenefitRow(icon: "heart.circle", text: "Dietary restriction compliance")
                    BenefitRow(icon: "chart.bar.fill", text: "Detailed nutrition breakdown")
                    BenefitRow(icon: "person.crop.circle.badge.checkmark", text: "Recommendations tailored to you")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // Sign in button
                Button("Sign In to MealMap") {
                    // Navigate to sign in or trigger authentication
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Nutrition Scoring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Benefit Row
struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 16))
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
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
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
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
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// Preview
struct MenuItemScoreCard_Previews: PreviewProvider {
    static var previews: some View {
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
}