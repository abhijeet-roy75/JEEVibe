# Firestore Index Fix Plan

## Root Cause Analysis

The error message suggests a collection group index, but the actual query in `streakService.js` is a **subcollection query**:
```javascript
db.collection('daily_quizzes')
  .doc(userId)
  .collection('quizzes')  // This is a subcollection, not a collection group
  .where('status', '==', 'completed')
  .where('completed_at', '>=', todayStart)
  .where('completed_at', '<=', todayEnd)
```

**Key Insight:** Firestore's error messages can be misleading. For subcollection queries with range filters on the same field (>= and <=), you need:
1. The range field in **ASCENDING** order (regardless of whether you use orderBy)
2. The index can be either a subcollection index OR a collection group index (both work)

## Immediate Fix

The index we created (status ASC + completed_at ASC + __name__ ASC) should work, but it may take time to build. However, we should also ensure we have the DESCENDING version for queries that use `orderBy('completed_at', 'desc')`.

## Action Items

1. ✅ **Already Fixed:** Index for `status` + `completed_at` (ASC) with `__name__`
2. **Add:** Index for `status` + `completed_at` (DESC) for orderBy queries
3. **Verify:** All other query patterns have proper indexes

## Testing Strategy

After indexes are built:
1. Test `/api/daily-quiz/summary` endpoint
2. Test streak calculation
3. Test quiz history with date filters
4. Monitor for any new index errors

