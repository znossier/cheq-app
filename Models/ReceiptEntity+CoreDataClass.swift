//
//  ReceiptEntity+CoreDataClass.swift
//  Cheq
//
//  Core Data entity class for Receipt
//

import Foundation
import CoreData

@objc(ReceiptEntity)
public class ReceiptEntity: NSManagedObject {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReceiptEntity> {
        return NSFetchRequest<ReceiptEntity>(entityName: "ReceiptEntity")
    }
}

extension ReceiptEntity {
    @NSManaged public var id: UUID?
    @NSManaged public var servicePercentage: NSDecimalNumber?
    @NSManaged public var subtotal: NSDecimalNumber?
    @NSManaged public var timestamp: Date?
    @NSManaged public var total: NSDecimalNumber?
    @NSManaged public var userId: String?
    @NSManaged public var vatPercentage: NSDecimalNumber?
    @NSManaged public var items: NSSet?
    @NSManaged public var people: NSSet?
}

extension ReceiptEntity {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ReceiptItemEntity)
    
    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ReceiptItemEntity)
    
    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)
    
    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
    
    @objc(addPeopleObject:)
    @NSManaged public func addToPeople(_ value: PersonEntity)
    
    @objc(removePeopleObject:)
    @NSManaged public func removeFromPeople(_ value: PersonEntity)
    
    @objc(addPeople:)
    @NSManaged public func addToPeople(_ values: NSSet)
    
    @objc(removePeople:)
    @NSManaged public func removeFromPeople(_ values: NSSet)
}
