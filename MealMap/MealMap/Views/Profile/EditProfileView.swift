import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    
    // Basic Information
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var displayName: String = ""
    
    // Health & Activity
    @State private var selectedHealthGoals: [HealthGoal] = []
    @State private var selectedDietaryRestrictions: [DietaryRestriction] = []
    @State private var activityLevel: ActivityLevel = .moderate
    
    // UI State
    @State private var isLoading = false
    @State private var showingSuccessAlert = false
    @State private var hasUnsavedChanges = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    profileHeaderSection
                    
                    // Basic Information
                    basicInformationSection
                    
                    // Health Goals
                    healthGoalsSection
                    
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
        .onChange(of: selectedHealthGoals) { _, _ in hasUnsavedChanges = true }
        .onChange(of: selectedDietaryRestrictions) { _, _ in hasUnsavedChanges = true }
        .onChange(of: activityLevel) { _, _ in hasUnsavedChanges = true }
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
    
    // MARK: - Health Goals Section
    private var healthGoalsSection: some View {
        ProfileCardSection(title: "Health Goals", icon: "target") {
            VStack(spacing: 12) {
                Text("Select your primary health and fitness goals")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(HealthGoal.allCases, id: \.self) { goal in
                        SelectableGoalCard(
                            goal: goal,
                            isSelected: selectedHealthGoals.contains(goal)
                        ) {
                            HapticService.shared.toggle()
                            if selectedHealthGoals.contains(goal) {
                                selectedHealthGoals.removeAll { $0 == goal }
                            } else {
                                selectedHealthGoals.append(goal)
                            }
                            hasUnsavedChanges = true
                        }
                    }
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
        selectedHealthGoals = user.profile.healthGoals
        selectedDietaryRestrictions = user.profile.dietaryRestrictions
        
        hasUnsavedChanges = false
    }
    
    private func saveProfile() {
        isLoading = true
        
        var updatedProfile = authManager.currentUser?.profile ?? UserProfile()
        updatedProfile.firstName = firstName
        updatedProfile.lastName = lastName
        updatedProfile.healthGoals = selectedHealthGoals
        updatedProfile.dietaryRestrictions = selectedDietaryRestrictions
        
        let updatedPreferences = authManager.currentUser?.preferences ?? UserPreferences()
        
        Task {
            await authManager.updateUserProfile(updatedProfile, preferences: updatedPreferences)
            await MainActor.run {
                isLoading = false
                hasUnsavedChanges = false
                
                // Check if profile is now complete
                let hasHealthGoals = !selectedHealthGoals.isEmpty
                let hasDietaryInfo = !selectedDietaryRestrictions.isEmpty
                
                if hasHealthGoals && hasDietaryInfo {
                    ProfileCompletionManager.shared.markProfileAsCompleted()
                    HapticService.shared.success()
                }
                
                showingSuccessAlert = true
            }
        }
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

struct SelectableGoalCard: View {
    let goal: HealthGoal
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(goal.emoji)
                    .font(.title2)
                
                Text(goal.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .blue : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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

#Preview {
    EditProfileView()
}