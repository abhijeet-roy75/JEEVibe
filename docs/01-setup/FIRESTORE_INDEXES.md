# Firestore Indexes Required for Initial Assessment

**Status:** ⚠️ **MUST CREATE BEFORE DEPLOYMENT**

These indexes are required for the assessment system to work properly. Queries will fail without them.

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

### 1. Initial Assessment Questions - By Subject and Difficulty

**Collection:** `initial_assessment_questions`

**Fields:**
- `subject` (Ascending)
- `difficulty` (Ascending)
- `question_id` (Ascending)

**Purpose:** Used for stratified randomization (grouping questions by subject+difficulty)

**Query Scope:** Collection

**Status:** ⚠️ **REQUIRED**

---

### 2. Assessment Responses - By Chapter Key

**Collection Group:** `responses` ⚠️ **IMPORTANT: Use collection name only, not full path**

**Fields:**
- `chapter_key` (Ascending)
- `answered_at` (Descending)

**Purpose:** Used for grouping responses by chapter for theta calculation

**Query Scope:** **Collection Group** (not Collection!)

**How to Create in Firebase Console:**
1. Click **Create Index**
2. Select **Collection group** (NOT "Collection")
3. Enter collection ID: `responses` (just "responses", not the full path)
4. Add fields:
   - `chapter_key` (Ascending)
   - `answered_at` (Descending)
5. Click **Create**

**Note:** The actual path is `assessment_responses/{userId}/responses`, but for collection group indexes, you only use the collection name `responses`.

**Status:** ⚠️ **REQUIRED**

---

### 3. Users - By Assessment Status

**Collection:** `users`

**Fields:**
- `assessment.status` (Ascending)

**Purpose:** ~~Used to find users who need to complete assessment~~ (Not currently used)

**Query Scope:** Collection

**Status:** ❌ **NOT NEEDED** - We only read individual user documents by ID, not querying by status

**Note:** Firebase will show "this index is not necessary" because we're not actually querying by this field. We only do `users.doc(userId).get()` which doesn't require an index. You can skip this index.

---

### 4. Users - By Learning Phase and Quiz Count

**Collection:** `users`

**Fields:**
- `learning_phase` (Ascending)
- `completed_quiz_count` (Ascending)

**Purpose:** Used for analytics and phase transition tracking

**Query Scope:** Collection

**Status:** 🟡 **OPTIONAL** (for analytics, not critical for MVP)

---

## Firebase CLI Configuration

If using Firebase CLI, create `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "initial_assessment_questions",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "subject",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "difficulty",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "question_id",
          "order": "ASCENDING"
        }
      ]
    },
    {
      "collectionGroup": "responses",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        {
          "fieldPath": "chapter_key",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "answered_at",
          "order": "DESCENDING"
        }
      ]
    },
    // Index 3 removed - not needed (we only read documents by ID, not querying by status)
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "learning_phase",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "completed_quiz_count",
          "order": "ASCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
```

---

## Verification

After creating indexes, verify they're building:
1. Go to Firebase Console → Firestore → Indexes
2. Check status: Should show "Enabled" (may take a few minutes to build)
3. Test queries to ensure they work

---

## Notes

- Indexes are **free** to create
- Index building may take a few minutes for large collections
- Queries will fail with "index required" error if indexes are missing
- Indexes are automatically maintained by Firebase

---

**Action Required:** Create indexes 1 and 2 before deploying to production. Index 3 is not needed.
