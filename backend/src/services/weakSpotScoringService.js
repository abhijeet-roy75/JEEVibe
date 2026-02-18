/**
 * Weak Spot Scoring Service
 *
 * Detects recurring student misconception patterns from chapter practice sessions
 * using a 3-component scoring formula:
 *
 *   node_score = skill_deficit_weight × skill_deficit_score   (default 0.60)
 *              + signature_weight     × signature_score       (default 0.25)
 *              + recurrence_weight    × recurrence_score      (default 0.15)
 *
 * Returns the top triggered node per session (1 capsule per session max).
 * Called internally by chapterPractice /complete — not an HTTP endpoint.
 */

const { db, admin } = require('../config/firebase');
const logger = require('../utils/logger');

// ============================================================================
// IN-MEMORY CACHE (5-minute TTL for static atlas content)
// ============================================================================

const _cache = new Map();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

async function getCached(key, fetchFn) {
  const hit = _cache.get(key);
  if (hit && Date.now() - hit.timestamp < CACHE_TTL) return hit.data;
  const data = await fetchFn();
  _cache.set(key, { data, timestamp: Date.now() });
  return data;
}

// ============================================================================
// DATA LOADERS
// ============================================================================

async function getSessionResponses(userId, sessionId) {
  const snap = await db
    .collection('chapter_practice_responses')
    .doc(userId)
    .collection('responses')
    .where('session_id', '==', sessionId)
    .get();

  return snap.docs.map(d => d.data());
}

async function getQuestionSkillMap(chapterKey) {
  return getCached(`qsm:${chapterKey}`, async () => {
    const doc = await db.collection('atlas_question_skill_map').doc(chapterKey).get();
    return doc.exists ? (doc.data().map || {}) : {};
  });
}

async function getMicroSkillMap(chapterKey) {
  return getCached(`msm:${chapterKey}`, async () => {
    const snap = await db
      .collection('atlas_micro_skills')
      .where('chapter_key', '==', chapterKey)
      .get();
    const map = {};
    snap.docs.forEach(d => {
      const data = d.data();
      map[data.micro_skill_id] = data;
    });
    return map;
  });
}

async function getAtlasNodes(chapterKey) {
  return getCached(`nodes:${chapterKey}`, async () => {
    // Atlas nodes don't have a chapter_key field — derive from micro_skill_ids prefix
    // All micro-skill IDs for a chapter share the same prefix (e.g. PHY.ELECTROSTATICS.*)
    // Instead, load all nodes and filter by which ones have micro_skills in this chapter's map
    const microSkillMap = await getMicroSkillMap(chapterKey);
    const chapterSkillIds = new Set(Object.keys(microSkillMap));

    const snap = await db.collection('atlas_nodes').where('status', '==', 'active').get();
    return snap.docs
      .map(d => ({ atlas_node_id: d.id, ...d.data() }))
      .filter(node =>
        (node.micro_skill_ids || []).some(skillId => chapterSkillIds.has(skillId))
      );
  });
}

async function getUserWeakSpot(userId, nodeId) {
  const doc = await db
    .collection('user_weak_spots')
    .doc(userId)
    .collection('nodes')
    .doc(nodeId)
    .get();
  return doc.exists ? doc.data() : null;
}

// ============================================================================
// SCORING COMPONENTS
// ============================================================================

/**
 * Component 1: Skill Deficit Score
 * Error rate across micro-skills linked to the node.
 * Returns 0.0 (all correct) to 1.0 (all wrong), or null if no questions tested.
 */
function calcSkillDeficitScore(responses, questionSkillMap, nodeSkillIds) {
  const deficits = [];

  for (const skillId of nodeSkillIds) {
    const skillQuestions = responses.filter(r =>
      (questionSkillMap[r.question_id] || []).includes(skillId)
    );
    if (skillQuestions.length === 0) continue;

    const wrong = skillQuestions.filter(r => !r.is_correct).length;
    deficits.push(wrong / skillQuestions.length);
  }

  if (deficits.length === 0) return null;
  return deficits.reduce((a, b) => a + b, 0) / deficits.length;
}

/**
 * Component 2: Signature Score
 * Whether wrong answers match known structural error patterns for this node.
 *
 * Matching strategy:
 * 1. Collect diagnostic_focus keywords from micro-skills (e.g. "component_resolution_error")
 * 2. Convert to space-separated form (e.g. "component resolution error")
 * 3. Also check diagnostic_keyword_hints if present (explicit expansion for natural-language DA)
 * 4. Match against distractor_analysis text of wrong answers
 */
function calcSignatureScore(responses, questionSkillMap, microSkillMap, nodeSkillIds) {
  const wrongResponses = responses.filter(r => !r.is_correct && r.student_answer);
  if (wrongResponses.length === 0) return 0;

  // Collect error keywords for this node's micro-skills
  const errorKeywords = new Set();
  for (const skillId of nodeSkillIds) {
    const skill = microSkillMap[skillId];
    if (!skill) continue;

    // Primary: diagnostic_focus (snake_case → space-separated)
    if (skill.diagnostic_focus) {
      skill.diagnostic_focus.forEach(e => errorKeywords.add(e.replace(/_/g, ' ')));
    }

    // Extended: diagnostic_keyword_hints (explicit natural-language expansions)
    if (skill.diagnostic_keyword_hints) {
      skill.diagnostic_keyword_hints.forEach(hint => errorKeywords.add(hint.toLowerCase()));
    }
  }

  if (errorKeywords.size === 0) return 0;

  const signatureMatches = wrongResponses.filter(r => {
    const distractorText = (r.distractor_analysis?.[r.student_answer] || '').toLowerCase();
    if (!distractorText) return false;
    return [...errorKeywords].some(keyword => distractorText.includes(keyword));
  });

  return signatureMatches.length / wrongResponses.length;
}

/**
 * Component 3: Recurrence Score
 * Whether this node's micro-skills have been weak across multiple previous sessions.
 */
async function calcRecurrenceScore(userId, chapterKey, nodeSkillIds, questionSkillMap, currentSessionId) {
  const previousSnap = await db
    .collection('chapter_practice_responses')
    .doc(userId)
    .collection('responses')
    .where('chapter_key', '==', chapterKey)
    .where('session_id', '!=', currentSessionId)
    .orderBy('session_id') // needed for inequality filter; answered_at not always indexed
    .limit(45) // ~3 sessions × 15 questions
    .get();

  if (previousSnap.empty) return 0;

  const prevDocs = previousSnap.docs.map(d => d.data());

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

// ============================================================================
// NODE SCORING
// ============================================================================

async function scoreNode(responses, questionSkillMap, microSkillMap, atlasNode, userId) {
  const {
    atlas_node_id,
    micro_skill_ids,
    scoring_weights,
    trigger_threshold,
    stability_threshold,
    min_signal_count,
  } = atlasNode;

  const nodeSkillIds = micro_skill_ids || [];

  // Minimum signal check: need enough questions touching this node
  const testedQuestions = responses.filter(r =>
    nodeSkillIds.some(skillId =>
      (questionSkillMap[r.question_id] || []).includes(skillId)
    )
  );

  if (testedQuestions.length < (min_signal_count || 2)) {
    return { nodeScore: 0, state: 'inactive', tested: false };
  }

  const skillDeficit = calcSkillDeficitScore(responses, questionSkillMap, nodeSkillIds);
  if (skillDeficit === null) return { nodeScore: 0, state: 'inactive', tested: false };

  const signatureScore = calcSignatureScore(responses, questionSkillMap, microSkillMap, nodeSkillIds);

  const chapterKey = responses[0]?.chapter_key;
  const currentSessionId = responses[0]?.session_id;
  const recurrenceScore = await calcRecurrenceScore(
    userId, chapterKey, nodeSkillIds, questionSkillMap, currentSessionId
  );

  const weights = scoring_weights || {
    skill_deficit_weight: 0.6,
    signature_weight: 0.25,
    recurrence_weight: 0.15,
  };

  const nodeScore =
    weights.skill_deficit_weight * skillDeficit +
    weights.signature_weight * signatureScore +
    weights.recurrence_weight * recurrenceScore;

  return {
    nodeScore,
    tested: true,
    components: { skillDeficit, signatureScore, recurrenceScore },
    trigger_threshold: trigger_threshold || 0.6,
    stability_threshold: stability_threshold || 0.4,
  };
}

// ============================================================================
// FIRESTORE WRITERS
// ============================================================================

async function updateWeakSpot(userId, nodeId, { nodeScore, newState, capsuleId, severityLevel }) {
  const ref = db.collection('user_weak_spots').doc(userId).collection('nodes').doc(nodeId);
  await ref.set(
    {
      node_id: nodeId,
      current_score: nodeScore,
      node_state: newState,
      capsule_id: capsuleId || null,
      severity_level: severityLevel || null,
      last_scored_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function logWeakSpotEvent(userId, nodeId, eventData) {
  await db.collection('weak_spot_events').add({
    student_id: userId,
    atlas_node_id: nodeId,
    ...eventData,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ============================================================================
// MAIN DETECTION FUNCTION
// ============================================================================

/**
 * detectWeakSpots
 *
 * Called internally after chapter practice /complete.
 * Returns the top triggered node or null if none triggered.
 *
 * @param {string} userId
 * @param {string} sessionId
 * @returns {Promise<Object|null>} Triggered node info or null
 */
async function detectWeakSpots(userId, sessionId) {
  try {
    const responses = await getSessionResponses(userId, sessionId);
    if (!responses.length) return null;

    const chapterKey = responses[0].chapter_key;
    if (!chapterKey) return null;

    // Load static content (cached)
    const [questionSkillMap, microSkillMap, atlasNodes] = await Promise.all([
      getQuestionSkillMap(chapterKey),
      getMicroSkillMap(chapterKey),
      getAtlasNodes(chapterKey),
    ]);

    if (!atlasNodes.length) return null; // Chapter not in cognitive mastery yet

    const triggered = [];

    for (const node of atlasNodes) {
      const { nodeScore, tested, components, trigger_threshold, stability_threshold } = await scoreNode(
        responses, questionSkillMap, microSkillMap, node, userId
      );

      if (!tested) continue;

      // Load existing state for this node
      const existing = await getUserWeakSpot(userId, node.atlas_node_id);
      const prevState = existing?.node_state || 'inactive';
      const prevScore = existing?.current_score ?? 0;

      const newState = nodeScore >= trigger_threshold ? 'active'
        : nodeScore <= stability_threshold ? 'stable'
        : prevState;

      // Persist state
      await updateWeakSpot(userId, node.atlas_node_id, {
        nodeScore,
        newState,
        capsuleId: node.capsule_id,
        severityLevel: node.severity_level,
      });

      // Log the scoring event
      await logWeakSpotEvent(userId, node.atlas_node_id, {
        chapter_key: chapterKey,
        session_id: sessionId,
        capsule_id: node.capsule_id || null,
        event_type: 'chapter_scored',
        previous_state: prevState,
        new_state: newState,
        previous_score: prevScore,
        new_score: nodeScore,
        score_components: components || null,
      });

      if (newState === 'active') {
        triggered.push({ ...node, nodeScore, newState });
      }
    }

    if (!triggered.length) return null;

    // Return highest-severity, then highest-scoring node (1 per session)
    const severityOrder = { high: 3, medium: 2, low: 1 };
    triggered.sort((a, b) => {
      const sDiff = (severityOrder[b.severity_level] || 0) - (severityOrder[a.severity_level] || 0);
      return sDiff !== 0 ? sDiff : b.nodeScore - a.nodeScore;
    });

    const top = triggered[0];
    logger.info(`Weak spot detected for user ${userId}: ${top.atlas_node_id} (score=${top.nodeScore.toFixed(3)}, state=${top.newState})`);

    return {
      nodeId: top.atlas_node_id,
      title: top.node_name,
      score: Math.round(top.nodeScore * 100) / 100,
      nodeState: top.newState,
      capsuleId: top.capsule_id,
      severityLevel: top.severity_level || 'medium',
    };
  } catch (err) {
    // Non-fatal: scoring failure should not break chapter practice completion
    logger.error(`detectWeakSpots failed for session ${sessionId}: ${err.message}`, err);
    return null;
  }
}

// ============================================================================
// RETRIEVAL EVALUATION
// ============================================================================

/**
 * evaluateRetrieval
 *
 * After student completes 3 retrieval questions (2 near + 1 contrast).
 * Updates node score and state. Returns result summary.
 *
 * @param {string} userId
 * @param {string} nodeId
 * @param {Array} responses - [{questionId, isCorrect}]
 * @param {Object} atlasNode - node data from Firestore
 * @returns {Promise<Object>} Result with passed, correctCount, newScore, newState
 */
async function evaluateRetrieval(userId, nodeId, responses, atlasNode) {
  const existing = await getUserWeakSpot(userId, nodeId);
  const currentScore = existing?.current_score ?? 0.7;
  const stabilityThreshold = atlasNode.stability_threshold || 0.4;

  const correctCount = responses.filter(r => r.isCorrect).length;
  const passed = correctCount >= 2;

  let newScore, newState;
  if (passed) {
    newScore = currentScore * 0.5; // strong decay on pass
    newState = newScore <= stabilityThreshold ? 'stable' : 'improving';
  } else {
    newScore = Math.min(currentScore * 1.05, 1.0); // light increase on fail
    newState = 'active';
  }

  await updateWeakSpot(userId, nodeId, {
    nodeScore: newScore,
    newState,
    capsuleId: atlasNode.capsule_id,
    severityLevel: atlasNode.severity_level,
  });

  await logWeakSpotEvent(userId, nodeId, {
    event_type: 'retrieval_completed',
    capsule_id: atlasNode.capsule_id || null,
    session_id: null,
    chapter_key: null,
    previous_state: existing?.node_state || 'active',
    new_state: newState,
    previous_score: currentScore,
    new_score: newScore,
  });

  return {
    passed,
    correctCount,
    totalQuestions: responses.length,
    oldScore: Math.round(currentScore * 100) / 100,
    newScore: Math.round(newScore * 100) / 100,
    previousState: existing?.node_state || 'active',
    newState,
  };
}

// ============================================================================
// USER WEAK SPOTS QUERY
// ============================================================================

/**
 * getUserWeakSpots
 *
 * Retrieves all weak spots for a user with computed capsule status from event log.
 *
 * @param {string} userId
 * @param {Object} options - { nodeState, limit }
 * @returns {Promise<Array>}
 */
async function getUserWeakSpots(userId, { nodeState, limit = 10 } = {}) {
  let query = db
    .collection('user_weak_spots')
    .doc(userId)
    .collection('nodes');

  if (nodeState) query = query.where('node_state', '==', nodeState);
  query = query.limit(limit);

  const snap = await query.get();
  if (snap.empty) return [];

  const weakSpots = snap.docs.map(d => d.data());

  // For each node, look up capsule status from latest engagement event
  const enriched = await Promise.all(weakSpots.map(async ws => {
    const eventsSnap = await db
      .collection('weak_spot_events')
      .where('student_id', '==', userId)
      .where('atlas_node_id', '==', ws.node_id)
      .where('event_type', 'in', [
        'capsule_delivered', 'capsule_opened', 'capsule_saved',
        'capsule_completed', 'capsule_skipped',
      ])
      .orderBy('created_at', 'desc')
      .limit(1)
      .get();

    const latestEvent = eventsSnap.empty ? null : eventsSnap.docs[0].data().event_type;
    const capsuleStatus = deriveCapsuleStatus(latestEvent);

    return {
      nodeId: ws.node_id,
      title: ws.node_name || ws.node_id,
      currentScore: ws.current_score,
      nodeState: ws.node_state,
      severityLevel: ws.severity_level,
      capsuleId: ws.capsule_id,
      detectedAt: ws.last_scored_at?.toDate?.()?.toISOString() || null,
      capsuleStatus,
    };
  }));

  return enriched;
}

function deriveCapsuleStatus(latestEventType) {
  switch (latestEventType) {
    case 'capsule_completed': return 'completed';
    case 'capsule_opened': return 'opened';
    case 'capsule_saved': return 'ignored';
    default: return 'delivered';
  }
}

// ============================================================================
// ENGAGEMENT EVENT LOGGING
// ============================================================================

const ALLOWED_MOBILE_EVENTS = new Set([
  'capsule_delivered',
  'capsule_opened',
  'capsule_saved',
  'capsule_completed',
  'capsule_skipped',
  'retrieval_started',
]);

/**
 * logEngagementEvent
 *
 * Validates and writes a mobile-initiated engagement event to weak_spot_events.
 *
 * @param {string} userId
 * @param {string} nodeId
 * @param {string} eventType
 * @param {string} capsuleId
 * @returns {Promise<void>}
 */
async function logEngagementEvent(userId, nodeId, eventType, capsuleId) {
  if (!ALLOWED_MOBILE_EVENTS.has(eventType)) {
    throw new Error(`Invalid eventType: ${eventType}`);
  }

  await db.collection('weak_spot_events').add({
    student_id: userId,
    atlas_node_id: nodeId,
    capsule_id: capsuleId || null,
    chapter_key: null,
    session_id: null,
    event_type: eventType,
    previous_state: null,
    new_state: null,
    previous_score: null,
    new_score: null,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

module.exports = {
  detectWeakSpots,
  evaluateRetrieval,
  getUserWeakSpots,
  logEngagementEvent,
};
