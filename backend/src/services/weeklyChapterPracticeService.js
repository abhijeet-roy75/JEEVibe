/**
 * Weekly Chapter Practice Service
 *
 * Tracks weekly chapter practice limits for free tier users.
 * Uses a rolling 7-day window from completion timestamp.
 *
 * Storage: users/{userId}/chapter_practice_weekly/{subject}
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');

const COOLDOWN_DAYS = 7;
const SUBJECTS = ['physics', 'chemistry', 'mathematics'];

/**
 * Normalize subject name to lowercase key
 * @param {string} subject - Subject name (e.g., "Physics", "Maths", "mathematics")
 * @returns {string} Normalized subject key
 */
function normalizeSubject(subject) {
  const normalized = subject.toLowerCase();
  // Handle "maths" alias
  if (normalized === 'maths') {
    return 'mathematics';
  }
  return normalized;
}

/**
 * Get weekly usage for all subjects
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Weekly usage per subject
 */
async function getWeeklyUsage(userId) {
  const usage = {};
  const now = new Date();

  // Fetch all subjects in parallel
  const promises = SUBJECTS.map(async (subject) => {
    const docRef = db.collection('users')
      .doc(userId)
      .collection('chapter_practice_weekly')
      .doc(subject);

    const doc = await retryFirestoreOperation(() => docRef.get());

    if (doc.exists) {
      const data = doc.data();
      const expiresAt = data.expires_at?.toDate?.() || new Date(data.expires_at);
      const isLocked = expiresAt > now;

      return {
        subject,
        data: {
          is_locked: isLocked,
          last_chapter_key: data.last_chapter_key || null,
          last_chapter_name: data.last_chapter_name || null,
          last_completed_at: data.last_completed_at?.toDate?.()?.toISOString() || null,
          unlocks_at: isLocked ? expiresAt.toISOString() : null,
          days_remaining: isLocked
            ? Math.ceil((expiresAt - now) / (1000 * 60 * 60 * 24))
            : 0
        }
      };
    }

    return {
      subject,
      data: {
        is_locked: false,
        last_chapter_key: null,
        last_chapter_name: null,
        last_completed_at: null,
        unlocks_at: null,
        days_remaining: 0
      }
    };
  });

  const results = await Promise.all(promises);

  // Build usage object
  for (const result of results) {
    usage[result.subject] = result.data;
  }

  // Add convenience flag
  usage.any_locked = Object.values(usage).some(s => s.is_locked === true);

  return usage;
}

/**
 * Check if user can practice in a subject
 * @param {string} userId - User ID
 * @param {string} subject - Subject name
 * @returns {Promise<Object>} { allowed: boolean, reason?, unlocks_at?, days_remaining? }
 */
async function canPracticeSubject(userId, subject) {
  const normalizedSubject = normalizeSubject(subject);

  const docRef = db.collection('users')
    .doc(userId)
    .collection('chapter_practice_weekly')
    .doc(normalizedSubject);

  const doc = await retryFirestoreOperation(() => docRef.get());

  if (!doc.exists) {
    return { allowed: true };
  }

  const data = doc.data();
  const expiresAt = data.expires_at?.toDate?.() || new Date(data.expires_at);
  const now = new Date();

  if (expiresAt > now) {
    const daysRemaining = Math.ceil((expiresAt - now) / (1000 * 60 * 60 * 24));

    return {
      allowed: false,
      reason: 'WEEKLY_LIMIT_REACHED',
      last_chapter_key: data.last_chapter_key,
      last_chapter_name: data.last_chapter_name,
      unlocks_at: expiresAt.toISOString(),
      days_remaining: daysRemaining
    };
  }

  return { allowed: true };
}

/**
 * Record chapter practice completion
 * Called from chapterPractice.js /complete endpoint
 * @param {string} userId - User ID
 * @param {string} subject - Subject name
 * @param {string} chapterKey - Chapter key that was practiced
 * @param {string} chapterName - Chapter name (human readable)
 */
async function recordCompletion(userId, subject, chapterKey, chapterName) {
  const normalizedSubject = normalizeSubject(subject);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + COOLDOWN_DAYS * 24 * 60 * 60 * 1000);

  const docRef = db.collection('users')
    .doc(userId)
    .collection('chapter_practice_weekly')
    .doc(normalizedSubject);

  await retryFirestoreOperation(() =>
    docRef.set({
      subject: normalizedSubject,
      last_completed_at: admin.firestore.FieldValue.serverTimestamp(),
      last_chapter_key: chapterKey,
      last_chapter_name: chapterName,
      expires_at: admin.firestore.Timestamp.fromDate(expiresAt)
    })
  );

  logger.info('Chapter practice weekly limit recorded', {
    userId,
    subject: normalizedSubject,
    chapterKey,
    chapterName,
    expiresAt: expiresAt.toISOString()
  });
}

/**
 * Clear weekly usage for a subject (admin/testing utility)
 * @param {string} userId - User ID
 * @param {string} subject - Subject name (or 'all' for all subjects)
 */
async function clearWeeklyUsage(userId, subject = 'all') {
  if (subject === 'all') {
    const batch = db.batch();
    for (const subj of SUBJECTS) {
      const docRef = db.collection('users')
        .doc(userId)
        .collection('chapter_practice_weekly')
        .doc(subj);
      batch.delete(docRef);
    }
    await retryFirestoreOperation(() => batch.commit());
    logger.info('Cleared all weekly chapter practice usage', { userId });
  } else {
    const normalizedSubject = normalizeSubject(subject);
    const docRef = db.collection('users')
      .doc(userId)
      .collection('chapter_practice_weekly')
      .doc(normalizedSubject);
    await retryFirestoreOperation(() => docRef.delete());
    logger.info('Cleared weekly chapter practice usage', { userId, subject: normalizedSubject });
  }
}

module.exports = {
  getWeeklyUsage,
  canPracticeSubject,
  recordCompletion,
  clearWeeklyUsage,
  normalizeSubject,
  COOLDOWN_DAYS,
  SUBJECTS
};
