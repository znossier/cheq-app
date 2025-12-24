//
//  ConfirmReceiptView.swift
//  FairShare
//
//  Confirm and edit receipt screen
//

import SwiftUI

struct ConfirmReceiptView: View {
    @StateObject private var viewModel: ConfirmReceiptViewModel
    @State private var navigateToAddPeople = false
    @State private var editingItemIndex: Int?
    @State private var editingItemName = ""
    @State private var editingItemPrice = ""
    @State private var editingItemQuantity = ""
    @State private var currency = StorageService.shared.loadCurrency()
    @State private var showDebugView = false
    let isPreviewMode: Bool
    let onRetry: (() -> Void)?
    
    init(ocrResult: OCRResult, isPreviewMode: Bool = false, onRetry: (() -> Void)? = nil) {
        self.isPreviewMode = isPreviewMode
        self.onRetry = onRetry
        _viewModel = StateObject(wrappedValue: ConfirmReceiptViewModel(ocrResult: ocrResult, isPreview: isPreviewMode))
    }
    
    var body: some View {
        NavigationStack {
            if viewModel.isPreviewMode, let image = viewModel.previewImage {
                ReceiptPreviewView(
                    image: image,
                    boundingBoxes: viewModel.boundingBoxes ?? [],
                    ocrResult: viewModel.ocrResult,
                    onConfirm: {
                        viewModel.confirmPreview()
                    },
                    onRetry: {
                        onRetry?()
                    }
                )
                .navigationTitle("Preview Receipt")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Retry Scan") {
                            onRetry?()
                        }
                    }
                }
            } else {
                Form {
                // Items section
                Section("Items") {
                    ForEach(Array(viewModel.receipt.items.enumerated()), id: \.element.id) { index, item in
                        ItemEditRow(
                            item: item,
                            isEditing: editingItemIndex == index,
                            onEdit: {
                                editingItemIndex = index
                                editingItemName = item.name
                                editingItemPrice = String(item.unitPrice.doubleValue)
                                editingItemQuantity = String(item.quantity)
                            },
                            onSave: {
                                if let price = Decimal(string: editingItemPrice),
                                   let quantity = Int(editingItemQuantity) {
                                    viewModel.updateItem(
                                        at: index,
                                        name: editingItemName,
                                        unitPrice: price,
                                        quantity: quantity
                                    )
                                }
                                editingItemIndex = nil
                            },
                            onCancel: {
                                editingItemIndex = nil
                            }
                        )
                    }
                }
                
                // Totals section
                Section("Totals") {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(viewModel.receipt.subtotal.formatted(currency: currency))
                    }
                    
                    HStack {
                        Text("VAT")
                        Spacer()
                        TextField("0", value: $viewModel.receipt.vatPercentage, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%")
                    }
                    .onChange(of: viewModel.receipt.vatPercentage) { _, _ in
                        viewModel.updateVATPercentage(viewModel.receipt.vatPercentage)
                    }
                    
                    HStack {
                        Text("Service")
                        Spacer()
                        TextField("0", value: $viewModel.receipt.servicePercentage, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%")
                    }
                    .onChange(of: viewModel.receipt.servicePercentage) { _, _ in
                        viewModel.updateServicePercentage(viewModel.receipt.servicePercentage)
                    }
                    
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(viewModel.receipt.total.formatted(currency: currency))
                            .font(.headline)
                            .contentTransition(.numericText())
                    }
                }
            }
            .navigationTitle("Confirm Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .navigationBarLeading) {
                    if let debugData = viewModel.ocrResult.debugData {
                        Button("Debug") {
                            showDebugView = true
                        }
                    }
                }
                #endif
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Confirm") {
                        navigateToAddPeople = true
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            #if DEBUG
            .sheet(isPresented: $showDebugView) {
                if let debugData = viewModel.ocrResult.debugData {
                    NavigationStack {
                        DebugReceiptView(debugData: debugData)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Close") {
                                        showDebugView = false
                                    }
                                }
                            }
                    }
                }
            }
            #endif
            .navigationDestination(isPresented: $navigateToAddPeople) {
                AddPeopleView(receipt: viewModel.receipt)
            }
            }
        }
    }
}

struct ItemEditRow: View {
    let item: ReceiptItem
    let isEditing: Bool
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var name: String
    @State private var price: String
    @State private var quantity: String
    
    init(item: ReceiptItem, isEditing: Bool, onEdit: @escaping () -> Void, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.item = item
        self.isEditing = isEditing
        self.onEdit = onEdit
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: item.name)
        _price = State(initialValue: String(item.unitPrice.doubleValue))
        _quantity = State(initialValue: String(item.quantity))
    }
    
    var body: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Item name", text: $name)
                TextField("Unit price", text: $price)
                    .keyboardType(.decimalPad)
                TextField("Quantity", text: $quantity)
                    .keyboardType(.numberPad)
                
                HStack {
                    Button("Cancel", action: onCancel)
                    Spacer()
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                }
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                    if item.quantity > 1 {
                        Text("\(item.quantity) × \(item.unitPrice.formatted(currency: StorageService.shared.loadCurrency()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(item.totalPrice.formatted(currency: StorageService.shared.loadCurrency()))
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
            }
        }
    }
}

