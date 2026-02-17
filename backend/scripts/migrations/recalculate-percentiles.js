/**
 * Recalculate Percentiles for All Users
 *
 * This script recalculates overall_percentile for all users using the corrected
 * normal CDF formula instead of the broken exponential approximation.
 *
 * Usage:
 *   node scripts/recalculate-percentiles.js [--dry-run]
 *
 * Options:
 *   --dry-run    Show what would be changed without updating Firestore
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

/**
 * Standard normal cumulative distribution function (CDF)
 * Uses Abramowitz and Stegun approximation for accurate results
 *
 * @param {number} z - Standard normal variable
 * @returns {number} Probability [0, 1]
 */
function normalCDF(z) {
  // Approximation using erf with error < 1.5 × 10^-7
  const t = 1 / (1 + 0.2316419 * Math.abs(z));
  const d = 0.3989423 * Math.exp(-z * z / 2);
  const prob = d * t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
  return z > 0 ? 1 - prob : prob;
}

/**
 * Convert theta to percentile (CORRECTED formula)
 *
 * @param {number} theta - Theta value [-3, +3]
 * @returns {number} Percentile [0, 100]
 */
function thetaToPercentile(theta) {
  // Bound theta to valid range
  const boundedTheta = Math.max(-3, Math.min(3, theta));
  const percentile = normalCDF(boundedTheta) * 100;
  return Math.max(0, Math.min(100, Math.round(percentile * 100) / 100));
}

/**
 * OLD (broken) formula for comparison
 */
function oldThetaToPercentile(theta) {
  const z = Math.max(-3, Math.min(3, theta));
  const percentile = 50 + 50 * (1 - Math.exp(-0.5 * z * z)) * Math.sign(z);
  return Math.max(0, Math.min(100, Math.round(percentile * 100) / 100));
}

async function recalculatePercentiles(dryRun = false) {
  console.log('========================================');
  console.log('Recalculating User Percentiles');
  console.log('========================================');
  console.log(`Mode: ${dryRun ? 'DRY RUN (no changes)' : 'LIVE UPDATE'}`);
  console.log('');

  try {
    // Fetch all users
    console.log('Fetching all users...');
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.size} users\n`);

    let updatedCount = 0;
    let unchangedCount = 0;
    let errorCount = 0;
    const updates = [];

    // Process each user
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();

      try {
        // Get current theta and percentile
        const currentTheta = userData.overall_theta;
        const currentPercentile = userData.overall_percentile;

        // Skip users without theta
        if (currentTheta === undefined || currentTheta === null) {
          unchangedCount++;
          continue;
        }

        // Calculate correct percentile
        const correctPercentile = thetaToPercentile(currentTheta);
        const oldPercentile = oldThetaToPercentile(currentTheta);

        // Check if update is needed (allow 0.1% tolerance for rounding)
        const needsUpdate = Math.abs(correctPercentile - (currentPercentile || 0)) > 0.1;

        if (needsUpdate) {
          const change = correctPercentile - (currentPercentile || 0);
          updates.push({
            userId,
            phone: userData.phone || 'N/A',
            firstName: userData.firstName || userData.first_name || 'N/A',
            theta: currentTheta.toFixed(2),
            oldPercentile: (currentPercentile || 0).toFixed(2),
            newPercentile: correctPercentile.toFixed(2),
            change: (change >= 0 ? '+' : '') + change.toFixed(2),
            brokenFormula: oldPercentile.toFixed(2)
          });

          if (!dryRun) {
            // Update Firestore
            await db.collection('users').doc(userId).update({
              overall_percentile: correctPercentile
            });
          }

          updatedCount++;
        } else {
          unchangedCount++;
        }
      } catch (err) {
        console.error(`Error processing user ${userId}:`, err.message);
        errorCount++;
      }
    }

    // Display results
    console.log('========================================');
    console.log('Results Summary');
    console.log('========================================');
    console.log(`Total users:     ${usersSnapshot.size}`);
    console.log(`Updated:         ${updatedCount}`);
    console.log(`Unchanged:       ${unchangedCount}`);
    console.log(`Errors:          ${errorCount}`);
    console.log('');

    if (updates.length > 0) {
      console.log('========================================');
      console.log('Updated Users (showing all changes)');
      console.log('========================================');
      console.log('');
      console.log('Phone         | Name       | Theta  | Old%   | New%   | Change | Broken');
      console.log('--------------|------------|--------|--------|--------|--------|--------');

      updates.forEach(u => {
        console.log(
          `${u.phone.padEnd(13)} | ` +
          `${u.firstName.padEnd(10).substring(0, 10)} | ` +
          `${u.theta.padStart(6)} | ` +
          `${u.oldPercentile.padStart(6)} | ` +
          `${u.newPercentile.padStart(6)} | ` +
          `${u.change.padStart(6)} | ` +
          `${u.brokenFormula.padStart(6)}`
        );
      });
      console.log('');
      console.log('Note: "Broken" column shows what the old (incorrect) formula would give');
    }

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
recalculatePercentiles(dryRun);
