/**
 * Content Moderation Service for AI Tutor
 * Monitors, flags, and alerts on out-of-context or concerning communications
 * Integrated with Sentry for real-time alerting
 */

const Sentry = require('@sentry/node');
const { db, FieldValue } = require('../config/firebase');
const logger = require('../utils/logger');

// ============================================================================
// DETECTION PATTERNS
// ============================================================================

/**
 * Keywords and patterns that trigger flagging
 * Organized by severity and category
 */
const DETECTION_PATTERNS = {
  // HIGH SEVERITY - Immediate alert required
  high: {
    self_harm: [
      /\b(suicide|suicidal|kill myself|end my life|want to die|self.?harm|cutting myself|hurt myself)\b/i,
      /\b(no point living|better off dead|can't go on|give up on life)\b/i
    ],
    violence: [
      /\b(kill|murder|attack|hurt|harm)\s+(someone|teacher|parent|friend|him|her|them)\b/i,
      /\b(bring a|have a)\s+(gun|knife|weapon)\b/i
    ],
    abuse: [
      /\b(being abused|abusing me|hits me|beats me|molest|inappropriate touch)\b/i,
      /\b(forced to|making me do)\s+(things|stuff)\s+(i don't want|uncomfortable)\b/i
    ],
    explicit: [
      /\b(sex|porn|nude|naked|xxx|sexual|erotic|horny)\b/i,
      /\b(dick|penis|vagina|boobs|breasts)\b/i  // Anatomical terms outside educational context
    ]
  },

  // MEDIUM SEVERITY - Flag for review
  medium: {
    mental_health: [
      /\b(depressed|depression|anxiety|panic attack|can't sleep|insomnia)\b/i,
      /\b(stressed out|too much pressure|breaking down|mental health)\b/i,
      /\b(nobody understands|feel alone|lonely|isolated|no friends)\b/i
    ],
    academic_dishonesty: [
      /\b(cheat|cheating|copy|copying|leaked paper|leaked questions)\b/i,
      /\b(answer key|hack|bypass|trick the system)\b/i,
      /\b(proxy|impersonate|someone else.*exam)\b/i
    ],
    substance: [
      /\b(drugs|weed|marijuana|alcohol|drinking|drunk|smoking|cigarette)\b/i,
      /\b(adderall|modafinil|study drugs|pills to study|stay awake pills)\b/i
    ],
    jailbreak: [
      /\b(ignore|disregard|forget)\s+(previous|your|all)\s+(instructions|rules|guidelines)\b/i,
      /\b(act as|pretend to be|you are now|new persona)\b/i,
      /\b(dan|jailbreak|bypass|hack)\s*(mode|prompt)?\b/i,
      /\b(system prompt|reveal.*instructions|show.*prompt)\b/i,
      /\b(roleplay|role.?play)\s+(as|scenario)\b/i
    ],
    personal_info_sharing: [
      /\b(my phone|my number|my address|where i live|my email)\s*(is|:)/i,
      /\b(call me|text me|message me|contact me)\s*(at|on)/i
    ]
  },

  // LOW SEVERITY - Track for patterns
  low: {
    off_topic: [
      /\b(girlfriend|boyfriend|crush|dating|relationship|love life)\b/i,
      /\b(movie|netflix|instagram|youtube|gaming|pubg|valorant|cricket|football)\b/i,
      /\b(politics|modi|election|congress|bjp|religion|hindu|muslim|christian)\b/i,
      /\b(college ranking|which iit|best branch|placement|salary)\b/i
    ],
    other_exams: [
      /\b(neet|bitsat|viteee|srmjee|mhtcet|wbjee|board exam|cbse|icse)\b/i,
      /\b(cat|gate|upsc|ssc|banking)\b/i
    ],
    frustration: [
      /\b(hate this|this is stupid|waste of time|useless app|dumb ai)\b/i,
      /\b(you('re| are) (useless|stupid|dumb|bad|wrong))\b/i,
      /\b(worst|terrible|horrible|pathetic)\s*(app|ai|tutor)?\b/i
    ],
    support_redirect: [
      /\b(bug|error|crash|not working|app.*broken|subscription|payment|refund)\b/i,
      /\b(can't login|password|account.*problem)\b/i
    ]
  }
};

/**
 * Appropriate responses for flagged content
 */
const SAFE_RESPONSES = {
  self_harm: `I'm really concerned about what you've shared. Please know that you're not alone, and there are people who want to help.

Please reach out to:
• iCall: 9152987821 (Mon-Sat, 8am-10pm)
• Vandrevala Foundation: 1860-2662-345 (24/7)
• NIMHANS: 080-46110007

Your wellbeing matters more than any exam. Please talk to a trusted adult - a parent, teacher, or counselor. 💙

I'm here for JEE help whenever you're ready.`,

  abuse: `I'm very sorry you're going through this. What you've described is serious and you deserve help.

Please reach out to:
• Childline India: 1098 (24/7, free)
• Women Helpline: 181
• Police: 100

Please tell a trusted adult - a teacher, relative, or counselor. You don't have to face this alone.

I'm here for your studies when you need me. 💙`,

  mental_health: `I hear that you're going through a tough time. JEE preparation can be really stressful, and your feelings are valid.

While I can help with studies, for emotional support please consider:
• Talking to a parent, teacher, or school counselor
• iCall: 9152987821 (professional counseling)
• Taking breaks - your mental health matters!

When you're ready to study, I'm here. What topic would help you feel more prepared? 💙`,

  off_topic: `I appreciate you chatting with me! But I'm specifically designed to help with JEE preparation - Physics, Chemistry, and Mathematics.

For that topic, you might want to ask a friend, family member, or search online.

Now, what JEE topic can I help you with today? 📚`
};

// ============================================================================
// CORE MODERATION FUNCTIONS
// ============================================================================

/**
 * Analyze message content for concerning patterns
 * @param {string} message - User message to analyze
 * @returns {Object} Analysis result with flags, severity, and categories
 */
function analyzeMessage(message) {
  if (!message || typeof message !== 'string') {
    return { flagged: false, severity: null, categories: [], matches: [] };
  }

  const result = {
    flagged: false,
    severity: null,
    categories: [],
    matches: [],
    requiresImmediateAlert: false,
    suggestedResponse: null
  };

  const normalizedMessage = message.toLowerCase().trim();

  // Check each severity level
  for (const [severity, categories] of Object.entries(DETECTION_PATTERNS)) {
    for (const [category, patterns] of Object.entries(categories)) {
      for (const pattern of patterns) {
        const match = normalizedMessage.match(pattern);
        if (match) {
          result.flagged = true;

          // Set highest severity found
          if (!result.severity ||
              (severity === 'high') ||
              (severity === 'medium' && result.severity === 'low')) {
            result.severity = severity;
          }

          if (!result.categories.includes(category)) {
            result.categories.push(category);
          }

          result.matches.push({
            category,
            severity,
            pattern: pattern.toString(),
            matched: match[0]
          });
        }
      }
    }
  }

  // Set immediate alert flag for high severity
  if (result.severity === 'high') {
    result.requiresImmediateAlert = true;
  }

  // Set suggested response based on most severe category
  if (result.flagged) {
    const priorityCategories = ['self_harm', 'abuse', 'violence', 'explicit', 'mental_health'];
    for (const cat of priorityCategories) {
      if (result.categories.includes(cat) && SAFE_RESPONSES[cat]) {
        result.suggestedResponse = SAFE_RESPONSES[cat];
        break;
      }
    }
    if (!result.suggestedResponse) {
      result.suggestedResponse = SAFE_RESPONSES.off_topic;
    }
  }

  return result;
}

/**
 * Log flagged content to Firestore for review
 * @param {string} userId - User ID
 * @param {string} message - Original message
 * @param {Object} analysis - Analysis result from analyzeMessage
 * @param {Object} metadata - Additional context (conversationId, etc.)
 * @returns {Promise<string>} Flag document ID
 */
async function logFlaggedContent(userId, message, analysis, metadata = {}) {
  try {
    const flagDoc = {
      userId,
      message: message.substring(0, 500), // Truncate for storage
      messageLength: message.length,
      severity: analysis.severity,
      categories: analysis.categories,
      matches: analysis.matches.map(m => ({
        category: m.category,
        severity: m.severity,
        matched: m.matched
      })),
      requiresImmediateAlert: analysis.requiresImmediateAlert,
      timestamp: FieldValue.serverTimestamp(),
      reviewed: false,
      reviewedBy: null,
      reviewedAt: null,
      action: null,
      notes: null,
      ...metadata
    };

    const docRef = await db.collection('moderation_flags').add(flagDoc);

    logger.warn('Content flagged for moderation', {
      flagId: docRef.id,
      userId,
      severity: analysis.severity,
      categories: analysis.categories
    });

    // Update user's flag count
    await updateUserFlagCount(userId, analysis.severity);

    return docRef.id;
  } catch (error) {
    logger.error('Error logging flagged content', { userId, error: error.message });
    throw error;
  }
}

/**
 * Update user's cumulative flag count for pattern detection
 * @param {string} userId - User ID
 * @param {string} severity - Flag severity
 */
async function updateUserFlagCount(userId, severity) {
  try {
    const userRef = db.collection('users').doc(userId);
    const updateData = {
      'moderation_stats.total_flags': FieldValue.increment(1),
      'moderation_stats.last_flag_at': FieldValue.serverTimestamp(),
      [`moderation_stats.flags_by_severity.${severity}`]: FieldValue.increment(1)
    };

    await userRef.set(updateData, { merge: true });
  } catch (error) {
    logger.error('Error updating user flag count', { userId, error: error.message });
    // Non-blocking - don't throw
  }
}

/**
 * Check if user has exceeded flag thresholds
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Threshold check result
 */
async function checkUserFlagThresholds(userId) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const stats = userDoc.data()?.moderation_stats || {};

    const thresholds = {
      shouldAlert: false,
      shouldRestrict: false,
      reasons: []
    };

    // Check high severity flags
    const highFlags = stats.flags_by_severity?.high || 0;
    if (highFlags >= 1) {
      thresholds.shouldAlert = true;
      thresholds.reasons.push(`${highFlags} high-severity flag(s)`);
    }

    // Check medium severity flags (threshold: 3)
    const mediumFlags = stats.flags_by_severity?.medium || 0;
    if (mediumFlags >= 3) {
      thresholds.shouldAlert = true;
      thresholds.reasons.push(`${mediumFlags} medium-severity flags`);
    }

    // Check total flags (threshold: 10)
    const totalFlags = stats.total_flags || 0;
    if (totalFlags >= 10) {
      thresholds.shouldAlert = true;
      thresholds.shouldRestrict = true;
      thresholds.reasons.push(`${totalFlags} total flags - consider restricting access`);
    }

    return thresholds;
  } catch (error) {
    logger.error('Error checking user flag thresholds', { userId, error: error.message });
    return { shouldAlert: false, shouldRestrict: false, reasons: [] };
  }
}

// ============================================================================
// ALERTING FUNCTIONS
// ============================================================================

/**
 * Send immediate alert for high-severity content
 * Integrates with Sentry for real-time alerting and monitoring
 * @param {string} userId - User ID
 * @param {string} flagId - Flag document ID
 * @param {Object} analysis - Analysis result
 */
async function sendImmediateAlert(userId, flagId, analysis) {
  try {
    // Log to alerts collection for dashboard
    const alertRef = await db.collection('moderation_alerts').add({
      userId,
      flagId,
      severity: analysis.severity,
      categories: analysis.categories,
      timestamp: FieldValue.serverTimestamp(),
      acknowledged: false,
      acknowledgedBy: null,
      acknowledgedAt: null
    });

    // ========================================
    // SENTRY INTEGRATION
    // ========================================
    if (process.env.SENTRY_DSN) {
      // Set user context for Sentry
      Sentry.setUser({ id: userId });

      // Set tags for filtering in Sentry dashboard
      Sentry.setTag('moderation_severity', analysis.severity);
      Sentry.setTag('moderation_alert', 'true');
      Sentry.setTag('flag_id', flagId);

      // Set extra context
      Sentry.setContext('moderation', {
        flagId,
        alertId: alertRef.id,
        categories: analysis.categories,
        matchCount: analysis.matches?.length || 0
      });

      // Create a custom Sentry event for high-severity content
      // This will trigger Sentry alerts based on your alert rules
      const sentryEventId = Sentry.captureMessage(
        `🚨 AI Tutor Content Moderation Alert: ${analysis.categories.join(', ')}`,
        {
          level: analysis.severity === 'high' ? 'error' : 'warning',
          tags: {
            moderation_severity: analysis.severity,
            moderation_categories: analysis.categories.join(','),
            alert_type: 'content_moderation'
          },
          extra: {
            userId,
            flagId,
            alertId: alertRef.id,
            categories: analysis.categories,
            matches: analysis.matches?.map(m => ({
              category: m.category,
              matched: m.matched
            })),
            requiresImmediateAction: analysis.severity === 'high'
          },
          fingerprint: ['content-moderation', analysis.severity, ...analysis.categories]
        }
      );

      logger.info('Sentry alert sent', { sentryEventId, flagId, userId });
    }

    // Log for additional monitoring
    logger.error('🚨 IMMEDIATE MODERATION ALERT', {
      alertType: 'HIGH_SEVERITY_CONTENT',
      userId,
      flagId,
      alertId: alertRef.id,
      categories: analysis.categories,
      severity: analysis.severity,
      alert: true
    });

  } catch (error) {
    logger.error('Error sending immediate alert', { userId, flagId, error: error.message });
    // Still try to report the error to Sentry
    if (process.env.SENTRY_DSN) {
      Sentry.captureException(error, {
        tags: { service: 'content_moderation' },
        extra: { userId, flagId }
      });
    }
  }
}

/**
 * Create daily summary of moderation flags
 * Can be called by a scheduled function
 * @returns {Promise<Object>} Summary statistics
 */
async function generateDailySummary() {
  try {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(0, 0, 0, 0);

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const flagsSnapshot = await db.collection('moderation_flags')
      .where('timestamp', '>=', yesterday)
      .where('timestamp', '<', today)
      .get();

    const summary = {
      date: yesterday.toISOString().split('T')[0],
      totalFlags: flagsSnapshot.size,
      bySeverity: { high: 0, medium: 0, low: 0 },
      byCategory: {},
      uniqueUsers: new Set(),
      unreviewedCount: 0
    };

    flagsSnapshot.forEach(doc => {
      const data = doc.data();
      summary.bySeverity[data.severity] = (summary.bySeverity[data.severity] || 0) + 1;
      summary.uniqueUsers.add(data.userId);
      if (!data.reviewed) summary.unreviewedCount++;

      data.categories.forEach(cat => {
        summary.byCategory[cat] = (summary.byCategory[cat] || 0) + 1;
      });
    });

    summary.uniqueUsers = summary.uniqueUsers.size;

    // Store summary
    await db.collection('moderation_summaries').add({
      ...summary,
      generatedAt: FieldValue.serverTimestamp()
    });

    logger.info('Daily moderation summary generated', summary);

    return summary;
  } catch (error) {
    logger.error('Error generating daily summary', { error: error.message });
    throw error;
  }
}

// ============================================================================
// MIDDLEWARE FUNCTION
// ============================================================================

/**
 * Express middleware to moderate incoming messages
 * Use this in the AI tutor message route
 * Integrates with Sentry for tracking and alerting
 */
function moderateMessage() {
  return async (req, _res, next) => {
    const message = req.body?.message;
    const userId = req.userId;

    if (!message) {
      return next();
    }

    try {
      // Analyze the message
      const analysis = analyzeMessage(message);

      // Attach analysis to request for use in route handler
      req.moderationAnalysis = analysis;

      if (analysis.flagged) {
        // Log the flagged content
        const flagId = await logFlaggedContent(userId, message, analysis, {
          endpoint: req.path,
          requestId: req.requestId
        });

        req.moderationFlagId = flagId;

        // Add Sentry breadcrumb for tracking
        if (process.env.SENTRY_DSN) {
          Sentry.addBreadcrumb({
            category: 'moderation',
            message: `Content flagged: ${analysis.categories.join(', ')}`,
            level: analysis.severity === 'high' ? 'error' : 'warning',
            data: {
              flagId,
              severity: analysis.severity,
              categories: analysis.categories
            }
          });
        }

        // Send immediate alert for high severity
        if (analysis.requiresImmediateAlert) {
          await sendImmediateAlert(userId, flagId, analysis);
        }

        // Check user thresholds
        const thresholds = await checkUserFlagThresholds(userId);
        req.moderationThresholds = thresholds;

        // Alert if user has exceeded thresholds
        if (thresholds.shouldAlert && process.env.SENTRY_DSN) {
          Sentry.captureMessage(
            `⚠️ User exceeded moderation thresholds`,
            {
              level: 'warning',
              tags: {
                alert_type: 'user_threshold_exceeded',
                should_restrict: thresholds.shouldRestrict.toString()
              },
              extra: {
                userId,
                reasons: thresholds.reasons,
                currentFlagId: flagId
              }
            }
          );
        }
      }

      next();
    } catch (error) {
      logger.error('Error in moderation middleware', { userId, error: error.message });
      // Report to Sentry but don't block the request
      if (process.env.SENTRY_DSN) {
        Sentry.captureException(error, {
          tags: { service: 'content_moderation', middleware: 'true' },
          extra: { userId }
        });
      }
      next();
    }
  };
}

// ============================================================================
// ADMIN FUNCTIONS
// ============================================================================

/**
 * Get flagged content for admin review
 * @param {Object} filters - Query filters
 * @returns {Promise<Array>} Flagged content documents
 */
async function getFlaggedContent(filters = {}) {
  try {
    let query = db.collection('moderation_flags')
      .orderBy('timestamp', 'desc');

    if (filters.severity) {
      query = query.where('severity', '==', filters.severity);
    }

    if (filters.reviewed !== undefined) {
      query = query.where('reviewed', '==', filters.reviewed);
    }

    if (filters.userId) {
      query = query.where('userId', '==', filters.userId);
    }

    const limit = filters.limit || 50;
    query = query.limit(limit);

    const snapshot = await query.get();

    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate?.() || doc.data().timestamp
    }));
  } catch (error) {
    logger.error('Error getting flagged content', { error: error.message });
    throw error;
  }
}

/**
 * Mark flag as reviewed
 * @param {string} flagId - Flag document ID
 * @param {string} reviewerId - Admin user ID
 * @param {string} action - Action taken (dismissed, warned, restricted)
 * @param {string} notes - Review notes
 */
async function reviewFlag(flagId, reviewerId, action, notes = '') {
  try {
    await db.collection('moderation_flags').doc(flagId).update({
      reviewed: true,
      reviewedBy: reviewerId,
      reviewedAt: FieldValue.serverTimestamp(),
      action,
      notes
    });

    logger.info('Flag reviewed', { flagId, reviewerId, action });
  } catch (error) {
    logger.error('Error reviewing flag', { flagId, error: error.message });
    throw error;
  }
}

/**
 * Get moderation statistics for admin dashboard
 * @returns {Promise<Object>} Moderation stats
 */
async function getModerationStats() {
  try {
    const now = new Date();
    const todayStart = new Date(now);
    todayStart.setHours(0, 0, 0, 0);

    const weekAgo = new Date(now);
    weekAgo.setDate(weekAgo.getDate() - 7);

    // Get today's flags
    const todaySnapshot = await db.collection('moderation_flags')
      .where('timestamp', '>=', todayStart)
      .get();

    // Get this week's flags
    const weekSnapshot = await db.collection('moderation_flags')
      .where('timestamp', '>=', weekAgo)
      .get();

    // Get unreviewed flags
    const unreviewedSnapshot = await db.collection('moderation_flags')
      .where('reviewed', '==', false)
      .get();

    // Get unacknowledged alerts
    const alertsSnapshot = await db.collection('moderation_alerts')
      .where('acknowledged', '==', false)
      .get();

    // Calculate stats
    const todayFlags = todaySnapshot.docs.map(d => d.data());
    const weekFlags = weekSnapshot.docs.map(d => d.data());

    const stats = {
      today: {
        total: todayFlags.length,
        high: todayFlags.filter(f => f.severity === 'high').length,
        medium: todayFlags.filter(f => f.severity === 'medium').length,
        low: todayFlags.filter(f => f.severity === 'low').length
      },
      thisWeek: {
        total: weekFlags.length,
        high: weekFlags.filter(f => f.severity === 'high').length,
        medium: weekFlags.filter(f => f.severity === 'medium').length,
        low: weekFlags.filter(f => f.severity === 'low').length,
        uniqueUsers: new Set(weekFlags.map(f => f.userId)).size
      },
      pending: {
        unreviewedFlags: unreviewedSnapshot.size,
        unacknowledgedAlerts: alertsSnapshot.size
      },
      categoryBreakdown: {}
    };

    // Category breakdown for the week
    weekFlags.forEach(flag => {
      (flag.categories || []).forEach(cat => {
        stats.categoryBreakdown[cat] = (stats.categoryBreakdown[cat] || 0) + 1;
      });
    });

    return stats;
  } catch (error) {
    logger.error('Error getting moderation stats', { error: error.message });
    throw error;
  }
}

/**
 * Get unacknowledged moderation alerts
 * @param {number} limit - Max alerts to return
 * @returns {Promise<Array>} Alert documents
 */
async function getUnacknowledgedAlerts(limit = 50) {
  try {
    const snapshot = await db.collection('moderation_alerts')
      .where('acknowledged', '==', false)
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .get();

    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate?.() || doc.data().timestamp
    }));
  } catch (error) {
    logger.error('Error getting unacknowledged alerts', { error: error.message });
    throw error;
  }
}

/**
 * Acknowledge a moderation alert
 * @param {string} alertId - Alert document ID
 * @param {string} acknowledgedBy - Admin user who acknowledged
 */
async function acknowledgeAlert(alertId, acknowledgedBy) {
  try {
    await db.collection('moderation_alerts').doc(alertId).update({
      acknowledged: true,
      acknowledgedBy,
      acknowledgedAt: FieldValue.serverTimestamp()
    });

    logger.info('Moderation alert acknowledged', { alertId, acknowledgedBy });
  } catch (error) {
    logger.error('Error acknowledging alert', { alertId, error: error.message });
    throw error;
  }
}

/**
 * Get users with most flags (for monitoring repeat offenders)
 * @param {number} limit - Max users to return
 * @returns {Promise<Array>} Users sorted by flag count
 */
async function getUsersWithMostFlags(limit = 20) {
  try {
    // Query users who have moderation stats
    const usersSnapshot = await db.collection('users')
      .where('moderation_stats.total_flags', '>', 0)
      .orderBy('moderation_stats.total_flags', 'desc')
      .limit(limit)
      .get();

    return usersSnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        userId: doc.id,
        displayName: data.displayName || data.firstName || 'Unknown',
        email: data.email,
        totalFlags: data.moderation_stats?.total_flags || 0,
        flagsBySeverity: data.moderation_stats?.flags_by_severity || {},
        lastFlagAt: data.moderation_stats?.last_flag_at?.toDate?.() || null
      };
    });
  } catch (error) {
    logger.error('Error getting users with most flags', { error: error.message });
    throw error;
  }
}

module.exports = {
  analyzeMessage,
  logFlaggedContent,
  checkUserFlagThresholds,
  sendImmediateAlert,
  generateDailySummary,
  moderateMessage,
  getFlaggedContent,
  reviewFlag,
  getModerationStats,
  getUnacknowledgedAlerts,
  acknowledgeAlert,
  getUsersWithMostFlags,
  SAFE_RESPONSES,
  DETECTION_PATTERNS
};
