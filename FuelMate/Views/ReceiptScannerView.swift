import SwiftUI
import PhotosUI

public struct ReceiptScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject public var viewModel: FuelLogViewModel
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showingCameraPicker = false
    @State private var isProcessing = false
    @State private var scanStatusMessage = "Position thermal receipt in frame or select photo"
    @State private var scannedResult: ScannedReceiptData? = nil
    @State private var showAddLogWithScannedData = false
    @State private var errorMessage: String? = nil
    @State private var scanLaserOffset: CGFloat = -120
    
    public init(viewModel: FuelLogViewModel) {
        self.viewModel = viewModel
    }
    
    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // MARK: - Scanning Viewport / Reticle Card
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(AppTheme.primaryGradient, lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
                    
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .padding(6)
                    } else {
                        // Viewfinder Reticle
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "doc.viewfinder.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(AppTheme.primaryGradient)
                            }
                            
                            Text("On-Device Thermal Receipt Scanner")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Apple Vision OCR extracts Station Brand (CEYPETCO, LIOC, SINOPEC), Total Cost, and Liters with zero cloud APIs.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }
                    }
                    
                    // Laser Beam Scanning Overlay
                    if isProcessing {
                        ZStack {
                            Color.black.opacity(0.35)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.clear, Color.cyan, Color.white, Color.cyan, Color.clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 3)
                                .shadow(color: Color.cyan, radius: 8, x: 0, y: 0)
                                .offset(y: scanLaserOffset)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                        scanLaserOffset = 120
                                    }
                                }
                            
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.3)
                                
                                Text(scanStatusMessage)
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 3)
                            }
                        }
                    }
                }
                .frame(height: 310)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // MARK: - Action Buttons
                VStack(spacing: 12) {
                    if isCameraAvailable {
                        Button(action: {
                            Haptics.medium()
                            showingCameraPicker = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                Text("Scan Receipt with Camera")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.primaryGradient)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isProcessing)
                    }
                    
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Select Receipt from Photos")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isCameraAvailable ? Color.secondary.opacity(0.12) : Color.blue)
                        .foregroundColor(isCameraAvailable ? .primary : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isProcessing)

                }
                .padding(.horizontal, 16)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppTheme.errorColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
            .navigationTitle("Receipt Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let item = newItem else { return }
                loadAndProcessPhotoItem(item)
            }
            .sheet(isPresented: $showingCameraPicker) {
                CameraPickerView { image in
                    self.selectedImage = image
                    self.processCapturedImage(image)
                }
            }
            .sheet(isPresented: $showAddLogWithScannedData) {
                AddLogView(viewModel: viewModel, prefilledData: scannedResult)
            }
        }
    }
    
    // MARK: - Photo Loading & Vision OCR
    private func loadAndProcessPhotoItem(_ item: PhotosPickerItem) {
        isProcessing = true
        scanStatusMessage = "Loading receipt photo..."
        errorMessage = nil
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.selectedImage = uiImage
                    }
                    await processCapturedImage(uiImage)
                } else {
                    await MainActor.run {
                        self.isProcessing = false
                        self.errorMessage = "Failed to load the selected image."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func processCapturedImage(_ uiImage: UIImage) {
        isProcessing = true
        scanStatusMessage = "Running Apple Vision OCR..."
        errorMessage = nil
        
        Task {
            do {
                let result = try await ReceiptScannerService.shared.scanReceipt(from: uiImage)
                await MainActor.run {
                    self.isProcessing = false
                    self.scannedResult = result
                    Haptics.success()
                    self.showAddLogWithScannedData = true
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

}

// MARK: - Native UIKit Camera Controller Wrapper
public struct CameraPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    public let onImageCaptured: (UIImage) -> Void
    
    public init(onImageCaptured: @escaping (UIImage) -> Void) {
        self.onImageCaptured = onImageCaptured
    }
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        
        init(_ parent: CameraPickerView) {
            self.parent = parent
        }
        
        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
