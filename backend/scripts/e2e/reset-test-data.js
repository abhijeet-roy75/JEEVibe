/**
 * Reset Test Data Script
 *
 * Resets all test user data to a clean state:
 * - Deletes all test user data from Firestore (daily_usage, quiz history, etc.)
 * - Keeps Firebase Auth accounts intact
 * - Recreates Firestore user documents with fresh data
 * - Resets daily usage counters
 *
 * Usage: node scripts/reset-test-data.js
 */

const { admin, db } = require('../../src/config/firebase');
const logger = require('../../src/utils/logger');

// Test user IDs (from setup-test-users.js)
const TEST_USER_IDS = [
  'test-user-free-001',
  'test-user-free-002',
  'test-user-free-003',
  'test-user-pro-001',
  'test-user-pro-002',
  'test-user-pro-003',
  'test-user-ultra-001',
  'test-user-ultra-002',
  'test-user-trial-active',
  'test-user-trial-expiring'
];

/**
 * Delete all subcollections for a user
 *
 * @param {string} userId - User ID
 */
async function deleteUserSubcollections(userId) {
  const subcollections = [
    'daily_usage',
    'daily_quizzes',
    'chapter_sessions',
    'assessments',
    'mock_test_sessions',
    'snap_history',
    'theta_snapshots'
  ];

  for (const subcollection of subcollections) {
    try {
      const snapshot = await db.collection('users')
        .doc(userId)
        .collection(subcollection)
        .get();

      const batch = db.batch();
      let count = 0;

      snapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
        count++;
      });

      if (count > 0) {
        await batch.commit();
        logger.info(`  Deleted ${count} documents from ${subcollection}`);
      }
    } catch (error) {
      logger.warn(`  Warning: Could not delete ${subcollection}: ${error.message}`);
    }
  }
}

/**
 * Delete user's main Firestore document
 *
 * @param {string} userId - User ID
 */
async function deleteUserDocument(userId) {
  try {
    await db.collection('users').doc(userId).delete();
    logger.info(`  Deleted user document`);
  } catch (error) {
    logger.error(`  Error deleting user document: ${error.message}`);
  }
}

/**
 * Recreate user document with fresh data
 *
 * @param {string} userId - User ID
 * @param {Object} userData - User data from setup-test-users.js
 */
async function recreateUserDocument(userId, userData) {
  try {
    await db.collection('users').doc(userId).set(userData);
    logger.info(`  Recreated user document`);
  } catch (error) {
    logger.error(`  Error recreating user document: ${error.message}`);
  }
}

/**
 * Generate fresh user data (same as setup-test-users.js)
 *
 * @param {string} userId - User ID
 * @returns {Object} User data
 */
function generateUserData(userId) {
  const userConfigs = {
    'test-user-free-001': {
      phone: '+16505551001',
      displayName: 'Test Free User 1',
      tier: 'free',
      hasProgress: false,
      coaching: false
    },
    'test-user-free-002': {
      phone: '+16505551002',
      displayName: 'Test Free User 2',
      tier: 'free',
      hasProgress: true,
      coaching: true,
      quizzesCompleted: 20,
      practiceCompleted: 10
    },
    'test-user-free-003': {
      phone: '+16505551003',
      displayName: 'Test Free User 3',
      tier: 'free',
      hasProgress: true,
      coaching: false,
      quizzesCompleted: 5,
      practiceCompleted: 3
    },
    'test-user-pro-001': {
      phone: '+16505551004',
      displayName: 'Test Pro User 1',
      tier: 'pro',
      hasProgress: false,
      coaching: false
    },
    'test-user-pro-002': {
      phone: '+16505551005',
      displayName: 'Test Pro User 2',
      tier: 'pro',
      hasProgress: true,
      coaching: true,
      quizzesCompleted: 50,
      practiceCompleted: 30
    },
    'test-user-pro-003': {
      phone: '+16505551006',
      displayName: 'Test Pro User 3',
      tier: 'pro',
      hasProgress: true,
      coaching: false,
      quizzesCompleted: 100,
      practiceCompleted: 60
    },
    'test-user-ultra-001': {
      phone: '+16505551007',
      displayName: 'Test Ultra User 1',
      tier: 'ultra',
      hasProgress: true,
      coaching: true,
      quizzesCompleted: 150,
      practiceCompleted: 80
    },
    'test-user-ultra-002': {
      phone: '+16505551008',
      displayName: 'Test Ultra User 2',
      tier: 'ultra',
      hasProgress: true,
      coaching: false,
      quizzesCompleted: 200,
      practiceCompleted: 100
    },
    'test-user-trial-active': {
      phone: '+16505551009',
      displayName: 'Test Trial Active',
      tier: 'trial',
      hasProgress: true,
      coaching: true,
      quizzesCompleted: 10,
      practiceCompleted: 5,
      trialDaysRemaining: 25
    },
    'test-user-trial-expiring': {
      phone: '+16505551010',
      displayName: 'Test Trial Expiring',
      tier: 'trial',
      hasProgress: true,
      coaching: false,
      quizzesCompleted: 30,
      practiceCompleted: 15,
      trialDaysRemaining: 1
    }
  };

  const config = userConfigs[userId];
  if (!config) {
    throw new Error(`Unknown test user ID: ${userId}`);
  }

  // Generate theta data
  const quizzesCompleted = config.quizzesCompleted || 0;
  const baseTheta = (quizzesCompleted / 200) - 0.5;
  const percentile = 50 + (baseTheta * 34);

  const thetaData = {
    overall_theta: Number(baseTheta.toFixed(2)),
    overall_percentile: Number(percentile.toFixed(1)),
    theta_by_subject: {
      physics: {
        theta: Number((baseTheta + Math.random() * 0.2 - 0.1).toFixed(2)),
        se: 0.3,
        questions_answered: Math.floor(quizzesCompleted * 1.5)
      },
      chemistry: {
        theta: Number((baseTheta + Math.random() * 0.2 - 0.1).toFixed(2)),
        se: 0.3,
        questions_answered: Math.floor(quizzesCompleted * 1.5)
      },
      mathematics: {
        theta: Number((baseTheta + Math.random() * 0.2 - 0.1).toFixed(2)),
        se: 0.3,
        questions_answered: Math.floor(quizzesCompleted * 1.5)
      }
    },
    theta_by_chapter: {
      physics_kinematics: { theta: Number((baseTheta + 0.1).toFixed(2)), se: 0.25, questions_answered: 10 },
      chemistry_atomic_structure: { theta: Number((baseTheta - 0.1).toFixed(2)), se: 0.28, questions_answered: 8 },
      mathematics_calculus: { theta: Number((baseTheta + 0.05).toFixed(2)), se: 0.26, questions_answered: 12 }
    }
  };

  // Build user data
  const userData = {
    phoneNumber: config.phone,
    displayName: config.displayName,
    isEnrolledInCoaching: config.coaching,
    subscriptionStatus: config.tier === 'trial' ? 'pro_trial' : config.tier,
    subscriptionTier: config.tier === 'trial' ? 'pro' : config.tier.charAt(0).toUpperCase() + config.tier.slice(1),
    subscription: {
      tier: config.tier === 'trial' ? 'pro' : config.tier,
      status: config.tier === 'trial' ? 'trial' : 'active',
      last_synced: admin.firestore.FieldValue.serverTimestamp()
    },
    ...thetaData,
    quizzes_completed: quizzesCompleted,
    chapter_practice_completed: config.practiceCompleted || 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  // Add trial data if applicable
  if (config.tier === 'trial') {
    const now = new Date();
    const trialEnd = new Date(now.getTime() + (config.trialDaysRemaining * 24 * 60 * 60 * 1000));
    const trialStart = new Date(now.getTime() - ((30 - config.trialDaysRemaining) * 24 * 60 * 60 * 1000));

    userData.trial = {
      ends_at: admin.firestore.Timestamp.fromDate(trialEnd),
      started_at: admin.firestore.Timestamp.fromDate(trialStart),
      is_active: true,
      tier_id: 'pro'
    };
    userData.trialEndsAt = admin.firestore.Timestamp.fromDate(trialEnd);
  }

  // Add override for Pro/Ultra users
  if (config.tier === 'pro' || config.tier === 'ultra') {
    const overrideEnd = new Date();
    overrideEnd.setDate(overrideEnd.getDate() + 90);

    userData.subscription.override = {
      type: 'testing',
      tier_id: config.tier,
      granted_by: 'reset-test-data-script',
      granted_at: admin.firestore.FieldValue.serverTimestamp(),
      expires_at: admin.firestore.Timestamp.fromDate(overrideEnd),
      reason: 'Test user reset'
    };
  }

  return userData;
}

/**
 * Reset a single test user
 *
 * @param {string} userId - User ID
 */
async function resetTestUser(userId) {
  console.log(`\n🔄 Resetting ${userId}...`);

  try {
    // Step 1: Delete all subcollections
    await deleteUserSubcollections(userId);

    // Step 2: Delete main user document
    await deleteUserDocument(userId);

    // Step 3: Recreate user document with fresh data
    const userData = generateUserData(userId);
    await recreateUserDocument(userId, userData);

    console.log(`✅ ${userId} reset successfully`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to reset ${userId}:`, error.message);
    return false;
  }
}

/**
 * Main execution
 */
async function resetAllTestData() {
  console.log('========================================');
  console.log('Resetting Test Data...');
  console.log('========================================');
  console.log(`Found ${TEST_USER_IDS.length} test users to reset\n`);

  let successCount = 0;
  let errorCount = 0;

  for (const userId of TEST_USER_IDS) {
    const success = await resetTestUser(userId);
    if (success) {
      successCount++;
    } else {
      errorCount++;
    }
  }

  console.log('\n========================================');
  console.log('Test Data Reset Complete!');
  console.log('========================================');
  console.log(`✅ Successful: ${successCount}/${TEST_USER_IDS.length}`);
  console.log(`❌ Failed: ${errorCount}/${TEST_USER_IDS.length}`);

  if (successCount === TEST_USER_IDS.length) {
    console.log('\n✨ All test data reset successfully!');
    console.log('\n📝 Test users are ready for testing:');
    TEST_USER_IDS.forEach(userId => {
      console.log(`  - ${userId}`);
    });
  } else {
    console.log('\n⚠️  Some test users failed to reset. Check errors above.');
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  resetAllTestData()
    .then(() => {
      console.log('\n✅ Done!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('\n❌ Fatal error:', error);
      process.exit(1);
    });
}

module.exports = { resetAllTestData, resetTestUser, generateUserData };
