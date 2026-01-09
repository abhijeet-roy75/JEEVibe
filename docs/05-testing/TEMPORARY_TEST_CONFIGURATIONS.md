# Temporary Test Configurations

This document lists all temporary changes made for testing purposes that **MUST be reverted before production release**.

---

## Backend Changes

### 1. Daily Snap Limit Increased

**File:** `backend/src/services/snapHistoryService.js:10`

**Current (Testing):**
```javascript
const DAILY_LIMIT = 20; // Temporarily increased from 5 to 20 for performance testing
```

**Production Value:**
```javascript
const DAILY_LIMIT = 5;
```

---

### 2. Assessment Retake Allowed (Multiple Attempts)

**File:** `backend/src/routes/assessment.js:34-51`

**Current (Testing):** Code is **commented out**
```javascript
// TEMPORARILY DISABLED FOR TESTING: Allow multiple assessment attempts
// TODO: Re-enable this check before production
// Check if user already completed assessment
// const userRef = db.collection('users').doc(userId);
// ...
```

**Production Action:** Uncomment the entire block (lines 34-51) to prevent users from retaking the assessment.

---

### 3. Assessment Multiple Submissions Allowed

**File:** `backend/src/routes/assessment.js:111-129`

**Current (Testing):** Code is **commented out**
```javascript
// TEMPORARILY DISABLED FOR TESTING: Allow multiple assessment submissions
// TODO: Re-enable this check before production
// Check if user already completed assessment BEFORE processing
// ...
```

**Production Action:** Uncomment the entire block (lines 111-129) to prevent duplicate submissions.

---

### 4. Assessment Transaction Check Disabled

**File:** `backend/src/services/assessmentService.js:346-360`

**Current (Testing):** Code is **commented out**
```javascript
// TEMPORARILY DISABLED FOR TESTING: Allow overwriting completed assessments
// TODO: Re-enable this check before production
// if (userDoc.exists) {
//   const userData = userDoc.data();
//   if (userData.assessment?.status === 'completed') {
//     ...
//   }
// }
```

**Production Action:** Uncomment the entire block (lines 351-360) to enforce single assessment completion at the transaction level.

---

### 5. Old Assessment Responses Cleared on Retake

**File:** `backend/src/services/assessmentService.js:394-404`

**Current (Testing):**
```javascript
// Clear old responses before saving new ones (for retakes during testing)
const oldResponsesRef = db.collection('assessment_responses')...
```

**Production Action:** This can remain as-is since the assessment retake prevention (items 2-4 above) will prevent this code from being reached in production. However, you may want to remove this cleanup logic entirely for cleaner code.

---

### 6. Daily Quiz Limit Disabled (Multiple Quizzes Per Day)

**File:** `backend/src/routes/dailyQuiz.js:169-191`

**Current (Testing):** Code is **commented out** with `/* ... */`
```javascript
/*
if (!todayQuizzesSnapshot.empty) {
  // User has already completed a quiz today
  return res.status(429).json({
    success: false,
    error: {
      code: 'DAILY_LIMIT_REACHED',
      message: 'You have already completed your daily quiz today...'
    },
    ...
  });
}
*/
```

**Production Action:** Uncomment the entire block (lines 170-191) to enforce one quiz per day limit.

---

## Mobile App Changes

### 7. Custom Image Preview Flag

**Files:**
- `mobile/lib/screens/home_screen.dart:529`
- `mobile/lib/screens/camera_screen.dart:94`

**Current (Testing/Production):**
```dart
const forceCustomPreview = false;
```

**Note:** This is currently set correctly for production. If you need to test the custom preview on iOS, set it to `true` temporarily.

---

### 8. Daily Quiz Start Button Always Enabled

**File:** `mobile/lib/screens/daily_quiz_home_screen.dart:352`

**Current (Testing):**
```dart
canStartQuiz = true; // RESTORE: Temporarily enabled for testing
```

**Production Action:** This should respect the actual quiz availability logic. Review and restore proper condition:
```dart
canStartQuiz = /* actual logic based on quiz state */;
```

---

## Summary Checklist

Before production release, complete these tasks:

| # | Component | File | Action Required |
|---|-----------|------|-----------------|
| 1 | Backend | `snapHistoryService.js` | Change `DAILY_LIMIT` from 20 to 5 |
| 2 | Backend | `assessment.js:34-51` | Uncomment assessment completion check |
| 3 | Backend | `assessment.js:111-129` | Uncomment submission duplicate check |
| 4 | Backend | `assessmentService.js:346-360` | Uncomment transaction-level check |
| 5 | Backend | `assessmentService.js:394-404` | Optional: Remove retake cleanup logic |
| 6 | Backend | `dailyQuiz.js:169-191` | Uncomment daily quiz limit check |
| 7 | Mobile | `home_screen.dart`, `camera_screen.dart` | Keep `forceCustomPreview = false` |
| 8 | Mobile | `daily_quiz_home_screen.dart:352` | Restore proper `canStartQuiz` logic |

---

## Quick Revert Commands

To help identify all test configurations, run:

```bash
# Find all TEMPORARILY DISABLED comments
grep -rn "TEMPORARILY DISABLED\|TODO.*production" backend/src/

# Find commented-out code blocks in dailyQuiz.js
grep -n "/\*" backend/src/routes/dailyQuiz.js
```

---

*Last Updated: January 2026*
