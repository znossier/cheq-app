//
//  AuthViewModel.swift
//  Cheq
//
//  Authentication view model
//

import Foundation
import Combine
import UIKit

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authService = AuthService.shared
    
    init() {
        isAuthenticated = authService.isAuthenticated
        currentUser = authService.currentUser
    }
    
    func signIn() {
        isLoading = true
        errorMessage = nil
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to access view controller"
            isLoading = false
            return
        }
        
        Task {
            do {
                try await authService.signIn(with: rootViewController)
                self.isAuthenticated = self.authService.isAuthenticated
                self.currentUser = self.authService.currentUser
                self.isLoading = false
            } catch {
                self.errorMessage = "Sign in failed. Please try again."
                self.isLoading = false
            }
        }
    }
    
    func signOut() {
        authService.signOut()
        isAuthenticated = false
        currentUser = nil
    }
}

