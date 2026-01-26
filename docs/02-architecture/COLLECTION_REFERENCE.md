# Firestore Collection Reference

This document lists all Firestore collections used in JEEVibe and which cleanup scripts handle them.

## User-Specific Collections (keyed by userId)

### Top-Level Collections

| Collection | Subcollection | Full Path | Cleanup Scripts |
|------------|---------------|-----------|-----------------|
| `users` | - | `users/{userId}` | cleanup-user, cleanup-orphaned |
| `assessment_responses` | `responses` | `assessment_responses/{userId}/responses/*` | cleanup-user, cleanup-orphaned, wipe-collection |
| `daily_quizzes` | `quizzes` → `questions` | `daily_quizzes/{userId}/quizzes/{quizId}/questions/*` | cleanup-user, cleanup-orphaned, wipe-collection |
| `daily_quiz_responses` | `responses` | `daily_quiz_responses/{userId}/responses/*` | cleanup-user, cleanup-orphaned, wipe-collection |
| `practice_streaks` | - | `practice_streaks/{userId}` | cleanup-user, cleanup-orphaned, wipe-collection |
| `theta_history` | `snapshots` | `theta_history/{userId}/snapshots/*` | cleanup-user, cleanup-orphaned, wipe-collection |
| `theta_snapshots` | `daily` | `theta_snapshots/{userId}/daily/*` | cleanup-user, cleanup-orphaned, wipe-collection |
| `chapter_practice_sessions` | `sessions` → `questions` | `chapter_practice_sessions/{userId}/sessions/{sessionId}/questions/*` | cleanup-user, cleanup-orphaned, wipe-collection |
| `chapter_practice_responses` | `responses` | `chapter_practice_responses/{userId}/responses/*` | cleanup-user, cleanup-orphaned, wipe-collection |
| `share_events` | `items` | `share_events/{userId}/items/*` | cleanup-user, cleanup-orphaned, wipe-collection |
| `feedback` | - | `feedback/{docId}` (queried by userId field) | cleanup-user, cleanup-orphaned, wipe-collection |

### User Document Subcollections

| Parent | Subcollection | Full Path | Cleanup Scripts |
|--------|---------------|-----------|-----------------|
| `users/{userId}` | `snaps` | `users/{userId}/snaps/*` | cleanup-user, cleanup-orphaned |
| `users/{userId}` | `daily_usage` | `users/{userId}/daily_usage/*` | cleanup-user, cleanup-orphaned |
| `users/{userId}` | `quizzes` | `users/{userId}/quizzes/*` | cleanup-user, cleanup-orphaned |
| `users/{userId}` | `subscriptions` | `users/{userId}/subscriptions/*` | cleanup-user, cleanup-orphaned |
| `users/{userId}` | `chapter_practice_weekly` | `users/{userId}/chapter_practice_weekly/*` | cleanup-user, cleanup-orphaned |
| `users/{userId}` | `tutor_conversation` | `users/{userId}/tutor_conversation/active/messages/*` | cleanup-user, cleanup-orphaned |

### Legacy Collections (typos - kept for cleanup)

| Collection | Correct Name | Full Path | Cleanup Scripts |
|------------|--------------|-----------|-----------------|
| `thetha_snapshots` | `theta_snapshots` | `thetha_snapshots/{userId}/daily/*` | cleanup-user, cleanup-orphaned, wipe-collection |
| `thetha_history` | `theta_history` | `thetha_history/{userId}/snapshots/*` | cleanup-user, cleanup-orphaned, wipe-collection |
| `chapter_practise_sessions` | `chapter_practice_sessions` | `chapter_practise_sessions/{userId}/sessions/*` | cleanup-user, cleanup-orphaned, wipe-collection |

## System Collections (not user-specific)

| Collection | Purpose | Notes |
|------------|---------|-------|
| `questions` | Question bank | Read-only seed data |
| `initial_assessment_questions` | Initial assessment questions | Read-only seed data |
| `tier_config` | Subscription tier configuration | Single doc 'active' |

## Storage

| Path | Purpose | Cleanup Scripts |
|------|---------|-----------------|
| `snaps/{userId}/*` | Snap/solve images | cleanup-user, cleanup-orphaned |

## Cleanup Script Usage

### Delete a specific user's data
```bash
npm run cleanup:user -- <userId|phoneNumber> [--preview] [--force]
```

### Delete orphaned data (users that no longer exist)
```bash
npm run cleanup:orphaned -- [--preview] [--force] [--collection=name]
```

### Diagnose collection status
```bash
npm run diagnose:collections -- [--collection=name]
```

### Wipe an entire collection
```bash
npm run wipe:collection -- <collection-name> [--preview] [--force]
```
