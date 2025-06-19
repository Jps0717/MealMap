import SwiftUI

// MARK: - Reusable Loading Components

struct LoadingView: View {
    let title: String
    let subtitle: String?
    let progress: Double?
    let style: LoadingStyle
    
    init(
        title: String = "Loading...",
        subtitle: String? = nil,
        progress: Double? = nil,
        style: LoadingStyle = .overlay
    ) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .overlay:
            overlayStyle
        case .inline:
            inlineStyle
        case .fullScreen:
            fullScreenStyle
        case .compact:
            compactStyle
        }
    }
    
    // MARK: - Loading Styles
    
    private var overlayStyle: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if let progress = progress {
                    CircularProgressView(progress: progress)
                } else {
                    ProgressView()
                        .scaleEffect(2.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.blue)
                    .shadow(radius: 10)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
    }
    
    private var inlineStyle: some View {
        VStack(spacing: 16) {
            if let progress = progress {
                CircularProgressView(progress: progress, size: .medium)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(minHeight: 120)
    }
    
    private var fullScreenStyle: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if let progress = progress {
                CircularProgressView(progress: progress, size: .large)
            } else {
                ProgressView()
                    .scaleEffect(2.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var compactStyle: some View {
        HStack(spacing: 8) {
            if let progress = progress {
                CircularProgressView(progress: progress, size: .small)
            } else {
                ProgressView()
                    .scaleEffect(0.6)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            }
            
            if !title.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            } else {
                // For title-less compact loading (like CategoryCard)
                Text("loading...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, title.isEmpty ? 8 : 16)
        .padding(.vertical, title.isEmpty ? 4 : 12)
        .background(
            RoundedRectangle(cornerRadius: title.isEmpty ? 8 : 12)
                .fill(title.isEmpty ? Color.clear : Color(.systemGray6))
        )
    }
}

// MARK: - Custom Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let size: ProgressSize
    
    init(progress: Double, size: ProgressSize = .medium) {
        self.progress = progress
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4), lineWidth: size.lineWidth)
                .frame(width: size.diameter, height: size.diameter)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: size.lineWidth, lineCap: .round)
                )
                .frame(width: size.diameter, height: size.diameter)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            
            if size != .small {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size.fontSize, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Supporting Types

enum LoadingStyle {
    case overlay    // Dark overlay with loading indicator
    case inline     // Inline loading for sections
    case fullScreen // Full screen loading
    case compact    // Compact horizontal loading
}

enum ProgressSize {
    case small, medium, large
    
    var diameter: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 40
        case .large: return 60
        }
    }
    
    var lineWidth: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 12
        case .large: return 16
        }
    }
}

// MARK: - Specialized Loading Views

struct DataLoadingView: View {
    let dataType: String
    let progress: Double?
    
    var body: some View {
        LoadingView(
            title: "Loading \(dataType)...",
            subtitle: "This may take a moment",
            progress: progress,
            style: .inline
        )
    }
}

struct SearchLoadingView: View {
    let searchQuery: String
    
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            Text("Searching for '\(searchQuery)'...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.blue.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct RestaurantLoadingView: View {
    let restaurantName: String
    let progress: Double?
    
    init(restaurantName: String, progress: Double? = nil) {
        self.restaurantName = restaurantName
        self.progress = progress
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Restaurant icon with loading animation
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                if let progress = progress {
                    CircularProgressView(progress: progress, size: .large)
                } else {
                    ProgressView()
                        .scaleEffect(2.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                }
                
                VStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                        .opacity(0.7)
                }
                .offset(y: -8)
            }
            
            VStack(spacing: 12) {
                Text("Loading Menu")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Getting nutrition data for \(restaurantName)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                if let progress = progress {
                    Text("\(Int(progress * 100))% complete")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                } else {
                    Text("This may take a moment...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct MenuLoadingIndicator: View {
    let itemCount: Int?
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Loading menu items...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let count = itemCount {
                    Text("Found \(count) items")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Text("Parsing nutrition data")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct MapDataLoadingView: View {
    let progress: Double
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color(.systemBackground).opacity(0.9), lineWidth: 3)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                    
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    
                    Image(systemName: "map")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 120)
            }
        }
        .allowsHitTesting(false)
        .zIndex(2)
    }
}

struct CategoryLoadingView: View {
    let category: RestaurantCategory
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: category.color))
            
            VStack(spacing: 4) {
                Text("Loading \(category.rawValue)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Finding restaurants near you...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview("Overlay Loading") {
    ZStack {
        Color.gray.opacity(0.3)
        
        LoadingView(
            title: "Loading Restaurants...",
            subtitle: "Finding the best options near you",
            progress: 0.65,
            style: .overlay
        )
    }
}

#Preview("Inline Loading") {
    VStack {
        Text("Some Content")
        
        LoadingView(
            title: "Loading Data...",
            subtitle: "Please wait",
            progress: 0.4,
            style: .inline
        )
        
        Text("More Content")
    }
}
