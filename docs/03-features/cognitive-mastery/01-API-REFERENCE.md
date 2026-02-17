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

**POST** `/weak-spots/detect`

Analyzes a completed chapter practice session to detect weak spots.

**Request:**
```json
{
  "userId": "string",
  "sessionId": "string"
}
```

**Response (Weak Spot Detected):**
```json
{
  "success": true,
  "data": {
    "detected": true,
    "weakSpot": {
      "nodeId": "PHY_ELEC_VEC_001",
      "title": "Vector Superposition Error",
      "score": 0.50,
      "nodeState": "active",
      "capsuleId": "CAP_PHY_ELEC_VEC_001_V1",
      "severityLevel": "high"
    }
  }
}
```

**Response (No Weak Spot):**
```json
{
  "success": true,
  "data": {
    "detected": false,
    "weakSpot": null
  }
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
- Feature gated by `cognitive_mastery_enabled` flag in `tier_config/active`
- Detection is called server-side after chapter practice session completes — mobile does not need to call detect separately; it receives the result in the chapter practice completion response

---

## Related Documentation

- [Scoring Engine Spec](02-SCORING-ENGINE-SPEC.md) - Detection algorithm
- [Mobile UI Spec](03-MOBILE-UI-SPEC.md) - How mobile consumes these APIs
- [Analytics Events](04-ANALYTICS-EVENTS.md) - Tracking spec
- [Testing Strategy](06-TESTING-STRATEGY.md) - API test cases
