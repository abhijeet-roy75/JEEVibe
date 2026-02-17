/**
 * Cleanup All Users Script
 *
 * SYSTEMATICALLY DELETES ALL USER DATA from the system:
 * - All Firestore user documents and subcollections
 * - All Firebase Auth users
 * - All user-related Storage files
 *
 * This script iterates through all users and calls cleanup-user.js for each.
 *
 * Usage:
 *   # Preview what will be deleted (safe, no changes)
 *   node scripts/cleanup-all-users.js --preview
 *
 *   # Delete all users with confirmation
 *   node scripts/cleanup-all-users.js
 *
 *   # Force delete without confirmation (DANGEROUS)
 *   node scripts/cleanup-all-users.js --force
 *
 * WARNING: This is a DESTRUCTIVE operation that cannot be undone!
 */

const { db, admin } = require('../src/config/firebase');
const { cleanupUser } = require('./cleanup-user');
const readline = require('readline');

/**
 * Get all user IDs from both Firestore and Firebase Auth
 */
async function getAllUserIds() {
  const userIds = new Set();

  // Get users from Firestore
  console.log('   Scanning Firestore users collection...');
  const firestoreUsers = await db.collection('users').get();
  firestoreUsers.docs.forEach(doc => userIds.add(doc.id));
  console.log(`   Found ${firestoreUsers.size} users in Firestore`);

  // Get users from Firebase Auth
  console.log('   Scanning Firebase Auth...');
  let authCount = 0;
  let nextPageToken;

  do {
    const listResult = await admin.auth().listUsers(1000, nextPageToken);
    listResult.users.forEach(user => {
      userIds.add(user.uid);
      authCount++;
    });
    nextPageToken = listResult.pageToken;
  } while (nextPageToken);

  console.log(`   Found ${authCount} users in Firebase Auth`);
  console.log(`   Total unique users: ${userIds.size}`);

  return Array.from(userIds);
}

/**
 * Confirm bulk deletion
 */
async function confirmBulkDeletion(userCount) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise((resolve) => {
    console.log('\n' + '='.repeat(60));
    console.log('⚠️  EXTREME CAUTION: BULK USER DELETION');
    console.log('='.repeat(60));
    console.log(`You are about to PERMANENTLY delete ALL ${userCount} users.`);
    console.log('This includes:');
    console.log('  - All user profiles and preferences');
    console.log('  - All quiz responses and progress data');
    console.log('  - All theta/ability scores');
    console.log('  - All practice sessions and streaks');
    console.log('  - All snap history and images');
    console.log('  - All Firebase Auth accounts');
    console.log('='.repeat(60));

    rl.question(
      `\nType 'DELETE ALL USERS' to confirm (or anything else to cancel): `,
      (answer) => {
        rl.close();
        resolve(answer.trim() === 'DELETE ALL USERS');
      }
    );
  });
}

/**
 * Main function
 */
async function main() {
  try {
    console.log('🧹 Cleanup All Users Script\n');
    console.log('='.repeat(60));

    // Parse arguments
    const args = process.argv.slice(2);
    const isPreview = args.includes('--preview');
    const isForce = args.includes('--force');

    console.log(`Mode: ${isPreview ? 'PREVIEW (no changes)' : 'DELETE'}`);
    console.log('='.repeat(60));

    // Get all user IDs
    console.log('\n🔍 Discovering users...\n');
    const userIds = await getAllUserIds();

    if (userIds.length === 0) {
      console.log('\n✅ No users found in the system. Nothing to clean up.\n');
      return;
    }

    // Preview mode
    if (isPreview) {
      console.log('\n' + '='.repeat(60));
      console.log('👀 PREVIEW MODE - No data will be deleted');
      console.log('='.repeat(60));
      console.log(`\nWould delete ${userIds.length} users:\n`);

      // Show first 10 users
      const displayUsers = userIds.slice(0, 10);
      for (const userId of displayUsers) {
        console.log(`   - ${userId}`);
      }
      if (userIds.length > 10) {
        console.log(`   ... and ${userIds.length - 10} more`);
      }

      console.log('\n💡 To actually delete, run without --preview');
      console.log('💡 Use --force to skip confirmation prompt\n');
      return;
    }

    // Confirmation (unless --force)
    if (!isForce) {
      const confirmed = await confirmBulkDeletion(userIds.length);
      if (!confirmed) {
        console.log('\n❌ Bulk deletion cancelled. No changes made.\n');
        return;
      }
    }

    // Delete users one by one
    console.log('\n🗑️  Starting bulk user deletion...\n');

    let successCount = 0;
    let errorCount = 0;
    const errors = [];

    for (let i = 0; i < userIds.length; i++) {
      const userId = userIds[i];
      const progress = `[${i + 1}/${userIds.length}]`;

      try {
        console.log(`\n${progress} Cleaning up user: ${userId}`);
        await cleanupUser(userId, { isPreview: false, isForce: true });
        successCount++;
      } catch (error) {
        console.error(`${progress} ❌ Error cleaning up ${userId}: ${error.message}`);
        errorCount++;
        errors.push({ userId, error: error.message });
      }
    }

    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 Bulk Deletion Summary');
    console.log('='.repeat(60));
    console.log(`Total users processed: ${userIds.length}`);
    console.log(`Successfully deleted: ${successCount}`);
    console.log(`Errors: ${errorCount}`);

    if (errors.length > 0) {
      console.log('\n❌ Failed deletions:');
      for (const { userId, error } of errors) {
        console.log(`   - ${userId}: ${error}`);
      }
    }

    console.log('\n🎉 Bulk user cleanup complete!\n');

  } catch (error) {
    console.error('\n❌ Fatal error:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('💥 Script failed:', error);
      process.exit(1);
    });
}

module.exports = { getAllUserIds };
