# Cognitive Mastery Feature Flag

## Overview

The Cognitive Mastery feature (Weak Spots detection and remediation) is controlled by a global feature flag in Firestore. This allows for gradual rollout and data collection before full launch.

## Feature Flag Location

**Firestore Path:** `tier_config/active`

**Field:** `feature_flags.show_cognitive_mastery` (boolean)

**Default:** `false` (feature hidden from users)

## How It Works

### Backend
- The `tierConfigService.js` includes the flag in the default config
- The flag is cached with a 5-minute TTL along with tier configuration

### Mobile
- On app startup, the `home_screen.dart` reads the flag from Firestore
- If `show_cognitive_mastery` is `true`:
  - "Active Weak Spots" card appears on home screen
  - Weak spots API is called to load user's weak spots
  - Users can tap to see all weak spots and work through lessons
- If `show_cognitive_mastery` is `false`:
  - "Active Weak Spots" card is hidden
  - Weak spots API is NOT called (saves bandwidth)
  - Feature is still operational for testing/debugging

## Toggling the Feature

### Using the Script

```bash
# Check current status
node backend/scripts/toggle-cognitive-mastery.js

# Enable the feature (show to all users)
node backend/scripts/toggle-cognitive-mastery.js on

# Disable the feature (hide from users)
node backend/scripts/toggle-cognitive-mastery.js off
```

### Manual Update (Firestore Console)

1. Go to Firestore Console
2. Navigate to `tier_config/active`
3. Update `feature_flags.show_cognitive_mastery` to `true` or `false`
4. Changes take effect on next app restart or within 5 minutes (cache TTL)

## Affected Screens

When **enabled** (`true`):
- [home_screen.dart](../mobile/lib/screens/home_screen.dart) — Shows "Active Weak Spots" card
- [all_weak_spots_screen.dart](../mobile/lib/screens/all_weak_spots_screen.dart) — Accessible via "View All Weak Spots" button
- [capsule_screen.dart](../mobile/lib/screens/capsule_screen.dart) — Lesson viewer for weak spots
- [weak_spot_retrieval_screen.dart](../mobile/lib/screens/weak_spot_retrieval_screen.dart) — 3-question validation
- [weak_spot_results_screen.dart](../mobile/lib/screens/weak_spot_results_screen.dart) — Pass/fail results
- [chapter_practice_result_screen.dart](../mobile/lib/screens/chapter_practice/chapter_practice_result_screen.dart) — Shows "Weak Spot Detected" modal

When **disabled** (`false`):
- All of the above screens remain accessible programmatically (for testing)
- "Active Weak Spots" card does NOT appear on home screen
- Weak spots modal STILL shows after chapter practice (backend detection continues)
- Users can still navigate to capsules/retrieval if they have direct links

## API Endpoints Affected

When flag is `false`, these endpoints are NOT called from the mobile app:
- `GET /api/weak-spots/:userId` — Not called (saves backend load)

These endpoints continue to work regardless of flag state:
- `POST /api/weak-spots/events` — Still logs engagement events
- `POST /api/weak-spots/retrieval` — Still accepts retrieval submissions
- `GET /api/capsules/:capsuleId` — Still fetches capsule content

## Backend Detection

**Important:** The backend `weakSpotScoringService.detectWeakSpots()` runs **regardless of the flag state**. This means:
- Weak spots are still detected after chapter practice completion
- Data is still written to `user_weak_spots` and `weak_spot_events`
- This allows data collection even when feature is hidden from users

## Rollout Strategy

### Phase 1: Internal Testing (Current)
- Flag: `false`
- Behavior: Feature hidden, backend continues to detect and log data
- Goal: Collect baseline data, ensure backend stability

### Phase 2: Beta Testing
- Flag: `true` for beta users only (future: user-level flags)
- Behavior: Selected users see the feature
- Goal: Gather user feedback, validate UX

### Phase 3: General Availability
- Flag: `true` for all users
- Behavior: Feature live for everyone
- Goal: Full launch

## Data Collection

Even with the flag set to `false`, the following data is collected:
- Weak spot detections (via chapter practice completion)
- Weak spot state transitions (active → improving → stable)
- Capsule engagement events (capsule_opened, capsule_completed)
- Retrieval validation results (passed/failed, correctness data)

This data can be analyzed via the **Cognitive Mastery** page in the admin dashboard:
- URL: https://jeevibe-admin.web.app/cognitive-mastery
- Metrics: Total detections, capsules opened, retrievals attempted, pass rate

## Troubleshooting

### Flag Not Taking Effect
- Wait 5 minutes for tier config cache to expire
- Force-close and restart the mobile app
- Check Firestore: `tier_config/active` → `feature_flags.show_cognitive_mastery`

### Card Still Showing After Disabling
- User may have cached data — force-close app
- Check if flag was actually updated in Firestore
- Verify script output shows "DISABLED ❌"

### Backend Still Detecting Weak Spots
- This is **expected behavior**
- Backend detection is independent of the feature flag
- Only the UI visibility is controlled by the flag

## Future Enhancements

- User-level flags (show to specific users only)
- A/B testing support (show to 50% of users)
- Admin dashboard toggle (no need for script)
- Real-time flag updates (no need to restart app)

## Related Files

- [toggle-cognitive-mastery.js](../backend/scripts/toggle-cognitive-mastery.js) — Toggle script
- [tierConfigService.js](../backend/src/services/tierConfigService.js) — Backend flag definition
- [home_screen.dart](../mobile/lib/screens/home_screen.dart) — Mobile flag reading
- [MEMORY.md](../.claude/projects/-Users-abhijeetroy-Documents-JEEVibe/memory/MEMORY.md) — Claude Code memory (Week 2 implementation notes)

---

**Created:** 2026-02-20
**Last Updated:** 2026-02-20
**Status:** Implemented ✅
