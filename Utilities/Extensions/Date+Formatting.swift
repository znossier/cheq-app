//
//  Date+Formatting.swift
//  Cheq
//
//  Date formatting for smart relative display
//

import Foundation

extension Date {
    /// Formats a date with smart relative display:
    /// - Recent (within 24 hours): "2h ago", "30m ago"
    /// - Recent (within 7 days): "3d ago"
    /// - Older: Actual date format (e.g., "Jan 15" or "Jan 15, 2024" if older than current year)
    func formattedRelative() -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)
        
        // Within the last hour: show minutes
        if let minutes = components.minute, minutes < 60 {
            if minutes < 1 {
                return "Just now"
            }
            return "\(minutes)m ago"
        }
        
        // Within the last 24 hours: show hours
        if let hours = components.hour, hours < 24 {
            return "\(hours)h ago"
        }
        
        // Within the last 7 days: show days
        if let days = components.day, days < 7 {
            return "\(days)d ago"
        }
        
        // Older than 7 days: show actual date
        let formatter = DateFormatter()
        let currentYear = calendar.component(.year, from: now)
        let dateYear = calendar.component(.year, from: self)
        
        if dateYear == currentYear {
            // Same year: show month and day (e.g., "Jan 15")
            formatter.dateFormat = "MMM d"
        } else {
            // Different year: show month, day, and year (e.g., "Jan 15, 2024")
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: self)
    }
}

