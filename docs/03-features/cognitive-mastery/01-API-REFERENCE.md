# Cognitive Mastery - API Reference

## Overview

This document specifies all backend API endpoints for the Cognitive Mastery feature.

---

## Base URL

- **Development**: `http://localhost:3000/api`
- **Production**: `https://api.jeevibe.com/api`

---

## Endpoints

### 1. Detect Weak Spots

**INTERNAL ONLY — not an HTTP endpoint.**

Detection runs server-side as a direct function call inside the chapter practice `/complete` route. Mobile never calls this directly — it receives the result embedded in the chapter practice completion response.

```javascript
// Called inside POST /api/chapter-practice/complete
const weakSpot = await detectWeakSpots(userId, sessionId, db);
// weakSpot is then included in the completion response
```

**Chapter Practice Completion Response (extended):**
```json
{
  "success": true,
  "summary": { "...existing fields..." },
  "updated_stats": { "...existing fields..." },
  "chapter_practice_stats": { "...existing fields..." },
  "weakSpot": {
    "nodeId": "PHY_ELEC_VEC_001",
    "title": "Vector Superposition Error",
    "score": 0.50,
    "nodeState": "active",
    "capsuleId": "CAP_PHY_ELEC_VEC_001_V1",
    "severityLevel": "high"
  }
}
```

**Response when no weak spot triggered:**
```json
{
  "weakSpot": null
}
```

---

### 2. Get Capsule

**GET** `/capsules/:capsuleId`

Retrieves capsule content for display.

**Request Parameters:**
- `capsuleId` (path) - Capsule identifier

**Response:**
```json
{
  "success": true,
  "data": {
    "capsule": {
      "capsuleId": "CAP_PHY_ELEC_VEC_001_V1",
      "nodeId": "PHY_ELEC_VEC_001",
      "nodeName": "Vector Superposition Error",
      "coreMisconception": "You're adding field magnitudes without resolving into components...",
      "structuralRule": "ALWAYS resolve E fields into x and y components before adding...",
      "illustrativeExample": "For charges at 90°, E_net = √(E₁² + E₂²), not E₁ + E₂",
      "estimatedReadTime": 90,
      "poolId": "POOL_PHY_ELEC_VEC_001"
    }
  }
}
```

---

### 3. Submit Retrieval

**POST** `/weak-spots/retrieval`

Submits retrieval question responses and updates weak spot score.

**Request:**
```json
{
  "userId": "string",
  "nodeId": "string",
  "responses": [
    { "questionId": "PHY_ELEC_RQ_001", "selectedAnswer": "B", "isCorrect": true },
    { "questionId": "PHY_ELEC_RQ_002", "selectedAnswer": "A", "isCorrect": false },
    { "questionId": "PHY_ELEC_RQ_003", "selectedAnswer": "C", "isCorrect": true }
  ]
}
```

**Pass rule: 2/3 correct** (2 near + 1 contrast questions)

**Response:**
```json
{
  "success": true,
  "data": {
    "passed": true,
    "correctCount": 2,
    "totalQuestions": 3,
    "oldScore": 0.50,
    "newScore": 0.25,
    "previousState": "active",
    "newState": "improving"
  }
}
```

---

### 4. Get User Weak Spots

**GET** `/weak-spots/:userId`

Retrieves all weak spots for a user (for dashboard).

**Request Parameters:**
- `userId` (path) - User identifier
- `nodeState` (query, optional) - Filter by state: `active`, `improving`, `stable`
- `limit` (query, optional) - Max results (default: 10)

**Response:**
```json
{
  "success": true,
  "data": {
    "weakSpots": [
      {
        "nodeId": "PHY_ELEC_VEC_001",
        "title": "Vector Superposition Error",
        "currentScore": 0.50,
        "nodeState": "active",
        "severityLevel": "high",
        "detectedAt": "2026-02-16T10:30:00Z",
        "status": "active",
        "capsuleViewed": false
      },
      {
        "nodeId": "PHY_UNITS_DIM_002",
        "title": "Dimensional Formula Construction",
        "currentScore": 0.42,
        "nodeState": "improving",
        "severityLevel": "medium",
        "detectedAt": "2026-02-14T14:20:00Z",
        "capsuleStatus": "completed"
      }
    ],
    "totalCount": 2
  }
}
```

---

### 5. Log Engagement Event

**POST** `/weak-spots/events`

Called by mobile to log user engagement with capsules. This is how `capsule_status` is tracked — the event log is the source of truth, not a mutable field. Backend validates the `eventType` against an allowlist before writing.

**Request:**
```json
{
  "nodeId": "PHY_ELEC_VEC_001",
  "eventType": "capsule_opened",
  "capsuleId": "CAP_PHY_ELEC_VEC_001_V1"
}
```

**Allowed `eventType` values (mobile-initiated):**
- `capsule_delivered` — modal shown to user
- `capsule_opened` — user tapped "Read Capsule"
- `capsule_saved` — user tapped "Save for Later"
- `capsule_completed` — user scrolled to bottom of capsule
- `capsule_skipped` — user tapped "Skip for Now" on capsule screen
- `retrieval_started` — user tapped "Continue to Validation"

**Note:** State-change events (`chapter_scored`, `retrieval_completed`) are written by backend only — mobile cannot submit these.

**Response:**
```json
{
  "success": true
}
```

**How `capsule_status` is derived (for dashboard display):**

The `GET /api/weak-spots/:userId` endpoint reads the latest engagement event per node from `weak_spot_events` and computes `capsuleStatus`:

| Latest engagement event | `capsuleStatus` returned |
|------------------------|--------------------------|
| `capsule_delivered` (or none) | `"delivered"` |
| `capsule_saved` | `"ignored"` |
| `capsule_opened` | `"opened"` |
| `capsule_completed` | `"completed"` |

**How "Resume Capsule" works (Q8):**
- Dashboard stores `capsuleId` in weak spot data (from `atlas_nodes`)
- Mobile calls `GET /api/capsules/:capsuleId` — same endpoint, no special resume flow
- Mobile skips Screen 1 (modal) and goes directly to Screen 2 (capsule viewer)

---

## Authentication

All endpoints require Firebase Auth ID token in header:

```
Authorization: Bearer <firebase_id_token>
```

---

## Error Responses

**400 Bad Request:**
```json
{
  "success": false,
  "error": "Invalid sessionId"
}
```

**401 Unauthorized:**
```json
{
  "success": false,
  "error": "Authentication required"
}
```

**404 Not Found:**
```json
{
  "success": false,
  "error": "Capsule not found"
}
```

**500 Internal Server Error:**
```json
{
  "success": false,
  "error": "Internal server error"
}
```

---

## Implementation Notes

- All endpoints are built real from day 1 — no stub phase
- Content for pilot chapters (Electrostatics + Units & Measurements) already loaded into Firestore
- No per-tier gating — feature is available to all tiers (Free, Pro, Ultra). Free tier naturally has fewer sessions due to chapter practice limits (5 questions/chapter, 5 chapters/day), which means fewer capsule triggers organically. Optional kill switch: add `cognitive_mastery_enabled: false` to top-level `tier_config/active` if needed, but not required for launch.
- Detection runs as an internal function call inside `/api/chapter-practice/complete` — NOT a separate HTTP endpoint
- Mobile never calls Firestore directly — all writes go through backend API endpoints
- `capsule_status` is derived from the `weak_spot_events` event log, not stored as a mutable field

### API Summary

| Method | Endpoint | Caller | Purpose |
|--------|----------|--------|---------|
| INTERNAL | `detectWeakSpots()` | Backend only | Called inside `/complete`, result embedded in response |
| GET | `/api/capsules/:capsuleId` | Mobile | Fetch capsule content |
| POST | `/api/weak-spots/retrieval` | Mobile | Submit retrieval answers |
| GET | `/api/weak-spots/:userId` | Mobile | List weak spots for dashboard |
| POST | `/api/weak-spots/events` | Mobile | Log engagement events (capsule opened, skipped, etc.) |

---

## Related Documentation

- [Scoring Engine Spec](02-SCORING-ENGINE-SPEC.md) - Detection algorithm
- [Mobile UI Spec](03-MOBILE-UI-SPEC.md) - How mobile consumes these APIs
- [Analytics Events](04-ANALYTICS-EVENTS.md) - Tracking spec
- [Testing Strategy](06-TESTING-STRATEGY.md) - API test cases
