# Firebase Setup Guide for JEEVibe

## Step 1: Create Firebase Account & Project

### 1.1 Sign Up for Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Get Started"** or **"Go to Console"**
3. Sign in with your Google account (or create one)
4. **Cost**: Free! (We'll use the free Spark plan)

### 1.2 Create New Project

1. Click **"Add project"** or **"Create a project"**
2. **Project name**: `JEEVibe` (or `jeevibe-app`)
3. Click **Continue**
4. **Google Analytics**: 
   - Toggle ON (recommended for tracking)
   - Click **Continue**
5. **Analytics account**: 
   - Select "Default Account for Firebase" or create new
   - Click **Create project**
6. Wait ~30 seconds for project creation
7. Click **Continue** when done

---

## Step 2: Enable Firebase Services

### 2.1 Enable Authentication

1. In Firebase Console, click **"Authentication"** in left sidebar
2. Click **"Get started"**
3. Go to **"Sign-in method"** tab
4. Click **"Phone"** provider
5. Toggle **Enable** switch
6. Click **Save**

**Important**: Phone authentication is now enabled!

### 2.2 Enable Cloud Firestore

1. Click **"Firestore Database"** in left sidebar
2. Click **"Create database"**
3. **Security rules**: Select **"Start in test mode"**
   - We'll update security rules later
   - Click **Next**
4. **Location**: Select **"asia-south1 (Mumbai)"**
   - Best for India users
   - Click **Enable**
5. Wait for database creation (~1 minute)

### 2.3 Enable Firebase Storage (Optional - for future)

1. Click **"Storage"** in left sidebar
2. Click **"Get started"**
3. **Security rules**: Click **Next** (default is fine)
4. **Location**: **"asia-south1 (Mumbai)"**
5. Click **Done**

### 2.4 Enable Firebase Analytics (Already done)

✅ Already enabled during project creation!

---

## Step 3: Add Firebase to Your Flutter App

### 3.1 Install Firebase CLI

**On Mac** (you're on Mac):
```bash
# Install Firebase CLI
curl -sL https://firebase.tools | bash

# Verify installation
firebase --version
```

**Login to Firebase**:
```bash
firebase login
```
- Browser will open
- Sign in with your Google account
- Allow Firebase CLI access

### 3.2 Install FlutterFire CLI

```bash
# Activate FlutterFire CLI
dart pub global activate flutterfire_cli

# Verify installation
flutterfire --version
```

### 3.3 Configure Firebase for Flutter

**Navigate to your project**:
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
```

**Run FlutterFire configure**:
```bash
flutterfire configure
```

**Follow prompts**:
1. **Select project**: Choose `JEEVibe` (or your project name)
2. **Select platforms**: 
   - Press **Space** to select **iOS**
   - Press **Space** to select **Android**
   - Press **Enter** to confirm
3. **iOS bundle ID**: `com.jeevibe.app` (or your bundle ID)
4. **Android package**: `com.jeevibe.app` (or your package)

**What this does**:
- Creates `firebase_options.dart` in `lib/`
- Downloads `google-services.json` for Android
- Downloads `GoogleService-Info.plist` for iOS
- Updates iOS and Android config files

---

## Step 4: Update Flutter Dependencies

### 4.1 Add Firebase Packages

**File**: `mobile/pubspec.yaml`

Add these dependencies:
```yaml
dependencies:
  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_analytics: ^10.8.0
  
  # Secure Storage (for PIN)
  flutter_secure_storage: ^9.0.0
  
  # Authentication UI
  pin_code_fields: ^8.0.1
  country_code_picker: ^3.0.0
```

**Install packages**:
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
flutter pub get
```

### 4.2 Initialize Firebase in App

**File**: `mobile/lib/main.dart`

Add Firebase initialization:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}
```

---

## Step 5: Configure iOS (Important!)

### 5.1 Update Info.plist

**File**: `mobile/ios/Runner/Info.plist`

Add these keys inside `<dict>`:
```xml
<!-- Firebase Phone Auth -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
    </array>
  </dict>
</array>
```

**Get YOUR-CLIENT-ID**:
1. Open `mobile/ios/Runner/GoogleService-Info.plist`
2. Find `REVERSED_CLIENT_ID` value
3. Copy that value (e.g., `com.googleusercontent.apps.123456789-abc`)
4. Use it in the URL scheme above

### 5.2 Update Podfile

**File**: `mobile/ios/Podfile`

Update platform version:
```ruby
platform :ios, '13.0'  # Change from 12.0 to 13.0
```

**Install pods**:
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile/ios
pod install
```

---

## Step 6: Configure Android

### 6.1 Update build.gradle (Project Level)

**File**: `mobile/android/build.gradle`

Add Google services:
```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

### 6.2 Update build.gradle (App Level)

**File**: `mobile/android/app/build.gradle`

Add at the bottom:
```gradle
apply plugin: 'com.google.gms.google-services'
```

Update minSdkVersion:
```gradle
defaultConfig {
    minSdkVersion 21  // Change from 19 to 21
}
```

Add multidex:
```gradle
dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
}
```

---

## Step 7: Test Firebase Connection

### 7.1 Create Test Screen

**File**: `mobile/lib/test_firebase.dart`

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestFirebaseScreen extends StatelessWidget {
  const TestFirebaseScreen({Key? key}) : super(key: key);

  Future<void> testFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('test')
          .doc('test_doc')
          .set({'message': 'Hello Firebase!', 'timestamp': FieldValue.serverTimestamp()});
      print('✅ Firestore write successful!');
    } catch (e) {
      print('❌ Firestore error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Firebase')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: testFirestore,
              child: const Text('Test Firestore Write'),
            ),
            const SizedBox(height: 20),
            Text('Firebase Auth: ${FirebaseAuth.instance.currentUser?.uid ?? "Not signed in"}'),
          ],
        ),
      ),
    );
  }
}
```

### 7.2 Run the App

```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile

# For iOS
flutter run -d ios

# For Android
flutter run -d android
```

**Test**:
1. Navigate to test screen
2. Click "Test Firestore Write"
3. Check console for "✅ Firestore write successful!"
4. Check Firebase Console → Firestore → `test` collection

---

## Step 8: Verify Setup in Firebase Console

### 8.1 Check Authentication

1. Go to Firebase Console → Authentication
2. Should see "Phone" enabled under Sign-in methods

### 8.2 Check Firestore

1. Go to Firebase Console → Firestore Database
2. Should see `test` collection with `test_doc` document
3. Delete test data (optional)

### 8.3 Check Project Settings

1. Click ⚙️ (Settings) → Project settings
2. **Your apps** section should show:
   - iOS app (bundle ID)
   - Android app (package name)

---

## Common Issues & Solutions

### Issue 1: "No Firebase App '[DEFAULT]' has been created"

**Solution**: Make sure `Firebase.initializeApp()` is called in `main()` before `runApp()`

### Issue 2: iOS build fails with "module 'firebase_core' not found"

**Solution**:
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
```

### Issue 3: Android build fails

**Solution**: 
- Check `minSdkVersion` is 21 or higher
- Make sure `google-services.json` is in `android/app/`
- Run `flutter clean` and rebuild

### Issue 4: Phone auth not working

**Solution**:
- Check Firebase Console → Authentication → Phone is enabled
- For iOS: Verify `CFBundleURLSchemes` in Info.plist
- For Android: Verify SHA-1 fingerprint is added (for production)

---

## Next Steps After Setup

Once Firebase is set up and tested:

1. ✅ **Remove test code** (test_firebase.dart)
2. ✅ **Start building auth screens** (Welcome, Phone Entry, OTP, etc.)
3. ✅ **Create Firebase services** (auth_service.dart, firestore_service.dart)
4. ✅ **Implement phone authentication flow**

---

## Cost Tracking

### Free Tier Limits (Spark Plan):
- **Phone Auth**: 10,000 verifications/month
- **Firestore**: 50K reads/day, 20K writes/day, 1GB storage
- **Analytics**: Unlimited
- **Storage**: 5GB (if you use it later)

**Your Usage** (estimated for 1000 users):
- Phone Auth: ~3,000/month ✅
- Firestore: ~30K reads/day, ~15K writes/day ✅
- **Total Cost**: $0/month ✅

---

## Summary Checklist

- [ ] Create Firebase account
- [ ] Create Firebase project
- [ ] Enable Authentication (Phone)
- [ ] Enable Cloud Firestore
- [ ] Install Firebase CLI
- [ ] Install FlutterFire CLI
- [ ] Run `flutterfire configure`
- [ ] Add Firebase packages to pubspec.yaml
- [ ] Initialize Firebase in main.dart
- [ ] Configure iOS (Info.plist, Podfile)
- [ ] Configure Android (build.gradle)
- [ ] Test Firebase connection
- [ ] Verify in Firebase Console

**Estimated Time**: 1-2 hours

Ready to start? Let me know if you hit any issues during setup!
