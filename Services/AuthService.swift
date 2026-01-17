//
//  AuthService.swift
//  Cheq
//
//  Google Sign-In authentication service
//

import Foundation
import GoogleSignIn
import UIKit

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private let userKey = "currentUser"
    private let authStateKey = "isAuthenticated"
    
    private init() {
        loadAuthState()
    }
    
    func signIn(with presentingViewController: UIViewController) async throws {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        
        let user = User(
            id: result.user.userID ?? "",
            name: result.user.profile?.name ?? "",
            email: result.user.profile?.email ?? "",
            currency: StorageService.shared.loadCurrency()
        )
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            self.saveAuthState(user: user)
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.set(false, forKey: authStateKey)
    }
    
    private func saveAuthState(user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userKey)
            UserDefaults.standard.set(true, forKey: authStateKey)
        }
    }
    
    private func loadAuthState() {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.currentUser = user
            self.isAuthenticated = UserDefaults.standard.bool(forKey: authStateKey)
        }
    }
}

enum AuthError: Error {
    case noPresentingViewController
    case signInFailed
}

