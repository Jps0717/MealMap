import SwiftUI

struct NutritionixSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var nutritionixService = NutritionixAPIService.shared
    
    @State private var showingAPIKeySetup = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
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
                
                // Account Information Section
                Section {
                    Link(destination: URL(string: "https://developer.nutritionix.com/")!) {
                        Label("Nutritionix Developer Portal", systemImage: "link")
                    }
                    
                    Link(destination: URL(string: "https://www.nutritionix.com/business/api")!) {
                        Label("View Pricing Plans", systemImage: "creditcard")
                    }
                    
                    Link(destination: URL(string: "https://docs.google.com/document/d/1_q-K-ObMTZvO0qUEAxROrN3bwMujwAN25sLHwJzliK0/edit")!) {
                        Label("API Documentation", systemImage: "book")
                    }
                } header: {
                    Text("Resources")
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
            .navigationTitle("Nutritionix Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAPIKeySetup) {
            NutritionixAPIKeySetupView()
        }
        .confirmationDialog(
            "Remove API Key",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                nutritionixService.clearAPICredentials()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove your Nutritionix credentials? This will disable nutrition analysis until you add new ones.")
        }
    }
}

#Preview {
    NutritionixSettingsView()
}