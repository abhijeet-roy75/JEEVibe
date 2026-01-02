# Firestore Index Analysis - Comprehensive Review

**Date:** 2025-12-14  
**Engineer:** Senior Database & Backend Engineer Review  
**Purpose:** Identify all required Firestore indexes and ensure proper configuration

## Executive Summary

After thorough analysis of all Firestore queries in the backend, I've identified **critical issues** with the current index configuration:

1. **Mismatch between query types and index definitions** - Some queries are subcollection queries but indexes are defined as collection group indexes
2. **Missing indexes** for several query patterns
3. **Incorrect sort order** in some indexes (ASCENDING vs DESCENDING)
4. **Unnecessary collection group indexes** where subcollection indexes would suffice

## Query Analysis by Collection

### 1. `quizzes` Collection (Subcollection: `daily_quizzes/{userId}/quizzes`)

#### Query Patterns Found:

**A. Active Quiz Query (Multiple locations)**
```javascript
// Location: dailyQuiz.js lines 50, 593, 1133
db.collection('daily_quizzes')
  .doc(userId)
  .collection('quizzes')
  .where('status', '==', 'in_progress')
  .orderBy('generated_at', 'desc')
  .limit(1)
```
**Required Index:** 
- Collection: `quizzes` (subcollection)
- Fields: `status` (ASC), `generated_at` (DESC)
- **Status:** ✅ Defined (index #156: status ASC, generated_at DESC)

**B. Today's Completed Quizzes (Streak Service)**
```javascript
// Location: streakService.js line 76
db.collection('daily_quizzes')
  .doc(userId)
  .collection('quizzes')
  .where('status', '==', 'completed')
  .where('completed_at', '>=', todayStart)
  .where('completed_at', '<=', todayEnd)
```
**Required Index:**
- Collection: `quizzes` (subcollection - NOT collection group!)
- Fields: `status` (ASC), `completed_at` (ASC)
- **Status:** ❌ **CRITICAL ISSUE** - Index #132 is defined as COLLECTION_GROUP but query is subcollection
- **Fix:** This query does NOT need a collection group index. Firestore auto-creates single-field indexes for subcollections, but for composite queries we need a subcollection index.

**C. Today's Completed Quizzes (Summary Endpoint)**
```javascript
// Location: dailyQuiz.js line 1161
db.collection('daily_quizzes')
  .doc(userId)
  .collection('quizzes')
  .where('status', '==', 'completed')
  .where('completed_at', '>=', todayTimestamp)
```
**Required Index:**
- Collection: `quizzes` (subcollection)
- Fields: `status` (ASC), `completed_at` (ASC)
- **Status:** Same issue as B above

**D. Quiz History with Date Range**
```javascript
// Location: dailyQuiz.js line 796
db.collection('daily_quizzes')
  .doc(userId)
  .collection('quizzes')
  .where('status', '==', 'completed')
  // Optional: .where('completed_at', '>=', startDate)
  // Optional: .where('completed_at', '<=', endDate)
```
**Required Index:**
- Collection: `quizzes` (subcollection)
- Fields: `status` (ASC), `completed_at` (ASC)
- **Status:** Same issue as B above

**E. Completed Quizzes Ordered by Date**
```javascript
// Location: streakService.js line 266, progressService.js line 169
db.collection('daily_quizzes')
  .doc(userId)
  .collection('quizzes')
  .where('status', '==', 'completed')
  .orderBy('completed_at', 'desc')
```
**Required Index:**
- Collection: `quizzes` (subcollection)
- Fields: `status` (ASC), `completed_at` (DESC)
- **Status:** ❌ **MISSING** - Need DESCENDING order for this query

**F. Progress by Chapter**
```javascript
// Location: dailyQuiz.js line 1290
db.collection('daily_quizzes')
  .doc(userId)
  .collection('quizzes')
  .where('status', '==', 'completed')
  .where('chapters_covered', 'array-contains', chapter_key)
  .orderBy('completed_at', 'desc')
```
**Required Index:**
- Collection: `quizzes` (subcollection)
- Fields: `status` (ASC), `chapters_covered` (ARRAY_CONTAINS), `completed_at` (DESC)
- **Status:** ✅ Defined (index #141: status ASC, chapters_covered CONTAINS, completed_at DESC)

**G. Weekly Snapshot Queries**
```javascript
// Location: weeklySnapshotService.js line 235, 385
db.collection('daily_quizzes')
  .doc(userId)
  .collection('quizzes')
  .where('completed_at', '>=', weekStart)
  .where('completed_at', '<=', weekEnd)
  .where('status', '==', 'completed')
```
**Required Index:**
- Collection: `quizzes` (subcollection)
- Fields: `status` (ASC), `completed_at` (ASC)
- **Status:** Same issue as B above

### 2. `responses` Collection (Subcollections: `daily_quiz_responses/{userId}/responses` and `assessment_responses/{userId}/responses`)

#### Query Patterns Found:

**A. Review Questions (Spaced Repetition)**
```javascript
// Location: spacedRepetitionService.js line 122, 133
db.collection('daily_quiz_responses')
  .doc(userId)
  .collection('responses')
  .where('answered_at', '>=', cutoffTimestamp)
  .where('is_correct', '==', false)

db.collection('assessment_responses')
  .doc(userId)
  .collection('responses')
  .where('answered_at', '>=', cutoffTimestamp)
  .where('is_correct', '==', false)
```
**Required Index:**
- Collection: `responses` (subcollection - NOT collection group!)
- Fields: `is_correct` (ASC), `answered_at` (ASC)
- **Status:** ❌ **MISSING** - Index #39 exists for collection group but query is subcollection

**B. Recent Questions (Question Selection)**
```javascript
// Location: questionSelectionService.js line 99, 109
db.collection('daily_quiz_responses')
  .doc(userId)
  .collection('responses')
  .where('answered_at', '>=', cutoffTimestamp)

db.collection('assessment_responses')
  .doc(userId)
  .collection('responses')
  .where('answered_at', '>=', cutoffTimestamp)
```
**Required Index:**
- Collection: `responses` (subcollection)
- Fields: `answered_at` (ASC)
- **Status:** ✅ Auto-created by Firestore (single field)

**C. Weekly Snapshot - Responses**
```javascript
// Location: weeklySnapshotService.js line 256, 280, 457, 473
db.collectionGroup('daily_quiz_responses')  // NOTE: collectionGroup!
  .where('answered_at', '>=', weekStart)
  .where('answered_at', '<=', weekEnd)

db.collectionGroup('assessment_responses')  // NOTE: collectionGroup!
  .where('answered_at', '>=', weekStart)
  .where('answered_at', '<=', weekEnd)
```
**Required Index:**
- Collection Group: `daily_quiz_responses` and `assessment_responses`
- Fields: `answered_at` (ASC)
- **Status:** ❌ **MISSING** - No indexes defined for these collection groups

### 3. `questions` Collection

#### Query Patterns Found:

**A. Questions by Subject and Chapter**
```javascript
// Location: questionSelectionService.js line 248
db.collection('questions')
  .where('subject', '==', subject)
  .where('chapter', '==', chapter)
  .limit(MAX_CANDIDATES)
```
**Required Index:**
- Collection: `questions`
- Fields: `subject` (ASC), `chapter` (ASC)
- **Status:** ✅ Auto-created by Firestore (composite equality)

**B. Easy Questions for Recovery**
```javascript
// Location: circuitBreakerService.js line 165
db.collection('questions')
  .where('subject', '==', subject)
  .where('chapter', '==', chapter)
  .where('irt_parameters.difficulty_b', '<=', EASY_DIFFICULTY_MAX)
  .orderBy('irt_parameters.difficulty_b', 'asc')
```
**Required Index:**
- Collection: `questions`
- Fields: `subject` (ASC), `chapter` (ASC), `irt_parameters.difficulty_b` (ASC)
- **Status:** ✅ Defined (index #3: subject ASC, chapter ASC, difficulty_b ASC)

**C. Medium Questions for Recovery**
```javascript
// Location: circuitBreakerService.js line 207
db.collection('questions')
  .where('subject', '==', subject)
  .where('chapter', '==', chapter)
  .where('irt_parameters.difficulty_b', '>', MEDIUM_DIFFICULTY_MIN)
  .where('irt_parameters.difficulty_b', '<=', MEDIUM_DIFFICULTY_MAX)
  .orderBy('irt_parameters.difficulty_b', 'asc')
```
**Required Index:**
- Collection: `questions`
- Fields: `subject` (ASC), `chapter` (ASC), `irt_parameters.difficulty_b` (ASC)
- **Status:** ✅ Same as B above

### 4. Collection Group Queries (Actual Collection Groups)

**A. Responses Collection Group (for analytics)**
```javascript
// Location: Various - but these are actual collection group queries
db.collectionGroup('responses')
  .where('student_id', '==', userId)
  .where('is_correct', '==', false)
  .where('answered_at', '>=', timestamp)
```
**Required Index:**
- Collection Group: `responses`
- Fields: `student_id` (ASC), `is_correct` (ASC), `answered_at` (DESC)
- **Status:** ✅ Defined (index #39)

**B. Quizzes Collection Group (for analytics)**
```javascript
// These queries don't actually exist in the codebase!
// All quiz queries are subcollection queries, not collection group queries
```
**Status:** ⚠️ **UNNECESSARY** - Indexes #83-156 for `quizzes` collection group are NOT needed if all queries are subcollection queries

## Critical Issues Identified

### Issue #1: Subcollection vs Collection Group Confusion
**Problem:** Index #132 is defined as COLLECTION_GROUP for `quizzes`, but all actual queries are subcollection queries.

**Impact:**** The index won't be used, causing Firestore to require a new index each time, leading to repeated errors.

**Root Cause:** The error message from Firestore is misleading - it suggests a collection group index, but the actual query is a subcollection query.

**Solution:** 
1. Remove collection group indexes for `quizzes` that aren't actually used
2. Ensure subcollection queries have proper indexes (Firestore auto-creates some, but composite queries need explicit indexes)

### Issue #2: Missing Subcollection Indexes
**Problem:** Firestore doesn't automatically create composite indexes for subcollections. When you have:
- Multiple `where()` clauses, OR
- `where()` + `orderBy()` on different fields

You need explicit indexes.

**Solution:** We need to define indexes at the subcollection level. However, Firestore's index file format doesn't directly support subcollection indexes - they're created automatically when you run the query and click the link in the error.

**Alternative Solution:** Use collection group queries instead of subcollection queries where possible, OR ensure all composite queries use fields that Firestore can auto-index.

### Issue #3: Sort Order Mismatch
**Problem:** Index #132 has `completed_at` as ASCENDING, but some queries use `orderBy('completed_at', 'desc')`.

**Solution:** We need BOTH indexes:
- `status` (ASC) + `completed_at` (ASC) - for range queries (>=, <=)
- `status` (ASC) + `completed_at` (DESC) - for descending orderBy

## Recommended Actions

### Immediate Fixes (Critical)

1. **Create subcollection index for streak query:**
   - Run the query that's failing
   - Click the link in the error message
   - This will create the proper subcollection index

2. **Add missing index for responses subcollection:**
   - For `daily_quiz_responses/{userId}/responses` with `is_correct` + `answered_at`
   - Run the query and use the error link

3. **Add index for completed quizzes with DESC order:**
   - `status` (ASC) + `completed_at` (DESC)
   - For queries that use `orderBy('completed_at', 'desc')`

### Medium Priority

4. **Review collection group indexes:**
   - Verify if any queries actually use `collectionGroup('quizzes')`
   - If not, these indexes are unnecessary but harmless

5. **Add collection group indexes for weekly snapshots:**
   - `daily_quiz_responses` collection group: `answered_at` (ASC)
   - `assessment_responses` collection group: `answered_at` (ASC)

### Long-term Improvements

6. **Standardize query patterns:**
   - Decide: subcollection queries OR collection group queries?
   - Collection group queries are more flexible but require explicit indexes
   - Subcollection queries are simpler but have index limitations

7. **Document all query patterns:**
   - Maintain a query registry
   - Map each query to its required index
   - Update when adding new queries

## Index Inventory

### Currently Defined Indexes (firestore.indexes.json)

1. ✅ `questions`: subject + chapter + difficulty_b (ASC)
2. ✅ `questions`: subject + chapter + discrimination_a (DESC)
3. ✅ `questions`: subject + chapter + question_id (ASC)
4. ✅ `responses` (CG): student_id + answered_at (DESC)
5. ✅ `responses` (CG): student_id + is_correct + answered_at (DESC)
6. ✅ `responses` (CG): student_id + chapter_key + answered_at (DESC)
7. ✅ `responses` (CG): is_correct + answered_at + __name__ (ASC)
8. ✅ `responses` (CG): student_id + quiz_id + question_position (ASC)
9. ✅ `responses` (CG): question_id + answered_at (DESC)
10. ✅ `quizzes` (CG): student_id + quiz_number (DESC)
11. ✅ `quizzes` (CG): student_id + completed_at (DESC)
12. ✅ `quizzes` (CG): student_id + learning_phase + completed_at (DESC)
13. ✅ `snapshots` (CG): student_id + week_end (DESC)
14. ✅ `snapshots` (CG): student_id + week_number (ASC)
15. ✅ `initial_assessment_questions`: subject + difficulty + question_id (ASC)
16. ⚠️ `quizzes` (CG): status + completed_at (ASC) + __name__ (ASC) - **May not be used**
17. ✅ `quizzes` (CG): status + chapters_covered (CONTAINS) + completed_at (DESC)
18. ✅ `quizzes` (CG): status + generated_at (DESC)

### Missing Indexes (Required)

1. ❌ `quizzes` (subcollection): status (ASC) + completed_at (DESC) - for orderBy desc
2. ❌ `responses` (subcollection): is_correct (ASC) + answered_at (ASC) - for review questions
3. ❌ `daily_quiz_responses` (CG): answered_at (ASC) - for weekly snapshots
4. ❌ `assessment_responses` (CG): answered_at (ASC) - for weekly snapshots

## Conclusion

The main issue is that **Firestore's error messages are misleading** - they suggest collection group indexes even for subcollection queries. The actual solution is to:

1. **Run the failing queries** and use Firestore's auto-generated index links
2. **Document which queries are subcollection vs collection group**
3. **Create a comprehensive index registry** that maps queries to indexes
4. **Consider refactoring** some queries to use collection groups if it simplifies index management

The current index file is mostly correct, but we're missing some subcollection indexes that Firestore can't auto-detect from the JSON file format.

