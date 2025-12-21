/**
 * Chapter Mapping Service
 * 
 * Dynamically maps standardized chapter keys (e.g., "physics_laws_of_motion")
 * to the actual names found in the Firestore "questions" collection.
 */

const { db } = require('../config/firebase');
const logger = require('../utils/logger');
const { formatChapterKey } = require('./thetaCalculationService');

// In-memory cache for mappings
// Map<chapterKey, { subject, chapter }>
let mappingCache = null;
let lastUpdate = 0;
const CACHE_TTL = 30 * 60 * 1000; // 30 minutes

/**
 * Initialize or refresh mappings by scanning the questions collection
 */
async function initializeMappings() {
    try {
        const now = Date.now();
        if (mappingCache && (now - lastUpdate < CACHE_TTL)) {
            return mappingCache;
        }

        logger.info('Refreshing chapter mappings from database...');

        // Fetch unique subject/chapter pairs
        // Note: In a large DB, we might want a dedicated 'metadata' collection
        // but for 1200 questions, a direct scan (or distinct query) is fine.
        const snapshot = await db.collection('questions').get();

        const newCache = new Map();

        snapshot.forEach(doc => {
            const data = doc.data();
            const subjectName = data.subject;
            const chapterName = data.chapter;

            if (subjectName && chapterName) {
                const key = formatChapterKey(subjectName, chapterName);
                if (!newCache.has(key)) {
                    newCache.set(key, {
                        subject: subjectName,
                        chapter: chapterName
                    });
                }
            }
        });

        mappingCache = newCache;
        lastUpdate = now;
        logger.info('Chapter mappings refreshed', { uniqueChapters: mappingCache.size });
        return mappingCache;
    } catch (error) {
        logger.error('Failed to initialize chapter mappings', { error: error.message });
        throw error;
    }
}

/**
 * Get the actual database names for a given chapter key
 * 
 * @param {string} chapterKey - Standardized key (e.g. "physics_magnetic_effects")
 * @returns {Promise<{subject: string, chapter: string}|null>}
 */
async function getDatabaseNames(chapterKey) {
    const cache = await initializeMappings();
    const mapping = cache.get(chapterKey);

    if (mapping) {
        return mapping;
    }

    logger.warn('No database mapping found for chapter key', { chapterKey });
    return null;
}

module.exports = {
    initializeMappings,
    getDatabaseNames
};
