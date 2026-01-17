//
//  CalculationService.swift
//  Cheq
//
//  Service for calculating fair bill splits
//

import Foundation

struct PersonSplit {
    let person: Person
    var itemTotal: Decimal
    var vatShare: Decimal
    var serviceShare: Decimal
    var finalAmount: Decimal
    var items: [ReceiptItem]
}

class CalculationService {
    static let shared = CalculationService()
    
    private init() {}
    
    func calculateSplits(for receipt: Receipt) -> [PersonSplit] {
        var splits: [UUID: PersonSplit] = [:]
        
        // Initialize splits for all people
        for person in receipt.people {
            splits[person.id] = PersonSplit(
                person: person,
                itemTotal: 0,
                vatShare: 0,
                serviceShare: 0,
                finalAmount: 0,
                items: []
            )
        }
        
        // Calculate item costs per person
        for item in receipt.items {
            var mutableItem = item
            mutableItem.ensureUnitAssignmentsCount()
            
            for (unitIndex, assignedPersonIds) in mutableItem.unitAssignments.enumerated() {
                guard unitIndex < mutableItem.quantity, !assignedPersonIds.isEmpty else { continue }
                
                let unitCost = mutableItem.unitPrice
                let sharePerPerson = unitCost / Decimal(assignedPersonIds.count)
                
                for personId in assignedPersonIds {
                    if var split = splits[personId] {
                        split.itemTotal += sharePerPerson
                        // Track which items this person has
                        var itemCopy = mutableItem
                        itemCopy.quantity = 1
                        split.items.append(itemCopy)
                        splits[personId] = split
                    }
                }
            }
        }
        
        // Calculate proportional VAT and service fees
        let subtotal = receipt.subtotal
        guard subtotal > 0 else {
            return Array(splits.values)
        }
        
        let totalVAT = receipt.vatAmount
        let totalService = receipt.serviceAmount
        
        for personId in splits.keys {
            if var split = splits[personId] {
                // Proportional distribution
                let proportion = split.itemTotal / subtotal
                split.vatShare = (totalVAT * proportion).rounded(2, .plain)
                split.serviceShare = (totalService * proportion).rounded(2, .plain)
                split.finalAmount = (split.itemTotal + split.vatShare + split.serviceShare).rounded(2, .plain)
                splits[personId] = split
            }
        }
        
        // Apply rounding adjustments to match receipt total exactly
        let calculatedTotal = splits.values.reduce(Decimal(0)) { $0 + $1.finalAmount }
        let difference = receipt.total - calculatedTotal
        
        if abs(difference.doubleValue) > 0.01 {
            // Distribute rounding difference to the person with the largest amount
            if let maxSplit = splits.values.max(by: { $0.finalAmount < $1.finalAmount }),
               let personId = splits.keys.first(where: { splits[$0]?.person.id == maxSplit.person.id }) {
                splits[personId]?.finalAmount += difference
            }
        }
        
        return Array(splits.values).sorted { $0.person.name < $1.person.name }
    }
    
    func validateAssignments(for receipt: Receipt) -> Bool {
        for item in receipt.items {
            var mutableItem = item
            mutableItem.ensureUnitAssignmentsCount()
            for (index, assignments) in mutableItem.unitAssignments.enumerated() {
                if index >= mutableItem.quantity {
                    continue
                }
                if assignments.isEmpty {
                    return false // At least one unit is not assigned
                }
            }
        }
        return true
    }
}

