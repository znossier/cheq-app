//
//  Constants.swift
//  FairShare
//
//  App-wide constants
//

import Foundation

enum Constants {
    static let maxReceiptsToStore = 5
    static let minimumTapTargetSize: CGFloat = 44.0
    
    // Scanning configuration
    static let scanningConfidenceThreshold: Double = 0.6
    static let scanningStabilityDuration: TimeInterval = 1.0 // 1000ms
    static let scanningFrameRateLimit: TimeInterval = 0.5 // Max 2 fps
    static let receiptMinAspectRatio: Double = 1.2
    static let receiptMinSizeRatio: Double = 0.2 // 20% of frame width
    
    // Feature flags
    static let enableLiveScanning = false // Disabled during pipeline hardening
}

