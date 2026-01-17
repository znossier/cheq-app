//
//  HomeView.swift
//  Cheq
//
//  Home screen with greeting and recent receipts
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showScan = false
    @State private var showReceiptHistory = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with personalized greeting
                    VStack(alignment: .leading, spacing: 8) {
                        if let user = authViewModel.currentUser, !user.name.isEmpty {
                            Text("Hi, \(user.firstName)")
                                .font(.system(size: 28, weight: .bold))
                        } else {
                            Text("Hi")
                                .font(.system(size: 28, weight: .bold))
                        }
                        
                        Text("Ready to split your next bill?")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Scan button
                    Button(action: {
                        showScan = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 20, weight: .medium))
                            Text("Scan Receipt")
                                .font(.headline)
                        }
                        .foregroundColor(.appTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appSurface)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .frame(minHeight: Constants.minimumTapTargetSize)
                    .accessibilityLabel("Scan New Receipt")
                    .accessibilityHint("Opens camera to scan a receipt")
                    
                    // Recent receipts - always show section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Receipts")
                                .font(.headline)
                            
                            Spacer()
                            
                            if viewModel.hasMoreReceipts {
                                Button(action: {
                                    showReceiptHistory = true
                                }) {
                                    Text("View All")
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimary)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        if viewModel.isLoading {
                            // Loading state
                            VStack(spacing: 16) {
                                ProgressView()
                                Text("Loading receipts...")
                                    .font(.subheadline)
                                    .foregroundColor(.appTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal)
                        } else if let error = viewModel.loadError {
                            // Error state
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.red)
                                
                                Text("Error Loading Receipts")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.appTextSecondary)
                                    .multilineTextAlignment(.center)
                                
                                Button("Retry") {
                                    viewModel.refreshReceipts()
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal)
                        } else if viewModel.recentReceipts.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                AppIcon.receiptSearch.image(size: 60)
                                    .foregroundColor(.appTextSecondary)
                                
                                Text("No Recent Receipts")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                Text("Start scanning receipts to see them here")
                                    .font(.subheadline)
                                    .foregroundColor(.appTextSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal)
                        } else {
                            ForEach(viewModel.recentReceipts) { receipt in
                                NavigationLink(destination: SummaryView(receipt: receipt)) {
                                    ReceiptRowView(receipt: receipt)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cheq")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showScan) {
                ScanView()
            }
            .navigationDestination(isPresented: $showReceiptHistory) {
                ReceiptHistoryView()
            }
            .onAppear {
                // Refresh when view appears (initial load and when returning from other screens)
                print("📱 HomeView: Appeared, refreshing receipts")
                viewModel.refreshReceipts()
            }
            .onChange(of: showScan) { _, isPresented in
                // When the scan sheet is dismissed, refresh receipts to show new ones
                if !isPresented {
                    print("📱 HomeView: Scan sheet dismissed, refreshing receipts")
                    Task { @MainActor in
                        // Wait for any saves to complete (notification handles most cases, but this is a backup)
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                        viewModel.refreshReceipts()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReceiptSaved"))) { _ in
                // Refresh when a receipt is saved
                // The notification is already posted after merge completes, so we can refresh immediately
                print("📬 HomeView: Received ReceiptSaved notification, refreshing receipts")
                Task { @MainActor in
                    // Small delay to ensure any final Core Data operations complete
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms buffer
                    viewModel.refreshReceipts()
                }
            }
        }
    }
}

