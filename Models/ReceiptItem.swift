//
//  ReceiptItem.swift
//  Cheq
//
//  Receipt item model with quantity support
//

import Foundation

struct ReceiptItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var unitPrice: Decimal
    var quantity: Int
    var unitAssignments: [[UUID]] // Array of arrays, one per unit. Each inner array contains person IDs assigned to that unit.
    
    init(id: UUID = UUID(), name: String, unitPrice: Decimal, quantity: Int = 1, unitAssignments: [[UUID]] = []) {
        self.id = id
        self.name = name
        self.unitPrice = unitPrice
        self.quantity = quantity
        // Initialize unitAssignments with empty arrays for each unit
        if unitAssignments.isEmpty {
            self.unitAssignments = Array(repeating: [], count: quantity)
        } else {
            self.unitAssignments = unitAssignments
        }
    }
    
    var totalPrice: Decimal {
        unitPrice * Decimal(quantity)
    }
    
    mutating func ensureUnitAssignmentsCount() {
        while unitAssignments.count < quantity {
            unitAssignments.append([])
        }
        while unitAssignments.count > quantity {
            unitAssignments.removeLast()
        }
    }
}

