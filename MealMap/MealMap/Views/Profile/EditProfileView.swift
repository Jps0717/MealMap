import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    
    // Basic Information
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var displayName: String = ""
    
    // Health & Activity
    @State private var selectedDietaryRestrictions: [DietaryRestriction] = []
    @State private var activityLevel: ActivityLevel = .moderate
    
    // UI State
    @State private var isLoading = false
    @State private var showingSuccessAlert = false
    @State private var hasUnsavedChanges = false
    
    @State private var userPreferences: UserPreferences = UserPreferences()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    profileHeaderSection
                    
                    // Basic Information
                    basicInformationSection
                    
                    // NEW: Add the nutrition goals section
                    nutritionGoalsSection
                    
                    // Dietary Restrictions
                    dietaryRestrictionsSection
                    
                    // Activity Level
                    activityLevelSection
                    
                    // Save Button
                    saveButtonSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticService.shared.buttonPress()
                        if hasUnsavedChanges {
                            // Show confirmation alert
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticService.shared.buttonPress()
                        saveProfile()
                    }
                    .disabled(isLoading)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
        .onChange(of: firstName) { _, _ in hasUnsavedChanges = true }
        .onChange(of: lastName) { _, _ in hasUnsavedChanges = true }
        .onChange(of: displayName) { _, _ in hasUnsavedChanges = true }
        .onChange(of: selectedDietaryRestrictions) { _, _ in hasUnsavedChanges = true }
        .onChange(of: activityLevel) { _, _ in hasUnsavedChanges = true }
        .onChange(of: userPreferences.dailyCalorieGoal) { _, _ in hasUnsavedChanges = true }
        .onChange(of: userPreferences.dailyProteinGoal) { _, _ in hasUnsavedChanges = true }
        .onChange(of: userPreferences.dailyCarbGoal) { _, _ in hasUnsavedChanges = true }
        .onChange(of: userPreferences.dailyFatGoal) { _, _ in hasUnsavedChanges = true }
        .onChange(of: userPreferences.dailyFiberGoal) { _, _ in hasUnsavedChanges = true }
        .onChange(of: userPreferences.dailySodiumLimit) { _, _ in hasUnsavedChanges = true }
        .alert("Profile Updated", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your profile has been successfully updated.")
        }
    }
    
    // MARK: - Profile Header
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Text(getInitials())
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text(displayName.isEmpty ? "Your Name" : displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let user = authManager.currentUser {
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Basic Information Section
    private var basicInformationSection: some View {
        ProfileCardSection(title: "Basic Information", icon: "person.fill") {
            VStack(spacing: 16) {
                ProfileTextField(
                    title: "Display Name",
                    text: $displayName,
                    placeholder: "How you'd like to be known"
                )
                
                HStack(spacing: 12) {
                    ProfileTextField(
                        title: "First Name",
                        text: $firstName,
                        placeholder: "First"
                    )
                    
                    ProfileTextField(
                        title: "Last Name", 
                        text: $lastName,
                        placeholder: "Last"
                    )
                }
            }
        }
    }
    
    // MARK: - Dietary Restrictions Section
    private var dietaryRestrictionsSection: some View {
        ProfileCardSection(title: "Dietary Restrictions", icon: "leaf.fill") {
            VStack(spacing: 12) {
                Text("Help us filter restaurants and menu items for you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                    ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                        VStack(spacing: 8) {
                            SelectableDietaryCard(
                                restriction: restriction,
                                isSelected: selectedDietaryRestrictions.contains(restriction)
                            ) {
                                HapticService.shared.toggle()
                                if selectedDietaryRestrictions.contains(restriction) {
                                    selectedDietaryRestrictions.removeAll { $0 == restriction }
                                } else {
                                    selectedDietaryRestrictions.append(restriction)
                                }
                                hasUnsavedChanges = true
                            }
                            if selectedDietaryRestrictions.contains(restriction) {
                                if restriction == .lowCarb {
                                    HStack {
                                        Text("Low Carb ≤")
                                            .font(.caption)
                                        Stepper(value: $userPreferences.lowCarbThreshold, in: 5...100, step: 1) {
                                            Text("\(Int(userPreferences.lowCarbThreshold))g")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.leading, 44)
                                }
                                if restriction == .lowSodium {
                                    HStack {
                                        Text("Low Sodium ≤")
                                            .font(.caption)
                                        Stepper(value: $userPreferences.lowSodiumThreshold, in: 50...2000, step: 10) {
                                            Text("\(Int(userPreferences.lowSodiumThreshold))mg")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.leading, 44)
                                }
                                if restriction == .diabetic {
                                    HStack {
                                        Text("Diabetic-Friendly Carb ≤")
                                            .font(.caption)
                                        Stepper(value: $userPreferences.diabeticFriendlyCarbThreshold, in: 5...100, step: 1) {
                                            Text("\(Int(userPreferences.diabeticFriendlyCarbThreshold))g")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.leading, 44)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Nutrition Goals Section
    private var nutritionGoalsSection: some View {
        ProfileCardSection(title: "Daily Nutrition Goals", icon: "chart.bar.fill") {
            VStack(spacing: 16) {
                Text("Set your personalized daily nutrition targets for AI recommendations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 20) {
                    // Calories
                    NutritionGoalRow(
                        icon: "flame.fill",
                        color: .orange,
                        title: "Daily Calories",
                        value: $userPreferences.dailyCalorieGoal,
                        unit: "kcal",
                        range: 1000...5000,
                        step: 50
                    )
                    
                    // Protein
                    NutritionGoalRow(
                        icon: "fish.fill",
                        color: .red,
                        title: "Protein Goal",
                        value: $userPreferences.dailyProteinGoal,
                        unit: "g",
                        range: 50...300,
                        step: 10
                    )
                    
                    // Carbohydrates
                    NutritionGoalRow(
                        icon: "leaf.fill",
                        color: .green,
                        title: "Carbohydrate Goal",
                        value: $userPreferences.dailyCarbGoal,
                        unit: "g",
                        range: 50...500,
                        step: 10
                    )
                    
                    // Fat
                    NutritionGoalRow(
                        icon: "drop.fill",
                        color: .yellow,
                        title: "Fat Goal",
                        value: $userPreferences.dailyFatGoal,
                        unit: "g",
                        range: 20...200,
                        step: 5
                    )
                    
                    // Fiber
                    NutritionGoalRow(
                        icon: "scissors",
                        color: .brown,
                        title: "Fiber Goal",
                        value: $userPreferences.dailyFiberGoal,
                        unit: "g",
                        range: 10...60,
                        step: 5
                    )
                    
                    // Sodium Limit
                    NutritionGoalRow(
                        icon: "saltshaker.fill",
                        color: .gray,
                        title: "Sodium Limit",
                        value: $userPreferences.dailySodiumLimit,
                        unit: "mg",
                        range: 500...4000,
                        step: 100
                    )
                }
                
                // Quick Presets
                VStack(spacing: 12) {
                    Text("Quick Presets")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 8) {
                        NutritionPresetButton(title: "Weight Loss", icon: "minus.circle.fill", color: .blue) {
                            setWeightLossPreset()
                        }
                        
                        NutritionPresetButton(title: "Maintenance", icon: "equal.circle.fill", color: .green) {
                            setMaintenancePreset()
                        }
                        
                        NutritionPresetButton(title: "Muscle Gain", icon: "plus.circle.fill", color: .orange) {
                            setMuscleGainPreset()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Activity Level Section
    private var activityLevelSection: some View {
        ProfileCardSection(title: "Activity Level", icon: "figure.run") {
            VStack(spacing: 12) {
                Text("This helps personalize your nutrition recommendations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 8) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        ActivityLevelRow(
                            level: level,
                            isSelected: activityLevel == level
                        ) {
                            HapticService.shared.toggle()
                            activityLevel = level
                            hasUnsavedChanges = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Save Button Section
    private var saveButtonSection: some View {
        Button(action: {
            HapticService.shared.buttonPress()
            saveProfile()
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(isLoading ? "Saving..." : "Save Changes")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: isLoading ? [Color.gray, Color.gray.opacity(0.8)] : [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
            .shadow(color: isLoading ? .clear : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            .disabled(isLoading || !hasUnsavedChanges)
            .opacity(hasUnsavedChanges ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Methods
    private func getInitials() -> String {
        let first = firstName.isEmpty ? displayName.first : firstName.first
        let last = lastName.first
        
        if let first = first, let last = last {
            return "\(first)\(last)".uppercased()
        } else if let first = first {
            return "\(first)".uppercased()
        } else {
            return "?"
        }
    }
    
    private func loadCurrentProfile() {
        guard let user = authManager.currentUser else { return }
        
        firstName = user.profile.firstName
        lastName = user.profile.lastName
        displayName = user.displayName
        selectedDietaryRestrictions = user.profile.dietaryRestrictions
        userPreferences = user.preferences
        
        hasUnsavedChanges = false
    }
    
    private func saveProfile() {
        isLoading = true
        
        var updatedProfile = authManager.currentUser?.profile ?? UserProfile()
        updatedProfile.firstName = firstName
        updatedProfile.lastName = lastName
        updatedProfile.dietaryRestrictions = selectedDietaryRestrictions
        updatedProfile.activityLevel = activityLevel
        
        var updatedPreferences = userPreferences
        
        Task {
            await authManager.updateUserProfile(updatedProfile, preferences: updatedPreferences)
            
            // Update AI memory with new user data
            let updatedUser = User(
                id: authManager.currentUser?.id ?? "guest",
                email: authManager.currentUser?.email ?? "",
                displayName: displayName
            )
            var userWithUpdatedData = updatedUser
            userWithUpdatedData.profile = updatedProfile
            userWithUpdatedData.preferences = updatedPreferences
            
            // Update ChatGPT service memory
            ChatGPTDietaryService.shared.initializeForUser(userWithUpdatedData)
            
            await MainActor.run {
                isLoading = false
                hasUnsavedChanges = false
                
                let hasDietaryInfo = !selectedDietaryRestrictions.isEmpty
                
                if hasDietaryInfo {
                    ProfileCompletionManager.shared.markProfileAsCompleted()
                    HapticService.shared.success()
                }
                
                showingSuccessAlert = true
            }
        }
    }
    
    // MARK: - Nutrition Preset Methods
    private func setWeightLossPreset() {
        userPreferences.dailyCalorieGoal = 1500
        userPreferences.dailyProteinGoal = 120
        userPreferences.dailyCarbGoal = 150
        userPreferences.dailyFatGoal = 50
        userPreferences.dailyFiberGoal = 30
        userPreferences.dailySodiumLimit = 2000
        hasUnsavedChanges = true
        HapticService.shared.buttonPress()
    }
    
    private func setMaintenancePreset() {
        userPreferences.dailyCalorieGoal = 2000
        userPreferences.dailyProteinGoal = 150
        userPreferences.dailyCarbGoal = 250
        userPreferences.dailyFatGoal = 67
        userPreferences.dailyFiberGoal = 25
        userPreferences.dailySodiumLimit = 2300
        hasUnsavedChanges = true
        HapticService.shared.buttonPress()
    }
    
    private func setMuscleGainPreset() {
        userPreferences.dailyCalorieGoal = 2500
        userPreferences.dailyProteinGoal = 200
        userPreferences.dailyCarbGoal = 300
        userPreferences.dailyFatGoal = 80
        userPreferences.dailyFiberGoal = 35
        userPreferences.dailySodiumLimit = 2500
        hasUnsavedChanges = true
        HapticService.shared.buttonPress()
    }
}

// MARK: - Supporting Views

struct ProfileCardSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct ProfileTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            TextField(placeholder, text: $text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

struct SelectableDietaryCard: View {
    let restriction: DietaryRestriction
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(restriction.emoji)
                    .font(.title3)
                
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ActivityLevelRow: View {
    let level: ActivityLevel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .blue : .primary)
                    
                    Text("Multiplier: \(String(format: "%.1f", level.multiplier))x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NEW: Nutrition Goal Row Component
struct NutritionGoalRow: View {
    let icon: String
    let color: Color
    let title: String
    @Binding var value: Int
    let unit: String
    let range: ClosedRange<Int>
    let step: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Title and Value
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Button("-") {
                        let newValue = max(range.lowerBound, value - step)
                        if newValue != value {
                            value = newValue
                            HapticService.shared.buttonPress()
                        }
                    }
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(color))
                    .disabled(value <= range.lowerBound)
                    
                    Text("\(value) \(unit)")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                        .frame(minWidth: 80)
                        .multilineTextAlignment(.center)
                    
                    Button("+") {
                        let newValue = min(range.upperBound, value + step)
                        if newValue != value {
                            value = newValue
                            HapticService.shared.buttonPress()
                        }
                    }
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(color))
                    .disabled(value >= range.upperBound)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - NEW: Nutrition Preset Button
struct NutritionPresetButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(color.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EditProfileView()
}