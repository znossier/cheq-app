//
//  AppearanceMode.swift
//  Cheq
//
//  Appearance mode preference enum
//

import SwiftUI

enum AppearanceMode: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil // nil means follow system
        }
    }
    
    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "System"
        }
    }
}

