import SwiftUI

struct CacheStatusView: View {
    @StateObject private var enhancedCache = EnhancedCacheManager.shared
    @State private var stats = EnhancedCacheStats(
        memoryRestaurantAreas: 0,
        memoryNutritionItems: 0,
        memorySearchResults: 0,
        memoryAPIResponses: 0,
        totalMemoryRestaurants: 0,
        activePreloadTasks: 0,
        cacheHitRate: 0.0
    )
    @State private var showingDetailedStats = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Compact Cache Status
            HStack(spacing: 12) {
                // Cache hit rate indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(cacheHealthColor)
                        .frame(width: 8, height: 8)
                    
                    Text("Cache")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(stats.cacheHitRate * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(cacheHealthColor)
                }
                
                Divider()
                    .frame(height: 16)
                
                // Restaurant count
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    
                    Text("\(stats.totalMemoryRestaurants)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                // Nutrition count
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    
                    Text("\(stats.memoryNutritionItems)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                // Preload tasks
                if stats.activePreloadTasks > 0 {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        
                        Text("\(stats.activePreloadTasks)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showingDetailedStats = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            )
        }
        .onAppear {
            updateStats()
            startPeriodicUpdates()
        }
        .sheet(isPresented: $showingDetailedStats) {
            DetailedCacheStatsView(stats: stats)
        }
    }
    
    private var cacheHealthColor: Color {
        if stats.cacheHitRate >= 0.8 {
            return .green
        } else if stats.cacheHitRate >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func updateStats() {
        stats = enhancedCache.getEnhancedCacheStats()
    }
    
    private func startPeriodicUpdates() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            updateStats()
        }
    }
}

struct DetailedCacheStatsView: View {
    let stats: EnhancedCacheStats
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall Performance
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.blue)
                            Text("Performance")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Cache Hit Rate")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.1f", stats.cacheHitRate * 100))%")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            CacheCircularProgressView(
                                progress: stats.cacheHitRate,
                                color: stats.cacheHitRate >= 0.8 ? .green : .orange
                            )
                            .frame(width: 60, height: 60)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Memory Cache
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "memorychip")
                                .foregroundColor(.purple)
                            Text("Memory Cache")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            StatCard(
                                title: "Restaurant Areas",
                                value: "\(stats.memoryRestaurantAreas)",
                                icon: "map",
                                color: .blue
                            )
                            
                            StatCard(
                                title: "Total Restaurants",
                                value: "\(stats.totalMemoryRestaurants)",
                                icon: "fork.knife",
                                color: .green
                            )
                            
                            StatCard(
                                title: "Nutrition Items",
                                value: "\(stats.memoryNutritionItems)",
                                icon: "chart.bar.fill",
                                color: .orange
                            )
                            
                            StatCard(
                                title: "API Responses",
                                value: "\(stats.memoryAPIResponses)",
                                icon: "network",
                                color: .red
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Background Tasks
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "gearshape.2")
                                .foregroundColor(.indigo)
                            Text("Background Tasks")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Active Preload Tasks")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(stats.activePreloadTasks)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            if stats.activePreloadTasks > 0 {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Cache Tips
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                            Text("Optimization Tips")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            if stats.cacheHitRate < 0.7 {
                                TipRow(
                                    icon: "arrow.clockwise",
                                    text: "Low cache hit rate. Try staying in the same area longer.",
                                    color: .orange
                                )
                            }
                            
                            if stats.totalMemoryRestaurants > 5000 {
                                TipRow(
                                    icon: "memorychip",
                                    text: "High memory usage. Cache will auto-clean soon.",
                                    color: .red
                                )
                            }
                            
                            if stats.activePreloadTasks == 0 {
                                TipRow(
                                    icon: "checkmark.circle",
                                    text: "All preloading complete. Fast access ready!",
                                    color: .green
                                )
                            }
                            
                            TipRow(
                                icon: "info.circle",
                                text: "Cache automatically manages size and expiry for optimal performance.",
                                color: .blue
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Cache Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

struct CacheCircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    CacheStatusView()
}
