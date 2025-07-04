import SwiftUI
import VisionKit
import PhotosUI

struct MenuPhotoCaptureView: View {
    @StateObject private var ocrService = MenuOCRService()
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var analysisResult: MenuAnalysisResult?
    @State private var showingResults = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                if ocrService.isProcessing {
                    processingView
                } else if let result = analysisResult {
                    successView(result)
                } else {
                    captureOptionsView
                }
            }
            .padding()
            .navigationTitle("Analyze Menu")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker { image in
                selectedImage = image
                showingImagePicker = false
                Task {
                    await analyzeImage(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                selectedImage = image
                showingCamera = false
                Task {
                    await analyzeImage(image)
                }
            }
        }
        .sheet(isPresented: $showingResults) {
            if let result = analysisResult {
                MenuAnalysisResultsView(result: result)
            }
        }
    }
    
    private var captureOptionsView: some View {
        VStack(spacing: 40) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "camera.metering.center.weighted")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Analyze Menu Photo")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Take a photo or select from your library to get instant nutrition analysis of menu items")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Action Buttons
            VStack(spacing: 16) {
                Button(action: { showingCamera = true }) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Take Photo")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button(action: { showingImagePicker = true }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Library")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            
            // Tips
            VStack(alignment: .leading, spacing: 12) {
                Label("Best results with clear, well-lit photos", systemImage: "lightbulb")
                Label("Hold phone steady and avoid shadows", systemImage: "hand.raised")
                Label("Capture the entire menu section", systemImage: "viewfinder")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 30) {
            // Progress Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: ocrService.progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: ocrService.progress)
                
                VStack {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("\(Int(ocrService.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            
            // Processing Steps
            VStack(spacing: 8) {
                Text("Analyzing Menu...")
                    .font(.headline)
                
                Text(getProcessingStep())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Loading animation
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(ocrService.progress > Double(index) * 0.33 ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2), value: ocrService.progress)
                }
            }
        }
    }
    
    private func successView(_ result: MenuAnalysisResult) -> some View {
        VStack(spacing: 24) {
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            // Results Summary
            VStack(spacing: 12) {
                Text("Analysis Complete!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Found \(result.totalItems) menu items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let restaurantName = result.restaurantName {
                    Text(restaurantName)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
            
            // Confidence Indicator
            HStack {
                VStack {
                    Text("\(result.highConfidenceItems)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("High Confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack {
                    Text("\(Int(result.confidence * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Overall Accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Action Buttons
            VStack(spacing: 12) {
                Button("View Results") {
                    showingResults = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                
                Button("Analyze Another Menu") {
                    resetState()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
    }
    
    private func getProcessingStep() -> String {
        switch ocrService.progress {
        case 0.0..<0.3:
            return "Reading menu text..."
        case 0.3..<0.6:
            return "Identifying menu items..."
        case 0.6..<0.8:
            return "Analyzing ingredients..."
        case 0.8..<1.0:
            return "Calculating nutrition..."
        default:
            return "Finalizing results..."
        }
    }
    
    private func analyzeImage(_ image: UIImage) async {
        do {
            let result = try await ocrService.analyzeMenuImage(image)
            await MainActor.run {
                self.analysisResult = result
            }
        } catch {
            debugLog("❌ Menu analysis failed: \(error)")
            // Handle error
        }
    }
    
    private func resetState() {
        selectedImage = nil
        analysisResult = nil
        ocrService.progress = 0.0
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
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
                parent.onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    MenuPhotoCaptureView()
}