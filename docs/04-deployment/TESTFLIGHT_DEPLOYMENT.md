# TestFlight Deployment Guide for JEEVibe

## Prerequisites
- ✅ Apple Developer Account (paid membership)
- ✅ App registered in App Store Connect
- ✅ Certificates and Provisioning Profiles configured in Xcode

## Step-by-Step Process

### 1. Update Version & Build Number
Update `pubspec.yaml`:
```yaml
version: 1.0.1+2  # Format: MAJOR.MINOR.PATCH+BUILD_NUMBER
```
- Version (1.0.1): User-facing version
- Build Number (+2): Must increment for each TestFlight upload

### 2. Clean and Prepare
```bash
cd mobile
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

### 3. Build iOS Release
```bash
flutter build ipa --release
```
This creates: `build/ios/ipa/jeevibe_mobile.ipa`

### 4. Upload to App Store Connect

#### Option A: Using Xcode (Recommended)
1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select **Product → Archive**
3. Wait for archive to complete
4. In Organizer window:
   - Click **Distribute App**
   - Select **App Store Connect**
   - Click **Next**
   - Select **Upload**
   - Follow prompts to upload

#### Option B: Using Command Line (Transporter)
1. Download **Transporter** app from Mac App Store
2. Open Transporter
3. Drag the `.ipa` file from `build/ios/ipa/`
4. Click **Deliver**

#### Option C: Using `altool` (Legacy)
```bash
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/jeevibe_mobile.ipa \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```

### 5. Configure in App Store Connect
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **My Apps** → **JEEVibe**
3. Go to **TestFlight** tab
4. Wait for processing (usually 10-30 minutes)
5. Once processed:
   - Add testers (Internal or External)
   - Add build to a test group
   - Configure test information

### 6. Invite Testers
- **Internal Testers**: Up to 100, available immediately
- **External Testers**: Up to 10,000, requires Beta App Review (24-48 hours)

## Important Notes

### Version Requirements
- Each TestFlight build must have a unique, incrementing build number
- Version can stay the same, but build number must increase

### Processing Time
- First upload: 10-30 minutes
- Subsequent uploads: Usually faster
- External beta review: 24-48 hours (first time)

### Common Issues

1. **Code Signing Errors**
   - Check certificates in Xcode → Preferences → Accounts
   - Ensure provisioning profile matches bundle ID

2. **Build Number Conflicts**
   - Increment build number in `pubspec.yaml`
   - Or use: `flutter build ipa --build-number=3`

3. **Missing Permissions**
   - Camera: ✅ Already configured in Info.plist
   - Photo Library: ✅ Already configured in Info.plist

### Quick Commands Reference
```bash
# Clean build
flutter clean && flutter pub get

# Build IPA
flutter build ipa --release

# Build with specific version
flutter build ipa --release --build-number=3 --build-name=1.0.1

# Open Xcode
open ios/Runner.xcworkspace

# Check Flutter doctor
flutter doctor -v
```

## Current Configuration
- **Bundle ID**: Check in Xcode project settings
- **App Name**: JEEVibe
- **Version**: 1.0.0+1 (update before each build)
- **Permissions**: Camera & Photo Library ✅

