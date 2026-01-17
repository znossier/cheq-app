//
//  AppIcon.swift
//  Cheq
//
//  SF Symbols icon system for Cheq brand
//  Rules: Regular or Medium weight only, Monochrome only, No rounded variants
//

import SwiftUI

/// App icon system using SF Symbols
/// Icons should feel: Neutral, infrastructural, low personality
/// Icons are supporting elements, never decorative
enum AppIcon {
    case camera
    case cameraCircle
    case person
    case person2
    case checkmark
    case checkmarkCircle
    case circle
    case receipt
    case receiptSearch
    case settings
    case share
    case trash
    case plus
    case plusCircle
    case minus
    case minusCircle
    case pencil
    case globe
    case house
    case gear
    case ellipsis
    case ellipsisCircle
    case docViewfinder
    case squareSplit
    case photoLibrary
    case listBullet
    case sum
    case percent
    case star
    case xmark
    case xmarkCircle
    
    /// SF Symbol name for this icon (Regular or Medium weight, monochrome only)
    var sfSymbolName: String {
        switch self {
        case .camera: return "camera.fill"
        case .cameraCircle: return "camera.circle.fill"
        case .person: return "person.fill"
        case .person2: return "person.2.fill"
        case .checkmark: return "checkmark"
        case .checkmarkCircle: return "checkmark.circle.fill"
        case .circle: return "circle.fill"
        case .receipt: return "doc.text.fill"
        case .receiptSearch: return "doc.text.magnifyingglass"
        case .settings: return "gearshape.fill"
        case .share: return "square.and.arrow.up"
        case .trash: return "trash.fill"
        case .plus: return "plus"
        case .plusCircle: return "plus.circle.fill"
        case .minus: return "minus"
        case .minusCircle: return "minus.circle.fill"
        case .pencil: return "pencil"
        case .globe: return "globe"
        case .house: return "house.fill"
        case .gear: return "gearshape.fill"
        case .ellipsis: return "ellipsis"
        case .ellipsisCircle: return "ellipsis.circle.fill"
        case .docViewfinder: return "doc.text.viewfinder"
        case .squareSplit: return "square.split.2x2"
        case .photoLibrary: return "photo.on.rectangle"
        case .listBullet: return "list.bullet"
        case .sum: return "sum"
        case .percent: return "percent"
        case .star: return "star.fill"
        case .xmark: return "xmark"
        case .xmarkCircle: return "xmark.circle.fill"
        }
    }
    
    /// Create a SwiftUI Image from this icon
    /// - Parameter size: Optional size for the icon
    /// - Returns: A SwiftUI Image view with the SF Symbol
    func image(size: CGFloat? = nil) -> some View {
        let image = Image(systemName: sfSymbolName)
            .renderingMode(.template)
            .font(.system(size: size ?? 20, weight: .medium))
        
        if let size = size {
            return AnyView(
                image
                    .frame(width: size, height: size)
            )
        }
        
        return AnyView(image)
    }
    
    /// Create a direct Image (for tab bar use)
    func directImage() -> Image {
        Image(systemName: sfSymbolName)
            .renderingMode(.template)
    }
    
    /// Create an Image with medium weight (for emphasis)
    func imageMedium(size: CGFloat? = nil) -> some View {
        let image = Image(systemName: sfSymbolName)
            .renderingMode(.template)
            .font(.system(size: size ?? 20, weight: .medium))
        
        if let size = size {
            return AnyView(
                image
                    .frame(width: size, height: size)
            )
        }
        
        return AnyView(image)
    }
}

extension Image {
    /// Create an SF Symbol icon by name
    /// - Parameters:
    ///   - name: The SF Symbol name
    ///   - size: Optional size for the icon
    ///   - weight: Font weight (default: .regular)
    /// - Returns: A SwiftUI Image view with the SF Symbol
    static func sfSymbol(_ name: String, size: CGFloat? = nil, weight: Font.Weight = .regular) -> some View {
        let image = Image(systemName: name)
            .renderingMode(.template)
            .font(.system(size: size ?? 20, weight: weight))
        
        if let size = size {
            return AnyView(
                image
                    .frame(width: size, height: size)
            )
        }
        
        return AnyView(image)
    }
}

