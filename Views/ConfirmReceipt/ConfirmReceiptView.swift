//
//  ConfirmReceiptView.swift
//  Cheq
//
//  Confirm and edit receipt screen
//

import SwiftUI
import UIKit
import Foundation

struct ConfirmReceiptView: View {
    @StateObject private var viewModel: ConfirmReceiptViewModel
    @State private var navigateToAddPeople = false
    @State private var currency = StorageService.shared.loadCurrency()
    @State private var showDebugView = false
    @State private var vatInt: Int = 0
    @State private var serviceInt: Int = 0
    @FocusState private var focusedField: Field?
    let isPreviewMode: Bool
    let onRetry: (() -> Void)?
    
    enum Field {
        case vat, service
    }
    
    init(ocrResult: OCRResult, isPreviewMode: Bool = false, onRetry: (() -> Void)? = nil) {
        self.isPreviewMode = isPreviewMode
        self.onRetry = onRetry
        _viewModel = StateObject(wrappedValue: ConfirmReceiptViewModel(ocrResult: ocrResult, isPreview: isPreviewMode))
    }
    
    var body: some View {
        Group {
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
            } else {
                receiptForm
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
    
    private var receiptForm: some View {
        Form {
            // Items section
            Section("Items") {
                ForEach(viewModel.receipt.items) { item in
                    // Create stable closures outside the view initializer to prevent recreation
                    let itemId = item.id
                    let isItemEditing = viewModel.editingItemId == itemId
                    
                    // Use the item from the current receipt state to ensure we get the latest values
                    // Get the latest item from viewModel to ensure we have current values
                    let latestItem = viewModel.receipt.items.first(where: { $0.id == itemId }) ?? item
                    ReceiptItemRow(
                        item: latestItem,
                        currency: currency,
                        isEditing: isItemEditing,
                        viewModel: viewModel,
                        onEdit: { [weak viewModel] in
                            viewModel?.editingItemId = itemId
                        },
                        onSave: { name, unitPrice, quantity in
                            // CRITICAL: Only store draft, don't update item yet
                            // This prevents view recreation during editing
                            // Use strong reference to viewModel since it's a @StateObject and won't be deallocated
                            viewModel.setEditingDraft(id: itemId, name: name, unitPrice: unitPrice, quantity: quantity)
                        },
                        onDone: { name, unitPrice, quantity in
                            // #region agent log
                            if let logFile = FileHandle(forWritingAtPath: "/Users/zosman/cheq/.cursor/debug.log") {
                                let logData = try! JSONSerialization.data(withJSONObject: [
                                    "location": "ConfirmReceiptView.swift:120",
                                    "message": "onDone closure called",
                                    "data": [
                                        "itemId": itemId.uuidString,
                                        "name": name,
                                        "unitPrice": unitPrice.doubleValue,
                                        "quantity": quantity
                                    ],
                                    "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                                    "sessionId": "debug-session",
                                    "runId": "run1",
                                    "hypothesisId": "A"
                                ])
                                logFile.seekToEndOfFile()
                                logFile.write(logData)
                                logFile.write("\n".data(using: .utf8)!)
                                logFile.closeFile()
                            }
                            // #endregion
                            // Commit the current values directly to the item
                            // This is more reliable than relying on the draft
                            viewModel.updateItem(
                                id: itemId,
                                name: name,
                                unitPrice: unitPrice,
                                quantity: quantity,
                                commitDraft: true
                            )
                            // #region agent log
                            if let logFile = FileHandle(forWritingAtPath: "/Users/zosman/cheq/.cursor/debug.log") {
                                let updatedItem = viewModel.receipt.items.first(where: { $0.id == itemId })
                                let logData = try! JSONSerialization.data(withJSONObject: [
                                    "location": "ConfirmReceiptView.swift:131",
                                    "message": "After updateItem - checking receipt",
                                    "data": [
                                        "itemId": itemId.uuidString,
                                        "updatedItemName": updatedItem?.name ?? "nil",
                                        "updatedItemQuantity": updatedItem?.quantity ?? -1,
                                        "updatedItemUnitPrice": updatedItem?.unitPrice.doubleValue ?? -1,
                                        "receiptItemsCount": viewModel.receipt.items.count
                                    ],
                                    "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                                    "sessionId": "debug-session",
                                    "runId": "run1",
                                    "hypothesisId": "B"
                                ])
                                logFile.seekToEndOfFile()
                                logFile.write(logData)
                                logFile.write("\n".data(using: .utf8)!)
                                logFile.closeFile()
                            }
                            // #endregion
                            viewModel.clearEditingDraft(id: itemId)
                            viewModel.editingItemId = nil
                        },
                        onCancel: { [weak viewModel] in
                            viewModel?.clearEditingDraft(id: itemId)
                            viewModel?.editingItemId = nil
                        },
                        onDelete: { [weak viewModel] in
                            viewModel?.deleteItem(id: itemId)
                        }
                    )
                    .id(itemId) // Simple stable ID
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteItem(id: itemId)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
            
            // Totals section
            Section("Totals") {
                    // Totals will update when view naturally re-evaluates (e.g., user interaction)
                    // Computed properties read from private editingItemDrafts dictionary
                    
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(viewModel.calculatedSubtotal.formatted(currency: currency))
                            .foregroundColor(.appTextSecondary)
                            .contentTransition(.numericText())
                    }
                    
                    HStack {
                        Text("VAT")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", value: $vatInt, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .focused($focusedField, equals: .vat)
                                .onChange(of: vatInt) { _, newValue in
                                    viewModel.updateVATPercentage(Decimal(newValue))
                                }
                            Text("%")
                                .foregroundColor(.appTextSecondary)
                                .padding(.trailing, 12)
                        }
                        .padding(.vertical, 8)
                        .padding(.leading, 12)
                        .background(Color.appSurface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == .vat ? Color.appPrimary : Color.clear, lineWidth: 2)
                        )
                    }
                    .onAppear {
                        vatInt = Int(viewModel.receipt.vatPercentage.doubleValue)
                    }
                    .onChange(of: viewModel.receipt.vatPercentage) { _, newValue in
                        let newInt = Int(newValue.doubleValue)
                        if vatInt != newInt {
                            vatInt = newInt
                        }
                    }
                    
                    HStack {
                        Text("Service")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", value: $serviceInt, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .focused($focusedField, equals: .service)
                                .onChange(of: serviceInt) { _, newValue in
                                    viewModel.updateServicePercentage(Decimal(newValue))
                                }
                            Text("%")
                                .foregroundColor(.appTextSecondary)
                                .padding(.trailing, 12)
                        }
                        .padding(.vertical, 8)
                        .padding(.leading, 12)
                        .background(Color.appSurface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == .service ? Color.appPrimary : Color.clear, lineWidth: 2)
                        )
                    }
                    .onAppear {
                        serviceInt = Int(viewModel.receipt.servicePercentage.doubleValue)
                    }
                    .onChange(of: viewModel.receipt.servicePercentage) { _, newValue in
                        let newInt = Int(newValue.doubleValue)
                        if serviceInt != newInt {
                            serviceInt = newInt
                        }
                    }
                    
                    HStack {
                        Text("VAT Amount")
                        Spacer()
                        Text(viewModel.calculatedVatAmount.formatted(currency: currency))
                            .foregroundColor(.appTextSecondary)
                            .contentTransition(.numericText())
                    }
                    
                    HStack {
                        Text("Service Amount")
                        Spacer()
                        Text(viewModel.calculatedServiceAmount.formatted(currency: currency))
                            .foregroundColor(.appTextSecondary)
                            .contentTransition(.numericText())
                    }
                    
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(viewModel.calculatedTotal.formatted(currency: currency))
                            .font(.headline)
                            .contentTransition(.numericText())
                    }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    Spacer()
                    if focusedField == .vat {
                        Button("Next") {
                            focusedField = .service
                        }
                        .padding(.trailing, 8)
                    }
                    Button("Done") {
                        focusedField = nil
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .padding(.trailing, 16)
                }
            }
        }
    }
}

struct ReceiptItemRow: View {
    let item: ReceiptItem
    let currency: Currency
    let isEditingBinding: Bool // Renamed to make it clear this is a binding
    @ObservedObject var viewModel: ConfirmReceiptViewModel // ObservedObject to react to receipt changes
    let onEdit: () -> Void
    let onSave: (String, Decimal, Int) -> Void
    let onDone: (String, Decimal, Int) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    // Computed property to get the current item from view model (always up-to-date)
    var currentItem: ReceiptItem {
        let found = viewModel.receipt.items.first(where: { $0.id == item.id }) ?? item
        // #region agent log
        if let logFile = FileHandle(forWritingAtPath: "/Users/zosman/cheq/.cursor/debug.log") {
            let logData = try! JSONSerialization.data(withJSONObject: [
                "location": "ConfirmReceiptView.swift:394",
                "message": "currentItem computed",
                "data": [
                    "itemId": item.id.uuidString,
                    "foundName": found.name,
                    "foundQuantity": found.quantity,
                    "foundUnitPrice": found.unitPrice.doubleValue,
                    "receiptItemsCount": viewModel.receipt.items.count
                ],
                "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "C"
            ])
            logFile.seekToEndOfFile()
            logFile.write(logData)
            logFile.write("\n".data(using: .utf8)!)
            logFile.closeFile()
        }
        // #endregion
        return found
    }
    
    @State private var name: String
    @State private var unitPrice: Decimal
    @State private var quantity: Int
    @State private var isSaving = false // Flag to prevent onChange from resetting during save
    @State private var lastSyncedItemId: UUID?
    @State private var isEditing: Bool // Local state - source of truth during editing
    @State private var lastSavedQuantity: Int? // Track the last quantity we saved to prevent loops
    @State private var wasEditingBeforeRecreation = false // Track if we were editing before view recreation
    @FocusState private var focusedItemField: ItemField?
    
    enum ItemField {
        case name, price
    }
    
    init(
        item: ReceiptItem,
        currency: Currency,
        isEditing: Bool,
        viewModel: ConfirmReceiptViewModel,
        onEdit: @escaping () -> Void,
        onSave: @escaping (String, Decimal, Int) -> Void,
        onDone: @escaping (String, Decimal, Int) -> Void,
        onCancel: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.currency = currency
        self.isEditingBinding = isEditing
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.onEdit = onEdit
        self.onSave = onSave
        self.onDone = onDone
        self.onCancel = onCancel
        self.onDelete = onDelete
        // CRITICAL: If we have a draft (view was recreated during editing), use draft values
        // Otherwise, use item values
        let editingDraft = viewModel.getEditingDraft(id: item.id)
        _name = State(initialValue: editingDraft?.name ?? item.name)
        _unitPrice = State(initialValue: editingDraft?.unitPrice ?? item.unitPrice)
        _quantity = State(initialValue: editingDraft?.quantity ?? item.quantity)
        _isSaving = State(initialValue: false)
        _lastSyncedItemId = State(initialValue: item.id)
        // CRITICAL: If we have a draft, we were editing, so preserve edit mode even if isEditingBinding is false
        // This handles the case where view is recreated but editingItemId hasn't been set yet
        let shouldBeEditing = isEditing || editingDraft != nil
        _isEditing = State(initialValue: shouldBeEditing)
        _wasEditingBeforeRecreation = State(initialValue: shouldBeEditing)
        
    }
    
    var body: some View {
        // Explicitly access currentItem properties to ensure SwiftUI tracks changes
        // This ensures the view re-evaluates when receipt items are updated
        let itemName = currentItem.name
        let itemQuantity = currentItem.quantity
        let itemUnitPrice = currentItem.unitPrice
        // #region agent log
        if let logFile = FileHandle(forWritingAtPath: "/Users/zosman/cheq/.cursor/debug.log") {
            let logData = try! JSONSerialization.data(withJSONObject: [
                "location": "ConfirmReceiptView.swift:351",
                "message": "ReceiptItemRow body evaluated",
                "data": [
                    "itemId": item.id.uuidString,
                    "itemName": itemName,
                    "itemQuantity": itemQuantity,
                    "itemUnitPrice": itemUnitPrice.doubleValue,
                    "isEditing": isEditing,
                    "receiptItemsCount": viewModel.receipt.items.count
                ],
                "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "D"
            ])
            logFile.seekToEndOfFile()
            logFile.write(logData)
            logFile.write("\n".data(using: .utf8)!)
            logFile.closeFile()
        }
        // #endregion
        return contentView
            .onChange(of: viewModel.receipt.items) {
                // #region agent log
                if let logFile = FileHandle(forWritingAtPath: "/Users/zosman/cheq/.cursor/debug.log") {
                    let logData = try! JSONSerialization.data(withJSONObject: [
                        "location": "ConfirmReceiptView.swift:353",
                        "message": "onChange receipt.items triggered",
                        "data": [
                            "itemId": item.id.uuidString,
                            "itemsCount": viewModel.receipt.items.count
                        ],
                        "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                        "sessionId": "debug-session",
                        "runId": "run1",
                        "hypothesisId": "D"
                    ])
                    logFile.seekToEndOfFile()
                    logFile.write(logData)
                    logFile.write("\n".data(using: .utf8)!)
                    logFile.closeFile()
                }
                // #endregion
                // Force view refresh when receipt items change
                // This ensures currentItem is re-evaluated with latest values
            }
            .onChange(of: isEditingBinding) { oldValue, newValue in
                handleEditingBindingChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: currentItem.id) { oldId, newId in
                handleItemIdChange(oldId: oldId, newId: newId)
            }
            .onChange(of: currentItem.quantity) { oldQty, newQty in
                handleItemQuantityChange(oldQty: oldQty, newQty: newQty)
            }
            .onAppear {
                handleOnAppear()
            }
    }
    
    @ViewBuilder
    private var contentView: some View {
        Group {
            if isEditing {
                VStack(alignment: .leading, spacing: 16) {
                            // Quantity row - using native Stepper for stability
                            HStack {
                                Text("Quantity")
                                    .font(.subheadline)
                                    .foregroundColor(.appTextSecondary)
                                Spacer()
                                Stepper(value: Binding(
                                    get: { quantity },
                                    set: { newValue in
                                        // Clamp to minimum 1
                                        let clampedValue = max(1, newValue)
                                        // Update local state immediately
                                        quantity = clampedValue
                                        lastSavedQuantity = clampedValue
                                        triggerHapticFeedback()
                                        // Store draft without triggering view updates
                                        let currentName = name
                                        let currentUnitPrice = unitPrice
                                        isSaving = true
                                        onSave(currentName, currentUnitPrice, clampedValue)
                                        isSaving = false
                                    }
                                ), in: 1...999) {
                                    Text("\(quantity)")
                                        .frame(minWidth: 40)
                                        .multilineTextAlignment(.center)
                                }
                            }
                    
                    // Name field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Item Name")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                        TextField("Item name", text: $name)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.appSurface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedItemField == .name ? Color.appPrimary : Color.clear, lineWidth: 2)
                            )
                            .focused($focusedItemField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedItemField = .price
                            }
                            .onChange(of: focusedItemField) { _, newValue in
                                if newValue != .name {
                                    saveChanges()
                                }
                            }
                    }
                    
                    // Price field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unit Price")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                        HStack(spacing: 0) {
                            Text(currency.symbol)
                                .foregroundColor(.appTextSecondary)
                                .padding(.leading, 12)
                                .padding(.trailing, 4)
                            TextField("0.00", value: $unitPrice, format: .number)
                                .keyboardType(.decimalPad)
                                .focused($focusedItemField, equals: .price)
                                .submitLabel(.done)
                                .onSubmit {
                                    saveChanges()
                                    isEditing = false
                                    lastSavedQuantity = nil
                                    onDone(name, unitPrice, quantity)
                                }
                                .onChange(of: focusedItemField) { _, newValue in
                                    if newValue != .price {
                                        saveChanges()
                                    }
                                }
                                .onChange(of: unitPrice) { _, _ in
                                    saveChanges()
                                }
                        }
                        .padding(.vertical, 8)
                        .padding(.trailing, 12)
                        .background(Color.appSurface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedItemField == .price ? Color.appPrimary : Color.clear, lineWidth: 2)
                        )
                    }
                    
                    // Cancel and Done buttons
                    HStack {
                        Button {
                            // Reset to original values before canceling
                            name = currentItem.name
                            unitPrice = currentItem.unitPrice
                            quantity = currentItem.quantity
                            focusedItemField = nil
                            // Dismiss keyboard
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            // Exit edit mode
                            onCancel()
                        } label: {
                            Text("Cancel")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.appTextSecondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                        Spacer()
                        Button {
                            // #region agent log
                            if let logFile = FileHandle(forWritingAtPath: "/Users/zosman/cheq/.cursor/debug.log") {
                                let logData = try! JSONSerialization.data(withJSONObject: [
                                    "location": "ConfirmReceiptView.swift:496",
                                    "message": "Done button tapped",
                                    "data": [
                                        "itemId": item.id.uuidString,
                                        "name": name,
                                        "unitPrice": unitPrice.doubleValue,
                                        "quantity": quantity,
                                        "isEditing": isEditing
                                    ],
                                    "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                                    "sessionId": "debug-session",
                                    "runId": "run1",
                                    "hypothesisId": "A"
                                ])
                                logFile.seekToEndOfFile()
                                logFile.write(logData)
                                logFile.write("\n".data(using: .utf8)!)
                                logFile.closeFile()
                            }
                            // #endregion
                            // Pass current values directly to onDone - this will commit the changes
                            let validQuantity = max(1, quantity)
                            // #region agent log
                            if let logFile = FileHandle(forWritingAtPath: "/Users/zosman/cheq/.cursor/debug.log") {
                                let logData = try! JSONSerialization.data(withJSONObject: [
                                    "location": "ConfirmReceiptView.swift:499",
                                    "message": "Calling onDone",
                                    "data": [
                                        "itemId": item.id.uuidString,
                                        "name": name,
                                        "unitPrice": unitPrice.doubleValue,
                                        "quantity": validQuantity
                                    ],
                                    "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                                    "sessionId": "debug-session",
                                    "runId": "run1",
                                    "hypothesisId": "E"
                                ])
                                logFile.seekToEndOfFile()
                                logFile.write(logData)
                                logFile.write("\n".data(using: .utf8)!)
                                logFile.closeFile()
                            }
                            // #endregion
                            onDone(name, unitPrice, validQuantity)
                            // After onDone updates the view model, sync local state with the updated item
                            // This ensures the non-editing view displays the correct values
                            // #region agent log
                            if let logFile = FileHandle(forWritingAtPath: "/Users/zosman/cheq/.cursor/debug.log") {
                                let logData = try! JSONSerialization.data(withJSONObject: [
                                    "location": "ConfirmReceiptView.swift:502",
                                    "message": "After onDone - syncing state",
                                    "data": [
                                        "itemId": item.id.uuidString,
                                        "currentItemName": currentItem.name,
                                        "currentItemQuantity": currentItem.quantity,
                                        "currentItemUnitPrice": currentItem.unitPrice.doubleValue,
                                        "localName": name,
                                        "localQuantity": quantity,
                                        "localUnitPrice": unitPrice.doubleValue
                                    ],
                                    "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                                    "sessionId": "debug-session",
                                    "runId": "run1",
                                    "hypothesisId": "C"
                                ])
                                logFile.seekToEndOfFile()
                                logFile.write(logData)
                                logFile.write("\n".data(using: .utf8)!)
                                logFile.closeFile()
                            }
                            // #endregion
                            name = currentItem.name
                            unitPrice = currentItem.unitPrice
                            quantity = currentItem.quantity
                            // Exit edit mode and clear tracking
                            isEditing = false
                            lastSavedQuantity = nil
                        } label: {
                            Text("Done")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.appPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentItem.name)
                            if currentItem.quantity > 1 {
                                Text("Qty: \(currentItem.quantity) × \(currentItem.unitPrice.formatted(currency: currency))")
                                    .font(.caption)
                                    .foregroundColor(.appTextSecondary)
                            }
                        }
                        Spacer()
                        Text(currentItem.totalPrice.formatted(currency: currency))
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.appPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func handleEditingBindingChange(oldValue: Bool, newValue: Bool) {
            // Sync local isEditing state from binding ONLY when entering edit mode
            // CRITICAL: Never exit edit mode based on binding changes - only exit via Done/Cancel buttons
            // This prevents edit mode from closing when item updates cause temporary binding changes
            if newValue && !isEditing {
                // Entering edit mode - sync state from item
                            name = currentItem.name
                            unitPrice = currentItem.unitPrice
                            quantity = currentItem.quantity
                isEditing = true
                wasEditingBeforeRecreation = true
            } else if newValue && isEditing {
                // Binding is still true and we're already editing - view was recreated during editing
                // CRITICAL: Don't reset state - preserve current local state (quantity, name, etc.)
                // The local state is the source of truth during editing
                // Just ensure isEditing stays true (it should already be true)
                wasEditingBeforeRecreation = true
            } else if !newValue && isEditing {
                // Exiting edit mode - sync with updated item from viewModel
                // This ensures the non-editing view displays the latest values after updateItem completes
                name = currentItem.name
                unitPrice = currentItem.unitPrice
                quantity = currentItem.quantity
                isEditing = false
                wasEditingBeforeRecreation = false
            } else if !newValue {
                // Binding became false but we're not editing - just update flag
                wasEditingBeforeRecreation = false
            }
        }
    
    private func handleItemIdChange(oldId: UUID, newId: UUID) {
        // Only sync if item ID changed (different item) and we're not editing
        // CRITICAL: Never sync during editing - check isEditing directly
        if !isEditing && newId != lastSyncedItemId {
            name = currentItem.name
            unitPrice = currentItem.unitPrice
            quantity = currentItem.quantity
            lastSyncedItemId = newId
        }
    }
    
    private func handleItemQuantityChange(oldQty: Int, newQty: Int) {
        // CRITICAL: Never sync quantity from item if we're editing - we are the source of truth
        // Only sync if we're not editing and not in the middle of saving
        // Also don't sync if this is the quantity we just saved (to prevent loops)
        if !isEditing && !isSaving && newQty != quantity {
            // Only sync if this change wasn't from our own commit
            // If lastSavedQuantity is set, it means we just committed this value, so don't reset it
            // This prevents the view from resetting the quantity after updateItem completes
            if lastSavedQuantity == nil || newQty != lastSavedQuantity {
                quantity = newQty
            }
        }
        // If isEditing is true, we completely ignore item.quantity changes
    }
    
    private func handleOnAppear() {
        // Initialize lastSyncedItemId
        if lastSyncedItemId == nil {
            lastSyncedItemId = currentItem.id
        }
        // CRITICAL: If we're editing and view was recreated, preserve edit mode
        // Check if binding is true but local state says we're not editing (view was recreated)
        if isEditingBinding && !isEditing {
            // View was recreated during editing - restore edit mode
            isEditing = true
            // Don't reset quantity/name/price - they should already be set from init
            // But if they're wrong, we might need to preserve them differently
        }
    }
    
    private func saveChanges(commit: Bool = false) {
        // Ensure quantity is always at least 1
        let validQuantity = max(1, quantity)
        // Pass commit flag to indicate if we should actually update the item
        // For quantity stepper, we don't commit (just store draft)
        // For Done button, we commit (actually update the item)
        onSave(name, unitPrice, validQuantity)
    }
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}


