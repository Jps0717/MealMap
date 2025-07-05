import SwiftUI
import PhotosUI

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
    
    @State private var processingState: ImageProcessingState = .idle
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingResults = false
    @State private var validatedItems: [ValidatedMenuItem] = []
    @State private var processingMethod: ProcessingMethod = .aiNutritionix // Default to AI + Nutritionix
    @State private var showingAdvancedSettings = false // NEW: For settings sheet
    
    let autoTriggerCamera: Bool
    let autoTriggerPhotos: Bool
    
    init(autoTriggerCamera: Bool = false, autoTriggerPhotos: Bool = false) {
        self.autoTriggerCamera = autoTriggerCamera
        self.autoTriggerPhotos = autoTriggerPhotos
    }
    
    enum ProcessingMethod: String, CaseIterable {
        case aiNutritionix = "ai_nutritionix"    // Only AI + Nutritionix option
        
        var displayName: String {
            switch self {
            case .aiNutritionix: return "AI + Nutritionix"
            }
        }
        
        var description: String {
            switch self {
            case .aiNutritionix: return "AI menu parsing with high-accuracy Nutritionix nutrition data"
            }
        }
        
        var emoji: String {
            switch self {
            case .aiNutritionix: return "🤖🥗"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                if case .idle = processingState {
                    idleStateView
                } else if processingState.isProcessing {
                    processingStateView
                } else if case .error(let message) = processingState {
                    errorStateView(message: message)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Menu Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(processingState.isProcessing)
                }
                
                // NEW: Settings gear icon
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingAdvancedSettings = true
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(.blue)
                    }
                    .disabled(processingState.isProcessing)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                PhotosPicker(
                    selection: Binding<PhotosPickerItem?>(
                        get: { nil },
                        set: { item in
                            if let item = item {
                                loadPhotoFromPicker(item)
                            }
                        }
                    ),
                    matching: .images
                ) {
                    Text("Select Photo")
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera) { image in
                    selectedImage = image
                    processImage(image)
                }
            }
            .sheet(isPresented: $showingResults) {
                MenuAnalysisResultsView(validatedItems: validatedItems)
            }
            .sheet(isPresented: $showingAdvancedSettings) {
                AdvancedSettingsView(processingMethod: $processingMethod)
            }
            .onAppear {
                handleAutoTrigger()
            }
        }
    }
    
    private func handleAutoTrigger() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if autoTriggerCamera {
                showingCamera = true
            } else if autoTriggerPhotos {
                showingImagePicker = true
            }
        }
    }
    
    private var idleStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Header with icon and title
            VStack(spacing: 16) {
                Image(systemName: "camera.metering.center.weighted")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text("Scan Menu")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("Take or select a clear photo of any menu section")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
            
            // Primary CTA
            VStack(spacing: 16) {
                Button("Take Photo") {
                    showingCamera = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                
                // Minimal library link
                Button("Choose from Library") {
                    showingImagePicker = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
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
            .padding(.bottom, 32)
        }
    }
    
    private var processingStateView: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
                VStack(spacing: 8) {
                    Text(processingStateTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(processingStateSubtitle)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 8) {
                ProgressView(value: ocrService.progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(y: 2)
                
                Text("\(Int(ocrService.progress * 100))% complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                ProcessingStepView(
                    title: "Extract Text",
                    isCompleted: ocrService.progress > 0.4,
                    isActive: ocrService.progress <= 0.4
                )
                ProcessingStepView(
                    title: processingStepTitle,
                    isCompleted: ocrService.progress > 0.6,
                    isActive: ocrService.progress > 0.4 && ocrService.progress <= 0.6
                )
                ProcessingStepView(
                    title: validationStepTitle,
                    isCompleted: ocrService.progress >= 1.0,
                    isActive: ocrService.progress > 0.6
                )
            }
            .padding(.horizontal)
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
                    showingImagePicker = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
    
    private var processingStateTitle: String {
        switch processingState {
        case .uploading:
            return "Uploading photo..."
        case .analyzing:
            return "AI parsing with Nutritionix..."
        default:
            return "Processing..."
        }
    }
    
    private var processingStateSubtitle: String {
        switch processingState {
        case .uploading:
            return "Please wait while we upload your image"
        case .analyzing:
            return "Using AI to parse menu structure, then Nutritionix API for accurate nutrition analysis"
        default:
            return "Please wait..."
        }
    }
    
    private var processingStepTitle: String {
        return "AI Menu Parsing"
    }
    
    private var validationStepTitle: String {
        return "Nutritionix Analysis"
    }
    
    private func loadPhotoFromPicker(_ item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                    processImage(image)
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        Task {
            await MainActor.run {
                processingState = .analyzing
            }
            
            do {
                let result = try await ocrService.processMenuImageWithAINutritionix(image)
                await MainActor.run {
                    // Skip the completion screen and go directly to results
                    validatedItems = result
                    processingState = .idle // Reset state
                    showingResults = true   // Show results immediately
                }
            } catch {
                debugLog("📸 Image processing failed: \(error)")
                await MainActor.run {
                    processingState = .error(error.localizedDescription)
                }
            }
        }
    }
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

#Preview {
    MenuPhotoCaptureView()
}