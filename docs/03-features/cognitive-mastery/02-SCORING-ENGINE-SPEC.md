# Cognitive Mastery - Scoring Engine Specification

## Overview

The scoring engine analyzes chapter practice session responses to detect weak spots and calculate node scores.

**Approach**: Full 3-component formula using data already collected in Firestore. No schema changes required.

---

## Data Sources (All Already in Firestore)

| Input | Firestore Location | Fields Used |
|-------|-------------------|-------------|
| Session responses | `users/{userId}/chapter_practice_responses` | `student_answer`, `correct_answer`, `is_correct`, `time_taken_seconds`, `question_irt_params`, `distractor_analysis` |
| Micro-skill map | `atlas_micro_skills/{chapterKey}` (uploaded from data1/) | `micro_skill_id`, `diagnostic_focus` |
| Question→skill map | `atlas_question_skill_map/{chapterKey}` (uploaded from data1/) | `question_id → [micro_skill_ids]` |
| Atlas nodes | `atlas_nodes/{nodeId}` | `micro_skill_ids`, `scoring_weights`, `trigger_threshold`, `stability_threshold`, `min_signal_count` |
| Previous sessions | `users/{userId}/chapter_practice_responses` (query by `chapter_key`) | `is_correct`, `student_answer` from prior sessions |

---

## Scoring Formula

```
node_score = skill_deficit_weight   × skill_deficit_score    (0.60 per node config)
           + signature_weight       × signature_score         (0.25 per node config)
           + recurrence_weight      × recurrence_score        (0.15 per node config)
```

Weights come from `atlas_node.scoring_weights` — they are **per-node configurable**, not hardcoded.

**Thresholds** (also per-node, from `atlas_nodes` collection):
- `trigger_threshold: 0.60` → node becomes "active", capsule triggered
- `stability_threshold: 0.40` → node becomes "stable"

---

## Component 1: Skill Deficit Score

**What it measures**: Error rate across micro-skills linked to the node.

```javascript
function calcSkillDeficitScore(responses, questionSkillMap, nodeSkillIds) {
  const deficits = [];

  for (const skillId of nodeSkillIds) {
    const skillQuestions = responses.filter(r =>
      (questionSkillMap[r.question_id] || []).includes(skillId)
    );
    if (skillQuestions.length === 0) continue;

    const wrong = skillQuestions.filter(r => !r.is_correct).length;
    deficits.push(wrong / skillQuestions.length); // 0.0 = all correct, 1.0 = all wrong
  }

  if (deficits.length === 0) return null; // node not tested
  return deficits.reduce((a, b) => a + b, 0) / deficits.length;
}
```

**Example**: Node has 2 micro-skills. Student got 3/4 wrong on skill A (deficit 0.75) and 2/3 wrong on skill B (deficit 0.67). `skill_deficit_score = (0.75 + 0.67) / 2 = 0.71`.

---

## Component 2: Signature Score

**What it measures**: Whether the student's wrong answers match known structural error patterns for this node.

**Data flow**:
- `distractor_analysis` on each response: `{ "A": "sign error — treats charge as positive...", "B": "..." }`
- `diagnostic_focus` on each micro-skill: `["sign_error", "inverse_square_error", ...]`
- Match: does the text of `distractor_analysis[student_answer]` contain the error type keyword?

```javascript
function calcSignatureScore(responses, questionSkillMap, microSkillMap, nodeSkillIds) {
  const wrongResponses = responses.filter(r => !r.is_correct && r.student_answer);
  if (wrongResponses.length === 0) return 0;

  // Collect all diagnostic_focus keywords for this node's micro-skills
  const errorKeywords = new Set();
  for (const skillId of nodeSkillIds) {
    const skill = microSkillMap[skillId];
    if (skill?.diagnostic_focus) {
      skill.diagnostic_focus.forEach(e => errorKeywords.add(e.replace(/_/g, ' ')));
    }
  }

  // Check each wrong answer against distractor analysis
  const signatureMatches = wrongResponses.filter(r => {
    const distractorText = (r.distractor_analysis?.[r.student_answer] || '').toLowerCase();
    return [...errorKeywords].some(keyword => distractorText.includes(keyword));
  });

  return signatureMatches.length / wrongResponses.length; // 0.0 to 1.0
}
```

**Example**: Student answered "A" on a vector question. `distractor_analysis["A"] = "component resolution error — student added magnitudes directly"`. Node micro-skill has `diagnostic_focus: ["component_resolution_error"]`. Match → signature confirmed.

**Graceful degradation**: If `distractor_analysis` is absent on a question, that question contributes 0 to signature score — the component still works, just with less signal.

---

## Component 3: Recurrence Score

**What it measures**: Whether this node's micro-skills have been consistently weak across multiple sessions, not just a one-off bad session.

```javascript
async function calcRecurrenceScore(userId, chapterKey, nodeSkillIds, questionSkillMap, currentSessionId, db) {
  // Fetch responses from last 3 sessions for this chapter (excluding current)
  const previousResponses = await db
    .collection(`users/${userId}/chapter_practice_responses`)
    .where('chapter_key', '==', chapterKey)
    .where('session_id', '!=', currentSessionId)
    .orderBy('answered_at', 'desc')
    .limit(45) // ~3 sessions × 15 questions
    .get();

  if (previousResponses.empty) return 0; // first session, no recurrence

  const prevDocs = previousResponses.docs.map(d => d.data());

  // Calculate deficit for node's micro-skills in previous sessions
  const prevDeficits = [];
  for (const skillId of nodeSkillIds) {
    const skillQuestions = prevDocs.filter(r =>
      (questionSkillMap[r.question_id] || []).includes(skillId)
    );
    if (skillQuestions.length === 0) continue;
    const wrong = skillQuestions.filter(r => !r.is_correct).length;
    prevDeficits.push(wrong / skillQuestions.length);
  }

  if (prevDeficits.length === 0) return 0;
  return prevDeficits.reduce((a, b) => a + b, 0) / prevDeficits.length;
}
```

**Example**: Student has done 2 previous Electrostatics sessions. In both, they got 70%+ wrong on vector superposition micro-skills. `recurrence_score ≈ 0.72` — strong signal this is a persistent pattern, not a bad day.

---

## Full Node Scoring Function

```javascript
async function scoreNode(responses, questionSkillMap, microSkillMap, atlasNode, userId, db) {
  const { micro_skill_ids, scoring_weights, trigger_threshold, stability_threshold, min_signal_count } = atlasNode;

  // Check minimum signal — need enough questions tested
  const testedQuestions = responses.filter(r =>
    micro_skill_ids.some(skillId =>
      (questionSkillMap[r.question_id] || []).includes(skillId)
    )
  );
  if (testedQuestions.length < min_signal_count) {
    return { nodeScore: 0, state: 'inactive', tested: false };
  }

  // Calculate all 3 components
  const skillDeficit = calcSkillDeficitScore(responses, questionSkillMap, micro_skill_ids);
  if (skillDeficit === null) return { nodeScore: 0, state: 'inactive', tested: false };

  const signatureScore = calcSignatureScore(responses, questionSkillMap, microSkillMap, micro_skill_ids);

  const recurrenceScore = await calcRecurrenceScore(
    userId, responses[0].chapter_key, micro_skill_ids, questionSkillMap,
    responses[0].session_id, db
  );

  // Apply per-node weights
  const nodeScore =
    scoring_weights.skill_deficit_weight * skillDeficit +
    scoring_weights.signature_weight     * signatureScore +
    scoring_weights.recurrence_weight    * recurrenceScore;

  return { nodeScore, tested: true };
}
```

---

## Full Detection Flow

```javascript
async function detectWeakSpots(userId, sessionId, db) {
  // 1. Load session responses
  const responses = await getSessionResponses(userId, sessionId, db);
  if (!responses.length) return null;

  const chapterKey = responses[0].chapter_key;

  // 2. Load static content (cached in memory, 5-min TTL)
  const [questionSkillMap, microSkillMap, atlasNodes] = await Promise.all([
    getQuestionSkillMap(chapterKey, db),
    getMicroSkillMap(chapterKey, db),
    getAtlasNodes(chapterKey, db)
  ]);

  // 3. Score all nodes
  const scored = [];
  for (const node of atlasNodes) {
    const { nodeScore, tested } = await scoreNode(
      responses, questionSkillMap, microSkillMap, node, userId, db
    );
    if (!tested) continue;

    // 4. Determine state
    const existing = await getUserWeakSpot(userId, node.atlas_node_id, db);
    const newState = nodeScore >= node.trigger_threshold ? 'active'
                   : nodeScore <= node.stability_threshold ? 'stable'
                   : (existing?.node_state || 'inactive');

    // 5. Write state + event log
    await updateWeakSpot(userId, node.atlas_node_id, { nodeScore, newState }, db);
    await logWeakSpotEvent(userId, node.atlas_node_id, {
      event_type: 'chapter_scored',
      previous_score: existing?.current_score ?? 0,
      new_score: nodeScore,
      previous_state: existing?.node_state ?? 'inactive',
      new_state: newState
    }, db);

    if (newState === 'active') {
      scored.push({ ...node, nodeScore, newState });
    }
  }

  // 6. Return highest-severity, highest-scoring triggered node (1 per session)
  scored.sort((a, b) => {
    const severityOrder = { high: 3, medium: 2, low: 1 };
    if (severityOrder[b.severity_level] !== severityOrder[a.severity_level])
      return severityOrder[b.severity_level] - severityOrder[a.severity_level];
    return b.nodeScore - a.nodeScore;
  });

  return scored[0] || null;
}
```

---

## Retrieval Scoring (Post-Capsule)

After student completes 3 retrieval questions (2 near + 1 contrast):

```javascript
function evaluateRetrieval(responses, atlasNode) {
  const correctCount = responses.filter(r => r.is_correct).length;
  const passed = correctCount >= 2; // pass rule: 2/3

  let newScore, newState;
  if (passed) {
    newScore = atlasNode.current_score * 0.5; // strong decay
    newState = newScore <= atlasNode.stability_threshold ? 'stable' : 'improving';
  } else {
    newScore = Math.min(atlasNode.current_score * 1.05, 1.0); // light increase, capped
    newState = 'active';
  }

  return { passed, correctCount, totalQuestions: 3, newScore, newState };
}
```

---

## Worked Example (Electrostatics — Vector Superposition Node)

**Node**: `PHY_ELEC_VEC_001`, weights: `{skill_deficit: 0.60, signature: 0.25, recurrence: 0.15}`, trigger: 0.60

**Session**: 15 questions, 5 touch this node's micro-skills

| Q | Micro-skill | Correct? | Student Answer | Distractor Analysis Match? |
|---|-------------|---------|----------------|---------------------------|
| PHY_ELEC_005 | FIELD_SUPERPOSITION | ❌ | "B" | "component_resolution_error" ✅ |
| PHY_ELEC_009 | FIELD_SUPERPOSITION | ❌ | "A" | "angle_calculation_error" ✅ |
| PHY_ELEC_011 | SYMMETRY_CANCELLATION | ❌ | "C" | "symmetry_recognition_failure" ✅ |
| PHY_ELEC_013 | FIELD_SUPERPOSITION | ✅ | "D" | — |
| PHY_ELEC_015 | SYMMETRY_CANCELLATION | ❌ | "B" | no match ❌ |

**Component calculations**:

```
skill_deficit_score:
  FIELD_SUPERPOSITION:    2/3 wrong = 0.667
  SYMMETRY_CANCELLATION:  2/2 wrong = 1.000
  avg = (0.667 + 1.000) / 2 = 0.833

signature_score:
  4 wrong responses, 3 matched diagnostic_focus = 3/4 = 0.75

recurrence_score:
  Previous session same chapter: deficit was 0.70 → recurrence = 0.70

node_score = 0.60 × 0.833 + 0.25 × 0.75 + 0.15 × 0.70
           = 0.500 + 0.188 + 0.105
           = 0.793

trigger_threshold = 0.60 → 0.793 ≥ 0.60 → node_state = "active" → capsule triggered ✅
```

---

## Caching Strategy

Static content (atlas nodes, micro-skill maps, question-skill maps) changes rarely. Cache in memory with 5-minute TTL to avoid repeated Firestore reads on every session completion.

```javascript
const cache = new Map();
const TTL = 5 * 60 * 1000; // 5 minutes

async function getCached(key, fetchFn) {
  const hit = cache.get(key);
  if (hit && Date.now() - hit.timestamp < TTL) return hit.data;
  const data = await fetchFn();
  cache.set(key, { data, timestamp: Date.now() });
  return data;
}
```

---

## Implementation Checklist

- [ ] Create `backend/src/services/weakSpotScoringService.js` with all 3 components
- [ ] Create `backend/scripts/upload-cognitive-mastery.js` (loads from `inputs/cognitive_mastery/data1/`)
- [ ] Create `backend/scripts/tag-questions-micro-skills.js` (writes `micro_skill_ids` to existing questions in Firestore)
- [ ] Add unit tests: `backend/tests/weakSpotScoringService.test.js`
- [ ] Hook into `backend/src/routes/chapterPractice.js` after session submit
- [ ] Validate trigger rate on test data (target 30-40% of sessions)

---

## Related Documentation

- [API Reference](01-API-REFERENCE.md) - `/weak-spots/detect` endpoint
- [Testing Strategy](06-TESTING-STRATEGY.md) - Scoring engine test cases
- [Mobile UI Spec](03-MOBILE-UI-SPEC.md) - How scores surface to students
