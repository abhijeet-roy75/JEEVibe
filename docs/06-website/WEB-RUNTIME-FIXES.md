# Flutter Web Runtime Fixes

**Date**: 2026-02-20
**Issue**: Web app building successfully but showing empty page when run

---

## Issues Fixed

### 1. Platform.isAndroid/Platform.isIOS on Web

**Error**: Runtime error - `dart:io` Platform class not available on web
**Location**: `main.dart:63` (_initializeScreenProtection)

**Root Cause**:
- `Platform.isAndroid` and `Platform.isIOS` from `dart:io` don't exist on web
- Code was importing `dart:io` without conditional compilation

**Solution**:
```dart
// Before
import 'dart:io' show Platform;

// After
import 'dart:io' show Platform if (dart.library.html) '';

// In _initializeScreenProtection():
Future<void> _initializeScreenProtection() async {
  // Skip on web - screen protector only works on mobile
  if (kIsWeb) {
    debugPrint('Screen protection skipped on web');
    return;
  }
  // ... rest of code
}
```

---

### 2. Firebase Background Message Handler

**Error**: Runtime error - `firebaseMessagingBackgroundHandler` not defined on web
**Location**: `main.dart:156`

**Root Cause**:
- Firebase Cloud Messaging background handlers work differently on web vs mobile
- Web uses Service Workers, mobile uses native background handlers

**Solution**:
```dart
// Before
FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

// After
if (!kIsWeb) {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}
```

---

### 3. Push Notification Service

**Error**: Runtime error - Push notification initialization fails on web
**Location**: `main.dart:774`

**Root Cause**:
- Push notifications on web require different setup (FCM web config, service workers)
- Mobile push notification service not compatible with web

**Solution**:
```dart
// Before
PushNotificationService().initialize(
  authToken,
  navigatorKey: globalNavigatorKey,
).catchError((e) {
  print('Error initializing push notifications: $e');
});

// After
if (!kIsWeb) {
  PushNotificationService().initialize(
    authToken,
    navigatorKey: globalNavigatorKey,
  ).catchError((e) {
    print('Error initializing push notifications: $e');
  });
}
```

---

## Testing the Web App

### Development Mode

```bash
# Option 1: Run with web-server (what you're using)
cd mobile
flutter run -d web-server --web-port=8080

# Open browser at: http://localhost:8080
```

```bash
# Option 2: Run with Chrome DevTools (better for debugging)
cd mobile
flutter run -d chrome

# Chrome will open automatically with Flutter DevTools
```

### What Should Work

✅ **Authentication**
- Phone number entry
- OTP verification
- Auto-login for returning users
- No PIN required on web

✅ **Core Features**
- Daily Quiz
- Chapter Practice
- Mock Tests
- Snap & Solve (with file upload instead of camera)
- AI Tutor
- Analytics
- Profile

✅ **Subscription**
- Tier detection (Free/Pro/Ultra)
- Feature gating based on tier
- Trial status display

### What Won't Work

❌ **Offline Features** (disabled on web)
- Cached solutions
- Offline quizzes
- Offline analytics

❌ **Mobile-Specific Features**
- Screen protection (screenshots allowed on web)
- Biometric authentication
- Camera (uses file picker instead)
- Push notifications (not implemented for web yet)

---

## Known Web-Specific Behaviors

### 1. Authentication Persistence

**Mobile**: Uses encrypted local storage + PIN
**Web**: Uses IndexedDB (Firebase Auth persistence) + session cookies

Users stay logged in across browser sessions (no PIN needed).

### 2. Image Upload

**Mobile**: Camera + Gallery picker
**Web**: File picker only (no camera access in current implementation)

### 3. Connectivity Detection

**Mobile**: Uses native connectivity plugins
**Web**: Uses browser `navigator.onLine` API (less reliable)

---

## Empty Page Troubleshooting

If you see an empty page:

### 1. Check Browser Console

```bash
# Run with Chrome DevTools
flutter run -d chrome

# Then check Console tab for JavaScript errors
```

### 2. Common Causes

| Issue | Solution |
|-------|----------|
| JavaScript errors | Check console, fix runtime errors |
| Firebase init failed | Check `firebase_options.dart`, verify API key |
| CORS errors | Configure backend CORS headers |
| Service worker blocked | Clear browser cache, disable extensions |
| Port conflict | Change port: `--web-port=8081` |

### 3. Clean Build

```bash
cd mobile
flutter clean
flutter pub get
flutter build web --release
flutter run -d web-server --web-port=8080
```

---

## Production Deployment

### Firebase Hosting

```bash
cd mobile
flutter build web --release

# Deploy to Firebase
firebase deploy --only hosting
```

**Required Configuration**:
- `firebase.json` with hosting config
- `.firebaserc` with project ID
- CORS configured on backend API

### Environment Variables

**Web Build**:
```bash
# Set via environment or dart-define
flutter build web --release --dart-define=API_BASE_URL=https://api.jeevibe.com
```

**Backend CORS** (`backend/.env`):
```bash
ALLOWED_ORIGINS=https://app.jeevibe.com,https://jeevibe-app.web.app
```

---

## Files Modified

| File | Change |
|------|--------|
| `mobile/lib/main.dart` | Added `kIsWeb` guards for Platform, FCM, Push Notifications |

---

## Next Steps

1. ✅ Fix web build errors → DONE
2. ✅ Fix web runtime errors → DONE
3. ⏳ Test authentication flow on web
4. ⏳ Test core features (quiz, practice, etc.)
5. ⏳ Configure backend CORS
6. ⏳ Deploy to Firebase Hosting

---

## References

- Flutter Web: https://docs.flutter.dev/platform-integration/web
- Firebase Auth Web: https://firebase.google.com/docs/auth/web/start
- Conditional Imports: https://dart.dev/guides/libraries/create-library-packages#conditionally-importing-and-exporting-library-files
