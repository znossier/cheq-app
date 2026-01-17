//
//  MainTabView.swift
//  Cheq
//
//  Main tab bar navigation
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
    }
}

