# How to Get Firebase ID Token for Testing

## Option 1: From Flutter App (Recommended)

### Step 1: Navigate to Flutter App Directory

```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
```

### Step 2: Run Flutter App

**On iOS Simulator:**
```bash
flutter run
```

**On Physical Device:**
```bash
flutter run -d <device-id>
```

**List available devices:**
```bash
flutter devices
```

### Step 3: Get Token from App

You can add a temporary debug button or print statement to get the token:

**Option A: Add to existing screen (temporary)**

Add this to any screen where user is logged in:

```dart
import 'package:firebase_auth/firebase_auth.dart';

// In your widget or service
Future<void> printToken() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    String? token = await user.getIdToken();
    print('🔑 Firebase ID Token:');
    print(token);
    // Copy this token for testing
  }
}
```

**Option B: Use Flutter DevTools**

1. Run app: `flutter run`
2. Open DevTools: Press `d` in terminal or go to `http://localhost:9100`
3. Check console logs for token

**Option C: Add temporary debug route**

Create a simple test screen that shows the token:

```dart
// In your Flutter app, create a test screen
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TokenTestScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Get Token')),
      body: FutureBuilder<String?>(
        future: FirebaseAuth.instance.currentUser?.getIdToken(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Firebase ID Token:', 
                       style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  SelectableText(
                    snapshot.data!,
                    style: TextStyle(fontSize: 12),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Copy to clipboard
                    },
                    child: Text('Copy Token'),
                  ),
                ],
              ),
            );
          }
          return CircularProgressIndicator();
        },
      ),
    );
  }
}
```

---

## Option 2: Use Firebase Admin SDK (Backend Script)

Create a simple script to generate a test token:

```bash
cd /Users/abhijeetroy/Documents/JEEVibe/backend
```

Create `scripts/get-test-token.js`:

```javascript
const { admin } = require('../src/config/firebase');

async function getTestToken() {
  // Get or create test user
  const email = 'test@jeevibe.com';
  let user;
  
  try {
    user = await admin.auth().getUserByEmail(email);
  } catch (error) {
    user = await admin.auth().createUser({
      email: email,
      password: 'TestPassword123!',
      emailVerified: true
    });
  }
  
  // Create custom token (can be exchanged for ID token)
  const customToken = await admin.auth().createCustomToken(user.uid);
  console.log('Custom Token:', customToken);
  console.log('\nNote: Exchange this custom token for ID token using Firebase Auth REST API');
  console.log('Or use it directly if your backend accepts custom tokens');
}

getTestToken();
```

**Run:**
```bash
node scripts/get-test-token.js
```

---

## Option 3: Use Firebase Console + REST API

1. **Go to Firebase Console** → Authentication → Users
2. **Create a test user** (or use existing)
3. **Get User UID** from the user list
4. **Use Firebase Admin SDK** to create custom token (see Option 2)

---

## Option 4: Quick Test Without Token (Limited)

You can test the authentication middleware:

```bash
# Should return 401
curl http://localhost:3000/api/assessment/questions
```

This confirms authentication is working, but you won't be able to test the full flow without a token.

---

## Recommended Workflow

1. **Run Flutter app:**
   ```bash
   cd /Users/abhijeetroy/Documents/JEEVibe/mobile
   flutter run
   ```

2. **Sign in to the app** (phone auth or your auth method)

3. **Add temporary debug code** to print token (see Option 1 above)

4. **Copy the token** from console/logs

5. **Test API:**
   ```bash
   cd /Users/abhijeetroy/Documents/JEEVibe/backend
   curl -X GET "http://localhost:3000/api/assessment/questions" \
     -H "Authorization: Bearer YOUR_TOKEN_HERE"
   ```

---

## Quick Reference: Flutter Commands

**All commands run from:** `/Users/abhijeetroy/Documents/JEEVibe/mobile`

```bash
# Check Flutter installation
flutter doctor

# List devices
flutter devices

# Run on iOS Simulator
flutter run

# Run on specific device
flutter run -d <device-id>

# Hot reload (press 'r' while app is running)
# Hot restart (press 'R' while app is running)
# Quit (press 'q' while app is running)

# Check for errors
flutter analyze

# Get dependencies
flutter pub get
```

---

## Troubleshooting

### "No devices found"
- **iOS**: Open Simulator: `open -a Simulator`
- **Android**: Start Android Emulator from Android Studio

### "Flutter not found"
- Install Flutter: https://flutter.dev/docs/get-started/install
- Add to PATH: `export PATH="$PATH:/path/to/flutter/bin"`

### "Token expired"
- Tokens expire after 1 hour
- Get a fresh token from the app

### "User not authenticated"
- Make sure user is signed in to Firebase Auth
- Check `FirebaseAuth.instance.currentUser` is not null
