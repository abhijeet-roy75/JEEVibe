# Cognitive Mastery - Analytics Events

## Overview

This document specifies all analytics events to track for the Cognitive Mastery feature.

---

## Event Categories

| Category | Purpose | Platform |
|----------|---------|----------|
| **Detection** | Track weak spot detection | Backend |
| **Engagement** | Track user interaction with capsules | Mobile |
| **Learning Outcomes** | Track retrieval performance | Backend + Mobile |
| **Dashboard** | Track dashboard usage | Mobile |

---

## Detection Events

### 1. `weak_spot_detected`

**When:** Backend detects a weak spot after chapter practice

**Platform:** Backend

**Properties:**
```javascript
{
  userId: "string",
  nodeId: "string",
  chapterKey: "string",
  score: 0.82,              // Node score (0.0-1.0)
  sessionId: "string",
  timestamp: "ISO 8601"
}
```

**Implementation (Backend):**
```javascript
// Location: /backend/src/services/weakSpotScoringService.js

analytics.track('weak_spot_detected', {
  userId: userId,
  nodeId: detectedNode.nodeId,
  chapterKey: session.chapterKey,
  score: detectedNode.score,
  sessionId: session.sessionId,
  timestamp: new Date().toISOString()
});
```

---

### 2. `weak_spot_below_threshold`

**When:** Node score is 0.60-0.74 (show on dashboard, no modal)

**Platform:** Backend

**Properties:**
```javascript
{
  userId: "string",
  nodeId: "string",
  score: 0.65,
  threshold: 0.75,
  timestamp: "ISO 8601"
}
```

---

## Engagement Events

### 3. `weak_spot_modal_shown`

**When:** Detection modal displayed to user

**Platform:** Mobile

**Properties:**
```javascript
{
  userId: "string",
  nodeId: "string",
  capsuleId: "string",
  chapterKey: "string",
  timestamp: "ISO 8601"
}
```

**Implementation (Mobile):**
```dart
// Location: /mobile/lib/screens/weak_spot_detected_modal.dart

@override
void initState() {
  super.initState();
  analytics.track('weak_spot_modal_shown', {
    'userId': widget.userId,
    'nodeId': widget.nodeId,
    'capsuleId': widget.capsuleId,
    'chapterKey': widget.chapterKey,
    'timestamp': DateTime.now().toIso8601String(),
  });
}
```

---

### 4. `capsule_opened`

**When:** User taps "Read Capsule" button

**Platform:** Mobile

**Properties:**
```javascript
{
  userId: "string",
  capsuleId: "string",
  nodeId: "string",
  source: "modal" | "dashboard",  // Where user opened from
  timestamp: "ISO 8601"
}
```

---

### 5. `capsule_viewed`

**When:** User scrolls to bottom of capsule (read fully)

**Platform:** Mobile

**Properties:**
```javascript
{
  userId: "string",
  capsuleId: "string",
  nodeId: "string",
  timeSpent: 95,            // Seconds spent reading
  timestamp: "ISO 8601"
}
```

**Implementation:**
```dart
// Trigger when ScrollController reaches bottom
scrollController.addListener(() {
  if (scrollController.position.pixels >= scrollController.position.maxScrollExtent) {
    _trackCapsuleViewed();
  }
});
```

---

### 6. `capsule_skipped`

**When:** User taps "Skip" or "Save for Later"

**Platform:** Mobile

**Properties:**
```javascript
{
  userId: "string",
  capsuleId: "string",
  nodeId: "string",
  timeSpent: 12,            // Seconds before skipping
  action: "skip" | "save_for_later",
  timestamp: "ISO 8601"
}
```

---

## Learning Outcomes Events

### 7. `retrieval_started`

**When:** User begins retrieval questions

**Platform:** Mobile

**Properties:**
```javascript
{
  userId: "string",
  nodeId: "string",
  capsuleId: "string",
  questionCount: 2,
  timestamp: "ISO 8601"
}
```

---

### 8. `retrieval_question_answered`

**When:** User submits each retrieval question

**Platform:** Mobile

**Properties:**
```javascript
{
  userId: "string",
  nodeId: "string",
  questionId: "string",
  questionNumber: 1,        // 1 or 2
  isCorrect: true,
  timeTaken: 45,            // Seconds
  timestamp: "ISO 8601"
}
```

---

### 9. `retrieval_completed`

**When:** User completes all retrieval questions

**Platform:** Backend (after submission)

**Properties:**
```javascript
{
  userId: "string",
  nodeId: "string",
  capsuleId: "string",
  passed: true,             // 2/2 correct
  correctCount: 2,
  totalQuestions: 2,
  oldScore: 0.82,
  newScore: 0.49,
  status: "improved" | "active",
  timestamp: "ISO 8601"
}
```

**Implementation (Backend):**
```javascript
// Location: /backend/src/routes/weakSpots.js

analytics.track('retrieval_completed', {
  userId: req.userId,
  nodeId: req.body.nodeId,
  capsuleId: capsuleId,
  passed: result.passed,
  correctCount: result.correctCount,
  totalQuestions: 2,
  oldScore: result.oldScore,
  newScore: result.newScore,
  status: result.status,
  timestamp: new Date().toISOString()
});
```

---

## Dashboard Events

### 10. `weak_spots_card_viewed`

**When:** User views Active Weak Spots card on home screen

**Platform:** Mobile

**Properties:**
```javascript
{
  userId: "string",
  activeCount: 3,           // Number of active weak spots
  timestamp: "ISO 8601"
}
```

---

### 11. `weak_spot_clicked`

**When:** User clicks a weak spot from dashboard

**Platform:** Mobile

**Properties:**
```javascript
{
  userId: "string",
  nodeId: "string",
  source: "home_card" | "all_weak_spots_screen",
  status: "active" | "improved",
  timestamp: "ISO 8601"
}
```

---

### 12. `all_weak_spots_viewed`

**When:** User opens "View All Weak Spots" screen

**Platform:** Mobile

**Properties:**
```javascript
{
  userId: "string",
  totalCount: 8,            // Total weak spots (all statuses)
  activeCount: 3,
  improvedCount: 5,
  timestamp: "ISO 8601"
}
```

---

## Key Metrics to Track

### Engagement Metrics (Week 4 Checkpoint)

| Metric | Formula | Target |
|--------|---------|--------|
| **Capsule Delivery Rate** | `weak_spot_detected / chapter_practice_sessions` | 30-40% |
| **Capsule Open Rate** | `capsule_opened / weak_spot_modal_shown` | 60%+ |
| **Capsule Completion Rate** | `capsule_viewed / capsule_opened` | 80%+ |
| **Capsule Skip Rate** | `capsule_skipped / capsule_opened` | <20% |
| **Retrieval Pass Rate** | `retrieval_completed(passed=true) / retrieval_started` | 50-70% |

### Learning Outcomes (Week 8 Launch)

| Metric | Formula | Target |
|--------|---------|--------|
| **Theta Improvement** | Compare theta change for capsule users vs control | +0.1 higher |
| **Score Reduction** | `(oldScore - newScore) / oldScore` | 40%+ drop |
| **Relapse Rate** | `weak_spot_detected(nodeId=X) / 30 days after resolved` | <20% |

### Business Impact (Post-Launch)

| Metric | Formula | Target |
|--------|---------|--------|
| **Feature Awareness** | `users_with_weak_spot_detected / total_active_users` | 50%+ in Week 1 |
| **30-Day Retention** | Compare retention for capsule users vs non-users | +10% |
| **Weekly Engagement** | `avg_capsules_per_user_per_week` | 1-2 |

---

## Analytics Implementation

**No third-party event tracking (Segment, Amplitude, etc.) — all events are written to Firestore.**

The `weak_spot_events` collection is the single source of truth for both state changes AND engagement. Product metrics are queried directly from this collection.

### Event Storage

All events — whether backend-initiated (state changes) or mobile-initiated (engagement) — are written to `weak_spot_events` as append-only documents.

**Backend state-change events** are written directly in `weakSpotScoringService.js` and the retrieval route.

**Mobile engagement events** are sent via `POST /api/weak-spots/events` — backend validates the `eventType` allowlist and writes to Firestore. Mobile never writes to Firestore directly.

### Unified Event Schema

```javascript
// weak_spot_events/{auto-id}
{
  student_id: "uid",
  atlas_node_id: "PHY_ELEC_VEC_001",
  chapter_key: "physics_electrostatics",      // null for engagement events
  capsule_id: "CAP_PHY_ELEC_VEC_001_V1",      // null for state-change events
  session_id: "string",                        // null for engagement events

  event_type:
    // State changes (backend writes only)
    "chapter_scored" | "retrieval_completed" |
    // Engagement (mobile → POST /api/weak-spots/events → backend writes)
    "capsule_delivered" | "capsule_opened" | "capsule_saved" |
    "capsule_completed" | "capsule_skipped" | "retrieval_started",

  // State change fields (null for engagement events)
  previous_state: null | "inactive" | "active" | "improving" | "stable",
  new_state: null | "active" | "improving" | "stable",
  previous_score: null | 0.82,
  new_score: null | 0.49,

  created_at: serverTimestamp()
}
```

### Deriving `capsule_status` from Event Log

The `GET /api/weak-spots/:userId` endpoint computes `capsuleStatus` per node by reading the latest engagement event:

| Latest engagement event | `capsuleStatus` |
|------------------------|-----------------|
| none / `capsule_delivered` | `"delivered"` |
| `capsule_saved` | `"ignored"` |
| `capsule_opened` | `"opened"` |
| `capsule_completed` | `"completed"` |

### Querying Product Metrics

```javascript
// Capsule delivery rate (backend query)
const delivered = await db.collection('weak_spot_events')
  .where('event_type', '==', 'capsule_delivered')
  .where('created_at', '>=', weekAgo).get();

// Capsule open rate
const opened = await db.collection('weak_spot_events')
  .where('event_type', '==', 'capsule_opened')
  .where('created_at', '>=', weekAgo).get();

// open_rate = opened.size / delivered.size
```

---

## Testing Analytics

### Manual Testing Checklist

- [ ] Trigger weak spot detection (backend logs event)
- [ ] Open detection modal (mobile logs event)
- [ ] Read capsule to bottom (mobile logs viewed event)
- [ ] Skip capsule (mobile logs skipped event)
- [ ] Complete retrieval questions (backend logs completed event)
- [ ] View dashboard card (mobile logs card_viewed event)

### Automated Testing

Use Segment debugger or analytics dashboard to verify:
- All events have required properties
- Timestamps are in ISO 8601 format
- UserIds match Firebase Auth UIDs
- No duplicate events within 1 second

---

## Privacy & GDPR Compliance

**Data Retention:**
- Raw event data: 90 days
- Aggregated metrics: 2 years
- User can request data deletion via profile settings

**PII Handling:**
- Never track question content or student answers in analytics
- Only track question IDs and correctness (boolean)
- User IDs are anonymized in exports

---

## Related Documentation

- [API Reference](01-API-REFERENCE.md) - Where backend events are triggered
- [Mobile UI Spec](03-MOBILE-UI-SPEC.md) - Where mobile events are triggered
- [Scoring Engine](02-SCORING-ENGINE-SPEC.md) - Detection logic
