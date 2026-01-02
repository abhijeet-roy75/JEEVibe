# Fix Android Firebase Phone Auth SHA Certificate Error

## Problem
Error: "A play_integrity_token was passed, but no matching SHA-256 was registered in the Firebase console."

This happens when the SHA-256 certificate of the keystore used to sign your app doesn't match what's registered in Firebase Console.

## Solution: Add Both Debug AND Release SHA Certificates

You need to add SHA certificates for **both** the debug keystore (for development/testing) and the release keystore (for production builds).

### Step 1: Get Debug Keystore SHA Certificates

For development and testing (when running `flutter run`):

```bash
cd mobile/android
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Look for:
- **SHA1:** `XX:XX:XX:...`
- **SHA256:** `XX:XX:XX:...`

### Step 2: Get Release Keystore SHA Certificates

If you have a release keystore configured:

```bash
# Replace with your actual keystore path and alias
keytool -list -v -keystore ~/upload-keystore.jks -alias upload
# You'll be prompted for the keystore password
```

Or if you're using a different keystore, check your `android/key.properties` file for the `storeFile` path.

### Step 3: Add ALL SHA Certificates to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **jeevibe**
3. Click **⚙️ Project Settings** → **Your apps**
4. Find your **Android app** (`com.jeevibe.jeevibe_mobile`)
5. In **SHA certificate fingerprints** section:
   - Click **Add fingerprint**
   - Add the **SHA-1** from debug keystore
   - Click **Add fingerprint** again
   - Add the **SHA-256** from debug keystore
   - Click **Add fingerprint** again
   - Add the **SHA-1** from release keystore (if you have one)
   - Click **Add fingerprint** again
   - Add the **SHA-256** from release keystore (if you have one)

**Important:** You should have at least 4 fingerprints total:
- Debug SHA-1
- Debug SHA-256
- Release SHA-1 (if using release keystore)
- Release SHA-256 (if using release keystore)

### Step 4: Download Updated google-services.json

**CRITICAL:** After adding SHA certificates, you MUST download the updated config file:

1. In Firebase Console, still in **Project Settings** → **Your apps** → Android app
2. Click **Download google-services.json**
3. Replace the existing file:
   ```bash
   # Backup the old one first (optional)
   cp mobile/android/app/google-services.json mobile/android/app/google-services.json.backup
   
   # Replace with the new one
   # (Copy the downloaded file to mobile/android/app/google-services.json)
   ```

### Step 5: Rebuild the App

After updating `google-services.json`:

```bash
cd mobile
flutter clean
flutter pub get
flutter run
```

## Quick Check: Which Keystore is Being Used?

To check which keystore your app is currently using:

```bash
cd mobile/android
# Check if key.properties exists
ls -la key.properties

# If it exists, check what keystore it points to
cat key.properties | grep storeFile
```

- **If `key.properties` exists:** App is using release keystore → Add release SHA to Firebase
- **If `key.properties` doesn't exist:** App is using debug keystore → Add debug SHA to Firebase
- **Best practice:** Add BOTH to Firebase so it works in both scenarios

## Common Scenarios

### Scenario 1: Testing on Physical Device (Debug Build)
- App is signed with **debug keystore**
- Need **debug SHA-1 and SHA-256** in Firebase
- Get them with: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`

### Scenario 2: Testing Release Build Locally
- App is signed with **release keystore** (from `key.properties`)
- Need **release SHA-1 and SHA-256** in Firebase
- Get them from your release keystore

### Scenario 3: App from Play Store
- App is signed with **Play App Signing** certificate (different from upload keystore)
- Need to get SHA from **Play Console**:
  1. Go to Google Play Console
  2. Your app → **Release** → **Setup** → **App signing**
  3. Copy the **SHA-1** and **SHA-256** from "App signing key certificate"
  4. Add them to Firebase

## Verify Your Setup

After adding SHA certificates and updating `google-services.json`:

1. **Wait 5-10 minutes** for Firebase to propagate changes
2. **Clean rebuild:**
   ```bash
   cd mobile
   flutter clean
   flutter pub get
   flutter run
   ```
3. Test phone authentication again

## Still Not Working?

1. **Double-check package name matches:**
   - Firebase Console: `com.jeevibe.jeevibe_mobile`
   - Your app: Check `mobile/android/app/build.gradle.kts` → `applicationId`

2. **Verify google-services.json is up to date:**
   - Check the file modification time
   - Re-download from Firebase Console if unsure

3. **Check if you're using the correct keystore:**
   - Run: `cd mobile/android && cat key.properties` (if exists)
   - Verify the keystore path matches where you got the SHA from

4. **Try adding SHA from Play Console** (if app is published):
   - Play Console → App → Release → Setup → App signing
   - Copy SHA certificates from there

## Summary Checklist

- [ ] Added debug keystore SHA-1 to Firebase
- [ ] Added debug keystore SHA-256 to Firebase
- [ ] Added release keystore SHA-1 to Firebase (if using release keystore)
- [ ] Added release keystore SHA-256 to Firebase (if using release keystore)
- [ ] Downloaded updated `google-services.json` from Firebase Console
- [ ] Replaced `mobile/android/app/google-services.json` with new file
- [ ] Ran `flutter clean` and rebuilt the app
- [ ] Waited 5-10 minutes for Firebase to propagate changes
