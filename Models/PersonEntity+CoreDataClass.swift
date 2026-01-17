//
//  PersonEntity+CoreDataClass.swift
//  Cheq
//
//  Core Data entity class for Person
//

import Foundation
import CoreData

@objc(PersonEntity)
public class PersonEntity: NSManagedObject {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PersonEntity> {
        return NSFetchRequest<PersonEntity>(entityName: "PersonEntity")
    }
}

extension PersonEntity {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var receipts: NSSet?
}

extension PersonEntity {
    @objc(addReceiptsObject:)
    @NSManaged public func addToReceipts(_ value: ReceiptEntity)
    
    @objc(removeReceiptsObject:)
    @NSManaged public func removeFromReceipts(_ value: ReceiptEntity)
    
    @objc(addReceipts:)
    @NSManaged public func addToReceipts(_ values: NSSet)
    
    @objc(removeReceipts:)
    @NSManaged public func removeFromReceipts(_ values: NSSet)
}
