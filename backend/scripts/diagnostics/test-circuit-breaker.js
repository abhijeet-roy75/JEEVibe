/**
 * Circuit Breaker Test Script
 * 
 * Tests the circuit breaker mechanism that prevents student "death spirals"
 * by detecting consecutive failures and generating recovery quizzes.
 * 
 * Usage:
 *   TOKEN="your-firebase-token" node scripts/test-circuit-breaker.js
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

const token = process.env.TOKEN;

if (!token) {
  console.error('❌ Error: Firebase ID token required!');
  process.exit(1);
}

// Circuit Breaker Configuration (from algorithm spec)
const CIRCUIT_BREAKER_THRESHOLD = 5;           // Consecutive failures to trigger
const CIRCUIT_BREAKER_REALTIME_THRESHOLD = 3; // Failures in current quiz
const CIRCUIT_BREAKER_COOLDOWN = 2;            // Quizzes before re-checking

/**
 * Extract user ID from token
 */
function getUserIdFromToken(token) {
  try {
    const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
    return payload.user_id || payload.sub;
  } catch (e) {
    return null;
  }
}

/**
 * Check circuit breaker status
 * Returns: { shouldTrigger: boolean, consecutiveFailures: number, reason: string }
 */
async function checkCircuitBreaker(userId) {
  try {
    // Get last 10 responses (covers ~1 quiz)
    const responsesRef = db.collection('assessment_responses')
      .doc(userId)
      .collection('responses');
    
    const snapshot = await responsesRef
      .orderBy('answered_at', 'desc')
      .limit(10)
      .get();
    
    if (snapshot.empty) {
      return {
        shouldTrigger: false,
        consecutiveFailures: 0,
        reason: 'No responses found'
      };
    }
    
    const responses = [];
    snapshot.forEach(doc => {
      responses.push(doc.data());
    });
    
    if (responses.length < CIRCUIT_BREAKER_THRESHOLD) {
      return {
        shouldTrigger: false,
        consecutiveFailures: 0,
        reason: `Not enough responses (${responses.length} < ${CIRCUIT_BREAKER_THRESHOLD})`
      };
    }
    
    // Count consecutive failures from most recent
    let consecutiveFailures = 0;
    for (const response of responses) {
      if (response.is_correct === false) {
        consecutiveFailures++;
      } else {
        break; // Stop at first correct answer
      }
    }
    
    const shouldTrigger = consecutiveFailures >= CIRCUIT_BREAKER_THRESHOLD;
    
    return {
      shouldTrigger,
      consecutiveFailures,
      reason: shouldTrigger 
        ? `Circuit breaker triggered: ${consecutiveFailures} consecutive failures`
        : `No trigger: ${consecutiveFailures} consecutive failures (threshold: ${CIRCUIT_BREAKER_THRESHOLD})`,
      recentResponses: responses.slice(0, 5).map(r => ({
        question_id: r.question_id,
        is_correct: r.is_correct,
        answered_at: r.answered_at?.toDate?.() || r.answered_at
      }))
    };
  } catch (error) {
    console.error('Error checking circuit breaker:', error);
    throw error;
  }
}

/**
 * Simulate circuit breaker scenario by creating test responses
 */
async function simulateCircuitBreakerScenario(userId, scenarioName) {
  console.log(`\n${'═'.repeat(80)}`);
  console.log(`🧪 SIMULATING: ${scenarioName}`);
  console.log(`${'═'.repeat(80)}`);
  
  // Get questions to create realistic responses
  const questionsRef = db.collection('initial_assessment_questions');
  const snapshot = await questionsRef.limit(10).get();
  
  const questions = [];
  snapshot.forEach(doc => {
    questions.push({ question_id: doc.id, ...doc.data() });
  });
  
  if (questions.length === 0) {
    console.error('❌ No questions found in database');
    return;
  }
  
  console.log(`\n📝 Creating ${CIRCUIT_BREAKER_THRESHOLD} consecutive wrong answers...`);
  
  // Create responses with all wrong answers
  const responsesRef = db.collection('assessment_responses')
    .doc(userId)
    .collection('responses');
  
  const testResponses = [];
  for (let i = 0; i < CIRCUIT_BREAKER_THRESHOLD; i++) {
    const question = questions[i % questions.length];
    const correctAnswer = question.correct_answer;
    
    // Generate wrong answer
    let wrongAnswer;
    if (question.question_type === 'numerical') {
      const correctNum = parseFloat(correctAnswer);
      wrongAnswer = (correctNum + 10 + Math.random() * 20).toFixed(2);
    } else {
      const options = question.options || ['A', 'B', 'C', 'D'];
      const wrongOptions = options.filter(opt => opt !== correctAnswer);
      wrongAnswer = wrongOptions[0] || 'A';
    }
    
    const responseId = `test_cb_${scenarioName.toLowerCase().replace(/\s+/g, '_')}_${Date.now()}_${i}`;
    
    testResponses.push({
      response_id: responseId,
      student_id: userId,
      question_id: question.question_id,
      student_answer: wrongAnswer,
      correct_answer: correctAnswer,
      is_correct: false, // All wrong to trigger circuit breaker
      time_taken_seconds: 60 + Math.floor(Math.random() * 60),
      subject: question.subject,
      chapter: question.chapter,
      chapter_key: `${question.subject.toLowerCase()}_${question.chapter.toLowerCase().replace(/\s+/g, '_')}`,
      answered_at: new Date(Date.now() - (CIRCUIT_BREAKER_THRESHOLD - i) * 60000), // Staggered timestamps
      created_at: new Date()
    });
  }
  
  // Save test responses
  const batch = db.batch();
  testResponses.forEach(response => {
    const docRef = responsesRef.doc(response.response_id);
    batch.set(docRef, response);
  });
  
  await batch.commit();
  console.log(`✅ Created ${testResponses.length} test responses (all incorrect)`);
  
  // Wait a moment for Firestore to index
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // Check circuit breaker
  const result = await checkCircuitBreaker(userId);
  
  console.log(`\n🔍 Circuit Breaker Check Result:`);
  console.log(`   Status: ${result.shouldTrigger ? '🔴 TRIGGERED' : '🟢 Not Triggered'}`);
  console.log(`   Consecutive Failures: ${result.consecutiveFailures}`);
  console.log(`   Reason: ${result.reason}`);
  
  if (result.recentResponses && result.recentResponses.length > 0) {
    console.log(`\n📋 Recent Responses (last 5):`);
    result.recentResponses.forEach((r, idx) => {
      console.log(`   ${idx + 1}. Question ${r.question_id.substring(0, 20)}... : ${r.is_correct ? '✅ Correct' : '❌ Wrong'}`);
    });
  }
  
  return result;
}

/**
 * Generate recovery quiz structure (simulation)
 */
function generateRecoveryQuizStructure() {
  console.log(`\n🔄 Recovery Quiz Structure (when circuit breaker triggers):`);
  console.log(`   ──────────────────────────────────────────────────────────`);
  console.log(`   7 questions: EASY (difficulty b = 0.4 to 0.7)`);
  console.log(`     → Expected success rate: 75-85%`);
  console.log(`     → From weakest topics to prevent gap widening`);
  console.log(`   ──────────────────────────────────────────────────────────`);
  console.log(`   2 questions: MEDIUM (difficulty b = 0.8 to 1.1)`);
  console.log(`     → Expected success rate: 60-70%`);
  console.log(`     → Gentle challenge to rebuild confidence`);
  console.log(`   ──────────────────────────────────────────────────────────`);
  console.log(`   1 question: REVIEW (previously correct 7-14 days ago)`);
  console.log(`     → Expected success rate: ~90%`);
  console.log(`     → Psychological boost ("I know this!")`);
  console.log(`   ──────────────────────────────────────────────────────────`);
  console.log(`   Total: 10 questions`);
  console.log(`   Expected overall success: ~75-80%`);
}

/**
 * Clean up test responses
 */
async function cleanupTestResponses(userId, scenarioName) {
  try {
    const responsesRef = db.collection('assessment_responses')
      .doc(userId)
      .collection('responses');
    
    const prefix = `test_cb_${scenarioName.toLowerCase().replace(/\s+/g, '_')}_`;
    const snapshot = await responsesRef.get();
    
    const batch = db.batch();
    let count = 0;
    snapshot.forEach(doc => {
      if (doc.id.startsWith(prefix)) {
        batch.delete(doc.ref);
        count++;
      }
    });
    
    if (count > 0) {
      await batch.commit();
      console.log(`\n🧹 Cleaned up ${count} test responses`);
    }
  } catch (error) {
    console.warn('⚠️  Error cleaning up test responses:', error.message);
  }
}

/**
 * Test different circuit breaker scenarios
 */
async function testCircuitBreakerScenarios() {
  console.log('🧪 Circuit Breaker Test Suite');
  console.log('═'.repeat(80));
  console.log(`📍 Testing circuit breaker mechanism`);
  console.log(`⏰ ${new Date().toISOString()}`);
  console.log(`\n💡 Note: This test creates temporary responses to simulate scenarios`);
  
  const userId = getUserIdFromToken(token);
  if (!userId) {
    console.error('❌ Could not extract user ID from token');
    process.exit(1);
  }
  
  console.log(`\n👤 User ID: ${userId}`);
  
  // Scenario 1: Check current state
  console.log(`\n${'═'.repeat(80)}`);
  console.log('📊 SCENARIO 1: Check Current Circuit Breaker Status');
  console.log(`${'═'.repeat(80)}`);
  
  const currentStatus = await checkCircuitBreaker(userId);
  console.log(`\n🔍 Current Status:`);
  console.log(`   Status: ${currentStatus.shouldTrigger ? '🔴 TRIGGERED' : '🟢 Not Triggered'}`);
  console.log(`   Consecutive Failures: ${currentStatus.consecutiveFailures}`);
  console.log(`   Reason: ${currentStatus.reason}`);
  
  if (currentStatus.recentResponses && currentStatus.recentResponses.length > 0) {
    console.log(`\n📋 Recent Responses:`);
    currentStatus.recentResponses.forEach((r, idx) => {
      console.log(`   ${idx + 1}. ${r.is_correct ? '✅' : '❌'} Question: ${r.question_id.substring(0, 25)}...`);
    });
  }
  
  // Scenario 2: Simulate circuit breaker trigger
  console.log(`\n${'═'.repeat(80)}`);
  console.log('📊 SCENARIO 2: Simulate Circuit Breaker Trigger');
  console.log(`${'═'.repeat(80)}`);
  console.log(`\n💡 This will create ${CIRCUIT_BREAKER_THRESHOLD} consecutive wrong answers`);
  console.log(`   to test if the circuit breaker would trigger.`);
  
  const triggerResult = await simulateCircuitBreakerScenario(userId, 'Trigger Test');
  
  // Show recovery quiz structure
  if (triggerResult.shouldTrigger) {
    generateRecoveryQuizStructure();
  }
  
  // Cleanup scenario 2 before scenario 3
  await cleanupTestResponses(userId, 'Trigger Test');
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // Scenario 3: Test with fewer failures (should not trigger)
  console.log(`\n${'═'.repeat(80)}`);
  console.log('📊 SCENARIO 3: Test with 3 Failures (Below Threshold)');
  console.log(`${'═'.repeat(80)}`);
  console.log(`\n💡 This will create only 3 consecutive wrong answers`);
  console.log(`   (below the ${CIRCUIT_BREAKER_THRESHOLD} threshold)`);
  
  // Create only 3 wrong answers
  const questionsRef = db.collection('initial_assessment_questions');
  const snapshot = await questionsRef.limit(3).get();
  const questions = [];
  snapshot.forEach(doc => {
    questions.push({ question_id: doc.id, ...doc.data() });
  });
  
  const responsesRef = db.collection('assessment_responses')
    .doc(userId)
    .collection('responses');
  
  const batch = db.batch();
  for (let i = 0; i < 3; i++) {
    const question = questions[i];
    const correctAnswer = question.correct_answer;
    const wrongAnswer = question.question_type === 'numerical' 
      ? (parseFloat(correctAnswer) + 10).toFixed(2)
      : (question.options || ['A', 'B', 'C', 'D']).find(opt => opt !== correctAnswer) || 'A';
    
    const responseId = `test_cb_below_threshold_${Date.now()}_${i}`;
    const docRef = responsesRef.doc(responseId);
    batch.set(docRef, {
      response_id: responseId,
      student_id: userId,
      question_id: question.question_id,
      student_answer: wrongAnswer,
      correct_answer: correctAnswer,
      is_correct: false,
      time_taken_seconds: 60,
      subject: question.subject,
      chapter: question.chapter,
      chapter_key: `${question.subject.toLowerCase()}_${question.chapter.toLowerCase().replace(/\s+/g, '_')}`,
      answered_at: new Date(Date.now() - (3 - i) * 60000),
      created_at: new Date()
    });
  }
  await batch.commit();
  console.log(`✅ Created 3 test responses (all incorrect)`);
  
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  const belowThresholdResult = await checkCircuitBreaker(userId);
  console.log(`\n🔍 Circuit Breaker Check Result:`);
  console.log(`   Status: ${belowThresholdResult.shouldTrigger ? '🔴 TRIGGERED' : '🟢 Not Triggered'}`);
  console.log(`   Consecutive Failures: ${belowThresholdResult.consecutiveFailures}`);
  console.log(`   Reason: ${belowThresholdResult.reason}`);
  
  if (belowThresholdResult.consecutiveFailures < CIRCUIT_BREAKER_THRESHOLD) {
    console.log(`\n✅ Expected: Should NOT trigger (${belowThresholdResult.consecutiveFailures} failures < ${CIRCUIT_BREAKER_THRESHOLD})`);
    if (belowThresholdResult.shouldTrigger) {
      console.log(`   ⚠️  Unexpected: Circuit breaker triggered when it shouldn't have`);
    } else {
      console.log(`   ✅ Correct: Circuit breaker did not trigger`);
    }
  } else {
    console.log(`\n⚠️  Note: ${belowThresholdResult.consecutiveFailures} failures detected (may include previous test responses)`);
  }
  
  // Cleanup
  console.log(`\n${'═'.repeat(80)}`);
  console.log('🧹 Cleanup');
  console.log(`${'═'.repeat(80)}`);
  await cleanupTestResponses(userId, 'Below Threshold');
  
  // Summary
  console.log(`\n${'═'.repeat(80)}`);
  console.log('📊 TEST SUMMARY');
  console.log(`${'═'.repeat(80)}`);
  console.log(`\n✅ Circuit Breaker Logic Tested:`);
  console.log(`   1. Current Status: ${currentStatus.shouldTrigger ? '🔴 TRIGGERED' : '🟢 OK'}`);
  console.log(`   2. Trigger Simulation: ${triggerResult.shouldTrigger ? '✅ TRIGGERED (5 failures)' : '❌ Failed to trigger'}`);
  console.log(`   3. Below Threshold Test: ${belowThresholdResult.consecutiveFailures} consecutive failures detected`);
  
  if (belowThresholdResult.consecutiveFailures < CIRCUIT_BREAKER_THRESHOLD) {
    console.log(`      ${belowThresholdResult.shouldTrigger ? '⚠️  Unexpected trigger' : '✅ Correctly did not trigger'}`);
  } else {
    console.log(`      ℹ️  Triggered due to ${belowThresholdResult.consecutiveFailures} failures (includes previous responses)`);
  }
  
  console.log(`\n💡 Next Steps:`);
  console.log(`   - Implement circuit breaker check in quiz generation`);
  console.log(`   - Implement recovery quiz generation`);
  console.log(`   - Add circuit breaker analytics tracking`);
  console.log(`   - Test with real student data`);
  
  console.log(`\n${'═'.repeat(80)}`);
  console.log('✅ Circuit breaker test completed!');
}

// Run
if (require.main === module) {
  testCircuitBreakerScenarios().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { checkCircuitBreaker, testCircuitBreakerScenarios };
