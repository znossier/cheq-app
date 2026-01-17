//
//  ReceiptHistoryView.swift
//  Cheq
//
//  Full receipt history view showing all past receipts
//

import SwiftUI

struct ReceiptHistoryView: View {
    @StateObject private var viewModel = ReceiptHistoryViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            if viewModel.allReceipts.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    AppIcon.receiptSearch.image(size: 60)
                        .foregroundColor(.appTextSecondary)
                    
                    Text("No Receipts Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Start scanning receipts to see them here")
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 100)
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.allReceipts) { receipt in
                        NavigationLink(destination: SummaryView(receipt: receipt)) {
                            ReceiptRowView(receipt: receipt)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("All Receipts")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            viewModel.refreshReceipts()
        }
        .onAppear {
            viewModel.loadReceipts()
        }
    }
}

@MainActor
class ReceiptHistoryViewModel: ObservableObject {
    @Published var allReceipts: [Receipt] = []
    @Published var isLoading = false
    
    private let storageService = StorageService.shared
    private let authService = AuthService.shared
    
    func loadReceipts() {
        Task {
            await performLoadReceipts()
        }
    }
    
    private func performLoadReceipts() async {
        guard let userId = authService.currentUser?.id else {
            allReceipts = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load all receipts, already sorted by newest first (timestamp descending)
            allReceipts = try await storageService.loadAllReceipts(userId: userId)
        } catch {
            print("Error loading receipts: \(error)")
            allReceipts = []
        }
    }
    
    func refreshReceipts() {
        loadReceipts()
    }
}

