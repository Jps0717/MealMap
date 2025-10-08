import SwiftUI
import UIKit

// MARK: - Dynamic Sizing System
struct DynamicSizing {
    // Screen size categories
    enum ScreenSize {
        case small      // iPhone SE, iPhone 12/13 mini
        case regular    // iPhone 12/13/14, iPhone 15
        case large      // iPhone 12/13/14 Plus, iPhone 15 Plus  
        case extraLarge // iPhone 12/13/14/15 Pro Max
        case iPad       // iPad sizes
        
        static var current: ScreenSize {
            let width = UIScreen.main.bounds.width
            let height = UIScreen.main.bounds.height
            let maxDimension = max(width, height)
            
            // Check if it's an iPad based on size
            if maxDimension >= 1000 {
                return .iPad
            }
            
            switch width {
            case ...380:
                return .small
            case 381...400:
                return .regular
            case 401...430:
                return .large
            default:
                return .extraLarge
            }
        }
    }
    
    // Content size categories
    enum ContentDensity {
        case compact
        case comfortable
        case spacious
        
        static var preferred: ContentDensity {
            let contentSize = UIApplication.shared.preferredContentSizeCategory
            switch contentSize {
            case .extraSmall, .small, .medium:
                return .compact
            case .large, .extraLarge, .extraExtraLarge:
                return .comfortable
            default:
                return .spacious
            }
        }
    }
    
    // Check if we're running on iPad
    static var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // Dynamic spacing values with more aggressive iPad scaling
    static func spacing(_ base: CGFloat, geometry: GeometryProxy? = nil) -> CGFloat {
        let screenMultiplier = screenSizeMultiplier()
        let contentMultiplier = contentSizeMultiplier()
        
        var dynamicSpacing = base * screenMultiplier * contentMultiplier
        
        // Further adjust based on available width if geometry is provided
        if let geometry = geometry {
            let baseWidth: CGFloat = isIPad ? 768 : 390 // iPad vs iPhone base width
            let widthRatio = geometry.size.width / baseWidth
            
            if isIPad {
                // More generous spacing scaling on iPad
                dynamicSpacing *= min(max(widthRatio * 1.2, 1.0), 2.5)
            } else {
                // Conservative scaling on iPhone
                dynamicSpacing *= min(max(widthRatio, 0.8), 1.3)
            }
        }
        
        return dynamicSpacing
    }
    
    // Dynamic font scaling
    static func fontSize(_ base: CGFloat) -> CGFloat {
        let contentMultiplier = contentSizeMultiplier()
        let iPadMultiplier: CGFloat = isIPad ? 1.1 : 1.0 // Slightly larger fonts on iPad
        return base * contentMultiplier * iPadMultiplier
    }
    
    // Dynamic card/component dimensions
    static func cardHeight(_ base: CGFloat, geometry: GeometryProxy? = nil) -> CGFloat {
        let screenMultiplier = screenSizeMultiplier()
        let contentMultiplier = contentSizeMultiplier()
        
        var height = base * screenMultiplier * contentMultiplier
        
        if let geometry = geometry {
            // Scale based on available height
            let baseHeight: CGFloat = isIPad ? 1024 : 844 // iPad vs iPhone base height
            let heightRatio = geometry.size.height / baseHeight
            height *= min(max(heightRatio, 0.8), 1.2)
        }
        
        return height
    }
    
    static func cardWidth(_ base: CGFloat, geometry: GeometryProxy? = nil) -> CGFloat {
        let screenMultiplier = screenSizeMultiplier()
        
        var width = base * screenMultiplier
        
        if let geometry = geometry {
            let baseWidth: CGFloat = isIPad ? 768 : 390
            let widthRatio = geometry.size.width / baseWidth
            width *= min(max(widthRatio, 0.8), isIPad ? 2.0 : 1.3) // Allow more scaling on iPad
        }
        
        return width
    }
    
    // Enhanced grid column count with better iPad support
    static func gridColumns(baseColumns: Int, geometry: GeometryProxy) -> Int {
        let availableWidth = geometry.size.width - (isIPad ? 80 : 40) // More padding on iPad
        
        if isIPad {
            // iPad: More sophisticated column calculation
            let minColumnWidth: CGFloat = 160
            let maxColumns = Int(availableWidth / minColumnWidth)
            
            // Scale based on screen width
            let screenWidth = geometry.size.width
            if screenWidth > 1200 {
                return max(1, min(maxColumns, baseColumns * 4)) // Very wide iPads
            } else if screenWidth > 1000 {
                return max(1, min(maxColumns, baseColumns * 3)) // Regular iPad Pro
            } else {
                return max(1, min(maxColumns, baseColumns * 2)) // iPad mini/Air
            }
        } else {
            // iPhone: Conservative approach
            let minColumnWidth: CGFloat = 140
            let maxColumns = Int(availableWidth / minColumnWidth)
            return max(1, min(maxColumns, baseColumns * 2))
        }
    }
    
    // Responsive icon size
    static func iconSize(_ base: CGFloat) -> CGFloat {
        let screenMultiplier = screenSizeMultiplier()
        let contentMultiplier = contentSizeMultiplier()
        return base * screenMultiplier * contentMultiplier
    }
    
    // Dynamic corner radius
    static func cornerRadius(_ base: CGFloat) -> CGFloat {
        let screenMultiplier = screenSizeMultiplier()
        return base * screenMultiplier
    }
    
    // Enhanced content width with better iPad optimization
    static func contentWidth(geometry: GeometryProxy) -> CGFloat? {
        if isIPad {
            let screenWidth = geometry.size.width
            
            if screenWidth > 1200 {
                // Very large iPads: Use 85% of width with max of 1100pt
                return min(screenWidth * 0.85, 1100)
            } else if screenWidth > 1000 {
                // Large iPads: Use 90% of width with max of 950pt  
                return min(screenWidth * 0.90, 950)
            } else {
                // Smaller iPads: Use 95% of width
                return screenWidth * 0.95
            }
        }
        return nil // Use full width on iPhone
    }
    
    // Safe area top padding for different devices
    static func safeAreaTopPadding() -> CGFloat {
        if isIPad {
            return 0 // iPad handles its own safe area
        } else {
            // iPhone: Check if device has notch/Dynamic Island
            let hasNotch = UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0 > 20
            return hasNotch ? 10 : 20 // Less padding for devices with notch
        }
    }
    
    // Content top offset for scrollable content
    static func contentTopOffset(geometry: GeometryProxy) -> CGFloat {
        if isIPad {
            return 0
        } else {
            // iPhone: Account for safe area
            let safeAreaTop = geometry.safeAreaInsets.top
            return safeAreaTop > 0 ? max(safeAreaTop - 20, 0) : 20
        }
    }
    
    // MARK: - Private Helpers
    private static func screenSizeMultiplier() -> CGFloat {
        switch ScreenSize.current {
        case .small:
            return 0.85  // Smaller scaling for compact devices
        case .regular:
            return 1.0   // Baseline
        case .large:
            return 1.15  // Slightly larger for Plus models
        case .extraLarge:
            return 1.25  // Larger for Pro Max
        case .iPad:
            // Enhanced iPad scaling based on actual screen size
            let screenWidth = UIScreen.main.bounds.width
            if screenWidth > 1200 {
                return 1.6   // Large iPad Pro
            } else if screenWidth > 1000 {
                return 1.4   // Regular iPad Pro  
            } else {
                return 1.3   // iPad Air/mini
            }
        }
    }
    
    private static func contentSizeMultiplier() -> CGFloat {
        switch ContentDensity.preferred {
        case .compact:
            return 0.95
        case .comfortable:
            return 1.0
        case .spacious:
            return 1.15
        }
    }
}

// MARK: - SwiftUI Modifiers for Dynamic Sizing
extension View {
    func dynamicFont(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: DynamicSizing.fontSize(baseSize), weight: weight))
    }
    
    func dynamicPadding(_ base: CGFloat = 16) -> some View {
        GeometryReader { geometry in
            self.padding(DynamicSizing.spacing(base, geometry: geometry))
        }
    }
    
    func dynamicCornerRadius(_ base: CGFloat = 12) -> some View {
        self.cornerRadius(DynamicSizing.cornerRadius(base))
    }
    
    func responsiveFrame(
        minWidth: CGFloat? = nil,
        idealWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        idealHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil
    ) -> some View {
        GeometryReader { geometry in
            self.frame(
                minWidth: minWidth.map { DynamicSizing.cardWidth($0, geometry: geometry) },
                idealWidth: idealWidth.map { DynamicSizing.cardWidth($0, geometry: geometry) },
                maxWidth: maxWidth.map { DynamicSizing.cardWidth($0, geometry: geometry) },
                minHeight: minHeight.map { DynamicSizing.cardHeight($0, geometry: geometry) },
                idealHeight: idealHeight.map { DynamicSizing.cardHeight($0, geometry: geometry) },
                maxHeight: maxHeight.map { DynamicSizing.cardHeight($0, geometry: geometry) }
            )
        }
    }
}

// MARK: - Dynamic Size Classes
struct ResponsiveGrid<Content: View>: View {
    let baseColumns: Int
    let spacing: CGFloat
    let content: () -> Content
    
    init(
        baseColumns: Int = 2,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.baseColumns = baseColumns
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            let columns = DynamicSizing.gridColumns(baseColumns: baseColumns, geometry: geometry)
            let dynamicSpacing = DynamicSizing.spacing(spacing, geometry: geometry)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: dynamicSpacing), count: columns),
                spacing: dynamicSpacing
            ) {
                content()
            }
        }
    }
}

// MARK: - Adaptive Card Components
struct DynamicCard<Content: View>: View {
    let content: () -> Content
    private let baseHeight: CGFloat
    private let adaptToContent: Bool
    
    init(
        height: CGFloat = 120,
        adaptToContent: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.baseHeight = height
        self.adaptToContent = adaptToContent
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            content()
                .frame(
                    maxWidth: .infinity,
                    minHeight: adaptToContent ? nil : DynamicSizing.cardHeight(baseHeight, geometry: geometry),
                    idealHeight: adaptToContent ? nil : DynamicSizing.cardHeight(baseHeight, geometry: geometry)
                )
                .background(
                    RoundedRectangle(cornerRadius: DynamicSizing.cornerRadius(16))
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: .black.opacity(0.08),
                            radius: DynamicSizing.spacing(8, geometry: geometry),
                            y: DynamicSizing.spacing(2, geometry: geometry)
                        )
                )
        }
    }
}

// MARK: - Responsive Icon Container
struct DynamicIconContainer: View {
    let systemName: String
    let color: Color
    let backgroundColor: Color
    let baseSize: CGFloat
    
    init(
        systemName: String,
        color: Color = .blue,
        backgroundColor: Color = .blue.opacity(0.1),
        baseSize: CGFloat = 60
    ) {
        self.systemName = systemName
        self.color = color
        self.backgroundColor = backgroundColor
        self.baseSize = baseSize
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = DynamicSizing.iconSize(baseSize)
            let iconSize = DynamicSizing.iconSize(baseSize * 0.4)
            
            ZStack {
                RoundedRectangle(cornerRadius: DynamicSizing.cornerRadius(16))
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                
                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundColor(color)
            }
        }
    }
}