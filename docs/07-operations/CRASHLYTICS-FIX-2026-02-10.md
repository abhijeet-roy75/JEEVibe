# Firebase Crashlytics Widget Lifecycle Fixes

**Date:** 2026-02-10
**Issue:** Fatal widget lifecycle crashes in production

## Problem Analysis

Three critical crash patterns were identified from Firebase Crashlytics:

### 1. InkWell MediaQuery Access During Disposal
```
FlutterError: Looking up a deactivated widget's ancestor is unsafe.
Error thrown while dispatching notifications for _HighlightModeManager.
at _InkResponseState.handleFocusHighlightModeChange
```

**Cause:** InkWell widgets attempting to access MediaQuery during widget tree teardown.

### 2. Provider.of Called on Disposed Widget
```
FlutterError: Looking up a deactivated widget's ancestor is unsafe.
at Provider.of(provider.dart:327)
at _AssessmentIntroScreenState.dispose(assessment_intro_screen.dart:111)
```

**Cause:** `_refreshChapterUnlockData()` and `_onProfileChanged()` callbacks were calling `Provider.of<AuthService>(context, listen: false)` after the widget was disposed but before listeners were removed.

### 3. setState on Defunct Widget
```
FlutterError: '_lifecycleState != _ElementLifecycle.defunct': is not true.
at State.setState
at _AssessmentIntroScreenState._loadData(assessment_intro_screen.dart:345)
```

**Cause:** Async operations in `_loadData()` completing after widget disposal. The `mounted` check alone was insufficient because the widget could become disposed **during** async operation execution.

## Solution

Added comprehensive disposal guards across all three affected screens:

### Key Changes

1. **Disposal Flag Pattern**
   ```dart
   bool _isDisposed = false;

   @override
   void dispose() {
     _isDisposed = true;
     // ... cleanup
     super.dispose();
   }
   ```

2. **Dual Check Before setState**
   ```dart
   if (!_isDisposed && mounted) {
     setState(() { ... });
   }
   ```

3. **Cached Provider References**
   ```dart
   // Store in initState to avoid context access after disposal
   AuthService? _authService;

   @override
   void initState() {
     super.initState();
     _authService = Provider.of<AuthService>(context, listen: false);
   }

   // Use cached reference instead of Provider.of
   final token = await _authService!.getIdToken();
   ```

4. **Early Returns in Callbacks**
   ```dart
   void _onProfileChanged() {
     if (_isDisposed) return;
     // ... safe to proceed
   }
   ```

5. **Timer Cancellation Guards**
   ```dart
   _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
     if (_isDisposed) {
       timer.cancel();
       return;
     }
     if (mounted) { ... }
   });
   ```

## Files Modified

### 1. assessment_intro_screen.dart
- **Lines Changed:** ~15 locations
- **Key Methods Protected:**
  - `_loadData()` - Main async data loading
  - `_refreshChapterUnlockData()` - Profile change handler
  - `_onProfileChanged()` - Listener callback
  - `_maybeRefreshData()` - App lifecycle handler
  - `didChangeAppLifecycleState()` - System callback

**Before:**
```dart
void _refreshChapterUnlockData() async {
  final authService = Provider.of<AuthService>(context, listen: false); // ❌ Unsafe
  final token = await authService.getIdToken();

  if (mounted && unlockData.isNotEmpty) { // ❌ Insufficient
    setState(() { ... });
  }
}
```

**After:**
```dart
void _refreshChapterUnlockData() async {
  if (_isDisposed || _authService == null) return; // ✅ Early exit

  final token = await _authService!.getIdToken(); // ✅ Cached reference

  if (!_isDisposed && mounted && unlockData.isNotEmpty) { // ✅ Dual check
    setState(() { ... });
  }
}
```

### 2. assessment_question_screen.dart
- **Lines Changed:** ~10 locations
- **Key Methods Protected:**
  - `_initializeAssessment()` - Async initialization
  - `_loadQuestions()` - API data fetching
  - `_recalculateRemainingTime()` - Timer callback
  - `_startTimer()` - Periodic timer
  - `_submitAssessment()` - Async submission
  - `didChangeAppLifecycleState()` - System callback

**Critical Timer Fix:**
```dart
void _startTimer() {
  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (_isDisposed) {
      timer.cancel(); // ✅ Self-canceling on disposal
      return;
    }
    if (mounted && _assessmentStartTime != null) {
      setState(() { ... });
    }
  });
}
```

### 3. chapter_list_screen.dart
- **Lines Changed:** ~8 locations
- **Key Methods Protected:**
  - `_initData()` - Async initialization
  - `_loadUnlockData()` - API data fetching
  - `_loadChaptersForSubject()` - Subject-specific loading
  - `didChangeAppLifecycleState()` - System callback

### 4. create_pin_screen.dart
- **Lines Changed:** 1 location
- **Fix:** Added disposal check before ScaffoldMessenger in error handler

### 5. profile_view_screen.dart (Crashes #7 & #8)
- **Lines Changed:** 3 locations
- **Fixes:**
  - Crash #7: Deferred profile loading to post-frame callback to avoid setState during build
  - Crash #8: Added `_isDisposed` flag and dual check before Navigator.of in `_signOut()`

### 6. trial_expired_dialog.dart (Crash #9)
- **Lines Changed:** 0 (indirect fix via AppSpacing.xxs)
- **Fix:** Spacing assertion resolved by increasing `AppSpacing.xxs` base value

### 7. app_colors.dart (Crash #9)
- **Lines Changed:** 1 location
- **Fix:** Increased `AppSpacing.xxs` from 2.0px to 2.5px (becomes 2.0px on Android, meets minimum)

### 8. chapter_practice_history_screen.dart (Crash #10)
- **Lines Changed:** 6 locations
- **Fix:** Added `_isDisposed` flag and protected all async setState calls

### 9. phone_entry_screen.dart (Crashes #11 & #14)
- **Lines Changed:** 6 locations
- **Fixes:**
  - Crash #11: Added `canPop()` check before Navigator.pop in back button
  - Crash #14: Added `_isDisposed` flag and protected Firebase Auth callbacks (verificationFailed, codeSent)
  - **Syntax fix:** Added missing closing parenthesis in codeSent callback's Navigator.push() call

### 10. assessment_intro_screen.dart (Crash #16 - RenderFlex Overflow)
- **Lines Changed:** 4 locations
- **Fix:** Reduced spacing and padding in detail chip rows to prevent 7.8px overflow on small screens
  - Reduced `SizedBox(width:)` from 6px → 4px between chips (3 locations)
  - Reduced chip horizontal padding from 8px → 6px per side
  - **Impact:** Prevents yellow overflow warning on iPhone SE and similar small screens
  - **Visual change:** Minimal (2px tighter spacing, barely noticeable)

## Testing Checklist

- [x] Code compiles without errors
- [ ] Test rapid navigation (back/forth between screens)
- [ ] Test app backgrounding during data loads
- [ ] Test device rotation during async operations
- [ ] Test network interruptions during API calls
- [ ] Monitor Crashlytics for 7 days post-deployment
- [ ] Verify no new lifecycle-related crashes

## Best Practices Established

### DO ✅
1. Always add `_isDisposed` flag for screens with async operations
2. Cache Provider references in `initState` if needed after disposal
3. Check both `!_isDisposed && mounted` before every `setState`
4. Add early returns at the start of callbacks/listeners
5. Cancel timers immediately when `_isDisposed` is detected

### DON'T ❌
1. Don't call `Provider.of(context)` in disposal-related paths
2. Don't rely solely on `mounted` check for async operations
3. Don't forget to check disposal state in app lifecycle callbacks
4. Don't leave timers running after disposal
5. Don't access context after widget is disposed

## Deployment Notes

- **Build Required:** Yes (mobile app changes only)
- **Backend Changes:** None
- **Breaking Changes:** None
- **Migration Required:** None
- **Rollback Plan:** Git revert to commit `904866e`

## Additional Fixes (Crashes #6-7)

### Crash #6: Missing Route Generator (Already Fixed)
**Error:** `Could not find a generator for route "/chapter-practice-loading"`
**Location:** `chapter_list_screen.dart:336`
**Status:** ✅ Already fixed in current codebase
**Details:** Old code used `Navigator.pushNamed()`, current code uses `Navigator.push(MaterialPageRoute(...))`. Will be resolved on deployment.

### Crash #7: setState During Build (UserProfileProvider)
**Error:** `setState() or markNeedsBuild() called during build`
**Location:** `profile_view_screen.dart:50`
**Cause:** `_ensureProfileLoaded()` called in `initState()` → `refreshProfile()` → `loadProfile()` → `notifyListeners()` during build phase
**Fix:** Defer profile loading to post-frame callback:
```dart
@override
void initState() {
  super.initState();
  _loadAppVersion();
  _loadSubscriptionStatus();
  // Defer to after frame is built
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _ensureProfileLoaded();
  });
}
```

### Crash #8: Navigator.of Called During Disposal
**Error:** `Looking up a deactivated widget's ancestor is unsafe` at `Navigator.of(context)`
**Location:** `profile_view_screen.dart:390`
**Cause:** Multiple async operations in `_signOut()` (clearing offline data, quiz state, auth signout) can complete after widget disposal. The `mounted` check alone is insufficient.
**Fix:** Added `_isDisposed` flag and dual check:
```dart
bool _isDisposed = false;

@override
void dispose() {
  _isDisposed = true;
  super.dispose();
}

Future<void> _signOut() async {
  // ... async operations (await clearUserData, clearQuizState, signOut)

  if (!_isDisposed && mounted) {  // ✅ Dual check
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }
}
```

### Crash #9: Spacing Assertion Error
**Error:** `Spacing too tight: 1.6px (from 2.0px). Minimum is 2px for readability`
**Location:** `trial_expired_dialog.dart:214`
**Cause:** `AppSpacing.xxs` (2.0px iOS) becomes 1.6px on Android after 0.80 spacing scale, violating 2px minimum.
**Fix:** Increased `AppSpacing.xxs` from 2.0px to 2.5px:
```dart
// Before
static double get xxs => PlatformSizing.spacing(2.0);  // 2.0px iOS, 1.6px Android ❌

// After
static double get xxs => PlatformSizing.spacing(2.5);  // 2.5px iOS, 2.0px Android ✅
```

### Crash #10: Null Check Operator on Disposed Widget
**Error:** `Null check operator used on a null value` at `setState`
**Location:** `chapter_practice_history_screen.dart:115`
**Cause:** Async API call completing after widget disposal, setState called on disposed widget.
**Fix:** Added `_isDisposed` flag and dual checks:
```dart
bool _isDisposed = false;

@override
void dispose() {
  _isDisposed = true;
  _scrollController.dispose();
  super.dispose();
}

// Protected all async setState calls
if (!_isDisposed && mounted) {
  setState(() { ... });
}
```

### Crash #11: Navigator.pop() with No Routes
**Error:** `Bad state: No element` at `Navigator.pop`
**Location:** `phone_entry_screen.dart:208`
**Cause:** Back button calling `Navigator.pop()` when screen is root route (no routes to pop).
**Fix:** Added `canPop()` check before pop:
```dart
// Before
onPressed: () => Navigator.of(context).pop(),

// After
onPressed: () {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
},
```

### Crash #12: Google Sign-In Native Crash (NOT FIXABLE)
**Error:** `NullPointerException` in `SignInHubActivity`
**Location:** Native Android code (Google Play Services)
**Status:** ⚠️ External library crash - cannot fix
**Details:** Crash occurs in Google Sign-In SDK native code. This is a known issue with certain Android devices/OS versions. Users should update Google Play Services.

### Crash #13: Font Size Too Small (ALREADY FIXED)
**Error:** `Font size too small: 9.68 (from 11.0)` at `PlatformSizing.fontSize`
**Location:** `profile_edit_screen.dart:468`
**Status:** ✅ Already fixed in current code
**Details:** Crash is from old deployed version. Current code uses 12px minimum (line 468: `fontSize: PlatformSizing.fontSize(12)`). Will be resolved on next deployment.

### Crash #14: ScaffoldMessenger After Disposal in OTP Flow
**Error:** `Looking up a deactivated widget's ancestor is unsafe` at `ScaffoldMessenger.of`
**Location:** `phone_entry_screen.dart:151`
**Cause:** Firebase Auth callbacks (`verificationFailed`, `codeSent`) executing after widget disposal.
**Fix:** Added `_isDisposed` flag and protected all callbacks:
```dart
bool _isDisposed = false;

@override
void dispose() {
  _isDisposed = true;
  _controller.dispose();
  super.dispose();
}

// Protected callbacks
verificationFailed: (e) {
  if (!_isDisposed && mounted) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(...);
  }
},
codeSent: (verificationId, resendToken) async {
  if (_isDisposed) return;
  // ... async operations
  if (!_isDisposed && mounted) {
    setState(() => _isLoading = false);
    Navigator.of(context).push(...);
  }
},
```

### Crash #15: Google Fonts Load Failure (NOT FIXABLE)
**Error:** `Failed to load font with url: https://fonts.gstatic.com/...`
**Location:** `google_fonts_base.dart`
**Status:** ⚠️ External network issue - cannot fix
**Details:** Crash occurs when device cannot reach Google Fonts CDN (network issue, firewall, etc.). The app should handle this gracefully by falling back to system fonts, but this is a Google Fonts package issue.

### Crash #16: RenderFlex Overflow (7.8px)
**Error:** `A RenderFlex overflowed by 7.8 pixels on the right`
**Location:** `assessment_intro_screen.dart` (detail chip rows)
**Cause:** On small screens (e.g., iPhone SE 320px width), the combination of outer padding (24px), inner padding (20px), chip padding (8px × 3), and spacing (6px × 2) caused 7.8px overflow.
**Fix:** Reduced spacing and padding:
```dart
// Before
const SizedBox(width: 6), // Between chips
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Chip padding

// After
const SizedBox(width: 4), // Reduced spacing between chips
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), // Reduced chip padding
```
**Impact:**
- Eliminates yellow overflow warning on small screens
- Visual change: Minimal (2px tighter total, barely noticeable)
- Affects 3 chip rows: Assessment card, Daily Quiz card, Mock Test card

## Monitoring

After deployment, monitor Firebase Crashlytics for:
1. Reduction in "deactivated widget ancestor" crashes
2. Reduction in "defunct lifecycle" setState crashes
3. Reduction in "route not found" errors
4. Reduction in "setState during build" errors
5. Reduction in Navigator.of disposal crashes (Crash #8)
6. Reduction in spacing assertion errors (Crash #9)
7. **Elimination of RenderFlex overflow warnings (Crash #16)**
8. Any new crash patterns introduced by changes

Expected result: **Zero widget lifecycle crashes** and **zero layout overflow warnings** in all affected screens.

## References

- Flutter Docs: [State Lifecycle](https://api.flutter.dev/flutter/widgets/State-class.html)
- Flutter Docs: [addPostFrameCallback](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addPostFrameCallback.html)
- Flutter Issue: [setState after dispose](https://github.com/flutter/flutter/issues/59525)
- Flutter Issue: [setState during build](https://github.com/flutter/flutter/issues/47502)
- Crashlytics Dashboard: [Firebase Console](https://console.firebase.google.com/project/jeevibe/crashlytics)
