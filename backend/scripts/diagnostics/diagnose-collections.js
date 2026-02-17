/**
 * Collection Diagnostic Script
 *
 * Shows the state of user data collections and helps identify:
 * - Total documents in each collection
 * - Which user IDs have data
 * - Whether those users exist in Auth and/or users collection
 *
 * Usage:
 *   node scripts/diagnose-collections.js [--collection=name]
 */

const { db, admin } = require('../src/config/firebase');

const COLLECTIONS_TO_CHECK = [
    'assessment_responses',
    'daily_quizzes',
    'daily_quiz_responses',
    'practice_streaks',
    'theta_history',
    'theta_snapshots',
    'chapter_practice_sessions',
    'chapter_practice_responses',
    'share_events',
    // Legacy typo collections
    'chapter_practise_sessions',
    'thetha_snapshots',
    'thetha_history'
];

async function checkUserExists(userId) {
    const results = { inAuth: false, inFirestore: false };

    try {
        await admin.auth().getUser(userId);
        results.inAuth = true;
    } catch (e) {
        // User not in Auth
    }

    try {
        const userDoc = await db.collection('users').doc(userId).get();
        results.inFirestore = userDoc.exists;
    } catch (e) {
        // Error checking Firestore
    }

    return results;
}

async function diagnoseCollection(collectionName) {
    console.log(`\n${'='.repeat(60)}`);
    console.log(`📂 ${collectionName}`);
    console.log('='.repeat(60));

    const snapshot = await db.collection(collectionName).get();

    if (snapshot.empty) {
        console.log('   (empty)');
        return { name: collectionName, total: 0, users: [] };
    }

    console.log(`   Total documents: ${snapshot.size}`);

    const userDetails = [];

    for (const doc of snapshot.docs) {
        const userId = doc.id;
        const exists = await checkUserExists(userId);

        let status = '';
        if (exists.inAuth && exists.inFirestore) {
            status = '✅ Active user (in Auth + Firestore)';
        } else if (exists.inAuth && !exists.inFirestore) {
            status = '⚠️  In Auth but NO Firestore profile';
        } else if (!exists.inAuth && exists.inFirestore) {
            status = '⚠️  In Firestore but NOT in Auth';
        } else {
            status = '❌ Orphaned (not in Auth or Firestore)';
        }

        userDetails.push({
            userId,
            inAuth: exists.inAuth,
            inFirestore: exists.inFirestore,
            status
        });
    }

    // Group by status
    const active = userDetails.filter(u => u.inAuth && u.inFirestore);
    const authOnly = userDetails.filter(u => u.inAuth && !u.inFirestore);
    const firestoreOnly = userDetails.filter(u => !u.inAuth && u.inFirestore);
    const orphaned = userDetails.filter(u => !u.inAuth && !u.inFirestore);

    console.log(`\n   Breakdown:`);
    console.log(`   - Active users (Auth + Firestore): ${active.length}`);
    console.log(`   - Auth only (no profile):          ${authOnly.length}`);
    console.log(`   - Firestore only (no Auth):        ${firestoreOnly.length}`);
    console.log(`   - Orphaned (neither):              ${orphaned.length}`);

    if (authOnly.length > 0) {
        console.log(`\n   Users in Auth but missing Firestore profile:`);
        authOnly.slice(0, 5).forEach(u => console.log(`      - ${u.userId}`));
        if (authOnly.length > 5) console.log(`      ... and ${authOnly.length - 5} more`);
    }

    if (orphaned.length > 0) {
        console.log(`\n   Orphaned user IDs:`);
        orphaned.slice(0, 5).forEach(u => console.log(`      - ${u.userId}`));
        if (orphaned.length > 5) console.log(`      ... and ${orphaned.length - 5} more`);
    }

    return { name: collectionName, total: snapshot.size, users: userDetails };
}

async function main() {
    console.log('\n' + '='.repeat(60));
    console.log('🔍 COLLECTION DIAGNOSTIC REPORT');
    console.log('='.repeat(60));

    // Check args for specific collection
    const args = process.argv.slice(2);
    const collectionArg = args.find(arg => arg.startsWith('--collection='));
    const targetCollection = collectionArg ? collectionArg.split('=')[1] : null;

    const collectionsToCheck = targetCollection
        ? COLLECTIONS_TO_CHECK.filter(c => c === targetCollection)
        : COLLECTIONS_TO_CHECK;

    if (targetCollection && collectionsToCheck.length === 0) {
        console.log(`\n❌ Collection "${targetCollection}" not in check list.`);
        console.log(`Available: ${COLLECTIONS_TO_CHECK.join(', ')}`);
        process.exit(1);
    }

    // Get Auth user count
    console.log('\n📋 Fetching Firebase Auth users...');
    let authUserCount = 0;
    let nextPageToken;
    do {
        const listResult = await admin.auth().listUsers(1000, nextPageToken);
        authUserCount += listResult.users.length;
        nextPageToken = listResult.pageToken;
    } while (nextPageToken);
    console.log(`   Total users in Firebase Auth: ${authUserCount}`);

    // Get Firestore users count
    const usersSnapshot = await db.collection('users').get();
    console.log(`   Total users in Firestore 'users' collection: ${usersSnapshot.size}`);

    // Diagnose each collection
    const results = [];
    for (const collection of collectionsToCheck) {
        try {
            const result = await diagnoseCollection(collection);
            results.push(result);
        } catch (error) {
            console.log(`\n❌ Error checking ${collection}: ${error.message}`);
        }
    }

    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 SUMMARY');
    console.log('='.repeat(60));

    const nonEmpty = results.filter(r => r.total > 0);
    if (nonEmpty.length === 0) {
        console.log('\n   All checked collections are empty! ✅');
    } else {
        console.log('\n   Collections with data:');
        nonEmpty.forEach(r => {
            console.log(`   - ${r.name}: ${r.total} documents`);
        });
    }

    console.log('\n' + '='.repeat(60) + '\n');
}

main().then(() => process.exit(0)).catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});
