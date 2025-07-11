import SwiftUI

struct DietaryRatingLegendView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Rating Scale
                    ratingScaleSection
                    
                    // What Gets Scored
                    whatGetsScoredSection
                    
                    // Nutrition Color Guide
                    nutritionColorGuideSection
                    
                    // How to Get Ratings
                    howToGetRatingsSection
                }
                .padding()
            }
            .navigationTitle("Dietary Rating Guide")
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text("Dietary Rating System")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text("Menu items are scored based on how well they match your personal dietary goals and restrictions.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var ratingScaleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rating Scale")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                RatingScaleRow(
                    level: "Excellent Match",
                    range: "90-100%",
                    color: .green,
                    description: "Perfect for your goals"
                )
                
                RatingScaleRow(
                    level: "Good Match",
                    range: "75-89%",
                    color: .blue,
                    description: "Great choice, minor issues"
                )
                
                RatingScaleRow(
                    level: "Fair Match",
                    range: "60-74%",
                    color: .yellow,
                    description: "Okay choice, some concerns"
                )
                
                RatingScaleRow(
                    level: "Poor Match",
                    range: "30-59%",
                    color: .orange,
                    description: "Not ideal for your goals"
                )
                
                RatingScaleRow(
                    level: "Avoid",
                    range: "0-29%",
                    color: .red,
                    description: "Violates dietary restrictions"
                )
            }
        }
    }
    
    private var whatGetsScoredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What Gets Scored")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                ScoringCategoryRow(
                    icon: "scale.3d",
                    title: "Macro Goals",
                    weight: "40%",
                    description: "Protein, carbs, fat alignment with your daily targets",
                    color: .blue
                )
                
                ScoringCategoryRow(
                    icon: "heart.fill",
                    title: "Health Goals",
                    weight: "30%",
                    description: "Supports weight loss, muscle building, health improvement",
                    color: .red
                )
                
                ScoringCategoryRow(
                    icon: "star.fill",
                    title: "Nutritional Quality",
                    weight: "20%",
                    description: "Fiber content, sodium levels, sugar content",
                    color: .yellow
                )
                
                ScoringCategoryRow(
                    icon: "flame.fill",
                    title: "Calorie Alignment",
                    weight: "10%",
                    description: "Fits within your daily calorie goals",
                    color: .orange
                )
            }
            
            // Hard Constraints
            VStack(alignment: .leading, spacing: 8) {
                Text("Hard Constraints")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Text("Items that violate dietary restrictions (vegetarian, vegan, gluten-free, etc.) automatically receive a score of 0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var nutritionColorGuideSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition Color Guide")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("In nutrition breakdowns, each macro has its own color:")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                NutritionColorRow(color: .orange, nutrient: "Calories", icon: "flame.fill")
                NutritionColorRow(color: .red, nutrient: "Protein", icon: "bolt.fill")
                NutritionColorRow(color: .blue, nutrient: "Carbohydrates", icon: "leaf.fill")
                NutritionColorRow(color: .purple, nutrient: "Fat", icon: "drop.fill")
            }
        }
    }
    
    private var howToGetRatingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Get Ratings")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                RequirementRow(
                    icon: "person.crop.circle.fill",
                    title: "Create Account",
                    description: "Sign up and log in to get personalized ratings",
                    isCompleted: authManager.isAuthenticated
                )
                
                RequirementRow(
                    icon: "slider.horizontal.3",
                    title: "Set Dietary Preferences",
                    description: "Configure your health goals and dietary restrictions",
                    isCompleted: authManager.isAuthenticated && authManager.currentUser?.profile.healthGoals.isEmpty == false
                )
                
                RequirementRow(
                    icon: "camera.fill",
                    title: "Analyze Menus",
                    description: "Take photos of menus to get nutrition data and ratings",
                    isCompleted: false
                )
            }
            
            if !authManager.isAuthenticated {
                VStack(spacing: 12) {
                    Text("Get started by creating an account to unlock personalized dietary ratings!")
                        .font(.body)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                    
                    Button("Create Account") {
                        // This would typically navigate to sign up
                        // For now, just dismiss
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

struct RatingScaleRow: View {
    let level: String
    let range: String
    let color: Color
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(level)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(range)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ScoringCategoryRow: View {
    let icon: String
    let title: String
    let weight: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(weight)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                }
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct NutritionColorRow: View {
    let color: Color
    let nutrient: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(nutrient)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Rectangle()
                .fill(color)
                .frame(width: 30, height: 4)
                .cornerRadius(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

struct RequirementRow: View {
    let icon: String
    let title: String
    let description: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isCompleted ? .green : .gray)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    DietaryRatingLegendView()
}