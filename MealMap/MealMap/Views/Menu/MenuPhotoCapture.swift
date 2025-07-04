import SwiftUI
import VisionKit
import PhotosUI

struct MenuPhotoCaptureView: View {
    @StateObject private var ocrService = MenuOCRService()
    @StateObject private var analysisProgress = MenuAnalysisProgress()
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var analysisResult: MenuAnalysisResult?
    @State private var showingResults = false
    @State private var showingCustomMenu = false
    @State private var isAnalysisComplete = false
    @State private var showingLoadingPage = false
    @State private var loadingMessage = "Preparing analysis..."
    @State private var loadingProgress: Double = 0.0
    @State private var isAnalyzing = false 
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                if showingLoadingPage || isAnalyzing {
                    loadingPageView
                } else if let result = analysisResult, isAnalysisComplete {
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
                showLoadingPageAndStartAnalysis(image)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                selectedImage = image
                showingCamera = false
                showLoadingPageAndStartAnalysis(image)
            }
        }
        .sheet(isPresented: $showingResults) {
            if let result = analysisResult {
                MenuAnalysisResultsView(result: result)
            }
        }
        .fullScreenCover(isPresented: $showingCustomMenu) {
            CustomMenuView(analysisResult: analysisProgress)
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
    
    private var loadingPageView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Large Loading Animation
            VStack(spacing: 24) {
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 6)
                        .frame(width: 140, height: 140)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: loadingProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: loadingProgress)
                    
                    // Inner content
                    VStack(spacing: 8) {
                        Image(systemName: isAnalyzing ? "doc.text.viewfinder" : "camera.metering.center.weighted")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                            .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2) * 0.1)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: loadingProgress)
                        
                        Text("\(Int(loadingProgress * 100))%")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                // Loading Message
                VStack(spacing: 8) {
                    Text(isAnalyzing ? "Analyzing Your Menu" : "Preparing Analysis")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(loadingMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: loadingMessage)
                }
            }
            
            // Real-time item count (if analysis has started)
            if analysisProgress.totalItems > 0 {
                VStack(spacing: 12) {
                    HStack {
                        Text("Found \(analysisProgress.totalItems) menu items")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("Processed \(analysisProgress.analyzedItems.count)/\(analysisProgress.totalItems)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Items processed progress bar
                    if analysisProgress.totalItems > 0 {
                        ProgressView(value: Double(analysisProgress.analyzedItems.count), total: Double(analysisProgress.totalItems))
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Image Preview (smaller)
            if let selectedImage = selectedImage {
                VStack(spacing: 12) {
                    Text("Analyzing Image")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .cornerRadius(8)
                        .shadow(radius: 2)
                        .opacity(0.8)
                }
            }
            
            Spacer()
            
            // Loading Dots
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                        .scaleEffect(loadingProgress > Double(index) * 0.33 ? 1.3 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: loadingProgress
                        )
                }
            }
            
            // Cancel button
            Button("Cancel") {
                resetState()
            }
            .font(.subheadline)
            .foregroundColor(.red)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
    
    private func successView(_ result: MenuAnalysisResult) -> some View {
        VStack(spacing: 24) {
            // Success Icon with animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .scaleEffect(isAnalysisComplete ? 1.0 : 0.5)
                .animation(.bouncy(duration: 0.6), value: isAnalysisComplete)
            
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Enhanced summary with nutrition breakdown
            VStack(spacing: 12) {
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
                        Text("\(nutritionDataAvailable)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("With Nutrition")
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
            }
            
            // Action Buttons - NOW ENABLED
            VStack(spacing: 12) {
                // Primary action - Custom Menu
                Button("View Custom Menu") {
                    showingCustomMenu = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .disabled(!isAnalysisComplete)
                
                // Secondary actions
                HStack(spacing: 12) {
                    Button("Detailed Results") {
                        showingResults = true
                    }
                    .font(.subheadline)
                    .foregroundColor(isAnalysisComplete ? .blue : .gray)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background((isAnalysisComplete ? Color.blue : Color.gray).opacity(0.1))
                    .cornerRadius(8)
                    .disabled(!isAnalysisComplete)
                    
                    Button("Analyze Another") {
                        resetState()
                    }
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .opacity(isAnalysisComplete ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.3), value: isAnalysisComplete)
        }
    }
    
    private func getProcessingStep() -> String {
        switch loadingProgress {
        case 0.0..<0.2:
            return "Reading text from image..."
        case 0.2..<0.4:
            return "Parsing menu structure..."
        case 0.4..<0.6:
            return "Identifying menu items..."
        case 0.6..<0.8:
            return "Looking up nutrition data from USDA..."
        case 0.8..<1.0:
            return "Finalizing results..."
        default:
            return "Analysis complete!"
        }
    }
    
    private func showLoadingPageAndStartAnalysis(_ image: UIImage) {
        // Immediately show loading page and start analyzing
        withAnimation(.easeInOut(duration: 0.3)) {
            showingLoadingPage = true
            isAnalyzing = true
            loadingProgress = 0.0
            loadingMessage = "Preparing analysis..."
        }
        
        // Start the analysis sequence
        Task {
            await runLoadingSequence()
            await analyzeImageWithProgressTracking(image)
        }
    }
    
    private func runLoadingSequence() async {
        let messages = [
            "Preparing analysis...",
            "Initializing OCR engine...",
            "Processing image...",
            "Starting menu analysis..."
        ]
        
        for (index, message) in messages.enumerated() {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.loadingMessage = message
                self.loadingProgress = Double(index + 1) / Double(messages.count) * 0.3
            }
            
            // Wait for each step
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        }
    }
    
    private func analyzeImageWithProgressTracking(_ image: UIImage) async {
        // Reset state
        self.analysisResult = nil
        self.isAnalysisComplete = false
        
        do {
            // Start analysis and track progress
            let result = try await analyzeImageWithProgressUpdates(image)
            
            self.analysisResult = result
            analysisProgress.completeAnalysis()
            
            // Complete the loading progress and show completion message
            withAnimation(.easeInOut(duration: 0.5)) {
                self.loadingProgress = 1.0
                self.loadingMessage = "✅ Analysis complete! Found \(result.menuItems.count) items with nutrition data."
            }
            
            // Show completion message briefly, then transition
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s to show completion message
            
            withAnimation(.easeInOut(duration: 0.4)) {
                self.showingLoadingPage = false
                self.isAnalyzing = false
            }
            
            // Mark analysis as complete with animation
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            withAnimation(.bouncy(duration: 0.8)) {
                self.isAnalysisComplete = true
            }
        } catch {
            debugLog("❌ Menu analysis failed: \(error)")
            analysisProgress.setError(error)
            
            // Show error message briefly
            withAnimation(.easeInOut(duration: 0.5)) {
                self.loadingMessage = "Analysis encountered an error, but partial results available."
            }
            
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s to show error
            
            withAnimation(.easeInOut(duration: 0.4)) {
                self.showingLoadingPage = false
                self.isAnalyzing = false
                self.isAnalysisComplete = true
            }
        }
    }
    
    private func analyzeImageWithProgressUpdates(_ image: UIImage) async throws -> MenuAnalysisResult {
        debugLog("🍽️ Starting ENHANCED menu analysis with USDA API...")
        
        // Step 1: OCR extraction (0-25% progress)
        loadingMessage = "Reading text from image..."
        loadingProgress = 0.05
        
        let ocrResults = try await ocrService.extractTextFromImage(image)
        
        loadingMessage = "Parsing menu structure..."
        loadingProgress = 0.15
        
        let rawMenuItems = try await ocrService.parseMenuStructure(ocrResults, image: image)
        
        loadingMessage = "Found \(rawMenuItems.count) menu items, starting USDA analysis..."
        loadingProgress = 0.25
        
        debugLog("📄 OCR found \(rawMenuItems.count) potential menu items")
        
        // Start progress tracking for items
        analysisProgress.startAnalysis(totalItems: rawMenuItems.count)
        
        // Step 2: USDA nutrition analysis (25-95% progress)
        var analyzedItems: [AnalyzedMenuItem] = []
        let totalItems = rawMenuItems.count
        let baseProgress = 0.25 // Start after OCR
        let analysisProgressRange = 0.70 // 70% of total progress for USDA analysis
        
        for (index, rawItem) in rawMenuItems.enumerated() {
            // Update progress for this item start
            let itemStartProgress = baseProgress + (Double(index) / Double(totalItems)) * analysisProgressRange
            loadingProgress = itemStartProgress
            loadingMessage = "Analyzing '\(String(rawItem.name.prefix(25)))...' with USDA database"
            
            // Actually perform the USDA analysis (this is where the real work happens)
            let analyzedItem = try await analyzeMenuItemWithDetailedProgress(rawItem, itemIndex: index + 1, totalItems: totalItems)
            analyzedItems.append(analyzedItem)
            
            // Complete progress for this item
            let itemCompleteProgress = baseProgress + (Double(index + 1) / Double(totalItems)) * analysisProgressRange
            loadingProgress = itemCompleteProgress
            loadingMessage = "✅ Completed analysis for '\(String(rawItem.name.prefix(20)))...' (\(index + 1)/\(totalItems))"
            
            // Update real-time progress
            analysisProgress.addAnalyzedItem(analyzedItem)
            
            debugLog("📊 Progress: \(index + 1)/\(totalItems) items analyzed (\(Int(itemCompleteProgress * 100))%)")
        }
        
        // Finalize analysis (95-99% progress)
        loadingProgress = 0.96
        loadingMessage = "Calculating nutrition confidence scores..."
        
        // Calculate overall confidence
        let overallConfidence = calculateOverallConfidence(analyzedItems)
        
        loadingProgress = 0.98
        loadingMessage = "Preparing final results..."
        
        let result = MenuAnalysisResult(
            restaurantName: ocrService.detectRestaurantName(from: ocrResults),
            location: nil,
            menuItems: analyzedItems,
            analysisDate: Date(),
            imageData: image.pngData(),
            confidence: overallConfidence
        )
        
        loadingProgress = 0.99
        loadingMessage = "Finalizing analysis results..."
        
        debugLog("✅ ENHANCED menu analysis complete: \(result.menuItems.count) items analyzed with USDA API")
        
        // This is the ACTUAL completion point - when the log message appears
        loadingMessage = "🎉 ENHANCED menu analysis complete: \(result.menuItems.count) items analyzed with USDA API"
        
        return result
    }
    
    private func analyzeMenuItemWithDetailedProgress(_ rawItem: RawMenuItem, itemIndex: Int, totalItems: Int) async throws -> AnalyzedMenuItem {
        debugLog("🔍 Starting USDA analysis for item \(itemIndex)/\(totalItems): '\(rawItem.name)'")
        
        // Update progress to show we're starting USDA lookup for this specific item
        loadingMessage = "🔍 USDA lookup: '\(String(rawItem.name.prefix(25)))...' (\(itemIndex)/\(totalItems))"
        
        // Perform the actual USDA analysis - this is where the API call happens
        // This method BLOCKS until the USDA API call completes
        let analyzedItem = try await ocrService.createUSDAOnlyAnalyzedItem(from: rawItem)
        
        debugLog("✅ Completed USDA analysis for: '\(rawItem.name)' - Tier: \(analyzedItem.estimationTier.rawValue)")
        
        return analyzedItem
    }
    
    private func calculateOverallConfidence(_ items: [AnalyzedMenuItem]) -> Double {
        guard !items.isEmpty else { return 0.0 }
        return items.map { $0.confidence }.reduce(0, +) / Double(items.count)
    }
    
    private var nutritionDataAvailable: Int {
        analysisResult?.menuItems.filter { $0.estimationTier != .unavailable }.count ?? 0
    }
    
    private func resetState() {
        selectedImage = nil
        analysisResult = nil
        isAnalysisComplete = false
        showingLoadingPage = false
        isAnalyzing = false
        loadingProgress = 0.0
        loadingMessage = "Preparing analysis..."
        analysisProgress.analyzedItems = []
        analysisProgress.totalItems = 0
        analysisProgress.isAnalyzing = false
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