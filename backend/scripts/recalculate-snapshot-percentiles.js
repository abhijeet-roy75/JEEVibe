/**
 * Recalculate Percentiles in Theta Snapshots
 *
 * This script recalculates percentiles in all historical theta snapshots
 * using the corrected normal CDF formula.
 *
 * Usage:
 *   node scripts/recalculate-snapshot-percentiles.js [--dry-run]
 *
 * Options:
 *   --dry-run    Show what would be changed without updating Firestore
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

/**
 * Standard normal cumulative distribution function (CDF)
 */
function normalCDF(z) {
  const t = 1 / (1 + 0.2316419 * Math.abs(z));
  const d = 0.3989423 * Math.exp(-z * z / 2);
  const prob = d * t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
  return z > 0 ? 1 - prob : prob;
}

/**
 * Convert theta to percentile (CORRECTED formula)
 */
function thetaToPercentile(theta) {
  const boundedTheta = Math.max(-3, Math.min(3, theta));
  const percentile = normalCDF(boundedTheta) * 100;
  return Math.max(0, Math.min(100, Math.round(percentile * 100) / 100));
}

async function recalculateSnapshotPercentiles(dryRun = false) {
  console.log('========================================');
  console.log('Recalculating Snapshot Percentiles');
  console.log('========================================');
  console.log(`Mode: ${dryRun ? 'DRY RUN (no changes)' : 'LIVE UPDATE'}`);
  console.log('');

  try {
    // Get all users and check each for snapshots
    console.log('Fetching all users...');
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.size} users\n`);

    let totalSnapshots = 0;
    let updatedSnapshots = 0;
    let unchangedSnapshots = 0;
    let errorCount = 0;
    let usersWithSnapshots = 0;

    // Process each user
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;

      try {
        // Get all daily snapshots for this user
        const dailySnapshotsSnapshot = await db
          .collection('theta_snapshots')
          .doc(userId)
          .collection('daily')
          .get();

        if (dailySnapshotsSnapshot.size > 0) {
          usersWithSnapshots++;
          console.log(`User ${userId}: ${dailySnapshotsSnapshot.size} snapshots`);
        }

        // Process each daily snapshot
        for (const snapshotDoc of dailySnapshotsSnapshot.docs) {
          totalSnapshots++;
          const snapshotData = snapshotDoc.data();

          // Get theta value
          const theta = snapshotData.overall_theta;

          if (theta === undefined || theta === null) {
            unchangedSnapshots++;
            continue;
          }

          // Calculate correct percentile
          const correctPercentile = thetaToPercentile(theta);
          const currentPercentile = snapshotData.overall_percentile;

          // Check if update needed
          const needsUpdate = Math.abs(correctPercentile - (currentPercentile || 0)) > 0.1;

          if (needsUpdate) {
            if (!dryRun) {
              await snapshotDoc.ref.update({
                overall_percentile: correctPercentile
              });
            }
            updatedSnapshots++;
          } else {
            unchangedSnapshots++;
          }
        }
      } catch (err) {
        console.error(`Error processing snapshots for user ${userId}:`, err.message);
        errorCount++;
      }
    }

    console.log(`\nUsers with snapshots: ${usersWithSnapshots}`);

    // Display results
    console.log('');
    console.log('========================================');
    console.log('Results Summary');
    console.log('========================================');
    console.log(`Total snapshots: ${totalSnapshots}`);
    console.log(`Updated:         ${updatedSnapshots}`);
    console.log(`Unchanged:       ${unchangedSnapshots}`);
    console.log(`Errors:          ${errorCount}`);
    console.log('');

    if (dryRun) {
      console.log('========================================');
      console.log('DRY RUN COMPLETE - No changes made');
      console.log('Run without --dry-run to apply changes');
      console.log('========================================');
    } else {
      console.log('========================================');
      console.log('UPDATE COMPLETE');
      console.log('========================================');
    }

    process.exit(0);
  } catch (error) {
    console.error('Fatal error:', error);
    process.exit(1);
  }
}

// Parse command line arguments
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');

// Run the script
recalculateSnapshotPercentiles(dryRun);
