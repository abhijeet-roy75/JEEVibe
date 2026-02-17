# Cognitive Mastery - Testing Strategy

## Overview

Three layers of testing, matching the feature's three main components:
1. **Backend** — scoring engine + API endpoints
2. **Mobile** — UI screens + navigation
3. **End-to-End** — full flow + edge cases

Plus a **manual QA checklist** before soft launch.

---

## 1. Backend Unit Tests

Location: `backend/tests/weakSpotScoringService.test.js`

### 1.1 Scoring Engine — Component 1: Skill Deficit

#### Test: No trigger — all correct
```javascript
// All answers correct → deficit = 0 → skill component = 0
const responses = [
  { question_id: 'Q1', is_correct: true, student_answer: 'C', distractor_analysis: {} },
  { question_id: 'Q2', is_correct: true, student_answer: 'B', distractor_analysis: {} },
];
const deficit = calcSkillDeficitScore(responses, questionSkillMap, nodeSkillIds);
expect(deficit).toBe(0);
```

#### Test: Full deficit — all wrong
```javascript
// All answers wrong → deficit = 1.0 per skill → avg = 1.0
const responses = [
  { question_id: 'Q1', is_correct: false, student_answer: 'A', distractor_analysis: {} },
  { question_id: 'Q2', is_correct: false, student_answer: 'B', distractor_analysis: {} },
];
const deficit = calcSkillDeficitScore(responses, questionSkillMap, nodeSkillIds);
expect(deficit).toBeCloseTo(1.0);
```

#### Test: Partial deficit — mixed across two micro-skills
```javascript
// Skill A: 2/3 wrong = 0.667, Skill B: 1/2 wrong = 0.50
// avg deficit = (0.667 + 0.50) / 2 = 0.583
expect(deficit).toBeCloseTo(0.583);
```

#### Test: micro-skill not tested in session
```javascript
// Node has skill A + skill B, session only touches skill A
// Score based on skill A only (skill B skipped, not averaged as 0)
const deficit = calcSkillDeficitScore(responses, questionSkillMap, ['SKILL_A', 'SKILL_B']);
// Only SKILL_A questions in responses
expect(result.testedSkillCount).toBe(1);
```

#### Test: min_signal_count not met → not scored
```javascript
// Node requires min_signal_count = 2, only 1 question touches node micro-skills
const result = await scoreNode(responses, questionSkillMap, microSkillMap, atlasNode, userId, db);
expect(result.tested).toBe(false);
```

#### Test: No questions for node at all → not scored
```javascript
const responses = [{ question_id: 'UNRELATED_Q1', is_correct: false }];
const result = await scoreNode(responses, questionSkillMap, microSkillMap, atlasNode, userId, db);
expect(result.tested).toBe(false);
```

---

### 1.2 Scoring Engine — Component 2: Signature Score

#### Test: Perfect signature match — all wrong answers match diagnostic_focus
```javascript
// student_answer: "A", distractor_analysis["A"]: "component resolution error..."
// micro_skill.diagnostic_focus: ["component_resolution_error"]
// → "component resolution error" contains "component resolution error" → match
const responses = [
  {
    question_id: 'Q1', is_correct: false, student_answer: 'A',
    distractor_analysis: { A: 'component resolution error — student added magnitudes' }
  }
];
const microSkillMap = {
  'SKILL_A': { diagnostic_focus: ['component_resolution_error'] }
};
const sig = calcSignatureScore(responses, questionSkillMap, microSkillMap, ['SKILL_A']);
expect(sig).toBeCloseTo(1.0);
```

#### Test: No signature match — wrong answer but unrelated error
```javascript
// student_answer: "B", distractor_analysis["B"]: "unit conversion error"
// diagnostic_focus: ["component_resolution_error"] → no match
const sig = calcSignatureScore(responses, questionSkillMap, microSkillMap, nodeSkillIds);
expect(sig).toBe(0);
```

#### Test: Partial signature match — 2/4 wrong answers match
```javascript
// 4 wrong answers: 2 match diagnostic_focus, 2 don't
const sig = calcSignatureScore(responses, questionSkillMap, microSkillMap, nodeSkillIds);
expect(sig).toBeCloseTo(0.5);
```

#### Test: No wrong answers → signature score = 0
```javascript
// All answers correct → no wrong responses to check
const responses = allCorrectResponses;
const sig = calcSignatureScore(responses, questionSkillMap, microSkillMap, nodeSkillIds);
expect(sig).toBe(0);
```

#### Test: distractor_analysis missing → graceful degradation (no crash)
```javascript
// Question has no distractor_analysis field
const responses = [{ question_id: 'Q1', is_correct: false, student_answer: 'A' }];
expect(() => calcSignatureScore(responses, ...)).not.toThrow();
const sig = calcSignatureScore(responses, questionSkillMap, microSkillMap, nodeSkillIds);
expect(sig).toBe(0); // no crash, contributes 0
```

---

### 1.3 Scoring Engine — Component 3: Recurrence Score

#### Test: First session — recurrence = 0
```javascript
// No previous sessions for this chapter → recurrence = 0
const rec = await calcRecurrenceScore(userId, 'physics_electrostatics', nodeSkillIds, questionSkillMap, sessionId, db);
expect(rec).toBe(0);
```

#### Test: Previous sessions with same weak skills → high recurrence
```javascript
// Mock 2 previous sessions: both had ~70% wrong on this node's skills
const rec = await calcRecurrenceScore(...);
expect(rec).toBeGreaterThan(0.6);
```

#### Test: Previous sessions with strong performance → low recurrence
```javascript
// Mock 2 previous sessions: mostly correct on this node's skills
const rec = await calcRecurrenceScore(...);
expect(rec).toBeLessThan(0.3);
```

---

### 1.4 Scoring Engine — Full Node Score + Trigger

#### Test: Full formula — high deficit + signature + recurrence triggers node
```javascript
// skill_deficit = 0.833, signature = 0.75, recurrence = 0.70
// node_score = 0.60×0.833 + 0.25×0.75 + 0.15×0.70 = 0.793
// trigger_threshold (from atlas node) = 0.60 → triggered ✅
const result = await scoreNode(responses, questionSkillMap, microSkillMap, atlasNode, userId, db);
expect(result.nodeScore).toBeCloseTo(0.793);
expect(result.nodeScore).toBeGreaterThanOrEqual(atlasNode.trigger_threshold);
```

#### Test: High deficit alone NOT enough to trigger (threshold = 0.60)
```javascript
// skill_deficit = 1.0, signature = 0, recurrence = 0
// node_score = 0.60×1.0 + 0 + 0 = 0.60 → exactly at threshold → triggered
// (edge case — boundary test)
expect(result.nodeScore).toBeCloseTo(0.60);
// 0.60 >= 0.60 → triggered
expect(result.triggered).toBe(true);
```

#### Test: Moderate deficit + no recurrence → below threshold
```javascript
// skill_deficit = 0.50, signature = 0, recurrence = 0
// node_score = 0.60×0.50 = 0.30 < 0.60 → not triggered
expect(result.nodeScore).toBeCloseTo(0.30);
expect(result.triggered).toBe(false);
```

#### Test: Multiple nodes — highest severity + highest score wins
```javascript
// Node A: score 0.80, severity "medium"
// Node B: score 0.72, severity "high"
// Result should be Node B (severity wins over score)
const result = await detectWeakSpots(userId, sessionId, db);
expect(result.nodeId).toBe('NODE_B');
```

#### Test: Multiple nodes — same severity, higher score wins
```javascript
// Node A: score 0.80, severity "high"
// Node B: score 0.72, severity "high"
// Result should be Node A
const result = await detectWeakSpots(userId, sessionId, db);
expect(result.nodeId).toBe('NODE_A');
```

### 1.5 Retrieval Scoring

Thresholds from atlas_nodes data: `trigger_threshold: 0.60`, `stability_threshold: 0.40`

#### Test: Pass (2/3 correct) — score decays below stability_threshold → state stable
```javascript
const result = evaluateRetrieval(
  [{ is_correct: true }, { is_correct: true }, { is_correct: false }],
  { current_score: 0.70, trigger_threshold: 0.60, stability_threshold: 0.40 }
);
expect(result.passed).toBe(true);
expect(result.correctCount).toBe(2);
expect(result.newScore).toBeCloseTo(0.35); // 0.70 * 0.5 = 0.35 ≤ 0.40
expect(result.newState).toBe('stable');
```

#### Test: Pass (2/3 correct) — score decays but stays above stability_threshold → state improving
```javascript
const result = evaluateRetrieval(
  [{ is_correct: true }, { is_correct: true }, { is_correct: false }],
  { current_score: 0.90, trigger_threshold: 0.60, stability_threshold: 0.40 }
);
expect(result.passed).toBe(true);
expect(result.newScore).toBeCloseTo(0.45); // 0.90 * 0.5 = 0.45 > 0.40
expect(result.newState).toBe('improving');
```

#### Test: Fail (1/3 correct) → state stays active, score increases slightly
```javascript
const result = evaluateRetrieval(
  [{ is_correct: true }, { is_correct: false }, { is_correct: false }],
  { current_score: 0.70, trigger_threshold: 0.60, stability_threshold: 0.40 }
);
expect(result.passed).toBe(false);
expect(result.newState).toBe('active');
expect(result.newScore).toBeCloseTo(0.735); // 0.70 * 1.05
```

#### Test: Fail (0/3 correct) → score increases, capped at 1.0
```javascript
const result = evaluateRetrieval(
  [{ is_correct: false }, { is_correct: false }, { is_correct: false }],
  { current_score: 0.99, trigger_threshold: 0.60, stability_threshold: 0.40 }
);
expect(result.passed).toBe(false);
expect(result.newScore).toBe(1.0); // 0.99 * 1.05 = 1.0395, capped
```

### 1.3 Event Log

#### Test: State change writes event
```javascript
await detectWeakSpots(userId, sessionId); // triggers node
const events = await getWeakSpotEvents(userId, nodeId);
expect(events).toHaveLength(1);
expect(events[0].event_type).toBe('chapter_detected');
expect(events[0].previous_state).toBe('inactive');
expect(events[0].new_state).toBe('active');
```

#### Test: Relapse writes event
```javascript
// Node was stable, new chapter session triggers it again
const events = await getWeakSpotEvents(userId, nodeId);
const relapseEvent = events.find(e => e.previous_state === 'stable' && e.new_state === 'active');
expect(relapseEvent).toBeDefined();
```

---

## 2. Backend API Integration Tests

Location: `backend/tests/weakSpots.routes.test.js`

### 2.1 POST /api/weak-spots/detect

| Test | Input | Expected |
|------|-------|---------|
| Weak spot detected | session with 3/4 wrong on node micro-skills | `detected: true`, `weakSpot` object |
| No weak spot | session with mostly correct answers | `detected: false`, `weakSpot: null` |
| Session not found | invalid `sessionId` | 404 error |
| Unauthenticated | no auth token | 401 error |
| Feature flag off | `cognitive_mastery_enabled: false` | `detected: false` (no scoring) |

### 2.2 GET /api/capsules/:capsuleId

| Test | Input | Expected |
|------|-------|---------|
| Valid capsule | existing `capsuleId` | capsule object with all fields |
| Not found | non-existent `capsuleId` | 404 error |
| Unauthenticated | no auth token | 401 error |

### 2.3 POST /api/weak-spots/retrieval

| Test | Input | Expected |
|------|-------|---------|
| Pass 2/3 (high score) | 2 correct, 1 wrong, current_score 0.90 | `passed: true`, `newState: "improving"` |
| Pass 2/3 (lower score) | 2 correct, 1 wrong, current_score 0.70 | `passed: true`, `newState: "stable"` |
| Fail 1/3 | 1 correct, 2 wrong | `passed: false`, `newState: "active"` |
| Fail 0/3 | 0 correct | `passed: false`, score increased |
| Wrong question count | 2 responses (not 3) | 400 error |
| Node not active | node in stable state | 400 error (can't do retrieval on stable node) |

### 2.4 GET /api/weak-spots/:userId

| Test | Input | Expected |
|------|-------|---------|
| Has weak spots | user with 3 active nodes | array of 3, sorted by severity |
| No weak spots | new user | empty array |
| Filter by state | `?nodeState=active` | only active nodes |
| Another user's data | different userId | 403 error |

---

## 3. Mobile UI Tests

Location: `mobile/test/cognitive_mastery/`

### 3.1 WeakSpotDetectedModal

```dart
// Test: shows node name and truncated description
testWidgets('shows weak spot title', (tester) async {
  await tester.pumpWidget(WeakSpotDetectedModal(
    nodeId: 'PHY_ELEC_VEC_001',
    title: 'Vector Superposition Error',
    description: 'You are adding field magnitudes...',
    capsuleId: 'CAP_001',
  ));
  expect(find.text('Vector Superposition Error'), findsOneWidget);
  expect(find.text('Read Capsule (90s) ✨'), findsOneWidget);
  expect(find.text('Save for Later'), findsOneWidget);
});

// Test: "Save for Later" calls dismiss callback
testWidgets('save for later dismisses modal', (tester) async {
  bool dismissed = false;
  await tester.pumpWidget(WeakSpotDetectedModal(
    onSaveForLater: () => dismissed = true,
    ...
  ));
  await tester.tap(find.text('Save for Later'));
  expect(dismissed, isTrue);
});
```

### 3.2 CapsuleScreen

```dart
// Test: renders all three sections
testWidgets('renders problem, fix, example', (tester) async {
  // ...
  expect(find.text('The Problem'), findsOneWidget);
  expect(find.text('The Fix'), findsOneWidget);
  expect(find.text('Example'), findsOneWidget);
});

// Test: "Continue to Validation" button navigates
testWidgets('continue button navigates to retrieval', (tester) async {
  await tester.tap(find.text('Continue to Validation'));
  await tester.pumpAndSettle();
  expect(find.byType(WeakSpotRetrievalScreen), findsOneWidget);
});
```

### 3.3 WeakSpotRetrievalScreen

```dart
// Test: shows correct progress header
testWidgets('shows progress 1/3 on first question', (tester) async {
  // ...
  expect(find.text('Validation (1/3)'), findsOneWidget);
});

// Test: advances to next question on submit
testWidgets('advances to question 2 after answer', (tester) async {
  await tester.tap(find.text('A')); // select option
  await tester.tap(find.text('Submit Answer'));
  await tester.pumpAndSettle();
  expect(find.text('Validation (2/3)'), findsOneWidget);
});

// Test: submits to API after question 3
testWidgets('submits retrieval after 3rd answer', (tester) async {
  // answer all 3, verify API called once
});
```

### 3.4 WeakSpotResultsScreen

```dart
// Test: pass state shows correct UI
testWidgets('pass state shows Weak Spot Improved', (tester) async {
  await tester.pumpWidget(WeakSpotResultsScreen(
    passed: true, correctCount: 2, totalQuestions: 3, newState: 'improving',
  ));
  expect(find.text('Weak Spot Improved! 🎉'), findsOneWidget);
  expect(find.text('Keep Practicing'), findsOneWidget); // node state label
});

// Test: fail state shows Keep Practicing
testWidgets('fail state shows encouragement', (tester) async {
  await tester.pumpWidget(WeakSpotResultsScreen(
    passed: false, correctCount: 1, totalQuestions: 3, newState: 'active',
  ));
  expect(find.text('Keep Practicing'), findsOneWidget);
  expect(find.text('Needs Strengthening'), findsOneWidget); // node state label
});
```

### 3.5 ActiveWeakSpotsCard

```dart
// Test: empty state
testWidgets('shows empty state when no active weak spots', (tester) async {
  // mock API returns []
  expect(find.text('No Active Weak Spots 🎉'), findsOneWidget);
});

// Test: sorts correctly — active before improving, high severity first
testWidgets('sorts by state then severity', (tester) async {
  // mock returns: [improving/low, active/high, active/medium]
  // expected order: active/high, active/medium, improving/low
});

// Test: shows max 3
testWidgets('shows at most 3 weak spots', (tester) async {
  // mock returns 5 active nodes
  expect(find.byType(WeakSpotListItem), findsNWidgets(3));
});
```

---

## 4. End-to-End Scenarios

Run manually against dev environment (or automated with integration test runner).

### Scenario 1: Happy Path (Full Loop)
1. Complete Electrostatics chapter practice, answer 3/4 vector questions wrong
2. ✅ Detection modal appears with "Vector Superposition Error"
3. Tap "Read Capsule" → capsule screen opens with problem/fix/example
4. Scroll to bottom → "Continue to Validation" enabled
5. Answer 3 retrieval questions, get 2/3 correct
6. ✅ Results: "Weak Spot Improved!" + "Keep Practicing" label
7. Navigate to home → Active Weak Spots card shows node as "Keep Practicing"
8. Check Firestore: node state = "improving", event log has 2 entries

### Scenario 2: Skip Capsule → Save for Later
1. Complete chapter practice, weak spot detected
2. Tap "Save for Later" on modal
3. ✅ Modal dismissed, no capsule shown
4. Home screen → Active Weak Spots card shows "Needs Strengthening"
5. Tap node → opens capsule from dashboard
6. Check Firestore: `capsule_status = "ignored"`

### Scenario 3: Fail Retrieval
1. Complete chapter practice, weak spot triggered
2. Read capsule, proceed to retrieval
3. Answer 1/3 correct
4. ✅ Results: "Keep Practicing" + "Needs Strengthening" label
5. Check Firestore: node stays "active", score increased slightly

### Scenario 4: Relapse Detection
1. Complete chapter practice (Electrostatics), node becomes "stable"
2. Complete another Electrostatics session, same weak spot reactivated
3. ✅ Detection modal appears again
4. Check Firestore: event log shows stable → active transition

### Scenario 5: No Weak Spot Triggered
1. Complete chapter practice with mostly correct answers
2. ✅ No detection modal appears
3. Chapter practice results shown normally
4. Home screen: no change to Active Weak Spots card

### Scenario 6: Feature Flag Off
1. Set `cognitive_mastery_enabled: false` in `tier_config/active`
2. Complete chapter practice with wrong answers
3. ✅ No detection modal appears
4. No weak_spot_events written to Firestore

### Scenario 7: Units & Measurements Chapter
1. Repeat Scenarios 1-3 for Units & Measurements chapter
2. Verify different nodes/capsules load correctly (cross-chapter check)

---

## 5. Manual QA Checklist (Pre-Soft-Launch)

### Backend
- [ ] Detection returns correct node for known "all wrong" session
- [ ] Detection returns `null` for known "all correct" session
- [ ] Capsule content renders with correct `coreMisconception` and `structuralRule`
- [ ] Retrieval pass/fail updates Firestore `node_state` correctly
- [ ] Event log has entry after every state change
- [ ] Feature flag disables scoring when `cognitive_mastery_enabled: false`
- [ ] API latency < 2 sec for detection endpoint (check Render.com logs)

### Mobile
- [ ] Detection modal appears after chapter practice (Electrostatics)
- [ ] Detection modal appears after chapter practice (Units & Measurements)
- [ ] LaTeX renders correctly in capsule text
- [ ] Retrieval progress header counts correctly (1/3, 2/3, 3/3)
- [ ] Pass result shows "Weak Spot Improved! 🎉"
- [ ] Fail result shows "Keep Practicing" with encouragement text
- [ ] Active Weak Spots card appears on home screen
- [ ] Empty state shows when no active nodes
- [ ] "Save for Later" dismisses modal and shows node in dashboard
- [ ] "View All Weak Spots" navigates to full list screen
- [ ] No crashes (check Crashlytics after 30 mins of testing)

### Data Integrity
- [ ] `users/{userId}/weak_spots/{nodeId}` updated correctly after detection
- [ ] `users/{userId}/weak_spots/{nodeId}` updated correctly after retrieval
- [ ] `weak_spot_events` has append-only entries (no overwrites)
- [ ] `capsule_status` transitions: `delivered → opened → completed` (or `ignored`)

---

## 6. Performance Targets

| Operation | Target | How to Measure |
|-----------|--------|----------------|
| Detection latency | < 2 sec | Render.com request logs |
| Capsule load time | < 1 sec | Mobile network profiler |
| Retrieval submission | < 1 sec | Mobile network profiler |
| Dashboard card load | < 500ms | Flutter DevTools |

---

## Related Documentation

- [Scoring Engine](02-SCORING-ENGINE-SPEC.md) — algorithm under test
- [API Reference](01-API-REFERENCE.md) — endpoint contracts
- [Mobile UI Spec](03-MOBILE-UI-SPEC.md) — screens under test
- [Implementation Log](05-IMPLEMENTATION-LOG.md) — testing tasks in Week 3
