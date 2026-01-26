# Analytics Counter Updates - JEEVibe Features

## Overview
This document describes how analytics counters are updated across all JEEVibe learning features to ensure consistency and accurate progress tracking.

---

## Global Analytics Fields

All features update these **user document** fields in Firestore:

| Field | Type | Purpose | Updated By |
|-------|------|---------|------------|
| `total_questions_solved` | number | Total questions attempted across all features | All features |
| `total_questions_correct` | number | Total correct answers across all features | All features |
| `total_questions_incorrect` | number | Total incorrect answers | Mock Tests only |
| `total_time_spent_minutes` | number | Total study time in minutes | Daily Quiz, Chapter Practice, Snap Practice |
| `theta_by_chapter` | object | IRT theta per chapter | All features |
| `theta_by_subject` | object | IRT theta per subject (Physics, Chemistry, Math) | All features |
| `subject_accuracy` | object | Correct/total/accuracy per subject | All features |
| `overall_theta` | number | Weighted overall theta | All features |
| `overall_percentile` | number | Percentile based on overall theta | Daily Quiz, Chapter Practice, Snap Practice |
| `cumulative_stats` | object | Cumulative correct/attempted/last_updated | All features |

---

## Cumulative Stats Structure

```javascript
{
  total_questions_correct: number,  // Total correct answers
  total_questions_attempted: number, // Total questions attempted
  last_updated: timestamp            // Last update time
}
```

**Purpose**: Provides a consistent, cross-feature view of student progress.

**Updated By**: Daily Quiz, Chapter Practice, Mock Tests, Snap Practice

---

## Feature-Specific Updates

### 1. Daily Quiz

**File**: `backend/src/routes/dailyQuiz.js`
**Update Location**: Lines 744-768
**Endpoint**: `POST /api/daily-quiz/complete`

**Counters Updated**:
```javascript
{
  completed_quiz_count: FieldValue.increment(1),
  total_questions_solved: FieldValue.increment(totalCount),
  total_time_spent_minutes: FieldValue.increment(Math.round(totalTime / 60)),
  theta_by_chapter: { /* updated theta values */ },
  theta_by_subject: { /* recalculated */ },
  subject_accuracy: { /* updated per subject */ },
  overall_theta: /* weighted average */,
  overall_percentile: /* calculated from theta */,
  'cumulative_stats.total_questions_correct': FieldValue.increment(correctCount),
  'cumulative_stats.total_questions_attempted': FieldValue.increment(totalCount),
  'cumulative_stats.last_updated': FieldValue.serverTimestamp()
}
```

**Theta Multiplier**: 1.0x (full impact on theta)

---

### 2. Chapter Practice

**File**: `backend/src/routes/chapterPractice.js`
**Update Locations**:
- Per-answer: Lines 600-624 (theta_by_chapter updated immediately)
- Session completion: Lines 968-982

**Endpoint**: `POST /api/chapter-practice/complete`

**Counters Updated**:
```javascript
{
  theta_by_subject: { /* recalculated */ },
  subject_accuracy: { /* updated per subject */ },
  overall_theta: /* weighted average */,
  overall_percentile: /* calculated from theta */,
  subtopic_accuracy: { /* fine-grained tracking */ },
  chapter_practice_stats: { /* aggregated per chapter/subject */ },
  total_questions_solved: FieldValue.increment(totalAnswered),
  total_time_spent_minutes: FieldValue.increment(Math.round(totalTime / 60)),
  'cumulative_stats.total_questions_correct': FieldValue.increment(correctCount),
  'cumulative_stats.total_questions_attempted': FieldValue.increment(totalAnswered),
  'cumulative_stats.last_updated': FieldValue.serverTimestamp()
}
```

**Theta Multiplier**: 0.5x (half impact - practice mode)

**Special**: Updates theta_by_chapter **per answer** in real-time (Line 622)

---

### 3. Mock Tests (Simulation)

**File**: `backend/src/services/mockTestService.js`
**Update Location**: Lines 755-775
**Endpoint**: `POST /api/mock-tests/:testId/submit`

**Counters Updated**:
```javascript
{
  mock_test_stats: { /* test count, scores, best score, avg, subject accuracy */ },
  last_mock_test_at: FieldValue.serverTimestamp(),

  // Global counters
  total_questions_solved: FieldValue.increment(attemptedCount),
  total_questions_correct: FieldValue.increment(correctCount),
  total_questions_incorrect: FieldValue.increment(incorrectCount),

  // Cumulative stats (added for consistency)
  'cumulative_stats.total_questions_correct': FieldValue.increment(correctCount),
  'cumulative_stats.total_questions_attempted': FieldValue.increment(attemptedCount),
  'cumulative_stats.last_updated': FieldValue.serverTimestamp(),

  // Theta updates
  theta_by_chapter: { /* updated based on performance */ },
  theta_by_subject: { /* recalculated */ },
  subject_accuracy: { /* updated with mock test results */ },
  overall_theta: /* weighted average */,
  theta_updated_at: FieldValue.serverTimestamp()
}
```

**Theta Multiplier**: Variable based on accuracy vs expected accuracy (Lines 843-848)

**Special Notes**:
- Only feature that updates `total_questions_incorrect`
- Uses atomic single-update pattern to prevent race conditions
- Theta calculated before update (pure function: `calculateThetaUpdates`)

---

### 4. Snap & Solve Practice

**File**: `backend/src/routes/solve.js`
**Update Location**: Lines 960-1000
**Endpoint**: `POST /api/snap-practice/complete`

**Counters Updated** (when correctCount > 0):
```javascript
{
  theta_by_chapter: { /* updated with 0.4x multiplier */ },
  theta_by_subject: { /* recalculated */ },
  overall_theta: /* weighted average */,
  overall_percentile: /* calculated from theta */,
  total_questions_solved: FieldValue.increment(totalQuestions),
  total_time_spent_minutes: FieldValue.increment(Math.round(totalTime / 60)),
  'cumulative_stats.total_questions_correct': FieldValue.increment(correctCount),
  'cumulative_stats.total_questions_attempted': FieldValue.increment(totalQuestions),
  'cumulative_stats.last_updated': FieldValue.serverTimestamp(),
  snap_practice_stats: { /* total sessions, questions, correct, last session */ }
}
```

**Theta Multiplier**: 0.4x (lowest impact - quick practice)

**Special**: No theta update if correctCount = 0 (Lines 988-1000)

---

## Theta Multipliers Summary

| Feature | Multiplier | Rationale |
|---------|-----------|-----------|
| Daily Quiz | 1.0x | Primary learning mode - full impact |
| Chapter Practice | 0.5x | Practice mode - moderate impact |
| Snap & Solve | 0.4x | Quick practice - lower impact |
| Mock Tests | Variable | Based on accuracy vs expected (complex formula) |

**Mock Test Theta Calculation** (Lines 843-848):
```javascript
let thetaDelta = 0;
const expectedAccuracy = 0.5 + (currentTheta - avgDifficulty) * 0.1;

if (accuracy > expectedAccuracy + 0.2) {
  thetaDelta = 0.1 * (accuracy - expectedAccuracy);
} else if (accuracy < expectedAccuracy - 0.2) {
  thetaDelta = 0.1 * (accuracy - expectedAccuracy);
}

const newTheta = Math.max(-3, Math.min(3, currentTheta + thetaDelta));
```

---

## Subject Accuracy Update Pattern

All features now update `subject_accuracy` consistently:

```javascript
subject_accuracy: {
  physics: {
    correct: number,      // Total correct in Physics
    total: number,        // Total attempted in Physics
    accuracy: number      // Percentage (0-100)
  },
  chemistry: { correct, total, accuracy },
  mathematics: { correct, total, accuracy }
}
```

**Calculation**: `accuracy = Math.round((correct / total) * 100)` or `0` if total is 0

**Updated by**:
- Daily Quiz: Via `calculateSubjectAndOverallThetaUpdate()` (Line 757)
- Chapter Practice: Via `calculateSubjectAndOverallThetaUpdate()` (Line 971)
- Mock Tests: Direct calculation with validation (Lines 872-910)
- Snap & Solve: ⚠️ **TO BE ADDED** (currently doesn't update subject_accuracy)

---

## Analytics Overview Display

The mobile app's **Analytics Overview** tab displays:

1. **Questions Solved**: `total_questions_solved`
2. **Quizzes Completed**: `completed_quiz_count` (Daily Quiz only)
3. **Current Streak**: From `practice_streaks` collection
4. **Subject Progress**: Uses `subject_accuracy` for each subject's correct/total/accuracy
5. **Overall Percentile**: `overall_percentile`

---

## Consistency Checklist

✅ All features update `total_questions_solved`
✅ All features update `cumulative_stats` (added to Mock Tests)
✅ All features update `theta_by_chapter`, `theta_by_subject`, `overall_theta`
✅ All features update `subject_accuracy` (except Snap Practice - needs fix)
⚠️ Only Mock Tests updates `total_questions_incorrect` (intentional?)
⚠️ Mock Tests doesn't update `overall_percentile` (should it?)
⚠️ Mock Tests doesn't track time (`total_time_spent_minutes`)

---

## Remaining Inconsistencies

### 1. Snap & Solve - Missing subject_accuracy Update
**Issue**: Snap practice doesn't update `subject_accuracy` field
**Impact**: Subject progress cards in Analytics don't include snap practice performance
**Fix**: Add subject_accuracy update in `/backend/src/routes/solve.js` around Line 965

### 2. Mock Tests - Missing overall_percentile Update
**Issue**: Mock tests update `overall_theta` but not `overall_percentile`
**Impact**: Percentile may be stale after mock test completion
**Fix**: Add `overall_percentile` calculation after Line 882:
```javascript
const overallPercentile = thetaToPercentile(overallTheta);
// Then include in update at Line 772
```

### 3. total_questions_incorrect - Only in Mock Tests
**Issue**: Only mock tests increment this counter
**Impact**: Counter doesn't reflect daily quiz, chapter practice, or snap practice errors
**Decision needed**: Should this be global or mock-test-only?

---

## Version History

- **v1.0** (Jan 26, 2026): Initial documentation
- **v1.1** (Jan 26, 2026): Added cumulative_stats to Mock Tests for consistency

---

## References

- Daily Quiz: `backend/src/routes/dailyQuiz.js`
- Chapter Practice: `backend/src/routes/chapterPractice.js`
- Mock Tests: `backend/src/services/mockTestService.js`
- Snap & Solve: `backend/src/routes/solve.js`
- Theta Calculation: `backend/src/services/thetaCalculationService.js`
- Theta Update: `backend/src/services/thetaUpdateService.js`
