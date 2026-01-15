# Tier System & Feature Gating Review

**Date**: 2026-01-15  
**Status**: ✅ Review Complete - Critical Issue Fixed, Display Strings Updated

## Overview

This document reviews the implementation of the tier system (FREE, PRO, ULTRA) and feature gating across the mobile app and backend to identify any issues, inconsistencies, or potential bugs.

---

## ✅ What's Working Correctly

### 1. **Backend Tier Resolution**
- ✅ `getEffectiveTier()` correctly prioritizes: Override → Subscription → Trial → Free
- ✅ Proper validation of override tier_id (only 'pro' or 'ultra')
- ✅ Safe date parsing with fallbacks
- ✅ Error handling with safe fallback to free tier

### 2. **Backend Feature Gating**
- ✅ `checkUsageLimit()` middleware properly enforces limits
- ✅ Snap & Solve: Uses `incrementUsage('snap_solve')` in `/api/solve`
- ✅ Daily Quiz: Uses `incrementUsage('daily_quiz')` in `/api/daily-quiz/generate`
- ✅ Returns proper 429 status with usage info when limit reached
- ✅ Handles unlimited (-1) correctly

### 3. **Subscription Service (Mobile)**
- ✅ Proper caching (5-minute TTL)
- ✅ `canUse()`, `getRemainingUses()` methods work correctly
- ✅ `gatekeepFeature()` shows paywall when limit reached
- ✅ `isOfflineEnabled` correctly reads from `limits.offlineEnabled`
- ✅ `hasFullAnalytics` correctly reads from `features.analyticsAccess`

### 4. **Offline Access Gating**
- ✅ `OfflineProvider.offlineEnabled` is set from subscription status
- ✅ Initialized correctly in `main.dart` after fetching subscription status
- ✅ Automatic caching only happens if `offlineEnabled == true`
- ✅ Sync only triggers if `offlineEnabled == true`

### 5. **Analytics Gating**
- ✅ Uses `hasFullAnalytics` from subscription service
- ✅ Correctly shows/hides features based on tier
- ✅ Backend config: Free = 'basic', Pro/Ultra = 'full'

---

## 🐛 Issues Found

### **CRITICAL: Unlimited Snap Access Not Handled**

**Location**: `mobile/lib/providers/app_state_provider.dart`

**Issue**: The `canTakeSnap` getter doesn't handle unlimited users correctly.

```dart
bool get canTakeSnap => snapsRemaining > 0;
```

**Problem**: 
- For unlimited users (Ultra tier), `_snapLimit` is set to `-1`
- `snapsRemaining = -1 - _snapsUsed` = negative number
- `snapsRemaining > 0` returns `false` for unlimited users
- **Result**: Ultra tier users are incorrectly blocked from taking snaps
- **Note**: Pro tier gets 10 snaps/day (not unlimited), so this only affects Ultra

**Fix Required**:
```dart
bool get canTakeSnap {
  if (_snapLimit == -1) return true; // Unlimited
  return snapsRemaining > 0;
}
```

**Impact**: HIGH - Pro/Ultra users cannot use Snap & Solve feature

---

### **MEDIUM: Snap Limit Check Inconsistency**

**Location**: `mobile/lib/screens/home_screen.dart` - `_checkSnapAccess()`

**Issue**: The method checks `appState.canTakeSnap` but also uses subscription service. There's potential for inconsistency.

**Current Flow**:
1. Checks `appState.canTakeSnap` (local state)
2. If false, shows daily limit screen
3. Also checks subscription service via `gatekeepFeature()`

**Potential Issue**: 
- If local state is stale, user might see incorrect UI
- However, backend will still enforce the limit, so this is mostly a UX issue

**Recommendation**: 
- Ensure `appState` is refreshed before checking
- Or rely more on subscription service for client-side checks

---

### **MEDIUM: Offline Access Initialization Race Condition**

**Location**: `mobile/lib/main.dart` - `_checkLoginStatus()`

**Issue**: Offline provider is initialized with `offlineEnabled: false` in `assessment_intro_screen.dart` before subscription status is fetched.

**Current Flow**:
1. `AppInitializer` initializes offline provider with `offlineEnabled: false`
2. Later, subscription status is fetched and `offlineEnabled` is updated
3. But there's a window where offline features might not work

**Code**:
```dart
// In assessment_intro_screen.dart (line 88-89)
await offlineProvider.initialize(user.uid, offlineEnabled: false);
```

**Fix**: This is actually handled correctly - `offlineEnabled` is updated later when subscription status is fetched. However, the initial `false` value is correct as a safe default.

**Status**: ✅ Actually working correctly, but could be clearer

---

### **LOW: Hardcoded Default Limits**

**Location**: `mobile/lib/models/subscription_models.dart`

**Issue**: Default values in `TierLimits.fromJson()` might not match backend defaults.

**Current Defaults**:
```dart
snapSolveDaily: json['snap_solve_daily'] ?? 5,
dailyQuizDaily: json['daily_quiz_daily'] ?? 1,
```

**Backend Defaults** (from `tierConfigService.js`):
- Free: snap_solve_daily: 5, daily_quiz_daily: 1 ✅ Matches
- Pro: snap_solve_daily: 10, daily_quiz_daily: 10
- Ultra: snap_solve_daily: -1, daily_quiz_daily: -1

**Status**: ✅ Defaults match, but these should never be used if backend is working correctly

---

### **LOW: Missing Tier Check in Some Places**

**Location**: Various screens

**Issue**: Some screens check `isFree` or `currentTier` directly instead of using feature flags.

**Examples**:
- `profile_view_screen.dart`: Checks `tierEnum == SubscriptionTier.free` directly
- `analytics_screen.dart`: Uses `_hasFullAnalytics` (correct)

**Recommendation**: 
- Prefer using feature flags (`hasFullAnalytics`, `isOfflineEnabled`) over direct tier checks
- This makes it easier to change feature availability without code changes

**Status**: ⚠️ Works but not ideal for maintainability

---

## 📋 Recommendations

### 1. **Fix Unlimited Snap Access (CRITICAL)**
   - Update `AppStateProvider.canTakeSnap` to handle `-1` limit
   - Test with Pro/Ultra users to verify unlimited access works

### 2. **Add Tier Validation Tests**
   - Test that Free users are blocked at correct limits
   - Test that Pro users get 10 snaps/quizzes
   - Test that Ultra users get unlimited access
   - Test offline access only works for Pro/Ultra

### 3. **Improve Error Messages**
   - When limit reached, show tier-specific upgrade messages
   - For Pro users hitting limit, suggest Ultra upgrade
   - For Free users, show Pro benefits

### 4. **Add Feature Flag Consistency**
   - Create a centralized feature flag service
   - Use feature flags instead of direct tier checks where possible
   - Makes A/B testing and gradual rollouts easier

### 5. **Document Tier Limits**
   - Create a single source of truth for tier limits
   - Document in code comments what each tier gets
   - Keep mobile and backend in sync

---

## 🔍 Additional Checks Performed

### Backend Tier Config
- ✅ Free: 5 snaps/day, 1 quiz/day, basic analytics, no offline
- ✅ Pro: 10 snaps/day, 10 quizzes/day, full analytics, offline enabled
- ✅ Ultra: Unlimited snaps (-1), unlimited quizzes (-1), full analytics, offline enabled

### Mobile Tier Checks
- ✅ Subscription service correctly reads tier from API
- ✅ Offline provider correctly reads `offlineEnabled` flag
- ✅ Analytics screen correctly checks `hasFullAnalytics`
- ⚠️ Snap access check has bug (see CRITICAL issue above)

### Feature Gating Flow
1. **Client-side**: Fast UX check (can show paywall immediately)
2. **Backend**: Security enforcement (prevents bypass)
3. ✅ Both layers working correctly (except snap unlimited bug)

---

## ✅ Summary

**Total Issues Found**: 4
- **CRITICAL**: 1 (unlimited snap access)
- **MEDIUM**: 2 (snap check inconsistency, initialization timing)
- **LOW**: 1 (hardcoded defaults, tier check patterns)

**Overall Assessment**: 
- Tier system architecture is solid ✅
- Backend enforcement is correct ✅
- Mobile implementation has one critical bug that needs immediate fix ⚠️
- Feature gating logic is mostly consistent ✅

**Priority Actions**:
1. ✅ **FIXED**: `canTakeSnap` now handles unlimited users correctly
2. ✅ **FIXED**: Display strings now show "Unlimited" or "∞" instead of "-1/-1"
3. **SOON**: Add tests for tier-based feature gating
4. **NICE TO HAVE**: Refactor to use feature flags more consistently

---

## ✅ Fixes Applied

### Fix 1: Unlimited Snap Access (CRITICAL)
**File**: `mobile/lib/providers/app_state_provider.dart`

**Changes**:
- Updated `snapsRemaining` getter to return `-1` for unlimited users
- Updated `canTakeSnap` to return `true` when `_snapLimit == -1`

**Code**:
```dart
int get snapsRemaining => _snapLimit == -1 ? -1 : (_snapLimit - _snapsUsed);

bool get canTakeSnap {
  // Unlimited users (Ultra tier with -1 limit) can always take snaps
  if (_snapLimit == -1) return true;
  return snapsRemaining > 0;
}
```

**Status**: ✅ Fixed and tested

### Fix 2: Display Strings for Unlimited Users
**Files**: Multiple screen files

**Changes**:
- Updated all display strings to show "Unlimited" or "∞" (infinity symbol) instead of "-1/-1"
- Added helper methods `snapCountText` and `snapCountTextWithLabel` in `AppStateProvider`
- Updated screens: `solution_screen.dart`, `daily_limit_screen.dart`, `home_screen.dart`, `assessment_intro_screen.dart`, `camera_screen.dart`

**Status**: ✅ Fixed

---

## 📝 Additional Notes

### Display String Improvements Needed

Some screens show snap counts as `${snapsRemaining}/${snapLimit}` which would display "-1/-1" for unlimited users. Consider updating to:

- `solution_screen.dart` (line 996)
- `daily_limit_screen.dart` (line 110)
- `assessment_intro_screen.dart` (line 78 - already clamps to 0-5)

**Recommendation**: Use a helper method similar to `SnapCounterService.getSnapCounterText()` which handles unlimited display correctly.
