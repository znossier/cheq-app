//
//  SummaryViewModel.swift
//  Cheq
//
//  Summary view model
//

import Foundation
import Combine
import UIKit

@MainActor
class SummaryViewModel: ObservableObject {
    @Published var splits: [PersonSplit] = []
    @Published var saveError: String?
    @Published var isSaving = false
    @Published var saveCompleted = false
    
    private let calculationService = CalculationService.shared
    private let storageService = StorageService.shared
    private let receipt: Receipt
    
    init(receipt: Receipt) {
        self.receipt = receipt
        Task { @MainActor in
            await calculateSplits(for: receipt)
            await saveReceipt()
        }
    }
    
    func calculateSplits(for receipt: Receipt) async {
        splits = calculationService.calculateSplits(for: receipt)
    }
        
    func saveReceipt() async {
        let authService = AuthService.shared
        guard let userId = authService.currentUser?.id else {
            print("⚠️ SummaryViewModel: Cannot save receipt - no user ID. Current user: \(String(describing: authService.currentUser))")
            saveError = "Cannot save receipt: User not authenticated"
            return
        }
        
        print("📝 SummaryViewModel: Saving receipt \(receipt.id) for user \(userId)")
        isSaving = true
        saveError = nil
        saveCompleted = false
        
        do {
            // Save receipt - simplified to use view context directly
            try await storageService.saveReceiptAsync(receipt, userId: userId)
            print("✅ SummaryViewModel: Receipt saved successfully")
            
            // Post notification immediately after save completes (merge is already done)
            NotificationCenter.default.post(name: NSNotification.Name("ReceiptSaved"), object: nil)
            print("✅ SummaryViewModel: ReceiptSaved notification posted")
            
            isSaving = false
            saveCompleted = true
        
        // Success haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        } catch {
            print("❌ SummaryViewModel: Error saving receipt: \(error.localizedDescription)")
            print("   Full error: \(error)")
            saveError = "Failed to save receipt: \(error.localizedDescription)"
            isSaving = false
            saveCompleted = false
        }
    }
    
    func generateShareText(currency: Currency) -> String {
        var text = "Cheq Summary:\n\n"
        
        for split in splits {
            let amount = split.finalAmount.formatted(currency: currency)
            text += "\(split.person.name) owes \(amount)\n"
        }
        
        text += "\nAll shares calculated correctly."
        return text
    }
}

