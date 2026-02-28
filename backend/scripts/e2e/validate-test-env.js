/**
 * Validate Test Environment Script
 *
 * Validates that the test environment is properly configured before running tests:
 * - Firebase credentials are valid
 * - Firestore is reachable
 * - Question bank has minimum required questions
 * - Assessment questions exist
 * - Mock test templates exist
 * - tier_config collection exists
 * - Test users exist in Firebase Auth and Firestore
 * - Firebase test phones are configured
 *
 * Usage: node scripts/validate-test-env.js
 */

const { admin, db } = require('../../src/config/firebase');
const logger = require('../../src/utils/logger');

// Test configuration
const REQUIRED_QUESTIONS = 500; // Minimum questions in question bank
const REQUIRED_ASSESSMENT_QUESTIONS = 30; // Minimum assessment questions
const REQUIRED_MOCK_TEMPLATES = 1; // Minimum mock test templates

// Test user IDs
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

// Test phone numbers
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

/**
 * Validation result
 */
const results = {
  passed: [],
  failed: [],
  warnings: []
};

/**
 * Log a passed check
 *
 * @param {string} message - Success message
 */
function pass(message) {
  results.passed.push(message);
  console.log(`✅ ${message}`);
}

/**
 * Log a failed check
 *
 * @param {string} message - Error message
 */
function fail(message) {
  results.failed.push(message);
  console.error(`❌ ${message}`);
}

/**
 * Log a warning
 *
 * @param {string} message - Warning message
 */
function warn(message) {
  results.warnings.push(message);
  console.warn(`⚠️  ${message}`);
}

/**
 * Check Firebase credentials
 */
async function checkFirebaseCredentials() {
  try {
    // Try to get app instance
    const app = admin.app();
    if (app) {
      pass('Firebase credentials are valid');
      return true;
    }
  } catch (error) {
    fail(`Firebase credentials invalid: ${error.message}`);
    return false;
  }
}

/**
 * Check Firestore connectivity
 */
async function checkFirestoreConnectivity() {
  try {
    // Try to read a document
    await db.collection('users').limit(1).get();
    pass('Firestore is reachable');
    return true;
  } catch (error) {
    fail(`Firestore unreachable: ${error.message}`);
    return false;
  }
}

/**
 * Check question bank size
 */
async function checkQuestionBank() {
  try {
    const snapshot = await db.collection('questions')
      .where('active', '==', true)
      .get();

    const count = snapshot.size;

    if (count >= REQUIRED_QUESTIONS) {
      pass(`Question bank has ${count} questions (required: ${REQUIRED_QUESTIONS})`);
      return true;
    } else {
      warn(`Question bank has only ${count} questions (recommended: ${REQUIRED_QUESTIONS}+)`);
      return true; // Warning, not failure
    }
  } catch (error) {
    fail(`Could not check question bank: ${error.message}`);
    return false;
  }
}

/**
 * Check assessment questions
 */
async function checkAssessmentQuestions() {
  try {
    const snapshot = await db.collection('questions')
      .where('active', '==', true)
      .limit(REQUIRED_ASSESSMENT_QUESTIONS)
      .get();

    const count = snapshot.size;

    if (count >= REQUIRED_ASSESSMENT_QUESTIONS) {
      pass(`Assessment has ${count}+ questions (required: ${REQUIRED_ASSESSMENT_QUESTIONS})`);
      return true;
    } else {
      fail(`Assessment has only ${count} questions (required: ${REQUIRED_ASSESSMENT_QUESTIONS})`);
      return false;
    }
  } catch (error) {
    fail(`Could not check assessment questions: ${error.message}`);
    return false;
  }
}

/**
 * Check mock test templates
 */
async function checkMockTestTemplates() {
  try {
    const snapshot = await db.collection('mock_test_templates')
      .where('active', '==', true)
      .get();

    const count = snapshot.size;

    if (count >= REQUIRED_MOCK_TEMPLATES) {
      pass(`Mock test templates: ${count} found (required: ${REQUIRED_MOCK_TEMPLATES})`);
      return true;
    } else {
      warn(`Mock test templates: only ${count} found (recommended: ${REQUIRED_MOCK_TEMPLATES}+)`);
      return true; // Warning, not failure (mock tests may not be ready yet)
    }
  } catch (error) {
    warn(`Could not check mock test templates: ${error.message}`);
    return true; // Warning, not failure
  }
}

/**
 * Check tier_config collection
 */
async function checkTierConfig() {
  try {
    const doc = await db.collection('tier_config').doc('active').get();

    if (doc.exists) {
      const data = doc.data();
      // Check both old structure (data.free) and new structure (data.tiers.free)
      const hasOldStructure = data && data.free && data.pro && data.ultra;
      const hasNewStructure = data && data.tiers && data.tiers.free && data.tiers.pro && data.tiers.ultra;

      if (hasOldStructure || hasNewStructure) {
        pass('tier_config collection exists with valid data');
        return true;
      } else {
        fail('tier_config exists but missing tier data');
        return false;
      }
    } else {
      fail('tier_config/active document does not exist');
      return false;
    }
  } catch (error) {
    fail(`Could not check tier_config: ${error.message}`);
    return false;
  }
}

/**
 * Check Firebase Auth test users
 */
async function checkAuthTestUsers() {
  try {
    let foundCount = 0;
    let missingUsers = [];

    for (const userId of TEST_USER_IDS) {
      try {
        await admin.auth().getUser(userId);
        foundCount++;
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
          missingUsers.push(userId);
        } else {
          throw error;
        }
      }
    }

    if (foundCount === TEST_USER_IDS.length) {
      pass(`All ${foundCount} test users exist in Firebase Auth`);
      return true;
    } else {
      fail(`Only ${foundCount}/${TEST_USER_IDS.length} test users in Firebase Auth. Missing: ${missingUsers.join(', ')}`);
      return false;
    }
  } catch (error) {
    fail(`Could not check Firebase Auth test users: ${error.message}`);
    return false;
  }
}

/**
 * Check Firestore test users
 */
async function checkFirestoreTestUsers() {
  try {
    let foundCount = 0;
    let missingUsers = [];

    for (const userId of TEST_USER_IDS) {
      const doc = await db.collection('users').doc(userId).get();

      if (doc.exists) {
        foundCount++;
      } else {
        missingUsers.push(userId);
      }
    }

    if (foundCount === TEST_USER_IDS.length) {
      pass(`All ${foundCount} test users exist in Firestore`);
      return true;
    } else {
      fail(`Only ${foundCount}/${TEST_USER_IDS.length} test users in Firestore. Missing: ${missingUsers.join(', ')}`);
      return false;
    }
  } catch (error) {
    fail(`Could not check Firestore test users: ${error.message}`);
    return false;
  }
}

/**
 * Check Firebase test phones
 *
 * Note: This cannot be checked programmatically via Admin SDK.
 * Test phones must be configured manually in Firebase Console.
 */
function checkTestPhones() {
  warn(`Firebase test phones must be verified manually in Firebase Console`);
  console.log(`   Expected test phones (${TEST_PHONES.length}):`);
  TEST_PHONES.forEach(phone => {
    console.log(`   - ${phone} (OTP: 123456)`);
  });
  console.log(`   Configure at: https://console.firebase.google.com/project/_/authentication/providers`);
  return true; // Warning only
}

/**
 * Check test fixtures exist
 */
async function checkTestFixtures() {
  const fs = require('fs');
  const path = require('path');

  const fixturesDir = path.join(__dirname, '../../tests/fixtures');
  const requiredFixtures = [
    'questions-100.json',
    'mock-test-template.json',
    'assessment-questions-30.json',
    'quiz-responses-valid.json',
    'quiz-responses-invalid.json',
    'user-theta-data.json',
    'weak-spot-event-log.json',
    'subscription-data.json'
  ];

  try {
    const missingFixtures = [];

    for (const fixture of requiredFixtures) {
      const fixturePath = path.join(fixturesDir, fixture);
      if (!fs.existsSync(fixturePath)) {
        missingFixtures.push(fixture);
      }
    }

    if (missingFixtures.length === 0) {
      pass(`All ${requiredFixtures.length} test fixtures exist`);
      return true;
    } else {
      fail(`Missing fixtures: ${missingFixtures.join(', ')}`);
      return false;
    }
  } catch (error) {
    fail(`Could not check test fixtures: ${error.message}`);
    return false;
  }
}

/**
 * Check test factories exist
 */
async function checkTestFactories() {
  const fs = require('fs');
  const path = require('path');

  const factoriesDir = path.join(__dirname, '../../tests/factories');
  const requiredFactories = [
    'userFactory.js',
    'questionFactory.js',
    'quizFactory.js',
    'mockTestFactory.js',
    'subscriptionFactory.js'
  ];

  try {
    const missingFactories = [];

    for (const factory of requiredFactories) {
      const factoryPath = path.join(factoriesDir, factory);
      if (!fs.existsSync(factoryPath)) {
        missingFactories.push(factory);
      }
    }

    if (missingFactories.length === 0) {
      pass(`All ${requiredFactories.length} test factories exist`);
      return true;
    } else {
      fail(`Missing factories: ${missingFactories.join(', ')}`);
      return false;
    }
  } catch (error) {
    fail(`Could not check test factories: ${error.message}`);
    return false;
  }
}

/**
 * Main validation
 */
async function validateTestEnvironment() {
  console.log('========================================');
  console.log('Validating Test Environment...');
  console.log('========================================\n');

  // Run all checks
  await checkFirebaseCredentials();
  await checkFirestoreConnectivity();
  await checkQuestionBank();
  await checkAssessmentQuestions();
  await checkMockTestTemplates();
  await checkTierConfig();
  await checkAuthTestUsers();
  await checkFirestoreTestUsers();
  checkTestPhones(); // Cannot check programmatically
  await checkTestFixtures();
  await checkTestFactories();

  // Print summary
  console.log('\n========================================');
  console.log('Validation Summary');
  console.log('========================================');
  console.log(`✅ Passed: ${results.passed.length}`);
  console.log(`⚠️  Warnings: ${results.warnings.length}`);
  console.log(`❌ Failed: ${results.failed.length}`);

  // Print warnings
  if (results.warnings.length > 0) {
    console.log('\n⚠️  Warnings:');
    results.warnings.forEach(warning => {
      console.log(`   - ${warning}`);
    });
  }

  // Print failures
  if (results.failed.length > 0) {
    console.log('\n❌ Failed Checks:');
    results.failed.forEach(failure => {
      console.log(`   - ${failure}`);
    });
    console.log('\n🔧 Fix these issues before running tests!');
    return false;
  }

  console.log('\n✅ Test environment is ready!');
  console.log('\n📝 Next steps:');
  console.log('   1. Run tests: npm test');
  console.log('   2. Reset test data: node scripts/e2e/reset-test-data.js');
  console.log('   3. Check test users: docs/05-testing/e2e/TESTING-USERS.md');

  return true;
}

// Run if executed directly
if (require.main === module) {
  validateTestEnvironment()
    .then((success) => {
      process.exit(success ? 0 : 1);
    })
    .catch((error) => {
      console.error('\n❌ Fatal error:', error);
      process.exit(1);
    });
}

module.exports = { validateTestEnvironment };
