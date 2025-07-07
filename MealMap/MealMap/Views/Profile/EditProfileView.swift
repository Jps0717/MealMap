import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var displayName: String = ""
    @State private var selectedHealthGoals: [HealthGoal] = []
    @State private var selectedDietaryRestrictions: [DietaryRestriction] = []
    @State private var activityLevel: ActivityLevel = .moderate
    
    @State private var isLoading = false
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information Section
                Section {
                    HStack {
                        Text("Display Name")
                        Spacer()
                        TextField("Display Name", text: $displayName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("First Name")
                        Spacer()
                        TextField("First Name", text: $firstName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Last Name")
                        Spacer()
                        TextField("Last Name", text: $lastName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Basic Information")
                }
                
                // Activity Level Section
                Section {
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                } header: {
                    Text("Activity Level")
                } footer: {
                    Text("This helps personalize your recommendations")
                }
                
                // Health Goals Section
                Section {
                    ForEach(HealthGoal.allCases, id: \.self) { goal in
                        HStack {
                            Text(goal.emoji)
                            Text(goal.rawValue)
                            Spacer()
                            if selectedHealthGoals.contains(goal) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .onTapGesture {
                            if selectedHealthGoals.contains(goal) {
                                selectedHealthGoals.removeAll { $0 == goal }
                                HapticService.shared.lightImpact()
                            } else {
                                selectedHealthGoals.append(goal)
                                HapticService.shared.selectionChanged()
                            }
                        }
                    }
                } header: {
                    Text("Health Goals")
                } footer: {
                    Text("Select your primary health and fitness goals")
                }
                
                // Dietary Restrictions Section
                Section {
                    ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                        HStack {
                            Text(restriction.emoji)
                            Text(restriction.rawValue)
                            Spacer()
                            if selectedDietaryRestrictions.contains(restriction) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .onTapGesture {
                            HapticsManager.shared.selection()
                            if selectedDietaryRestrictions.contains(restriction) {
                                selectedDietaryRestrictions.removeAll { $0 == restriction }
                            } else {
                                selectedDietaryRestrictions.append(restriction)
                            }
                        }
                    }
                } header: {
                    Text("Dietary Restrictions")
                } footer: {
                    Text("Help us filter restaurants and menu items for you")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticsManager.shared.buttonTap()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        HapticsManager.shared.buttonTap()
                        saveProfile()
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
        .alert("Profile Updated", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your profile has been successfully updated.")
        }
    }
    
    private func loadCurrentProfile() {
        guard let user = authManager.currentUser else { return }
        
        firstName = user.profile.firstName
        lastName = user.profile.lastName
        displayName = user.displayName
        selectedHealthGoals = user.profile.healthGoals
        selectedDietaryRestrictions = user.profile.dietaryRestrictions
        activityLevel = user.profile.activityLevel
    }
    
    private func saveProfile() {
        isLoading = true
        
        var updatedProfile = authManager.currentUser?.profile ?? UserProfile()
        updatedProfile.firstName = firstName
        updatedProfile.lastName = lastName
        updatedProfile.healthGoals = selectedHealthGoals
        updatedProfile.dietaryRestrictions = selectedDietaryRestrictions
        updatedProfile.activityLevel = activityLevel
        
        let updatedPreferences = authManager.currentUser?.preferences ?? UserPreferences()
        
        Task {
            await authManager.updateUserProfile(updatedProfile, preferences: updatedPreferences)
            await MainActor.run {
                isLoading = false
                
                // Check if profile is now complete and mark it
                let hasHealthGoals = !selectedHealthGoals.isEmpty
                let hasDietaryRestrictions = !selectedDietaryRestrictions.isEmpty
                
                if hasHealthGoals && hasDietaryRestrictions {
                    ProfileCompletionManager.shared.markProfileAsCompleted()
                    HapticService.shared.profileComplete()
                }
                
                showingSuccessAlert = true
            }
        }
    }
}

#Preview {
    EditProfileView()
}