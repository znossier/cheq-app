//
//  ScanViewModel.swift
//  Cheq
//
//  Receipt scanning view model
//

import Foundation
import UIKit
import Combine

@MainActor
class ScanViewModel: ObservableObject {
    @Published var scanningState: ScanningState = .idle
    @Published var scanResult: OCRResult?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var receiptCandidate: ReceiptCandidate?
    @Published var frozenImage: UIImage?
    
    private let ocrService = OCRService.shared
    private var stabilityStartTime: Date?
    private var lastCandidateText: String?
    private var lastCandidateRect: CGRect?
    private var lastFrameProcessTime: Date?
    private var errorDismissTask: Task<Void, Never>?
    
    init() {
        // Initialize to searching state when view model is created
        scanningState = .searchingForReceipt
    }
    
    func processVideoFrame(_ image: UIImage) {
        // Live scanning disabled during pipeline hardening
        guard Constants.enableLiveScanning else {
            return
        }
        
        // Respect state - don't process frames in certain states
        guard scanningState == .searchingForReceipt || scanningState == .receiptCandidateDetected || scanningState == .stableReceiptConfirmed else {
            return
        }
        
        // Frame rate limiting
        let now = Date()
        if let lastTime = lastFrameProcessTime,
           now.timeIntervalSince(lastTime) < Constants.scanningFrameRateLimit {
            return
        }
        lastFrameProcessTime = now
        
        Task {
            await processFrame(image)
        }
    }
    
    private func processFrame(_ image: UIImage) async {
        do {
            // Step 1: Detect rectangles
            let rectangles = try await ocrService.detectRectangles(in: image)
            
            guard let bestRectangle = rectangles.first else {
                // No rectangle detected, reset to searching
                await MainActor.run {
                    if self.scanningState != .searchingForReceipt {
                        self.scanningState = .searchingForReceipt
                        self.receiptCandidate = nil
                        self.stabilityStartTime = nil
                        self.lastCandidateText = nil
                        self.lastCandidateRect = nil
                    }
                }
                return
            }
            
            // Step 2: Process OCR using unified method
            let ocrResult = try await ocrService.processImageUnified(image, sourceType: "live")
            
            // Extract text from bounding boxes for stability comparison
            let detectedText = ocrResult.boundingBoxes.map { $0.text }.joined(separator: " ")
            
            // Calculate confidence based on number of items and bounding boxes found
            let confidence = min(1.0, Double(ocrResult.items.count) / 10.0 + Double(ocrResult.boundingBoxes.count) / 20.0)
            
            guard confidence >= Constants.scanningConfidenceThreshold else {
                // Low confidence, reset to searching
                await MainActor.run {
                    if self.scanningState != .searchingForReceipt {
                        self.scanningState = .searchingForReceipt
                        self.receiptCandidate = nil
                        self.stabilityStartTime = nil
                        self.lastCandidateText = nil
                        self.lastCandidateRect = nil
                    }
                }
                return
            }
            
            await MainActor.run {
                // Check stability
                if self.scanningState == .receiptCandidateDetected || self.scanningState == .stableReceiptConfirmed {
                    if self.isStable(rect: bestRectangle, text: detectedText) {
                        // Receipt is stable
                        if self.scanningState == .receiptCandidateDetected {
                            self.scanningState = .stableReceiptConfirmed
                            // Haptic feedback disabled during pipeline hardening
                            // let generator = UINotificationFeedbackGenerator()
                            // generator.notificationOccurred(.success)
                        }
                        
                        // Auto-capture disabled during pipeline hardening
                        // Check if stable long enough for auto-capture
                        // if let startTime = self.stabilityStartTime,
                        //    Date().timeIntervalSince(startTime) >= Constants.scanningStabilityDuration {
                        //     // Auto-capture!
                        //     self.autoCapture(image: image)
                        // }
                    } else {
                        // Not stable, reset
                        self.scanningState = .receiptCandidateDetected
                        self.stabilityStartTime = Date()
                        self.lastCandidateText = detectedText
                        self.lastCandidateRect = bestRectangle
                    }
                } else {
                    // New candidate detected
                    self.scanningState = .receiptCandidateDetected
                    let imageSize = CGSize(width: image.size.width, height: image.size.height)
                    self.receiptCandidate = ReceiptCandidate(
                        boundingRectangle: bestRectangle,
                        confidenceScore: confidence,
                        detectedText: detectedText,
                        imageSize: imageSize
                    )
                    self.stabilityStartTime = Date()
                    self.lastCandidateText = detectedText
                    self.lastCandidateRect = bestRectangle
                }
            }
        } catch {
            await MainActor.run {
                // On error, reset to searching
                if self.scanningState != .searchingForReceipt {
                    self.scanningState = .searchingForReceipt
                    self.receiptCandidate = nil
                    self.stabilityStartTime = nil
                }
            }
        }
    }
    
    private func isStable(rect: CGRect, text: String) -> Bool {
        guard let lastRect = lastCandidateRect, let lastText = lastCandidateText else {
            return false
        }
        
        // Check rectangle overlap (IOU)
        let intersection = rect.intersection(lastRect)
        let union = rect.union(lastRect)
        let iou = (intersection.width * intersection.height) / (union.width * union.height)
        
        // Check text similarity (simple comparison)
        let textSimilarity = calculateTextSimilarity(text, lastText)
        
        // Consider stable if IOU > 0.8 and text similarity > 0.7
        return iou > 0.8 && textSimilarity > 0.7
    }
    
    private func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }
    
    private func autoCapture(image: UIImage) {
        // Auto-capture disabled during pipeline hardening
        // This method is kept for potential future re-enablement
        guard Constants.enableLiveScanning else {
            return
        }
        
        scanningState = .capturedAndProcessing
        frozenImage = image
        
        Task {
            do {
                let result = try await ocrService.processImage(image)
                await MainActor.run {
                    self.scanResult = result
                    self.scanningState = .preview
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to process receipt. Please try again."
                    self.scanningState = .searchingForReceipt
                    self.frozenImage = nil
                    self.isLoading = false
                }
            }
        }
    }
    
    func manualCapture(image: UIImage) {
        // Manual capture for when live scanning is disabled
        scanningState = .capturedAndProcessing
        frozenImage = image
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Use unified processing method
                let result = try await ocrService.processImageUnified(image, sourceType: "live")
                await MainActor.run {
                    // Check if result is empty (no items and no totals)
                    if isOCRResultEmpty(result) {
                        self.errorMessage = "Nothing Detected"
                        self.scanningState = .searchingForReceipt
                        self.scanResult = nil // Don't set scanResult to prevent navigation
                        self.frozenImage = nil
                        self.isLoading = false
                        self.scheduleErrorDismiss()
                    } else {
                        self.scanResult = result
                        self.scanningState = .preview
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to process receipt. Please try again."
                    self.scanningState = .searchingForReceipt
                    self.frozenImage = nil
                    self.isLoading = false
                    self.scheduleErrorDismiss()
                }
            }
        }
    }
    
    func processImage(_ image: UIImage) {
        // Method for manual image selection (from photo library or camera)
        isLoading = true
        errorMessage = nil
        scanningState = .capturedAndProcessing
        frozenImage = image
        
        Task {
            do {
                // Use unified processing method
                let result = try await ocrService.processImageUnified(image, sourceType: "uploaded")
                await MainActor.run {
                    // Check if result is empty (no items and no totals)
                    if isOCRResultEmpty(result) {
                        self.errorMessage = "Nothing Detected"
                        self.scanningState = .searchingForReceipt
                        self.scanResult = nil // Don't set scanResult to prevent navigation
                        self.frozenImage = nil
                        self.isLoading = false
                        self.scheduleErrorDismiss()
                    } else {
                        self.scanResult = result
                        self.scanningState = .preview
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to process receipt. Please try again."
                    self.scanningState = .searchingForReceipt
                    self.frozenImage = nil
                    self.isLoading = false
                    self.scheduleErrorDismiss()
                }
            }
        }
    }
    
    func resetScanning() {
        scanningState = .searchingForReceipt
        receiptCandidate = nil
        stabilityStartTime = nil
        lastCandidateText = nil
        lastCandidateRect = nil
        frozenImage = nil
        scanResult = nil
        errorMessage = nil
        errorDismissTask?.cancel()
        errorDismissTask = nil
    }
    
    /// Check if OCR result is empty (no items and no totals/subtotals)
    private func isOCRResultEmpty(_ result: OCRResult) -> Bool {
        return result.items.isEmpty && result.total == nil && result.subtotal == nil
    }
    
    /// Schedule automatic dismissal of error message after 4 seconds
    private func scheduleErrorDismiss() {
        errorDismissTask?.cancel()
        errorDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
                // Check if task was cancelled before clearing error message
                guard !Task.isCancelled else { return }
                self.errorMessage = nil
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }
    
    /// Convert image coordinates to view coordinates
    /// Assumes videoGravity is .resizeAspectFill (as set in CameraViewController)
    /// - Parameters:
    ///   - imageRect: Rectangle in image coordinates
    ///   - imageSize: Size of the original image
    ///   - viewSize: Size of the view/preview layer
    /// - Returns: Rectangle in view coordinates
    func convertImageRectToViewRect(
        imageRect: CGRect,
        imageSize: CGSize,
        viewSize: CGSize
    ) -> CGRect {
        // Normalize imageRect to 0-1 coordinates
        let normalizedRect = CGRect(
            x: imageRect.origin.x / imageSize.width,
            y: imageRect.origin.y / imageSize.height,
            width: imageRect.width / imageSize.width,
            height: imageRect.height / imageSize.height
        )
        
        // Calculate aspect ratios
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var convertedRect: CGRect
        
        // For resizeAspectFill, the image is scaled to fill the view, cropping if necessary
        if imageAspect > viewAspect {
            // Image is wider - height fills view, width is cropped
            let scaledHeight = viewSize.height
            let scaledWidth = imageAspect * scaledHeight
            let xOffset = (scaledWidth - viewSize.width) / 2
            
            convertedRect = CGRect(
                x: normalizedRect.origin.x * scaledWidth - xOffset,
                y: normalizedRect.origin.y * scaledHeight,
                width: normalizedRect.width * scaledWidth,
                height: normalizedRect.height * scaledHeight
            )
        } else {
            // Image is taller - width fills view, height is cropped
            let scaledWidth = viewSize.width
            let scaledHeight = scaledWidth / imageAspect
            let yOffset = (scaledHeight - viewSize.height) / 2
            
            convertedRect = CGRect(
                x: normalizedRect.origin.x * scaledWidth,
                y: normalizedRect.origin.y * scaledHeight - yOffset,
                width: normalizedRect.width * scaledWidth,
                height: normalizedRect.height * scaledHeight
            )
        }
        
        // Clamp to view bounds
        convertedRect = convertedRect.intersection(CGRect(origin: .zero, size: viewSize))
        
        return convertedRect
    }
}

