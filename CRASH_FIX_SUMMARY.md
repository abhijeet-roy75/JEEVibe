# Mobile App Crash Fix Summary

**Date:** 2026-01-26
**Issue:** User reported app crash when opening Daily Quiz

## Issues Identified

### 1. User Document Not Found (CRITICAL - App Crash)
**Root Cause:** Session creation tried to update non-existent user documents using `.update()`, which throws `NOT_FOUND` error.

**Impact:** App crashed for users who authenticated but never had their Firestore profile created.

**Fix:** Changed all user document operations in `authService.js` to use `.set({ merge: true })` instead of `.update()`.

**Files Modified:**
- `backend/src/services/authService.js` - Fixed `createSession()`, `updateLastActive()`, `clearSession()`
- `backend/src/routes/auth.js` - Removed unnecessary error handling for NOT_FOUND

### 2. Invalid Question Data (Blocking User)
**Root Cause:** Question `CHEM_PURC_E_028` has `correct_answer_exact: "C2H4O2"` (chemical formula string) instead of numeric value.

**Impact:** Users couldn't submit answers to this question, getting repeated 500 errors.

**Fix:**
- Added graceful error handling in `quizResponseService.js` - logs error for admin but doesn't block user
- Created script `backend/scripts/fix-invalid-question.js` to fix the question data
- Created `backend/QUESTION_FIXES_NEEDED.md` documentation for manual fixes

**Files Modified:**
- `backend/src/services/quizResponseService.js` - Added graceful degradation for invalid `correct_answer_exact`
- `backend/scripts/fix-invalid-question.js` - New script to fix the question
- `backend/QUESTION_FIXES_NEEDED.md` - Documentation for manual fixes

### 3. Missing Firestore Index (Non-blocking Warning)
**Root Cause:** Review questions query needed a composite index for: `student_id` + `is_correct` + `answered_at` (ASC).

**Impact:** Review questions weren't being included in daily quizzes (gracefully handled, no crash).

**Fix:**
- Added missing index to `firestore.indexes.json`
- Deployed indexes using `firebase deploy --only firestore:indexes`

**Files Modified:**
- `backend/firebase/firestore.indexes.json` - Added new composite index

### 4. No Crash Reporting (CRITICAL Gap)
**Root Cause:** App had no crash reporting mechanism. Crashes were invisible unless users reported them.

**Impact:** No visibility into production crashes or errors.

**Fix:**
- Added `firebase_crashlytics` to `pubspec.yaml`
- Integrated Crashlytics in `main.dart` with `FlutterError.onError` and `PlatformDispatcher.instance.onError`
- Updated `ErrorHandler` utility to report errors to Crashlytics
- Added error reporting in `daily_quiz_loading_screen.dart`

**Files Modified:**
- `mobile/pubspec.yaml` - Added `firebase_crashlytics: ^4.1.5`
- `mobile/lib/main.dart` - Integrated Crashlytics error handlers
- `mobile/lib/utils/error_handler.dart` - Added `reportError()` method and Crashlytics integration
- `mobile/lib/screens/daily_quiz_loading_screen.dart` - Report errors to Crashlytics

## Testing Required

### Backend
1. Test session creation for new users (user document doesn't exist)
2. Test session creation for existing users (user document exists)
3. Verify question `CHEM_PURC_E_028` no longer blocks user submissions

### Mobile
1. Install dependencies: `cd mobile && flutter pub get`
2. Verify app builds: `flutter build ios` / `flutter build apk`
3. Test daily quiz flow for new user
4. Verify crashes are reported to Firebase Crashlytics console

### Firestore
1. Verify indexes are deployed: Check Firebase Console > Firestore > Indexes
2. Verify review questions are now included in daily quizzes

## Deployment Steps

### Backend
```bash
cd backend
npm install  # If any dependencies changed
# Deploy to Render (automatic on git push to main)
```

### Mobile
```bash
cd mobile
flutter pub get
flutter clean
flutter build ios --release
flutter build apk --release
# Submit to App Store / Play Store
```

### Firestore Indexes
```bash
cd backend/firebase
firebase deploy --only firestore:indexes --project jeevibe
```
✅ **Already deployed**

## Monitoring

### Firebase Crashlytics
- Monitor: https://console.firebase.google.com/project/jeevibe/crashlytics
- Check for new crashes and errors after deployment
- Set up alerts for critical errors

### Backend Logs (Render)
- Monitor for "invalid correct_answer_exact" log entries
- Fix questions as they appear in logs

### User Reports
- Follow up with test user to confirm crash is fixed
- Monitor support channels for similar crash reports

## Future Improvements

1. **Question Validation:** Add validation script to run before uploading questions to Firestore
2. **Automated Question Fixes:** Create admin tool to bulk-fix invalid questions
3. **Better Error Messages:** Improve user-facing error messages for common failures
4. **Proactive Monitoring:** Set up alerts for high error rates or new crash patterns
5. **User Profile Creation:** Ensure profile is created atomically with authentication

## Related Documentation

- `backend/QUESTION_FIXES_NEEDED.md` - Questions that need manual fixes
- `docs/03-features/TIER-SYSTEM-ARCHITECTURE.md` - Tier system and feature gating
- Firebase Crashlytics Docs: https://firebase.google.com/docs/crashlytics

## Affected User

- User ID: `YkgWqLZA68WUG0D6fOkC4XqYVxh2`
- Issue: User profile document didn't exist in Firestore
- Status: **Fixed** - session creation will now create document if needed
