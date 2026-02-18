# Cognitive Mastery - Implementation Log

## Overview

**Timeline:** 4 weeks
**Pilot Chapters:** Electrostatics + Units & Measurements (content already complete)
**Approach:** Build real from day 1 — no stub phase

**Content status:**
- ✅ Electrostatics: 7 atlas nodes, 18 micro-skills, 21 remediation questions, pools
- ✅ Units & Measurements: 7 atlas nodes, 16 micro-skills, 45 questions, pools
- ⏸️ Existing chapter practice questions need `micro_skill_ids` tags added

---

## Week 1 (Feb 17-23): Data + Backend

### Backend Goals
- [ ] Upload content to Firestore from `inputs/cognitive_mastery/data1/`
  - [ ] `atlas_nodes` collection (14 nodes: 7 electrostatics + 7 units)
  - [ ] `capsules` collection (14 capsules)
  - [ ] `retrieval_pools` collection (14 pools, 3 questions each, pass 2/3)
  - [ ] `retrieval_questions` collection (3 questions per pool = 42 questions total)
    - Stored separately from main `questions` collection (different ID namespace: `PHY_ELEC_VEC_001_RQ_001`)
    - Format must match existing question schema for `QuestionCardWidget` to render them
    - Source files: `RQ_PHY_ELEC_*.json` and `RQ_PHY_UNITS_*.json` in `data1/`
  - [ ] `atlas_micro_skills/{chapterKey}` collection
  - [ ] `atlas_question_skill_map/{chapterKey}` collection
  - **Script:** `backend/scripts/cognitive-mastery/upload-cognitive-mastery.js`
    ```bash
    # Dry run first to preview what will be written
    node scripts/cognitive-mastery/upload-cognitive-mastery.js --dry-run

    # Upload data1 (default dir)
    node scripts/cognitive-mastery/upload-cognitive-mastery.js

    # Upload a future chapter drop from product team
    node scripts/cognitive-mastery/upload-cognitive-mastery.js --dir inputs/cognitive_mastery/data2
    ```

- [ ] Tag existing chapter practice questions with `micro_skill_ids`
  - Use `question_to_micro_skill_map` uploaded in step above
  - **Script:** `backend/scripts/cognitive-mastery/tag-questions-micro-skills.js`
    ```bash
    # Dry run to preview which questions will be tagged
    node scripts/cognitive-mastery/tag-questions-micro-skills.js --dry-run

    # Tag all chapters that have maps in Firestore
    node scripts/cognitive-mastery/tag-questions-micro-skills.js

    # Tag a single chapter only
    node scripts/cognitive-mastery/tag-questions-micro-skills.js --chapter physics_electrostatics
    node scripts/cognitive-mastery/tag-questions-micro-skills.js --chapter physics_units_measurements
    ```
  - Expected output: "Questions tagged: N, Questions not found: M" (M should be 0)

- [ ] Build scoring engine: `backend/src/services/weakSpotScoringService.js`
  - Full formula: `node_score = 0.60 × skill_deficit + 0.25 × signature + 0.15 × recurrence`
  - Thresholds from atlas_nodes: `trigger_threshold = 0.60`, `stability_threshold = 0.40`
  - `min_signal_count = 2` (need ≥2 questions per node to trigger)
  - Returns top triggered node per session (1 capsule per session max)

- [ ] Build API endpoints: `backend/src/routes/weakSpots.js`
  - [ ] `GET /api/capsules/:capsuleId`
  - [ ] `POST /api/weak-spots/retrieval` (3 questions, pass 2/3)
  - [ ] `GET /api/weak-spots/:userId`
  - [ ] `POST /api/weak-spots/events` (mobile engagement events — allowlisted event types only)
  - **NOTE**: `/detect` is NOT an HTTP endpoint — it's an internal function call only

- [ ] Hook scoring into chapter practice: `backend/src/routes/chapterPractice.js`
  - Call `detectWeakSpots(userId, sessionId, db)` directly inside `/complete` handler
  - Include `weakSpot: { nodeId, title, score, nodeState, capsuleId, severityLevel } | null` in completion response

- [ ] Create `weak_spot_events` collection (append-only event log)
  - Write on every node state change

- [x] Feature flag decision: NO per-tier gating. Feature available to all tiers.
  - Free tier is naturally limited via chapter practice limits (5 Q/chapter, 5 chapters/day)
  - Analytics → Mastery tab is a separate IRT-based feature (Pro/Ultra only) — unrelated to cognitive mastery UI
  - Cognitive mastery surfaces on home screen + post-practice modal — both available to all tiers
  - Optional kill switch only: if needed, add `cognitive_mastery_enabled: true` as top-level boolean in `tier_config/active` — NOT in per-tier limits

- [ ] Deploy to Render.com

**Status:** ⬜ Not started
**Blockers:** None

---

## Week 2 (Feb 24 - Mar 1): Mobile UI

### Mobile Goals
- [ ] `weak_spot_detected_modal.dart`
  - Shown after chapter practice if `weakSpot != null` in response
  - Buttons: "Read Capsule" → Screen 2, "Save for Later" → dismiss

- [ ] `capsule_screen.dart`
  - Reads `coreMisconception`, `structuralRule`, `illustrativeExample`
  - Reuse `LatexWidget` for math rendering
  - Marks `capsule_status = "completed"` on scroll-to-bottom

- [ ] `weak_spot_retrieval_screen.dart`
  - 3 questions (from pool), reuse `QuestionCardWidget`
  - Header: "Validation (1/3)", "(2/3)", "(3/3)"
  - No timer

- [ ] `weak_spot_results_screen.dart`
  - Pass (2+/3): "Weak Spot Improved!" + new node state label
  - Fail (<2/3): "Keep Practicing" + encouragement

- [ ] `active_weak_spots_card.dart`
  - Sorted: active → severity → score
  - Node state labels: "Needs Strengthening" / "Keep Practicing" / "Recently Strengthened"
  - Empty state: "No Active Weak Spots 🎉"

- [ ] `all_weak_spots_screen.dart`
  - Grouped by state
  - "Resume Capsule" action for active nodes

- [ ] Modify `chapter_practice_results_screen.dart`
  - Check for `weakSpot` in response, show modal

- [ ] Modify `home_screen.dart`
  - Add `ActiveWeakSpotsCard` widget

**Status:** ⬜ Not started
**Blockers:** Week 1 backend APIs must be deployed

---

## Week 3 (Mar 2-8): Integration + Internal Testing

### Goals
- [ ] End-to-end flow working: chapter practice → detection → capsule → retrieval → dashboard
- [ ] Test both pilot chapters (Electrostatics + Units & Measurements)
- [ ] Enable feature flag for internal users: `cognitive_mastery_enabled: true`
- [ ] Test node state transitions: inactive → active → improving → stable → active (relapse)
- [ ] Verify trigger rate on test sessions (target: 30-40%)
- [ ] Verify retrieval pass rate (target: 50-70%)
- [ ] Fix critical bugs

**Status:** ⬜ Not started
**Blockers:** Weeks 1+2 complete

---

## Week 4 (Mar 9-15): Analytics + Soft Launch

### Goals
- [ ] Add analytics events (5 key events):
  - `weak_spot_detected` (backend, after scoring)
  - `capsule_opened` (mobile, on Screen 2 entry)
  - `capsule_completed` (mobile, on scroll-to-bottom)
  - `capsule_skipped` (mobile, on "Save for Later")
  - `retrieval_completed` (backend, with `passed`, `correctCount`, `newState`)

- [ ] Fix bugs from Week 3 internal testing

- [ ] Soft launch: enable for 20% of users (via feature flag or remote config)

- [ ] Monitor for 3 days:
  - Detection rate (target: 30-40% of chapter practice sessions)
  - Capsule open rate (target: 60%+)
  - Retrieval pass rate (target: 50-70%)

**Status:** ⬜ Not started
**Blockers:** Week 3 complete

---

## Success Criteria (End of Week 4)

### Engagement
- [ ] Detection rate: 30-40% of Electrostatics/Units sessions trigger a capsule
- [ ] Capsule open rate: 60%+ (not immediately skipped)
- [ ] Retrieval pass rate: 50-70%

### Technical
- [ ] Detection latency: < 2 sec after session submit
- [ ] No crashes in Crashlytics from new screens
- [ ] Event log writing correctly on all state transitions

---

## Post-Launch (Week 5+)

### Phase 2: Expand
1. Add Laws of Motion + more chapters (requires product team content)
2. Upgrade scoring to include signature distractor detection (0.25 weight)
3. Daily Quiz integration

### Phase 3: Scale
1. Admin dashboard: capsule skip rates, retrieval pass rates per node
2. Weekly insights email/notification
3. ML-based detection (replace rules-based)

---

## Risk Log

| Risk | Impact | Status |
|------|--------|--------|
| **Threshold calibration** (full formula max ~1.0, trigger 0.60) | Critical | ✅ Mitigated — using full 3-component formula |
| **Questions not tagged** (micro_skill_ids missing) | High | 🟡 Run tag-questions-micro-skills.js (Week 1) |
| **LaTeX rendering issues** in capsule text | Medium | 🟢 Reuse LatexWidget |
| **Pass rate too low** (<40%) | Medium | 🟡 Monitor Week 4, adjust pool if needed |
| **Pass rate too high** (>80%) | Low | 🟡 Monitor Week 4, add harder contrast questions |

---

## Notes
- Update status weekly (every Monday)
- Link to PRs/commits next to tasks as completed
- Feature flag: `cognitive_mastery_enabled` in `tier_config/active`

---

## Related Documentation

- [Feature Overview](../COGNITIVE-MASTERY.md)
- [API Reference](01-API-REFERENCE.md)
- [Scoring Engine](02-SCORING-ENGINE-SPEC.md)
- [Mobile UI Spec](03-MOBILE-UI-SPEC.md)
- [Analytics Events](04-ANALYTICS-EVENTS.md)
