//
//  AppColors.swift
//  Cheq
//
//  Design system color tokens
//  CRITICAL: Charcoal black and white contrast always, with subtle mint only
//

import SwiftUI

extension Color {
    // MARK: - Primary Contrast (Foundation - 95% of UI)
    /// Charcoal black - primary background in dark mode
    static let charcoalBlack = Color(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0)
    
    /// Pure white - primary background in light mode
    static let pureWhite = Color(red: 1.0, green: 1.0, blue: 1.0)
    
    // MARK: - Mint (Semantic Only - <5% of UI)
    /// Mint primary: #6FFF8B - only for verified/correct/final/completed states
    static let mintPrimary = Color(red: 0x6F / 255.0, green: 0xFF / 255.0, blue: 0x8B / 255.0)
    
    // MARK: - Dark Mode Colors (Primary Experience)
    /// Background: #0E1116 (charcoal black - foundation)
    static let darkBackground = Color(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0)
    
    /// Surface / Cards: #151A21
    static let darkSurface = Color(red: 0x15 / 255.0, green: 0x1A / 255.0, blue: 0x21 / 255.0)
    
    /// Elevated Surface: #1B222C
    static let darkElevatedSurface = Color(red: 0x1B / 255.0, green: 0x22 / 255.0, blue: 0x2C / 255.0)
    
    /// Divider: #232A36
    static let darkDivider = Color(red: 0x23 / 255.0, green: 0x2A / 255.0, blue: 0x36 / 255.0)
    
    /// Text Primary: #F4F6F8 (near white - high contrast)
    static let darkTextPrimary = Color(red: 0xF4 / 255.0, green: 0xF6 / 255.0, blue: 0xF8 / 255.0)
    
    /// Text Secondary: #A3ACB9 (muted white)
    static let darkTextSecondary = Color(red: 0xA3 / 255.0, green: 0xAC / 255.0, blue: 0xB9 / 255.0)
    
    /// Text Disabled: #6E7685
    static let darkTextDisabled = Color(red: 0x6E / 255.0, green: 0x76 / 255.0, blue: 0x85 / 255.0)
    
    /// Mint Soft: #4AD977 (subtle mint for icons/selections - use sparingly)
    static let darkMintSoft = Color(red: 0x4A / 255.0, green: 0xD9 / 255.0, blue: 0x77 / 255.0)
    
    /// Mint Subtle: #1E3A2A (very low opacity background tint - minimal use)
    static let darkMintSubtle = Color(red: 0x1E / 255.0, green: 0x3A / 255.0, blue: 0x2A / 255.0)
    
    // MARK: - Light Mode Colors
    /// Background: #FFFFFF (pure white - foundation)
    static let lightBackground = Color(red: 1.0, green: 1.0, blue: 1.0)
    
    /// Surface / Cards: #F5F7FA
    static let lightSurface = Color(red: 0xF5 / 255.0, green: 0xF7 / 255.0, blue: 0xFA / 255.0)
    
    /// Elevated Surface: #ECEFF4
    static let lightElevatedSurface = Color(red: 0xEC / 255.0, green: 0xEF / 255.0, blue: 0xF4 / 255.0)
    
    /// Divider: #D6DBE3
    static let lightDivider = Color(red: 0xD6 / 255.0, green: 0xDB / 255.0, blue: 0xE3 / 255.0)
    
    /// Text Primary: #0E1116 (charcoal black - high contrast)
    static let lightTextPrimary = Color(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0)
    
    /// Text Secondary: #475569 (muted charcoal)
    static let lightTextSecondary = Color(red: 0x47 / 255.0, green: 0x55 / 255.0, blue: 0x69 / 255.0)
    
    /// Text Disabled: #9AA3AF
    static let lightTextDisabled = Color(red: 0x9A / 255.0, green: 0xA3 / 255.0, blue: 0xAF / 255.0)
    
    /// Mint: #1FAE5A (darker mint for light mode - use sparingly)
    static let lightMint = Color(red: 0x1F / 255.0, green: 0xAE / 255.0, blue: 0x5A / 255.0)
    
    /// Mint Soft: #178F4A (subtle mint - minimal use)
    static let lightMintSoft = Color(red: 0x17 / 255.0, green: 0x8F / 255.0, blue: 0x4A / 255.0)
    
    /// Mint Subtle: #E9FFF0 (very subtle background - minimal use)
    static let lightMintSubtle = Color(red: 0xE9 / 255.0, green: 1.0, blue: 0xF0 / 255.0)
    
    // MARK: - Adaptive Colors (Use These in Views)
    /// Primary background - adapts to dark/light mode
    static var appBackground: Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)
            } else {
                return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            }
        })
        #else
        return Color(nsColor: NSColor { appearance in
            if appearance.name == .darkAqua {
                return NSColor(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)
            } else {
                return NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            }
        })
        #endif
    }
    
    /// Surface / Card background - adapts to dark/light mode
    static var appSurface: Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0x15 / 255.0, green: 0x1A / 255.0, blue: 0x21 / 255.0, alpha: 1.0)
            } else {
                return UIColor(red: 0xF5 / 255.0, green: 0xF7 / 255.0, blue: 0xFA / 255.0, alpha: 1.0)
            }
        })
        #else
        return Color(nsColor: NSColor { appearance in
            if appearance.name == .darkAqua {
                return NSColor(red: 0x15 / 255.0, green: 0x1A / 255.0, blue: 0x21 / 255.0, alpha: 1.0)
            } else {
                return NSColor(red: 0xF5 / 255.0, green: 0xF7 / 255.0, blue: 0xFA / 255.0, alpha: 1.0)
            }
        })
        #endif
    }
    
    /// Elevated surface - adapts to dark/light mode
    static var appElevatedSurface: Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0x1B / 255.0, green: 0x22 / 255.0, blue: 0x2C / 255.0, alpha: 1.0)
            } else {
                return UIColor(red: 0xEC / 255.0, green: 0xEF / 255.0, blue: 0xF4 / 255.0, alpha: 1.0)
            }
        })
        #else
        return Color(nsColor: NSColor { appearance in
            if appearance.name == .darkAqua {
                return NSColor(red: 0x1B / 255.0, green: 0x22 / 255.0, blue: 0x2C / 255.0, alpha: 1.0)
            } else {
                return NSColor(red: 0xEC / 255.0, green: 0xEF / 255.0, blue: 0xF4 / 255.0, alpha: 1.0)
            }
        })
        #endif
    }
    
    /// Divider color - adapts to dark/light mode
    static var appDivider: Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0x23 / 255.0, green: 0x2A / 255.0, blue: 0x36 / 255.0, alpha: 1.0)
            } else {
                return UIColor(red: 0xD6 / 255.0, green: 0xDB / 255.0, blue: 0xE3 / 255.0, alpha: 1.0)
            }
        })
        #else
        return Color(nsColor: NSColor { appearance in
            if appearance.name == .darkAqua {
                return NSColor(red: 0x23 / 255.0, green: 0x2A / 255.0, blue: 0x36 / 255.0, alpha: 1.0)
            } else {
                return NSColor(red: 0xD6 / 255.0, green: 0xDB / 255.0, blue: 0xE3 / 255.0, alpha: 1.0)
            }
        })
        #endif
    }
    
    /// Primary text color - adapts to dark/light mode
    static var appTextPrimary: Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0xF4 / 255.0, green: 0xF6 / 255.0, blue: 0xF8 / 255.0, alpha: 1.0)
            } else {
                return UIColor(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)
            }
        })
        #else
        return Color(nsColor: NSColor { appearance in
            if appearance.name == .darkAqua {
                return NSColor(red: 0xF4 / 255.0, green: 0xF6 / 255.0, blue: 0xF8 / 255.0, alpha: 1.0)
            } else {
                return NSColor(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)
            }
        })
        #endif
    }
    
    /// Secondary text color - adapts to dark/light mode
    static var appTextSecondary: Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0xA3 / 255.0, green: 0xAC / 255.0, blue: 0xB9 / 255.0, alpha: 1.0)
            } else {
                return UIColor(red: 0x47 / 255.0, green: 0x55 / 255.0, blue: 0x69 / 255.0, alpha: 1.0)
            }
        })
        #else
        return Color(nsColor: NSColor { appearance in
            if appearance.name == .darkAqua {
                return NSColor(red: 0xA3 / 255.0, green: 0xAC / 255.0, blue: 0xB9 / 255.0, alpha: 1.0)
            } else {
                return NSColor(red: 0x47 / 255.0, green: 0x55 / 255.0, blue: 0x69 / 255.0, alpha: 1.0)
            }
        })
        #endif
    }
    
    /// Disabled text color - adapts to dark/light mode
    static var appTextDisabled: Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0x6E / 255.0, green: 0x76 / 255.0, blue: 0x85 / 255.0, alpha: 1.0)
            } else {
                return UIColor(red: 0x9A / 255.0, green: 0xA3 / 255.0, blue: 0xAF / 255.0, alpha: 1.0)
            }
        })
        #else
        return Color(nsColor: NSColor { appearance in
            if appearance.name == .darkAqua {
                return NSColor(red: 0x6E / 255.0, green: 0x76 / 255.0, blue: 0x85 / 255.0, alpha: 1.0)
            } else {
                return NSColor(red: 0x9A / 255.0, green: 0xA3 / 255.0, blue: 0xAF / 255.0, alpha: 1.0)
            }
        })
        #endif
    }
    
    /// Mint color - adapts to dark/light mode (ONLY for verified/correct states)
    static var appMint: Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0x6F / 255.0, green: 0xFF / 255.0, blue: 0x8B / 255.0, alpha: 1.0)
            } else {
                return UIColor(red: 0x1F / 255.0, green: 0xAE / 255.0, blue: 0x5A / 255.0, alpha: 1.0)
            }
        })
        #else
        return Color(nsColor: NSColor { appearance in
            if appearance.name == .darkAqua {
                return NSColor(red: 0x6F / 255.0, green: 0xFF / 255.0, blue: 0x8B / 255.0, alpha: 1.0)
            } else {
                return NSColor(red: 0x1F / 255.0, green: 0xAE / 255.0, blue: 0x5A / 255.0, alpha: 1.0)
            }
        })
        #endif
    }
    
    /// Text color for buttons on mint background - black in light mode, white in dark mode
    static var appButtonTextOnMint: Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                // Dark mode: white
                return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            } else {
                // Light mode: black (charcoal)
                return UIColor(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)
            }
        })
        #else
        return Color(nsColor: NSColor { appearance in
            if appearance.name == .darkAqua {
                return NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            } else {
                return NSColor(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)
            }
        })
        #endif
    }
    
    // MARK: - Legacy Support (Deprecated - Use appMint instead)
    /// @deprecated Use appMint for verified states only. Do not use for primary actions.
    static var appPrimary: Color {
        appMint
    }
}

#if os(iOS)
import UIKit

extension UIColor {
    convenience init(_ color: Color) {
        // Convert SwiftUI Color to UIColor properly to avoid infinite recursion
        let uiColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)
            default:
                return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            }
        }
        self.init(cgColor: uiColor.cgColor)
    }
    
    convenience init(swiftUIColor: Color) {
        // Helper to convert specific Color instances
        if let cgColor = swiftUIColor.cgColor {
            self.init(cgColor: cgColor)
        } else {
            self.init(white: 0.5, alpha: 1.0) // Fallback
        }
    }
}
#endif

#if os(macOS)
import AppKit

extension NSColor {
    convenience init(_ color: Color) {
        // Convert SwiftUI Color to NSColor properly to avoid infinite recursion
        if let cgColor = color.cgColor {
            self.init(cgColor: cgColor)
        } else {
            self.init(white: 0.5, alpha: 1.0) // Fallback
        }
    }
}
#endif
