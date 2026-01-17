//
//  SummaryView.swift
//  Cheq
//
//  Summary screen with per-person breakdown
//

import SwiftUI

struct SummaryView: View {
    @State var receipt: Receipt
    @StateObject private var viewModel: SummaryViewModel
    @State private var showShareSheet = false
    @State private var currency = StorageService.shared.loadCurrency()
    @Environment(\.dismiss) var dismiss
    
    init(receipt: Receipt) {
        self._receipt = State(initialValue: receipt)
        _viewModel = StateObject(wrappedValue: SummaryViewModel(receipt: receipt))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary header
                    Text("Bill Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                        // Save status indicator
                        if viewModel.isSaving {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Saving receipt...")
                                    .font(.subheadline)
                                    .foregroundColor(.appTextSecondary)
                            }
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(8)
                            .padding(.horizontal)
                        } else if let error = viewModel.saveError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        } else if viewModel.saveCompleted {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Receipt saved successfully")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                        
                    // Per-person breakdown
                    ForEach(viewModel.splits, id: \.person.id) { split in
                        PersonSummaryCard(split: split, currency: currency)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    
                    // Total verification
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(receipt.total.formatted(currency: currency))
                            .font(.headline)
                    }
                    .padding()
                    .background(Color.appSurface)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [viewModel.generateShareText(currency: currency)])
            }
            .interactiveDismissDisabled(viewModel.isSaving)
        }
    }
}

struct PersonSummaryCard: View {
    let split: PersonSplit
    let currency: Currency
    
    // Group items by name and calculate totals
    private var groupedItems: [(name: String, quantity: Int, unitPrice: Decimal, total: Decimal)] {
        var itemGroups: [String: (quantity: Int, unitPrice: Decimal, total: Decimal)] = [:]
        
        for item in split.items {
            if let existing = itemGroups[item.name] {
                itemGroups[item.name] = (
                    quantity: existing.quantity + 1,
                    unitPrice: item.unitPrice,
                    total: existing.total + item.unitPrice
                )
            } else {
                itemGroups[item.name] = (
                    quantity: 1,
                    unitPrice: item.unitPrice,
                    total: item.unitPrice
                )
            }
        }
        
        return itemGroups.map { (name: $0.key, quantity: $0.value.quantity, unitPrice: $0.value.unitPrice, total: $0.value.total) }
            .sorted { $0.name < $1.name }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(split.person.name)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            VStack(alignment: .leading, spacing: 8) {
                // Item details
                if !groupedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(groupedItems, id: \.name) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if item.quantity > 1 {
                                        Text("\(item.quantity)× \(item.unitPrice.formatted(currency: currency))")
                                            .font(.caption)
                                            .foregroundColor(.appTextSecondary)
                                    } else {
                                        Text(item.unitPrice.formatted(currency: currency))
                                            .font(.caption)
                                            .foregroundColor(.appTextSecondary)
                                    }
                                }
                                Spacer()
                                Text(item.total.formatted(currency: currency))
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
                
                // Items subtotal
                HStack {
                    Text("Items Subtotal")
                    Spacer()
                    Text(split.itemTotal.formatted(currency: currency))
                }
                
                if split.vatShare > 0 {
                    HStack {
                        Text("VAT")
                        Spacer()
                        Text(split.vatShare.formatted(currency: currency))
                    }
                }
                
                if split.serviceShare > 0 {
                    HStack {
                        Text("Service")
                        Spacer()
                        Text(split.serviceShare.formatted(currency: currency))
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(split.finalAmount.formatted(currency: currency))
                        .font(.headline)
                        .contentTransition(.numericText())
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: Color.charcoalBlack.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(split.person.name) owes \(split.finalAmount.formatted(currency: currency))")
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

