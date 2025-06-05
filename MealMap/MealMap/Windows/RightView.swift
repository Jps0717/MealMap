import SwiftUI

struct RightView: View {
    // Dummy placeholders – swap with your data/model later
    let bannerColor = Color(.systemGray6)
    let profileImage = Image(systemName: "person.crop.circle.fill")
    let userName = "John Doe"
    let userLocation = "NY"
    let userStatus = "Online"
    let userBio = "Foodie and adventurer."
    let isOnline = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Top Banner
                        ZStack(alignment: .topTrailing) {
                            bannerColor
                                .frame(height: 160)
                                .overlay(
                                    // Profile image, bottom left of banner
                                    profileImage
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 90, height: 90)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                        .shadow(radius: 7, y: 4)
                                        .offset(x: 23, y: 0)
                                    , alignment: .bottomLeading
                                )
                            
                            // Settings & Edit icons
                            HStack(spacing: 14) {
                                Button(action: { /* open settings */ }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 25, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .padding(10)
                                        .background(.ultraThinMaterial, in: Circle())
                                }
                                Button(action: { /* profile action */ }) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 25, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .padding(10)
                                        .background(.ultraThinMaterial, in: Circle())
                                }
                            }
                            .padding(.top, 0)
                            .padding(.trailing, 16)
                        }
                        .frame(height: 150)
                        .padding(.bottom, 28) // For profile overlap

                        // Name & status
                        HStack(alignment: .center, spacing: 14) {
                            Spacer()
                                .frame(width: 110) // To align with profile image

                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(userName), \(userLocation)")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.primary)
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(isOnline ? Color.green : Color.gray)
                                        .frame(width: 10, height: 10)
                                    Text(userStatus)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, -100)
                        .padding(.bottom, 20)

                        // Bio Section
                        ProfileSectionView(
                            title: "About",
                            content: AnyView(
                                Text(userBio)
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            )
                        )

                        // Settings Options
                        ProfileSectionView(
                            title: "Settings",
                            content: AnyView(
                                VStack(spacing: 0) {
                                    SettingsRowView(icon: "bell", title: "Notifications", hasArrow: true)
                                    Divider().padding(.leading, 40)
                                    SettingsRowView(icon: "lock", title: "Privacy", hasArrow: true)
                                    Divider().padding(.leading, 40)
                                    SettingsRowView(icon: "questionmark.circle", title: "Help & Support", hasArrow: true)
                                    Divider().padding(.leading, 40)
                                    SettingsRowView(icon: "rectangle.portrait.and.arrow.right", title: "Sign Out", hasArrow: false, textColor: .red)
                                }
                            )
                        )

                        Spacer(minLength: 100)
                    }
                }
            }
            .preferredColorScheme(.light) // Force light mode
        }
    }
}

// MARK: - Supporting Views

struct ProfileSectionView: View {
    let title: String
    let content: AnyView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            content
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    let hasArrow: Bool
    var textColor: Color = .primary
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColor)
            
            Spacer()
            
            if hasArrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            // Handle tap
        }
    }
}

struct RightView_Previews: PreviewProvider {
    static var previews: some View {
        RightView()
    }
}
