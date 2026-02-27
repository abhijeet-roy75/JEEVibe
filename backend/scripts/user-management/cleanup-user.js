/**
 * User Data Cleanup Script
 *
 * SYSTEMATICALLY DELETES ALL DATA RELATED TO A SPECIFIC USER:
 * 1. Firebase Auth User (Optional cleanup)
 * 2. User Profile & stats (users/{userId})
 * 3. Snap usage (users/{userId}/daily_usage)
 * 4. Snap history (users/{userId}/snaps)
 * 5. Initial assessment responses (assessment_responses/{userId}/responses)
 * 6. Daily quizzes (daily_quizzes/{userId}/quizzes)
 *    - INCLUDING nested question subcollections (quizzes/{quizId}/questions)
 * 7. Daily quiz responses (daily_quiz_responses/{userId}/responses)
 * 8. Practice streaks (practice_streaks/{userId})
 * 9. Theta history/Weekly snapshots (theta_history/{userId}/snapshots)
 * 10. Snap Images in Storage (snaps/{userId}/*)
 * 11. AI Tutor conversations (users/{userId}/tutor_conversation/active/messages)
 * 12. Theta snapshots (theta_snapshots/{userId}/daily)
 * 13. Chapter practice sessions (chapter_practice_sessions/{userId}/sessions)
 * 14. Chapter practice responses (chapter_practice_responses/{userId}/responses)
 * 15. Chapter practice weekly limits (users/{userId}/chapter_practice_weekly)
 * 16. Subscriptions (users/{userId}/subscriptions)
 * 17. Share events (share_events/{userId}/items)
 * 18. Feedback entries (feedback collection, queried by userId)
 * 19. User quizzes subcollection (users/{userId}/quizzes)
 * 20. Snap practice sessions (snap_practice_sessions/{odatgabkak}/{odatgabkak} - from snap-and-solve)
 * 21. Trial events (trial_events collection, queried by user_id)
 *
 * LEGACY COLLECTIONS (typos - kept for cleanup):
 * 22. thetha_snapshots/{userId}/daily (typo: thetha -> theta)
 * 23. thetha_history/{userId}/snapshots (typo: thetha -> theta)
 * 24. chapter_practise_sessions/{userId}/sessions (typo: practise -> practice)
 *
 * Usage:
 *   node scripts/cleanup-user.js <userId|phoneNumber> [--preview] [--force]
 *
 * Flags:
 *   --preview  : Dry-run mode. Shows what would be deleted without making changes.
 *   --force    : Skips the interactive confirmation prompt.
 */

const { db, admin, storage } = require('../../src/config/firebase');
const readline = require('readline');

async function deleteCollection(collectionRef, isPreview = false, batchSize = 100) {
    const query = collectionRef.limit(batchSize);

    if (isPreview) {
        const snapshot = await query.get();
        if (snapshot.size > 0) {
            console.log(`     [DRY RUN] Would delete ~${snapshot.size} documents from ${collectionRef.path}`);
        }
        return;
    }

    return new Promise((resolve, reject) => {
        deleteQueryBatch(query, resolve).catch(reject);
    });
}

async function deleteQueryBatch(query, resolve) {
    const snapshot = await query.get();

    const batchSize = snapshot.size;
    if (batchSize === 0) {
        resolve();
        return;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
    });
    await batch.commit();

    // Recurse on the next process tick, to avoid
    // spreading the stack.
    process.nextTick(() => {
        deleteQueryBatch(query, resolve);
    });
}

/**
 * Delete quizzes with their nested question subcollections
 * Handles the new subcollection structure where each quiz has a questions/{position} subcollection
 * @param {string} userId
 * @param {boolean} isPreview
 */
async function deleteQuizzesWithSubcollections(userId, isPreview = false) {
    const quizzesRef = db.collection('daily_quizzes').doc(userId).collection('quizzes');
    const quizzesSnapshot = await quizzesRef.get();

    if (quizzesSnapshot.empty) {
        return;
    }

    if (isPreview) {
        console.log(`     [DRY RUN] Would delete ${quizzesSnapshot.size} quiz documents...`);

        // Count total question documents across all quizzes
        let totalQuestions = 0;
        for (const quizDoc of quizzesSnapshot.docs) {
            const questionsSnapshot = await quizDoc.ref.collection('questions').get();
            totalQuestions += questionsSnapshot.size;
        }

        if (totalQuestions > 0) {
            console.log(`     [DRY RUN] Would delete ${totalQuestions} question documents from quiz subcollections...`);
        }
        return;
    }

    // Delete each quiz and its questions subcollection
    let deletedQuizzes = 0;
    let deletedQuestions = 0;

    for (const quizDoc of quizzesSnapshot.docs) {
        // Delete questions subcollection first
        const questionsRef = quizDoc.ref.collection('questions');
        const questionsSnapshot = await questionsRef.get();

        if (!questionsSnapshot.empty) {
            const batch = db.batch();
            questionsSnapshot.docs.forEach(questionDoc => {
                batch.delete(questionDoc.ref);
            });
            await batch.commit();
            deletedQuestions += questionsSnapshot.size;
        }

        // Then delete the quiz document itself
        await quizDoc.ref.delete();
        deletedQuizzes++;
    }

    console.log(`     ✓ Deleted ${deletedQuizzes} quizzes and ${deletedQuestions} question documents`);
}

/**
 * Delete all files in a storage folder
 * @param {string} prefix - The folder path (e.g. 'snaps/userId')
 */
async function deleteStorageFolder(prefix, isPreview = false) {
    try {
        const bucket = storage.bucket();
        const [files] = await bucket.getFiles({ prefix });

        if (files.length === 0) {
            return;
        }

        if (isPreview) {
            console.log(`   - [DRY RUN] Would delete ${files.length} files from storage (${prefix})...`);
            return;
        }

        console.log(`   - Deleting ${files.length} files from storage (${prefix})...`);

        // Delete files in batches of 100
        const batchSize = 100;
        for (let i = 0; i < files.length; i += batchSize) {
            const batch = files.slice(i, i + batchSize);
            await Promise.all(batch.map(file => file.delete()));
        }
    } catch (error) {
        console.error(`⚠️  Warning: Error deleting storage folder ${prefix}:`, error.message);
        // Don't throw - continue with other deletions
    }
}

/**
 * Delete chapter practice sessions with their nested question subcollections
 * @param {string} userId
 * @param {boolean} isPreview
 * @param {string} collectionName - Collection name (supports legacy typo versions)
 */
async function deleteChapterPracticeSessions(userId, isPreview = false, collectionName = 'chapter_practice_sessions') {
    const sessionsRef = db.collection(collectionName).doc(userId).collection('sessions');
    const sessionsSnapshot = await sessionsRef.get();

    if (sessionsSnapshot.empty) {
        return;
    }

    if (isPreview) {
        console.log(`     [DRY RUN] Would delete ${sessionsSnapshot.size} chapter practice session documents...`);

        // Count total question documents across all sessions
        let totalQuestions = 0;
        for (const sessionDoc of sessionsSnapshot.docs) {
            const questionsSnapshot = await sessionDoc.ref.collection('questions').get();
            totalQuestions += questionsSnapshot.size;
        }

        if (totalQuestions > 0) {
            console.log(`     [DRY RUN] Would delete ${totalQuestions} question documents from session subcollections...`);
        }
        return;
    }

    // Delete each session and its questions subcollection
    let deletedSessions = 0;
    let deletedQuestions = 0;

    for (const sessionDoc of sessionsSnapshot.docs) {
        // Delete questions subcollection first
        const questionsRef = sessionDoc.ref.collection('questions');
        const questionsSnapshot = await questionsRef.get();

        if (!questionsSnapshot.empty) {
            const batch = db.batch();
            questionsSnapshot.docs.forEach(questionDoc => {
                batch.delete(questionDoc.ref);
            });
            await batch.commit();
            deletedQuestions += questionsSnapshot.size;
        }

        // Then delete the session document itself
        await sessionDoc.ref.delete();
        deletedSessions++;
    }

    console.log(`     ✓ Deleted ${deletedSessions} chapter practice sessions and ${deletedQuestions} question documents`);
}

/**
 * Delete feedback entries by userId
 * Queries the feedback collection for entries belonging to this user
 * @param {string} userId
 * @param {boolean} isPreview
 */
async function deleteFeedbackByUser(userId, isPreview = false) {
    const feedbackQuery = db.collection('feedback').where('userId', '==', userId);
    const feedbackSnapshot = await feedbackQuery.get();

    if (feedbackSnapshot.empty) {
        return;
    }

    if (isPreview) {
        console.log(`     [DRY RUN] Would delete ${feedbackSnapshot.size} feedback entries...`);
        return;
    }

    const batch = db.batch();
    feedbackSnapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
    });
    await batch.commit();

    console.log(`     ✓ Deleted ${feedbackSnapshot.size} feedback entries`);
}

/**
 * Delete trial events by user_id
 * Queries the trial_events collection for entries belonging to this user
 * @param {string} userId
 * @param {boolean} isPreview
 */
async function deleteTrialEventsByUser(userId, isPreview = false) {
    const trialEventsQuery = db.collection('trial_events').where('user_id', '==', userId);
    const trialEventsSnapshot = await trialEventsQuery.get();

    if (trialEventsSnapshot.empty) {
        return;
    }

    if (isPreview) {
        console.log(`     [DRY RUN] Would delete ${trialEventsSnapshot.size} trial event entries...`);
        return;
    }

    const batch = db.batch();
    trialEventsSnapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
    });
    await batch.commit();

    console.log(`     ✓ Deleted ${trialEventsSnapshot.size} trial event entries`);
}

async function cleanupUser(identifier, options = {}) {
    const { isPreview = false, isForce = false } = options;

    if (!identifier) {
        console.error('Error: Please provide a userId or phoneNumber as an argument.');
        console.error('Usage: npm run cleanup:user -- <userId|phoneNumber> [--preview] [--force]');
        process.exit(1);
    }

    let userId = identifier;
    let authUser = null;

    try {
        // --- IDENTIFIER RESOLUTION ---

        if (identifier.startsWith('+') || (/^\d+$/.test(identifier) && identifier.length >= 10)) {
            console.log(`🔍 Looking up user for phone number: ${identifier}...`);
            try {
                authUser = await admin.auth().getUserByPhoneNumber(identifier);
                userId = authUser.uid;
                console.log(`✅ Found User: ${authUser.phoneNumber} (UID: ${userId})`);
            } catch (authError) {
                if (authError.code === 'auth/user-not-found') {
                    console.error(`❌ Error: No user account found for phone number ${identifier}.`);
                    process.exit(1);
                }
                throw authError;
            }
        } else {
            try {
                authUser = await admin.auth().getUser(identifier);
                console.log(`🚀 Target User: ${userId} (${authUser.phoneNumber || 'no phone'})`);
            } catch (authError) {
                if (authError.code === 'auth/user-not-found') {
                    console.warn(`⚠️  Warning: User UID ${identifier} not found in Auth system, but checking database...`);
                } else {
                    console.warn(`⚠️  Warning: Could not verify UID in Auth: ${authError.message}`);
                }
            }
        }

        if (isPreview) {
            console.log('\n' + '='.repeat(60));
            console.log('👀 PREVIEW MODE - No data will be deleted');
            console.log('='.repeat(60) + '\n');
        } else if (!isForce) {
            const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
            const confirmed = await new Promise(resolve => {
                rl.question(`\n⚠️  EXTREME CAUTION: You are about to PERMANENTLY purge all data for user ${userId}.\nThis includes AUTH, STORAGE, and DATABASE records.\n\nType 'PURGE' to confirm: `, answer => {
                    rl.close();
                    resolve(answer.trim() === 'PURGE');
                });
            });

            if (!confirmed) {
                console.log('\n❌ Cleanup cancelled. No changes made.\n');
                return;
            }
        }

        // 1. Check if user document exists in Firestore
        const userRef = db.collection('users').doc(userId);
        const userDoc = await userRef.get();
        if (!userDoc.exists) {
            console.warn(`⚠️  Warning: Firestore profile document for ${userId} not found.`);
        }

        // --- STORAGE ---
        console.log('   - Checking Firebase Storage for snap images...');
        await deleteStorageFolder(`snaps/${userId}/`, isPreview);

        // --- USER SUBCOLLECTIONS ---
        console.log('   - Processing snap history documents...');
        await deleteCollection(userRef.collection('snaps'), isPreview);

        console.log('   - Processing daily snap usage records...');
        await deleteCollection(userRef.collection('daily_usage'), isPreview);

        console.log('   - Processing user quizzes subcollection...');
        await deleteCollection(userRef.collection('quizzes'), isPreview);

        console.log('   - Processing assessment responses...');
        await deleteCollection(db.collection('assessment_responses').doc(userId).collection('responses'), isPreview);
        if (!isPreview) await db.collection('assessment_responses').doc(userId).delete();

        console.log('   - Processing daily quizzes...');
        await deleteQuizzesWithSubcollections(userId, isPreview);
        if (!isPreview) await db.collection('daily_quizzes').doc(userId).delete();

        console.log('   - Processing individual quiz responses...');
        await deleteCollection(db.collection('daily_quiz_responses').doc(userId).collection('responses'), isPreview);
        if (!isPreview) await db.collection('daily_quiz_responses').doc(userId).delete();

        console.log('   - Processing theta history snapshots...');
        await deleteCollection(db.collection('theta_history').doc(userId).collection('snapshots'), isPreview);
        if (!isPreview) await db.collection('theta_history').doc(userId).delete();

        // --- LEGACY: thetha_history (typo version) ---
        console.log('   - Processing legacy thetha_history (typo)...');
        await deleteCollection(db.collection('thetha_history').doc(userId).collection('snapshots'), isPreview);
        if (!isPreview) await db.collection('thetha_history').doc(userId).delete().catch(() => {});

        // --- AI TUTOR CONVERSATIONS ---
        console.log('   - Processing AI tutor conversation messages...');
        const tutorConversationRef = userRef.collection('tutor_conversation').doc('active');
        await deleteCollection(tutorConversationRef.collection('messages'), isPreview);
        if (!isPreview) {
            await tutorConversationRef.delete();
        }

        // --- THETA SNAPSHOTS (Daily) ---
        console.log('   - Processing theta snapshots (daily)...');
        await deleteCollection(db.collection('theta_snapshots').doc(userId).collection('daily'), isPreview);
        if (!isPreview) await db.collection('theta_snapshots').doc(userId).delete();

        // --- LEGACY: thetha_snapshots (typo version) ---
        console.log('   - Processing legacy thetha_snapshots (typo)...');
        await deleteCollection(db.collection('thetha_snapshots').doc(userId).collection('daily'), isPreview);
        if (!isPreview) await db.collection('thetha_snapshots').doc(userId).delete().catch(() => {});

        // --- CHAPTER PRACTICE ---
        console.log('   - Processing chapter practice sessions...');
        await deleteChapterPracticeSessions(userId, isPreview);
        if (!isPreview) await db.collection('chapter_practice_sessions').doc(userId).delete();

        // --- LEGACY: chapter_practise_sessions (typo version) ---
        console.log('   - Processing legacy chapter_practise_sessions (typo)...');
        await deleteChapterPracticeSessions(userId, isPreview, 'chapter_practise_sessions');
        if (!isPreview) await db.collection('chapter_practise_sessions').doc(userId).delete().catch(() => {});

        console.log('   - Processing chapter practice responses...');
        await deleteCollection(db.collection('chapter_practice_responses').doc(userId).collection('responses'), isPreview);
        if (!isPreview) await db.collection('chapter_practice_responses').doc(userId).delete();

        console.log('   - Processing chapter practice weekly limits...');
        await deleteCollection(userRef.collection('chapter_practice_weekly'), isPreview);

        // --- SNAP PRACTICE SESSIONS (from snap-and-solve) ---
        console.log('   - Processing snap practice sessions...');
        await deleteCollection(db.collection('snap_practice_sessions').doc(userId).collection('sessions'), isPreview);
        if (!isPreview) await db.collection('snap_practice_sessions').doc(userId).delete().catch(() => {});

        // --- SUBSCRIPTIONS ---
        console.log('   - Processing subscription records...');
        await deleteCollection(userRef.collection('subscriptions'), isPreview);

        // --- SHARE EVENTS ---
        console.log('   - Processing share events...');
        await deleteCollection(db.collection('share_events').doc(userId).collection('items'), isPreview);
        if (!isPreview) await db.collection('share_events').doc(userId).delete();

        // --- FEEDBACK ---
        console.log('   - Processing feedback entries...');
        await deleteFeedbackByUser(userId, isPreview);

        // --- TRIAL EVENTS ---
        console.log('   - Processing trial events...');
        await deleteTrialEventsByUser(userId, isPreview);

        // --- TOP-LEVEL ---
        console.log('   - Processing practice streak document...');
        if (!isPreview) await db.collection('practice_streaks').doc(userId).delete();

        console.log('   - Processing user profile document...');
        if (!isPreview) await userRef.delete();

        // --- AUTH ---
        if (authUser) {
            if (isPreview) {
                console.log(`   - [DRY RUN] Would delete user account from Firebase Authentication (UID: ${userId})`);
            } else {
                console.log('   - Deleting user from Firebase Authentication...');
                await admin.auth().deleteUser(userId);
                console.log('✅  User account removed from Auth system.');
            }
        }

        if (isPreview) {
            console.log('\n' + '='.repeat(60));
            console.log('💡 Dry run complete. To actually delete, remove the --preview flag.');
            console.log('='.repeat(60) + '\n');
        } else {
            console.log(`\n🎉  CRITICAL CLEANUP COMPLETE!`);
            console.log(`Purged User: ${userId}`);
            console.log(`All associated database records, storage files, and the user account itself have been removed.`);
        }

    } catch (error) {
        console.error(`\n❌  Fatal Error during cleanup for ${identifier}:`, error);
        process.exit(1);
    }
}

// Export for use by other scripts
module.exports = { cleanupUser };

// Only run if called directly (not imported)
if (require.main === module) {
    const args = process.argv.slice(2);
    const identifier = args.find(arg => !arg.startsWith('--'));
    const options = {
        isPreview: args.includes('--preview'),
        isForce: args.includes('--force')
    };

    cleanupUser(identifier, options).then(() => process.exit(0));
}
