# Firestore Index Deployment Strategy

**Date**: January 1, 2026
**Status**: Ready for Implementation
**Based on**: Complete schema analysis + query pattern analysis

---

## Executive Summary

**Current Status**: Database structure is **GOOD (7.5/10)** - well-designed with proper denormalization

**Index Status**: ⚠️ **NEEDS CLEANUP** - Existing indexes have duplicates and missing critical indexes

**Action Required**:
1. Fix critical missing index (review questions feature broken)
2. Add adaptive difficulty indexes (P1 backend fix)
3. Remove unnecessary duplicates
4. Deploy clean index configuration

---

## Critical Finding: Structure is Good ✅

Based on comprehensive schema analysis, **NO structural changes needed before index deployment**.

### Database Strengths
1. ✅ **Proper hierarchy**: Subcollections for user-scoped data
2. ✅ **Excellent denormalization**: `cumulative_stats` reduces 500 reads → 1 read (99.8% reduction)
3. ✅ **Atomic transactions**: Quiz completion uses single transaction correctly
4. ✅ **Pre-calculation pattern**: Theta updates calculated outside transaction (prevents timeout)
5. ✅ **Batch operations**: Response writes use batches efficiently

### Minor Issues Found (Non-blocking)
- **Medium**: Unbounded array growth in `weekly_stats` (monitor, not urgent)
- **Medium**: Large quiz documents with embedded questions (safe now, optimize later)
- **Low**: Inconsistent IRT parameter naming (has fallback, works fine)

**Conclusion**: Database structure is production-ready. Proceed with index deployment.

---

## Required Indexes Analysis

### Critical Indexes (Deploy Immediately)

#### 1. Review Questions Index ⚠️ **MISSING - BREAKS FEATURE**

**Query**:
```javascript
// spacedRepetitionService.js:118-126
db.collectionGroup('responses')
  .where('student_id', '==', userId)
  .where('answered_at', '>=', sevenDaysAgo)
  .where('is_correct', '==', false)
```

**Index Required**:
```json
{
  "collectionGroup": "responses",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "student_id", "order": "ASCENDING" },
    { "fieldPath": "is_correct", "order": "ASCENDING" },
    { "fieldPath": "answered_at", "order": "DESCENDING" }
  ]
}
```

**Impact if Missing**: Review questions feature silently fails (returns empty array)

#### 2. Adaptive Difficulty - Chapter + Active + Difficulty (P1 Backend Fix)

**Queries**:
```javascript
// questionSelectionService.js:82-86, 94-98
db.collection('questions')
  .where('chapter', '==', chapterKey)
  .where('is_active', '==', true)
  .orderBy('difficulty_b', 'asc')  // or difficulty_irt

// Used by: Daily quiz generation (adaptive threshold feature from P1 fixes)
```

**Indexes Required** (2 indexes):
```json
{
  "collectionGroup": "questions",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "chapter", "order": "ASCENDING" },
    { "fieldPath": "is_active", "order": "ASCENDING" },
    { "fieldPath": "difficulty_b", "order": "ASCENDING" }
  ]
},
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

**Impact if Missing**: Adaptive difficulty threshold won't work (quiz generation falls back to all questions)

---

### Existing Indexes Analysis

**Total Existing**: 19 composite indexes (deployed)

#### Useful Existing Indexes ✅
1. **questions** - subject + chapter + irt_parameters.difficulty_b
2. **questions** - subject + chapter + irt_parameters.discrimination_a (DESC)
3. **questions** - subject + chapter + question_id
4. **quizzes** - status + completed_at (DESC) - Used by daily quiz queries
5. **quizzes** - status + chapters_covered (ARRAY) + completed_at (DESC)
6. **quizzes** - student_id + completed_at (DESC)
7. **quizzes** - student_id + learning_phase + completed_at (DESC)
8. **responses** - student_id + answered_at (DESC)
9. **responses** - student_id + chapter_key + answered_at (DESC)
10. **responses** - student_id + quiz_id + question_position
11. **snapshots** - student_id + week_end (DESC)
12. **snapshots** - student_id + week_number

#### Duplicate/Unused Indexes ⚠️
1. **quizzes** - status + completed_at (ASC) - **DUPLICATE** of #4 (can remove, DESC covers ASC)
2. **quizzes** - status + generated_at (DESC) - **UNUSED** (code uses `generated_at` only, no `where` on status)
3. **responses** - is_correct + answered_at (DESC) - **PARTIAL** (missing student_id, not useful globally)
4. **responses** - question_id + answered_at (DESC) - **UNUSED** (no queries fetch all responses for a question)

#### Missing Critical Indexes ❌
1. **responses** - student_id + is_correct + answered_at (DESC) - **MISSING** (review questions)
2. **questions** - chapter + is_active + difficulty_b (ASC) - **MISSING** (adaptive difficulty)
3. **questions** - chapter + is_active + difficulty_irt (ASC) - **MISSING** (adaptive difficulty fallback)

---

## Comprehensive Index Deployment Plan

### Recommended firestore.indexes.json

```json
{
  "indexes": [
    {
      "comment": "Daily quiz queries - status filter + completion date sort",
      "collectionGroup": "quizzes",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "completed_at", "order": "DESCENDING" }
      ]
    },
    {
      "comment": "Quiz history by user - most recent first",
      "collectionGroup": "quizzes",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "completed_at", "order": "DESCENDING" }
      ]
    },
    {
      "comment": "Quiz history by learning phase",
      "collectionGroup": "quizzes",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "learning_phase", "order": "ASCENDING" },
        { "fieldPath": "completed_at", "order": "DESCENDING" }
      ]
    },
    {
      "comment": "Quiz history with chapter filter",
      "collectionGroup": "quizzes",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "chapters_covered", "arrayConfig": "CONTAINS" },
        { "fieldPath": "completed_at", "order": "DESCENDING" }
      ]
    },
    {
      "comment": "Quiz position tracking for user",
      "collectionGroup": "quizzes",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "quiz_number", "order": "DESCENDING" }
      ]
    },
    {
      "comment": "Question selection - subject + chapter + IRT difficulty",
      "collectionGroup": "questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "subject", "order": "ASCENDING" },
        { "fieldPath": "chapter", "order": "ASCENDING" },
        { "fieldPath": "irt_parameters.difficulty_b", "order": "ASCENDING" }
      ]
    },
    {
      "comment": "Question selection - discrimination parameter (for filtering high-quality questions)",
      "collectionGroup": "questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "subject", "order": "ASCENDING" },
        { "fieldPath": "chapter", "order": "ASCENDING" },
        { "fieldPath": "irt_parameters.discrimination_a", "order": "DESCENDING" }
      ]
    },
    {
      "comment": "Question lookup by identifiers",
      "collectionGroup": "questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "subject", "order": "ASCENDING" },
        { "fieldPath": "chapter", "order": "ASCENDING" },
        { "fieldPath": "question_id", "order": "ASCENDING" }
      ]
    },
    {
      "comment": "⚠️ NEW - Adaptive difficulty: chapter + active status + difficulty_b",
      "collectionGroup": "questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "chapter", "order": "ASCENDING" },
        { "fieldPath": "is_active", "order": "ASCENDING" },
        { "fieldPath": "difficulty_b", "order": "ASCENDING" }
      ]
    },
    {
      "comment": "⚠️ NEW - Adaptive difficulty: chapter + active status + difficulty_irt (fallback)",
      "collectionGroup": "questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "chapter", "order": "ASCENDING" },
        { "fieldPath": "is_active", "order": "ASCENDING" },
        { "fieldPath": "difficulty_irt", "order": "ASCENDING" }
      ]
    },
    {
      "comment": "Assessment question selection",
      "collectionGroup": "initial_assessment_questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "subject", "order": "ASCENDING" },
        { "fieldPath": "difficulty", "order": "ASCENDING" },
        { "fieldPath": "question_id", "order": "ASCENDING" }
      ]
    },
    {
      "comment": "User response history - recent responses",
      "collectionGroup": "responses",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "answered_at", "order": "DESCENDING" }
      ]
    },
    {
      "comment": "Response history by chapter",
      "collectionGroup": "responses",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "chapter_key", "order": "ASCENDING" },
        { "fieldPath": "answered_at", "order": "DESCENDING" }
      ]
    },
    {
      "comment": "Quiz response retrieval in order",
      "collectionGroup": "responses",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "quiz_id", "order": "ASCENDING" },
        { "fieldPath": "question_position", "order": "ASCENDING" }
      ]
    },
    {
      "comment": "🔴 CRITICAL - Review questions: incorrect responses in last 7 days",
      "collectionGroup": "responses",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "is_correct", "order": "ASCENDING" },
        { "fieldPath": "answered_at", "order": "DESCENDING" }
      ]
    },
    {
      "comment": "Weekly progress snapshots",
      "collectionGroup": "snapshots",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "week_end", "order": "DESCENDING" }
      ]
    },
    {
      "comment": "Weekly snapshots by week number",
      "collectionGroup": "snapshots",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "week_number", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

### Index Count: 17 Indexes
- **Existing (kept)**: 12 indexes
- **New (critical)**: 3 indexes
- **Removed (duplicates/unused)**: 4 indexes
- **Net change**: -1 index (cleaner, more efficient)

---

## What Was Removed (and Why)

### 1. ❌ Removed: `quizzes` - status + completed_at (ASC)
**Reason**: Duplicate - Firestore can use DESC index for ASC queries
**Original**:
```json
{
  "collectionGroup": "quizzes",
  "fields": [
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "completed_at", "order": "ASCENDING" }
  ]
}
```
**Kept instead**: status + completed_at (DESC) - more commonly used

### 2. ❌ Removed: `quizzes` - status + generated_at (DESC)
**Reason**: No code queries with `where('status') + orderBy('generated_at')`
**Actual queries use**: `orderBy('generated_at')` alone (doesn't need composite index)

### 3. ❌ Removed: `responses` - is_correct + answered_at (global)
**Reason**: No queries fetch global responses by correctness
**Queries are always scoped to user**: `where('student_id', '==', userId).where('is_correct'...)`

### 4. ❌ Removed: `responses` - question_id + answered_at (global)
**Reason**: No queries fetch all responses for a specific question across all users
**Current usage**: Questions don't track response history

---

## Deployment Instructions

### Step 1: Backup Current Indexes
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/backend
firebase firestore:indexes > firestore.indexes.backup.json
```

### Step 2: Replace firestore.indexes.json
Replace current file with the recommended configuration above.

### Step 3: Deploy Indexes
```bash
firebase deploy --only firestore:indexes
```

**Expected Output**:
```
✔ Deploy complete!
Deploying indexes...
  ✔ Creating index: responses (student_id, is_correct, answered_at)
  ✔ Creating index: questions (chapter, is_active, difficulty_b)
  ✔ Creating index: questions (chapter, is_active, difficulty_irt)
  ⚠ Deleting unused index: quizzes (status, completed_at ASC)
  ⚠ Deleting unused index: quizzes (status, generated_at)
  ⚠ Deleting unused index: responses (is_correct, answered_at)
  ⚠ Deleting unused index: responses (question_id, answered_at)
```

### Step 4: Monitor Index Build Status
```bash
# Check Firebase Console
# → Firestore → Indexes tab
# → Wait for all indexes to show "Enabled" (may take 5-30 minutes)
```

**Build Time Estimates**:
- Small collections (<1000 docs): 1-5 minutes
- Medium collections (1000-10000 docs): 5-15 minutes
- Large collections (>10000 docs): 15-60 minutes

### Step 5: Verify Index Usage
```bash
# Test review questions feature
curl -X POST https://your-api.com/api/daily-quiz/generate \
  -H "Authorization: Bearer $TOKEN"

# Check logs for "Review questions query requires Firestore index" warning
# Should NOT appear after deployment
```

---

## Testing Checklist

### Critical Feature Tests

- [ ] **Review Questions** (uses new index #15)
  - Generate daily quiz
  - Verify review questions appear (if user has incorrect responses from last 7 days)
  - Check logs - no "missing index" warnings

- [ ] **Adaptive Difficulty** (uses new indexes #9, #10)
  - Generate quiz with user at high theta (>2.0)
  - Verify >=10 questions returned (threshold relaxation working)
  - Generate quiz with user at low theta (<-2.0)
  - Verify >=10 questions returned

- [ ] **Quiz History** (existing indexes)
  - Fetch quiz history with filters
  - Verify fast response times (<500ms)

- [ ] **Question Selection** (existing indexes)
  - Generate quiz
  - Verify questions match user's chapters
  - Verify no "missing index" errors

### Performance Benchmarks

**Before Deployment**:
```bash
# Time quiz generation
time curl -X POST .../api/daily-quiz/generate
```

**After Deployment**:
```bash
# Should be same or faster (missing indexes cause slower queries)
time curl -X POST .../api/daily-quiz/generate
```

**Expected**:
- Quiz generation: <2 seconds
- Quiz completion: <3 seconds
- Progress API: <500ms (single read)

---

## Rollback Plan

If critical issues found:

### Option 1: Revert Index Configuration
```bash
cp firestore.indexes.backup.json firestore.indexes.json
firebase deploy --only firestore:indexes
```

**Time**: 5-30 minutes (index rebuild)

### Option 2: Keep Indexes, Disable Feature
```javascript
// Temporary: Disable review questions
const ENABLE_REVIEW_QUESTIONS = false;

if (ENABLE_REVIEW_QUESTIONS) {
  reviewQuestions = await getReviewQuestions(userId);
}
```

**Time**: 1 minute (code change + deploy)

---

## Post-Deployment Monitoring

### Firebase Console Metrics (7 days)

1. **Index Usage**:
   - Firestore → Usage tab → "Index Operations"
   - Verify new indexes being used

2. **Query Performance**:
   - Check p95 latency for quiz generation
   - Should be <2 seconds

3. **Error Rates**:
   - Check for "missing index" errors
   - Should be 0

### Application Logs

```bash
# Check for index warnings
grep "Firestore index" logs/backend.log

# Should return 0 results after deployment
```

---

## Summary

**Index Strategy**: ✅ **READY TO DEPLOY**

**Changes**:
- ➕ Add 3 critical missing indexes
- ➖ Remove 4 duplicate/unused indexes
- ✅ Keep 12 existing useful indexes
- **Total**: 17 indexes (down from 19, cleaner configuration)

**Impact**:
- ✅ Fixes review questions feature (currently broken)
- ✅ Enables adaptive difficulty (P1 backend fix)
- ✅ Removes index bloat (faster index updates)
- ✅ No structural changes needed (database is well-designed)

**Recommendation**: **Deploy now** - All indexes are well-justified by actual queries, no structural blockers.
