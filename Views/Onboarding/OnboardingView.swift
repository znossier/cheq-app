//
//  OnboardingView.swift
//  Cheq
//
//  Onboarding carousel with 3 screens
//

import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    
    private let pages = [
        OnboardingPage(
            title: "Scan receipts instantly",
            description: "Cheq extracts all item details automatically.",
            icon: "doc.text.viewfinder"
        ),
        OnboardingPage(
            title: "Calculated proportionately",
            description: "Tax and service are allocated based on item shares.",
            icon: "divide"
        ),
        OnboardingPage(
            title: "Know who owes what",
            description: "Clear totals for everyone before you settle.",
            icon: "checkmark.circle"
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background extends behind safe areas
                Color.appBackground
                    .ignoresSafeArea()
                
                // Content respects safe areas
                VStack(spacing: 0) {
                    // Skip button - add safe area top padding
                    HStack {
                        Spacer()
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top + 8 : 8)
                    
                    // Carousel
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            OnboardingPageView(page: pages[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page)
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    
                    // Continue button - add safe area bottom padding
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        Text(currentPage < pages.count - 1 ? "Next" : "Start Cheq")
                            .font(.headline)
                            .foregroundColor(currentPage < pages.count - 1 ? .appTextPrimary : .appButtonTextOnMint)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(currentPage < pages.count - 1 ? Color.appSurface : Color.appMint)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom + 16 : 16)
                }
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        withAnimation {
            showOnboarding = false
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let icon: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: page.icon)
                .font(.system(size: 80, weight: .medium))
                .foregroundColor(.appTextSecondary)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}

