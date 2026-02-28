/**
 * Setup Test Users Script
 *
 * Creates 10 standard test users across all tiers for testing:
 * - 3 Free tier users
 * - 3 Pro tier users
 * - 2 Ultra tier users
 * - 2 Trial state users (active, expiring)
 *
 * Usage: node scripts/setup-test-users.js
 */

const { admin, db } = require('../../src/config/firebase');
const logger = require('../../src/utils/logger');

// Test user phone numbers (must be configured in Firebase Console as test phones)
const TEST_PHONES = [
  '+16505551001',
  '+16505551002',
  '+16505551003',
  '+16505551004',
  '+16505551005',
  '+16505551006',
  '+16505551007',
  '+16505551008',
  '+16505551009',
  '+16505551010'
];

// Test user configurations
const TEST_USERS = [
  // Free tier users (3)
  {
    userId: 'test-user-free-001',
    phone: TEST_PHONES[0],
    displayName: 'Test Free User 1',
    tier: 'free',
    hasProgress: false, // New user, no progress
    coaching: false
  },
  {
    userId: 'test-user-free-002',
    phone: TEST_PHONES[1],
    displayName: 'Test Free User 2',
    tier: 'free',
    hasProgress: true, // Active user with progress
    coaching: true,
    quizzesCompleted: 20,
    practiceCompleted: 10
  },
  {
    userId: 'test-user-free-003',
    phone: TEST_PHONES[2],
    displayName: 'Test Free User 3',
    tier: 'free',
    hasProgress: true,
    coaching: false,
    quizzesCompleted: 5,
    practiceCompleted: 3
  },

  // Pro tier users (3)
  {
    userId: 'test-user-pro-001',
    phone: TEST_PHONES[3],
    displayName: 'Test Pro User 1',
    tier: 'pro',
    hasProgress: false, // New Pro subscriber
    coaching: false
  },
  {
    userId: 'test-user-pro-002',
    phone: TEST_PHONES[4],
    displayName: 'Test Pro User 2',
    tier: 'pro',
    hasProgress: true,
    coaching: true,
    quizzesCompleted: 50,
    practiceCompleted: 30
  },
  {
    userId: 'test-user-pro-003',
    phone: TEST_PHONES[5],
    displayName: 'Test Pro User 3',
    tier: 'pro',
    hasProgress: true,
    coaching: false,
    quizzesCompleted: 100,
    practiceCompleted: 60
  },

  // Ultra tier users (2)
  {
    userId: 'test-user-ultra-001',
    phone: TEST_PHONES[6],
    displayName: 'Test Ultra User 1',
    tier: 'ultra',
    hasProgress: true,
    coaching: true,
    quizzesCompleted: 150,
    practiceCompleted: 80
  },
  {
    userId: 'test-user-ultra-002',
    phone: TEST_PHONES[7],
    displayName: 'Test Ultra User 2',
    tier: 'ultra',
    hasProgress: true,
    coaching: false,
    quizzesCompleted: 200,
    practiceCompleted: 100
  },

  // Trial users (2)
  {
    userId: 'test-user-trial-active',
    phone: TEST_PHONES[8],
    displayName: 'Test Trial Active',
    tier: 'trial',
    hasProgress: true,
    coaching: true,
    quizzesCompleted: 10,
    practiceCompleted: 5,
    trialDaysRemaining: 25 // 25 days left in trial
  },
  {
    userId: 'test-user-trial-expiring',
    phone: TEST_PHONES[9],
    displayName: 'Test Trial Expiring',
    tier: 'trial',
    hasProgress: true,
    coaching: false,
    quizzesCompleted: 30,
    practiceCompleted: 15,
    trialDaysRemaining: 1 // Trial expiring in 1 day
  }
];

/**
 * Generate sample theta data based on progress
 */
function generateThetaData(hasProgress, quizzesCompleted = 0) {
  if (!hasProgress) {
    return {
      overall_theta: 0.0,
      overall_percentile: 50.0,
      theta_by_subject: {
        physics: { theta: 0.0, se: 0.6, questions_answered: 0 },
        chemistry: { theta: 0.0, se: 0.6, questions_answered: 0 },
        mathematics: { theta: 0.0, se: 0.6, questions_answered: 0 }
      },
      theta_by_chapter: {}
    };
  }

  // Users with progress have varied theta values
  const baseTheta = (quizzesCompleted / 200) - 0.5; // Range: -0.5 to 0.5
  const percentile = 50 + (baseTheta * 34); // Normal distribution approximation

  return {
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
      // Add 2-3 sample chapters
      physics_kinematics: { theta: Number((baseTheta + 0.1).toFixed(2)), se: 0.25, questions_answered: 10 },
      chemistry_atomic_structure: { theta: Number((baseTheta - 0.1).toFixed(2)), se: 0.28, questions_answered: 8 },
      mathematics_calculus: { theta: Number((baseTheta + 0.05).toFixed(2)), se: 0.26, questions_answered: 12 }
    }
  };
}

/**
 * Create Firebase Auth user
 */
async function createAuthUser(userId, phone, displayName) {
  try {
    // Check if user already exists
    try {
      await admin.auth().getUser(userId);
      logger.info(`Auth user ${userId} already exists`);
      return;
    } catch (error) {
      if (error.code !== 'auth/user-not-found') {
        throw error;
      }
    }

    // Create new auth user
    await admin.auth().createUser({
      uid: userId,
      phoneNumber: phone,
      displayName: displayName
    });

    logger.info(`Created Firebase Auth user: ${userId} (${phone})`);
  } catch (error) {
    logger.error(`Error creating auth user ${userId}:`, error.message);
    throw error;
  }
}

/**
 * Create Firestore user document
 */
async function createFirestoreUser(userConfig) {
  const { userId, phone, displayName, tier, hasProgress, coaching, quizzesCompleted = 0, practiceCompleted = 0, trialDaysRemaining } = userConfig;

  try {
    const thetaData = generateThetaData(hasProgress, quizzesCompleted);

    // Calculate trial dates if applicable
    let trialData = null;
    if (tier === 'trial') {
      const now = new Date();
      const trialEnd = new Date(now.getTime() + (trialDaysRemaining * 24 * 60 * 60 * 1000));
      const trialStart = new Date(now.getTime() - ((30 - trialDaysRemaining) * 24 * 60 * 60 * 1000));

      trialData = {
        ends_at: admin.firestore.Timestamp.fromDate(trialEnd),
        started_at: admin.firestore.Timestamp.fromDate(trialStart),
        is_active: true,
        tier_id: 'pro'
      };
    }

    // Build user document
    const userData = {
      phoneNumber: phone,
      displayName: displayName,
      isEnrolledInCoaching: coaching,
      subscriptionStatus: tier === 'trial' ? 'pro_trial' : tier,
      subscriptionTier: tier === 'trial' ? 'pro' : tier.charAt(0).toUpperCase() + tier.slice(1),

      // Subscription object
      subscription: {
        tier: tier === 'trial' ? 'pro' : tier,
        status: tier === 'trial' ? 'trial' : 'active',
        last_synced: admin.firestore.FieldValue.serverTimestamp()
      },

      // Trial data (if applicable)
      ...(trialData && {
        trial: trialData,
        trialEndsAt: trialData.ends_at
      }),

      // Theta data
      ...thetaData,

      // Usage stats
      quizzes_completed: quizzesCompleted,
      chapter_practice_completed: practiceCompleted,

      // Timestamps
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Add override for Pro/Ultra users (for testing tier enforcement)
    if (tier === 'pro' || tier === 'ultra') {
      const overrideEnd = new Date();
      overrideEnd.setDate(overrideEnd.getDate() + 90); // 90 days from now

      userData.subscription.override = {
        type: 'testing',
        tier_id: tier,
        granted_by: 'setup-test-users-script',
        granted_at: admin.firestore.FieldValue.serverTimestamp(),
        expires_at: admin.firestore.Timestamp.fromDate(overrideEnd),
        reason: 'Test user for automated testing'
      };
    }

    // Write to Firestore
    await db.collection('users').doc(userId).set(userData);

    logger.info(`Created Firestore document for ${userId} (tier: ${tier}, progress: ${hasProgress})`);
  } catch (error) {
    logger.error(`Error creating Firestore user ${userId}:`, error.message);
    throw error;
  }
}

/**
 * Create daily usage document for users with progress
 */
async function createDailyUsage(userId, tier) {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const dateKey = today.toISOString().split('T')[0];

    const usageData = {
      date: admin.firestore.Timestamp.fromDate(today),
      snap_solve_count: tier === 'free' ? 2 : tier === 'pro' ? 5 : 10,
      daily_quiz_count: tier === 'free' ? 0 : tier === 'pro' ? 3 : 8,
      chapter_practice_count: tier === 'free' ? 2 : tier === 'pro' ? 5 : 10,
      last_updated: admin.firestore.FieldValue.serverTimestamp()
    };

    await db.collection('users')
      .doc(userId)
      .collection('daily_usage')
      .doc(dateKey)
      .set(usageData);

    logger.info(`Created daily usage for ${userId}`);
  } catch (error) {
    logger.error(`Error creating daily usage for ${userId}:`, error.message);
  }
}

/**
 * Main execution
 */
async function setupTestUsers() {
  console.log('========================================');
  console.log('Setting up test users...');
  console.log('========================================\n');

  let successCount = 0;
  let errorCount = 0;

  for (const userConfig of TEST_USERS) {
    try {
      console.log(`\nProcessing: ${userConfig.userId} (${userConfig.tier})...`);

      // Create Firebase Auth user
      await createAuthUser(userConfig.userId, userConfig.phone, userConfig.displayName);

      // Create Firestore user document
      await createFirestoreUser(userConfig);

      // Create daily usage if user has progress
      if (userConfig.hasProgress) {
        await createDailyUsage(userConfig.userId, userConfig.tier === 'trial' ? 'pro' : userConfig.tier);
      }

      successCount++;
      console.log(`✅ ${userConfig.userId} created successfully`);
    } catch (error) {
      errorCount++;
      console.error(`❌ Failed to create ${userConfig.userId}:`, error.message);
    }
  }

  console.log('\n========================================');
  console.log('Test User Setup Complete!');
  console.log('========================================');
  console.log(`✅ Successful: ${successCount}/${TEST_USERS.length}`);
  console.log(`❌ Failed: ${errorCount}/${TEST_USERS.length}`);

  if (successCount === TEST_USERS.length) {
    console.log('\n✨ All test users created successfully!');
    console.log('\nTest phone numbers (OTP: 123456):');
    TEST_USERS.forEach(u => {
      console.log(`  ${u.userId.padEnd(25)} ${u.phone} (${u.tier})`);
    });
  } else {
    console.log('\n⚠️  Some test users failed to create. Check errors above.');
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  setupTestUsers()
    .then(() => {
      console.log('\n✅ Done!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('\n❌ Fatal error:', error);
      process.exit(1);
    });
}

module.exports = { setupTestUsers, TEST_USERS, TEST_PHONES };
