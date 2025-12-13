/**
 * Comprehensive Assessment & Theta Calculation Test
 * 
 * Tests assessment submission and validates theta calculations
 * 
 * Usage:
 *   TOKEN="your-firebase-token" node scripts/test-assessment-theta.js
 *   OR
 *   node scripts/test-assessment-theta.js --token="your-firebase-token"
 * 
 * Prerequisites:
 *   - Backend server running on localhost:3000
 *   - Valid Firebase ID token
 *   - Questions populated in Firestore
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');
const axios = require('axios');

const BASE_URL = process.env.TEST_API_URL || 'http://localhost:3000';

// Get token from command line or environment
const args = process.argv.slice(2);
let token = process.env.TOKEN;

// Parse command line arguments
for (const arg of args) {
  if (arg.startsWith('--token=')) {
    token = arg.split('=')[1];
  } else if (arg === '--help' || arg === '-h') {
    console.log(`
Usage:
  TOKEN="your-token" node scripts/test-assessment-theta.js
  node scripts/test-assessment-theta.js --token="your-token"

Options:
  --token=TOKEN    Firebase ID token (required)
  --help, -h       Show this help message
    `);
    process.exit(0);
  }
}

if (!token) {
  console.error('❌ Error: Firebase ID token required!');
  console.error('   Set TOKEN environment variable or use --token="your-token"');
  console.error('   Example: TOKEN="eyJ..." node scripts/test-assessment-theta.js');
  process.exit(1);
}

/**
 * Get questions from API
 */
async function getQuestions(token) {
  console.log('\n📋 Step 1: Fetching Assessment Questions');
  console.log('─'.repeat(60));
  
  try {
    const response = await axios.get(`${BASE_URL}/api/assessment/questions`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    
    if (!response.data.success || !response.data.questions) {
      throw new Error('Invalid response format');
    }
    
    const questions = response.data.questions;
    console.log(`✅ Retrieved ${questions.length} questions`);
    
    // Show sample
    if (questions.length > 0) {
      const sample = questions[0];
      console.log(`\n📝 Sample Question:`);
      console.log(`   ID: ${sample.question_id}`);
      console.log(`   Subject: ${sample.subject}`);
      console.log(`   Chapter: ${sample.chapter}`);
      console.log(`   Difficulty: ${sample.difficulty}`);
    }
    
    return questions;
  } catch (error) {
    console.error('❌ Error fetching questions:', error.response?.data || error.message);
    throw error;
  }
}

/**
 * Get correct answers from Firestore (for creating realistic test scenarios)
 */
async function getCorrectAnswers(questionIds) {
  console.log('\n🔍 Step 2: Fetching Correct Answers (for test scenarios)');
  console.log('─'.repeat(60));
  
  try {
    const questionRefs = questionIds.map(id => 
      db.collection('initial_assessment_questions').doc(id)
    );
    
    const questionDocs = await db.getAll(...questionRefs);
    const answerMap = new Map();
    
    questionDocs.forEach(doc => {
      if (doc.exists) {
        const data = doc.data();
        answerMap.set(doc.id, data.correct_answer);
      }
    });
    
    console.log(`✅ Retrieved ${answerMap.size} correct answers`);
    return answerMap;
  } catch (error) {
    console.error('❌ Error fetching correct answers:', error.message);
    throw error;
  }
}

/**
 * Create test responses with different accuracy scenarios
 */
function createTestResponses(questions, correctAnswers, accuracyLevel = 0.6) {
  console.log(`\n📝 Step 3: Creating Test Responses (${(accuracyLevel * 100).toFixed(0)}% accuracy)`);
  console.log('─'.repeat(60));
  
  const responses = [];
  let correctCount = 0;
  
  questions.forEach((question, index) => {
    const correctAnswer = correctAnswers.get(question.question_id);
    const shouldBeCorrect = Math.random() < accuracyLevel;
    const questionType = question.question_type || 'mcq_single';
    
    let studentAnswer;
    if (shouldBeCorrect && correctAnswer) {
      // Answer correctly
      studentAnswer = correctAnswer;
      correctCount++;
    } else {
      // Answer incorrectly
      if (questionType === 'numerical') {
        // For numerical questions, generate a wrong number
        const correctNum = parseFloat(correctAnswer);
        if (!isNaN(correctNum)) {
          // Generate a number that's different from correct answer
          const wrongNum = correctNum + (Math.random() > 0.5 ? 1 : -1) * (10 + Math.random() * 20);
          studentAnswer = wrongNum.toFixed(2);
        } else {
          // Fallback if correct answer isn't a number
          studentAnswer = (Math.random() * 100).toFixed(2);
        }
      } else {
        // For MCQ questions, pick a wrong option
        const options = question.options || ['A', 'B', 'C', 'D'];
        const wrongOptions = options.filter(opt => opt !== correctAnswer);
        studentAnswer = wrongOptions[Math.floor(Math.random() * wrongOptions.length)] || 'A';
      }
    }
    
    // Realistic time: 60-180 seconds per question
    const timeTaken = 60 + Math.floor(Math.random() * 120);
    
    responses.push({
      question_id: question.question_id,
      student_answer: studentAnswer,
      time_taken_seconds: timeTaken
    });
  });
  
  const actualAccuracy = correctCount / responses.length;
  console.log(`✅ Created ${responses.length} responses`);
  console.log(`   Expected accuracy: ${(accuracyLevel * 100).toFixed(1)}%`);
  console.log(`   Actual accuracy: ${(actualAccuracy * 100).toFixed(1)}% (${correctCount}/${responses.length} correct)`);
  
  return responses;
}

/**
 * Submit assessment
 */
async function submitAssessment(token, responses) {
  console.log('\n🚀 Step 4: Submitting Assessment');
  console.log('─'.repeat(60));
  
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
    
    if (!response.data.success) {
      throw new Error('Assessment submission failed');
    }
    
    console.log('✅ Assessment submitted successfully!');
    return response.data;
  } catch (error) {
    console.error('❌ Error submitting assessment:', error.response?.data || error.message);
    if (error.response?.status === 400) {
      console.error('   Details:', JSON.stringify(error.response.data.details, null, 2));
    }
    throw error;
  }
}

/**
 * Validate theta calculations
 */
function validateThetaCalculations(results) {
  console.log('\n✅ Step 5: Validating Theta Calculations');
  console.log('─'.repeat(60));
  
  const errors = [];
  const warnings = [];
  
  // Validate overall theta
  const overallTheta = results.overall_theta;
  if (overallTheta === undefined || overallTheta === null) {
    errors.push('Overall theta is missing');
  } else if (overallTheta < -3.0 || overallTheta > 3.0) {
    errors.push(`Overall theta out of bounds: ${overallTheta} (expected [-3.0, 3.0])`);
  } else {
    console.log(`✅ Overall theta: ${overallTheta.toFixed(3)} (within bounds)`);
  }
  
  // Validate overall percentile
  const overallPercentile = results.overall_percentile;
  if (overallPercentile === undefined || overallPercentile === null) {
    errors.push('Overall percentile is missing');
  } else if (overallPercentile < 0 || overallPercentile > 100) {
    errors.push(`Overall percentile out of bounds: ${overallPercentile} (expected [0, 100])`);
  } else {
    console.log(`✅ Overall percentile: ${overallPercentile.toFixed(2)}% (within bounds)`);
  }
  
  // Validate theta by chapter
  const thetaByChapter = results.theta_by_chapter || {};
  const chapters = Object.keys(thetaByChapter);
  
  if (chapters.length === 0) {
    errors.push('No chapter theta values found');
  } else {
    console.log(`✅ Found ${chapters.length} chapters with theta values`);
    
    chapters.forEach(chapterKey => {
      const chapterData = thetaByChapter[chapterKey];
      
      // Validate theta
      if (chapterData.theta === undefined || chapterData.theta === null) {
        errors.push(`Chapter ${chapterKey}: theta is missing`);
      } else if (chapterData.theta < -3.0 || chapterData.theta > 3.0) {
        errors.push(`Chapter ${chapterKey}: theta out of bounds: ${chapterData.theta}`);
      }
      
      // Validate percentile
      if (chapterData.percentile === undefined || chapterData.percentile === null) {
        errors.push(`Chapter ${chapterKey}: percentile is missing`);
      } else if (chapterData.percentile < 0 || chapterData.percentile > 100) {
        errors.push(`Chapter ${chapterKey}: percentile out of bounds: ${chapterData.percentile}`);
      }
      
      // Validate accuracy
      if (chapterData.accuracy === undefined || chapterData.accuracy === null) {
        errors.push(`Chapter ${chapterKey}: accuracy is missing`);
      } else if (chapterData.accuracy < 0 || chapterData.accuracy > 1) {
        errors.push(`Chapter ${chapterKey}: accuracy out of bounds: ${chapterData.accuracy}`);
      }
      
      // Validate attempts
      if (chapterData.attempts === undefined || chapterData.attempts === null) {
        errors.push(`Chapter ${chapterKey}: attempts is missing`);
      } else if (chapterData.attempts <= 0) {
        warnings.push(`Chapter ${chapterKey}: attempts is ${chapterData.attempts} (expected > 0)`);
      }
      
      // Validate SE
      if (chapterData.confidence_SE === undefined || chapterData.confidence_SE === null) {
        warnings.push(`Chapter ${chapterKey}: confidence_SE is missing`);
      } else if (chapterData.confidence_SE < 0.15 || chapterData.confidence_SE > 0.6) {
        warnings.push(`Chapter ${chapterKey}: confidence_SE out of typical range: ${chapterData.confidence_SE}`);
      }
    });
  }
  
  // Validate chapters explored/confident
  if (results.chapters_explored === undefined) {
    warnings.push('chapters_explored is missing');
  } else {
    console.log(`✅ Chapters explored: ${results.chapters_explored}`);
  }
  
  if (results.chapters_confident === undefined) {
    warnings.push('chapters_confident is missing');
  } else {
    console.log(`✅ Chapters confident: ${results.chapters_confident}`);
  }
  
  // Validate subject balance
  const subjectBalance = results.subject_balance || {};
  const subjects = Object.keys(subjectBalance);
  if (subjects.length === 0) {
    warnings.push('Subject balance is missing');
  } else {
    const total = subjects.reduce((sum, subj) => sum + (subjectBalance[subj] || 0), 0);
    if (Math.abs(total - 1.0) > 0.01) {
      warnings.push(`Subject balance doesn't sum to 1.0: ${total.toFixed(3)}`);
    } else {
      console.log(`✅ Subject balance: ${JSON.stringify(subjectBalance)}`);
    }
  }
  
  // Report results
  if (errors.length > 0) {
    console.error('\n❌ Validation Errors:');
    errors.forEach(err => console.error(`   - ${err}`));
  }
  
  if (warnings.length > 0) {
    console.warn('\n⚠️  Validation Warnings:');
    warnings.forEach(warn => console.warn(`   - ${warn}`));
  }
  
  if (errors.length === 0 && warnings.length === 0) {
    console.log('\n✅ All validations passed!');
  }
  
  return { errors, warnings };
}

/**
 * Display detailed results
 */
function displayResults(results) {
  console.log('\n📊 Assessment Results Summary');
  console.log('═'.repeat(60));
  
  console.log(`\n🎯 Overall Performance:`);
  console.log(`   Theta: ${results.overall_theta?.toFixed(3)}`);
  console.log(`   Percentile: ${results.overall_percentile?.toFixed(2)}%`);
  console.log(`   Chapters Explored: ${results.chapters_explored}`);
  console.log(`   Chapters Confident: ${results.chapters_confident}`);
  
  if (results.subject_balance) {
    console.log(`\n📚 Subject Distribution:`);
    Object.entries(results.subject_balance).forEach(([subject, proportion]) => {
      console.log(`   ${subject}: ${(proportion * 100).toFixed(1)}%`);
    });
  }
  
  if (results.theta_by_chapter) {
    console.log(`\n📈 Theta by Chapter (top 10):`);
    const chapters = Object.entries(results.theta_by_chapter)
      .sort((a, b) => b[1].theta - a[1].theta)
      .slice(0, 10);
    
    chapters.forEach(([chapterKey, data]) => {
      console.log(`   ${chapterKey}:`);
      console.log(`      Theta: ${data.theta?.toFixed(3)}`);
      console.log(`      Percentile: ${data.percentile?.toFixed(2)}%`);
      console.log(`      Accuracy: ${(data.accuracy * 100)?.toFixed(1)}%`);
      console.log(`      Attempts: ${data.attempts}`);
      console.log(`      SE: ${data.confidence_SE?.toFixed(3)}`);
    });
    
    if (Object.keys(results.theta_by_chapter).length > 10) {
      console.log(`   ... and ${Object.keys(results.theta_by_chapter).length - 10} more chapters`);
    }
  }
}

/**
 * Main test runner
 */
async function runTest() {
  console.log('🧪 Assessment & Theta Calculation Test');
  console.log('═'.repeat(60));
  console.log(`📍 Base URL: ${BASE_URL}`);
  console.log(`⏰ ${new Date().toISOString()}`);
  console.log(`🔑 Token: ${token.substring(0, 20)}...${token.substring(token.length - 10)}`);
  
  try {
    // Step 1: Get questions
    const questions = await getQuestions(token);
    
    // Step 2: Get correct answers (for realistic test)
    const questionIds = questions.map(q => q.question_id);
    const correctAnswers = await getCorrectAnswers(questionIds);
    
    // Step 3: Create test responses (60% accuracy scenario)
    const responses = createTestResponses(questions, correctAnswers, 0.6);
    
    // Step 4: Submit assessment
    const results = await submitAssessment(token, responses);
    
    // Step 5: Validate calculations
    const validation = validateThetaCalculations(results);
    
    // Step 6: Display results
    displayResults(results);
    
    // Final summary
    console.log('\n' + '═'.repeat(60));
    if (validation.errors.length === 0) {
      console.log('✅ Test completed successfully!');
      if (validation.warnings.length > 0) {
        console.log(`⚠️  ${validation.warnings.length} warning(s) - review above`);
      }
    } else {
      console.log(`❌ Test completed with ${validation.errors.length} error(s)`);
      process.exit(1);
    }
    
  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    if (error.stack) {
      console.error('\nStack trace:', error.stack);
    }
    process.exit(1);
  }
}

// Run test
if (require.main === module) {
  runTest().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { runTest };
