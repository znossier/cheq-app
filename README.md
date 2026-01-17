# Cheq iOS

Split the cheque. Correctly.

A bill splitting app for iOS that scans receipts and calculates fair splits including proportional VAT and service fees.

## Features

- Receipt scanning using Apple Vision framework
- Fair bill splitting (not just even splits)
- Quantity handling for items with multiple units
- Proportional VAT and service fee distribution
- Google Sign-In authentication
- Last 5 receipts storage
- Multiple currency support (EGP, AED, SAR, USD, EUR)

## Setup

1. Open the project in Xcode
2. Add Google Sign-In SDK via Swift Package Manager:
   - File > Add Package Dependencies
   - URL: https://github.com/google/GoogleSignIn-iOS
   - Version: 7.0.0 or later
3. Configure Google Sign-In:
   - See [GOOGLE_SIGNIN_SETUP.md](GOOGLE_SIGNIN_SETUP.md) for detailed setup instructions
   - Add your Google Client ID to the project
   - Update `Info.plist` with your Google Sign-In configuration
4. Build and run on iOS 18+ device or simulator

## Project Structure

- `Models/` - Data models (Receipt, ReceiptItem, Person, User)
- `ViewModels/` - MVVM view models
- `Views/` - SwiftUI views organized by feature
- `Services/` - Business logic services (OCR, Auth, Calculation, Storage)
- `Utilities/` - Extensions and constants

## Requirements

- iOS 18.0+
- Xcode 15.0+
- Swift 5.9+

