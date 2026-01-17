//
//  AssignItemsViewModel.swift
//  Cheq
//
//  Assign items view model
//

import Foundation
import Combine
import UIKit

@MainActor
class AssignItemsViewModel: ObservableObject {
    @Published var receipt: Receipt
    @Published var personTotals: [UUID: Decimal] = [:]
    @Published var canProceed = false
    
    private let calculationService = CalculationService.shared
    
    init(receipt: Receipt) {
        self.receipt = receipt
        updateTotals()
    }
    
    func addPerson(_ person: Person) {
        if !receipt.people.contains(where: { $0.id == person.id }) {
            receipt.people.append(person)
        }
    }
    
    func togglePersonAssignment(for itemId: UUID, unitIndex: Int, personId: UUID) {
        guard let itemIndex = receipt.items.firstIndex(where: { $0.id == itemId }) else { return }
        
        var item = receipt.items[itemIndex]
        item.ensureUnitAssignmentsCount()
        
        guard unitIndex < item.unitAssignments.count else { return }
        
        var assignments = item.unitAssignments[unitIndex]
        
        if let index = assignments.firstIndex(of: personId) {
            // Only remove if there's more than one person assigned (minimum 1 required)
            if assignments.count > 1 {
                assignments.remove(at: index)
            }
        } else {
            assignments.append(personId)
        }
        
        item.unitAssignments[unitIndex] = assignments
        receipt.items[itemIndex] = item
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        
        updateTotals()
    }
    
    func isPersonAssigned(to itemId: UUID, unitIndex: Int, personId: UUID) -> Bool {
        guard let item = receipt.items.first(where: { $0.id == itemId }) else { return false }
        var mutableItem = item
        mutableItem.ensureUnitAssignmentsCount()
        guard unitIndex < mutableItem.unitAssignments.count else { return false }
        return mutableItem.unitAssignments[unitIndex].contains(personId)
    }
    
    private func updateTotals() {
        // Calculate per-person item totals (before VAT/service)
        var totals: [UUID: Decimal] = [:]
        
        for person in receipt.people {
            totals[person.id] = 0
        }
        
        for item in receipt.items {
            var mutableItem = item
            mutableItem.ensureUnitAssignmentsCount()
            for (unitIndex, assignedPersonIds) in mutableItem.unitAssignments.enumerated() {
                guard unitIndex < mutableItem.quantity, !assignedPersonIds.isEmpty else { continue }
                
                let unitCost = mutableItem.unitPrice
                let sharePerPerson = unitCost / Decimal(assignedPersonIds.count)
                
                for personId in assignedPersonIds {
                    totals[personId, default: 0] += sharePerPerson
                }
            }
        }
        
        personTotals = totals
        canProceed = CalculationService.shared.validateAssignments(for: receipt)
    }
}

