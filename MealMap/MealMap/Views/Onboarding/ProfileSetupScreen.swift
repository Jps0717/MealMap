import SwiftUI

// MARK: - Profile Setup Screen
struct ProfileSetupScreen: View {
    let onComplete: () -> Void
    
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var profile = UserProfile()
    @State private var preferences = UserPreferences()
    @State private var currentStep = 0
    
    private let totalSteps = 3
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .padding(.horizontal, 24)
                .padding(.top, 20)
            
            // Content
            TabView(selection: $currentStep) {
                // Step 1: Basic Info
                BasicInfoStep(profile: $profile)
                    .tag(0)
                
                // Step 2: Dietary Restrictions
                DietaryRestrictionsStep(profile: $profile)
                    .tag(1)
                
                // Step 3: Nutrition Goals
                NutritionGoalsStep(preferences: $preferences)
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(currentStep == totalSteps - 1 ? "Complete Setup" : "Next") {
                    if currentStep == totalSteps - 1 {
                        completeSetup()
                    } else {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
                .disabled(authManager.isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
    }
    
    private func completeSetup() {
        Task {
            await authManager.updateUserProfile(profile, preferences: preferences)
            onComplete()
        }
    }
}

// MARK: - Step 1: Basic Info
struct BasicInfoStep: View {
    @Binding var profile: UserProfile
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Tell us about yourself")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("This helps us personalize your nutrition recommendations")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        FloatingTextField(title: "First Name", text: $profile.firstName)
                        FloatingTextField(title: "Last Name", text: $profile.lastName)
                    }
                    
                    // Health Goals
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Health Goals")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(HealthGoal.allCases, id: \.self) { goal in
                                HealthGoalCard(
                                    goal: goal,
                                    isSelected: profile.healthGoals.contains(goal)
                                ) {
                                    if profile.healthGoals.contains(goal) {
                                        profile.healthGoals.removeAll { $0 == goal }
                                    } else {
                                        profile.healthGoals.append(goal)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Step 2: Dietary Restrictions
struct DietaryRestrictionsStep: View {
    @Binding var profile: UserProfile
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Dietary Restrictions")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Select any dietary restrictions so we can filter restaurants and menu items accordingly")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                        DietaryRestrictionCard(
                            restriction: restriction,
                            isSelected: profile.dietaryRestrictions.contains(restriction)
                        ) {
                            if profile.dietaryRestrictions.contains(restriction) {
                                profile.dietaryRestrictions.removeAll { $0 == restriction }
                            } else {
                                profile.dietaryRestrictions.append(restriction)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Step 3: Nutrition Goals
struct NutritionGoalsStep: View {
    @Binding var preferences: UserPreferences
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Nutrition Goals")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Set your daily nutrition targets to help track your progress")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    NutritionGoalSlider(
                        title: "Daily Calories",
                        value: $preferences.dailyCalorieGoal,
                        range: 1200...4000,
                        unit: "kcal",
                        color: .red
                    )
                    
                    NutritionGoalSlider(
                        title: "Daily Protein",
                        value: $preferences.dailyProteinGoal,
                        range: 50...300,
                        unit: "g",
                        color: .blue
                    )
                    
                    NutritionGoalSlider(
                        title: "Daily Carbs",
                        value: $preferences.dailyCarbGoal,
                        range: 50...500,
                        unit: "g",
                        color: .orange
                    )
                    
                    NutritionGoalSlider(
                        title: "Daily Fat",
                        value: $preferences.dailyFatGoal,
                        range: 30...150,
                        unit: "g",
                        color: .green
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Supporting Views
struct HealthGoalCard: View {
    let goal: HealthGoal
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(goal.emoji)
                    .font(.largeTitle)
                
                Text(goal.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct DietaryRestrictionCard: View {
    let restriction: DietaryRestriction
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(restriction.emoji)
                    .font(.title2)
                
                Text(restriction.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct NutritionGoalSlider: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(value) \(unit)")
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 10
            )
            .accentColor(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}