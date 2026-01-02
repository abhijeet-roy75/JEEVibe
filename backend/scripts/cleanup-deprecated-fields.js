/**
 * Cleanup Deprecated User Profile Fields
 *
 * Removes deprecated fields from user documents after onboarding simplification:
 *
 * Fields to DELETE:
 * - dateOfBirth
 * - gender
 * - currentClass
 * - schoolName
 * - city
 * - coachingInstitute
 * - coachingBranch
 * - studyMode (replaced by studySetup array)
 * - preferredLanguage
 * - weakSubjects
 * - strongSubjects
 *
 * Usage:
 *   node scripts/cleanup-deprecated-fields.js [--preview] [--batch-size=500]
 *
 * Flags:
 *   --preview     : Dry-run mode. Shows what would be deleted without making changes.
 *   --batch-size  : Number of users to process per batch (default: 500)
 */

const { db, admin } = require('../src/config/firebase');

// Fields to remove
const DEPRECATED_FIELDS = [
  'dateOfBirth',
  'gender',
  'currentClass',
  'schoolName',
  'city',
  'coachingInstitute',
  'coachingBranch',
  'studyMode', // Replaced by studySetup
  'preferredLanguage',
  'weakSubjects',
  'strongSubjects',
];

/**
 * Cleanup deprecated fields from all users
 */
async function cleanupDeprecatedFields(isPreview = false, batchSize = 500) {
  console.log('='.repeat(60));
  console.log('Cleanup Deprecated User Profile Fields');
  console.log('='.repeat(60));
  console.log(`Mode: ${isPreview ? 'PREVIEW (dry-run)' : 'LIVE'}`);
  console.log(`Batch size: ${batchSize}`);
  console.log(`Fields to remove: ${DEPRECATED_FIELDS.length}`);
  DEPRECATED_FIELDS.forEach(field => console.log(`  - ${field}`));
  console.log('');

  try {
    // Fetch all users
    console.log('Fetching users from Firestore...');
    const usersSnapshot = await db.collection('users').get();

    if (usersSnapshot.empty) {
      console.log('No users found in database.');
      return;
    }

    console.log(`Found ${usersSnapshot.size} users\n`);

    // Statistics
    let stats = {
      total: usersSnapshot.size,
      withDeprecatedFields: 0,
      withoutDeprecatedFields: 0,
      fieldCounts: {},
      cleaned: 0,
      errors: 0,
    };

    // Initialize field counts
    DEPRECATED_FIELDS.forEach(field => {
      stats.fieldCounts[field] = 0;
    });

    // Analyze which users have deprecated fields
    const usersToClean = [];

    for (const doc of usersSnapshot.docs) {
      const data = doc.data();
      const userId = doc.id;

      // Check which deprecated fields exist
      const fieldsToRemove = [];
      for (const field of DEPRECATED_FIELDS) {
        if (data[field] !== undefined) {
          fieldsToRemove.push(field);
          stats.fieldCounts[field]++;
        }
      }

      if (fieldsToRemove.length > 0) {
        stats.withDeprecatedFields++;
        usersToClean.push({
          userId,
          fields: fieldsToRemove,
        });
      } else {
        stats.withoutDeprecatedFields++;
      }
    }

    // Print analysis
    console.log('Analysis:');
    console.log(`  Total users:                    ${stats.total}`);
    console.log(`  Users with deprecated fields:   ${stats.withDeprecatedFields}`);
    console.log(`  Users without deprecated fields: ${stats.withoutDeprecatedFields}`);
    console.log('');

    if (stats.withDeprecatedFields > 0) {
      console.log('Deprecated field usage:');
      for (const [field, count] of Object.entries(stats.fieldCounts)) {
        if (count > 0) {
          const percentage = ((count / stats.total) * 100).toFixed(1);
          console.log(`  ${field.padEnd(20)} : ${count.toString().padStart(4)} users (${percentage}%)`);
        }
      }
      console.log('');
    }

    if (usersToClean.length === 0) {
      console.log('✓ No deprecated fields found! All users are clean.');
      return;
    }

    if (isPreview) {
      console.log('[DRY RUN] Cleanup preview - no changes will be made');
      console.log('\nSample cleanup operations (first 5 users):');
      for (const user of usersToClean.slice(0, 5)) {
        console.log(`  User ${user.userId}:`);
        console.log(`    Will remove: ${user.fields.join(', ')}`);
      }
      if (usersToClean.length > 5) {
        console.log(`  ... and ${usersToClean.length - 5} more users`);
      }
      return;
    }

    // Execute cleanup in batches
    console.log(`Starting cleanup of ${usersToClean.length} users...`);
    console.log('');

    let batch = db.batch();
    let batchCount = 0;
    let processedCount = 0;

    for (const user of usersToClean) {
      const userRef = db.collection('users').doc(user.userId);

      // Build update object with FieldValue.delete() for each deprecated field
      const updateData = {};
      for (const field of user.fields) {
        updateData[field] = admin.firestore.FieldValue.delete();
      }

      batch.update(userRef, updateData);
      batchCount++;
      processedCount++;

      // Commit batch when it reaches batchSize
      if (batchCount >= batchSize) {
        try {
          await batch.commit();
          console.log(`✓ Cleaned batch (${processedCount}/${usersToClean.length})`);
          batch = db.batch();
          batchCount = 0;
        } catch (error) {
          console.error(`✗ Error cleaning batch at user ${processedCount}:`, error.message);
          stats.errors++;
          // Continue with new batch
          batch = db.batch();
          batchCount = 0;
        }
      }
    }

    // Commit remaining batch
    if (batchCount > 0) {
      try {
        await batch.commit();
        console.log(`✓ Cleaned final batch (${processedCount}/${usersToClean.length})`);
      } catch (error) {
        console.error(`✗ Error cleaning final batch:`, error.message);
        stats.errors++;
      }
    }

    stats.cleaned = processedCount - stats.errors;

    console.log('');
    console.log('='.repeat(60));
    console.log('Cleanup Complete');
    console.log('='.repeat(60));
    console.log(`✓ Successfully cleaned:  ${stats.cleaned} users`);
    if (stats.errors > 0) {
      console.log(`✗ Errors:                ${stats.errors} users`);
    }
    console.log('');

    // Verify cleanup (sample check)
    console.log('Verification: Checking 5 random users...');
    const randomUsers = usersToClean.slice(0, 5);
    let verified = 0;
    for (const user of randomUsers) {
      const userDoc = await db.collection('users').doc(user.userId).get();
      const data = userDoc.data();

      const remainingDeprecated = [];
      for (const field of DEPRECATED_FIELDS) {
        if (data && data[field] !== undefined) {
          remainingDeprecated.push(field);
        }
      }

      if (remainingDeprecated.length === 0) {
        verified++;
        console.log(`  ✓ User ${user.userId}: Clean`);
      } else {
        console.log(`  ✗ User ${user.userId}: Still has ${remainingDeprecated.join(', ')}`);
      }
    }
    console.log(`Verification: ${verified}/${randomUsers.length} users verified clean`);
    console.log('');

  } catch (error) {
    console.error('Fatal error during cleanup:', error);
    throw error;
  }
}

// Parse command line arguments
const args = process.argv.slice(2);
const isPreview = args.includes('--preview');
const batchSizeArg = args.find(arg => arg.startsWith('--batch-size='));
const batchSize = batchSizeArg ? parseInt(batchSizeArg.split('=')[1], 10) : 500;

// Run cleanup
cleanupDeprecatedFields(isPreview, batchSize)
  .then(() => {
    console.log('Cleanup script completed.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Cleanup script failed:', error);
    process.exit(1);
  });
