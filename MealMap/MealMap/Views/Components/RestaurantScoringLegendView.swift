import SwiftUI

struct RestaurantScoringLegendView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = FirebaseAuthService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Restaurant Nutrition Scoring")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Restaurants with nutrition data are scored based on their menu items' nutritional value.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Scoring Legend
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Score Grades")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            ScoreLegendRow(
                                grade: .excellent,
                                range: "90-100",
                                description: "Excellent nutritional value with healthy options"
                            )
                            
                            ScoreLegendRow(
                                grade: .veryGood,
                                range: "80-89",
                                description: "Very good nutrition with some healthy choices"
                            )
                            
                            ScoreLegendRow(
                                grade: .good,
                                range: "70-79",
                                description: "Good nutrition with balanced options"
                            )
                            
                            ScoreLegendRow(
                                grade: .fair,
                                range: "60-69",
                                description: "Fair nutrition with limited healthy options"
                            )
                            
                            ScoreLegendRow(
                                grade: .poor,
                                range: "50-59",
                                description: "Poor nutrition with mostly unhealthy options"
                            )
                            
                            ScoreLegendRow(
                                grade: .veryPoor,
                                range: "0-49",
                                description: "Very poor nutrition with unhealthy options"
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Personalization Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Personalized Scoring")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if authService.isAuthenticated {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "person.crop.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Personalized scores active")
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                                
                                Text("Scores are calculated based on your personal health goals, dietary restrictions, and nutrition preferences.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .foregroundColor(.gray)
                                    Text("General health scores")
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                                
                                Text("Sign in to get personalized scores based on your health goals and dietary preferences.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                Button("Sign In for Personalized Scores") {
                                    // TODO: Open sign-in flow
                                }
                                .font(.body)
                                .foregroundColor(.blue)
                                .padding(.top, 8)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Scoring Factors
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Scoring Factors")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            ScoringFactorRow(
                                icon: "chart.bar.fill",
                                title: "Nutrition Quality",
                                description: "Calories, protein, sodium, fiber, and other nutrients"
                            )
                            
                            ScoringFactorRow(
                                icon: "target",
                                title: "Goal Alignment",
                                description: "How well items match your health goals"
                            )
                            
                            ScoringFactorRow(
                                icon: "exclamationmark.shield.fill",
                                title: "Dietary Restrictions",
                                description: "Compliance with your dietary restrictions"
                            )
                            
                            ScoringFactorRow(
                                icon: "scalemass.fill",
                                title: "Portion Size",
                                description: "Appropriate portion sizes for your goals"
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Map Pin Guide
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Map Pin Guide")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Text("85")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Scored Restaurant")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("Shows nutrition score on pin")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 6, height: 6)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Nutrition Available")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("Has nutrition data, score calculating")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Text("🍽️")
                                            .font(.system(size: 12))
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Standard Restaurant")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("No nutrition data available")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Scoring Guide")
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
}

// MARK: - Supporting Views
struct ScoreLegendRow: View {
    let grade: ScoreGrade
    let range: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(grade.color)
                    .frame(width: 20, height: 20)
                
                Text(grade.emoji)
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(grade.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(range)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ScoringFactorRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    RestaurantScoringLegendView()
}