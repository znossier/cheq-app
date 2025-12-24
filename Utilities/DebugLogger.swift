//
//  DebugLogger.swift
//  FairShare
//
//  Debug logging utility for OCR pipeline
//

import Foundation
import Vision
import UIKit

#if DEBUG

struct OCRDebugLine {
    let text: String
    let confidence: Double
    let boundingBox: CGRect
    let classification: BoundingBoxClassification?
    let classificationReason: String
    let excluded: Bool
    let exclusionReason: String?
    // Phase 4: Enhanced debug visibility
    let zone: String? // "header", "middle", "footer"
    let priceDetected: Bool
    let groupedWith: [String]? // If part of multi-line group
    let scoreBreakdown: [String: Double]? // Individual rule scores
    
    init(
        text: String,
        confidence: Double,
        boundingBox: CGRect,
        classification: BoundingBoxClassification? = nil,
        classificationReason: String = "",
        excluded: Bool = false,
        exclusionReason: String? = nil,
        zone: String? = nil,
        priceDetected: Bool = false,
        groupedWith: [String]? = nil,
        scoreBreakdown: [String: Double]? = nil
    ) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.classification = classification
        self.classificationReason = classificationReason
        self.excluded = excluded
        self.exclusionReason = exclusionReason
        self.zone = zone
        self.priceDetected = priceDetected
        self.groupedWith = groupedWith
        self.scoreBreakdown = scoreBreakdown
    }
}

struct OCRDebugData {
    let rawObservations: [VNRecognizedTextObservation]
    let processedLines: [OCRDebugLine]
    let imageResolution: CGSize
    let processingTime: TimeInterval
    let sourceType: String // "uploaded" or "live"
    
    init(
        rawObservations: [VNRecognizedTextObservation],
        processedLines: [OCRDebugLine],
        imageResolution: CGSize,
        processingTime: TimeInterval,
        sourceType: String
    ) {
        self.rawObservations = rawObservations
        self.processedLines = processedLines
        self.imageResolution = imageResolution
        self.processingTime = processingTime
        self.sourceType = sourceType
    }
}

#endif

