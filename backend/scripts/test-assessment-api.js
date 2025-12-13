/**
 * Test Assessment API Script
 * 
 * Tests all assessment endpoints with a test user token
 * 
 * Usage:
 *   node scripts/test-assessment-api.js
 * 
 * Prerequisites:
 *   - Backend server running on localhost:3000
 *   - Firebase Admin SDK configured
 *   - Questions populated in Firestore
 */

require('dotenv').config();
const { admin } = require('../src/config/firebase');
const axios = require('axios');

const BASE_URL = process.env.TEST_API_URL || 'http://localhost:3000';
const TEST_USER_EMAIL = 'test@jeevibe.com';
const TEST_USER_PASSWORD = 'TestPassword123!';

/**
 * Create or get a test user and generate an ID token
 */
async function getTestUserToken() {
  try {
    let user;
    
    // Try to get existing user
    try {
      user = await admin.auth().getUserByEmail(TEST_USER_EMAIL);
      console.log('✅ Found existing test user:', user.uid);
    } catch (error) {
      // User doesn't exist, create one
      console.log('📝 Creating new test user...');
      user = await admin.auth().createUser({
        email: TEST_USER_EMAIL,
        password: TEST_USER_PASSWORD,
        emailVerified: true,
        displayName: 'Test User'
      });
      console.log('✅ Created test user:', user.uid);
    }
    
    // Generate a custom token (for testing, we'll use Admin SDK to create ID token)
    // Note: In production, users get ID tokens from Firebase Auth client SDK
    // For testing, we can create a custom token and exchange it, or use Admin SDK
    // to create a token directly
    
    // Create custom token (can be exchanged for ID token via REST API)
    const customToken = await admin.auth().createCustomToken(user.uid);
    
    console.log('⚠️  Note: Custom token created. In real app, use Firebase Auth client SDK.');
    console.log('   For testing, you can use the custom token or get ID token from Flutter app.');
    console.log('   Custom token:', customToken.substring(0, 50) + '...');
    
    // Alternative: Use REST API to exchange custom token for ID token
    // This requires Firebase API key (not recommended for production testing)
    // For now, we'll use a simpler approach: create a test user document
    // and use Admin SDK to verify (bypassing token for testing)
    
    return { userId: user.uid, customToken };
  } catch (error) {
    console.error('❌ Error creating/getting test user:', error.message);
    throw error;
  }
}

/**
 * Test 1: Get Assessment Questions
 */
async function testGetQuestions(token) {
  console.log('\n🧪 Test 1: GET /api/assessment/questions');
  console.log('─'.repeat(50));
  
  try {
    const response = await axios.get(`${BASE_URL}/api/assessment/questions`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    
    console.log('✅ Status:', response.status);
    console.log('✅ Count:', response.data.count);
    console.log('✅ Questions returned:', response.data.questions?.length || 0);
    
    if (response.data.questions && response.data.questions.length > 0) {
      const firstQuestion = response.data.questions[0];
      console.log('\n📋 Sample Question:');
      console.log('   ID:', firstQuestion.question_id);
      console.log('   Subject:', firstQuestion.subject);
      console.log('   Chapter:', firstQuestion.chapter);
      console.log('   Has image:', !!firstQuestion.image_url);
      console.log('   Options:', firstQuestion.options?.length || 0);
      
      // Verify sensitive fields are removed
      if (firstQuestion.correct_answer || firstQuestion.solution_text) {
        console.log('⚠️  WARNING: Sensitive fields not removed!');
      } else {
        console.log('✅ Sensitive fields properly removed');
      }
    }
    
    return response.data.questions;
  } catch (error) {
    console.error('❌ Error:', error.response?.data || error.message);
    if (error.response?.status === 401) {
      console.error('   Authentication failed. Make sure token is valid.');
    }
    throw error;
  }
}

/**
 * Test 2: Submit Assessment (with sample responses)
 */
async function testSubmitAssessment(token, questions) {
  console.log('\n🧪 Test 2: POST /api/assessment/submit');
  console.log('─'.repeat(50));
  
  if (!questions || questions.length === 0) {
    console.log('⚠️  No questions available. Skipping submit test.');
    return null;
  }
  
  // Create sample responses (all correct answers for testing)
  // In real scenario, user would provide actual answers
  const responses = questions.map((q, index) => {
    // For testing, we'll use option A for all (may not be correct)
    // In real test, you'd need to know correct answers
    return {
      question_id: q.question_id,
      student_answer: 'A', // Placeholder - may be wrong
      time_taken_seconds: 60 + Math.floor(Math.random() * 120) // 60-180 seconds
    };
  });
  
  console.log(`📝 Submitting ${responses.length} responses...`);
  
  try {
    const response = await axios.post(
      `${BASE_URL}/api/assessment/submit`,
      { responses },
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      }
    );
    
    console.log('✅ Status:', response.status);
    console.log('✅ Assessment completed!');
    console.log('\n📊 Results:');
    console.log('   Overall Theta:', response.data.overall_theta?.toFixed(3));
    console.log('   Overall Percentile:', response.data.overall_percentile?.toFixed(2));
    console.log('   Chapters Explored:', response.data.chapters_explored);
    console.log('   Chapters Confident:', response.data.chapters_confident);
    
    if (response.data.theta_by_chapter) {
      const chapters = Object.keys(response.data.theta_by_chapter);
      console.log('\n📈 Theta by Chapter:');
      chapters.slice(0, 5).forEach(chapter => {
        const data = response.data.theta_by_chapter[chapter];
        console.log(`   ${chapter}:`);
        console.log(`      Theta: ${data.theta?.toFixed(3)}`);
        console.log(`      Percentile: ${data.percentile?.toFixed(2)}`);
        console.log(`      Accuracy: ${(data.accuracy * 100)?.toFixed(1)}%`);
        console.log(`      Attempts: ${data.attempts}`);
      });
      if (chapters.length > 5) {
        console.log(`   ... and ${chapters.length - 5} more chapters`);
      }
    }
    
    return response.data;
  } catch (error) {
    console.error('❌ Error:', error.response?.data || error.message);
    if (error.response?.status === 400) {
      console.error('   Validation error:', error.response.data.details);
    }
    throw error;
  }
}

/**
 * Test 3: Get Assessment Results
 */
async function testGetResults(token, userId) {
  console.log('\n🧪 Test 3: GET /api/assessment/results/:userId');
  console.log('─'.repeat(50));
  
  try {
    const response = await axios.get(
      `${BASE_URL}/api/assessment/results/${userId}`,
      {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      }
    );
    
    console.log('✅ Status:', response.status);
    console.log('✅ Results retrieved!');
    console.log('\n📊 Assessment Status:', response.data.assessment?.status);
    console.log('   Completed At:', response.data.assessment?.completed_at);
    console.log('   Overall Theta:', response.data.overall_theta?.toFixed(3));
    console.log('   Overall Percentile:', response.data.overall_percentile?.toFixed(2));
    
    return response.data;
  } catch (error) {
    if (error.response?.status === 400) {
      console.log('⚠️  Assessment not completed yet (this is OK if you skipped submit test)');
      console.log('   Status:', error.response.data.status);
    } else if (error.response?.status === 403) {
      console.error('❌ Forbidden: Cannot access other user\'s results');
    } else {
      console.error('❌ Error:', error.response?.data || error.message);
    }
    return null;
  }
}

/**
 * Test 4: Test Authentication (without token)
 */
async function testAuthentication() {
  console.log('\n🧪 Test 4: Authentication Check');
  console.log('─'.repeat(50));
  
  try {
    await axios.get(`${BASE_URL}/api/assessment/questions`);
    console.error('❌ Should have failed without token!');
  } catch (error) {
    if (error.response?.status === 401) {
      console.log('✅ Authentication required (401 Unauthorized)');
      console.log('   Error:', error.response.data.error);
    } else {
      console.error('❌ Unexpected error:', error.message);
    }
  }
}

/**
 * Main test runner
 */
async function runTests() {
  console.log('🚀 Starting Assessment API Tests');
  console.log('='.repeat(50));
  console.log(`📍 Base URL: ${BASE_URL}`);
  console.log(`⏰ ${new Date().toISOString()}`);
  
  try {
    // Get test user token
    const { userId, customToken } = await getTestUserToken();
    
    console.log('\n⚠️  IMPORTANT: For full testing, you need a Firebase ID token.');
    console.log('   Options:');
    console.log('   1. Use your Flutter app to get a real ID token');
    console.log('   2. Use Firebase Console to create a user and get token');
    console.log('   3. Use the custom token above with Firebase Auth REST API');
    console.log('\n   For now, we\'ll test with the custom token (may fail auth).');
    console.log('   You can also manually set TOKEN environment variable.\n');
    
    // Check if token is provided via environment
    const token = process.env.TOKEN || customToken;
    
    if (!token || token === customToken) {
      console.log('⚠️  Using custom token. Some tests may fail authentication.');
      console.log('   Set TOKEN environment variable with a valid Firebase ID token to test fully.\n');
    }
    
    // Run tests
    await testAuthentication();
    
    const questions = await testGetQuestions(token);
    const submitResult = await testSubmitAssessment(token, questions);
    
    if (submitResult) {
      await testGetResults(token, userId);
    } else {
      console.log('\n⚠️  Skipping results test (assessment not submitted)');
    }
    
    console.log('\n' + '='.repeat(50));
    console.log('✅ All tests completed!');
    console.log('\n💡 Next Steps:');
    console.log('   1. Get a real Firebase ID token from your Flutter app');
    console.log('   2. Set TOKEN environment variable: export TOKEN="your-token"');
    console.log('   3. Run this script again for full authentication testing');
    
  } catch (error) {
    console.error('\n❌ Test suite failed:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  runTests().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { runTests };
