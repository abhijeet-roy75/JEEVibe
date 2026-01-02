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
 *
 * Usage:
 *   node scripts/cleanup-user.js <userId|phoneNumber> [--preview] [--force]
 *
 * Flags:
 *   --preview  : Dry-run mode. Shows what would be deleted without making changes.
 *   --force    : Skips the interactive confirmation prompt.
 */

const { db, admin, storage } = require('../src/config/firebase');
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

        // --- SUBCOLLECTIONS ---
        console.log('   - Processing snap history documents...');
        await deleteCollection(userRef.collection('snaps'), isPreview);

        console.log('   - Processing daily snap usage records...');
        await deleteCollection(userRef.collection('daily_usage'), isPreview);

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

// Parse args
const args = process.argv.slice(2);
const identifier = args.find(arg => !arg.startsWith('--'));
const options = {
    isPreview: args.includes('--preview'),
    isForce: args.includes('--force')
};

cleanupUser(identifier, options).then(() => process.exit(0));
