/**
 * Snap History Service
 * Handles Firestore operations for snap history, usage tracking, and storage URLs
 */

const { db, admin } = require('../config/firebase');
const logger = require('../utils/logger');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');

const DAILY_LIMIT = 20; // Temporarily increased from 5 to 20 for performance testing

/**
 * Get current snap usage for a user for today
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Usage info { used, limit, resetsAt }
 */
async function getDailyUsage(userId) {
    try {
        const today = new Date().toISOString().split('T')[0];
        const usageRef = db.collection('users').doc(userId).collection('daily_usage').doc(today);

        const doc = await usageRef.get();
        const used = doc.exists ? doc.data().count : 0;

        // Calculate reset time (midnight of next day)
        const tomorrow = new Date();
        tomorrow.setHours(24, 0, 0, 0);

        return {
            used,
            limit: DAILY_LIMIT,
            resetsAt: tomorrow.toISOString()
        };
    } catch (error) {
        logger.error('Error fetching daily usage:', { userId, error: error.message });
        return { used: 0, limit: DAILY_LIMIT, resetsAt: new Date().toISOString() };
    }
}

/**
 * Increment daily usage count for a user
 * @param {string} userId - User ID
 * @param {string} subject - Subject of the snap (for stats)
 */
async function incrementDailyUsage(userId, subject) {
    return await retryFirestoreOperation(async () => {
        const today = new Date().toISOString().split('T')[0];
        const userRef = db.collection('users').doc(userId);
        const usageRef = userRef.collection('daily_usage').doc(today);

        await db.runTransaction(async (transaction) => {
            // 1. Update daily count
            const usageDoc = await transaction.get(usageRef);
            const currentCount = usageDoc.exists ? usageDoc.data().count : 0;
            transaction.set(usageRef, {
                count: currentCount + 1,
                last_updated: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });

            // 2. Update user-level stats
            const subjectKey = subject ? subject.toLowerCase() : 'unknown';
            const statsUpdate = {
                'snap_stats.total_snaps': admin.firestore.FieldValue.increment(1),
                [`snap_stats.subject_counts.${subjectKey}`]: admin.firestore.FieldValue.increment(1),
                'snap_stats.last_snap_at': admin.firestore.FieldValue.serverTimestamp()
            };

            transaction.update(userRef, statsUpdate);
        });
    });
}

/**
 * Save a snap record to user's history
 * Note: Usage tracking is now handled separately by usageTrackingService
 * @param {string} userId - User ID
 * @param {Object} snapData - Snap data including solution, question, etc.
 * @returns {Promise<string>} Snap record ID
 */
async function saveSnapRecord(userId, snapData) {
    try {
        const snapsRef = db.collection('users').doc(userId).collection('snaps');

        const record = {
            ...snapData,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            created_at: admin.firestore.FieldValue.serverTimestamp()
        };

        const docRef = await snapsRef.add(record);

        // Update subject-level stats only (usage tracking handled by usageTrackingService)
        await updateSnapStats(userId, snapData.subject);

        return docRef.id;
    } catch (error) {
        logger.error('Error saving snap record:', { userId, error: error.message });
        throw error;
    }
}

/**
 * Update snap statistics (without usage counting)
 * @param {string} userId - User ID
 * @param {string} subject - Subject of the snap
 */
async function updateSnapStats(userId, subject) {
    try {
        const userRef = db.collection('users').doc(userId);
        const subjectKey = subject ? subject.toLowerCase() : 'unknown';

        await userRef.update({
            'snap_stats.total_snaps': admin.firestore.FieldValue.increment(1),
            [`snap_stats.subject_counts.${subjectKey}`]: admin.firestore.FieldValue.increment(1),
            'snap_stats.last_snap_at': admin.firestore.FieldValue.serverTimestamp()
        });
    } catch (error) {
        // Non-blocking - log error but don't fail
        logger.warn('Error updating snap stats:', { userId, error: error.message });
    }
}

/**
 * Get snap history for a user
 * @param {string} userId - User ID
 * @param {number} limit - Number of records to fetch
 * @param {string} lastDocId - For pagination (optional)
 * @param {number} historyDays - Number of days of history to return (-1 for unlimited)
 * @returns {Promise<Array>} List of snap records
 */
async function getSnapHistory(userId, limit = 20, lastDocId = null, historyDays = -1) {
    try {
        let query = db.collection('users')
            .doc(userId)
            .collection('snaps')
            .orderBy('timestamp', 'desc');

        // Apply date filter based on tier's history limit
        if (historyDays > 0) {
            const cutoffDate = new Date();
            cutoffDate.setDate(cutoffDate.getDate() - historyDays);
            cutoffDate.setHours(0, 0, 0, 0);
            query = query.where('timestamp', '>=', cutoffDate);
        }

        query = query.limit(limit);

        if (lastDocId) {
            const lastDoc = await db.collection('users').doc(userId).collection('snaps').doc(lastDocId).get();
            if (lastDoc.exists) {
                query = query.startAfter(lastDoc);
            }
        }

        const snapshot = await query.get();
        return snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            timestamp: doc.data().timestamp ? doc.data().timestamp.toDate().toISOString() : null
        }));
    } catch (error) {
        logger.error('Error fetching snap history:', { userId, error: error.message });
        throw error;
    }
}

module.exports = {
    getDailyUsage,
    incrementDailyUsage,
    saveSnapRecord,
    getSnapHistory,
    DAILY_LIMIT
};
