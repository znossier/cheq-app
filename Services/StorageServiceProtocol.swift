//
//  StorageServiceProtocol.swift
//  Cheq
//
//  Protocol for storage service abstraction
//

import Foundation

protocol StorageServiceProtocol {
    /// Saves a receipt for a specific user
    func saveReceipt(_ receipt: Receipt, userId: String) async throws
    
    /// Loads all receipts for a specific user
    func loadAllReceipts(userId: String) async throws -> [Receipt]
    
    /// Deletes a receipt for a specific user
    func deleteReceipt(_ receiptId: UUID, userId: String) async throws
    
    /// Saves currency preference
    func saveCurrency(_ currency: Currency) async throws
    
    /// Loads currency preference
    func loadCurrency() async throws -> Currency
}

