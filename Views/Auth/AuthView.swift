//
//  AuthView.swift
//  Cheq
//
//  Authentication screen with Google Sign-In
//

import SwiftUI
import GoogleSignIn
import UIKit

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            // Background color - uses design system
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    // App logo: 120 x 72 px
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 72)
                    
                    // Cheq: SF Pro, Heavy, 32px
                    Text("Cheq")
                        .font(.system(size: 32, weight: .heavy, design: .default))
                        .foregroundColor(.appTextPrimary)
                    
                    // Slogan: SF Pro Medium, 14px
                    Text("Split the cheque. Correctly.")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.appTextPrimary)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    if authViewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        GoogleSignInButton(action: {
                            authViewModel.signIn()
                        })
                        
                        AppleSignInButton(action: {
                            // Placeholder - will implement Sign in with Apple functionality later
                        })
                    }
                    
                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// Google Sign-In button using app's design system with Google logo
struct GoogleSignInButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Google "G" logo - using official logo asset
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                
                Text("Continue with Google")
                    .font(.headline)
                    .foregroundColor(.appTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appSurface)
            .cornerRadius(12)
        }
        .frame(minHeight: Constants.minimumTapTargetSize)
    }
}

// Apple Sign-In button using app's design system with Apple logo
struct AppleSignInButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Apple logo - using SF Symbol
                Image(systemName: "applelogo")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                
                Text("Continue with Apple ID")
                    .font(.headline)
                    .foregroundColor(.appTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appSurface)
            .cornerRadius(12)
        }
        .frame(minHeight: Constants.minimumTapTargetSize)
    }
}

