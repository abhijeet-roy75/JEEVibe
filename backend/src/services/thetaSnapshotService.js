/**
 * Theta Snapshot Service
 *
 * Handles storage and retrieval of per-quiz theta snapshots.
 * Each snapshot captures the complete theta state after a daily quiz,
 * enabling analytics and progress tracking over time.
 *
 * Collection: theta_snapshots/{userId}/daily/{quizId}
 *
 * Storage estimate: ~5KB per snapshot × 365 quizzes = ~1.8MB/user/year
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { ApiError } = require('../middleware/errorHandler');

/**
 * Validate userId format
 * @param {string} userId - The user ID to validate
 * @throws {ApiError} If userId is invalid
 */
function validateUserId(userId) {
  if (!userId || typeof userId !== 'string') {
    throw new ApiError(400, 'userId is required and must be a string', 'INVALID_USER_ID');
  }
  if (userId.trim().length === 0) {
    throw new ApiError(400, 'userId cannot be empty', 'INVALID_USER_ID');
  }
  if (userId.length > 128) {
    throw new ApiError(400, 'userId too long (max 128 characters)', 'INVALID_USER_ID');
  }
}

/**
 * Validate quizId format
 * @param {string} quizId - The quiz ID to validate
 * @throws {ApiError} If quizId is invalid
 */
function validateQuizId(quizId) {
  if (!quizId || typeof quizId !== 'string') {
    throw new ApiError(400, 'quizId is required and must be a string', 'INVALID_QUIZ_ID');
  }
  if (quizId.trim().length === 0) {
    throw new ApiError(400, 'quizId cannot be empty', 'INVALID_QUIZ_ID');
  }
  if (quizId.length > 100) {
    throw new ApiError(400, 'quizId too long (max 100 characters)', 'INVALID_QUIZ_ID');
  }
}

/**
 * Save a theta snapshot after quiz completion
 *
 * @param {string} userId - The user ID
 * @param {string} quizId - The quiz ID
 * @param {Object} snapshotData - The snapshot data
 * @param {Object} snapshotData.theta_by_chapter - Complete theta state by chapter
 * @param {Object} snapshotData.theta_by_subject - Theta aggregated by subject
 * @param {number} snapshotData.overall_theta - Overall theta value
 * @param {number} snapshotData.overall_percentile - Overall percentile
 * @param {Object} snapshotData.quiz_performance - Quiz performance summary
 * @param {Object} snapshotData.chapter_updates - Changes made in this quiz
 * @param {number} snapshotData.quiz_number - The quiz number for this user
 * @returns {Promise<Object>} The saved snapshot with ID
 */
async function saveThetaSnapshot(userId, quizId, snapshotData) {
  validateUserId(userId);
  validateQuizId(quizId);

  if (!snapshotData || typeof snapshotData !== 'object') {
    throw new ApiError(400, 'snapshotData is required and must be an object', 'INVALID_SNAPSHOT_DATA');
  }

  const snapshotRef = db.collection('theta_snapshots')
    .doc(userId)
    .collection('daily')
    .doc(quizId);

  const snapshot = {
    student_id: userId,
    quiz_id: quizId,
    quiz_number: snapshotData.quiz_number || null,
    snapshot_type: 'daily_quiz',

    // Complete theta state at this point in time
    theta_by_chapter: snapshotData.theta_by_chapter || {},
    theta_by_subject: snapshotData.theta_by_subject || {},
    overall_theta: snapshotData.overall_theta || 0,
    overall_percentile: snapshotData.overall_percentile || 50,

    // Quiz performance that triggered this snapshot
    quiz_performance: {
      score: snapshotData.quiz_performance?.score || 0,
      total: snapshotData.quiz_performance?.total || 0,
      accuracy: snapshotData.quiz_performance?.accuracy || 0,
      total_time_seconds: snapshotData.quiz_performance?.total_time_seconds || 0,
      chapters_tested: snapshotData.quiz_performance?.chapters_tested || []
    },

    // What changed in this quiz (for quick delta analysis)
    chapter_updates: snapshotData.chapter_updates || {},

    // Metadata - single timestamp (captured_at serves as both creation and capture time)
    captured_at: admin.firestore.FieldValue.serverTimestamp()
  };

  await retryFirestoreOperation(async () => {
    return await snapshotRef.set(snapshot);
  });

  logger.info('Theta snapshot saved', {
    userId,
    quizId,
    quizNumber: snapshot.quiz_number,
    overall_theta: snapshot.overall_theta,
    chapters_updated: Object.keys(snapshot.chapter_updates).length
  });

  return {
    ...snapshot,
    snapshot_id: quizId
  };
}

/**
 * Get theta snapshots for a user with pagination
 *
 * @param {string} userId - The user ID
 * @param {Object} options - Query options
 * @param {number} options.limit - Number of snapshots to return (default: 30)
 * @param {Date} options.startDate - Filter snapshots from this date
 * @param {Date} options.endDate - Filter snapshots until this date
 * @param {string} options.startAfter - Cursor for pagination (quiz_id)
 * @returns {Promise<Object>} Snapshots with pagination info
 */
async function getThetaSnapshots(userId, options = {}) {
  validateUserId(userId);

  const {
    limit = 30,
    startDate = null,
    endDate = null,
    startAfter = null
  } = options;

  let query = db.collection('theta_snapshots')
    .doc(userId)
    .collection('daily')
    .orderBy('captured_at', 'desc');

  // Apply date filters
  if (startDate) {
    query = query.where('captured_at', '>=', admin.firestore.Timestamp.fromDate(startDate));
  }
  if (endDate) {
    query = query.where('captured_at', '<=', admin.firestore.Timestamp.fromDate(endDate));
  }

  // Apply cursor pagination (with retry)
  if (startAfter) {
    const cursorDoc = await retryFirestoreOperation(async () => {
      return await db.collection('theta_snapshots')
        .doc(userId)
        .collection('daily')
        .doc(startAfter)
        .get();
    });

    if (cursorDoc.exists) {
      query = query.startAfter(cursorDoc);
    }
  }

  query = query.limit(limit + 1); // Fetch one extra to check if there's more

  const snapshot = await retryFirestoreOperation(async () => {
    return await query.get();
  });

  const snapshots = [];
  const docs = snapshot.docs.slice(0, limit);

  docs.forEach(doc => {
    const data = doc.data();
    snapshots.push({
      snapshot_id: doc.id,
      quiz_id: data.quiz_id,
      quiz_number: data.quiz_number,
      captured_at: data.captured_at?.toDate?.()?.toISOString() || data.captured_at,
      overall_theta: data.overall_theta,
      overall_percentile: data.overall_percentile,
      theta_by_subject: data.theta_by_subject,
      theta_by_chapter: data.theta_by_chapter,
      quiz_performance: data.quiz_performance,
      chapter_updates: data.chapter_updates
    });
  });

  const hasMore = snapshot.docs.length > limit;
  const lastDoc = docs[docs.length - 1];

  return {
    snapshots,
    pagination: {
      limit,
      has_more: hasMore,
      next_cursor: hasMore && lastDoc ? lastDoc.id : null
    }
  };
}

/**
 * Get a single theta snapshot by quiz ID
 *
 * @param {string} userId - The user ID
 * @param {string} quizId - The quiz ID
 * @returns {Promise<Object|null>} The snapshot or null if not found
 */
async function getThetaSnapshotByQuizId(userId, quizId) {
  validateUserId(userId);
  validateQuizId(quizId);

  const snapshotRef = db.collection('theta_snapshots')
    .doc(userId)
    .collection('daily')
    .doc(quizId);

  const doc = await retryFirestoreOperation(async () => {
    return await snapshotRef.get();
  });

  if (!doc.exists) {
    return null;
  }

  const data = doc.data();
  return {
    snapshot_id: doc.id,
    quiz_id: data.quiz_id,
    quiz_number: data.quiz_number,
    captured_at: data.captured_at?.toDate?.()?.toISOString() || data.captured_at,
    overall_theta: data.overall_theta,
    overall_percentile: data.overall_percentile,
    theta_by_subject: data.theta_by_subject,
    theta_by_chapter: data.theta_by_chapter,
    quiz_performance: data.quiz_performance,
    chapter_updates: data.chapter_updates
  };
}

/**
 * Get theta progression for a specific chapter over time
 *
 * @param {string} userId - The user ID
 * @param {string} chapterKey - The chapter key (e.g., "physics_electrostatics")
 * @param {Object} options - Query options
 * @param {number} options.limit - Number of data points (default: 30)
 * @returns {Promise<Array>} Array of {date, theta, percentile} objects
 */
async function getChapterThetaProgression(userId, chapterKey, options = {}) {
  validateUserId(userId);

  if (!chapterKey || typeof chapterKey !== 'string') {
    throw new ApiError(400, 'chapterKey is required and must be a string', 'INVALID_CHAPTER_KEY');
  }

  const { limit = 30 } = options;

  const query = db.collection('theta_snapshots')
    .doc(userId)
    .collection('daily')
    .orderBy('captured_at', 'desc')
    .limit(limit);

  const snapshot = await retryFirestoreOperation(async () => {
    return await query.get();
  });

  const progression = [];

  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const chapterData = data.theta_by_chapter?.[chapterKey];

    if (chapterData) {
      progression.push({
        quiz_id: data.quiz_id,
        quiz_number: data.quiz_number,
        date: data.captured_at?.toDate?.()?.toISOString() || data.captured_at,
        theta: chapterData.theta || 0,
        percentile: chapterData.percentile || 50,
        accuracy: chapterData.accuracy || 0,
        was_tested: data.chapter_updates?.[chapterKey] !== undefined
      });
    }
  });

  // Log if no data found for chapter (helps debug invalid chapter keys)
  if (progression.length === 0 && snapshot.docs.length > 0) {
    logger.warn('No theta progression data found for chapter', {
      userId,
      chapterKey,
      snapshotsChecked: snapshot.docs.length
    });
  }

  // Reverse to get chronological order (oldest first)
  return progression.reverse();
}

/**
 * Get theta progression for a specific subject over time
 *
 * @param {string} userId - The user ID
 * @param {string} subject - The subject (physics, chemistry, mathematics)
 * @param {Object} options - Query options
 * @param {number} options.limit - Number of data points (default: 30)
 * @returns {Promise<Array>} Array of {date, theta, percentile} objects
 */
async function getSubjectThetaProgression(userId, subject, options = {}) {
  validateUserId(userId);

  if (!subject || typeof subject !== 'string') {
    throw new ApiError(400, 'subject is required and must be a string', 'INVALID_SUBJECT');
  }

  const { limit = 30 } = options;

  const query = db.collection('theta_snapshots')
    .doc(userId)
    .collection('daily')
    .orderBy('captured_at', 'desc')
    .limit(limit);

  const snapshot = await retryFirestoreOperation(async () => {
    return await query.get();
  });

  const progression = [];

  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const subjectData = data.theta_by_subject?.[subject.toLowerCase()];

    if (subjectData) {
      progression.push({
        quiz_id: data.quiz_id,
        quiz_number: data.quiz_number,
        date: data.captured_at?.toDate?.()?.toISOString() || data.captured_at,
        theta: subjectData.theta || 0,
        percentile: subjectData.percentile || 50
      });
    }
  });

  // Reverse to get chronological order (oldest first)
  return progression.reverse();
}

/**
 * Get overall theta progression over time
 *
 * @param {string} userId - The user ID
 * @param {Object} options - Query options
 * @param {number} options.limit - Number of data points (default: 30)
 * @returns {Promise<Array>} Array of {date, theta, percentile} objects
 */
async function getOverallThetaProgression(userId, options = {}) {
  validateUserId(userId);

  const { limit = 30 } = options;

  const query = db.collection('theta_snapshots')
    .doc(userId)
    .collection('daily')
    .orderBy('captured_at', 'desc')
    .limit(limit);

  const snapshot = await retryFirestoreOperation(async () => {
    return await query.get();
  });

  const progression = [];

  snapshot.docs.forEach(doc => {
    const data = doc.data();
    progression.push({
      quiz_id: data.quiz_id,
      quiz_number: data.quiz_number,
      date: data.captured_at?.toDate?.()?.toISOString() || data.captured_at,
      theta: data.overall_theta || 0,
      percentile: data.overall_percentile || 50,
      quiz_accuracy: data.quiz_performance?.accuracy || 0
    });
  });

  // Reverse to get chronological order (oldest first)
  return progression.reverse();
}

/**
 * Get snapshot count for a user (for analytics)
 *
 * @param {string} userId - The user ID
 * @returns {Promise<number>} Total number of snapshots
 */
async function getSnapshotCount(userId) {
  validateUserId(userId);

  const countSnapshot = await retryFirestoreOperation(async () => {
    return await db.collection('theta_snapshots')
      .doc(userId)
      .collection('daily')
      .count()
      .get();
  });

  return countSnapshot.data().count;
}

module.exports = {
  saveThetaSnapshot,
  getThetaSnapshots,
  getThetaSnapshotByQuizId,
  getChapterThetaProgression,
  getSubjectThetaProgression,
  getOverallThetaProgression,
  getSnapshotCount
};
