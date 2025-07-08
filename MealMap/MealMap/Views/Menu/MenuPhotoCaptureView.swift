import SwiftUI

// MARK: - Image Processing State
enum ImageProcessingState {
    case idle
    case uploading
    case analyzing
    case error(String)
    
    var isProcessing: Bool {
        switch self {
        case .uploading, .analyzing:
            return true
        default:
            return false
        }
    }
}

struct MenuPhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ocrService = MenuOCRService()
    @StateObject private var nutritionixService = NutritionixAPIService.shared // For usage tracking and API key management
    @StateObject private var savedMenuManager = SavedMenuManager.shared // Add saved menu manager
    
    @State private var processingState: ImageProcessingState = .idle
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false // Separate state for photo library
    @State private var showingResults = false
    @State private var validatedItems: [ValidatedMenuItem] = []
    @State private var processingMethod: ProcessingMethod = .aiNutritionix // Default to AI + Nutritionix
    @State private var showingAdvancedSettings = false // For settings sheet
    @State private var showingAPIKeyErrorPopup = false // For custom error popup
    @State private var currentProcessingTask: Task<Void, Never>? // Track processing task for cancellation
    @State private var selectedSavedMenu: SavedMenuAnalysis? = nil // For saved menu detail view

    let autoTriggerCamera: Bool
    let autoTriggerPhotos: Bool
    
    init(autoTriggerCamera: Bool = false, autoTriggerPhotos: Bool = false) {
        self.autoTriggerCamera = autoTriggerCamera
        self.autoTriggerPhotos = autoTriggerPhotos
    }
    
    enum ProcessingMethod: String, CaseIterable {
        case aiNutritionix = "ai_nutritionix"    // Only nutrition analysis option
        
        var displayName: String {
            switch self {
            case .aiNutritionix: return "Menu Analysis"
            }
        }
        
        var description: String {
            switch self {
            case .aiNutritionix: return "AI menu parsing with nutrition data analysis"
            }
        }
        
        var emoji: String {
            switch self {
            case .aiNutritionix: return "📱🍽️"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                switch processingState {
                case .idle:
                    idleStateView
                case .uploading, .analyzing:
                    processingStateView
                case .error(let message):
                    errorStateView(message: message)
                }
            }
            .navigationTitle("Menu Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if processingState.isProcessing {
                            cancelProcessing()
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !processingState.isProcessing {
                        Button(action: {
                            showingAdvancedSettings = true
                        }) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
        }
        .onAppear {
            // Check if API key is configured, show setup if needed
            if !nutritionixService.isAPIKeyConfigured {
                nutritionixService.showAPIKeySetup()
            }
            
            // Auto-trigger based on initialization parameters
            if autoTriggerCamera {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingCamera = true
                }
            } else if autoTriggerPhotos {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingPhotoLibrary = true
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera) { image in
                selectedImage = image
                processImage(image)
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary) { image in
                selectedImage = image
                processImage(image)
            }
        }
        .sheet(isPresented: $showingAdvancedSettings) {
            AdvancedSettingsView(processingMethod: $processingMethod)
        }
        .sheet(isPresented: $nutritionixService.showingAPIKeySetup) {
            NutritionixAPIKeySetupView()
        }
        .sheet(isPresented: $showingAPIKeyErrorPopup) {
            CustomAPIKeyErrorPopup(isPresented: $showingAPIKeyErrorPopup) {
                nutritionixService.showAPIKeySetup()
            }
            .presentationBackground(.clear)
            .presentationDetents([.fraction(0.6)])
        }
        .fullScreenCover(isPresented: $showingResults) {
            if !validatedItems.isEmpty {
                MenuAnalysisResultsView(validatedItems: validatedItems)
            }
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                processImage(image)
            }
        }
        .sheet(item: $selectedSavedMenu) { menu in
            SavedMenuDetailView(savedMenu: menu)
        }
    }
    
    private func cancelProcessing() {
        currentProcessingTask?.cancel()
        currentProcessingTask = nil
        processingState = .idle
    }
    
    private var idleStateView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with icon and title
                VStack(spacing: 16) {
                    Image(systemName: "camera.metering.center.weighted")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("Scan Menu")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Take or select a clear photo of any menu section")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                
                // Photo capture buttons - MOVED UP
                VStack(spacing: 16) {
                    Button("Take Photo") {
                        if !nutritionixService.isAPIKeyConfigured {
                            showingAPIKeyErrorPopup = true
                        } else if nutritionixService.hasReachedDailyLimit {
                            processingState = .error("Daily limit of 200 nutrition analyses reached. Resets at midnight.")
                        } else {
                            showingCamera = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!nutritionixService.isAPIKeyConfigured) // Disable button if no API key
                    
                    // Minimal library link
                    Button("Choose from Library") {
                        if !nutritionixService.isAPIKeyConfigured {
                            showingAPIKeyErrorPopup = true
                        } else if nutritionixService.hasReachedDailyLimit {
                            processingState = .error("Daily limit of 200 nutrition analyses reached. Resets at midnight.")
                        } else {
                            showingPhotoLibrary = true
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(nutritionixService.isAPIKeyConfigured ? .blue : .gray) // Gray out if no API key
                    .disabled(!nutritionixService.isAPIKeyConfigured) // Disable button if no API key
                }
                .padding(.horizontal, 32)
                
                // Minimal tip
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Best with well-lit, focused shots")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // API Key status and daily usage tracker
                VStack(spacing: 6) {
                    if nutritionixService.isAPIKeyConfigured {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text("Daily usage: \(nutritionixService.dailyUsageString)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                    } else {
                        Button("Set up Nutritionix API Key") {
                            nutritionixService.showAPIKeySetup()
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Saved Menus")
                                .font(.title2)
                                .fontWeight(.semibold)
                            if !savedMenuManager.savedMenus.isEmpty {
                                Text("\(savedMenuManager.savedMenus.count) saved analyses")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        
                        if !savedMenuManager.savedMenus.isEmpty {
                            Button("View All") {
                                // Could add a dedicated saved menus view here
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    if savedMenuManager.savedMenus.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            Text("No Saved Menus")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text("Scan your first menu to get started")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        .padding(.horizontal, 32)
                    } else {
                        // Saved menus list
                        LazyVStack(spacing: 8) {
                            ForEach(savedMenuManager.savedMenus.prefix(3)) { menu in
                                SavedMenuRowView(menu: menu) {
                                    selectedSavedMenu = menu
                                }
                            }
                            
                            if savedMenuManager.savedMenus.count > 3 {
                                Button("View \(savedMenuManager.savedMenus.count - 3) more") {
                                    // Could expand or navigate to full list
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                }
                
                Spacer(minLength: 32)
            }
            .padding(.vertical, 16)
        }
    }
    
    private var processingStateView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Centered header with breathing room
            VStack(spacing: 24) {
                // Icon
                ProgressView()
                    .scaleEffect(2.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
                // Title only - removed subtitle description
                Text(processingStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Progress section
            VStack(spacing: 20) {
                // Progress bar with proper insets
                VStack(spacing: 12) {
                    ProgressView(value: ocrService.progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(y: 1.5)
                        .padding(.horizontal, 16)
                    
                    Text("\(Int(ocrService.progress * 100))% complete")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                // Simplified step indicators
                VStack(spacing: 8) {
                    ProcessingStepView(
                        title: "Extract Text",
                        isCompleted: ocrService.progress > 0.4,
                        isActive: ocrService.progress <= 0.4
                    )
                    ProcessingStepView(
                        title: "AI Menu Parsing",
                        isCompleted: ocrService.progress > 0.6,
                        isActive: ocrService.progress > 0.4 && ocrService.progress <= 0.6
                    )
                    MinimalStepView(
                        title: validationStepTitle, 
                        isCompleted: ocrService.progress >= 1.0,
                        isActive: ocrService.progress > 0.6
                    )
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
        }
    }
    
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("Analysis Failed")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                Button("Try Again") {
                    processingState = .idle
                    selectedImage = nil
                    validatedItems = []
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Choose Different Photo") {
                    processingState = .idle
                    selectedImage = nil
                    validatedItems = []
                    showingPhotoLibrary = true 
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
    
    private var processingStateTitle: String {
        return "Scanning Menu"
    }
    
    private var processingStateSubtitle: String {
        return "Using AI to parse menu structure and analyze nutrition data"
    }
    
    private var validationStepTitle: String {
        return "Nutrition Analysis" 
    }
    
    struct ProcessingStepView: View {
        let title: String
        let isCompleted: Bool
        let isActive: Bool
        
        var body: some View {
            HStack {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : (isActive ? "circle.dotted" : "circle"))
                    .foregroundColor(isCompleted ? .green : (isActive ? .blue : .gray))
                    .font(.title3)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(isCompleted ? .primary : (isActive ? .primary : .secondary))
                
                Spacer()
                
                if isActive && !isCompleted {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    struct MinimalStepView: View {
        let title: String
        let isCompleted: Bool
        let isActive: Bool
        
        var body: some View {
            HStack {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : (isActive ? "circle.dotted" : "circle"))
                    .foregroundColor(isCompleted ? .green : (isActive ? .blue : .gray))
                    .font(.title3)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(isCompleted ? .primary : (isActive ? .primary : .secondary))
                
                Spacer()
                
                if isActive && !isCompleted {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func processImage(_ image: UIImage) {
        // Cancel any existing task
        currentProcessingTask?.cancel()
        
        currentProcessingTask = Task { @MainActor in
            processingState = .analyzing
            
            do {
                let result = try await ocrService.processMenuImageWithAINutritionix(image)
                
                // Check if task was cancelled
                if Task.isCancelled {
                    processingState = .idle
                    return
                }
                
                // Skip the completion screen and go directly to results
                validatedItems = result
                processingState = .idle 
                showingResults = true   
            } catch {
                // Check if task was cancelled
                if Task.isCancelled {
                    processingState = .idle
                    return
                }
                
                debugLog(" Image processing failed: \(error)")
                processingState = .error(error.localizedDescription)
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct AdvancedSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var processingMethod: MenuPhotoCaptureView.ProcessingMethod
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Processing Method")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        ForEach(MenuPhotoCaptureView.ProcessingMethod.allCases, id: \.self) { method in
                            Button(action: { processingMethod = method }) {
                                HStack(spacing: 12) {
                                    Image(systemName: processingMethod == method ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(processingMethod == method ? .blue : .gray)
                                        .font(.title3)
                                    
                                    Text(method.emoji)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(method.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text(method.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tips for Best Results")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Best results with clear, well-lit photos", systemImage: "lightbulb")
                        Label("Hold phone steady and avoid shadows", systemImage: "hand.raised")
                        Label("Capture the entire menu section", systemImage: "viewfinder")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Saved Menu Row View
struct SavedMenuRowView: View {
    let menu: SavedMenuAnalysis
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Menu icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                
                // Menu details
                VStack(alignment: .leading, spacing: 2) {
                    Text(menu.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(menu.displaySummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(menu.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Success rate indicator
                VStack(spacing: 2) {
                    Text("\(menu.successRate)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(menu.successRate > 80 ? .green : menu.successRate > 50 ? .orange : .red)
                    Text("success")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MenuPhotoCaptureView()
}