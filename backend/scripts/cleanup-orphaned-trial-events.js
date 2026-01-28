/**
 * Cleanup Orphaned Trial Events
 *
 * Deletes trial_events documents for users that no longer exist in the users collection.
 * These are typically leftover from manual deletions or old cleanup scripts that didn't
 * include trial_events cleanup.
 *
 * Usage:
 *   node scripts/cleanup-orphaned-trial-events.js [--preview] [--force]
 *
 * Flags:
 *   --preview : Dry-run mode. Shows what would be deleted without making changes.
 *   --force   : Skips the interactive confirmation prompt.
 */

const { db } = require('../src/config/firebase');
const readline = require('readline');

async function cleanupOrphanedTrialEvents(options = {}) {
  const { isPreview = false, isForce = false } = options;

  try {
    console.log('🔍 Scanning trial_events collection for orphaned entries...\n');

    // Get all trial events
    const trialEventsSnapshot = await db.collection('trial_events').get();

    if (trialEventsSnapshot.empty) {
      console.log('✅ No trial events found.\n');
      return;
    }

    console.log(`Found ${trialEventsSnapshot.size} trial event(s). Checking for orphaned entries...\n`);

    // Get unique user IDs from trial events
    const userIdsInTrialEvents = new Set();
    trialEventsSnapshot.docs.forEach(doc => {
      const userId = doc.data().user_id;
      if (userId) {
        userIdsInTrialEvents.add(userId);
      }
    });

    console.log(`Found ${userIdsInTrialEvents.size} unique user(s) referenced in trial_events.\n`);

    // Check which users still exist
    const existingUserIds = new Set();
    const userCheckPromises = Array.from(userIdsInTrialEvents).map(async userId => {
      const userDoc = await db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        existingUserIds.add(userId);
      }
    });

    await Promise.all(userCheckPromises);

    console.log(`${existingUserIds.size} user(s) still exist in users collection.\n`);

    // Find orphaned trial events (user doesn't exist)
    const orphanedEvents = [];
    trialEventsSnapshot.docs.forEach(doc => {
      const userId = doc.data().user_id;
      if (userId && !existingUserIds.has(userId)) {
        orphanedEvents.push({
          id: doc.id,
          userId: userId,
          eventType: doc.data().event_type,
          timestamp: doc.data().timestamp?.toDate?.()
        });
      }
    });

    if (orphanedEvents.length === 0) {
      console.log('✅ No orphaned trial events found. All events reference existing users.\n');
      return;
    }

    console.log(`Found ${orphanedEvents.length} orphaned trial event(s):\n`);

    // Group by user ID for better display
    const eventsByUser = {};
    orphanedEvents.forEach(event => {
      if (!eventsByUser[event.userId]) {
        eventsByUser[event.userId] = [];
      }
      eventsByUser[event.userId].push(event);
    });

    // Show details
    Object.keys(eventsByUser).forEach((userId, index) => {
      const events = eventsByUser[userId];
      console.log(`${index + 1}. User ID: ${userId} (${events.length} event(s))`);
      events.forEach(event => {
        const timestamp = event.timestamp ? event.timestamp.toISOString() : 'N/A';
        console.log(`   - ${event.eventType} at ${timestamp}`);
      });
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
        rl.question(`\n⚠️  Are you sure you want to delete these ${orphanedEvents.length} orphaned trial events?\nType 'DELETE' to confirm: `, answer => {
          rl.close();
          resolve(answer.trim() === 'DELETE');
        });
      });

      if (!confirmed) {
        console.log('\n❌ Cleanup cancelled. No changes made.\n');
        return;
      }
    }

    // Delete orphaned events in batches
    console.log('\n🗑️  Deleting orphaned trial events...\n');

    let deletedCount = 0;
    const batchSize = 500;

    for (let i = 0; i < orphanedEvents.length; i += batchSize) {
      const batch = db.batch();
      const batchEvents = orphanedEvents.slice(i, i + batchSize);

      batchEvents.forEach(event => {
        batch.delete(db.collection('trial_events').doc(event.id));
      });

      try {
        await batch.commit();
        deletedCount += batchEvents.length;
        console.log(`✓ Deleted batch ${Math.floor(i / batchSize) + 1}: ${batchEvents.length} event(s)`);
      } catch (error) {
        console.error(`✗ Failed to delete batch: ${error.message}`);
      }
    }

    console.log(`\n🎉 Cleanup complete! Deleted ${deletedCount} of ${orphanedEvents.length} orphaned trial events.\n`);

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

  cleanupOrphanedTrialEvents(options).then(() => process.exit(0));
}

module.exports = { cleanupOrphanedTrialEvents };
