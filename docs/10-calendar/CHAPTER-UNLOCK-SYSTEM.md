# Chapter Unlock/Scheduling System

## Overview

This document describes the chapter unlock system for JEEVibe's Daily Quiz feature. The system ensures students only receive questions from chapters they've learned based on their JEE exam timeline.

## Problem Statement

Daily quiz currently shows questions from ALL chapters regardless of student's academic timeline. This causes:
- Students facing questions they haven't learned yet
- Unfair theta score penalties
- Poor learning experience and frustration

## Solution

Build a **chapter unlock system** that:
1. Asks students for JEE target exam date during onboarding
2. Determines which chapters should be unlocked based on timeline
3. Filters daily quiz questions to only include unlocked chapters
4. Auto-places late joiners at the correct position (all past chapters unlocked)

## Design Options

We have two implementation approaches:

| Aspect | Option A (Countdown) | Option B (Grade-based) |
|--------|---------------------|------------------------|
| **Calendars** | 1 (24-month) | 2 (11th + 12th) |
| **Grade calc** | Not needed | Required |
| **Dropdown** | Never changes | Review yearly |
| **School alignment** | Low | High |
| **Complexity** | Lower | Medium |
| **Existing data** | Need to transform | Can use coaching schedule directly |
| **User mental model** | "X months to exam" | "I'm in 11th/12th" |

### Option A: 24-Month Countdown Timeline (Recommended)
- Single unified curriculum ending at January JEE exam
- Position calculated as: `24 - monthsUntilExam + 1`
- See: [OPTION-A-COUNTDOWN-TIMELINE.md](./OPTION-A-COUNTDOWN-TIMELINE.md)

### Option B: Grade-Based Calendars
- Separate calendars for 11th and 12th grade
- Aligned with school academic year (April-March)
- See: [OPTION-B-GRADE-CALENDARS.md](./OPTION-B-GRADE-CALENDARS.md)

---

## UI Messaging Discussion

**Key Insight:** If we use "X months to JEE" as the unified messaging, Option A becomes strictly better since:
1. Simpler backend (1 calendar vs 2)
2. No grade calculation needed
3. Identical user experience
4. "8 months to JEE" is more actionable than "You're in 12th grade"

**Recommended Messaging:**

| UI Element | Message |
|------------|---------|
| Dashboard header | "8 months to JEE January 2027" |
| Chapter unlock | "Optics unlocks in 2 weeks" |
| Progress | "17 of 40 chapters unlocked" |

The only reason to choose Option B is if we explicitly want to display "11th grade" / "12th grade" terminology in the UI for familiarity with school structure.

**Current Recommendation:** Option A with "X months to JEE" messaging

---

## Why 24 Months?

The 24-month timeline is a **universal buffer** that accommodates different coaching schedules across India:

| Coaching Center | Typical Start | Maps to Month |
|-----------------|---------------|---------------|
| Early/Foundation batches | Jan-Feb | Month 1-2 |
| Allen, Resonance | March | Month 3 |
| FIITJEE, Aakash | April | Month 4 |
| School boards, PW | April-May | Month 4-5 |

**For JEE January 2027:**
```
Month 1:  Jan 2025  → Buffer for early starters
Month 3:  Mar 2025  → Most coaching centers start
Month 16: Apr 2026  → 12th grade / advanced topics
Month 20: Aug 2026  → Syllabus completion
Month 24: Jan 2027  → JEE exam
```

**Key point:** Most students will be auto-placed at month 3-5 when they join. The "extra" months provide flexibility without affecting the core experience.

---

## Example Scenarios (Today: February 2026)

### Scenario A: Student entering 11th grade in May 2026
**Target exam: JEE January 2028**

| When they join | Months to JEE | Position | Chapters Unlocked |
|----------------|---------------|----------|-------------------|
| Feb 2026 (now) | 23 months | Month 2 | Foundation chapters only |
| May 2026 | 20 months | Month 5 | Units, Kinematics, Laws of Motion, Basic Concepts, Atomic Structure, Sets, Trigonometry, Complex Numbers |
| Oct 2026 | 15 months | Month 10 | All 11th chapters up to Oct schedule |
| Jan 2027 | 12 months | Month 13 | Full 11th syllabus |

**UI shows:** "20 months to JEE January 2028" (when joining May 2026)

---

### Scenario B: Student entering 12th grade in May 2026
**Target exam: JEE January 2027**

| When they join | Months to JEE | Position | Chapters Unlocked |
|----------------|---------------|----------|-------------------|
| Feb 2026 (now) | 11 months | Month 14 | All 11th + early 12th (Electrostatics, Current Electricity, Solutions) |
| May 2026 | 8 months | Month 17 | All 11th + 12th through May (adds Magnetic Effects, EMI, Optics, Organic Chem) |
| Oct 2026 | 3 months | Month 22 | Full syllabus (revision mode) |

**UI shows:** "8 months to JEE January 2027" (when joining May 2026)

---

### Scenario C: Dropper joining in May 2026
**Target exam: JEE January 2027** (same as 12th grader above)

| When they join | Months to JEE | Position | Chapters Unlocked |
|----------------|---------------|----------|-------------------|
| May 2026 | 8 months | Month 17 | All chapters through Month 17 |

**Key insight:** The system treats droppers identically to 12th graders targeting the same exam. No special handling needed - just "months to JEE" determines everything.

---

### Scenario D: Early starter (10th grader) joining Feb 2026
**Target exam: JEE January 2028**

| When they join | Months to JEE | Position | Chapters Unlocked |
|----------------|---------------|----------|-------------------|
| Feb 2026 (now) | 23 months | Month 2 | Foundation/early chapters |

**UI shows:** "23 months to JEE January 2028"

This student gets the same experience as a future 11th grader - they're just starting earlier and will have more time to master each chapter.

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Late joiner handling | Unlock all past chapters | No drip unlock - immediate access |
| Coaching differentiation | None | Same schedule for all students |
| JEE dates | Hardcoded | Session 1: Jan 20-30, Session 2: Apr 1-15 |
| Schedule storage | Firestore | Allows yearly updates without code deploys |

## Implementation Checklist

### Backend
- [ ] Create `chapterUnlockService.js` - core unlock logic
- [ ] Create `seed-countdown-schedule.js` - populate Firestore schedule
- [ ] Modify `dailyQuizService.js` - filter by unlocked chapters
- [ ] Modify `chapterPracticeService.js` - check unlock before practice
- [ ] Update `users.js` routes - accept `jeeTargetExamDate` field
- [ ] Create migration script for existing ~7 users

### Mobile
- [ ] Update `onboarding_step1_screen.dart`:
  - Replace "Current Class" dropdown with "JEE Target Date" dropdown
  - Remove `currentClass` field (no longer needed)
  - Move "Are you enrolled in coaching?" to Step 2 (make it optional)
- [ ] Update `onboarding_step2_screen.dart`:
  - Add "Are you enrolled in coaching?" question (optional)
- [ ] Update `user_profile.dart` model - add `jeeTargetExamDate` field

### Data
- [ ] Seed 24-month unlock schedule to Firestore
- [ ] Run migration script for existing users

---

## Related Files

- Source schedule: `inputs/guides/coaching_unlock_schedule_updated.json`
- Daily quiz service: `backend/src/services/dailyQuizService.js`
- Chapter practice: `backend/src/services/chapterPracticeService.js`
- Onboarding: `mobile/lib/screens/onboarding/onboarding_step1_screen.dart`
