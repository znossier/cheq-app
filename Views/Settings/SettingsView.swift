//
//  SettingsView.swift
//  Cheq
//
//  Settings screen with profile and preferences
//

import SwiftUI
import UIKit

enum SettingsFocusField {
    case vat
    case service
}

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedCurrency: Currency = StorageService.shared.loadCurrency()
    @State private var showLogoutAlert = false
    @State private var showDeleteAllReceiptsAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showResetPreferencesAlert = false
    @State private var receiptCount: Int = 0
    @State private var isLoadingReceiptCount = false
    @State private var defaultVATInt: Int = 0
    @State private var defaultServiceFeeInt: Int = 0
    @State private var hapticFeedbackEnabled: Bool = true
    @State private var appearanceMode: AppearanceMode = .system
    @FocusState private var focusedField: SettingsFocusField?
    
    private let preferencesService = UserPreferencesService.shared
    private let storageService = StorageService.shared
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile section
                Section("Profile") {
                    if let user = authViewModel.currentUser {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(user.name)
                                .foregroundColor(.appTextSecondary)
                        }
                        
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }
                
                // Preferences section
                Section {
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(Currency.allCases, id: \.self) { currency in
                            Text("\(currency.symbol) \(currency.rawValue)").tag(currency)
                        }
                    }
                    .onChange(of: selectedCurrency) { _, newCurrency in
                        StorageService.shared.saveCurrency(newCurrency)
                    }
                    
                    HStack {
                        Text("Default VAT %")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", value: $defaultVATInt, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .focused($focusedField, equals: .vat)
                                .onChange(of: defaultVATInt) { _, newValue in
                                    preferencesService.saveDefaultVATPercentage(Decimal(newValue))
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
                        defaultVATInt = Int(preferencesService.loadDefaultVATPercentage().doubleValue)
                    }
                    
                    HStack {
                        Text("Default Service Fee %")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", value: $defaultServiceFeeInt, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .focused($focusedField, equals: .service)
                                .onChange(of: defaultServiceFeeInt) { _, newValue in
                                    preferencesService.saveDefaultServiceFeePercentage(Decimal(newValue))
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
                        defaultServiceFeeInt = Int(preferencesService.loadDefaultServiceFeePercentage().doubleValue)
                    }
                } header: {
                    Text("Preferences")
                } footer: {
                    Text("Changes to currency, VAT, or service fee will apply to receipts scanned from now on. Existing receipts will not change.")
                }
                
                // Data Management section
                Section("Data") {
                    HStack {
                        Text("Receipts Stored")
                        Spacer()
                        if isLoadingReceiptCount {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("\(receiptCount)")
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                    
                    NavigationLink(destination: ReceiptHistoryView()) {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.appTextSecondary)
                            Text("View All Receipts")
                                .foregroundColor(.appTextPrimary)
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        showDeleteAllReceiptsAlert = true
                    }) {
                        Label("Clear All Receipts", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                // Appearance & Accessibility section
                Section("Appearance & Accessibility") {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .onChange(of: appearanceMode) { _, newValue in
                        preferencesService.saveAppearanceMode(newValue)
                        // Trigger appearance update
                        NotificationCenter.default.post(name: NSNotification.Name("AppearanceModeChanged"), object: nil)
                    }
                    
                    Toggle("Haptic Feedback", isOn: $hapticFeedbackEnabled)
                        .onChange(of: hapticFeedbackEnabled) { _, newValue in
                            preferencesService.saveHapticFeedbackEnabled(newValue)
                        }
                }
                
                // App Information section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.appTextSecondary)
                    }
                    
                    Link(destination: URL(string: "https://your-privacy-policy-url.com")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    Link(destination: URL(string: "https://your-terms-url.com")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    Button(action: {
                        if let url = URL(string: "mailto:zeina.nossier@gmail.com") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("Contact Support", systemImage: "envelope")
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    ShareLink(item: URL(string: "https://apps.apple.com/app/your-app-id")!) {
                        Label("Share App", systemImage: "square.and.arrow.up")
                            .foregroundColor(.appTextPrimary)
                    }
                }
                
                // Quick Actions section
                Section("Quick Actions") {
                    Button(action: {
                        resetOnboarding()
                    }) {
                        Label("View Tutorial", systemImage: "book")
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    Button(action: {
                        showResetPreferencesAlert = true
                    }) {
                        Label("Reset Preferences", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.appTextPrimary)
                    }
                }
                
                // Account section
                Section {
                    Button(role: .destructive, action: {
                        showLogoutAlert = true
                    }) {
                        Text("Log Out")
                    }
                    
                    Button(role: .destructive, action: {
                        showDeleteAccountAlert = true
                    }) {
                        Text("Delete Account")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                        .padding(.trailing, 16)
                    }
                }
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    authViewModel.signOut()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Clear All Receipts", isPresented: $showDeleteAllReceiptsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    clearAllReceipts()
                }
            } message: {
                Text("This will permanently delete all your receipts. This action cannot be undone.")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            .alert("Reset Preferences", isPresented: $showResetPreferencesAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetPreferences()
                }
            } message: {
                Text("This will reset all preferences to their default values.")
            }
            .task {
                loadPreferences()
                await loadReceiptCountAsync()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReceiptSaved"))) { _ in
                // Refresh receipt count when a new receipt is saved
                Task {
                    await loadReceiptCountAsync()
                }
            }
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    private func loadPreferences() {
        defaultVATInt = Int(preferencesService.loadDefaultVATPercentage().doubleValue)
        defaultServiceFeeInt = Int(preferencesService.loadDefaultServiceFeePercentage().doubleValue)
        hapticFeedbackEnabled = preferencesService.loadHapticFeedbackEnabled()
        appearanceMode = preferencesService.loadAppearanceMode()
    }
    
    private func loadReceiptCount() {
        guard authViewModel.currentUser?.id != nil else {
            receiptCount = 0
            isLoadingReceiptCount = false
            return
        }
        
        isLoadingReceiptCount = true
        Task {
            await loadReceiptCountAsync()
        }
    }
    
    @MainActor
    private func loadReceiptCountAsync() async {
        guard let userId = authViewModel.currentUser?.id else {
            receiptCount = 0
            isLoadingReceiptCount = false
            return
        }
        
        isLoadingReceiptCount = true
        defer {
            // Always reset loading state, even if there's an error
            isLoadingReceiptCount = false
        }
        
        do {
            // Load receipts - will fail fast if Core Data model not found
            let receipts = try await storageService.loadAllReceipts(userId: userId)
            receiptCount = receipts.count
        } catch {
            print("Error loading receipt count: \(error)")
            // Show error state instead of endless spinner
            // Set count to 0 to indicate error, but don't keep loading
            receiptCount = 0
            
            // Check if it's a model file error
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("failed to load model") || errorDescription.contains("model named") {
                print("⚠️ SettingsView: Core Data model not found - receipt count unavailable")
            }
        }
    }
    
    private func clearAllReceipts() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        Task {
            do {
                try await storageService.deleteAllReceipts(userId: userId)
                await MainActor.run {
                    receiptCount = 0
                }
            } catch {
                print("Error clearing receipts: \(error)")
            }
        }
    }
    
    private func resetPreferences() {
        preferencesService.resetToDefaults()
        loadPreferences()
    }
    
    private func deleteAccount() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        Task {
            // Clear all receipts
            do {
                try await storageService.deleteAllReceipts(userId: userId)
            } catch {
                print("Error deleting receipts: \(error)")
            }
            
            // Clear preferences
            preferencesService.resetToDefaults()
            
            // Sign out (this clears auth data)
            await MainActor.run {
                authViewModel.signOut()
            }
        }
    }
    
    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
        // Trigger immediate onboarding display via notification
        NotificationCenter.default.post(name: NSNotification.Name("ResetOnboarding"), object: nil)
    }
}
