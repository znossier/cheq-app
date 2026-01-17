//
//  CoreDataStack.swift
//  Cheq
//
//  Core Data stack with optional CloudKit support
//

import Foundation
import CoreData

class CoreDataStack {
    static let shared = CoreDataStack()
    
    private let containerName = "Cheq"
    private lazy var persistentContainer: NSPersistentContainer = {
        // Validate model file exists in bundle before creating container
        validateModelFile()
        
        let container = NSPersistentContainer(name: containerName)
        
        // Configure store options for optimal performance and reliability
        if let storeDescription = container.persistentStoreDescriptions.first {
            // Enable automatic lightweight migration
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            
            // Set journaling mode to WAL (Write-Ahead Logging) for better performance
            storeDescription.setOption(["journal_mode": "WAL"] as NSObject, forKey: NSSQLitePragmasOption)
            
            print("✅ CoreDataStack: Store options configured (WAL journaling, auto-migration enabled)")
        }
        
        // Load stores synchronously - Core Data will fail fast if model not found
        container.loadPersistentStores { description, error in
            if let error = error {
                print("❌ CoreDataStack: Failed to load persistent store: \(error.localizedDescription)")
                print("   Store URL: \(description.url?.path ?? "unknown")")
                print("   Full error: \(error)")
                
                // Check if it's a model file error
                if error.localizedDescription.contains("Failed to load model") {
                    print("❌ CoreDataStack: Core Data model file not found in app bundle!")
                    print("   This usually means the .xcdatamodeld file is not included in the Resources build phase.")
                }
            } else {
                print("✅ CoreDataStack: Persistent store loaded successfully at \(description.url?.path ?? "unknown")")
            }
        }
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil // Disable undo for better performance
        print("✅ CoreDataStack: View context configured with auto-merge enabled")
        
        return container
    }()
    
    /// Validates that the Core Data model file exists in the app bundle
    private func validateModelFile() {
        // Check for compiled model (.momd) in bundle
        if Bundle.main.url(forResource: containerName, withExtension: "momd") != nil {
            print("✅ CoreDataStack: Model file found in bundle (.momd)")
            return
        }
        
        // Check for source model (.xcdatamodeld) in bundle (shouldn't be there, but check anyway)
        if Bundle.main.url(forResource: containerName, withExtension: "xcdatamodeld") != nil {
            print("⚠️ CoreDataStack: Source model file found in bundle (.xcdatamodeld) - this shouldn't happen")
                return
            }
            
        // Model file not found
        print("❌ CoreDataStack: Model file '\(containerName).momd' not found in app bundle!")
        print("   The Core Data model file must be included in the Resources build phase.")
        print("   Check that Cheq.xcdatamodeld is added to the target's Resources in Xcode.")
    }
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    func saveContext() throws {
        let context = viewContext
        if context.hasChanges {
            try context.save()
        }
    }
    
    func saveContext(_ context: NSManagedObjectContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    /// Returns the store file URL if available
    func getStoreURL() -> URL? {
        guard let storeDescription = persistentContainer.persistentStoreDescriptions.first else { return nil }
        return storeDescription.url
    }
    
    /// Diagnostic method to get store information
    func getStoreInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        info["hasContainer"] = true
        info["storeURL"] = getStoreURL()?.path ?? "unknown"
        info["storeDescriptions"] = persistentContainer.persistentStoreDescriptions.map { description in
            [
                "url": description.url?.path ?? "unknown",
                "type": description.type
            ]
        }
        return info
    }
    
    /// Diagnostic method to check store file size
    func getStoreFileSize() -> Int64? {
        guard let url = getStoreURL() else { return nil }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return attributes[.size] as? Int64
    }
    
    /// Diagnostic method to count receipts in store
    func countReceiptsInStore() -> Int {
        let context = viewContext
        let fetchRequest: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("⚠️ CoreDataStack: Error counting receipts: \(error.localizedDescription)")
            return -1
        }
    }
    
    /// Resets the database by deleting all store files and clearing state
    /// Use this if the database is corrupted or you want a fresh start
    func resetDatabase() throws {
        print("🔄 CoreDataStack: Resetting database...")
        
        // Close container
        let coordinator = persistentContainer.persistentStoreCoordinator
        for storeDescription in persistentContainer.persistentStoreDescriptions {
            if let storeURL = storeDescription.url,
               let store = coordinator.persistentStore(for: storeURL) {
                try coordinator.remove(store)
            }
        }
        
        // Delete store files
        guard let storeURL = getStoreURL() else {
            print("✅ CoreDataStack: Database reset complete (no store file found)")
            return
        }
        
        let fileManager = FileManager.default
        let storePath = storeURL.path
        
        // Delete main store file
        if fileManager.fileExists(atPath: storePath) {
            try fileManager.removeItem(atPath: storePath)
            print("🗑️ CoreDataStack: Deleted store file: \(storePath)")
        }
        
        // Delete WAL and SHM files
        let walPath = storePath + "-wal"
        let shmPath = storePath + "-shm"
        
        if fileManager.fileExists(atPath: walPath) {
            try? fileManager.removeItem(atPath: walPath)
            print("🗑️ CoreDataStack: Deleted WAL file: \(walPath)")
        }
        
        if fileManager.fileExists(atPath: shmPath) {
            try? fileManager.removeItem(atPath: shmPath)
            print("🗑️ CoreDataStack: Deleted SHM file: \(shmPath)")
        }
        
        print("✅ CoreDataStack: Database reset complete")
    }
    
    private init() {}
}
