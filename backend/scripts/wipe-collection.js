/**
 * Collection Wipe Script
 *
 * DANGER: Completely wipes ALL data from specified collections.
 * Use with extreme caution - this deletes data for ALL users.
 *
 * Usage:
 *   node scripts/wipe-collection.js <collection-name> [--preview] [--force]
 *
 * Examples:
 *   node scripts/wipe-collection.js theta_snapshots --preview
 *   node scripts/wipe-collection.js daily_quizzes --force
 */

const { db } = require('../src/config/firebase');
const readline = require('readline');

// Allowed collections to wipe (safety measure)
const ALLOWED_COLLECTIONS = [
    'assessment_responses',
    'daily_quizzes',
    'daily_quiz_responses',
    'practice_streaks',
    'theta_history',
    'theta_snapshots',
    'chapter_practice_sessions',
    'chapter_practice_responses',
    'share_events',
    'feedback',
    // Legacy typo collections
    'chapter_practise_sessions',
    'thetha_snapshots',
    'thetha_history'
];

// Subcollection mappings
const SUBCOLLECTION_MAP = {
    'assessment_responses': ['responses'],
    'daily_quizzes': ['quizzes'],  // quizzes have nested 'questions'
    'daily_quiz_responses': ['responses'],
    'theta_history': ['snapshots'],
    'theta_snapshots': ['daily'],
    'thetha_snapshots': ['daily'],
    'thetha_history': ['snapshots'],
    'chapter_practice_sessions': ['sessions'],  // sessions have nested 'questions'
    'chapter_practise_sessions': ['sessions'],
    'chapter_practice_responses': ['responses'],
    'share_events': ['items']
};

// Collections with nested questions subcollections
const HAS_NESTED_QUESTIONS = ['daily_quizzes', 'chapter_practice_sessions', 'chapter_practise_sessions'];

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

async function wipeCollection(collectionName, isPreview = false) {
    console.log(`\n📂 Processing ${collectionName}...`);

    const collectionRef = db.collection(collectionName);
    const snapshot = await collectionRef.get();

    if (snapshot.empty) {
        console.log('   Collection is already empty.');
        return { deleted: 0 };
    }

    console.log(`   Found ${snapshot.size} documents`);

    if (isPreview) {
        console.log(`   [DRY RUN] Would delete ${snapshot.size} documents and all subcollections`);
        return { deleted: 0, wouldDelete: snapshot.size };
    }

    let deleted = 0;
    const subcollections = SUBCOLLECTION_MAP[collectionName] || [];
    const hasNestedQuestions = HAS_NESTED_QUESTIONS.includes(collectionName);

    for (const doc of snapshot.docs) {
        // Delete subcollections first
        for (const subcol of subcollections) {
            const subcolRef = doc.ref.collection(subcol);

            // Check for nested questions
            if (hasNestedQuestions) {
                const subDocs = await subcolRef.get();
                for (const subDoc of subDocs.docs) {
                    await deleteCollectionRecursively(subDoc.ref.collection('questions'));
                }
            }

            await deleteCollectionRecursively(subcolRef);
        }

        // Delete the document
        await doc.ref.delete();
        deleted++;

        if (deleted % 10 === 0) {
            process.stdout.write(`\r   Deleted ${deleted}/${snapshot.size} documents...`);
        }
    }

    console.log(`\n   ✅ Deleted ${deleted} documents`);
    return { deleted };
}

async function main() {
    const args = process.argv.slice(2);
    const collectionName = args.find(arg => !arg.startsWith('--'));
    const isPreview = args.includes('--preview');
    const isForce = args.includes('--force');

    if (!collectionName) {
        console.error('\n❌ Error: Please specify a collection name.');
        console.error('\nUsage: node scripts/wipe-collection.js <collection-name> [--preview] [--force]');
        console.error('\nAllowed collections:');
        ALLOWED_COLLECTIONS.forEach(c => console.error(`  - ${c}`));
        process.exit(1);
    }

    if (!ALLOWED_COLLECTIONS.includes(collectionName)) {
        console.error(`\n❌ Error: "${collectionName}" is not in the allowed list.`);
        console.error('\nAllowed collections:');
        ALLOWED_COLLECTIONS.forEach(c => console.error(`  - ${c}`));
        process.exit(1);
    }

    console.log('\n' + '='.repeat(60));
    console.log('🗑️  COLLECTION WIPE TOOL');
    console.log('='.repeat(60));
    console.log(`\nTarget: ${collectionName}`);

    if (isPreview) {
        console.log('Mode: PREVIEW (no changes will be made)');
    } else {
        console.log('Mode: DESTRUCTIVE');

        if (!isForce) {
            const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
            const confirmed = await new Promise(resolve => {
                rl.question(`\n⚠️  WARNING: This will DELETE ALL DATA in "${collectionName}".\n\nType the collection name to confirm: `, answer => {
                    rl.close();
                    resolve(answer.trim() === collectionName);
                });
            });

            if (!confirmed) {
                console.log('\n❌ Cancelled. No changes made.\n');
                return;
            }
        }
    }

    const result = await wipeCollection(collectionName, isPreview);

    console.log('\n' + '='.repeat(60));
    if (isPreview) {
        console.log(`💡 Run without --preview to actually delete the data.`);
    } else {
        console.log(`✅ Wipe complete! Deleted ${result.deleted} documents.`);
    }
    console.log('='.repeat(60) + '\n');
}

main().then(() => process.exit(0)).catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});
