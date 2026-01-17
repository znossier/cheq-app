//
//  Constants.swift
//  Cheq
//
//  App-wide constants
//

import Foundation

enum Constants {
    /// Maximum number of receipts to display on the home screen
    /// All receipts are stored per user, but only this many are shown on home
    static let maxReceiptsToStore = 7 // Used for home screen display limit
    static let minimumTapTargetSize: CGFloat = 44.0
    
    // Scanning configuration
    static let scanningConfidenceThreshold: Double = 0.6
    static let scanningStabilityDuration: TimeInterval = 1.0 // 1000ms
    static let scanningFrameRateLimit: TimeInterval = 0.5 // Max 2 fps
    static let receiptMinAspectRatio: Double = 1.2
    static let receiptMinSizeRatio: Double = 0.2 // 20% of frame width
    
    // Feature flags
    static let enableLiveScanning = false // Disabled during pipeline hardening
    
    // User preferences defaults
    static let defaultVATPercentage: Decimal = 0
    static let defaultServiceFeePercentage: Decimal = 0
    static let defaultAutoSaveReceipts: Bool = true
    static let defaultHapticFeedback: Bool = true
    
    // UserDefaults keys for preferences
    static let defaultVATKey = "defaultVATPercentage"
    static let defaultServiceFeeKey = "defaultServiceFeePercentage"
    static let autoSaveKey = "autoSaveReceipts"
    static let hapticFeedbackKey = "hapticFeedbackEnabled"
}

