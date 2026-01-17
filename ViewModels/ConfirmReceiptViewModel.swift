//
//  ConfirmReceiptViewModel.swift
//  Cheq
//
//  Confirm receipt view model
//

import Foundation
import Combine
import UIKit

@MainActor
class ConfirmReceiptViewModel: ObservableObject {
    @Published var receipt: Receipt
    @Published var isValid = false
    @Published var isPreviewMode: Bool
    @Published var previewImage: UIImage?
    @Published var boundingBoxes: [BoundingBox]?
    // Non-reactive storage for drafts - prevents view recreation when drafts change
    private var editingItemDrafts: [UUID: (name: String, unitPrice: Decimal, quantity: Int)] = [:]
    
    // Computed properties for totals that include drafts
    var calculatedSubtotal: Decimal {
        var subtotal = Decimal(0)
        for item in receipt.items {
            if let draft = editingItemDrafts[item.id] {
                subtotal += draft.unitPrice * Decimal(draft.quantity)
            } else {
                subtotal += item.totalPrice
            }
        }
        return subtotal
    }
    
    var calculatedVatAmount: Decimal {
        calculatedSubtotal * (receipt.vatPercentage / 100)
    }
    
    var calculatedServiceAmount: Decimal {
        calculatedSubtotal * (receipt.servicePercentage / 100)
    }
    
    var calculatedTotal: Decimal {
        calculatedSubtotal + calculatedVatAmount + calculatedServiceAmount
    }
    @Published var editingItemId: UUID? {
        didSet {
        }
    }
    let ocrResult: OCRResult
    
    private let storageService = StorageService.shared
    
    init(ocrResult: OCRResult, isPreview: Bool = false) {
        self.ocrResult = ocrResult
        self.isPreviewMode = isPreview
        self.previewImage = ocrResult.sourceImage
        self.boundingBoxes = ocrResult.boundingBoxes
        
        let items = ocrResult.items
        let subtotal = ocrResult.subtotal ?? items.reduce(Decimal(0)) { $0 + $1.totalPrice }
        let total = ocrResult.total ?? subtotal
        
        self.receipt = Receipt(
            items: items,
            subtotal: subtotal,
            vatPercentage: ocrResult.vatPercentage ?? 14,
            servicePercentage: ocrResult.servicePercentage ?? 12,
            total: total
        )
        
        updateValidity()
    }
    
    func confirmPreview() {
        isPreviewMode = false
    }
    
    func setEditingDraft(id: UUID, name: String, unitPrice: Decimal, quantity: Int) {
        editingItemDrafts[id] = (name: name, unitPrice: unitPrice, quantity: quantity)
        // Don't trigger any view updates - totals will update on next natural view evaluation
        // This prevents ForEach from recreating ReceiptItemRow views
    }
    
    func getEditingDraft(id: UUID) -> (name: String, unitPrice: Decimal, quantity: Int)? {
        return editingItemDrafts[id]
    }
    
    func clearEditingDraft(id: UUID) {
        editingItemDrafts.removeValue(forKey: id)
        // Don't trigger any view updates - totals will update on next natural view evaluation
    }
    
    func updateItem(id: UUID, name: String? = nil, unitPrice: Decimal? = nil, quantity: Int? = nil, commitDraft: Bool = false) {
        guard let index = receipt.items.firstIndex(where: { $0.id == id }) else { return }
        
        // If commitDraft is true, we're actually updating the item (user tapped Done)
        // Otherwise, we're just storing a draft (user is still editing)
        if commitDraft {
            // Always update all fields when committing - don't use optional chaining
            // CRITICAL: Modify the item, then reassign the entire receipt to trigger @Published update
            var updatedItem = receipt.items[index]
            if let name = name {
                updatedItem.name = name
            }
            if let unitPrice = unitPrice {
                updatedItem.unitPrice = unitPrice
            }
            if let quantity = quantity, quantity >= 1 {
                updatedItem.quantity = quantity
                updatedItem.ensureUnitAssignmentsCount()
            }
            // Update the items array
            var updatedItems = receipt.items
            updatedItems[index] = updatedItem
            // Reassign the entire receipt to trigger @Published update
            // This is necessary because Receipt is a struct, so modifying nested properties doesn't trigger @Published
            let newReceipt = Receipt(
                id: receipt.id,
                items: updatedItems,
                subtotal: receipt.subtotal,
                vatPercentage: receipt.vatPercentage,
                servicePercentage: receipt.servicePercentage,
                total: receipt.total,
                timestamp: receipt.timestamp,
                people: receipt.people
            )
            receipt = newReceipt
            // Force objectWillChange to ensure view updates
            objectWillChange.send()
            // Clear draft since we've committed it
            editingItemDrafts.removeValue(forKey: id)
            recalculateTotals()
        } else {
            // Just store draft, don't update item (prevents view recreation)
            // Totals are already recalculated in setEditingDraft
        }
        
    }
    
    func deleteItem(id: UUID) {
        receipt.items.removeAll { $0.id == id }
        recalculateTotals()
    }
    
    func updateVATPercentage(_ percentage: Decimal) {
        // Clamp to 0-100 and ensure integer value
        let clamped = max(0, min(100, percentage))
        receipt.vatPercentage = clamped.rounded(0, .plain)
        recalculateTotals()
    }
    
    func updateServicePercentage(_ percentage: Decimal) {
        // Clamp to 0-100 and ensure integer value
        let clamped = max(0, min(100, percentage))
        receipt.servicePercentage = clamped.rounded(0, .plain)
        recalculateTotals()
    }
    
    private func recalculateTotals() {
        receipt.subtotal = receipt.items.reduce(Decimal(0)) { $0 + $1.totalPrice }
        receipt.total = receipt.calculatedTotal
        updateValidity()
    }
    
    // Removed recalculateTotalsWithDrafts - we now use computed properties instead
    // This prevents view recreation during editing
    
    private func updateValidity() {
        isValid = !receipt.items.isEmpty && calculatedTotal > 0
    }
}

