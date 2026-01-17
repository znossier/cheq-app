//
//  UserPreferencesService.swift
//  Cheq
//
//  Service for managing user preferences stored in UserDefaults
//

import Foundation

class UserPreferencesService {
    static let shared = UserPreferencesService()
    
    // UserDefaults keys
    private let defaultVATKey = "defaultVATPercentage"
    private let defaultServiceFeeKey = "defaultServiceFeePercentage"
    private let autoSaveKey = "autoSaveReceipts"
    private let hapticFeedbackKey = "hapticFeedbackEnabled"
    private let appearanceModeKey = "appearanceMode"
    
    private init() {}
    
    // MARK: - Default VAT Percentage
    
    func saveDefaultVATPercentage(_ percentage: Decimal) {
        // Store as String for reliable encoding/decoding
        let stringValue = NSDecimalNumber(decimal: percentage).stringValue
        UserDefaults.standard.set(stringValue, forKey: defaultVATKey)
    }
    
    func loadDefaultVATPercentage() -> Decimal {
        guard let stringValue = UserDefaults.standard.string(forKey: defaultVATKey),
              let decimalValue = Decimal(string: stringValue) else {
            return Constants.defaultVATPercentage
        }
        return decimalValue
    }
    
    // MARK: - Default Service Fee Percentage
    
    func saveDefaultServiceFeePercentage(_ percentage: Decimal) {
        // Store as String for reliable encoding/decoding
        let stringValue = NSDecimalNumber(decimal: percentage).stringValue
        UserDefaults.standard.set(stringValue, forKey: defaultServiceFeeKey)
    }
    
    func loadDefaultServiceFeePercentage() -> Decimal {
        guard let stringValue = UserDefaults.standard.string(forKey: defaultServiceFeeKey),
              let decimalValue = Decimal(string: stringValue) else {
            return Constants.defaultServiceFeePercentage
        }
        return decimalValue
    }
    
    // MARK: - Auto-save Receipts
    
    func saveAutoSaveReceipts(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: autoSaveKey)
    }
    
    func loadAutoSaveReceipts() -> Bool {
        if UserDefaults.standard.object(forKey: autoSaveKey) == nil {
            return Constants.defaultAutoSaveReceipts
        }
        return UserDefaults.standard.bool(forKey: autoSaveKey)
    }
    
    // MARK: - Haptic Feedback
    
    func saveHapticFeedbackEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: hapticFeedbackKey)
    }
    
    func loadHapticFeedbackEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: hapticFeedbackKey) == nil {
            return Constants.defaultHapticFeedback
        }
        return UserDefaults.standard.bool(forKey: hapticFeedbackKey)
    }
    
    // MARK: - Appearance Mode
    
    func saveAppearanceMode(_ mode: AppearanceMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: appearanceModeKey)
    }
    
    func loadAppearanceMode() -> AppearanceMode {
        guard let rawValue = UserDefaults.standard.string(forKey: appearanceModeKey),
              let mode = AppearanceMode(rawValue: rawValue) else {
            return .system // Default to system
        }
        return mode
    }
    
    // MARK: - Reset to Defaults
    
    func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: defaultVATKey)
        UserDefaults.standard.removeObject(forKey: defaultServiceFeeKey)
        UserDefaults.standard.removeObject(forKey: autoSaveKey)
        UserDefaults.standard.removeObject(forKey: hapticFeedbackKey)
        UserDefaults.standard.removeObject(forKey: appearanceModeKey)
    }
}

