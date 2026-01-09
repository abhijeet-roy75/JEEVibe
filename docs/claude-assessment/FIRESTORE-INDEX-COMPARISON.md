# Firestore Index Comparison Analysis

**Date**: January 1, 2026
**Purpose**: Compare newly created indexes (from P1 backend fixes) with existing deployed indexes

---

## Summary

**Existing Indexes**: 19 composite indexes (deployed in Firebase)
**Newly Created Indexes**: 6 composite indexes (in firestore.indexes.json)
**Overlap**: 2 indexes are duplicates
**New Unique Indexes**: 4 indexes (need deployment)
**Recommendation**: Deploy new indexes + clean up duplicates

---

## Newly Created Indexes (from P1 Backend Fixes)

From `/Users/abhijeetroy/Documents/JEEVibe/backend/firestore.indexes.json`:

### 1. daily_quizzes - Status + Completed At (DESCENDING)
```json
{
  "collectionGroup": "daily_quizzes",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "completed_at", "order": "DESCENDING" }
  ]
}
```
**Status**: ✅ **DUPLICATE** (already exists as quizzes index #7)

### 2. daily_quizzes - Status + Created At (DESCENDING)
```json
{
  "collectionGroup": "daily_quizzes",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "created_at", "order": "DESCENDING" }
  ]
}
```
**Status**: ⚠️ **NEW** (similar to quizzes index #8 but uses created_at instead of generated_at)

### 3. questions - Chapter + Is Active + Difficulty B
```json
{
  "collectionGroup": "questions",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "chapter", "order": "ASCENDING" },
    { "fieldPath": "is_active", "order": "ASCENDING" },
    { "fieldPath": "difficulty_b", "order": "ASCENDING" }
  ]
}
```
**Status**: ✅ **NEW** (no existing equivalent)
**Purpose**: Filter questions by chapter and active status, then sort by IRT difficulty

### 4. questions - Chapter + Is Active + Difficulty IRT
```json
{
  "collectionGroup": "questions",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "chapter", "order": "ASCENDING" },
    { "fieldPath": "is_active", "order": "ASCENDING" },
    { "fieldPath": "difficulty_irt", "order": "ASCENDING" }
  ]
}
```
**Status**: ✅ **NEW** (no existing equivalent)
**Purpose**: Alternative difficulty field for question selection

### 5. responses - Question ID + Created At (DESCENDING)
```json
{
  "collectionGroup": "responses",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "question_id", "order": "ASCENDING" },
    { "fieldPath": "created_at", "order": "DESCENDING" }
  ]
}
```
**Status**: ⚠️ **SIMILAR** to existing index #13 (uses answered_at instead of created_at)
**Note**: Field name mismatch - existing uses `answered_at`, new uses `created_at`

### 6. responses - Is Correct + Created At (DESCENDING)
```json
{
  "collectionGroup": "responses",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "is_correct", "order": "ASCENDING" },
    { "fieldPath": "created_at", "order": "DESCENDING" }
  ]
}
```
**Status**: ⚠️ **SIMILAR** to existing index #12 (uses answered_at instead of created_at)
**Note**: Field name mismatch - existing uses `answered_at`, new uses `created_at`

---

## Existing Deployed Indexes

### For Collection: initial_assessment_questions
1. **Index #1**: subject + difficulty + question_id

### For Collection: questions
2. **Index #2**: subject + chapter + irt_parameters.difficulty_b
3. **Index #3**: subject + chapter + irt_parameters.discrimination_a (DESC)
4. **Index #4**: subject + chapter + question_id

### For Collection Group: quizzes
5. **Index #5**: status + chapters_covered (ARRAY) + completed_at (DESC)
6. **Index #6**: status + completed_at (ASC)
7. **Index #7**: status + completed_at (DESC) ← **DUPLICATE of new index #1**
8. **Index #8**: status + generated_at (DESC)
9. **Index #9**: student_id + completed_at (DESC)
10. **Index #10**: student_id + learning_phase + completed_at (DESC)
11. **Index #11**: student_id + quiz_number (DESC)

### For Collection Group: responses
12. **Index #12**: is_correct + answered_at (DESC)
13. **Index #13**: question_id + answered_at (DESC)
14. **Index #14**: student_id + answered_at (DESC)
15. **Index #15**: student_id + chapter_key + answered_at (DESC)
16. **Index #16**: student_id + is_correct + answered_at (DESC)
17. **Index #17**: student_id + quiz_id + question_position

### For Collection Group: snapshots
18. **Index #18**: student_id + week_end (DESC)
19. **Index #19**: student_id + week_number

---

## Analysis

### ✅ Confirmed Duplicates
1. **daily_quizzes: status + completed_at (DESC)**
   - Already exists as quizzes index #7
   - **Action**: No deployment needed (already covered)

### ⚠️ Field Name Mismatches
The new indexes use `created_at` while existing indexes use `answered_at`:

1. **responses: question_id + created_at** (new) vs **responses: question_id + answered_at** (existing #13)
2. **responses: is_correct + created_at** (new) vs **responses: is_correct + answered_at** (existing #12)

**Investigation Needed**:
- Check if `responses` collection uses `created_at` or `answered_at` field
- If both fields exist, decide which to use for queries
- If only one exists, update indexes to match actual field name

### ✅ New Unique Indexes (Need Deployment)
These indexes are genuinely new and required:

1. **questions: chapter + is_active + difficulty_b**
   - Used by daily quiz question selection (filter by chapter, active status, difficulty)
   - **Required for**: Efficient question filtering in questionSelectionService.js

2. **questions: chapter + is_active + difficulty_irt**
   - Alternative difficulty field for question selection
   - **Required for**: Fallback when difficulty_b not available

3. **daily_quizzes: status + created_at (DESC)**
   - Different from existing (uses created_at vs generated_at)
   - **Required for**: Fetching quizzes by creation timestamp

---

## Recommendations

### 1. Verify Field Names in responses Collection
```javascript
// Check actual field names used in responses
// Option A: created_at (timestamp when response created)
// Option B: answered_at (timestamp when student answered)
```

**Action**: Review backend code to confirm which field is used:
- Check `dailyQuiz.js` routes -どのフィールドを使用しているか
- Check `responses` collection schema in Firestore Console

### 2. Update firestore.indexes.json
Based on field verification, update the indexes file:

**If using `answered_at`** (likely):
```json
{
  "collectionGroup": "responses",
  "fields": [
    { "fieldPath": "question_id", "order": "ASCENDING" },
    { "fieldPath": "answered_at", "order": "DESCENDING" }
  ]
}
```

**If using `created_at`**:
Keep current index definitions (no change needed)

### 3. Deploy New Indexes
After field verification, deploy:

```bash
cd backend
firebase deploy --only firestore:indexes

# Expected: 4-6 new indexes created (depending on field name resolution)
```

### 4. Monitor Index Build Status
New indexes may take time to build:

```bash
# Check index status in Firebase Console
# → Firestore → Indexes tab
# → Wait for all indexes to show "Enabled" status
```

### 5. Clean Up Duplicate Indexes (Optional)
If index #1 (daily_quizzes: status + completed_at DESC) is truly duplicate:
- Keep existing quizzes index
- Remove from firestore.indexes.json to avoid confusion

---

## Collection Name Discrepancy

**Issue**: Newly created indexes use `daily_quizzes` collection, existing use `quizzes` collection.

**Investigation Needed**:
1. Check actual collection name in Firestore:
   - Is it `daily_quizzes` or `quizzes`?
   - Are there two separate collections?

2. Check backend code:
   - dailyQuiz.js routes - which collection do they reference?
   - Are quiz documents stored in `users/{userId}/daily_quizzes` or `users/{userId}/quizzes`?

**Likely Scenario**: `daily_quizzes` is a subcollection under users, while existing `quizzes` indexes are for collection group queries.

**Resolution**:
- If `daily_quizzes` is a subcollection: indexes should use `COLLECTION_GROUP` scope
- If separate collection: current indexes are correct

---

## Next Steps

### Immediate Actions
1. ✅ Compare indexes (COMPLETED)
2. ⏳ Verify field names in responses collection (`created_at` vs `answered_at`)
3. ⏳ Verify collection structure (`daily_quizzes` vs `quizzes`)
4. ⏳ Update firestore.indexes.json based on findings
5. ⏳ Deploy updated indexes to Firebase

### Testing After Deployment
1. Test daily quiz queries (should not get "missing index" errors)
2. Monitor Firestore usage in Firebase Console
3. Verify query performance improvements
4. Check for any unused indexes (optimize in future)

---

## Field Name Verification Command

```bash
# Check which timestamp field is used in responses
cd backend
grep -r "created_at\|answered_at" src/routes/dailyQuiz.js

# Check Firestore schema
# (Manual check in Firebase Console → Firestore → responses collection)
```

---

## Summary Table

| Index | Collection | Fields | Status | Action |
|-------|-----------|--------|--------|--------|
| #1 | daily_quizzes | status + completed_at DESC | Duplicate | Skip deployment |
| #2 | daily_quizzes | status + created_at DESC | New | Deploy (verify collection name) |
| #3 | questions | chapter + is_active + difficulty_b | New | ✅ Deploy |
| #4 | questions | chapter + is_active + difficulty_irt | New | ✅ Deploy |
| #5 | responses | question_id + created_at DESC | Field mismatch | Verify then deploy |
| #6 | responses | is_correct + created_at DESC | Field mismatch | Verify then deploy |

**Total New Indexes to Deploy**: 4-6 (depending on verification results)

---

**Status**: Analysis complete, awaiting field verification before deployment
**Next**: Verify `created_at` vs `answered_at` and `daily_quizzes` vs `quizzes` collection names
