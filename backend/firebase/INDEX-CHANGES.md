# Firestore Index Changes

## Data Extraction Script Indexes

Added 4 new composite indexes to support the student data extraction script (`backend/scripts/extract-student-data.js`).

### Indexes Added (2026-02-07)

#### 1. Assessment Responses by User
**Collection:** `assessment_responses`
**Query:** Filter by `user_id` + Sort by `completed_at` (DESC)
**Used by:** `extractAssessment()` function
**Purpose:** Retrieve all assessments for a student, most recent first

```javascript
db.collection('assessment_responses')
  .where('user_id', '==', userId)
  .orderBy('completed_at', 'desc')
```

**Index Fields:**
- `user_id` (ASCENDING)
- `completed_at` (DESCENDING)

---

#### 2. Chapter Practice Sessions by User
**Collection:** `chapter_practice_sessions`
**Query:** Filter by `user_id` + Sort by `started_at` (DESC)
**Used by:** `extractChapterPractice()` function
**Purpose:** Retrieve all chapter practice sessions for a student, most recent first

```javascript
db.collection('chapter_practice_sessions')
  .where('user_id', '==', userId)
  .orderBy('started_at', 'desc')
```

**Index Fields:**
- `user_id` (ASCENDING)
- `started_at` (DESCENDING)

---

#### 3. Theta Snapshots by User
**Collection:** `theta_snapshots`
**Query:** Filter by `user_id` + Sort by `snapshot_date` (ASC)
**Used by:** `extractThetaEvolution()` function
**Purpose:** Retrieve weekly theta snapshots for a student in chronological order

```javascript
db.collection('theta_snapshots')
  .where('user_id', '==', userId)
  .orderBy('snapshot_date', 'asc')
```

**Index Fields:**
- `user_id` (ASCENDING)
- `snapshot_date` (ASCENDING)

---

#### 4. Daily Usage by User
**Collection:** `daily_usage`
**Query:** Filter by `user_id` + Sort by `date` (DESC)
**Used by:** `extractUsageMetrics()` function
**Purpose:** Retrieve daily usage logs for a student, most recent first

```javascript
db.collection('daily_usage')
  .where('user_id', '==', userId)
  .orderBy('date', 'desc')
```

**Index Fields:**
- `user_id` (ASCENDING)
- `date` (DESCENDING)

---

## Index Deployment

### Deploy to Firestore

```bash
# From project root
firebase deploy --only firestore:indexes

# Or using Firebase CLI
cd backend/firebase
firebase deploy --only firestore:indexes --project jeevibe-prod
```

### Verify Deployment

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Navigate to Firestore Database → Indexes
3. Verify all 4 indexes show "Enabled" status

### Index Build Time

- Small collections (<1000 docs): ~1-2 minutes
- Medium collections (1000-10000 docs): ~5-10 minutes
- Large collections (>10000 docs): ~15-30 minutes

---

## Existing Indexes (Not Modified)

The following existing indexes were **not modified**:
- Daily quiz queries (quizzes collection group)
- Question selection indexes (questions collection)
- Response history indexes (responses collection group)
- Weekly snapshots indexes (snapshots collection group)
- AI Tutor indexes (messages collection)
- Chapter practice session indexes (sessions collection group)
- Content moderation indexes (moderation_flags, moderation_alerts)
- Teacher integration indexes (teachers, teacher_reports)

---

## Performance Impact

**Query Performance Before Indexes:**
- ❌ Full collection scan required
- ❌ High read costs (reads entire collection)
- ❌ Slow query times (>1 second for large collections)
- ❌ May timeout for users with lots of data

**Query Performance After Indexes:**
- ✅ Index-backed queries
- ✅ Low read costs (reads only matching documents)
- ✅ Fast query times (<100ms)
- ✅ Scales with user data

---

## Index Maintenance

### Monitoring

Check index usage in Firebase Console:
1. Firestore → Usage tab
2. Monitor read/write operations
3. Check for unused indexes (can be deleted)

### Cost

- **Storage Cost:** Negligible (~$0.01/month for 4 indexes)
- **Write Cost:** Small increase (each write also updates indexes)
- **Read Cost:** Significant savings (no full collection scans)

### Best Practices

✅ **DO:**
- Add indexes before running queries in production
- Test queries with indexes in development first
- Monitor index usage and remove unused indexes
- Document all indexes with comments

❌ **DON'T:**
- Deploy indexes without testing queries first
- Create duplicate indexes (Firestore auto-suggests some)
- Delete indexes that are actively used
- Create indexes for single-field queries (Firestore auto-indexes)

---

## Troubleshooting

### Error: "The query requires an index"

If you see this error, it means:
1. The index hasn't been deployed yet → Run `firebase deploy --only firestore:indexes`
2. The index is still building → Wait for completion (check Firebase Console)
3. The query doesn't match the index → Check field names and sort order

### Error: "Index already exists"

This is harmless and means:
- Firebase auto-created the index from a previous query
- The index is already deployed

You can safely ignore this warning.

---

## Related Files

- **Index Config:** [firestore.indexes.json](./firestore.indexes.json)
- **Extraction Script:** [backend/scripts/extract-student-data.js](../scripts/extract-student-data.js)
- **Data Schema Docs:** [docs/DATA-COLLECTION-REFERENCE.md](../../docs/DATA-COLLECTION-REFERENCE.md)
- **Firestore Rules:** [firestore.rules](./firestore.rules)

---

**Last Updated:** 2026-02-07
**Deployed By:** [Your Name]
**Environment:** Production (jeevibe-prod)
