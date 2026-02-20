# Flutter Web Build Fixes

**Date**: 2026-02-20
**Issue**: Initial `flutter build web --release` failed with compilation errors

---

## Issues Encountered

### 1. Isar Large Integer Literals (CRITICAL)

**Error**:
```
lib/models/offline/cached_solution.g.dart:18:7:
Error: The integer literal 4614895316407292546 can't be represented exactly in JavaScript.
```

**Root Cause**:
- Isar generates code with 64-bit integer literals for IDs
- JavaScript only supports integers up to 2^53 - 1 (53-bit precision)
- Isar's web support is incomplete/experimental

**Solution**:
- Disabled Isar database on web builds
- Modified `database_service.dart` to return early on web with `kIsWeb` guard
- Updated `isar` getter to throw `UnsupportedError` on web
- Offline features (cached solutions, quizzes, analytics) disabled on web

**Code Changes**:
```dart
// database_service.dart
if (kIsWeb) {
  // Web: Disable offline features (Isar doesn't fully support web)
  _isInitialized = true;
  if (kDebugMode) {
    print('DatabaseService: Skipped initialization on web (offline features disabled)');
  }
  _initCompleter?.complete();
  return;
}
```

**Impact**:
- ✅ Web build compiles successfully
- ❌ Offline mode NOT available on web
- ✅ Online features work normally
- ✅ Mobile app unaffected (still has full offline support)

---

### 2. Sentry API Signature Mismatch

**Error**:
```
lib/main.dart:87:30:
Error: A value of type 'SentryEvent? Function(SentryEvent, dynamic)' can't be assigned to a variable of type 'FutureOr<SentryEvent?> Function(SentryEvent, {Hint? hint})?'.
```

**Root Cause**:
- Sentry Flutter 7.x changed the `beforeSend` callback signature
- Old signature: `(event, hint)` (positional parameters)
- New signature: `(event, {hint})` (named parameter)

**Solution**:
Changed `beforeSend` callback to use named parameter:

```dart
// Before
options.beforeSend = (event, hint) { ... }

// After
options.beforeSend = (event, {hint}) { ... }
```

**Impact**: ✅ Sentry integration compiles successfully

---

## Final Configuration

### Offline Features Status

| Feature | Mobile | Web |
|---------|--------|-----|
| **Database (Isar)** | ✅ Enabled | ❌ Disabled |
| **Cached Solutions** | ✅ Enabled | ❌ Disabled |
| **Cached Quizzes** | ✅ Enabled | ❌ Disabled |
| **Cached Analytics** | ✅ Enabled | ❌ Disabled |
| **Image Cache** | ✅ Enabled (500 MB) | ✅ Enabled (browser cache) |
| **Connectivity Detection** | ✅ Enabled | ✅ Enabled |

**Image Caching**: Works on web via `flutter_cache_manager` (uses browser cache, not Isar)

---

## Alternative Solutions Considered

### Option 1: Use Hive instead of Isar (REJECTED)
- **Pro**: Hive has better web support
- **Con**: Would require rewriting entire offline system (~2000 lines)
- **Con**: Mobile app performance regression

### Option 2: Conditional compilation (REJECTED)
- **Pro**: Could use Isar on mobile, Hive on web
- **Con**: Maintaining two database implementations
- **Con**: Testing complexity doubles

### Option 3: Disable offline features on web (SELECTED ✅)
- **Pro**: Minimal code changes
- **Pro**: Web users typically always online
- **Pro**: Matches user expectations (web apps don't usually work offline)
- **Con**: No offline mode on web

---

## User Impact

### Free Tier
- No impact (offline mode not available on Free tier anyway)

### Pro/Ultra Tier
**Mobile**: No change - full offline mode available
**Web**:
- Cannot download solutions for offline viewing
- Cannot cache quizzes
- Must be online to use the app
- **Acceptable trade-off**: Most web users have consistent internet

---

## Future Improvements (Post-Launch)

### Option A: Implement Web-Specific Offline (Week 20+)
Use browser APIs for offline storage:
- **IndexedDB** (via `idb` package) for structured data
- **Cache API** for responses
- **Service Workers** for background sync

**Effort**: 2 weeks
**Priority**: Low (web users expect online-only)

### Option B: Wait for Isar Web Support
Monitor Isar GitHub for web support improvements:
- https://github.com/isar/isar/issues?q=is%3Aissue+is%3Aopen+web

**Effort**: 0 (just waiting)
**Priority**: Low (uncertain timeline)

---

## Runtime Fixes (2026-02-20)

After fixing build errors, the web app showed an empty page. Additional runtime fixes were needed:

### Issue 4: Platform.isAndroid/Platform.isIOS Not Available on Web

**Error**: Runtime crash - `Platform.isAndroid` undefined on web
**Fix**: Added conditional import for `dart:io` and `kIsWeb` guard in `_initializeScreenProtection()`
```dart
import 'dart:io' show Platform if (dart.library.html) '';

Future<void> _initializeScreenProtection() async {
  if (kIsWeb) {
    debugPrint('Screen protection skipped on web');
    return;
  }
  // ... rest of code
}
```

### Issue 5: Firebase Background Message Handler

**Error**: Runtime crash - `firebaseMessagingBackgroundHandler` not defined on web
**Fix**: Added `kIsWeb` guard around Firebase Messaging registration
```dart
if (!kIsWeb) {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}
```

### Issue 6: Push Notification Service

**Error**: Runtime crash - Push notification initialization fails on web
**Fix**: Disabled push notification initialization on web
```dart
if (!kIsWeb) {
  PushNotificationService().initialize(...);
}
```

**Full documentation**: See `docs/06-website/WEB-RUNTIME-FIXES.md`

---

## Testing Checklist

Before deploying web version:

- [x] Test web build compiles: `flutter build web --release`
- [x] Fix runtime errors (Platform, FCM, Push Notifications)
- [ ] Test web app loads and displays login screen
- [ ] Verify Sentry error tracking works on web
- [ ] Test authentication flow (phone + OTP)
- [ ] Confirm offline features gracefully disabled (no errors)
- [ ] Test image caching works on web
- [ ] Verify connectivity detection works
- [ ] Test all core features online (quiz, practice, mock tests)
- [ ] Verify proper error messages if user goes offline
- [ ] Configure backend CORS for web domain

---

## Lessons Learned

1. **Isar web support is experimental** - Not production-ready for large-scale apps
2. **JavaScript integer limitations** - 53-bit precision vs Dart's 64-bit
3. **Web vs mobile trade-offs** - Not all mobile features translate to web
4. **Package compatibility** - Always check web support in pubspec dependencies
5. **Error tracking API changes** - Sentry signatures changed between versions

---

## References

- Isar Web Support: https://isar.dev/web.html
- JavaScript Number Limits: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number
- Sentry Flutter Migration: https://docs.sentry.io/platforms/flutter/migration/
- Flutter Cache Manager Web: https://pub.dev/packages/flutter_cache_manager#web-support
