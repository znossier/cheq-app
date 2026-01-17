//
//  ScanningState.swift
//  Cheq
//
//  Scanning state machine and supporting types
//

import Foundation
import UIKit

enum ScanningState: Equatable {
    case idle
    case searchingForReceipt
    case receiptCandidateDetected
    case stableReceiptConfirmed
    case capturedAndProcessing
    case preview
}

struct ReceiptCandidate: Equatable {
    let boundingRectangle: CGRect
    let confidenceScore: Double
    let detectedText: String
    let timestamp: Date
    let imageSize: CGSize // Image size for coordinate conversion
    
    init(boundingRectangle: CGRect, confidenceScore: Double, detectedText: String, imageSize: CGSize, timestamp: Date = Date()) {
        self.boundingRectangle = boundingRectangle
        self.confidenceScore = confidenceScore
        self.detectedText = detectedText
        self.imageSize = imageSize
        self.timestamp = timestamp
    }
}

enum BoundingBoxClassification: String, Codable {
    case lineItem
    case subtotal
    case tax
    case service
    case total
}

struct BoundingBox: Equatable, Identifiable {
    let id: UUID
    let rectangle: CGRect
    let text: String
    let classification: BoundingBoxClassification
    
    init(id: UUID = UUID(), rectangle: CGRect, text: String, classification: BoundingBoxClassification) {
        self.id = id
        self.rectangle = rectangle
        self.text = text
        self.classification = classification
    }
}

