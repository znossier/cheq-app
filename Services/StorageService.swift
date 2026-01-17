//
//  StorageService.swift
//  Cheq
//
//  Service for storing and retrieving receipts and user preferences
//

import Foundation

class StorageService: ObservableObject {
    static let shared = StorageService()
    
    private let oldReceiptsKey = "storedReceipts" // Legacy key for migration
    private let currencyKey = "userCurrency"
    private let migrationCompletedKey = "receiptsMigrationCompleted"
    private let coreDataMigrationCompletedKey = "coreDataMigrationCompleted"
    
    private let backend: StorageServiceProtocol
    
    private init() {
        // Initialize Core Data backend
        self.backend = CoreDataStorageService()
    }
    
    // MARK: - Receipts Storage
    
    /// Generates a user-specific key for storing receipts (legacy UserDefaults)
    private func receiptsKey(for userId: String) -> String {
        return "receipts_\(userId)"
    }
    
    /// Saves a receipt for a specific user. Stores all receipts (no limit).
    func saveReceipt(_ receipt: Receipt, userId: String) {
        print("💾 StorageService: Starting save for receipt \(receipt.id), user \(userId)")
        Task {
            do {
                try await backend.saveReceipt(receipt, userId: userId)
                print("✅ StorageService: Successfully saved receipt \(receipt.id)")
            } catch {
                print("❌ StorageService: Error saving receipt \(receipt.id): \(error.localizedDescription)")
                print("   Full error: \(error)")
            }
        }
    }
    
    /// Saves a receipt for a specific user (async version that can be awaited).
    func saveReceiptAsync(_ receipt: Receipt, userId: String) async throws {
        print("💾 StorageService: Starting async save for receipt \(receipt.id), user \(userId)")
        try await backend.saveReceipt(receipt, userId: userId)
        print("✅ StorageService: Successfully saved receipt \(receipt.id)")
    }
    
    /// Loads all receipts for a specific user (async version)
    func loadAllReceipts(userId: String) async throws -> [Receipt] {
        return try await backend.loadAllReceipts(userId: userId)
    }
    
    /// Loads all receipts for a specific user (synchronous version - deprecated, use async version)
    @available(*, deprecated, message: "Use async loadAllReceipts instead")
    func loadAllReceiptsSync(userId: String) -> [Receipt] {
        // For synchronous access, use a semaphore to wait for async operation
        let semaphore = DispatchSemaphore(value: 0)
        var receipts: [Receipt] = []
        
        Task {
            do {
                receipts = try await backend.loadAllReceipts(userId: userId)
            } catch {
                print("Error loading receipts: \(error)")
                receipts = []
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return receipts
    }
    
    /// Loads receipts for a specific user (for backward compatibility, same as loadAllReceipts)
    func loadReceipts(userId: String) async throws -> [Receipt] {
        return try await loadAllReceipts(userId: userId)
    }
    
    /// Deletes a receipt for a specific user
    func deleteReceipt(_ receiptId: UUID, userId: String) async throws {
        try await backend.deleteReceipt(receiptId, userId: userId)
    }
    
    /// Deletes all receipts for a specific user
    func deleteAllReceipts(userId: String) async throws {
        let receipts = try await loadAllReceipts(userId: userId)
        for receipt in receipts {
            try await deleteReceipt(receipt.id, userId: userId)
        }
    }
    
    /// Migrates existing UserDefaults receipts to Core Data + CloudKit
    /// Should be called once when the app starts with an authenticated user
    func migrateReceiptsIfNeeded(to userId: String) {
        // Check if Core Data migration has already been completed
        if UserDefaults.standard.bool(forKey: coreDataMigrationCompletedKey) {
            return
        }
        
        Task {
            await performCoreDataMigration(userId: userId)
        }
    }
    
    /// Performs migration from UserDefaults to Core Data
    private func performCoreDataMigration(userId: String) async {
        // Check if old receipts exist in UserDefaults
        let key = receiptsKey(for: userId)
        guard let data = UserDefaults.standard.data(forKey: key),
              let receipts = try? JSONDecoder().decode([Receipt].self, from: data),
              !receipts.isEmpty else {
            // Also check legacy key
            guard let legacyData = UserDefaults.standard.data(forKey: oldReceiptsKey),
                  let legacyReceipts = try? JSONDecoder().decode([Receipt].self, from: legacyData),
                  !legacyReceipts.isEmpty else {
                // Mark migration as completed even if no old receipts exist
                UserDefaults.standard.set(true, forKey: coreDataMigrationCompletedKey)
                return
            }
            
            // Migrate legacy receipts
            await migrateReceipts(legacyReceipts, userId: userId)
            UserDefaults.standard.removeObject(forKey: oldReceiptsKey)
            UserDefaults.standard.set(true, forKey: coreDataMigrationCompletedKey)
            return
        }
        
        // Migrate user-specific receipts
        await migrateReceipts(receipts, userId: userId)
        
        // Mark migration as completed
        UserDefaults.standard.set(true, forKey: coreDataMigrationCompletedKey)
    }
    
    /// Migrates an array of receipts to Core Data
    private func migrateReceipts(_ receipts: [Receipt], userId: String) async {
        for receipt in receipts {
            do {
                try await backend.saveReceipt(receipt, userId: userId)
            } catch {
                print("Error migrating receipt \(receipt.id): \(error)")
            }
        }
    }
    
    // MARK: - Currency Preference
    
    func saveCurrency(_ currency: Currency) {
        Task {
            do {
                try await backend.saveCurrency(currency)
            } catch {
                print("Error saving currency: \(error)")
            }
        }
    }
    
    func loadCurrency() -> Currency {
        // For synchronous access, use a semaphore to wait for async operation
        let semaphore = DispatchSemaphore(value: 0)
        var currency: Currency = .egp
        
        Task {
            do {
                currency = try await backend.loadCurrency()
            } catch {
                print("Error loading currency: \(error)")
                currency = .egp
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return currency
    }
}

