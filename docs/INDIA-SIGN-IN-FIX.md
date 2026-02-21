# India Sign-In Error Fix

**Error**: "Verification Failed: Hostname match not found"
**When**: User in India trying to sign in with phone number
**Works**: Sign-in works from US

## Root Cause

This error occurs when Firebase API key restrictions block requests that don't match registered app signatures.

## Immediate Fix

### Option 1: Remove API Key Restrictions (QUICKEST - For Testing)

1. Go to **Google Cloud Console**: https://console.cloud.google.com/apis/credentials?project=jeevibe
2. Click on API key: `AIzaSyDcXazgUQe2MAp1xAtEtGC-OXhF-Y9UYjc`
3. Under **Application restrictions**:
   - Change from "Android apps" or "iOS apps" → **None** (temporarily)
4. Click **Save**
5. Wait 1-2 minutes for propagation
6. Ask Indian tester to retry

**⚠️ WARNING**: This removes security restrictions. Use only for testing!

---

### Option 2: Add App SHA-1 Fingerprint (PROPER FIX for Android)

#### Step 1: Get SHA-1 from Indian Tester's Device

Ask the tester to run:
```bash
cd android
./gradlew signingReport
```

Or generate from debug keystore:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### Step 2: Register SHA-1 in Firebase

1. Go to **Firebase Console**: https://console.firebase.google.com/project/jeevibe/settings/general
2. Scroll to **Your apps** → **Android app**
3. Click **Add fingerprint**
4. Paste the SHA-1 hash
5. Click **Save**

#### Step 3: Download new google-services.json

1. Click **Download google-services.json**
2. Replace `/Users/abhijeetroy/Documents/JEEVibe/mobile/android/app/google-services.json`
3. Rebuild app: `flutter clean && flutter build apk --release`
4. Send new APK to tester

---

### Option 3: Fix API Key Restrictions (PROPER FIX for Production)

#### Step 1: Check Current Restrictions

1. Go to **Google Cloud Console**: https://console.cloud.google.com/apis/credentials?project=jeevibe
2. Click on the API key
3. Note current **Application restrictions**

#### Step 2: Add All Valid App Signatures

**For Android:**
1. Under **Application restrictions** → **Android apps**
2. Click **Add an item**
3. Enter:
   - **Package name**: `com.jeevibe.jeevibe_mobile`
   - **SHA-1 fingerprint**: (from Step 2.1 above)

**For iOS:**
1. Under **Application restrictions** → **iOS apps**
2. Click **Add an item**
3. Enter **Bundle ID**: `com.jeevibe.jeevibeMobile`

#### Step 3: Add API Restrictions (Optional Security)

1. Under **API restrictions** → **Restrict key**
2. Select:
   - ✅ **Firebase Authentication API**
   - ✅ **Cloud Firestore API**
   - ✅ **Cloud Storage for Firebase API**
   - ✅ **Identity Toolkit API**
3. Click **Save**

---

## Verification Steps

After applying fix:

1. **Ask Indian tester to**:
   - Clear app data: `Settings → Apps → JEEVibe → Clear data`
   - Uninstall and reinstall app (if using Option 2)
   - Try sign-in again

2. **Monitor Firebase logs**:
   - Go to **Firebase Console** → **Authentication** → **Users**
   - Check if new user appears after successful sign-in

3. **Check API usage**:
   - Go to **Google Cloud Console** → **APIs & Services** → **Credentials**
   - Check API key usage metrics (should show requests from India)

---

## Why This Happens

**Geographic Difference**:
- US tester: Likely using same development environment/keystore as you
- India tester: Using different device, possibly with different app signature

**Debug vs Release**:
- Debug builds use `debug.keystore` (SHA-1: one value)
- Release builds use `upload.keystore` or Play Store signing (SHA-1: different value)
- If Indian tester has release build but SHA-1 not registered → error

**Firebase Restrictions**:
- Firebase API keys can be restricted by:
  - App signature (SHA-1 for Android, Bundle ID for iOS)
  - IP address (geo-blocking)
  - Referrer (web only)

---

## Quick Diagnostic Commands

### Check if API key is restricted:
```bash
curl -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=AIzaSyDcXazgUQe2MAp1xAtEtGC-OXhF-Y9UYjc" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected**:
- If unrestricted: Returns error about missing phone number
- If restricted: Returns "API key not valid" or "Hostname match not found"

### Get SHA-1 from APK (if tester sends APK):
```bash
unzip -p app-release.apk META-INF/CERT.RSA | keytool -printcert | grep SHA1
```

---

## Long-Term Solution

### 1. Use Firebase App Distribution
- Distribute builds via Firebase App Distribution
- Automatically registers all test devices
- No SHA-1 issues

### 2. Use Play Store Internal Testing
- Google Play handles app signing
- Single SHA-1 for all users
- Register Play Store SHA-1 in Firebase

### 3. Enable App Check (Advanced)
- Go to **Firebase Console** → **App Check**
- Register app with SafetyNet (Android) or App Attest (iOS)
- Provides device-level verification instead of API key restrictions

---

## Immediate Action Plan

**Right now (5 minutes)**:
1. Remove API key restrictions (Option 1)
2. Ask India tester to retry
3. If works → confirms issue is API key restrictions

**Short-term (1 hour)**:
1. Get SHA-1 from Indian tester
2. Register in Firebase (Option 2)
3. Rebuild and redistribute app

**Long-term (before launch)**:
1. Set up proper API key restrictions (Option 3)
2. Register all device signatures
3. Enable App Check for production security

---

## Contact

If issue persists after trying all options:
1. Check **Firebase Console** → **Authentication** → **Sign-in method** → **Phone** is enabled
2. Check **Firebase Console** → **Authentication** → **Settings** → **Authorized domains** includes your domain
3. Check Firebase quotas (shouldn't be issue for new project)

**Firebase Support**: https://firebase.google.com/support

---

**Last Updated**: 2026-02-21
**Status**: Awaiting fix confirmation from India tester
