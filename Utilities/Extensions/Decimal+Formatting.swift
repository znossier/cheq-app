//
//  Decimal+Formatting.swift
//  Cheq
//
//  Decimal formatting for currency display
//

import Foundation

extension Decimal {
    func formatted(currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.currencySymbol = currency.symbol
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "\(currency.symbol)0.00"
    }
}

