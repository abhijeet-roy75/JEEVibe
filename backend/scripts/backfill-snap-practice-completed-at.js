#!/usr/bin/env node
/**
 * Backfill completed_at Field for Snap Practice Sessions
 *
 * Adds completed_at = created_at for all snap practice sessions that are missing it.
 * This ensures they appear in weekly activity graphs.
 *
 * Usage:
 *   node scripts/backfill-snap-practice-completed-at.js --dry-run
 *   node scripts/backfill-snap-practice-completed-at.js
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

async function backfillCompletedAt(dryRun = false) {
  console.log('\n🔧 Backfilling completed_at for snap practice sessions');
  if (dryRun) {
    console.log('🧪 DRY RUN MODE - No changes will be made\n');
  } else {
    console.log('⚠️  LIVE MODE - Sessions will be updated\n');
  }

  console.log('📊 Scanning snap_practice_sessions collection...\n');

  // Get all users
  const usersSnapshot = await db.collection('users').select().get();
  console.log(`Found ${usersSnapshot.size} users\n`);

  let totalSessions = 0;
  let sessionsNeedingUpdate = 0;
  let updated = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;

    // Get all snap practice sessions for this user
    const sessionsSnapshot = await db
      .collection('snap_practice_sessions')
      .doc(userId)
      .collection('sessions')
      .get();

    if (sessionsSnapshot.empty) continue;

    totalSessions += sessionsSnapshot.size;

    // Find sessions missing completed_at
    const sessionsToUpdate = [];

    sessionsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (!data.completed_at && data.created_at) {
        sessionsToUpdate.push({
          id: doc.id,
          created_at: data.created_at
        });
      }
    });

    if (sessionsToUpdate.length === 0) continue;

    sessionsNeedingUpdate += sessionsToUpdate.length;

    console.log(`User ${userId}: ${sessionsToUpdate.length} sessions need update`);

    if (dryRun) continue;

    // Update sessions in batches
    const batchSize = 500;
    for (let i = 0; i < sessionsToUpdate.length; i += batchSize) {
      const batch = db.batch();
      const chunk = sessionsToUpdate.slice(i, i + batchSize);

      chunk.forEach(session => {
        const ref = db
          .collection('snap_practice_sessions')
          .doc(userId)
          .collection('sessions')
          .doc(session.id);

        batch.update(ref, {
          completed_at: session.created_at
        });
      });

      await batch.commit();
      updated += chunk.length;
    }
  }

  console.log('\n📊 Summary:');
  console.log(`  Total sessions: ${totalSessions}`);
  console.log(`  Sessions needing update: ${sessionsNeedingUpdate}`);

  if (dryRun) {
    console.log('\n💡 Run without --dry-run to update these sessions\n');
  } else {
    console.log(`  ✅ Updated: ${updated}\n`);
  }

  process.exit(0);
}

const dryRun = process.argv.includes('--dry-run');

backfillCompletedAt(dryRun).catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
