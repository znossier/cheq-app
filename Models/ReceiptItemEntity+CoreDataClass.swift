//
//  ReceiptItemEntity+CoreDataClass.swift
//  Cheq
//
//  Core Data entity class for ReceiptItem
//

import Foundation
import CoreData

@objc(ReceiptItemEntity)
public class ReceiptItemEntity: NSManagedObject {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReceiptItemEntity> {
        return NSFetchRequest<ReceiptItemEntity>(entityName: "ReceiptItemEntity")
    }
}

extension ReceiptItemEntity {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var quantity: Int16
    @NSManaged public var unitAssignments: [[UUID]]?
    @NSManaged public var unitPrice: NSDecimalNumber?
    @NSManaged public var receipt: ReceiptEntity?
}
