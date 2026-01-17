//
//  ScanView.swift
//  Cheq
//
//  Receipt scanning screen with camera
//

import SwiftUI
@preconcurrency import AVFoundation
import CoreImage

struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var navigateToConfirm = false
    @State private var ocrResult: OCRResult?
    @State private var cameraController: CameraViewController?
    @State private var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @State private var cameraError: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Scanning receipt...")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                    }
                } else if let error = cameraError {
                    // Show error state when camera fails
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.appTextSecondary)
                        Text(error)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Use Photo Library") {
                            sourceType = .photoLibrary
                            showImagePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if cameraPermissionStatus == .notDetermined {
                    // Show loading state while requesting permission
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Requesting camera access...")
                            .font(.headline)
                            .foregroundColor(.appTextSecondary)
                    }
                } else if cameraPermissionStatus == .authorized {
                    ZStack {
                        CameraView(
                            onFrameCaptured: { image in
                                viewModel.processVideoFrame(image)
                            },
                            onManualCapture: { image in
                                viewModel.manualCapture(image: image)
                            },
                            enableLiveScanning: Constants.enableLiveScanning,
                            controllerRef: $cameraController,
                            onError: { error in
                                cameraError = error
                            }
                        )
                        
                        // Bounding box overlay
                        GeometryReader { geometry in
                            if let candidate = viewModel.receiptCandidate {
                                let convertedRect = viewModel.convertImageRectToViewRect(
                                    imageRect: candidate.boundingRectangle,
                                    imageSize: candidate.imageSize,
                                    viewSize: geometry.size
                                )
                                
                                ReceiptBoundingBoxOverlay(
                                    boundingRect: convertedRect,
                                    state: viewModel.scanningState,
                                    viewSize: geometry.size
                                )
                            } else {
                                ReceiptBoundingBoxOverlay(
                                    boundingRect: nil,
                                    state: viewModel.scanningState,
                                    viewSize: geometry.size
                                )
                            }
                        }
                    }
                    .overlay(alignment: .top) {
                        ScanningOverlayView(viewModel: viewModel)
                    }
                    .overlay(alignment: .bottom) {
                        if !Constants.enableLiveScanning {
                            VStack(spacing: 16) {
                                Button(action: {
                                    cameraController?.capturePhoto()
                                }) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 30, weight: .medium))
                                        .foregroundColor(.appTextPrimary)
                                        .frame(width: 60, height: 60)
                                        .background(Color.appSurface)
                                        .clipShape(Circle())
                                }
                                .padding(.bottom, 40)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            sourceType = .camera
                            showCamera = true
                        }) {
                            Label {
                                Text("Take Photo")
                            } icon: {
                                Image(systemName: "camera.fill")
                            }
                        }
                        
                        Button(action: {
                            sourceType = .photoLibrary
                            // Ensure sourceType is set before showing the picker
                            DispatchQueue.main.async {
                                showImagePicker = true
                            }
                        }) {
                            Label {
                                Text("Choose from Library")
                            } icon: {
                                Image(systemName: "photo.on.rectangle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: sourceType) { image in
                    viewModel.processImage(image)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera) { image in
                    viewModel.processImage(image)
                }
            }
            .onChange(of: viewModel.scanningState) { _, newState in
                if newState == .preview, let result = viewModel.scanResult {
                    // Only navigate if result has valid data (items or totals)
                    let hasValidData = !result.items.isEmpty || result.total != nil || result.subtotal != nil
                    if hasValidData {
                        ocrResult = result
                        navigateToConfirm = true
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToConfirm) {
                if let result = ocrResult {
                    ConfirmReceiptView(ocrResult: result, isPreviewMode: true, onRetry: {
                        viewModel.resetScanning()
                        navigateToConfirm = false
                    })
                }
            }
            .onAppear {
                checkCameraPermission()
            }
        }
    }
    
    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermissionStatus = status
        
        switch status {
        case .notDetermined:
            requestCameraPermission()
        case .authorized:
            // Camera is authorized, will be shown
            break
        case .denied, .restricted:
            cameraError = "Camera access is required to scan receipts. Please enable it in Settings."
        @unknown default:
            cameraError = "Unable to access camera. Please use photo library instead."
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in
                if granted {
                    cameraPermissionStatus = .authorized
                    cameraError = nil
                    // Wait a bit for camera controller to be set up
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                    // Start camera session if it's set up
                    if let session = cameraController?.captureSession, !session.isRunning {
                        // Capture session reference to avoid Sendable warning
                        let sessionRef = session
                        DispatchQueue.global(qos: .userInitiated).async {
                            sessionRef.startRunning()
                        }
                    }
                } else {
                    cameraPermissionStatus = .denied
                    cameraError = "Camera access denied. Please enable it in Settings or use photo library."
                }
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    let onFrameCaptured: (UIImage) -> Void
    let onManualCapture: (UIImage) -> Void
    let enableLiveScanning: Bool
    @Binding var controllerRef: CameraViewController?
    let onError: ((String) -> Void)?
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onFrameCaptured = onFrameCaptured
        controller.onManualCapture = onManualCapture
        controller.enableLiveScanning = enableLiveScanning
        controller.onError = { error in
            onError?(error)
        }
        DispatchQueue.main.async {
            controllerRef = controller
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.onManualCapture = onManualCapture
        uiViewController.enableLiveScanning = enableLiveScanning
        uiViewController.onError = { error in
            onError?(error)
        }
    }
}

class CameraViewController: UIViewController {
    var onFrameCaptured: ((UIImage) -> Void)?
    var onManualCapture: ((UIImage) -> Void)?
    var enableLiveScanning: Bool = false
    var onError: ((String) -> Void)?
    var captureSession: AVCaptureSession? // Made internal so ScanView can access it
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private let videoQueue = DispatchQueue(label: "com.cheq.videoQueue")
    private var lastCapturedImage: UIImage?
    private var isSetupComplete = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreviewLayerFrame()
        
        // Only start session if permission is granted and setup is complete
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
           let session = captureSession, !session.isRunning, isSetupComplete {
            // Capture session reference to avoid Sendable warning
            let sessionRef = session
            DispatchQueue.global(qos: .userInitiated).async {
                sessionRef.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let session = captureSession, session.isRunning {
            // Capture session reference to avoid Sendable warning
            let sessionRef = session
            DispatchQueue.global(qos: .userInitiated).async {
                sessionRef.stopRunning()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreviewLayerFrame()
    }
    
    private func updatePreviewLayerFrame() {
        // Ensure UI access happens on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updatePreviewLayerFrame()
            }
            return
        }
        
        previewLayer?.frame = view.layer.bounds
    }
    
    private func setupCamera() {
        // Don't check permission here - let the view handle it
        // This allows the preview layer to be set up even if permission is being requested
        
        let session = AVCaptureSession()
        // Use .photo for maximum quality when capturing full-resolution images
        session.sessionPreset = .photo
        
        // Check if camera device is available
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("Camera not available on this device")
            }
            return
        }
        
        // Create input with proper error handling
        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            guard session.canAddInput(input) else {
                DispatchQueue.main.async { [weak self] in
                    self?.onError?("Unable to configure camera input")
                }
                return
            }
        session.addInput(input)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("Failed to initialize camera: \(error.localizedDescription)")
            }
            return
        }
        
        // Add photo output for manual capture (full resolution)
        let photoOutput = AVCapturePhotoOutput()
        guard session.canAddOutput(photoOutput) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("Unable to configure photo output")
            }
            return
        }
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        
        // Add video output only if live scanning is enabled
        if enableLiveScanning {
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: videoQueue)
            
            if session.canAddOutput(output) {
                session.addOutput(output)
                self.videoOutput = output
            }
        }
        
        // Create and add preview layer immediately so view isn't empty
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        self.captureSession = session
        self.previewLayer = previewLayer
        self.isSetupComplete = true
        
        // Only start session if permission is granted
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            // Capture session reference to avoid Sendable warning
            if let sessionRef = captureSession {
                DispatchQueue.global(qos: .userInitiated).async {
                    sessionRef.startRunning()
                }
            }
        }
    }
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        // Use default settings - they already provide maximum quality
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard enableLiveScanning else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        let image = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async { [weak self] in
            self?.onFrameCaptured?(image)
        }
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("Failed to capture photo: \(error.localizedDescription)")
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("Failed to process captured image")
            }
            return
        }
        
        // Store full-resolution image
        lastCapturedImage = image
        
        DispatchQueue.main.async { [weak self] in
            self?.onManualCapture?(image)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Update the source type if it changes
        if uiViewController.sourceType != sourceType {
            uiViewController.sourceType = sourceType
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        
        init(onImageSelected: @escaping (UIImage) -> Void) {
            self.onImageSelected = onImageSelected
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct ScanningOverlayView: View {
    @ObservedObject var viewModel: ScanViewModel
    
    var body: some View {
        VStack {
            // Error message (takes priority over state message)
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.top, 20)
            }
            // State indicator text (only show if no error message)
            else if viewModel.scanningState != .idle && viewModel.scanningState != .preview {
                Text(stateMessage)
                    .font(.headline)
                    .foregroundColor(.appTextPrimary)
                    .padding()
                    .background(Color.charcoalBlack.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.top, 20)
            }
            
            Spacer()
            
            // Visual indicator for detected receipt
            if viewModel.scanningState == .receiptCandidateDetected || viewModel.scanningState == .stableReceiptConfirmed {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(viewModel.scanningState == .stableReceiptConfirmed ? .appMint : .appTextSecondary)
                        // Note: symbolEffect is SF Symbols specific, using animation instead
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.scanningState)
                    
                    if viewModel.scanningState == .stableReceiptConfirmed {
                        Text("Hold steady...")
                            .font(.subheadline)
                            .foregroundColor(.appTextPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }
    
    private var stateMessage: String {
        switch viewModel.scanningState {
        case .idle:
            return ""
        case .searchingForReceipt:
            return "Searching for receipt..."
        case .receiptCandidateDetected:
            return "Receipt detected"
        case .stableReceiptConfirmed:
            return "Hold steady..."
        case .capturedAndProcessing:
            return "Processing..."
        case .preview:
            return ""
        }
    }
}

