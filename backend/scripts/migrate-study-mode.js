/**
 * Study Mode Migration Script
 *
 * Migrates studyMode field to studySetup array format
 *
 * Changes:
 * - Renames: studyMode → studySetup
 * - Converts: String → Array<String>
 * - Maps old values to new multi-select format
 *
 * Mapping:
 * - "Self-study only" → ["Self-study"]
 * - "Coaching only" → ["Offline coaching"]
 * - "Coaching + Self-study" → ["Self-study", "Offline coaching"]
 * - "Online classes only" → ["Online coaching"]
 * - "Hybrid (Online + Offline)" → ["Online coaching", "Offline coaching"]
 * - null/undefined → [] (empty array)
 *
 * Usage:
 *   node scripts/migrate-study-mode.js [--preview] [--batch-size=500]
 */

const { db, admin } = require('../src/config/firebase');

// Mapping from old studyMode values to new studySetup arrays
const STUDY_MODE_MAPPING = {
  'Self-study only': ['Self-study'],
  'Coaching only': ['Offline coaching'],
  'Coaching + Self-study': ['Self-study', 'Offline coaching'],
  'Online classes only': ['Online coaching'],
  'Hybrid (Online + Offline)': ['Online coaching', 'Offline coaching']
};

/**
 * Convert studyMode string to studySetup array
 */
function convertStudyMode(studyMode) {
  if (!studyMode || studyMode === '') {
    return [];
  }

  // Check if it matches a known value
  if (STUDY_MODE_MAPPING[studyMode]) {
    return STUDY_MODE_MAPPING[studyMode];
  }

  // Fallback: try to infer from string content
  console.warn(`Unknown studyMode value: "${studyMode}", attempting to infer...`);

  const lower = studyMode.toLowerCase();
  const setup = [];

  if (lower.includes('self') || lower.includes('self-study')) {
    setup.push('Self-study');
  }
  if (lower.includes('online')) {
    setup.push('Online coaching');
  }
  if (lower.includes('offline') || lower.includes('coaching')) {
    setup.push('Offline coaching');
  }
  if (lower.includes('school')) {
    setup.push('School only');
  }

  // If we couldn't infer anything, return empty array
  return setup.length > 0 ? setup : [];
}

/**
 * Migrate users in batches
 */
async function migrateUsers(isPreview = false, batchSize = 500) {
  console.log('='.repeat(60));
  console.log('Study Mode → Study Setup Migration');
  console.log('='.repeat(60));
  console.log(`Mode: ${isPreview ? 'PREVIEW (dry-run)' : 'LIVE'}`);
  console.log(`Batch size: ${batchSize}`);
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
      withStudyMode: 0,
      withoutStudyMode: 0,
      alreadyMigrated: 0,
      toMigrate: 0,
      migrated: 0,
      errors: 0,
      mappings: {}
    };

    // Analyze what needs to be migrated
    const usersToMigrate = [];

    for (const doc of usersSnapshot.docs) {
      const data = doc.data();
      const userId = doc.id;

      // Check if already migrated (has studySetup array)
      if (data.studySetup && Array.isArray(data.studySetup)) {
        stats.alreadyMigrated++;
        continue;
      }

      // Check if has studyMode
      if (data.studyMode) {
        stats.withStudyMode++;
        const studySetup = convertStudyMode(data.studyMode);

        // Track mapping usage
        if (!stats.mappings[data.studyMode]) {
          stats.mappings[data.studyMode] = 0;
        }
        stats.mappings[data.studyMode]++;

        usersToMigrate.push({
          userId,
          oldValue: data.studyMode,
          newValue: studySetup
        });
      } else {
        stats.withoutStudyMode++;
        // Still migrate to set empty array
        usersToMigrate.push({
          userId,
          oldValue: null,
          newValue: []
        });
      }
    }

    stats.toMigrate = usersToMigrate.length;

    // Print analysis
    console.log('Analysis:');
    console.log(`  Total users:          ${stats.total}`);
    console.log(`  Already migrated:     ${stats.alreadyMigrated}`);
    console.log(`  With studyMode:       ${stats.withStudyMode}`);
    console.log(`  Without studyMode:    ${stats.withoutStudyMode}`);
    console.log(`  To migrate:           ${stats.toMigrate}`);
    console.log('');

    if (Object.keys(stats.mappings).length > 0) {
      console.log('studyMode value distribution:');
      for (const [oldValue, count] of Object.entries(stats.mappings)) {
        const newValue = STUDY_MODE_MAPPING[oldValue] || convertStudyMode(oldValue);
        console.log(`  "${oldValue}" → [${newValue.map(v => `"${v}"`).join(', ')}] (${count} users)`);
      }
      console.log('');
    }

    if (stats.toMigrate === 0) {
      console.log('✓ All users already migrated!');
      return;
    }

    if (isPreview) {
      console.log('[DRY RUN] Migration preview - no changes will be made');
      console.log('\nSample migrations (first 5):');
      for (const user of usersToMigrate.slice(0, 5)) {
        console.log(`  User ${user.userId}:`);
        console.log(`    studyMode: ${user.oldValue === null ? 'null' : `"${user.oldValue}"`}`);
        console.log(`    studySetup: [${user.newValue.map(v => `"${v}"`).join(', ')}]`);
      }
      if (usersToMigrate.length > 5) {
        console.log(`  ... and ${usersToMigrate.length - 5} more users`);
      }
      return;
    }

    // Execute migration in batches
    console.log(`Starting migration of ${stats.toMigrate} users...`);
    console.log('');

    let batch = db.batch();
    let batchCount = 0;
    let processedCount = 0;

    for (const user of usersToMigrate) {
      const userRef = db.collection('users').doc(user.userId);

      // Update: add studySetup, remove studyMode
      batch.update(userRef, {
        studySetup: user.newValue,
        studyMode: admin.firestore.FieldValue.delete()
      });

      batchCount++;
      processedCount++;

      // Commit batch when it reaches batchSize
      if (batchCount >= batchSize) {
        try {
          await batch.commit();
          console.log(`✓ Migrated batch (${processedCount}/${stats.toMigrate})`);
          batch = db.batch();
          batchCount = 0;
        } catch (error) {
          console.error(`✗ Error migrating batch at user ${processedCount}:`, error.message);
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
        console.log(`✓ Migrated final batch (${processedCount}/${stats.toMigrate})`);
      } catch (error) {
        console.error(`✗ Error migrating final batch:`, error.message);
        stats.errors++;
      }
    }

    stats.migrated = processedCount - stats.errors;

    console.log('');
    console.log('='.repeat(60));
    console.log('Migration Complete');
    console.log('='.repeat(60));
    console.log(`✓ Successfully migrated: ${stats.migrated} users`);
    if (stats.errors > 0) {
      console.log(`✗ Errors:                ${stats.errors} users`);
    }
    console.log('');

  } catch (error) {
    console.error('Fatal error during migration:', error);
    throw error;
  }
}

// Parse command line arguments
const args = process.argv.slice(2);
const isPreview = args.includes('--preview');
const batchSizeArg = args.find(arg => arg.startsWith('--batch-size='));
const batchSize = batchSizeArg ? parseInt(batchSizeArg.split('=')[1], 10) : 500;

// Run migration
migrateUsers(isPreview, batchSize)
  .then(() => {
    console.log('Migration script completed.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Migration script failed:', error);
    process.exit(1);
  });
