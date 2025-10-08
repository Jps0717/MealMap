import SwiftUI

struct EnhancedLoadingView: View {
    let loadingState: NutritionDataManager.LoadingState
    let restaurantName: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Loading Animation
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
            
            // Status Text
            VStack(spacing: 8) {
                Text(loadingTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(loadingMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress Indicator
            if showProgressBar {
                ProgressView(value: progressValue)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(maxWidth: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
    
    private var loadingTitle: String {
        switch loadingState {
        case .idle:
            return "Preparing..."
        case .checkingCache:
            return "Checking Cache"
        case .loadingFromAPI:
            return "Loading Data"
        case .retryingAPI:
            return "Retrying..."
        case .loadingFromStatic:
            return "Loading Backup Data"
        case .failed:
            return "Failed to Load"
        case .success:
            return "Success!"
        }
    }
    
    private var loadingMessage: String {
        switch loadingState {
        case .idle:
            return "Getting ready to load nutrition data"
        case .checkingCache:
            return "Looking for cached data first"
        case .loadingFromAPI:
            return "Fetching latest nutrition data for \(restaurantName)"
        case .retryingAPI:
            return "Connection issue detected, trying again"
        case .loadingFromStatic:
            return "Using backup nutrition data"
        case .failed:
            return "Unable to load data from any source"
        case .success:
            return "Nutrition data loaded successfully"
        }
    }
    
    private var showProgressBar: Bool {
        switch loadingState {
        case .retryingAPI, .loadingFromStatic:
            return true
        default:
            return false
        }
    }
    
    private var progressValue: Double {
        switch loadingState {
        case .checkingCache:
            return 0.2
        case .loadingFromAPI:
            return 0.4
        case .retryingAPI:
            return 0.6
        case .loadingFromStatic:
            return 0.8
        case .success:
            return 1.0
        default:
            return 0.0
        }
    }
}

struct FallbackErrorView: View {
    let restaurantName: String
    let errorMessage: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Error Icon
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            // Error Message
            VStack(spacing: 8) {
                Text("Data Unavailable")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Retry Button
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(8)
            }
            
            // Help Text
            Text("We're working to resolve this issue. Please check your internet connection and try again.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}

struct DataSourceIndicator: View {
    let loadingState: NutritionDataManager.LoadingState
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            HStack {
                sourceIcon
                Text(sourceText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(6)
        }
    }
    
    private var sourceIcon: some View {
        Group {
            switch loadingState {
            case .checkingCache:
                Image(systemName: "memorychip")
                    .foregroundColor(.blue)
            case .loadingFromAPI:
                Image(systemName: "cloud")
                    .foregroundColor(.green)
            case .retryingAPI:
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.orange)
            case .loadingFromStatic:
                Image(systemName: "archivebox")
                    .foregroundColor(.purple)
            case .success:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            default:
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
            }
        }
        .font(.caption)
    }
    
    private var sourceText: String {
        switch loadingState {
        case .checkingCache:
            return "Cache"
        case .loadingFromAPI:
            return "Live Data"
        case .retryingAPI:
            return "Retrying"
        case .loadingFromStatic:
            return "Backup Data"
        case .success:
            return "Loaded"
        default:
            return "Unknown"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        EnhancedLoadingView(
            loadingState: .loadingFromAPI,
            restaurantName: "McDonald's"
        )
        
        EnhancedLoadingView(
            loadingState: .retryingAPI,
            restaurantName: "Subway"
        )
        
        FallbackErrorView(
            restaurantName: "Test Restaurant",
            errorMessage: "Unable to load nutrition data. Please check your internet connection.",
            onRetry: {}
        )
        
        DataSourceIndicator(
            loadingState: .loadingFromStatic,
            isVisible: true
        )
    }
    .padding()
}