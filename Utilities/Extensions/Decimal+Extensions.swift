//
//  Decimal+Extensions.swift
//  Cheq
//
//  Decimal formatting extensions
//

import Foundation

extension Decimal {
    func rounded(_ scale: Int, _ roundingMode: NSDecimalNumber.RoundingMode) -> Decimal {
        var result = Decimal()
        var localCopy = self
        NSDecimalRound(&result, &localCopy, scale, roundingMode)
        return result
    }
    
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

