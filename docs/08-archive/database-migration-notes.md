# Database Migration & Data Preservation Notes

## Current State Analysis

### Fields Already Created During Initial Assessment

When a user completes the initial assessment, the `assessmentService.js` **already creates** these daily quiz fields in the `users/{userId}` document:

```javascript
// These are set in assessmentService.js (lines 269-288)
completed_quiz_count: 0,
current_day: 0,
learning_phase: 'exploration',
phase_switched_at_quiz: null,
assessment_completed_at: "2024-12-03T09:00:00Z",
last_quiz_completed_at: null,
total_questions_solved: 30,  // Initial assessment count
total_time_spent_minutes: <calculated>,
chapter_attempt_counts: { ... },
chapters_explored: <count>,
chapters_confident: <count>,
subject_balance: { ... }
```

**Important:** These fields are saved using `{ merge: true }` (line 367), which means:
- ✅ They don't overwrite existing user profile fields
- ✅ They coexist with user profile data (firstName, lastName, etc.)
- ✅ They coexist with assessment data (assessment, theta_by_chapter, etc.)

### Fields That Will Be Added by Daily Quiz

When daily quiz is implemented, we will **update** (not create) these fields:
- `completed_quiz_count` - Incremented after each quiz
- `last_quiz_completed_at` - Updated after each quiz
- `total_questions_solved` - Incremented by 10 per quiz
- `total_time_spent_minutes` - Accumulated
- `chapter_attempt_counts` - Updated per chapter
- `chapters_explored` - Recalculated
- `chapters_confident` - Recalculated
- `subject_balance` - Recalculated
- `learning_phase` - Updated when transitioning from exploration to exploitation
- `phase_switched_at_quiz` - Set to 14 when phase switches

**New fields that will be added:**
- `circuit_breaker_active` - Boolean
- `consecutive_failures` - Number
- `last_circuit_breaker_trigger` - Timestamp

---

## Data Preservation Strategy

### 1. Initial Assessment Data Protection

**Assessment data is stored in separate fields and will NEVER be overwritten:**

```javascript
users/{userId} {
  // User Profile (preserved)
  firstName, lastName, phoneNumber, ...
  
  // Initial Assessment Data (preserved)
  assessment: {
    status: "completed",
    completed_at: "...",
    time_taken_seconds: 2700,
    responses: [...]
  },
  theta_by_chapter: { ... },      // Updated by daily quiz, but assessment data preserved
  theta_by_subject: { ... },      // Updated by daily quiz, but assessment data preserved
  subject_accuracy: { ... },      // Assessment-only (not updated by daily quiz)
  overall_theta: ...,             // Updated by daily quiz
  overall_percentile: ...,         // Updated by daily quiz
  
  // Daily Quiz Fields (updated, not overwritten)
  completed_quiz_count: 0 → 1 → 2 → ...
  last_quiz_completed_at: null → "2024-12-10T..."
  // etc.
}
```

### 2. Assessment Responses Protection

Assessment responses are stored in a **separate collection**:
- `assessment_responses/{userId}/responses/{responseId}`

**This collection is NEVER modified by daily quiz operations.** It's read-only after assessment completion.

### 3. Theta Updates Strategy

**Chapter-level theta (`theta_by_chapter`):**
- Initial values set during assessment (baseline)
- Updated incrementally by daily quiz (additive, not replacement)
- Structure: `{ chapter_key: { theta, percentile, attempts, ... } }`
- New chapters added as student encounters them
- Existing chapters updated (theta changes, attempts increment)

**Example:**
```javascript
// After assessment
theta_by_chapter: {
  "physics_electrostatics": { theta: 0.5, attempts: 3, ... }
}

// After 5 daily quiz questions on electrostatics
theta_by_chapter: {
  "physics_electrostatics": { theta: 0.62, attempts: 8, ... }  // Updated, not replaced
}
```

**Subject-level theta (`theta_by_subject`):**
- Recalculated from `theta_by_chapter` after each quiz
- Assessment baseline preserved in history (can be calculated from assessment responses)

### 4. Merge Strategy (Critical)

All updates to `users/{userId}` use `{ merge: true }`:

```javascript
// In assessmentService.js (line 367)
transaction.set(userRef, {
  assessment: ...,
  theta_by_chapter: ...,
  // ... other fields
}, { merge: true });  // ← This preserves existing fields

// In daily quiz service (to be implemented)
userRef.set({
  completed_quiz_count: newCount,
  last_quiz_completed_at: newTimestamp,
  theta_by_chapter: updatedThetas,  // Merges with existing
  // ... other updates
}, { merge: true });  // ← This preserves assessment data
```

**What `{ merge: true }` does:**
- ✅ Adds new fields if they don't exist
- ✅ Updates existing fields if they do exist
- ✅ Preserves all other fields (user profile, assessment data, etc.)
- ✅ Does NOT delete any fields

### 5. Assessment Baseline Preservation

To track progress "from baseline", we can:

**Option A: Store baseline snapshot (recommended)**
```javascript
users/{userId} {
  // ... existing fields
  
  // Baseline snapshot (set once during assessment, never updated)
  assessment_baseline: {
    theta_by_chapter: { ... },  // Snapshot of initial values
    theta_by_subject: { ... },
    overall_theta: 0.2,
    overall_percentile: 57.93,
    captured_at: "2024-12-03T09:00:00Z"
  }
}
```

**Option B: Calculate from assessment responses**
- Query `assessment_responses/{userId}/responses/` collection
- Recalculate baseline theta from original responses
- More storage-efficient, but requires query

**Recommendation:** Use Option A for faster progress calculations.

---

## Migration Checklist

### For Existing Users (if any)

If you have users who completed assessment before daily quiz fields were added:

1. **Check if daily quiz fields exist:**
   ```javascript
   const user = await db.collection('users').doc(userId).get();
   const data = user.data();
   
   if (!data.completed_quiz_count) {
     // User from before daily quiz fields were added
     // Initialize with assessment data
   }
   ```

2. **Initialize missing fields:**
   ```javascript
   await userRef.set({
     completed_quiz_count: 0,
     current_day: 0,
     learning_phase: 'exploration',
     phase_switched_at_quiz: null,
     last_quiz_completed_at: null,
     // ... other fields initialized from assessment data
   }, { merge: true });
   ```

3. **Create assessment baseline snapshot:**
   ```javascript
   await userRef.set({
     assessment_baseline: {
       theta_by_chapter: data.theta_by_chapter,  // Snapshot
       theta_by_subject: data.theta_by_subject,
       overall_theta: data.overall_theta,
       overall_percentile: data.overall_percentile,
       captured_at: data.assessment?.completed_at || new Date().toISOString()
     }
   }, { merge: true });
   ```

### For New Users

No migration needed - assessment service already creates all required fields.

---

## Data Integrity Guarantees

### What We Guarantee

1. ✅ **Assessment data is never deleted** - Stored in separate fields and subcollection
2. ✅ **User profile is never overwritten** - All updates use `{ merge: true }`
3. ✅ **Assessment responses are read-only** - Separate collection, never modified
4. ✅ **Theta updates are additive** - New chapters added, existing updated incrementally
5. ✅ **Baseline can be preserved** - Store snapshot or recalculate from responses

### What We Update

1. ✅ **Daily quiz state fields** - `completed_quiz_count`, `last_quiz_completed_at`, etc.
2. ✅ **Theta values** - `theta_by_chapter`, `theta_by_subject`, `overall_theta`
3. ✅ **Progress metrics** - `total_questions_solved`, `chapters_explored`, etc.
4. ✅ **Attempt counts** - `chapter_attempt_counts` incremented

### What We Never Touch

1. ❌ **Assessment object** - `assessment.status`, `assessment.completed_at`, etc.
2. ❌ **Assessment responses collection** - `assessment_responses/{userId}/responses/`
3. ❌ **User profile fields** - `firstName`, `lastName`, `phoneNumber`, etc.
4. ❌ **Initial assessment questions** - `initial_assessment_questions/` collection

---

## Implementation Safety

### Code Pattern for Daily Quiz Updates

```javascript
// ✅ CORRECT: Use merge to preserve existing data
async function updateUserAfterQuiz(userId, quizData) {
  const userRef = db.collection('users').doc(userId);
  
  // Read current state
  const userDoc = await userRef.get();
  const currentData = userDoc.data();
  
  // Calculate updates
  const updates = {
    completed_quiz_count: (currentData.completed_quiz_count || 0) + 1,
    last_quiz_completed_at: new Date().toISOString(),
    total_questions_solved: (currentData.total_questions_solved || 0) + 10,
    // ... other updates
    theta_by_chapter: {
      ...currentData.theta_by_chapter,  // Preserve existing
      ...updatedThetas                   // Merge updates
    }
  };
  
  // Update with merge (preserves all other fields)
  await userRef.set(updates, { merge: true });
}

// ❌ WRONG: This would overwrite entire document
await userRef.set(updates);  // Don't do this!
```

---

## Summary

**Answer to "Did we create these fields earlier or will we create now?":**

✅ **Already Created:** These fields are created when a user completes the initial assessment (in `assessmentService.js`). They are initialized with default values (quiz_count = 0, learning_phase = 'exploration', etc.).

✅ **Will Be Updated:** When daily quiz is implemented, these fields will be **updated** (not created) using `{ merge: true }` to preserve all existing data.

✅ **Assessment Data Protected:** All assessment data is stored in separate fields/collections and will never be overwritten. The `{ merge: true }` strategy ensures data preservation.

