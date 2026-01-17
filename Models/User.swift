//
//  User.swift
//  Cheq
//
//  User profile model
//

import Foundation

struct User: Codable {
    let id: String
    let name: String
    let email: String
    var currency: Currency
    
    var firstName: String {
        name.components(separatedBy: " ").first ?? name
    }
}

enum Currency: String, Codable, CaseIterable {
    case egp = "EGP"
    case aed = "AED"
    case sar = "SAR"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case cad = "CAD"
    case aud = "AUD"
    case inr = "INR"
    case kwd = "KWD"
    case qar = "QAR"
    case omr = "OMR"
    case bhd = "BHD"
    
    var symbol: String {
        switch self {
        case .egp: return "E£"
        case .aed: return "د.إ"
        case .sar: return "﷼"
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "¥"
        case .cad: return "C$"
        case .aud: return "A$"
        case .inr: return "₹"
        case .kwd: return "د.ك"
        case .qar: return "ر.ق"
        case .omr: return "ر.ع"
        case .bhd: return ".د.ب"
        }
    }
}

