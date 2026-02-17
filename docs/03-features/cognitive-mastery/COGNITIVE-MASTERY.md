# Cognitive Mastery - Feature Overview

## Executive Summary

**Cognitive Mastery** is a groundbreaking feature that shifts JEEVibe from tracking **what students get wrong** to fixing **how they think wrong**. Instead of generic "weak in Physics" feedback, we identify specific recurring weak spots (e.g., "Vector Addition Error") and deliver targeted 90-second interventions (capsules) that repair the underlying thinking flaw.

**Terminology Note**: User-facing UI uses "weak spots" to refer to misconception patterns. Internal code/APIs use "misconceptions" for technical clarity.

---

## The Problem

### Current State (All JEE Platforms)
- Track accuracy per chapter: "You got 40% correct in Laws of Motion"
- Recommend: "Practice more Laws of Motion questions"
- Result: Students repeat the SAME mistakes because the root cause (misconception) isn't addressed

### Why This Fails
- **Students don't have random errors** - they have systematic misconceptions
- **Practicing more doesn't fix thinking patterns** - it reinforces wrong mental models
- **No feedback loop** - students don't know if they've actually fixed the issue

### Real Student Pain
> "I keep making the same mistakes in different chapters. I practice 100 questions but my accuracy doesn't improve. I don't know what I'm doing wrong structurally."

---

## The Solution: Cognitive Mastery

### Core Innovation
**We track how students think, not just what they answer.**

1. **Detect Patterns** - Analyze 15-question chapter practice sessions to identify recurring misconception patterns (atlas nodes)
2. **Intervene Precisely** - Deliver 90-120 second text-based micro-lessons (capsules) that explain the exact thinking flaw
3. **Validate Understanding** - Test with 2 retrieval questions to confirm the fix worked
4. **Track Progress** - Show students their misconceptions resolved over time (learning trajectory)

---

## How It Works (User Experience)

### Step 1: Detection
- Student completes 15-question chapter practice
- System analyzes:
  - Which micro-skills were tested (e.g., "Resolve vectors", "Apply Gauss's Law")
  - Which answers were wrong AND showed a pattern across multiple questions
  - Error rate per micro-skill → rolled up to atlas node score

### Step 2: Diagnosis
- **Atlas Scoring Engine** calculates a score (0.0 - 1.0) for each misconception node
- Score ≥ 0.60 → Trigger immediate capsule (node becomes "active")
- Score 0.41-0.59 → Show on dashboard, no immediate capsule
- Score ≤ 0.40 → Node becomes "stable" (no action)
- Thresholds are **per-node** from `atlas_nodes` collection

### Step 3: Intervention (Capsule)
- **Modal overlay** appears after results screen
- Shows:
  - **Mistake Pattern**: "You're treating forces like numbers (10N + 8N = 18N). Forces are vectors - direction matters!"
  - **Repair Rule**: "ALWAYS resolve forces into components (x and y) before adding."
  - **Visual Asset**: Diagram showing vector decomposition
- User can read (90 sec) or skip for later

### Step 4: Validation (Retrieval)
- User taps "Continue to Retrieval"
- Shown 3 questions (2 near transfer + 1 contrast transfer) testing the SAME weak spot in new contexts
- Must get 2/3 correct to pass
- Results:
  - **Pass (2+/3)**: "Weak Spot Improved! 🎉 Node state: Improving"
  - **Fail (<2)**: "Keep Practicing. Try again after more chapter practice."

### Step 5: Tracking (UI)
- **Dashboard Card**: "Active Weak Spots" shows top 3 patterns sorted by severity
- **Node States**: Needs Strengthening (active) → Keep Practicing (improving) → Recently Strengthened (stable)
- **Weekly Insights**: "This week: 2 weak spots improved"

---

## Technical Architecture

### Data Hierarchy (Bottom-Up)

```
Questions (IRT-based, existing)
    ↓ (tagged with)
Micro-Skills (atomic thinking units)
    ↓ (grouped into)
Atlas Nodes (misconception patterns)
    ↓ (linked to)
Capsules (90-sec interventions)
    ↓ (validated by)
Retrieval Pools (6-10 questions per capsule)
```

### Example Mapping

**Micro-Skill**: `PHY.LOM.RESOLVE.2D` (Resolve forces into components)

**Atlas Node**: `PHY.LOM.VECTOR_ADD_ERROR` (Student adds magnitudes instead of vectors)
- Linked micro-skills: `PHY.LOM.RESOLVE.2D`, `PHY.LOM.FBD.1`
- Detection: Student got 4/6 wrong on vector questions, selected distractors "A" or "B" (signature errors)

**Capsule**: `CAP_PHY_LOM_001` (Title: "Stop Adding Magnitudes - Use Components")
- 90-second text lesson explaining the mistake and repair rule
- Linked to node `PHY.LOM.VECTOR_ADD_ERROR`

**Retrieval Pool**: `POOL_PHY_LOM_001`
- 6 questions testing vector addition (3 near transfer, 3 contrast transfer)
- System selects 2 random questions per retrieval attempt

---

## Why This is Powerful (Ed-Tech Perspective)

### 1. Rooted in Cognitive Science
- **Misconception Research**: 40+ years of research shows students have systematic, predictable misconceptions
- **Retrieval Practice**: Testing after learning (capsule → questions) improves long-term retention
- **Immediate Feedback**: Capsules delivered right after detection (context is fresh)

### 2. Psychological Impact
- **From Hopeless to Empowered**: "I'm bad at Physics" → "I fixed my vector addition weak spot"
- **Visible Progress**: Students see weak spot counts drop weekly
- **Confidence Building**: Validates that improvement comes from better thinking, not more hours

### 3. Market Differentiation
- **No competitor has this**: Unacademy/Vedantu/Embibe track chapters, not cognitive patterns
- **Coaching Replacement**: Mimics what great teachers do (spot recurring mistakes, intervene precisely)
- **Data Moat**: Mapping 100+ misconceptions across 50 chapters = years of SME work

---

## MVP Scope (4 Weeks)

### What We're Building
1. **Core Loop**: Practice → Detect → Capsule → Retrieval → Score Update
2. **Dashboard Integration**: "Active Weak Spots" card (UI)
3. **Analytics**: Capsule engagement metrics, weekly insights
4. **Content**: 2 chapters already complete (Electrostatics + Units & Measurements)

### What We're NOT Building (Yet)
- ML-powered detection (using rules-based scoring in MVP)
- Daily Quiz integration (Chapter Practice only for MVP)
- Coach/parent dashboard (student-only for MVP)
- Personalized study plans (manual remediation for MVP)

### Pilot Chapters (data already built)
**Physics - Electrostatics**
- 7 atlas nodes, 18 micro-skills, full capsule + retrieval pool set

**Physics - Units & Measurements**
- 7 atlas nodes, 16 micro-skills, 45 chapter practice questions mapped

---

## Success Metrics

### Engagement (Week 4 Checkpoint)
- Capsule delivery rate: 30-40% of chapter practice sessions
- Capsule open rate: 60%+ (not skipped)
- Capsule completion rate: 80%+ (read fully)
- Retrieval pass rate: 50-70% (validates difficulty)

### Learning Outcomes (Week 8 Launch)
- Theta improvement: +0.1 higher for capsule users vs control (A/B test)
- Node score reduction: 40%+ drop after capsule pass
- Relapse rate: <20% of stabilized nodes reactivate within 30 days

### Business Impact (Post-Launch)
- Feature awareness: 50%+ of users see at least 1 capsule in first week
- Retention: +10% 30-day retention for capsule users vs control
- Conversion: Free users upgrade to access capsule history (if gated)

---

## Strategic Decisions

### ✅ Finalized
1. **Tier Access**: **All tiers** (Free, Pro, Ultra) - Maximum reach
2. **Integration**: **Chapter Practice only** (15-question sessions)
3. **Timeline**: **4 weeks** (content already ready for 2 chapters)
4. **Content**: **Product team delivered** (Electrostatics + Units & Measurements)
5. **UX**: **Modal overlay** (immediate post-results)
6. **Pilot**: **Electrostatics + Units & Measurements** (data-ready)
7. **Scoring**: **Full 3-component formula** (skill deficit + signature + recurrence — all data already in Firestore)
8. **Retrieval**: **3 questions, pass 2/3** (2 near + 1 contrast)

### 🔄 To Be Validated
1. **Detection Thresholds**: A/B test node score thresholds (0.75 vs 0.70 vs 0.80)
2. **Retrieval Difficulty**: Adjust question selection if pass rate <50% or >80%
3. **Content Quality**: Disable capsules with skip rate >50%
4. **Scalability**: Validate backend can handle 1000+ concurrent users

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| **Content quality** (GPT-4 capsules are inaccurate) | Human review + pilot test with 10 users per capsule |
| **False positives** (capsules triggered incorrectly) | A/B test thresholds, allow manual dismissal |
| **User fatigue** (too many capsules = annoyance) | Limit to 1 capsule/session, track skip rates |
| **Low engagement** (users skip capsules) | Make content punchy (90 sec max), use modal overlay (not buried in UI) |
| **Backend latency** (scoring takes too long) | Cache atlas node definitions, batch calculations, target <2 sec response |

---

## Implementation Plan (4 Weeks)

### Week 1: Data + Backend
1. Upload Firestore content from `inputs/cognitive_mastery/data1/` (atlas nodes, capsules, pools)
2. Script to tag existing chapter practice questions with `micro_skill_ids`
3. Build scoring engine (skill-deficit formula, MVP thresholds lowered to ~0.40)
4. Build 4 real API endpoints (detect, get capsule, submit retrieval, list weak spots)
5. Hook scoring into chapter practice submission flow

### Week 2: Mobile UI
1. Weak Spot Detected modal
2. Capsule viewer (text + LaTeX, reuse existing widgets)
3. Retrieval screen: 3 questions (reuse QuestionCardWidget)
4. Results screen: pass/fail + node state transition

### Week 3: Dashboard + Integration Testing
1. Active Weak Spots card on home screen (sorted: active → severity → score)
2. End-to-end testing on both pilot chapters
3. Feature flag enabled for internal users

### Week 4: Polish + Launch
1. Analytics events instrumentation
2. Bug fixes from internal testing
3. Soft launch to 20% of users

---

## UI Terminology Guide

### User-Facing Terms (Mobile/Web UI)

| UI Context | Term to Use | Example |
|------------|-------------|---------|
| **Detection Modal** | "Weak Spot Detected" | "⚠️ Weak Spot Detected: Vector Addition" |
| **Capsule Title** | "Fix This Weak Spot" | "Fix This Weak Spot in 90 seconds" |
| **Dashboard Card** | "Active Weak Spots" | "Active Weak Spots (3)" |
| **Success Message** | "Weak Spot Improved!" | "🎉 Weak Spot Improved! Score: 0.82 → 0.49" |
| **Analytics** | "Weak Spots Fixed" | "Total Weak Spots Fixed: 5" |
| **Weekly Insight** | "Weak spots improved" | "This week: 2 weak spots improved" |
| **List Item** | Pattern name | "Vector Addition - detected today" |

### Internal/Technical Terms (Code/APIs/Firestore)

| Technical Context | Term to Use | Example |
|-------------------|-------------|---------|
| **Firestore Collection** | `misconception_nodes` | `/misconception_nodes/{nodeId}` |
| **API Response Field** | `misconception_id` | `{ "misconception_id": "PHY_LOM_001" }` |
| **Code Variables** | `misconceptionScore` | `const misconceptionScore = 0.82` |
| **Service Methods** | `detectMisconceptions()` | `weakSpotService.detectMisconceptions()` |
| **Analytics Events** | `misconception_detected` | `analytics.track('misconception_detected')` |

### Key UI Copy Examples

**Modal After Chapter Practice:**
```
⚠️ Weak Spot Detected

We noticed you're adding force magnitudes instead of
resolving them into components. Let's fix this!

[Read 90-sec Capsule] [Save for Later]
```

**Capsule Screen:**
```
Fix This Weak Spot: Vector Addition

⏱ 90 seconds

[The Problem section]
You're treating forces like regular numbers...

[The Fix section]
ALWAYS resolve forces into x and y components...

[Continue to Validation]
```

**Success State:**
```
🎉 Weak Spot Improved!

Your score: 0.82 → 0.49

You've made great progress on vector addition.
Keep practicing to solidify this!

[Back to Results]
```

**Dashboard Card:**
```
Active Weak Spots (3)

• Vector Addition - detected today
• Free Body Diagrams - 2 days ago
• Force Decomposition - 5 days ago

[View All Weak Spots]

This Week: 2 weak spots improved 🎯
```

---

## Documentation Structure

All docs are in `/docs/03-features/cognitive-mastery/`:

- [x] `COGNITIVE-MASTERY.md` (this file - feature overview & strategy)
- [ ] `01-API-REFERENCE.md` (backend endpoint specs)
- [ ] `02-SCORING-ENGINE-SPEC.md` (weak spot detection algorithm)
- [ ] `03-MOBILE-UI-SPEC.md` (screen layouts, flows, wireframes)
- [ ] `04-ANALYTICS-EVENTS.md` (tracking spec for backend + mobile)
- [ ] `05-IMPLEMENTATION-LOG.md` (weekly progress tracking)
- [ ] `06-TESTING-STRATEGY.md` (QA checklist + test cases)

**Note**: Content creation (capsules, micro-skill tagging) is handled by the product team separately.

---

## Questions?

For technical implementation:
- [API Reference](01-API-REFERENCE.md) - Backend endpoints
- [Scoring Engine](02-SCORING-ENGINE-SPEC.md) - Detection logic
- [Mobile UI Spec](03-MOBILE-UI-SPEC.md) - Screen designs
- [Analytics Events](04-ANALYTICS-EVENTS.md) - Tracking spec
- [Testing Strategy](06-TESTING-STRATEGY.md) - QA checklist

For implementation status:
- [Weekly Log](05-IMPLEMENTATION-LOG.md) - Updated weekly

---

## Implementation Roadmap

Content for 2 pilot chapters (Electrostatics + Units & Measurements) is already complete. Build real from day 1 — no stub phase.

### Firestore Schema

**Static Collections** (loaded from `inputs/cognitive_mastery/data1/`):
```javascript
// atlas_nodes/{nodeId}
{
  atlas_node_id, node_name, node_category,
  micro_skill_ids, capsule_id, pool_id,
  trigger_threshold: 0.40,   // lowered from 0.75 for MVP (skill-deficit-only scoring)
  stability_threshold: 0.20,
  severity_level: "high" | "medium" | "low",
  status: "active"
}

// capsules/{capsuleId}
{
  capsule_id, atlas_node_id, node_name,
  core_misconception,  // "The Problem" section (UI)
  structural_rule,     // "The Fix" section (UI)
  illustrative_example,
  estimated_read_time: 90,
  status: "active"
}

// retrieval_pools/{poolId}
{
  pool_id, atlas_node_id,
  question_ids,           // 3 questions (2 near + 1 contrast)
  pass_rule: { minimum_correct: 2, out_of: 3 }
}
```

**Dynamic Collections**:
```javascript
// users/{userId}/weak_spots/{nodeId}
{
  node_id, current_score,
  node_state: "inactive" | "active" | "improving" | "stable",
  first_detected_at, last_updated_at,
  capsule_status: "delivered" | "opened" | "completed" | "ignored",
  last_capsule_attempt_result
  // NOTE: no previous_score stored here — use event log for history
}

// weak_spot_events (append-only event log)
{
  student_id, atlas_node_id, event_type,
  previous_score, new_score,
  previous_state, new_state,
  created_at
}
```

### Node State Machine
```
inactive → active    (chapter practice: node_score ≥ trigger_threshold)
active → improving   (retrieval: partial pass)
active → stable      (retrieval: full pass)
improving → stable   (next retrieval: full pass)
stable → active      (future chapter: relapse detected)
```

### Scoring Engine (Full Formula — all data already in Firestore)

```
node_score = 0.60 × skill_deficit_score    (error rate per micro-skill)
           + 0.25 × signature_score         (student_answer vs distractor_analysis + diagnostic_focus)
           + 0.15 × recurrence_score        (same weak skills across previous sessions)
```

Weights and thresholds are **per-node** from `atlas_nodes` collection:
- `trigger_threshold: 0.60` → capsule triggered
- `stability_threshold: 0.40` → node marked stable

All three components use data already collected in `chapter_practice_responses`:
- `is_correct` → skill deficit
- `student_answer` + `distractor_analysis` + `diagnostic_focus` (micro-skill) → signature
- Previous session history (query by `chapter_key`) → recurrence

See [Scoring Engine Spec](02-SCORING-ENGINE-SPEC.md) for full implementation.

### API Endpoints
- **POST** `/api/weak-spots/detect` — called after chapter practice completes
- **GET** `/api/capsules/:capsuleId` — fetch capsule content
- **POST** `/api/weak-spots/retrieval` — submit 3 retrieval answers, get pass/fail + state
- **GET** `/api/weak-spots/:userId` — list weak spots for dashboard

### Mobile Screens
- `weak_spot_detected_modal.dart` — post-practice modal if node triggered
- `capsule_screen.dart` — reads `core_misconception` + `structural_rule` from capsule
- `weak_spot_retrieval_screen.dart` — 3 questions, reuse `QuestionCardWidget`
- `weak_spot_results_screen.dart` — pass/fail + new node state
- `active_weak_spots_card.dart` — home screen widget, sorted by: active → severity → score

### Dashboard Display Labels
| Node State | User-Facing Label | Action |
|------------|------------------|--------|
| active | "Needs Strengthening" | "Resume Capsule" |
| improving | "Keep Practicing" | "Continue Reinforcement" |
| stable | "Recently Strengthened" | — |

### Phase 2: Expand (Post-Launch)
- Add more chapters (content creation pipeline)
- Signature distractor detection (upgrade scoring to full formula)
- Daily Quiz integration
- Admin dashboard for capsule skip rates / pass rates
