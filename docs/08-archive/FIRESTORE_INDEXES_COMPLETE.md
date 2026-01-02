# Complete Firestore Indexes for Daily Adaptive Quiz System

**Status:** ⚠️ **MUST CREATE BEFORE DEPLOYMENT**

This document lists ALL Firestore indexes required for the complete daily adaptive quiz system, including initial assessment and daily quiz features.

---

## How to Create Indexes

### Option 1: Firebase Console (Recommended)
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database** → **Indexes**
4. Click **Create Index**
5. **IMPORTANT:** For subcollections, select **"Collection group"** (not "Collection")
6. Follow the instructions below for each index

### Option 2: Firebase CLI
1. Create `firestore.indexes.json` file (see below)
2. Run: `firebase deploy --only firestore:indexes`

---

## Required Indexes

### 1. Questions Collection - Subject + Chapter + Difficulty

**Collection:** `questions`

**Fields:**
- `subject` (Ascending)
- `chapter` (Ascending)
- `irt_parameters.difficulty_b` (Ascending)

**Purpose:** Query questions by subject+chapter with difficulty filtering for IRT-based selection

**Query Scope:** Collection

**Status:** ⚠️ **REQUIRED**

---

### 2. Questions Collection - Subject + Chapter + Discrimination

**Collection:** `questions`

**Fields:**
- `subject` (Ascending)
- `chapter` (Ascending)
- `irt_parameters.discrimination_a` (Descending)

**Purpose:** Query questions by subject+chapter sorted by discrimination (higher is better)

**Query Scope:** Collection

**Status:** ⚠️ **REQUIRED**

---

### 3. Questions Collection - Subject + Chapter + Question ID

**Collection:** `questions`

**Fields:**
- `subject` (Ascending)
- `chapter` (Ascending)
- `question_id` (Ascending)

**Purpose:** Query questions by subject+chapter with deterministic ordering

**Query Scope:** Collection

**Status:** ⚠️ **REQUIRED**

---

### 4. Assessment Responses - By Student and Date

**Collection Group:** `responses` ⚠️ **IMPORTANT: Use collection name only**

**Fields:**
- `student_id` (Ascending)
- `answered_at` (Descending)

**Purpose:** Get all assessment responses for a student, sorted by date

**Query Scope:** **Collection Group**

**Note:** Actual path is `assessment_responses/{userId}/responses`, but use `responses` as collection group name.

**Status:** ⚠️ **REQUIRED**

---

### 5. Assessment Responses - By Student, Chapter, and Date

**Collection Group:** `responses`

**Fields:**
- `student_id` (Ascending)
- `chapter_key` (Ascending)
- `answered_at` (Descending)

**Purpose:** Group assessment responses by chapter for theta calculation

**Query Scope:** **Collection Group**

**Status:** ⚠️ **REQUIRED**

---

### 6. Daily Quiz Responses - By Student and Date

**Collection Group:** `responses` ⚠️ **Same collection name as assessment responses**

**Fields:**
- `student_id` (Ascending)
- `answered_at` (Descending)

**Purpose:** Get all daily quiz responses for a student, sorted by date

**Query Scope:** **Collection Group**

**Note:** Actual path is `daily_quiz_responses/{userId}/responses`, but use `responses` as collection group name.

**Status:** ⚠️ **REQUIRED**

---

### 7. Daily Quiz Responses - By Student, Chapter, and Date

**Collection Group:** `responses`

**Fields:**
- `student_id` (Ascending)
- `chapter_key` (Ascending)
- `answered_at` (Descending)

**Purpose:** Group daily quiz responses by chapter for analytics

**Query Scope:** **Collection Group**

**Status:** ⚠️ **REQUIRED**

---

### 8. Daily Quiz Responses - By Student, Correctness, and Date

**Collection Group:** `responses`

**Fields:**
- `student_id` (Ascending)
- `is_correct` (Ascending)
- `answered_at` (Descending)

**Purpose:** Filter responses by correctness for analytics

**Query Scope:** **Collection Group**

**Status:** ⚠️ **REQUIRED**

---

### 9. Daily Quiz Responses - By Student, Quiz ID, and Position

**Collection Group:** `responses`

**Fields:**
- `student_id` (Ascending)
- `quiz_id` (Ascending)
- `question_position` (Ascending)

**Purpose:** Get all responses for a specific quiz in order

**Query Scope:** **Collection Group**

**Status:** ⚠️ **REQUIRED**

---

### 10. Daily Quiz Responses - By Question ID (Collection Group)

**Collection Group:** `responses`

**Fields:**
- `question_id` (Ascending)

**Purpose:** Aggregate question statistics across all users (for weekly job)

**Query Scope:** **Collection Group**

**Status:** ⚠️ **REQUIRED** (for question stats aggregation)

---

### 11. Daily Quizzes - By Student and Quiz Number

**Collection Group:** `quizzes` ⚠️ **Use collection name only**

**Fields:**
- `student_id` (Ascending)
- `quiz_number` (Descending)

**Purpose:** Get quiz history sorted by quiz number

**Query Scope:** **Collection Group**

**Note:** Actual path is `daily_quizzes/{userId}/quizzes`, but use `quizzes` as collection group name.

**Status:** ⚠️ **REQUIRED**

---

### 12. Daily Quizzes - By Student and Completion Date

**Collection Group:** `quizzes`

**Fields:**
- `student_id` (Ascending)
- `completed_at` (Descending)

**Purpose:** Get quizzes sorted by completion date for weekly snapshots

**Query Scope:** **Collection Group**

**Status:** ⚠️ **REQUIRED**

---

### 13. Daily Quizzes - By Student, Phase, and Date

**Collection Group:** `quizzes`

**Fields:**
- `student_id` (Ascending)
- `learning_phase` (Ascending)
- `completed_at` (Descending)

**Purpose:** Filter quizzes by learning phase for analytics

**Query Scope:** **Collection Group**

**Status:** ⚠️ **REQUIRED**

---

### 14. Theta History Snapshots - By Student and Week End

**Collection Group:** `snapshots` ⚠️ **Use collection name only**

**Fields:**
- `student_id` (Ascending)
- `week_end` (Descending)

**Purpose:** Get weekly snapshots sorted by week end date

**Query Scope:** **Collection Group**

**Note:** Actual path is `theta_history/{userId}/snapshots`, but use `snapshots` as collection group name.

**Status:** ⚠️ **REQUIRED**

---

### 15. Theta History Snapshots - By Student and Week Number

**Collection Group:** `snapshots`

**Fields:**
- `student_id` (Ascending)
- `week_number` (Ascending)

**Purpose:** Get snapshots sorted by week number for trend analysis

**Query Scope:** **Collection Group**

**Status:** ⚠️ **REQUIRED**

---

## Firebase CLI Configuration

Create `firestore.indexes.json` in your project root:

```json
{
  "indexes": [
    {
      "collectionGroup": "questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "subject", "order": "ASCENDING" },
        { "fieldPath": "chapter", "order": "ASCENDING" },
        { "fieldPath": "irt_parameters.difficulty_b", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "subject", "order": "ASCENDING" },
        { "fieldPath": "chapter", "order": "ASCENDING" },
        { "fieldPath": "irt_parameters.discrimination_a", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "subject", "order": "ASCENDING" },
        { "fieldPath": "chapter", "order": "ASCENDING" },
        { "fieldPath": "question_id", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "responses",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "answered_at", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "responses",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "chapter_key", "order": "ASCENDING" },
        { "fieldPath": "answered_at", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "responses",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "is_correct", "order": "ASCENDING" },
        { "fieldPath": "answered_at", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "responses",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "quiz_id", "order": "ASCENDING" },
        { "fieldPath": "question_position", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "responses",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "question_id", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "quizzes",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "quiz_number", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "quizzes",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "completed_at", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "quizzes",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "learning_phase", "order": "ASCENDING" },
        { "fieldPath": "completed_at", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "snapshots",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "student_id", "order": "ASCENDING" },
        { "fieldPath": "week_end", "order": "DESCENDING" }
      ]
    },
    {
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

---

## Important Notes

### Collection Groups vs Collections

- **Collection Groups:** Used for subcollections (e.g., `responses`, `quizzes`, `snapshots`)
  - Use only the collection name, not the full path
  - Example: `responses` (not `assessment_responses/{userId}/responses`)
  
- **Collections:** Used for top-level collections (e.g., `questions`)
  - Use the full collection name

### Index Building Time

- Indexes are **free** to create
- Building may take a few minutes to several hours depending on collection size
- Queries will fail with "index required" error if indexes are missing
- Check index status in Firebase Console → Firestore → Indexes

### Verification

After creating indexes:
1. Go to Firebase Console → Firestore → Indexes
2. Check status: Should show "Enabled" (may take time to build)
3. Test queries to ensure they work
4. Monitor query performance

---

## Index Summary

| Collection/Group | Index Count | Type |
|-----------------|-------------|------|
| `questions` | 3 | Collection |
| `responses` (assessment + daily) | 5 | Collection Group |
| `quizzes` | 3 | Collection Group |
| `snapshots` | 2 | Collection Group |
| **Total** | **13** | |

---

## Action Required

⚠️ **Create all 13 indexes before deploying to production.**

Queries will fail without these indexes. Start with the most critical ones:
1. Questions indexes (for quiz generation)
2. Responses indexes (for theta calculation)
3. Quizzes indexes (for progress tracking)
4. Snapshots indexes (for weekly jobs)

