# Daily Quiz Chapter Unlock Bug Fix

**Date:** 2026-02-28
**Bug Report:** Daily quiz showing questions from locked chapters (Circles, Sequences and Series)
**User Affected:** +14125965484 (User ID: whXKoBgqYQaD6NQafUDKGZcC5J42)

## Problem Summary

Daily Adaptive Quiz was presenting questions from locked chapters to users who are early in their JEE prep timeline.

**Example:** User at Month 2 (23 months to JEE, 7/66 chapters unlocked) was seeing questions from:
- `mathematics_circles` (unlocks at Month 6)
- `mathematics_sequences_and_series` (unlocks at Month 4)

## Root Cause

The `selectAnyAvailableQuestions()` fallback function in [`questionSelectionService.js`](../../backend/src/services/questionSelectionService.js) did NOT filter questions by unlocked chapters.

### Bug Location

**File:** `backend/src/services/questionSelectionService.js`
**Function:** `selectAnyAvailableQuestions()`
**Lines:** 532-593

When the daily quiz service couldn't find enough questions from unlocked chapters (< 10 questions), it fell back to `selectAnyAvailableQuestions()` which queried the entire question bank without respecting the unlock timeline.

### Trigger Condition

```javascript
// In dailyQuizService.js (line 874)
if (selectedQuestions.length < QUIZ_SIZE) {
  // Fallback: get ANY available questions
  const fallbackQuestions = await selectAnyAvailableQuestions(
    combinedExcludeIds,
    questionsNeeded
    // ❌ Missing: unlockedChapterKeys parameter
  );
}
```

This happened when:
1. User is early in prep timeline (few unlocked chapters)
2. Question bank has limited questions for unlocked chapters
3. Quiz generation falls short of 10 questions
4. Fallback activates and selects from ALL chapters (including locked ones)

## Fix Applied

### 1. Updated `selectAnyAvailableQuestions()` Signature

**File:** `backend/src/services/questionSelectionService.js`

Added optional `unlockedChapterKeys` parameter:

```javascript
async function selectAnyAvailableQuestions(
  excludeQuestionIds = new Set(),
  limit = 10,
  unlockedChapterKeys = null  // NEW: Filter by unlocked chapters
) {
  // ... existing code ...

  // Filter by unlocked chapters (if provided)
  if (unlockedChapterKeys !== null) {
    const beforeUnlockFilter = questions.length;
    questions = questions.filter(q => {
      const chapterKey = q.chapter_key || formatChapterKey(q.subject, q.chapter);
      return unlockedChapterKeys.has(chapterKey);
    });
    logger.info('Filtered questions by unlocked chapters', {
      beforeUnlockFilter,
      afterUnlockFilter: questions.length,
      unlockedChapterCount: unlockedChapterKeys.size
    });
  }

  // ... rest of function ...
}
```

### 2. Updated `dailyQuizService.js` Fallback Call

**File:** `backend/src/services/dailyQuizService.js`

**Lines changed:**
- Line 694: Declared `unlockedChapterKeys` outside try-catch (for scope)
- Line 899: Passed `unlockedChapterKeys` to fallback

```javascript
// Line 694: Declare outside try-catch for use in fallback
let unlockedChapterKeys = null;
try {
  const unlockResult = await getUnlockedChapters(userId);
  unlockedChapterKeys = new Set(unlockResult.unlockedChapterKeys);
  // ... filtering logic ...
} catch (unlockError) {
  // ... error handling ...
}

// Line 899: Pass to fallback
const fallbackQuestions = await selectAnyAvailableQuestions(
  combinedExcludeIds,
  questionsNeeded,
  unlockedChapterKeys  // ✅ Now respects unlocks
);
```

### 3. Added Import for `formatChapterKey`

**File:** `backend/src/services/questionSelectionService.js`
**Line:** 18

```javascript
const { formatChapterKey } = require('./thetaCalculationService');
```

## Testing

### Unit Tests

```bash
npm test -- questionSelectionService.test.js
```

✅ All 15 tests passing

### Manual Testing

**User:** whXKoBgqYQaD6NQafUDKGZcC5J42 (Month 2, 7 unlocked chapters)

**Expected behavior after fix:**
- Daily quiz questions ONLY from these 7 chapters:
  - `physics_units_measurements`
  - `physics_kinematics`
  - `chemistry_basic_concepts`
  - `chemistry_atomic_structure`
  - `chemistry_chemical_bonding`
  - `mathematics_sets_relations_functions`
  - `mathematics_trigonometry`

**Locked chapters (should NOT appear):**
- `mathematics_circles` (Month 6)
- `mathematics_sequences_and_series` (Month 4)
- All other chapters (Months 3-24)

## Impact

### Users Affected
- Early-stage students (Month 1-3) with few unlocked chapters
- Students with limited question banks for unlocked chapters

### Severity
- **High:** Violates core product promise (adaptive timeline-based learning)
- **User Experience:** Confusing to see locked chapters in quiz

### Fix Deployment
- Backend changes only (no mobile app update required)
- Deploy to Render.com via git push
- Live immediately after deployment

## Verification Steps

1. **Check user's unlocked chapters:**
   ```bash
   node backend/scripts/test-unlock-service.js
   ```

2. **Generate daily quiz:**
   - User generates new daily quiz
   - Verify all questions are from unlocked chapters only

3. **Check logs for fallback usage:**
   ```
   "Filtered questions by unlocked chapters"
   ```

4. **Monitor Firestore:**
   - Query `users/{userId}/quizzes` collection
   - Inspect `questions[].chapter_key` fields
   - Confirm no locked chapters appear

## Related Files

### Backend Services
- [`questionSelectionService.js`](../../backend/src/services/questionSelectionService.js) - Question fallback logic
- [`dailyQuizService.js`](../../backend/src/services/dailyQuizService.js) - Daily quiz generation
- [`chapterUnlockService.js`](../../backend/src/services/chapterUnlockService.js) - Unlock timeline

### Unlock Schedule
- Firestore: `unlock_schedules` collection (type: `countdown_24month`)
- Timeline: `month_1` through `month_24` with chapter arrays

## Future Improvements

1. **Add Integration Test:**
   - Test daily quiz generation with limited unlocked chapters
   - Verify fallback respects unlock filtering

2. **Question Bank Monitoring:**
   - Alert when unlocked chapters have < 10 questions
   - Prevent fallback activation during quiz generation

3. **Better Fallback Strategy:**
   - Prioritize recently unlocked chapters in fallback
   - Avoid relying on fallback altogether by ensuring sufficient question bank

## Deployment Checklist

- [x] Fix implemented in `questionSelectionService.js`
- [x] Fix implemented in `dailyQuizService.js`
- [x] Unit tests passing
- [ ] Changes committed to git
- [ ] Pushed to Render.com (auto-deploys on push)
- [ ] Verified in production with test user
- [ ] Updated MEMORY.md with fix summary
