# Firebase Phone Authentication Setup Guide

## Current Status
Your app code is correctly configured for phone authentication. The restriction to test phone numbers is likely due to Firebase Console configuration, not code issues.

## Steps to Enable Phone Auth for Any Phone Number

### 1. Remove Test Phone Numbers (if configured)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **jeevibe**
3. Navigate to **Authentication** → **Sign-in method**
4. Click on **Phone** provider
5. If you see a section for **Test phone numbers**, remove all test numbers listed there
6. Test phone numbers restrict authentication to only those numbers, even on Blaze plan

### 2. Enable Phone Authentication

1. In **Authentication** → **Sign-in method**
2. Find **Phone** in the list
3. Click on it
4. Toggle **Enable** to ON
5. Click **Save**

### 3. Configure Android App Verification

For Android apps, you need to configure SHA certificate fingerprints:

**Where to add SHA certificates in Firebase Console:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **jeevibe**
3. Click the **gear icon (⚙️)** in the top left → **Project settings**
4. Scroll down to the **Your apps** section
5. Find your **Android app** (package name: `com.jeevibe.jeevibe_mobile`)
6. Click on the Android app to expand it
7. Look for the **SHA certificate fingerprints** section
8. Click **Add fingerprint** button
9. Paste your SHA-1 fingerprint → Click **Save**
10. Click **Add fingerprint** again
11. Paste your SHA-256 fingerprint → Click **Save**

**To get SHA-1 and SHA-256 fingerprints:**

```bash
# For debug keystore (development/testing)
cd mobile/android
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

This will output something like:
```
Certificate fingerprints:
     SHA1: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE
     SHA256: 11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00
```

**For release keystore (production):**
```bash
keytool -list -v -keystore /path/to/your/release.keystore -alias your-key-alias
# You'll be prompted for the keystore password
```

**After adding SHA certificates:**
1. Download the updated `google-services.json`:
   - In the same **Your apps** section, click **Download google-services.json**
2. Replace the existing file:
   - `mobile/android/app/google-services.json`
3. **Rebuild your Android app** (required after updating config file):
   ```bash
   cd mobile
   flutter clean
   flutter pub get
   flutter run
   ```

### 4. Configure iOS App Verification

For iOS apps:

1. Go to **Project Settings** → **Your apps**
2. Find your iOS app
3. Ensure your **Bundle ID** matches exactly:
   - Check in Xcode: `Runner` target → `General` tab → `Bundle Identifier`
   - It should match what's in Firebase Console
4. Download the updated `GoogleService-Info.plist` and replace:
   - `mobile/ios/Runner/GoogleService-Info.plist`
5. **Rebuild your iOS app** (required after updating config file):
   ```bash
   cd mobile
   flutter clean
   flutter pub get
   flutter run
   ```

### 5. Verify Phone Authentication is Enabled

1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Click on **Phone** provider
3. Ensure it shows **Enabled** status
4. Verify there are no test phone numbers listed (if you see any, remove them)

**Note:** App Check is a separate feature for protecting backend resources and is NOT required for phone authentication. You can skip App Check setup for now.

### 6. Check Quotas and Billing

Since you're on Blaze plan:

1. Go to **Usage and billing** in Firebase Console
2. Verify your Blaze plan is active
3. Check that **Phone Authentication** quotas are not exceeded
4. On Blaze plan, you get:
   - First 10,000 verifications/month: Free
   - After that: $0.06 per verification

### 7. Rebuild and Test

**When to rebuild:**
- ✅ **YES, rebuild required** if you:
  - Added SHA certificates and downloaded new `google-services.json`
  - Updated `GoogleService-Info.plist` for iOS
  - Made any changes to Firebase config files
  
- ❌ **NO rebuild needed** if you only:
  - Removed test phone numbers (Firebase Console setting)
  - Enabled Phone authentication (Firebase Console setting)
  - Added SHA certificates (but didn't download new config file yet)

**Rebuild commands:**
```bash
cd mobile
flutter clean
flutter pub get
# For Android
flutter run
# For iOS
flutter run -d ios
```

**After rebuilding:**

1. **Wait 5-10 minutes** for Firebase to propagate changes (if you just added SHA certificates)
2. Test with a real phone number (not in test list)
3. You should receive an SMS with verification code

## Troubleshooting

### If phone auth still doesn't work:

1. **Check error messages** in the app:
   - `operation-not-allowed`: Phone auth not enabled
   - `invalid-phone-number`: Format issue
   - `quota-exceeded`: Billing/quota issue

2. **Verify Firebase project**:
   - Ensure you're using the correct Firebase project
   - Check `mobile/lib/firebase_options.dart` matches your project

3. **Check app configuration files**:
   - Android: `mobile/android/app/google-services.json` is up to date
   - iOS: `mobile/ios/Runner/GoogleService-Info.plist` is up to date

4. **Re-download config files**:
   - Go to Firebase Console → Project Settings
   - Download latest config files for both Android and iOS
   - Replace existing files in your project

5. **Clear app data and rebuild**:
   ```bash
   cd mobile
   flutter clean
   flutter pub get
   flutter run
   ```

## Code Verification

Your code is already correct. The authentication flow in:
- `mobile/lib/services/firebase/auth_service.dart` ✅
- `mobile/lib/screens/auth/phone_entry_screen.dart` ✅
- `mobile/lib/screens/auth/otp_verification_screen.dart` ✅

All use standard Firebase Auth APIs and don't have any phone number restrictions.

## Next Steps

1. ✅ Remove test phone numbers from Firebase Console
2. ✅ Verify Phone authentication is enabled
3. ✅ Add SHA certificates for Android
4. ✅ Verify Bundle ID for iOS
5. ✅ Test with a real phone number
6. ✅ Monitor Firebase Console for any errors

## Additional Resources

- [Firebase Phone Auth Documentation](https://firebase.google.com/docs/auth/android/phone-auth)
- [Firebase Console](https://console.firebase.google.com/)
- [Troubleshooting Phone Auth](https://firebase.google.com/docs/auth/android/phone-auth#troubleshooting)
