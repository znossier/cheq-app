//
//  ReceiptRowView.swift
//  Cheq
//
//  Receipt row view component for displaying receipt summaries
//

import SwiftUI

struct ReceiptRowView: View {
    let receipt: Receipt
    @State private var currency = StorageService.shared.loadCurrency()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.items.count == 1 ? "1 item" : "\(receipt.items.count) items")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
                
                Text(receipt.total.formatted(currency: currency))
                    .font(.headline)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // People count badge
                if !receipt.people.isEmpty {
                    HStack(spacing: 4) {
                        (receipt.people.count > 1 ? AppIcon.person2 : AppIcon.person).image(size: 12)
                        Text("\(receipt.people.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.appTextSecondary)
                }
                
                // Timestamp
                Text(receipt.timestamp.formattedRelative())
                    .font(.caption)
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }
}

