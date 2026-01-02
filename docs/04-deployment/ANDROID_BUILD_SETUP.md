# Android Build Setup Guide for JEEVibe

This guide covers setting up the Android build configuration, generating signing keys, building the app, and deploying to Google Play Console.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [App Signing Configuration](#app-signing-configuration)
4. [Building the App](#building-the-app)
5. [Testing](#testing)
6. [Google Play Console Deployment](#google-play-console-deployment)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

- Flutter SDK installed and configured
- Android Studio installed (for emulator and tools)
- Java JDK 17 or higher
- Google Play Console account with developer access
- Android SDK installed (via Android Studio)

Verify Flutter setup:
```bash
flutter doctor
```

## Initial Setup

The Android project is already configured with:
- ✅ Required permissions (camera, internet, storage)
- ✅ App metadata (name: "JEEVibe", bundle ID: `com.jeevibe.jeevibe_mobile`)
- ✅ Build configuration
- ✅ Signing configuration structure

### Verify Configuration

Check that the following files are properly configured:

1. **AndroidManifest.xml** (`mobile/android/app/src/main/AndroidManifest.xml`)
   - App label: "JEEVibe"
   - Permissions: CAMERA, INTERNET, storage permissions

2. **build.gradle.kts** (`mobile/android/app/build.gradle.kts`)
   - Application ID: `com.jeevibe.jeevibe_mobile`
   - Signing configuration ready

## App Signing Configuration

### Google Play App Signing

This project uses **Google Play App Signing**, which means:
- Google manages your production signing key (more secure)
- You only need to create an **upload key** for signing your releases
- If you lose your upload key, Google can reset it (unlike production keys)

### Step 1: Generate Upload Keystore

1. Open Terminal and navigate to your home directory (or preferred secure location):
```bash
cd ~
```

2. Generate the upload keystore:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

3. You'll be prompted for:
   - **Keystore password**: Create a strong password (save it securely!)
   - **Key password**: Use the same password or create a different one (save it!)
   - **Name, Organization, etc.**: Enter your details (these can be changed later)

4. **IMPORTANT**: Save the keystore file and passwords in a secure location (password manager, encrypted backup, etc.)

### Step 2: Configure key.properties

1. Copy the template file:
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile/android
cp key.properties.template key.properties
```

2. Edit `key.properties` and fill in your keystore information:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/abhijeetroy/upload-keystore.jks
```

**Note**: Update the `storeFile` path to match where you saved your keystore.

3. Verify that `key.properties` is in `.gitignore` (it should be automatically ignored)

### Step 3: Verify Signing Configuration

The `build.gradle.kts` file is already configured to:
- Load `key.properties` if it exists
- Use the upload keystore for release builds
- Fall back to debug signing if `key.properties` doesn't exist (for development)

## Building the App

### Debug Build (for testing)

Build a debug APK:
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Release Build (for Play Store)

#### Option 1: Build APK (for direct installation/testing)
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

#### Option 2: Build App Bundle (required for Google Play)
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

**Note**: Google Play requires `.aab` (Android App Bundle) format, not `.apk`.

### Version Management

Version is managed in `pubspec.yaml`:
```yaml
version: 1.0.0+3
```

Format: `versionName+versionCode`
- `1.0.0` = version name (user-visible)
- `3` = version code (must increment with each release)

To update version:
1. Edit `pubspec.yaml`
2. Increment version code for each release
3. Update version name as needed (e.g., `1.0.1+4`)

## Testing

### Option 1: Android Emulator

1. **Set up Android Emulator**:
   - Open Android Studio
   - Go to Tools → Device Manager
   - Create a new virtual device (recommended: Pixel 5 or similar, API 33+)
   - Start the emulator

2. **Run the app**:
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
flutter run
```

3. **Test release build**:
```bash
flutter run --release
```

### Option 2: Google Play Internal Testing

You can upload to Google Play Internal Testing track without a physical device:

1. Build the app bundle:
```bash
flutter build appbundle --release
```

2. Upload to Google Play Console (see [Deployment](#google-play-console-deployment) section)

3. Add yourself as a tester in Play Console

4. Install from Play Store link (even without a physical device, you can test on emulator)

## Google Play Console Deployment

### Initial Setup (First Time Only)

1. **Create App in Play Console**:
   - Go to [Google Play Console](https://play.google.com/console)
   - Click "Create app"
   - Fill in app details:
     - App name: "JEEVibe"
     - Default language: English
     - App or game: App
     - Free or paid: Free
   - Accept declarations

2. **Set up Google Play App Signing**:
   - Go to Release → Setup → App signing
   - Choose "Let Google manage and protect your app signing key" (recommended)
   - Upload your upload certificate (from your keystore)
   - Google will generate the production key

3. **Upload Upload Certificate**:
   - Extract certificate from your keystore:
   ```bash
   keytool -export -rfc -keystore ~/upload-keystore.jks -alias upload -file upload_certificate.pem
   ```
   - Upload `upload_certificate.pem` to Play Console

### Uploading a Release

1. **Build the App Bundle**:
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
flutter build appbundle --release
```

2. **Upload to Play Console**:
   - Go to Play Console → Your App → Release → Testing → Internal testing
   - Click "Create new release"
   - Upload `build/app/outputs/bundle/release/app-release.aab`
   - Fill in release notes
   - Review and roll out

3. **Add Testers**:
   - Go to Testing → Internal testing → Testers
   - Add email addresses or create a testers list
   - Share the opt-in link with testers

### Production Release

Once testing is complete:

1. Go to Release → Production
2. Create new release
3. Upload the same `.aab` file
4. Complete store listing (screenshots, description, etc.)
5. Submit for review

## Troubleshooting

### Build Errors

**Error: "key.properties not found"**
- Solution: Create `key.properties` from template (see [App Signing Configuration](#app-signing-configuration))
- For debug builds, this is optional (uses debug signing)

**Error: "Keystore file not found"**
- Solution: Check the `storeFile` path in `key.properties`
- Use absolute path (e.g., `/Users/abhijeetroy/upload-keystore.jks`)

**Error: "Wrong password"**
- Solution: Verify passwords in `key.properties` match your keystore
- Re-check keystore password and key password

### Permission Issues

**Camera not working on Android**
- Verify `CAMERA` permission is in `AndroidManifest.xml` (already added)
- Check runtime permissions are requested in code (Flutter plugins handle this)

**Storage access issues**
- Android 10+ uses scoped storage
- Permissions are already configured for Android 10-13
- For Android 14+, `READ_MEDIA_IMAGES` is used (already added)

### Version Code Conflicts

**Error: "Version code already used"**
- Solution: Increment version code in `pubspec.yaml`
- Format: `version: 1.0.0+4` (increment the number after `+`)

### Google Play Console Issues

**Upload certificate mismatch**
- If you lose your upload key, Google can reset it (with Google Play App Signing)
- Contact Google Play support if needed

**App bundle validation errors**
- Ensure you're uploading `.aab` file, not `.apk`
- Check that version code is higher than previous release
- Verify all required store listing information is complete

## Quick Reference Commands

```bash
# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Build release App Bundle (for Play Store)
flutter build appbundle --release

# Run on connected device/emulator
flutter run

# Run release build
flutter run --release

# Check Flutter setup
flutter doctor

# Clean build
flutter clean
flutter pub get
```

## Security Notes

- **Never commit `key.properties` or keystore files to git** (already in `.gitignore`)
- **Back up your upload keystore** in multiple secure locations
- **Use a password manager** to store keystore passwords
- **Enable Google Play App Signing** for added security (production key managed by Google)

## Next Steps

1. Generate upload keystore
2. Create `key.properties` file
3. Build release app bundle
4. Upload to Google Play Console Internal Testing
5. Test on emulator or via Play Store link
6. Iterate and improve
7. Submit for production release when ready

## Additional Resources

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Google Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Android App Bundle](https://developer.android.com/guide/app-bundle)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)

