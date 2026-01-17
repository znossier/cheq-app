//
//  ContentView.swift
//  Cheq
//
//  Root view that handles navigation based on auth state
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSplash = true
    @State private var showOnboarding = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if showSplash {
                    SplashView()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showSplash = false
                                    checkOnboardingStatus()
                                }
                            }
                        }
                } else if showOnboarding {
                    OnboardingView(showOnboarding: $showOnboarding)
                } else if authViewModel.isAuthenticated {
                    MainTabView()
                } else {
                    AuthView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetOnboarding"))) { _ in
            showOnboarding = true
        }
    }
    
    private func checkOnboardingStatus() {
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        if !hasSeenOnboarding {
            showOnboarding = true
        }
    }
}

