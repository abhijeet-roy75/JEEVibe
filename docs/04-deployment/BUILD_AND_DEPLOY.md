# Build and Deploy Guide - iOS & Android

This guide covers building and deploying JEEVibe to TestFlight (iOS) and Google Play Store (Android).

---

## Prerequisites

### iOS (TestFlight)
- ✅ Apple Developer Account ($99/year)
- ✅ Xcode installed (latest version)
- ✅ App registered in [App Store Connect](https://appstoreconnect.apple.com/)
- ✅ Bundle ID: `com.jeevibe.jeevibeMobile`

### Android (Play Store)
- ✅ Google Play Console account ($25 one-time fee)
- ✅ App registered in [Google Play Console](https://play.google.com/console/)
- ✅ Package name: `com.jeevibe.jeevibe_mobile`
- ✅ Upload keystore generated

---

## Version Management

Current version in `pubspec.yaml`:
```yaml
version: 1.0.0+5
```

Format: `versionName+versionCode`
- **versionName** (1.0.0): User-facing version (iOS: CFBundleShortVersionString)
- **versionCode** (5): Build number (iOS: CFBundleVersion, Android: versionCode)

**To update version:**
```yaml
version: 1.0.1+6  # Increment both for each release
```

---

## Part 1: iOS Build for TestFlight

### Step 1: Configure Xcode Project

1. **Open Xcode workspace:**
   ```bash
   cd mobile/ios
   open Runner.xcworkspace
   ```

2. **Select Runner target** → **Signing & Capabilities**
   - Team: Select your Apple Developer team
   - Bundle Identifier: `com.jeevibe.jeevibeMobile`
   - Automatically manage signing: ✅ Enabled

3. **Verify Info.plist:**
   - Display Name: `JEEVibe`
   - Bundle Identifier: `com.jeevibe.jeevibeMobile`
   - Version: Managed by Flutter (from pubspec.yaml)

### Step 2: Update Version in pubspec.yaml

```yaml
version: 1.0.0+5  # Update this before each build
```

### Step 3: Build Archive

**Option A: Using Xcode (Recommended for first build)**

1. Open `Runner.xcworkspace` in Xcode
2. Select **Any iOS Device** (not simulator) from device dropdown
3. Product → Archive
4. Wait for archive to complete
5. Window → Organizer (or Cmd+Shift+O)
6. Select your archive → **Distribute App**
7. Choose **App Store Connect**
8. Follow the wizard to upload

**Option B: Using Command Line**

```bash
cd mobile

# Clean previous builds
flutter clean
flutter pub get

# Build iOS release
flutter build ipa --release

# The .ipa file will be in: build/ios/ipa/
```

### Step 4: Upload to TestFlight

**Using Xcode Organizer:**
1. Window → Organizer
2. Select archive → **Distribute App**
3. Choose **App Store Connect**
4. Upload → Next → Upload
5. Wait for processing (10-30 minutes)

**Using Transporter App:**
1. Download [Transporter](https://apps.apple.com/app/transporter/id1450874784) from Mac App Store
2. Open Transporter → Drag `.ipa` file
3. Click **Deliver**

**Using Command Line (xcrun altool):**
```bash
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/JEEVibe.ipa \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```

### Step 5: Configure in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Select your app → **TestFlight** tab
3. Wait for processing to complete
4. Add testers (Internal/External)
5. Submit for review (if needed)

---

## Part 2: Android Build for Play Store

### Step 1: Generate Upload Keystore

**First time only - Generate keystore:**

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

**Important:**
- Store the keystore file securely (backup!)
- Remember passwords (storePassword and keyPassword)
- Keep the alias name (`upload`)

### Step 2: Configure key.properties

1. **Copy template:**
   ```bash
   cd mobile/android
   cp key.properties.template key.properties
   ```

2. **Edit `key.properties`:**
   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=/Users/abhijeetroy/upload-keystore.jks
   ```

3. **Add to .gitignore:**
   ```bash
   echo "android/key.properties" >> .gitignore
   echo "*.jks" >> .gitignore
   echo "*.keystore" >> .gitignore
   ```

### Step 3: Update Version

Update `pubspec.yaml`:
```yaml
version: 1.0.0+5  # Increment for each release
```

### Step 4: Build Release Bundle (AAB)

**Recommended for Play Store:**

```bash
cd mobile

# Clean previous builds
flutter clean
flutter pub get

# Build Android App Bundle (AAB)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

**Alternative: Build APK (for testing):**

```bash
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Step 5: Upload to Play Store

1. Go to [Google Play Console](https://play.google.com/console/)
2. Select your app
3. **Production** (or **Internal testing** / **Closed testing**)
4. **Create new release**
5. Upload `app-release.aab` file
6. Fill in release notes
7. Review and roll out

**Using Play Console CLI (optional):**
```bash
# Install Google Play Console API
pip install google-api-python-client

# Upload using fastlane or Play Console API
```

---

## Build Scripts

### iOS Build Script

Create `scripts/build_ios.sh`:

```bash
#!/bin/bash
set -e

echo "🧹 Cleaning..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🍎 Building iOS..."
flutter build ipa --release

echo "✅ Build complete! Archive location:"
echo "   build/ios/ipa/JEEVibe.ipa"
echo ""
echo "📤 Next steps:"
echo "   1. Open Xcode → Window → Organizer"
echo "   2. Select archive → Distribute App"
echo "   3. Upload to App Store Connect"
```

### Android Build Script

Create `scripts/build_android.sh`:

```bash
#!/bin/bash
set -e

echo "🧹 Cleaning..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🤖 Building Android App Bundle..."
flutter build appbundle --release

echo "✅ Build complete! AAB location:"
echo "   build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "📤 Next steps:"
echo "   1. Go to Google Play Console"
echo "   2. Upload app-release.aab"
echo "   3. Fill release notes and publish"
```

---

## Version Bump Script

Create `scripts/bump_version.sh`:

```bash
#!/bin/bash

# Usage: ./bump_version.sh [major|minor|patch]
# Example: ./bump_version.sh patch

if [ -z "$1" ]; then
  echo "Usage: ./bump_version.sh [major|minor|patch]"
  exit 1
fi

cd mobile

# Get current version
CURRENT=$(grep "^version:" pubspec.yaml | cut -d " " -f 2)
VERSION_NAME=$(echo $CURRENT | cut -d "+" -f 1)
VERSION_CODE=$(echo $CURRENT | cut -d "+" -f 2)

# Parse version parts
MAJOR=$(echo $VERSION_NAME | cut -d "." -f 1)
MINOR=$(echo $VERSION_NAME | cut -d "." -f 2)
PATCH=$(echo $VERSION_NAME | cut -d "." -f 3)

# Increment based on argument
case $1 in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "Invalid argument: $1"
    exit 1
    ;;
esac

# Increment version code
VERSION_CODE=$((VERSION_CODE + 1))

# New version
NEW_VERSION="$MAJOR.$MINOR.$PATCH+$VERSION_CODE"

# Update pubspec.yaml
sed -i '' "s/^version:.*/version: $NEW_VERSION/" pubspec.yaml

echo "✅ Version updated: $CURRENT → $NEW_VERSION"
```

---

## Troubleshooting

### iOS Issues

**"No signing certificate found"**
- Solution: Xcode → Preferences → Accounts → Add Apple ID → Download certificates

**"Bundle identifier already exists"**
- Solution: Use different bundle ID or register in App Store Connect

**"Invalid bundle"**
- Solution: Check Info.plist, ensure all required fields are set

**Archive upload fails**
- Solution: Check internet connection, try Transporter app instead

### Android Issues

**"Keystore file not found"**
- Solution: Check `key.properties` path is correct (use absolute path)

**"Keystore password incorrect"**
- Solution: Verify passwords in `key.properties` match keystore

**"Version code already used"**
- Solution: Increment version code in `pubspec.yaml`

**"AAB too large"**
- Solution: Enable ProGuard/R8, remove unused resources

---

## Pre-Release Checklist

### iOS
- [ ] Version updated in `pubspec.yaml`
- [ ] App icon set (all sizes)
- [ ] Launch screen configured
- [ ] Info.plist permissions correct
- [ ] TestFlight testers added
- [ ] App Store listing complete
- [ ] Privacy policy URL set
- [ ] Screenshots uploaded

### Android
- [ ] Version updated in `pubspec.yaml`
- [ ] Keystore configured (`key.properties`)
- [ ] App icon set
- [ ] Play Store listing complete
- [ ] Privacy policy URL set
- [ ] Screenshots uploaded
- [ ] Content rating completed
- [ ] Target audience set

### Both
- [ ] Firebase configuration correct
- [ ] API keys configured
- [ ] Analytics enabled
- [ ] Crash reporting enabled
- [ ] Tested on real devices
- [ ] All features working
- [ ] No console errors

---

## Quick Reference

### Build Commands

**iOS:**
```bash
flutter build ipa --release
```

**Android:**
```bash
flutter build appbundle --release  # For Play Store
flutter build apk --release         # For testing
```

### Version Format
```yaml
version: MAJOR.MINOR.PATCH+BUILD_NUMBER
# Example: 1.0.0+5
```

### Key Files
- iOS: `ios/Runner/Info.plist`
- Android: `android/app/build.gradle.kts`
- Version: `pubspec.yaml`
- Android Keystore: `android/key.properties` (not in git)

---

## Next Steps After First Release

1. **Set up CI/CD** (GitHub Actions, Codemagic, etc.)
2. **Automate version bumping**
3. **Set up crash reporting** (Firebase Crashlytics)
4. **Monitor analytics** (Firebase Analytics)
5. **Collect user feedback** (TestFlight, Play Console)

---

## Support

For issues:
- iOS: [Apple Developer Forums](https://developer.apple.com/forums/)
- Android: [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- Flutter: [Flutter Documentation](https://docs.flutter.dev/deployment)

