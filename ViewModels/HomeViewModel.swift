//
//  HomeViewModel.swift
//  Cheq
//
//  Home screen view model
//

import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var recentReceipts: [Receipt] = [] // Limited to 7 for display
    @Published var hasMoreReceipts = false // True if user has more than 7 receipts
    @Published var isLoading = false
    @Published var loadError: String? // User-friendly error message
    
    private let storageService = StorageService.shared
    private let authService = AuthService.shared
    
    init() {
        performMigrationIfNeeded()
        // Load receipts if user is already authenticated
        if authService.isAuthenticated {
        Task {
            await loadRecentReceipts()
            }
        }
    }
    
    /// Performs migration of old receipts to current user if needed
    private func performMigrationIfNeeded() {
        if let userId = authService.currentUser?.id {
            storageService.migrateReceiptsIfNeeded(to: userId)
        }
    }
    
    /// Loads the first 7 receipts for display on home screen
    func loadRecentReceipts() async {
        guard let userId = authService.currentUser?.id else {
            print("⚠️ HomeViewModel: Cannot load receipts - no user ID. Current user: \(String(describing: authService.currentUser))")
            await MainActor.run {
            recentReceipts = []
            hasMoreReceipts = false
                isLoading = false
            }
            return
        }
        
        print("📖 HomeViewModel: Loading receipts for user \(userId)")
        await MainActor.run {
        isLoading = true
            loadError = nil // Clear previous errors
        }
        
        do {
            // Load receipts - will fail fast if Core Data model not found
            let allReceipts = try await self.storageService.loadAllReceipts(userId: userId)
            
            print("📖 HomeViewModel: Loaded \(allReceipts.count) receipts")
            
            await MainActor.run {
            // Limit to first 7 for display
            recentReceipts = Array(allReceipts.prefix(Constants.maxReceiptsToStore))
            
            // Check if there are more receipts
            hasMoreReceipts = allReceipts.count > Constants.maxReceiptsToStore
                isLoading = false
                loadError = nil // Clear any errors on success
            print("📖 HomeViewModel: Showing \(recentReceipts.count) recent receipts, hasMore: \(hasMoreReceipts)")
            }
        } catch {
            print("❌ HomeViewModel: Error loading receipts: \(error.localizedDescription)")
            print("   Full error: \(error)")
            
            // Provide user-friendly error messages
            let userMessage: String
            let errorDescription = error.localizedDescription.lowercased()
            
            // Check for Core Data model file errors
            if errorDescription.contains("failed to load model") || errorDescription.contains("model named") {
                userMessage = "Database not available. The app may need to be reinstalled."
            } else if errorDescription.contains("persistent store") {
                userMessage = "Storage error. Please restart the app."
            } else {
                userMessage = "Failed to load receipts: \(error.localizedDescription)"
            }
            
            await MainActor.run {
            recentReceipts = []
            hasMoreReceipts = false
                isLoading = false
                loadError = userMessage
            }
        }
    }
    
    func refreshReceipts() {
        Task {
            await loadRecentReceipts()
        }
    }
}

