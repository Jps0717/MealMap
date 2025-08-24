import SwiftUI
import Foundation
import CoreLocation

// MARK: - Carousel Item Model
struct CarouselItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let backgroundColor: Color
    let action: () -> Void
}

// MARK: - Auto Sliding Carousel
struct AutoSlidingCarousel: View {
    @Binding var showingMenuPhotoCapture: Bool
    @Binding var showingMapScreen: Bool
    @Binding var showingDietaryChat: Bool
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @State private var isActive = true // Track if view is active
    
    @AppStorage("mealChatEnergy") private var mealChatEnergy: Int = 3
    @AppStorage("lastChatReset") private var lastChatReset: Date = Date()
    
    private let autoSlideInterval: TimeInterval = 3.0 // 3 seconds
    
    private func updateMealChatEnergy() -> Bool {
        let now = Date()
        let isYesterday = Calendar.current.isDateInYesterday(lastChatReset)
        let isBeforeToday = Calendar.current.compare(lastChatReset, to: now, toGranularity: .day) == .orderedAscending
        
        if isYesterday || isBeforeToday {
            mealChatEnergy = 3
            lastChatReset = now
        }
        
        if mealChatEnergy > 0 {
            mealChatEnergy -= 1
            return true
        }
        return false
    }
    
    private func getEnergyState() -> (subtitle: String, iconColor: Color, backgroundColor: Color) {
        let now = Date()
        let isYesterday = Calendar.current.isDateInYesterday(lastChatReset)
        let isBeforeToday = Calendar.current.compare(lastChatReset, to: now, toGranularity: .day) == .orderedAscending
        
        if isYesterday || isBeforeToday {
            mealChatEnergy = 3
        }
        
        if mealChatEnergy > 0 {
            return (
                subtitle: "Get personalized nutrition advice",
                iconColor: .purple,
                backgroundColor: Color.purple.opacity(0.1)
            )
        } else {
            return (
                subtitle: "Come back tomorrow!",
                iconColor: .gray,
                backgroundColor: Color.gray.opacity(0.1)
            )
        }
    }
    
    var carouselItems: [CarouselItem] {
        var items: [CarouselItem] = [
            CarouselItem(
                id: 0,
                title: "Scan Menu",
                subtitle: "Analyze nutrition from photos",
                icon: "camera.fill",
                iconColor: .blue,
                backgroundColor: Color.blue.opacity(0.1),
                action: {
                    print("🎯 Scan Menu action triggered")
                    // HapticService.shared.menuScan()
                    showingMenuPhotoCapture = true
                }
            ),
            CarouselItem(
                id: 1,
                title: "Meal Map",
                subtitle: "Find restaurants near you",
                icon: "map.fill",
                iconColor: .green,
                backgroundColor: Color.green.opacity(0.1),
                action: {
                    print("🎯 Meal Map action triggered")
                    // HapticService.shared.navigate()
                    showingMapScreen = true
                }
            )
        ]
        
        let energyState = getEnergyState()
        items.append(CarouselItem(
            id: 2,
            title: "Meal Chat (\(max(0, mealChatEnergy))/3)",
            subtitle: energyState.subtitle,
            icon: "message.circle.fill",
            iconColor: energyState.iconColor,
            backgroundColor: energyState.backgroundColor,
            action: {
                print("🎯 Meal Chat action triggered")
                if updateMealChatEnergy() {
                    // HapticService.shared.sheetPresent()
                    showingDietaryChat = true
                } else {
                    // Optionally show alert about energy limit
                    print("🎯 Meal Chat energy limit reached")
                }
            }
        ))
        
        return items
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Carousel Container
            ZStack {
                TabView(selection: $currentIndex) {
                    ForEach(carouselItems, id: \.id) { item in
                        CarouselItemView(item: item)
                            .tag(item.id)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 100)
                .onChange(of: currentIndex) { oldValue, newValue in
                    // Handle manual swipe - restart timer from new position
                    if oldValue != newValue && isActive {
                        restartTimer()
                    }
                }
            }
            .clipped()
            
            // Custom Page Indicators
            HStack(spacing: 8) {
                ForEach(0..<carouselItems.count, id: \.self) { index in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentIndex = index
                        }
                        restartTimer()
                    }) {
                        Circle()
                            .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    }
                }
            }
            .padding(.top, 12)
        }
        .onAppear {
            isActive = true
            startAutoSlide()
            // Reset energy if a day has passed
            let now = Date()
            let isYesterday = Calendar.current.isDateInYesterday(lastChatReset)
            let isBeforeToday = Calendar.current.compare(lastChatReset, to: now, toGranularity: .day) == .orderedAscending
            
            if isYesterday || isBeforeToday {
                mealChatEnergy = 3
                lastChatReset = now
            }
        }
        .onDisappear {
            isActive = false
            stopAutoSlide()
        }
        // Add additional safety for when app goes to background
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            stopAutoSlide()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if isActive {
                startAutoSlide()
                // Reset energy if a day has passed
                let now = Date()
                let isYesterday = Calendar.current.isDateInYesterday(lastChatReset)
                let isBeforeToday = Calendar.current.compare(lastChatReset, to: now, toGranularity: .day) == .orderedAscending
                
                if isYesterday || isBeforeToday {
                    mealChatEnergy = 3
                    lastChatReset = now
                }
            }
        }
    }
    
    private func startAutoSlide() {
        // Ensure we don't have multiple timers
        stopAutoSlide()
        
        timer = Timer.scheduledTimer(withTimeInterval: autoSlideInterval, repeats: true) { _ in
            guard isActive else {
                stopAutoSlide()
                return
            }
            
            withAnimation(.easeInOut(duration: 0.5)) {
                moveToNextIndex()
            }
        }
    }
    
    private func stopAutoSlide() {
        timer?.invalidate()
        timer = nil
    }
    
    private func restartTimer() {
        guard isActive else { return }
        stopAutoSlide()
        // Add small delay to prevent immediate restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.isActive {
                self.startAutoSlide()
            }
        }
    }
    
    private func moveToNextIndex() {
        currentIndex = (currentIndex + 1) % carouselItems.count
    }
}

// MARK: - Carousel Item View
struct CarouselItemView: View {
    let item: CarouselItem
    
    var body: some View {
        Button(action: item.action) {
            HStack {
                Image(systemName: item.icon)
                    .foregroundColor(item.iconColor)
                    .font(.title2)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding()
            .background(item.backgroundColor)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HomeScreen: View {
    @State private var showingMenuPhotoCapture = false
    @State private var showingMapScreen = false
    @State private var showingDietaryChat = false
    @State private var showingProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome to MealMap")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Discover healthy dining options near you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Auto sliding carousel
                    AutoSlidingCarousel(
                        showingMenuPhotoCapture: $showingMenuPhotoCapture,
                        showingMapScreen: $showingMapScreen,
                        showingDietaryChat: $showingDietaryChat
                    )
                    .padding(.horizontal)
                    
                    // Quick actions grid
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Actions")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            QuickActionButton(
                                icon: "camera.fill",
                                title: "Scan Menu",
                                color: .blue
                            ) {
                                showingMenuPhotoCapture = true
                            }
                            
                            QuickActionButton(
                                icon: "map.fill",
                                title: "Find Restaurants",
                                color: .green
                            ) {
                                showingMapScreen = true
                            }
                            
                            QuickActionButton(
                                icon: "message.fill",
                                title: "Meal Chat",
                                color: .purple
                            ) {
                                showingDietaryChat = true
                            }
                            
                            QuickActionButton(
                                icon: "person.fill",
                                title: "My Profile",
                                color: .orange
                            ) {
                                showingProfile = true
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Food categories
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Categories")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        // Placeholder for category items
                        // You can replace this with actual category views
                        VStack(spacing: 12) {
                            ForEach(0..<6) { index in
                                HStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Category \(index + 1)")
                                            .font(.headline)
                                        Text("Description for category \(index + 1)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            
            // Sheets and navigation
            .sheet(isPresented: $showingMenuPhotoCapture) {
                MenuPhotoCaptureView()
            }
            .sheet(isPresented: $showingMapScreen) {
                MapScreen()
            }
            .sheet(isPresented: $showingDietaryChat) {
                DietaryChatView()
            }
            .sheet(isPresented: $showingProfile) {
                EditProfileView()
            }
        }
    }
}

// MARK: - Food Type Category View
struct FoodTypeCategoryView: View {
    // You'll need to provide these properties based on your implementation
    @State private var hasValidLocation: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var restaurants: [HomeScreenRestaurant] = [] // Using different name to avoid conflicts
    
    // You'll need to define this based on your implementation
    let foodType: HomeScreenFoodType // Using different name to avoid conflicts
    
    var body: some View {
        // Your body implementation
        Text("Food Type Category View")
    }
    
    private func loadRestaurants() {
        // You'll need to implement this based on your implementation
        // This is just a placeholder showing the structure
    }
}

// Placeholder models - you'll need to replace these with your actual models
struct HomeScreenRestaurant: Identifiable {
    let id = UUID()
    let name: String
    let cuisine: String?
    
    func distanceFrom(_ coordinate: CLLocationCoordinate2D) -> Double {
        // Implementation needed
        return 0.0
    }
}

struct HomeScreenFoodType {
    let searchTerms: [String]
}

#Preview {
    HomeScreen()
}
