//
//  Typography.swift
//  Cheq
//
//  Typography system for Cheq brand
//  LOCKED - DO NOT MODIFY without explicit approval
//

import SwiftUI

extension Font {
    // MARK: - Display / Totals (34pt, SF Pro Display, Bold)
    /// Used only for: Final totals, per-person amounts, key numeric results
    /// Line height: 40pt, Tracking: -0.5%
    /// Rules: Numbers only or very short labels, can use mint color only when confirmed, never for paragraphs
    static var displayTotal: Font {
        .system(.largeTitle, design: .default)
            .weight(.bold)
    }
    
    // MARK: - Title / Section Headers (22pt, SF Pro Display, Bold)
    /// Used for: Screen titles, section headers, onboarding headlines
    /// Line height: 28pt, Tracking: -0.3%
    static var titleHeader: Font {
        .system(.title2, design: .default)
            .weight(.bold)
    }
    
    // MARK: - Body / Primary Text (16pt, SF Pro Text, Medium)
    /// Used for: Descriptions, instructions, explanatory copy
    /// Line height: 22pt, Tracking: 0%
    /// Rules: Never mint, neutral color only, short factual sentences
    static var bodyText: Font {
        .system(.body, design: .default)
            .weight(.medium)
    }
    
    // MARK: - Secondary / Metadata (14pt, SF Pro Text, Medium)
    /// Used for: Labels, helper text, context under amounts
    /// Line height: 20pt, Tracking: 0%
    static var secondaryText: Font {
        .system(.subheadline, design: .default)
            .weight(.medium)
    }
    
    // MARK: - UI Labels / Buttons (15pt, SF Pro Text, Semibold)
    /// Used for: Buttons, segmented controls, inline actions
    /// Line height: 20pt, Tracking: 0%
    /// Rules: No all caps, no bold CTAs, buttons should feel calm not promotional
    static var uiLabel: Font {
        .system(.callout, design: .default)
            .weight(.semibold)
    }
    
    // MARK: - Caption / Tertiary (12pt, SF Pro Text, Medium)
    /// Used for: Footnotes, disclaimers, disabled states
    /// Line height: 16pt, Tracking: 0.2%
    static var captionText: Font {
        .system(.caption, design: .default)
            .weight(.medium)
    }
    
    // MARK: - Numeric Hierarchy
    /// Semibold weight numbers for better visual hierarchy
    static func numeric(size: CGFloat) -> Font {
        .system(size: size, design: .default)
            .weight(.semibold)
    }
    
    /// Large numbers use SF Pro Display with bold weight
    static func numericDisplay(size: CGFloat) -> Font {
        .system(size: size, design: .default)
            .weight(.bold)
    }
}

extension View {
    /// Apply display total styling
    func displayTotalStyle() -> some View {
        self
            .font(.displayTotal)
            .foregroundColor(.appTextPrimary)
    }
    
    /// Apply title header styling
    func titleHeaderStyle() -> some View {
        self
            .font(.titleHeader)
            .foregroundColor(.appTextPrimary)
    }
    
    /// Apply body text styling
    func bodyTextStyle() -> some View {
        self
            .font(.bodyText)
            .foregroundColor(.appTextPrimary)
    }
    
    /// Apply secondary text styling
    func secondaryTextStyle() -> some View {
        self
            .font(.secondaryText)
            .foregroundColor(.appTextSecondary)
    }
    
    /// Apply UI label styling
    func uiLabelStyle() -> some View {
        self
            .font(.uiLabel)
            .foregroundColor(.appTextPrimary)
    }
    
    /// Apply caption styling
    func captionStyle() -> some View {
        self
            .font(.captionText)
            .foregroundColor(.appTextSecondary)
    }
}

