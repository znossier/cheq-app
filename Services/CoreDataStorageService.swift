//
//  CoreDataStorageService.swift
//  Cheq
//
//  Core Data implementation of StorageServiceProtocol
//

import Foundation
import CoreData

final class CoreDataStorageService: StorageServiceProtocol, @unchecked Sendable {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
    }
    
    // MARK: - Receipts Storage
    
    func saveReceipt(_ receipt: Receipt, userId: String) async throws {
        let saveStartTime = Date()
        print("💾 CoreDataStorageService: Starting save for receipt \(receipt.id)")
        print("   Receipt has \(receipt.items.count) items, \(receipt.people.count) people")
        print("   Total: \(receipt.total), Timestamp: \(receipt.timestamp)")
        
        // Access view context - container will initialize if needed and fail fast if model not found
        // Use view context directly - it's already on main thread
        return try await MainActor.run {
            let context = coreDataStack.viewContext
            
                do {
                    // Check if receipt already exists
                    let fetchRequest: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@ AND userId == %@", receipt.id as CVarArg, userId)
                    
                    let existingReceipts = try context.fetch(fetchRequest)
                    let receiptEntity: ReceiptEntity
                    
                    if let existing = existingReceipts.first {
                        print("💾 CoreDataStorageService: Updating existing receipt")
                        receiptEntity = existing
                    } else {
                        print("💾 CoreDataStorageService: Creating new receipt entity")
                        receiptEntity = ReceiptEntity(context: context)
                        receiptEntity.id = receipt.id
                        receiptEntity.userId = userId
                    }
                    
                    // Update receipt properties
                    receiptEntity.subtotal = NSDecimalNumber(decimal: receipt.subtotal)
                    receiptEntity.vatPercentage = NSDecimalNumber(decimal: receipt.vatPercentage)
                    receiptEntity.servicePercentage = NSDecimalNumber(decimal: receipt.servicePercentage)
                    receiptEntity.total = NSDecimalNumber(decimal: receipt.total)
                    receiptEntity.timestamp = receipt.timestamp
                    
                    print("💾 CoreDataStorageService: Receipt has \(receipt.items.count) items, \(receipt.people.count) people")
                    
                    // Remove existing items
                    if let existingItems = receiptEntity.items as? Set<ReceiptItemEntity> {
                        existingItems.forEach { context.delete($0) }
                    }
                    
                    // Add new items
                    for item in receipt.items {
                        let itemEntity = ReceiptItemEntity(context: context)
                        itemEntity.id = item.id
                        itemEntity.name = item.name
                        itemEntity.unitPrice = NSDecimalNumber(decimal: item.unitPrice)
                        itemEntity.quantity = Int16(item.quantity)
                        
                        // Store unitAssignments - Core Data will use the transformer automatically
                        itemEntity.unitAssignments = item.unitAssignments
                        
                        receiptEntity.addToItems(itemEntity)
                    }
                    
                // Remove existing people relationships
                    if let existingPeople = receiptEntity.people as? Set<PersonEntity> {
                        for personEntity in existingPeople {
                            receiptEntity.removeFromPeople(personEntity)
                        }
                    }
                    
                    // Add people
                    for person in receipt.people {
                        let personEntity = try self.findOrCreatePerson(id: person.id, name: person.name, in: context)
                        receiptEntity.addToPeople(personEntity)
                    }
                    
                // Save directly to view context
                print("💾 CoreDataStorageService: Saving to view context...")
                    try context.save()
                
                let totalDuration = Date().timeIntervalSince(saveStartTime)
                print("✅ CoreDataStorageService: Receipt saved successfully (took \(String(format: "%.3f", totalDuration))s)")
                } catch {
                print("❌ CoreDataStorageService: Error saving receipt: \(error.localizedDescription)")
                    print("   Full error: \(error)")
                throw error
                        }
        }
    }
    
    
    func loadAllReceipts(userId: String) async throws -> [Receipt] {
        let loadStartTime = Date()
        print("📖 CoreDataStorageService: Loading receipts for user \(userId)")
        
        // Access view context - container will initialize if needed and fail fast if model not found
        let context = coreDataStack.viewContext
        
        // Use view context directly - it's already on main thread
        return try await MainActor.run {
                do {
                    let fetchRequest: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
                    
                let fetchStartTime = Date()
                    let receiptEntities = try context.fetch(fetchRequest)
                let fetchDuration = Date().timeIntervalSince(fetchStartTime)
                print("📖 CoreDataStorageService: Found \(receiptEntities.count) receipt entities in database for user \(userId) (fetch took \(String(format: "%.3f", fetchDuration))s)")
                
                let convertStartTime = Date()
                    let convertToReceipt = self.convertToReceipt
                    let receipts = receiptEntities.map { convertToReceipt($0) }
                let convertDuration = Date().timeIntervalSince(convertStartTime)
                print("📖 CoreDataStorageService: Converted to \(receipts.count) receipts (convert took \(String(format: "%.3f", convertDuration))s)")
                
                let totalDuration = Date().timeIntervalSince(loadStartTime)
                print("📖 CoreDataStorageService: Complete load operation took \(String(format: "%.3f", totalDuration))s)")
                
                return receipts
                } catch {
                print("❌ CoreDataStorageService: Error loading receipts: \(error.localizedDescription)")
                print("   Full error: \(error)")
                throw error
            }
        }
    }
    
    func deleteReceipt(_ receiptId: UUID, userId: String) async throws {
        let context = coreDataStack.newBackgroundContext()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@ AND userId == %@", receiptId as CVarArg, userId)
                    
                    let receipts = try context.fetch(fetchRequest)
                    receipts.forEach { context.delete($0) }
                    
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Currency Preference
    
    func saveCurrency(_ currency: Currency) async throws {
        // Keep currency in UserDefaults for now (lightweight, doesn't need sync)
        if let encoded = try? JSONEncoder().encode(currency) {
            UserDefaults.standard.set(encoded, forKey: "userCurrency")
        }
    }
    
    func loadCurrency() async throws -> Currency {
        // Load from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "userCurrency"),
              let currency = try? JSONDecoder().decode(Currency.self, from: data) else {
            return .egp // Default
        }
        return currency
    }
    
    // MARK: - Helper Methods
    
    private func findOrCreatePerson(id: UUID, name: String, in context: NSManagedObjectContext) throws -> PersonEntity {
        let fetchRequest: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        if let existing = try context.fetch(fetchRequest).first {
            existing.name = name
            return existing
        } else {
            let personEntity = PersonEntity(context: context)
            personEntity.id = id
            personEntity.name = name
            return personEntity
        }
    }
    
    private func convertToReceipt(_ entity: ReceiptEntity) -> Receipt {
        let items = (entity.items as? Set<ReceiptItemEntity> ?? []).map { itemEntity -> ReceiptItem in
            // unitAssignments is automatically transformed by Core Data
            let unitAssignments: [[UUID]] = itemEntity.unitAssignments ?? []
            
            return ReceiptItem(
                id: itemEntity.id ?? UUID(),
                name: itemEntity.name ?? "",
                unitPrice: itemEntity.unitPrice?.decimalValue ?? 0,
                quantity: Int(itemEntity.quantity),
                unitAssignments: unitAssignments
            )
        }
        
        let people = (entity.people as? Set<PersonEntity> ?? []).map { personEntity -> Person in
            Person(
                id: personEntity.id ?? UUID(),
                name: personEntity.name ?? ""
            )
        }
        
        return Receipt(
            id: entity.id ?? UUID(),
            items: items,
            subtotal: entity.subtotal?.decimalValue ?? 0,
            vatPercentage: entity.vatPercentage?.decimalValue ?? 0,
            servicePercentage: entity.servicePercentage?.decimalValue ?? 0,
            total: entity.total?.decimalValue ?? 0,
            timestamp: entity.timestamp ?? Date(),
            people: people
        )
    }
}

