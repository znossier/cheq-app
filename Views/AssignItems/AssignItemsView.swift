//
//  AssignItemsView.swift
//  Cheq
//
//  Assign items to people screen
//

import SwiftUI

struct AssignItemsView: View {
    @State var receipt: Receipt
    @StateObject private var viewModel: AssignItemsViewModel
    @State private var navigateToSummary = false
    @State private var currency = StorageService.shared.loadCurrency()
    
    init(receipt: Receipt) {
        self._receipt = State(initialValue: receipt)
        _viewModel = StateObject(wrappedValue: AssignItemsViewModel(receipt: receipt))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Items list
                    ForEach(viewModel.receipt.items) { item in
                        ItemAssignmentCard(
                            item: item,
                            people: viewModel.receipt.people,
                            viewModel: viewModel
                        )
                    }
                    
                    // Per-person totals
                    if !viewModel.receipt.people.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Totals")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.receipt.people) { person in
                                HStack {
                                    Text(person.name)
                                    Spacer()
                                    Text((viewModel.personTotals[person.id] ?? 0).formatted(currency: currency))
                                        .font(.headline)
                                        .contentTransition(.numericText())
                                }
                                .padding()
                                .background(Color.appSurface)
                                .cornerRadius(8)
                                .padding(.horizontal)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.personTotals[person.id])
                            }
                        }
                        .padding(.top)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Assign Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Continue") {
                        navigateToSummary = true
                    }
                    .disabled(!viewModel.canProceed)
                }
            }
            .navigationDestination(isPresented: $navigateToSummary) {
                SummaryView(receipt: viewModel.receipt)
            }
        }
    }
}

struct ItemAssignmentCard: View {
    let item: ReceiptItem
    let people: [Person]
    @ObservedObject var viewModel: AssignItemsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Item header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.unitPrice.formatted(currency: StorageService.shared.loadCurrency()))
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                }
                Spacer()
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
            
            // Unit assignments
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<item.quantity, id: \.self) { unitIndex in
                    UnitAssignmentRow(
                        itemId: item.id,
                        unitIndex: unitIndex,
                        unitNumber: unitIndex + 1,
                        people: people,
                        viewModel: viewModel
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: Color.charcoalBlack.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: viewModel.receipt.items)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.quantity) units")
    }
}

struct UnitAssignmentRow: View {
    let itemId: UUID
    let unitIndex: Int
    let unitNumber: Int
    let people: [Person]
    @ObservedObject var viewModel: AssignItemsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unit \(unitNumber)")
                .font(.caption)
                .foregroundColor(.appTextSecondary)
            
            // Person toggles
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(people) { person in
                    Button(action: {
                        viewModel.togglePersonAssignment(
                            for: itemId,
                            unitIndex: unitIndex,
                            personId: person.id
                        )
                    }) {
                        HStack {
                            Image(systemName: viewModel.isPersonAssigned(to: itemId, unitIndex: unitIndex, personId: person.id) ? "checkmark.circle.fill" : "circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(viewModel.isPersonAssigned(to: itemId, unitIndex: unitIndex, personId: person.id) ? .appPrimary : .gray)
                            Text(person.name)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: Constants.minimumTapTargetSize)
                        .background(
                            viewModel.isPersonAssigned(to: itemId, unitIndex: unitIndex, personId: person.id) ?
                            Color.appPrimary.opacity(0.1) : Color.appSurface
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isPersonAssigned(to: itemId, unitIndex: unitIndex, personId: person.id))
                    .accessibilityLabel("\(person.name), \(viewModel.isPersonAssigned(to: itemId, unitIndex: unitIndex, personId: person.id) ? "assigned" : "not assigned")")
                    .accessibilityHint("Double tap to toggle assignment")
                }
            }
        }
    }
}

