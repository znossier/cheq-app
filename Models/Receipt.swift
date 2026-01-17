//
//  Receipt.swift
//  Cheq
//
//  Receipt data model
//

import Foundation

struct Receipt: Identifiable, Codable {
    let id: UUID
    var items: [ReceiptItem]
    var subtotal: Decimal
    var vatPercentage: Decimal
    var servicePercentage: Decimal
    var total: Decimal
    var timestamp: Date
    var people: [Person]
    
    init(
        id: UUID = UUID(),
        items: [ReceiptItem] = [],
        subtotal: Decimal = 0,
        vatPercentage: Decimal = 0,
        servicePercentage: Decimal = 0,
        total: Decimal = 0,
        timestamp: Date = Date(),
        people: [Person] = []
    ) {
        self.id = id
        self.items = items
        self.subtotal = subtotal
        self.vatPercentage = vatPercentage
        self.servicePercentage = servicePercentage
        self.total = total
        self.timestamp = timestamp
        self.people = people
    }
    
    var vatAmount: Decimal {
        subtotal * (vatPercentage / 100)
    }
    
    var serviceAmount: Decimal {
        subtotal * (servicePercentage / 100)
    }
    
    var calculatedTotal: Decimal {
        subtotal + vatAmount + serviceAmount
    }
}

