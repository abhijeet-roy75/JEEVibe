/**
 * Migration Script: Add isEnrolledInCoaching field to existing users
 *
 * Sets isEnrolledInCoaching = true for all existing users who don't have this field.
 * This assumes that current users are enrolled in coaching classes.
 *
 * Usage:
 *   node scripts/migrate-add-coaching-enrollment.js [--dry-run]
 *
 * Options:
 *   --dry-run    Show what would be updated without making changes
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function migrateCoachingEnrollment() {
  const isDryRun = process.argv.includes('--dry-run');

  console.log('🔍 Starting migration: Add isEnrolledInCoaching to existing users');
  console.log(`Mode: ${isDryRun ? 'DRY RUN (no changes will be made)' : 'LIVE'}`);
  console.log('---');

  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();

    console.log(`📊 Total users found: ${usersSnapshot.size}`);

    let usersToUpdate = 0;
    let usersAlreadyHaveField = 0;
    let usersUpdated = 0;
    let errors = 0;

    // Batch updates for better performance
    const batchSize = 500;
    let batch = db.batch();
    let operationsInBatch = 0;

    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();

      // Check if user already has isEnrolledInCoaching field
      if (userData.isEnrolledInCoaching !== undefined && userData.isEnrolledInCoaching !== null) {
        usersAlreadyHaveField++;
        console.log(`✓ User ${doc.id} already has isEnrolledInCoaching: ${userData.isEnrolledInCoaching}`);
        continue;
      }

      // User needs the field
      usersToUpdate++;

      if (!isDryRun) {
        // Add to batch - set to true for existing users
        batch.update(doc.ref, { isEnrolledInCoaching: true });
        operationsInBatch++;

        // Commit batch if it reaches the limit
        if (operationsInBatch >= batchSize) {
          try {
            await batch.commit();
            usersUpdated += operationsInBatch;
            console.log(`✅ Committed batch of ${operationsInBatch} updates (Total: ${usersUpdated})`);

            // Start a new batch
            batch = db.batch();
            operationsInBatch = 0;
          } catch (error) {
            console.error(`❌ Error committing batch:`, error.message);
            errors++;
          }
        }
      } else {
        console.log(`[DRY RUN] Would update user ${doc.id} (phoneNumber: ${userData.phoneNumber || 'N/A'})`);
      }
    }

    // Commit remaining operations in the last batch
    if (!isDryRun && operationsInBatch > 0) {
      try {
        await batch.commit();
        usersUpdated += operationsInBatch;
        console.log(`✅ Committed final batch of ${operationsInBatch} updates`);
      } catch (error) {
        console.error(`❌ Error committing final batch:`, error.message);
        errors++;
      }
    }

    // Summary
    console.log('\n📋 Migration Summary:');
    console.log('---');
    console.log(`Total users: ${usersSnapshot.size}`);
    console.log(`Users already had isEnrolledInCoaching: ${usersAlreadyHaveField}`);
    console.log(`Users that needed update: ${usersToUpdate}`);

    if (isDryRun) {
      console.log(`[DRY RUN] Would have updated: ${usersToUpdate} users`);
      console.log('\n💡 Run without --dry-run to apply changes');
    } else {
      console.log(`Users successfully updated: ${usersUpdated}`);
      console.log(`Errors: ${errors}`);

      if (usersUpdated === usersToUpdate && errors === 0) {
        console.log('\n✅ Migration completed successfully!');
      } else {
        console.log('\n⚠️  Migration completed with some issues. Check logs above.');
      }
    }

  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    process.exit(1);
  }
}

// Run migration
migrateCoachingEnrollment()
  .then(() => {
    console.log('\n✨ Script finished');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Script crashed:', error);
    process.exit(1);
  });
