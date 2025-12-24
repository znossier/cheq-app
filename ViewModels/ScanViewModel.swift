//
//  ScanViewModel.swift
//  FairShare
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
            
            // Step 2: Process OCR within rectangle
            let (observations, confidence) = try await ocrService.processImageInRectangle(image, rect: bestRectangle)
            
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
            
            // Extract text for stability comparison
            let detectedText = observations.compactMap { $0.topCandidates(1).first?.string ?? "" }.joined(separator: " ")
            
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
                    self.receiptCandidate = ReceiptCandidate(
                        boundingRectangle: bestRectangle,
                        confidenceScore: confidence,
                        detectedText: detectedText
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
    
    func resetScanning() {
        scanningState = .searchingForReceipt
        receiptCandidate = nil
        stabilityStartTime = nil
        lastCandidateText = nil
        lastCandidateRect = nil
        frozenImage = nil
        scanResult = nil
        errorMessage = nil
    }
}

