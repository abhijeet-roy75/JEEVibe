# Theta Storage Strategy - Historical vs Current Values

## Question

**Do we store theta values and changes over time, or only single current theta values?**

## Answer: Hybrid Approach

We use a **hybrid approach** that balances storage efficiency with analytics needs:

1. **Current Values** - Stored in `users/{userId}` (updated after each quiz)
2. **Baseline Snapshot** - Stored in `users/{userId}.assessment_baseline` (set once, never updated)
3. **Historical Snapshots** - Optional: Stored in `theta_history/{userId}/snapshots/{snapshotId}` (weekly or per-quiz)

---

## Storage Strategy

### 1. Current Values (Always Stored)

**Location:** `users/{userId}` document

**Fields:**
- `theta_by_chapter` - Current chapter-level theta (updated after each quiz)
- `theta_by_subject` - Current subject-level theta (recalculated after each quiz)
- `overall_theta` - Current overall theta (recalculated after each quiz)

**Purpose:**
- Used for quiz generation (algorithm needs current ability)
- Fast access (single document read)
- Updated incrementally (not replaced)

**Example:**
```javascript
users/{userId} {
  theta_by_chapter: {
    "physics_electrostatics": {
      theta: 0.5,        // Current value (was 0.3 at baseline)
      percentile: 69.15,
      attempts: 12,
      last_updated: "2024-12-10T14:30:00Z"
    }
  },
  theta_by_subject: {
    physics: { theta: 0.2 }  // Current value
  },
  overall_theta: 0.2  // Current value
}
```

### 2. Baseline Snapshot (Set Once, Never Updated)

**Location:** `users/{userId}.assessment_baseline`

**Purpose:**
- Track progress "from baseline" (initial assessment)
- Calculate improvements: `current_theta - baseline_theta`
- Show "You've improved by +0.2 in Electrostatics"

**Structure:**
```javascript
users/{userId} {
  assessment_baseline: {
    theta_by_chapter: {
      "physics_electrostatics": {
        theta: 0.3,        // Baseline from assessment
        percentile: 61.79,
        attempts: 3,
        accuracy: 0.67
      }
      // ... all chapters from assessment
    },
    theta_by_subject: {
      physics: { theta: 0.1, percentile: 53.98 },
      chemistry: { theta: -0.4, percentile: 34.46 },
      mathematics: { theta: 0.3, percentile: 61.79 }
    },
    overall_theta: 0.1,
    overall_percentile: 53.98,
    captured_at: "2024-12-03T09:00:00Z"  // Assessment completion time
  }
}
```

**When Created:**
- Set once during initial assessment completion
- Never updated after that
- Preserves assessment state for progress tracking

### 3. Historical Snapshots (Optional - For Trends)

**Location:** `theta_history/{userId}/snapshots/{snapshotId}`

**Purpose:**
- Track theta changes over time (weekly trends)
- Show progress graphs ("Your theta improved from 0.2 to 0.5 over 4 weeks")
- Analytics: "Which chapters improved most this week?"

**Structure:**
```javascript
theta_history/{userId}/snapshots/snapshot_week_2024-12-10 {
  snapshot_id: "snapshot_week_2024-12-10",
  snapshot_type: "weekly" | "quiz",  // Weekly summary or per-quiz
  week_start: "2024-12-04",          // Monday of week
  week_end: "2024-12-10",            // Sunday of week
  quiz_count: 7,                      // Quizzes completed this week
  
  // Snapshot of theta values at this point
  theta_by_chapter: {
    "physics_electrostatics": { theta: 0.5, percentile: 69.15 },
    // ... all chapters
  },
  theta_by_subject: {
    physics: { theta: 0.2, percentile: 57.93 },
    chemistry: { theta: -0.3, percentile: 38.21 },
    mathematics: { theta: 0.5, percentile: 69.15 }
  },
  overall_theta: 0.2,
  overall_percentile: 57.93,
  
  // Changes from previous snapshot
  changes_from_previous: {
    chapters_improved: 3,              // Chapters with theta increase
    chapters_declined: 0,              // Chapters with theta decrease
    overall_delta: 0.1,                // Overall theta change
    biggest_improvement: {
      chapter: "physics_electrostatics",
      delta: 0.2
    }
  },
  
  captured_at: "2024-12-10T23:59:59Z"
}
```

**When Created:**
- **Option A: Weekly snapshots** (recommended for storage efficiency)
  - Created every Sunday at end of week
  - Stores ~52 snapshots per year per user
  - Good for weekly progress tracking
  
- **Option B: Per-quiz snapshots** (more detailed, more storage)
  - Created after each quiz completion
  - Stores ~365 snapshots per year per user (if daily)
  - Better for detailed trend analysis

**Recommendation:** Start with **weekly snapshots**, add per-quiz if needed for analytics.

---

## Progress Calculation Examples

### 1. Progress from Baseline

```javascript
// Calculate improvement from baseline
function getProgressFromBaseline(user) {
  const baseline = user.assessment_baseline;
  const current = {
    theta_by_chapter: user.theta_by_chapter,
    theta_by_subject: user.theta_by_subject,
    overall_theta: user.overall_theta
  };
  
  return {
    overall_improvement: current.overall_theta - baseline.overall_theta,  // +0.1
    chapter_improvements: Object.keys(current.theta_by_chapter).map(chapter => ({
      chapter,
      baseline_theta: baseline.theta_by_chapter[chapter]?.theta || null,
      current_theta: current.theta_by_chapter[chapter].theta,
      improvement: current.theta_by_chapter[chapter].theta - 
                   (baseline.theta_by_chapter[chapter]?.theta || 0)
    }))
  };
}
```

### 2. Weekly Trends

```javascript
// Get theta trend over last 4 weeks
async function getWeeklyTrends(userId, weeks = 4) {
  const snapshotsRef = db.collection('theta_history')
    .doc(userId)
    .collection('snapshots')
    .orderBy('week_end', 'desc')
    .limit(weeks);
  
  const snapshots = await snapshotsRef.get();
  
  return snapshots.docs.map(doc => ({
    week: doc.data().week_start,
    overall_theta: doc.data().overall_theta,
    changes: doc.data().changes_from_previous
  }));
}
```

### 3. Chapter Improvement Tracking

```javascript
// Find chapters that improved this week
function getChaptersImproved(user, weekSnapshot) {
  const current = user.theta_by_chapter;
  const weekAgo = weekSnapshot.theta_by_chapter;
  
  return Object.keys(current)
    .filter(chapter => {
      const currentTheta = current[chapter].theta;
      const weekAgoTheta = weekAgo[chapter]?.theta;
      return weekAgoTheta && currentTheta > weekAgoTheta;
    })
    .map(chapter => ({
      chapter,
      improvement: current[chapter].theta - weekAgo[chapter].theta
    }));
}
```

---

## Storage Comparison

### Option 1: Current + Baseline Only (Minimal)
- **Storage:** ~5KB per user
- **Capabilities:** 
  - ✅ Progress from baseline
  - ❌ No historical trends
  - ❌ No weekly comparisons
- **Use Case:** Basic progress tracking

### Option 2: Current + Baseline + Weekly Snapshots (Recommended)
- **Storage:** ~260KB per user per year (52 weeks × 5KB)
- **Capabilities:**
  - ✅ Progress from baseline
  - ✅ Weekly trends
  - ✅ Week-over-week comparisons
  - ✅ Historical graphs
- **Use Case:** Full progress tracking with trends

### Option 3: Current + Baseline + Per-Quiz Snapshots (Maximum)
- **Storage:** ~1.8MB per user per year (365 quizzes × 5KB)
- **Capabilities:**
  - ✅ All of Option 2
  - ✅ Daily trends
  - ✅ Per-quiz granularity
- **Use Case:** Detailed analytics and research

---

## Implementation Recommendation

### Phase 1: Start Simple
1. **Current values** - Already implemented
2. **Baseline snapshot** - Add during assessment completion
3. **No historical snapshots** - Calculate trends from responses if needed

### Phase 2: Add Weekly Snapshots (When Needed)
1. Create snapshot after each week (Sunday night)
2. Store in `theta_history/{userId}/snapshots/`
3. Calculate changes from previous week
4. Use for weekly progress reports

### Phase 3: Add Per-Quiz Snapshots (If Analytics Required)
1. Only if detailed analytics needed
2. Can be added later without migration
3. Consider data retention policy (e.g., keep last 90 days)

---

## Code Pattern for Baseline Creation

```javascript
// In assessmentService.js - after assessment completion
async function saveAssessmentWithTransaction(userId, assessmentResults, responses) {
  // ... existing code ...
  
  // Add baseline snapshot
  const baselineSnapshot = {
    theta_by_chapter: JSON.parse(JSON.stringify(assessmentResults.theta_by_chapter)), // Deep copy
    theta_by_subject: JSON.parse(JSON.stringify(assessmentResults.theta_by_subject)),
    overall_theta: assessmentResults.overall_theta,
    overall_percentile: assessmentResults.overall_percentile,
    captured_at: assessmentResults.assessment_completed_at
  };
  
  transaction.set(userRef, {
    // ... existing fields ...
    assessment_baseline: baselineSnapshot  // Add baseline
  }, { merge: true });
}
```

---

## Summary

**Answer:** We store **both current values AND baseline snapshot**:

1. **Current values** - Updated after each quiz (for algorithm)
2. **Baseline snapshot** - Set once during assessment (for progress tracking)
3. **Historical snapshots** - Optional, added when needed for trends

This gives us:
- ✅ Fast access to current values (quiz generation)
- ✅ Progress from baseline (home page display)
- ✅ Historical trends (optional, when needed)

**Storage:** Minimal overhead (~5KB baseline + optional snapshots)

