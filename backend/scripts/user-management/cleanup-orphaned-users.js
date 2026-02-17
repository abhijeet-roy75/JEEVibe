/**
 * Cleanup Orphaned User Documents
 *
 * Deletes user documents that only have partial data (e.g., only fcm_token_updated_at)
 * These are typically leftover from testing or old code versions.
 *
 * A valid user document should have at least:
 * - phoneNumber field
 *
 * Usage:
 *   node scripts/cleanup-orphaned-users.js [--preview] [--force]
 *
 * Flags:
 *   --preview : Dry-run mode. Shows what would be deleted without making changes.
 *   --force   : Skips the interactive confirmation prompt.
 */

const { db, admin } = require('../src/config/firebase');
const readline = require('readline');

async function cleanupOrphanedUsers(options = {}) {
  const { isPreview = false, isForce = false } = options;

  try {
    console.log('🔍 Scanning users collection for orphaned documents...\n');

    // Get all user documents
    const usersSnapshot = await db.collection('users').get();
    const orphanedDocs = [];

    // Check each document
    for (const doc of usersSnapshot.docs) {
      const data = doc.data();

      // A valid user should have phoneNumber
      // Orphaned docs typically only have fcm_token_updated_at, auth.active_session, etc.
      if (!data.phoneNumber) {
        orphanedDocs.push({
          id: doc.id,
          fields: Object.keys(data)
        });
      }
    }

    if (orphanedDocs.length === 0) {
      console.log('✅ No orphaned user documents found. All user documents are valid.\n');
      return;
    }

    console.log(`Found ${orphanedDocs.length} orphaned user document(s):\n`);

    // Show details
    orphanedDocs.forEach((doc, index) => {
      console.log(`${index + 1}. User ID: ${doc.id}`);
      console.log(`   Fields: ${doc.fields.join(', ')}`);
      console.log('');
    });

    if (isPreview) {
      console.log('='.repeat(60));
      console.log('👀 PREVIEW MODE - No data will be deleted');
      console.log('='.repeat(60) + '\n');
      return;
    }

    // Confirmation prompt (unless --force)
    if (!isForce) {
      const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
      const confirmed = await new Promise(resolve => {
        rl.question(`\n⚠️  Are you sure you want to delete these ${orphanedDocs.length} orphaned user documents?\nType 'DELETE' to confirm: `, answer => {
          rl.close();
          resolve(answer.trim() === 'DELETE');
        });
      });

      if (!confirmed) {
        console.log('\n❌ Cleanup cancelled. No changes made.\n');
        return;
      }
    }

    // Delete orphaned documents
    console.log('\n🗑️  Deleting orphaned user documents...\n');

    let deletedCount = 0;
    for (const doc of orphanedDocs) {
      try {
        await db.collection('users').doc(doc.id).delete();
        console.log(`✓ Deleted: ${doc.id}`);
        deletedCount++;
      } catch (error) {
        console.error(`✗ Failed to delete ${doc.id}: ${error.message}`);
      }
    }

    console.log(`\n🎉 Cleanup complete! Deleted ${deletedCount} of ${orphanedDocs.length} orphaned documents.\n`);

  } catch (error) {
    console.error('\n❌ Error during cleanup:', error);
    process.exit(1);
  }
}

// Only run if called directly (not imported)
if (require.main === module) {
  const args = process.argv.slice(2);
  const options = {
    isPreview: args.includes('--preview'),
    isForce: args.includes('--force')
  };

  cleanupOrphanedUsers(options).then(() => process.exit(0));
}

module.exports = { cleanupOrphanedUsers };
