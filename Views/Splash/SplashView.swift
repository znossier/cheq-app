//
//  SplashView.swift
//  Cheq
//
//  Splash screen with centered logo
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.charcoalBlack
                .ignoresSafeArea()
            
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120)
        }
    }
}

