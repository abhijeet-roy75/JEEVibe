/**
 * Orphaned User Data Cleanup Script
 *
 * Scans all user-related collections and identifies data belonging to users
 * that no longer exist in Firebase Auth or the users collection.
 *
 * Collections scanned:
 * - users/{userId} (profile documents)
 * - users/{userId}/daily_usage
 * - users/{userId}/snaps
 * - users/{userId}/quizzes
 * - users/{userId}/tutor_conversation
 * - users/{userId}/chapter_practice_weekly
 * - users/{userId}/subscriptions
 * - assessment_responses/{userId}
 * - daily_quizzes/{userId}
 * - daily_quiz_responses/{userId}
 * - practice_streaks/{userId}
 * - theta_history/{userId}
 * - theta_snapshots/{userId}
 * - chapter_practice_sessions/{userId}
 * - chapter_practice_responses/{userId}
 * - share_events/{userId}
 * - feedback (queried by userId field)
 *
 * Usage:
 *   node scripts/cleanup-orphaned-data.js [--preview] [--force] [--collection=name]
 *
 * Flags:
 *   --preview       : Dry-run mode. Shows orphaned data without deleting.
 *   --force         : Skips confirmation prompt.
 *   --collection=X  : Only scan a specific collection (e.g., --collection=theta_snapshots)
 */

const { db, admin, storage } = require('../src/config/firebase');
const readline = require('readline');

// Collections with userId as document ID
const USER_ID_DOC_COLLECTIONS = [
    'users',
    'assessment_responses',
    'daily_quizzes',
    'daily_quiz_responses',
    'practice_streaks',
    'theta_history',
    'theta_snapshots',
    'chapter_practice_sessions',
    'chapter_practice_responses',
    'share_events',
    // Legacy collections with typos (kept for cleanup purposes)
    'chapter_practise_sessions',  // typo: practise -> practice
    'thetha_snapshots',           // typo: thetha -> theta
    'thetha_history'              // typo: thetha -> theta
];

// Subcollections under users/{userId}
const USER_SUBCOLLECTIONS = [
    'daily_usage',
    'snaps',
    'quizzes',
    'tutor_conversation',
    'chapter_practice_weekly',
    'subscriptions'
];

/**
 * Get all valid user IDs from Firebase Auth
 * @returns {Promise<Set<string>>} Set of valid user IDs
 */
async function getValidUserIds() {
    console.log('📋 Fetching all users from Firebase Auth...');
    const validUserIds = new Set();
    let nextPageToken;

    do {
        const listResult = await admin.auth().listUsers(1000, nextPageToken);
        listResult.users.forEach(user => validUserIds.add(user.uid));
        nextPageToken = listResult.pageToken;
    } while (nextPageToken);

    console.log(`   Found ${validUserIds.size} users in Firebase Auth\n`);
    return validUserIds;
}

/**
 * Delete a collection recursively
 */
async function deleteCollectionRecursively(collectionRef, batchSize = 100) {
    const query = collectionRef.limit(batchSize);

    return new Promise((resolve, reject) => {
        deleteQueryBatch(query, resolve).catch(reject);
    });
}

async function deleteQueryBatch(query, resolve) {
    const snapshot = await query.get();

    if (snapshot.size === 0) {
        resolve();
        return;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
    });
    await batch.commit();

    process.nextTick(() => {
        deleteQueryBatch(query, resolve);
    });
}

/**
 * Delete all subcollections for a user document
 */
async function deleteUserSubcollections(userId) {
    const userRef = db.collection('users').doc(userId);

    // Delete known subcollections
    for (const subcollection of USER_SUBCOLLECTIONS) {
        if (subcollection === 'tutor_conversation') {
            // Special handling for nested tutor_conversation
            const tutorRef = userRef.collection('tutor_conversation').doc('active');
            await deleteCollectionRecursively(tutorRef.collection('messages'));
            await tutorRef.delete().catch(() => {});
        } else {
            await deleteCollectionRecursively(userRef.collection(subcollection));
        }
    }
}

/**
 * Delete nested subcollections for collections with questions
 */
async function deleteNestedQuestions(parentRef) {
    const docs = await parentRef.get();

    for (const doc of docs.docs) {
        const questionsRef = doc.ref.collection('questions');
        await deleteCollectionRecursively(questionsRef);
    }
}

/**
 * Scan a top-level collection for orphaned user documents
 */
async function scanCollection(collectionName, validUserIds, isPreview) {
    console.log(`\n📂 Scanning ${collectionName}...`);

    const collectionRef = db.collection(collectionName);
    const snapshot = await collectionRef.get();

    if (snapshot.empty) {
        console.log(`   Collection is empty`);
        return { total: 0, orphaned: 0, deleted: 0 };
    }

    const orphanedDocs = [];

    for (const doc of snapshot.docs) {
        const userId = doc.id;
        if (!validUserIds.has(userId)) {
            orphanedDocs.push({ id: userId, ref: doc.ref });
        }
    }

    console.log(`   Total documents: ${snapshot.size}`);
    console.log(`   Orphaned documents: ${orphanedDocs.length}`);

    if (orphanedDocs.length === 0) {
        return { total: snapshot.size, orphaned: 0, deleted: 0 };
    }

    if (isPreview) {
        console.log(`   [DRY RUN] Would delete ${orphanedDocs.length} orphaned documents:`);
        orphanedDocs.slice(0, 10).forEach(doc => console.log(`      - ${doc.id}`));
        if (orphanedDocs.length > 10) {
            console.log(`      ... and ${orphanedDocs.length - 10} more`);
        }
        return { total: snapshot.size, orphaned: orphanedDocs.length, deleted: 0 };
    }

    // Delete orphaned documents
    let deleted = 0;
    for (const doc of orphanedDocs) {
        try {
            // Handle collections with subcollections
            if (collectionName === 'users') {
                await deleteUserSubcollections(doc.id);
            } else if (collectionName === 'daily_quizzes') {
                // Delete nested questions first
                await deleteNestedQuestions(doc.ref.collection('quizzes'));
                await deleteCollectionRecursively(doc.ref.collection('quizzes'));
            } else if (collectionName === 'chapter_practice_sessions' || collectionName === 'chapter_practise_sessions') {
                // Delete nested questions first (handles both correct and typo versions)
                await deleteNestedQuestions(doc.ref.collection('sessions'));
                await deleteCollectionRecursively(doc.ref.collection('sessions'));
            } else if (collectionName === 'assessment_responses') {
                await deleteCollectionRecursively(doc.ref.collection('responses'));
            } else if (collectionName === 'daily_quiz_responses') {
                await deleteCollectionRecursively(doc.ref.collection('responses'));
            } else if (collectionName === 'theta_history' || collectionName === 'thetha_history') {
                await deleteCollectionRecursively(doc.ref.collection('snapshots'));
            } else if (collectionName === 'theta_snapshots' || collectionName === 'thetha_snapshots') {
                await deleteCollectionRecursively(doc.ref.collection('daily'));
            } else if (collectionName === 'chapter_practice_responses') {
                await deleteCollectionRecursively(doc.ref.collection('responses'));
            } else if (collectionName === 'share_events') {
                await deleteCollectionRecursively(doc.ref.collection('items'));
            }

            // Delete the parent document
            await doc.ref.delete();
            deleted++;

            if (deleted % 10 === 0) {
                process.stdout.write(`\r   Deleted ${deleted}/${orphanedDocs.length} orphaned documents...`);
            }
        } catch (error) {
            console.error(`\n   ⚠️  Error deleting ${doc.id}: ${error.message}`);
        }
    }

    console.log(`\n   ✅ Deleted ${deleted} orphaned documents`);
    return { total: snapshot.size, orphaned: orphanedDocs.length, deleted };
}

/**
 * Scan feedback collection for orphaned entries (userId is a field, not doc ID)
 */
async function scanFeedbackCollection(validUserIds, isPreview) {
    console.log(`\n📂 Scanning feedback...`);

    const collectionRef = db.collection('feedback');
    const snapshot = await collectionRef.get();

    if (snapshot.empty) {
        console.log(`   Collection is empty`);
        return { total: 0, orphaned: 0, deleted: 0 };
    }

    const orphanedDocs = [];

    for (const doc of snapshot.docs) {
        const data = doc.data();
        const userId = data.userId;
        if (userId && !validUserIds.has(userId)) {
            orphanedDocs.push({ id: doc.id, userId, ref: doc.ref });
        }
    }

    console.log(`   Total documents: ${snapshot.size}`);
    console.log(`   Orphaned documents: ${orphanedDocs.length}`);

    if (orphanedDocs.length === 0) {
        return { total: snapshot.size, orphaned: 0, deleted: 0 };
    }

    if (isPreview) {
        console.log(`   [DRY RUN] Would delete ${orphanedDocs.length} orphaned feedback entries`);
        return { total: snapshot.size, orphaned: orphanedDocs.length, deleted: 0 };
    }

    // Delete in batches
    const batchSize = 450;
    let deleted = 0;

    for (let i = 0; i < orphanedDocs.length; i += batchSize) {
        const batch = db.batch();
        const chunk = orphanedDocs.slice(i, i + batchSize);

        chunk.forEach(doc => {
            batch.delete(doc.ref);
        });

        await batch.commit();
        deleted += chunk.length;
        process.stdout.write(`\r   Deleted ${deleted}/${orphanedDocs.length} orphaned feedback entries...`);
    }

    console.log(`\n   ✅ Deleted ${deleted} orphaned feedback entries`);
    return { total: snapshot.size, orphaned: orphanedDocs.length, deleted };
}

/**
 * Scan storage for orphaned snap images
 */
async function scanStorage(validUserIds, isPreview) {
    console.log(`\n📂 Scanning Firebase Storage (snaps/)...`);

    try {
        const bucket = storage.bucket();
        const [files] = await bucket.getFiles({ prefix: 'snaps/' });

        if (files.length === 0) {
            console.log(`   No files found in storage`);
            return { total: 0, orphaned: 0, deleted: 0 };
        }

        // Group files by userId
        const filesByUser = new Map();
        for (const file of files) {
            // Path format: snaps/{userId}/...
            const parts = file.name.split('/');
            if (parts.length >= 2) {
                const userId = parts[1];
                if (!filesByUser.has(userId)) {
                    filesByUser.set(userId, []);
                }
                filesByUser.get(userId).push(file);
            }
        }

        const orphanedUsers = [];
        let orphanedFileCount = 0;

        for (const [userId, userFiles] of filesByUser) {
            if (!validUserIds.has(userId)) {
                orphanedUsers.push(userId);
                orphanedFileCount += userFiles.length;
            }
        }

        console.log(`   Total files: ${files.length}`);
        console.log(`   Orphaned users with files: ${orphanedUsers.length}`);
        console.log(`   Orphaned files: ${orphanedFileCount}`);

        if (orphanedFileCount === 0) {
            return { total: files.length, orphaned: 0, deleted: 0 };
        }

        if (isPreview) {
            console.log(`   [DRY RUN] Would delete ${orphanedFileCount} orphaned files from ${orphanedUsers.length} users`);
            return { total: files.length, orphaned: orphanedFileCount, deleted: 0 };
        }

        // Delete files
        let deleted = 0;
        for (const userId of orphanedUsers) {
            const userFiles = filesByUser.get(userId);
            for (const file of userFiles) {
                try {
                    await file.delete();
                    deleted++;
                    if (deleted % 10 === 0) {
                        process.stdout.write(`\r   Deleted ${deleted}/${orphanedFileCount} orphaned files...`);
                    }
                } catch (error) {
                    console.error(`\n   ⚠️  Error deleting ${file.name}: ${error.message}`);
                }
            }
        }

        console.log(`\n   ✅ Deleted ${deleted} orphaned files`);
        return { total: files.length, orphaned: orphanedFileCount, deleted };
    } catch (error) {
        console.error(`   ⚠️  Error scanning storage: ${error.message}`);
        return { total: 0, orphaned: 0, deleted: 0 };
    }
}

/**
 * Main cleanup function
 */
async function cleanupOrphanedData(options = {}) {
    const { isPreview = false, isForce = false, targetCollection = null } = options;

    console.log('\n' + '='.repeat(60));
    console.log('🧹 ORPHANED USER DATA CLEANUP');
    console.log('='.repeat(60));

    if (isPreview) {
        console.log('\n👀 PREVIEW MODE - No data will be deleted\n');
    } else if (!isForce) {
        const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
        const confirmed = await new Promise(resolve => {
            rl.question(`\n⚠️  WARNING: This will delete all data for users that no longer exist.\n\nType 'CLEANUP' to confirm: `, answer => {
                rl.close();
                resolve(answer.trim() === 'CLEANUP');
            });
        });

        if (!confirmed) {
            console.log('\n❌ Cleanup cancelled. No changes made.\n');
            return;
        }
    }

    try {
        // Get valid user IDs
        const validUserIds = await getValidUserIds();

        const results = {
            collections: {},
            totals: { total: 0, orphaned: 0, deleted: 0 }
        };

        // Scan collections
        const collectionsToScan = targetCollection
            ? USER_ID_DOC_COLLECTIONS.filter(c => c === targetCollection)
            : USER_ID_DOC_COLLECTIONS;

        for (const collection of collectionsToScan) {
            const result = await scanCollection(collection, validUserIds, isPreview);
            results.collections[collection] = result;
            results.totals.total += result.total;
            results.totals.orphaned += result.orphaned;
            results.totals.deleted += result.deleted;
        }

        // Scan feedback collection (special case - userId is a field)
        if (!targetCollection || targetCollection === 'feedback') {
            const feedbackResult = await scanFeedbackCollection(validUserIds, isPreview);
            results.collections['feedback'] = feedbackResult;
            results.totals.total += feedbackResult.total;
            results.totals.orphaned += feedbackResult.orphaned;
            results.totals.deleted += feedbackResult.deleted;
        }

        // Scan storage
        if (!targetCollection || targetCollection === 'storage') {
            const storageResult = await scanStorage(validUserIds, isPreview);
            results.collections['storage'] = storageResult;
            results.totals.total += storageResult.total;
            results.totals.orphaned += storageResult.orphaned;
            results.totals.deleted += storageResult.deleted;
        }

        // Summary
        console.log('\n' + '='.repeat(60));
        console.log('📊 SUMMARY');
        console.log('='.repeat(60));
        console.log(`\nTotal items scanned: ${results.totals.total}`);
        console.log(`Orphaned items found: ${results.totals.orphaned}`);

        if (isPreview) {
            console.log(`\n💡 Run without --preview to delete orphaned data.`);
        } else {
            console.log(`Items deleted: ${results.totals.deleted}`);
            console.log(`\n✅ Orphaned data cleanup complete!`);
        }

        console.log('='.repeat(60) + '\n');

    } catch (error) {
        console.error(`\n❌ Fatal Error during cleanup:`, error);
        process.exit(1);
    }
}

// Parse args
const args = process.argv.slice(2);
const collectionArg = args.find(arg => arg.startsWith('--collection='));
const options = {
    isPreview: args.includes('--preview'),
    isForce: args.includes('--force'),
    targetCollection: collectionArg ? collectionArg.split('=')[1] : null
};

cleanupOrphanedData(options).then(() => process.exit(0));
