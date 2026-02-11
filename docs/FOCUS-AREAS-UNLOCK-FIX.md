# Focus Areas Unlock Filter Fix

**Date:** 2026-02-10
**Issue:** Locked chapters appearing in Focus Areas card on home screen
**Status:** ✅ FIXED

---

## Problem Statement

After implementing the 24-month countdown timeline for chapter unlocking:
- ✅ Daily quiz correctly filtered questions by unlocked chapters
- ❌ **Focus Areas** card on home screen showed ALL chapters from `theta_by_chapter`
- This meant students saw locked chapters they couldn't practice in the focus list

### User Experience Impact

**Before Fix:**
```
Focus Chapters
├─ Physics: Electromagnetic Induction (🔒 LOCKED)
├─ Chemistry: Organic Chemistry (🔒 LOCKED)
└─ Math: Calculus (✓ Unlocked)
```

**After Fix:**
```
Focus Chapters
├─ Physics: Kinematics (✓ Unlocked)
├─ Chemistry: Atomic Structure (✓ Unlocked)
└─ Math: Calculus (✓ Unlocked)
```

---

## Root Cause Analysis

### Daily Quiz Service ✅ (Already Correct)
**File:** `backend/src/services/dailyQuizService.js` (lines 693-749)

```javascript
// Get unlocked chapters
const unlockResult = await getUnlockedChapters(userId);
const unlockedChapterKeys = new Set(unlockResult.unlockedChapterKeys);

// Filter allChapterMappings to only include unlocked chapters
if (allChapterMappings && allChapterMappings.size > 0) {
  const filteredMappings = new Map();
  for (const [chapterKey, value] of allChapterMappings.entries()) {
    if (unlockedChapterKeys.has(chapterKey)) {
      filteredMappings.set(chapterKey, value);
    }
  }
  allChapterMappings = filteredMappings;
}
```

✅ Daily quiz **correctly** filters by unlocked chapters.

### Analytics Service ❌ (Bug Found)
**File:** `backend/src/services/analyticsService.js`

**Before (buggy code):**
```javascript
async function getAnalyticsOverview(userId) {
  const thetaByChapter = userData.theta_by_chapter || {};

  // Bug: Uses ALL theta chapters, not just unlocked ones
  const focusAreas = await calculateFocusAreas(thetaByChapter, ...);

  return { focus_areas: focusAreas };
}
```

❌ Analytics service used **all chapters** from `theta_by_chapter`, including locked ones.

### Focus Areas Display Flow

```
Mobile App (home_screen.dart)
       ↓
   API Call: /api/analytics/overview
       ↓
analyticsService.getAnalyticsOverview(userId)
       ↓
calculateFocusAreas(thetaByChapter)  ← BUG HERE
       ↓
Focus Areas: ALL chapters (locked + unlocked)
```

---

## Solution Implementation

### Code Changes

**File:** `backend/src/services/analyticsService.js`

**1. Import chapter unlock service:**
```javascript
const { getUnlockedChapters } = require('./chapterUnlockService');
```

**2. Filter theta before focus area calculation:**
```javascript
async function getAnalyticsOverview(userId) {
  const thetaByChapter = userData.theta_by_chapter || {};

  // NEW: Filter to only unlocked chapters
  let filteredThetaByChapter = thetaByChapter;
  try {
    const unlockResult = await getUnlockedChapters(userId);
    const unlockedChapterKeys = new Set(unlockResult.unlockedChapterKeys);

    filteredThetaByChapter = {};
    for (const [chapterKey, data] of Object.entries(thetaByChapter)) {
      if (unlockedChapterKeys.has(chapterKey)) {
        filteredThetaByChapter[chapterKey] = data;
      }
    }

    logger.info('Filtered focus areas by unlock status', {
      userId,
      currentMonth: unlockResult.currentMonth,
      totalChaptersInTheta: Object.keys(thetaByChapter).length,
      unlockedChaptersInTheta: Object.keys(filteredThetaByChapter).length,
      filteredOut: Object.keys(thetaByChapter).length - Object.keys(filteredThetaByChapter).length
    });
  } catch (unlockError) {
    logger.warn('Failed to filter by unlock status, using all theta chapters', {
      userId,
      error: unlockError.message
    });
    // Graceful fallback to all chapters if unlock check fails
    filteredThetaByChapter = thetaByChapter;
  }

  // Use filtered theta
  const chaptersMastered = countMasteredChapters(filteredThetaByChapter);
  const focusAreas = await calculateFocusAreas(filteredThetaByChapter, ...);
}
```

**3. Graceful error handling:**
- If `getUnlockedChapters()` fails → falls back to all chapters
- Prevents analytics from breaking if unlock service has issues
- Logs warning for debugging

---

## Testing Verification

### Expected Behavior After Fix

**Scenario 1: Student at Month 5 (Early in Timeline)**
- Unlocked: 8 chapters (Physics: 3, Chemistry: 3, Math: 2)
- Theta history: 15 chapters (practiced before timeline was enabled)
- **Focus Areas should show:** Only 3 chapters from the unlocked 8
- **Focus Areas should NOT show:** Any of the 7 locked chapters

**Scenario 2: Student at Month 20 (Near Exam)**
- Unlocked: 55 chapters (most of syllabus)
- Theta history: 40 chapters
- **Focus Areas should show:** 3 chapters from the unlocked 40
- **Focus Areas should NOT show:** Locked future chapters (if any)

**Scenario 3: Legacy User (No jeeTargetExamDate)**
- Unlocked: ALL chapters (backward compatibility)
- Theta history: 30 chapters
- **Focus Areas should show:** 3 chapters from all 30
- **Behavior:** Unchanged (all chapters already unlocked)

### Log Output Example

```
INFO: Filtered focus areas by unlock status
{
  userId: 'abc123',
  currentMonth: 14,
  totalChaptersInTheta: 25,
  unlockedChaptersInTheta: 18,
  filteredOut: 7
}
```

This shows:
- Student is at month 14 of 24
- Has attempted 25 chapters total (some before timeline implementation)
- Only 18 of those are currently unlocked
- 7 locked chapters were filtered out from focus areas

---

## Deployment

### Phase 1: Analytics Unlock Filtering
**Commit:** `88ffc4c`
**Deployed to:** Render.com (auto-deploy from `main` branch)
**Status:** ✅ Live

**Files Changed:**
1. `backend/src/services/analyticsService.js` - Added unlock filtering
2. `docs/03-features/REUSABLE_BUTTONS.md` - Moved from mobile/ (unrelated cleanup)

### Phase 2: Remove Weekly Rotation UI
**Commit:** `b4735a6`
**Deployed to:** Mobile app (requires rebuild)
**Status:** ⏳ Pending rebuild

**Files Changed:**
1. `mobile/lib/screens/home_screen.dart` - Removed subject lock UI logic
2. `docs/FOCUS-AREAS-UNLOCK-FIX.md` - Full documentation

### Phase 3: Remove Weekly Rotation Backend
**Commit:** `b55d8c1`
**Deployed to:** Render.com (auto-deploy from `main` branch)
**Status:** ✅ Live

**Changes:**
1. Firestore `tier_config/active` updated:
   - `chapter_practice_weekly_per_subject`: 1 → -1 (unlimited)
   - Added `chapter_practice_daily_limit`: 5
2. `backend/src/routes/chapterPractice.js` - Daily limit enforcement
   - Removed weekly subject checks
   - Track daily chapter count in `users/{userId}/daily_usage/{date}`

---

## Related Files

### Backend
- `backend/src/services/analyticsService.js` - Analytics overview generation (FIXED)
- `backend/src/services/chapterUnlockService.js` - Chapter unlock logic (used)
- `backend/src/services/dailyQuizService.js` - Daily quiz generation (already correct)

### Mobile
- `mobile/lib/screens/home_screen.dart` - Focus Areas card display (no changes needed)
- `mobile/lib/models/analytics_data.dart` - Analytics data model (no changes needed)

---

## Validation Checklist

- [x] Daily quiz only uses unlocked chapters
- [x] Focus Areas only shows unlocked chapters
- [x] Chapter list screen shows lock/unlock states correctly
- [x] High-water mark prevents re-locking of chapters
- [x] Legacy users (no jeeTargetExamDate) see all chapters
- [x] Post-exam students see all chapters
- [x] Graceful error handling if unlock service fails
- [x] Logging for debugging unlock filtering

---

## Future Considerations

### Performance Optimization
Currently, analytics service calls `getUnlockedChapters()` on every request. Consider:
- Caching unlock data per user (5-minute TTL)
- Including unlock data in user profile provider (mobile)
- Batch unlock checks for multiple users

### Additional Unlock Filters Needed
Consider filtering by unlock status in:
- ✅ Daily quiz (already done)
- ✅ Focus areas (fixed today)
- ❓ Chapter practice screen (verify if needed)
- ❓ Mock test chapter selection (verify if needed)
- ❓ AI Tutor context (verify if needed)

---

## Conclusion

The Focus Areas card now correctly shows only unlocked chapters, maintaining consistency with the 24-month countdown timeline system. Students will only see chapters they can actually practice, improving UX and reducing confusion.

**Key Learning:**
When implementing global features like chapter unlocking, audit ALL services that consume chapter data, not just the primary feature (daily quiz). Secondary features (analytics, focus areas, recommendations) must also respect the unlock logic.
