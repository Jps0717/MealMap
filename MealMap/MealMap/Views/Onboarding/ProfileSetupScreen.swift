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
            // Header with progress
            VStack(spacing: 20) {
                Text("Profile Setup")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.top, 20)
                
                // Progress bar using app's style
                VStack(spacing: 8) {
                    HStack {
                        Text("Step \(currentStep + 1) of \(totalSteps)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int((Double(currentStep + 1) / Double(totalSteps)) * 100))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(1.1)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 20)
            .background(Color(.systemBackground))
            
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
            .background(Color(.systemBackground))
            
            // Navigation buttons using app's button style
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button(action: {
                        HapticService.shared.buttonPress()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep -= 1
                        }
                    }) {
                        Text("Back")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    HapticService.shared.buttonPress()
                    if currentStep == totalSteps - 1 {
                        completeSetup()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    }
                }) {
                    HStack {
                        if authManager.isLoading && currentStep == totalSteps - 1 {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(currentStep == totalSteps - 1 ? "Complete Setup" : "Next")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: authManager.isLoading ? [Color.gray, Color.gray.opacity(0.8)] : [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: authManager.isLoading ? .clear : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    .disabled(authManager.isLoading)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
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
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Tell us about yourself")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("This helps us personalize your nutrition recommendations")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        EnhancedTextField(title: "First Name", text: $profile.firstName)
                        EnhancedTextField(title: "Last Name", text: $profile.lastName)
                    }
                    
                    // Health Goals using app's card style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Health Goals")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(HealthGoal.allCases, id: \.self) { goal in
                                HealthGoalCard(
                                    goal: goal,
                                    isSelected: profile.healthGoals.contains(goal)
                                ) {
                                    HapticService.shared.toggle()
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
        .background(Color(.systemBackground))
    }
}

// MARK: - Step 2: Dietary Restrictions
struct DietaryRestrictionsStep: View {
    @Binding var profile: UserProfile
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Dietary Restrictions")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Select any dietary restrictions so we can filter restaurants and menu items accordingly")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 40)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 12) {
                    ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                        DietaryRestrictionCard(
                            restriction: restriction,
                            isSelected: profile.dietaryRestrictions.contains(restriction)
                        ) {
                            HapticService.shared.toggle()
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
        .background(Color(.systemBackground))
    }
}

// MARK: - Step 3: Nutrition Goals
struct NutritionGoalsStep: View {
    @Binding var preferences: UserPreferences
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Nutrition Goals")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Set your daily nutrition targets to help track your progress")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
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
        .background(Color(.systemBackground))
    }
}

// MARK: - Supporting Views (updated with app's styling)
struct HealthGoalCard: View {
    let goal: HealthGoal
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Text(goal.emoji)
                    .font(.largeTitle)
                
                Text(goal.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .blue : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? .blue.opacity(0.2) : .black.opacity(0.05), radius: isSelected ? 8 : 4, x: 0, y: 2)
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
            HStack(spacing: 16) {
                Text(restriction.emoji)
                    .font(.title2)
                
                Text(restriction.rawValue)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .blue : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? .blue.opacity(0.2) : .black.opacity(0.05), radius: isSelected ? 8 : 4, x: 0, y: 2)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(value) \(unit)")
                    .font(.headline)
                    .fontWeight(.bold)
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
            .frame(height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}