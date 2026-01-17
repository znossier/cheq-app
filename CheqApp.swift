//
//  CheqApp.swift
//  Cheq
//
//  Created on iOS 18+
//

import SwiftUI
import GoogleSignIn
#if os(iOS)
import UIKit
#endif

@main
struct CheqApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var appearanceMode: AppearanceMode = .system
    
    init() {
        // Configure Google Sign-In
        // Google Cloud project: cheq-oauth
        let clientId = "787819429630-khd6bejk34llguqe77agj8kd0pqcse4v.apps.googleusercontent.com"
        
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
        
        // Register Core Data transformer
        ValueTransformer.registerUnitAssignmentsTransformer()
        
        // Load appearance mode preference
        appearanceMode = UserPreferencesService.shared.loadAppearanceMode()
        
        // Configure text selection highlighting colors
        #if os(iOS)
        // Text selection highlight: charcoal in light mode, white in dark mode
        let selectionColor = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                // Dark mode: white (#F4F6F8)
                return UIColor(red: 0xF4 / 255.0, green: 0xF6 / 255.0, blue: 0xF8 / 255.0, alpha: 1.0)
            } else {
                // Light mode: charcoal (#0E1116)
                return UIColor(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)
            }
        }
        
        UITextField.appearance().tintColor = selectionColor
        UITextView.appearance().tintColor = selectionColor
        
        // Configure tab bar appearance
        configureTabBarAppearance()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .preferredColorScheme(appearanceMode.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppearanceModeChanged"))) { _ in
                    appearanceMode = UserPreferencesService.shared.loadAppearanceMode()
                }
        }
    }
    
    #if os(iOS)
    private func configureTabBarAppearance() {
        // Create dynamic colors that adapt to trait collection
        let selectedColor = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                // Dark mode: white (#F4F6F8)
                return UIColor(red: 0xF4 / 255.0, green: 0xF6 / 255.0, blue: 0xF8 / 255.0, alpha: 1.0)
            } else {
                // Light mode: charcoal (#0E1116)
                return UIColor(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)
            }
        }
        
        let unselectedColor = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                // Dark mode: secondary white (#A3ACB9)
                return UIColor(red: 0xA3 / 255.0, green: 0xAC / 255.0, blue: 0xB9 / 255.0, alpha: 1.0)
            } else {
                // Light mode: secondary (#475569)
                return UIColor(red: 0x47 / 255.0, green: 0x55 / 255.0, blue: 0x69 / 255.0, alpha: 1.0)
            }
        }
        
        // Create adaptive appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Configure all layout appearances (stacked, inline, compact)
        let layouts = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ]
        
        for layout in layouts {
            // Configure selected state
            layout.selected.iconColor = selectedColor
            layout.selected.titleTextAttributes = [
                .foregroundColor: selectedColor
            ]
            
            // Configure unselected state
            layout.normal.iconColor = unselectedColor
            layout.normal.titleTextAttributes = [
                .foregroundColor: unselectedColor
            ]
        }
        
        // Also set via UITabBarItem appearance as a fallback
        UITabBarItem.appearance().setTitleTextAttributes([
            .foregroundColor: unselectedColor
        ], for: .normal)
        
        UITabBarItem.appearance().setTitleTextAttributes([
            .foregroundColor: selectedColor
        ], for: .selected)
        
        // Apply to tab bar appearance proxy
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // Force icon color update via tintColor (this affects unselected icons)
        UITabBar.appearance().unselectedItemTintColor = unselectedColor
        UITabBar.appearance().tintColor = selectedColor
    }
    #endif
}

