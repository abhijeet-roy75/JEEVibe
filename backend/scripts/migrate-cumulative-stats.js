/**
 * Migration Script: Populate Cumulative Stats
 *
 * Populates the cumulative_stats field for all existing users by aggregating
 * their response history. This is a one-time migration for the Progress API
 * cost optimization.
 *
 * Usage:
 *   node scripts/migrate-cumulative-stats.js
 *
 * What it does:
 * - Reads all users from Firestore
 * - For each user, aggregates their quiz responses
 * - Calculates total_questions_correct and total_questions_attempted
 * - Updates user document with cumulative_stats field
 *
 * Estimated time: ~1-2 minutes for 100 users
 */

const { db, admin } = require('../src/config/firebase');
const logger = require('../src/utils/logger');

// ============================================================================
// MIGRATION LOGIC
// ============================================================================

/**
 * Calculate cumulative stats for a single user
 */
async function calculateUserCumulativeStats(userId) {
  try {
    const userRef = db.collection('users').doc(userId);

    // Get all quiz responses for this user (across all quizzes)
    const responsesRef = db
      .collection('users')
      .doc(userId)
      .collection('daily_quizzes');

    const quizzesSnapshot = await responsesRef.get();

    let totalCorrect = 0;
    let totalAttempted = 0;

    // Iterate through all quizzes
    for (const quizDoc of quizzesSnapshot.docs) {
      const quizData = quizDoc.data();

      // Only count completed quizzes
      if (quizData.status !== 'completed') {
        continue;
      }

      // Get responses for this quiz
      const quizResponsesRef = quizDoc.ref.collection('responses');
      const responsesSnapshot = await quizResponsesRef.get();

      responsesSnapshot.docs.forEach((responseDoc) => {
        const response = responseDoc.data();

        if (response.is_correct !== undefined) {
          totalAttempted++;
          if (response.is_correct) {
            totalCorrect++;
          }
        }
      });
    }

    // Calculate overall accuracy
    const overallAccuracy =
      totalAttempted > 0 ? totalCorrect / totalAttempted : 0;

    // Update user document with cumulative stats
    await userRef.update({
      cumulative_stats: {
        total_questions_correct: totalCorrect,
        total_questions_attempted: totalAttempted,
        overall_accuracy: Math.round(overallAccuracy * 1000) / 1000,
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
      },
    });

    logger.info('Migrated cumulative stats for user', {
      userId,
      totalCorrect,
      totalAttempted,
      overallAccuracy: Math.round(overallAccuracy * 1000) / 1000,
    });

    return {
      userId,
      totalCorrect,
      totalAttempted,
      overallAccuracy,
    };
  } catch (error) {
    logger.error('Error calculating cumulative stats for user', {
      userId,
      error: error.message,
      stack: error.stack,
    });
    throw error;
  }
}

/**
 * Migrate all users
 */
async function migrateAllUsers() {
  try {
    console.log('Starting cumulative stats migration...\n');

    // Get all users
    const usersRef = db.collection('users');
    const usersSnapshot = await usersRef.get();

    console.log(`Found ${usersSnapshot.size} users to migrate\n`);

    let successCount = 0;
    let errorCount = 0;
    const errors = [];

    // Process each user
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;

      try {
        const result = await calculateUserCumulativeStats(userId);

        successCount++;

        console.log(
          `✅ [${successCount}/${usersSnapshot.size}] User: ${userId} - Correct: ${result.totalCorrect}/${result.totalAttempted} (${Math.round(result.overallAccuracy * 100)}%)`
        );
      } catch (error) {
        errorCount++;
        errors.push({ userId, error: error.message });

        console.error(
          `❌ [${successCount + errorCount}/${usersSnapshot.size}] User: ${userId} - Error: ${error.message}`
        );
      }
    }

    // Summary
    console.log('\n' + '='.repeat(80));
    console.log('Migration Complete!\n');
    console.log(`Total users: ${usersSnapshot.size}`);
    console.log(`✅ Successful: ${successCount}`);
    console.log(`❌ Failed: ${errorCount}`);
    console.log('='.repeat(80) + '\n');

    if (errors.length > 0) {
      console.log('Errors:');
      errors.forEach(({ userId, error }) => {
        console.log(`  - ${userId}: ${error}`);
      });
      console.log('');
    }

    console.log('Next steps:');
    console.log('1. Verify cumulative_stats field in Firestore for sample users');
    console.log('2. Test Progress API endpoint (/api/progress/cumulative)');
    console.log(
      '3. Monitor Firestore usage to confirm 99.8% cost reduction\n'
    );

    return {
      total: usersSnapshot.size,
      successful: successCount,
      failed: errorCount,
      errors,
    };
  } catch (error) {
    console.error('Fatal error during migration:', error);
    throw error;
  }
}

// ============================================================================
// DRY RUN MODE
// ============================================================================

/**
 * Dry run - preview what would be migrated without writing
 */
async function dryRun() {
  try {
    console.log('DRY RUN MODE - No changes will be made\n');

    const usersRef = db.collection('users');
    const usersSnapshot = await usersRef.get();

    console.log(`Found ${usersSnapshot.size} users\n`);

    let totalCorrect = 0;
    let totalAttempted = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();

      // Check if already has cumulative_stats
      const hasCumulativeStats = userData.cumulative_stats !== undefined;

      console.log(
        `User: ${userId} - ${hasCumulativeStats ? '✓ Has cumulative_stats' : '✗ Missing cumulative_stats'}`
      );

      if (hasCumulativeStats) {
        const stats = userData.cumulative_stats;
        totalCorrect += stats.total_questions_correct || 0;
        totalAttempted += stats.total_questions_attempted || 0;
      }
    }

    console.log('\nSummary:');
    console.log(
      `Total questions across all users: ${totalCorrect}/${totalAttempted}`
    );
    console.log(
      `Overall accuracy: ${totalAttempted > 0 ? Math.round((totalCorrect / totalAttempted) * 100) : 0}%\n`
    );
  } catch (error) {
    console.error('Error during dry run:', error);
    throw error;
  }
}

// ============================================================================
// CLI ENTRY POINT
// ============================================================================

async function main() {
  const args = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');

  try {
    if (isDryRun) {
      await dryRun();
    } else {
      // Confirm before running
      console.log('⚠️  WARNING: This will modify user documents in Firestore');
      console.log(
        'Run with --dry-run flag to preview changes without writing\n'
      );

      if (process.env.NODE_ENV === 'production') {
        console.error('❌ Cannot run migration in production');
        console.error('Please run this script in staging first\n');
        process.exit(1);
      }

      console.log('Starting migration in 3 seconds...\n');
      await new Promise((resolve) => setTimeout(resolve, 3000));

      const result = await migrateAllUsers();

      if (result.failed > 0) {
        process.exit(1);
      }
    }

    process.exit(0);
  } catch (error) {
    console.error('Fatal error:', error);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

// ============================================================================
// EXPORTS (for testing)
// ============================================================================

module.exports = {
  calculateUserCumulativeStats,
  migrateAllUsers,
  dryRun,
};
