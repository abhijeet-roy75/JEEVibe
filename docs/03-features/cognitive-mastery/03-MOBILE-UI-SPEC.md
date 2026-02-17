# Cognitive Mastery - Mobile UI Specification

## Overview

This document specifies all mobile screens and user flows for the Cognitive Mastery feature.

**Capsule content fields** (from Firestore `capsules` collection):
- `coreMisconception` → "The Problem" section
- `structuralRule` → "The Fix" section
- `illustrativeExample` → example block

---

## Screen Inventory

| Screen | File | Purpose |
|--------|------|---------|
| **1. Weak Spot Detection Modal** | `weak_spot_detected_modal.dart` | Alert after chapter practice |
| **2. Capsule Viewer** | `capsule_screen.dart` | Display 90-sec lesson |
| **3. Retrieval Questions** | `weak_spot_retrieval_screen.dart` | 3 validation questions |
| **4. Retrieval Results** | `weak_spot_results_screen.dart` | Pass/fail + node state |
| **5. Active Weak Spots Card** | `active_weak_spots_card.dart` | Home screen dashboard widget |
| **6. All Weak Spots List** | `all_weak_spots_screen.dart` | Full history |

---

## User Flow

```
Chapter Practice Session Completes
    ↓
Backend scores session, detects weak spot (server-side)
Chapter practice completion response includes weak spot if triggered
    ↓
If weakSpot != null in response:
    ↓
SCREEN 1: Weak Spot Detection Modal
    ↓ (tap "Read Capsule")
[GET /api/capsules/:capsuleId]
    ↓
SCREEN 2: Capsule Viewer
    ↓ (tap "Continue to Validation")
[retrieval questions included in capsule response]
    ↓
SCREEN 3: Retrieval Questions (3 questions: 2 near + 1 contrast)
    ↓ (submit all 3)
[POST /api/weak-spots/retrieval]
    ↓
SCREEN 4: Results (pass: 2+/3 correct)
    ↓
Back to Home
    ↓
SCREEN 5: Active Weak Spots Card (reflects new state)
```

---

## SCREEN 1: Weak Spot Detection Modal

### Purpose
Alert user immediately after chapter practice that a weak spot was detected. Shown as modal over results screen.

### Design

```
┌─────────────────────────────────┐
│  ⚠️ Weak Spot Detected           │
│                                 │
│  Vector Superposition Error     │ ← node_name
│                                 │
│  You're adding field magnitudes │
│  without resolving into         │ ← first line of coreMisconception
│  components. Let's fix this!    │
│                                 │
│  ┌─────────────────────────┐   │
│  │   Read Capsule (90s) ✨ │   │ ← Primary CTA
│  └─────────────────────────┘   │
│                                 │
│        Save for Later           │ ← dismisses, marks capsule_status: "ignored"
└─────────────────────────────────┘
```

**Data source:** `weakSpot` object in chapter practice completion response

**Actions:**
- **Read Capsule** → fetch capsule, navigate to Screen 2
- **Save for Later** → dismiss, `capsule_status = "ignored"`, visible in dashboard

---

## SCREEN 2: Capsule Viewer

### Purpose
Display the 90-second lesson. Reads `coreMisconception`, `structuralRule`, `illustrativeExample` from capsule.

### Design

```
┌─────────────────────────────────┐
│  ←  Fix This Weak Spot   ⏱ 90s │
│                                 │
│  Vector Superposition Error     │ ← node_name
│  ─────────────────────────────  │
│                                 │
│  The Problem                    │
│  ─────────                      │
│  [coreMisconception text]       │ ← LaTeX-rendered
│                                 │
│  The Fix                        │
│  ──────                         │
│  [structuralRule text]          │ ← LaTeX-rendered
│                                 │
│  Example                        │
│  ───────                        │
│  [illustrativeExample text]     │ ← LaTeX-rendered
│                                 │
│  ┌─────────────────────────┐   │
│  │  Continue to Validation │   │ ← navigates to Screen 3
│  └─────────────────────────┘   │
│                                 │
│         Skip for Now            │ ← marks capsule_status: "completed" (read), skips retrieval
└─────────────────────────────────┘
```

**Widgets to reuse:** `LatexWidget` for all text content

**On scroll to bottom:** mark `capsule_status = "completed"` (read fully)

---

## SCREEN 3: Retrieval Questions

### Purpose
3 questions (2 near transfer + 1 contrast transfer) to validate understanding. Reuse existing question UI.

### Design

```
┌─────────────────────────────────┐
│  ←  Validation (1/3)            │ ← progress header
│                                 │
│  [QuestionCardWidget — reused]  │
│  - Question text (LaTeX)        │
│  - Options A, B, C, D           │
│                                 │
│  ┌─────────────────────────┐   │
│  │      Submit Answer      │   │
│  └─────────────────────────┘   │
└─────────────────────────────────┘
```

**Pass rule:** 2 out of 3 correct

**Widgets to reuse:** `QuestionCardWidget` from daily quiz — same component, different header

**No timer** — retrieval questions are untimed

**After question 3:** submit all responses to `POST /api/weak-spots/retrieval`, navigate to Screen 4

---

## SCREEN 4: Retrieval Results

### Pass (2+/3 correct)

```
┌─────────────────────────────────┐
│  🎉 Weak Spot Improved!          │
│                                 │
│  You got 2/3 correct.           │
│                                 │
│  Keep practicing to solidify    │
│  this. It's now marked as       │
│  "Keep Practicing" on your      │
│  dashboard.                     │
│                                 │
│  ┌─────────────────────────┐   │
│  │      Back to Home       │   │
│  └─────────────────────────┘   │
└─────────────────────────────────┘
```

### Fail (<2/3 correct)

```
┌─────────────────────────────────┐
│  Keep Practicing                │
│                                 │
│  You got 1/3 correct.           │
│                                 │
│  This weak spot still Needs     │
│  Strengthening. Try more        │
│  chapter practice, then come    │
│  back to fix it.                │
│                                 │
│  ┌─────────────────────────┐   │
│  │      Back to Home       │   │
│  └─────────────────────────┘   │
└─────────────────────────────────┘
```

**Node state → label mapping:**
| `newState` | User-facing label |
|------------|------------------|
| `active` | "Needs Strengthening" |
| `improving` | "Keep Practicing" |
| `stable` | "Recently Strengthened" |

---

## SCREEN 5: Active Weak Spots Card (Dashboard)

### Purpose
Home screen widget. Shows top 3 active/improving weak spots.

**Sort order:** active first → then by `severity_level` (high > medium > low) → then by `current_score` descending

### Design

```
┌─────────────────────────────────┐
│  Active Weak Spots (3)          │
│                                 │
│  • Vector Superposition Error   │ ← active, high severity, score 0.50
│    Needs Strengthening          │
│                                 │
│  • Dimensional Formula          │ ← improving, medium severity
│    Keep Practicing              │
│                                 │
│  • Unit Conversion Logic        │ ← active, low severity
│    Needs Strengthening          │
│                                 │
│  View All Weak Spots →          │
└─────────────────────────────────┘
```

**Empty state** (no active/improving weak spots):
```
┌─────────────────────────────────┐
│  No Active Weak Spots 🎉        │
│                                 │
│  Complete chapter practice to   │
│  discover weak spots.           │
└─────────────────────────────────┘
```

---

## SCREEN 6: All Weak Spots List

Shows all weak spots grouped by state.

```
┌─────────────────────────────────┐
│  ←  My Weak Spots               │
│                                 │
│  NEEDS STRENGTHENING (2)        │
│  ─────────────────────          │
│  • Vector Superposition Error   │
│    Electrostatics · High        │
│    [Resume Capsule]             │
│                                 │
│  • Unit Conversion              │
│    Units & Meas. · Medium       │
│    [Resume Capsule]             │
│                                 │
│  KEEP PRACTICING (1)            │
│  ──────────────────             │
│  • Dimensional Formula          │
│    Units & Meas. · Low          │
│                                 │
│  RECENTLY STRENGTHENED (1)      │
│  ──────────────────────         │
│  • Error Propagation            │
│    Units & Meas.                │
└─────────────────────────────────┘
```

---

## Files to Create

| File | Location |
|------|----------|
| `weak_spot_detected_modal.dart` | `mobile/lib/screens/` |
| `capsule_screen.dart` | `mobile/lib/screens/` |
| `weak_spot_retrieval_screen.dart` | `mobile/lib/screens/` |
| `weak_spot_results_screen.dart` | `mobile/lib/screens/` |
| `active_weak_spots_card.dart` | `mobile/lib/widgets/` |
| `all_weak_spots_screen.dart` | `mobile/lib/screens/` |

## Files to Modify

| File | Change |
|------|--------|
| `chapter_practice_results_screen.dart` | Check for `weakSpot` in completion response, show modal |
| `home_screen.dart` | Add `ActiveWeakSpotsCard` widget |

## Widgets to Reuse

| Widget | File | Used In |
|--------|------|---------|
| `QuestionCardWidget` | `mobile/lib/widgets/daily_quiz/question_card_widget.dart` | Retrieval Screen |
| `LatexWidget` | `mobile/lib/widgets/latex_widget.dart` | Capsule Viewer |

---

## Related Documentation

- [API Reference](01-API-REFERENCE.md) - API endpoints
- [Scoring Engine](02-SCORING-ENGINE-SPEC.md) - Detection logic
- [Analytics Events](04-ANALYTICS-EVENTS.md) - Tracking spec
