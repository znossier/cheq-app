//
//  UnitAssignmentsTransformer.swift
//  Cheq
//
//  Transformer for unitAssignments array in Core Data
//

import Foundation

@objc(UnitAssignmentsTransformer)
class UnitAssignmentsTransformer: ValueTransformer {
    static let name = "UnitAssignmentsTransformer"
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let array = value as? [[UUID]] else { return nil }
        return try? JSONEncoder().encode(array.map { $0.map { $0.uuidString } })
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data,
              let stringArray = try? JSONDecoder().decode([[String]].self, from: data) else {
            return nil
        }
        return stringArray.map { $0.compactMap { UUID(uuidString: $0) } }
    }
}

extension ValueTransformer {
    static func registerUnitAssignmentsTransformer() {
        let transformerName = NSValueTransformerName(rawValue: UnitAssignmentsTransformer.name)
        ValueTransformer.setValueTransformer(UnitAssignmentsTransformer(), forName: transformerName)
    }
}

