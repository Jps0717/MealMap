import SwiftUI

struct NutritionixSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var nutritionixService = NutritionixAPIService.shared
    @StateObject private var authManager = AuthenticationManager.shared
    
    @State private var showingAPIKeySetup = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            List {
                // User Information Section
                Section {
                    if let user = authManager.currentUser {
                        Group {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.displayName.isEmpty ? "Guest" : user.displayName)
                                        .font(.headline)
                                    
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            
                            if !user.profile.fullName.isEmpty {
                                HStack {
                                    Text("Full Name")
                                    Spacer()
                                    Text(user.profile.fullName)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Text("Member Since")
                                Spacer()
                                Text(user.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                            }
                            
                            if !user.profile.healthGoals.isEmpty {
                                HStack {
                                    Text("Health Goals")
                                    Spacer()
                                    Text("\(user.profile.healthGoals.count) selected")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if !user.profile.dietaryRestrictions.isEmpty {
                                HStack {
                                    Text("Dietary Restrictions")
                                    Spacer()
                                    Text("\(user.profile.dietaryRestrictions.count) selected")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Button("Edit Profile") {
                                showingEditProfile = true
                            }
                            .foregroundColor(.blue)
                            
                            Button("Sign Out") {
                                authManager.signOut()
                                dismiss()
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        // This case should ideally not be reached with the guest user setup
                        Group {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Not Signed In")
                                        .font(.headline)
                                    
                                    Text("Sign in to sync your preferences")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "person.circle")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                            
                            Button("Sign In") {
                                // This button is now defunct
                            }
                            .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("Account")
                }
                
                // API Credentials Status Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Credentials Status")
                                .font(.headline)
                            
                            Text(nutritionixService.isAPICredentialsConfigured ? "Configured" : "Not configured")
                                .font(.subheadline)
                                .foregroundColor(nutritionixService.isAPICredentialsConfigured ? .green : .orange)
                        }
                        
                        Spacer()
                        
                        Image(systemName: nutritionixService.isAPICredentialsConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(nutritionixService.isAPICredentialsConfigured ? .green : .orange)
                    }
                    
                    if nutritionixService.isAPICredentialsConfigured {
                        HStack {
                            Text("App ID")
                            Spacer()
                            if let appId = nutritionixService.userAppID {
                                Text(String(appId.prefix(8)) + "...")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        HStack {
                            Text("API Key")
                            Spacer()
                            if let apiKey = nutritionixService.userAPIKey {
                                Text(String(apiKey.prefix(8)) + "...")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        Button("Update Credentials") {
                            showingAPIKeySetup = true
                        }
                        .foregroundColor(.blue)
                    } else {
                        Button("Set up Credentials") {
                            showingAPIKeySetup = true
                        }
                        .foregroundColor(.blue)
                    }
                } header: {
                    Text("Configuration")
                } footer: {
                    Text("Your Nutritionix App ID and API Key are stored securely on your device and work together as a pair.")
                }
                
                // Usage Statistics Section
                if nutritionixService.isAPICredentialsConfigured {
                    Section {
                        HStack {
                            Text("Today's Usage")
                            Spacer()
                            Text(nutritionixService.dailyUsageString)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Remaining Requests")
                            Spacer()
                            Text("\(nutritionixService.remainingDailyRequests)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Total Requests Made")
                            Spacer()
                            Text("\(nutritionixService.requestCount)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Usage Statistics")
                    } footer: {
                        Text("Daily limits reset at midnight. The free tier includes 150 requests per day.")
                    }
                }
                
                // Danger Zone
                if nutritionixService.isAPICredentialsConfigured {
                    Section {
                        Button("Remove Credentials") {
                            showingDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                    } header: {
                        Text("Danger Zone")
                    } footer: {
                        Text("Removing your credentials will disable nutrition analysis until you add new ones.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAPIKeySetup) {
            NutritionixAPIKeySetupView()
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .alert("Remove API Credentials", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                nutritionixService.clearAPICredentials()
            }
        } message: {
            Text("Are you sure you want to remove your Nutritionix API credentials? This will disable nutrition analysis until you add new credentials.")
        }
    }
}

#Preview {
    NutritionixSettingsView()
}