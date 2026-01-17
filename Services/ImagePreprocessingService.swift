//
//  ImagePreprocessingService.swift
//  Cheq
//
//  Image preprocessing service for OCR accuracy improvement
//

import Foundation
import UIKit
import CoreImage

class ImagePreprocessingService {
    static let shared = ImagePreprocessingService()
    
    private let context: CIContext
    
    private init() {
        // Use GPU-accelerated context for better performance
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .workingColorSpace: CGColorSpaceCreateDeviceRGB()
        ]
        self.context = CIContext(options: options)
    }
    
    /// Main preprocessing pipeline for OCR
    /// Applies all enhancements in optimal order
    func preprocessForOCR(_ image: UIImage, receiptRect: CGRect? = nil) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        var ciImage = CIImage(cgImage: cgImage)
        
        // Step 1: Correct orientation
        ciImage = correctOrientation(ciImage, originalImage: image)
        
        // Step 2: Crop to receipt area if rectangle detected
        if let rect = receiptRect {
            ciImage = cropToRect(ciImage, rect: rect)
        }
        
        // Step 3: Enhance contrast (CLAHE-like effect)
        ciImage = enhanceContrast(ciImage)
        
        // Step 4: Denoise (reduce noise while preserving text)
        ciImage = denoise(ciImage)
        
        // Step 5: Sharpen text edges
        ciImage = sharpen(ciImage)
        
        // Step 6: Binarize (convert to black/white for better OCR)
        ciImage = binarize(ciImage)
        
        // Step 7: Convert back to UIImage
        guard let outputCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
    }
    
    /// Enhance contrast using adaptive histogram equalization
    private func enhanceContrast(_ image: CIImage) -> CIImage {
        // Use CIColorControls for contrast enhancement
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.2, forKey: kCIInputContrastKey) // Increase contrast by 20%
        filter.setValue(0.0, forKey: kCIInputSaturationKey) // Desaturate for better text recognition
        filter.setValue(0.05, forKey: kCIInputBrightnessKey) // Slight brightness adjustment
        
        return filter.outputImage ?? image
    }
    
    /// Sharpen image to enhance text edges
    private func sharpen(_ image: CIImage) -> CIImage {
        // Use unsharp mask filter
        guard let filter = CIFilter(name: "CIUnsharpMask") else { return image }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.5, forKey: kCIInputRadiusKey) // Radius for sharpening
        filter.setValue(0.8, forKey: kCIInputIntensityKey) // Intensity of sharpening
        
        return filter.outputImage ?? image
    }
    
    /// Denoise image while preserving text
    private func denoise(_ image: CIImage) -> CIImage {
        // Use median filter for noise reduction (more widely available than CINoiseReduction)
        // Apply light blur to reduce noise while preserving text
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return image }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.5, forKey: kCIInputRadiusKey) // Very light blur to reduce noise
        
        return filter.outputImage ?? image
    }
    
    /// Binarize image (convert to black and white)
    /// This improves OCR accuracy by removing color variations
    private func binarize(_ image: CIImage) -> CIImage {
        // Convert to grayscale first
        guard let grayscaleFilter = CIFilter(name: "CIColorControls") else { return image }
        grayscaleFilter.setValue(image, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        
        guard let grayscale = grayscaleFilter.outputImage else { return image }
        
        // Apply threshold to create black/white image
        // Use a simpler approach with exposure adjustment for binarization
        guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return grayscale }
        exposureFilter.setValue(grayscale, forKey: kCIInputImageKey)
        exposureFilter.setValue(0.0, forKey: kCIInputEVKey) // Adjust exposure
        
        guard let adjusted = exposureFilter.outputImage else { return grayscale }
        
        // Apply threshold using color controls
        guard let finalFilter = CIFilter(name: "CIColorControls") else { return adjusted }
        finalFilter.setValue(adjusted, forKey: kCIInputImageKey)
        finalFilter.setValue(2.0, forKey: kCIInputContrastKey) // High contrast for binarization
        
        return finalFilter.outputImage ?? adjusted
    }
    
    /// Correct image orientation
    private func correctOrientation(_ image: CIImage, originalImage: UIImage) -> CIImage {
        // If image is already correctly oriented, return as-is
        if originalImage.imageOrientation == .up {
            return image
        }
        
        // Apply orientation transform
        let transform = orientationTransform(for: originalImage.imageOrientation, size: image.extent.size)
        return image.transformed(by: transform)
    }
    
    /// Get transform for image orientation
    private func orientationTransform(for orientation: UIImage.Orientation, size: CGSize) -> CGAffineTransform {
        switch orientation {
        case .up:
            return .identity
        case .down:
            return CGAffineTransform(translationX: size.width, y: size.height).rotated(by: .pi)
        case .left:
            return CGAffineTransform(translationX: size.height, y: 0).rotated(by: .pi / 2)
        case .right:
            return CGAffineTransform(translationX: 0, y: size.width).rotated(by: -.pi / 2)
        case .upMirrored:
            return CGAffineTransform(translationX: size.width, y: 0).scaledBy(x: -1, y: 1)
        case .downMirrored:
            return CGAffineTransform(translationX: 0, y: size.height).scaledBy(x: 1, y: -1)
        case .leftMirrored:
            return CGAffineTransform(translationX: size.height, y: size.width)
                .scaledBy(x: -1, y: 1)
                .rotated(by: .pi / 2)
        case .rightMirrored:
            return CGAffineTransform(translationX: 0, y: 0)
                .scaledBy(x: 1, y: -1)
                .rotated(by: -.pi / 2)
        @unknown default:
            return .identity
        }
    }
    
    /// Crop image to specified rectangle
    private func cropToRect(_ image: CIImage, rect: CGRect) -> CIImage {
        // Ensure rect is within image bounds
        let imageExtent = image.extent
        let croppedRect = rect.intersection(imageExtent)
        
        guard !croppedRect.isEmpty else { return image }
        
        return image.cropped(to: croppedRect)
    }
    
    /// Enhance contrast using CLAHE-like approach
    func enhanceContrast(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let enhanced = enhanceContrast(ciImage)
        
        guard let outputCGImage = context.createCGImage(enhanced, from: enhanced.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
    }
    
    /// Sharpen image
    func sharpen(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let sharpened = sharpen(ciImage)
        
        guard let outputCGImage = context.createCGImage(sharpened, from: sharpened.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
    }
    
    /// Correct perspective using detected rectangle
    func correctPerspective(_ image: UIImage, rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        
        // Use perspective correction filter
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            // Fallback to cropping if perspective correction not available
            let corrected = cropToRect(ciImage, rect: rect)
            guard let outputCGImage = context.createCGImage(corrected, from: corrected.extent) else {
                return nil
            }
            return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
        }
        
        // Calculate corner points from rect
        let topLeft = CIVector(x: rect.minX, y: rect.maxY)
        let topRight = CIVector(x: rect.maxX, y: rect.maxY)
        let bottomRight = CIVector(x: rect.maxX, y: rect.minY)
        let bottomLeft = CIVector(x: rect.minX, y: rect.minY)
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(topLeft, forKey: "inputTopLeft")
        filter.setValue(topRight, forKey: "inputTopRight")
        filter.setValue(bottomRight, forKey: "inputBottomRight")
        filter.setValue(bottomLeft, forKey: "inputBottomLeft")
        
        guard let output = filter.outputImage,
              let outputCGImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
    }
    
    /// Binarize image (convert to black and white)
    func binarize(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let binarized = binarize(ciImage)
        
        guard let outputCGImage = context.createCGImage(binarized, from: binarized.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
    }
}

