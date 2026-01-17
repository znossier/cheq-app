# Google Sign-In Setup Instructions

## ✅ Completed Steps

1. ✅ Xcode project created (`Cheq.xcodeproj`)
2. ✅ Google Sign-In SDK added via Swift Package Manager
3. ✅ Google Sign-In initialization code added to `CheqApp.swift`
4. ✅ URL scheme configuration added to `Info.plist`

## 🔧 Remaining Configuration

### Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project named **cheq-oauth** (or select existing project)
3. Enable the Google Sign-In API for your project

### Step 2: Get Your Google Client ID

1. In Google Cloud Console, navigate to **APIs & Services** > **Credentials**
2. Create a new **OAuth 2.0 Client ID** with application type set to **iOS**
3. Copy your Client ID (format: `123456789-abcdefghijklmnop.apps.googleusercontent.com`)

### Step 3: Configure Client ID in Code

1. Open `CheqApp.swift` in Xcode
2. Find the line: `let clientId = "YOUR_CLIENT_ID_HERE.apps.googleusercontent.com"`
3. Replace `YOUR_CLIENT_ID_HERE` with your actual Client ID (the part before `.apps.googleusercontent.com`)
   - Example: If your Client ID is `123456789-abcdefghijklmnop.apps.googleusercontent.com`
   - Replace `YOUR_CLIENT_ID_HERE` with `123456789-abcdefghijklmnop`

### Step 4: Configure URL Scheme in Info.plist

1. Open `Info.plist` in Xcode
2. Find the `CFBundleURLTypes` > `CFBundleURLSchemes` section
3. Locate the URL scheme value: `com.googleusercontent.apps.YOUR_CLIENT_ID_HERE`
4. Replace `YOUR_CLIENT_ID_HERE` with the same Client ID value you used in Step 3 (without `.apps.googleusercontent.com`)
   - Example: If your Client ID is `123456789-abcdefghijklmnop.apps.googleusercontent.com`
   - Replace `YOUR_CLIENT_ID_HERE` with `123456789-abcdefghijklmnop`
   - The final URL scheme should be: `com.googleusercontent.apps.123456789-abcdefghijklmnop`

### Step 5: Build and Run

1. Select an iOS 18+ simulator or device
2. Press **Cmd+R** to build and run
3. Test Google Sign-In functionality

## 📝 Notes

- The Google Sign-In SDK (version 7.0.0+) has been automatically resolved
- All Swift files are included in the project
- The project is configured for iOS 18.0+ deployment target
- Bundle identifier is set to `com.zeinanosier.cheq`
- Google Cloud project should be named **cheq-oauth**

