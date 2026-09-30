import SwiftUI
import PhotosUI

public struct ReceiptScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject public var viewModel: FuelLogViewModel
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isProcessing = false
    @State private var scanStatusMessage = "Position receipt in frame or select photo"
    @State private var scanProgress: CGFloat = 0.0
    @State private var scannedResult: ScannedReceiptData? = nil
    @State private var showAddLogWithScannedData = false
    @State private var errorMessage: String? = nil
    @State private var scanLaserOffset: CGFloat = -120
    
    public init(viewModel: FuelLogViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // MARK: - Scanning Viewport / Card
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
                        // Scanner Placeholder / Viewfinder Reticle
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "doc.viewfinder.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(AppTheme.primaryGradient)
                            }
                            
                            Text("Apple Vision OCR Scanner")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Extracts Total Cost, Liters, and Station Brand automatically from your fuel receipt.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }
                    }
                    
                    // Scanning Animation Overlay (Laser Beam)
                    if isProcessing {
                        ZStack {
                            Color.black.opacity(0.35)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            
                            // Laser Line
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
                .frame(height: 320)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // MARK: - Action Buttons
                VStack(spacing: 12) {
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
                        .background(AppTheme.primaryGradient)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isProcessing)
                    
                    // Quick Demo Receipt Tester for Instant Testing
                    Menu {
                        Button("Ceypetco Receipt (Rs. 6,220.00 • 20.0 L)") {
                            testWithSimulatedReceipt(
                                station: "Ceypetco",
                                grade: "Petrol 92 Octane",
                                cost: 6220.0,
                                volume: 20.0
                            )
                        }
                        Button("Lanka IOC Receipt (Rs. 5,909.00 • 19.0 L)") {
                            testWithSimulatedReceipt(
                                station: "Lanka IOC",
                                grade: "Petrol 92 Octane",
                                cost: 5909.0,
                                volume: 19.0
                            )
                        }
                        Button("Sinopec Receipt (Rs. 5,660.20 • 18.2 L)") {
                            testWithSimulatedReceipt(
                                station: "Sinopec",
                                grade: "Petrol 92 Octane",
                                cost: 5660.2,
                                volume: 18.2
                            )
                        }
                        Button("Shell / RM Parks (Rs. 7,087.60 • 18.8 L Super Diesel)") {
                            testWithSimulatedReceipt(
                                station: "Shell / RM Parks",
                                grade: "Super Diesel (Euro 4)",
                                cost: 7087.6,
                                volume: 18.8
                            )
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Try Sample Sri Lankan Receipt")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundColor(.primary)
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
            .sheet(isPresented: $showAddLogWithScannedData) {
                AddLogView(viewModel: viewModel, prefilledData: scannedResult)
            }
        }
    }
    
    // MARK: - Photo Loading & Vision OCR
    private func loadAndProcessPhotoItem(_ item: PhotosPickerItem) {
        isProcessing = true
        scanStatusMessage = "Loading image..."
        errorMessage = nil
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.selectedImage = uiImage
                        self.scanStatusMessage = "Running Apple Vision OCR..."
                    }
                    
                    let result = try await ReceiptScannerService.shared.scanReceipt(from: uiImage)
                    
                    await MainActor.run {
                        self.isProcessing = false
                        self.scannedResult = result
                        Haptics.success()
                        self.showAddLogWithScannedData = true
                    }
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
    
    // MARK: - Simulated Receipt Runner
    private func testWithSimulatedReceipt(station: String, grade: String, cost: Double, volume: Double) {
        isProcessing = true
        scanStatusMessage = "Analyzing \(station) receipt..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let data = ScannedReceiptData(
                totalCost: cost,
                volume: volume,
                stationName: station,
                fuelGrade: grade,
                rawText: "CEYLON PETROLEUM CORPORATION\n\(station.uppercased())\nFUEL: \(grade.uppercased())\nQTY: \(volume) L\nTOTAL: RS. \(cost)"
            )
            self.scannedResult = data
            self.isProcessing = false
            Haptics.success()
            self.showAddLogWithScannedData = true
        }
    }
}
