/**
 * Test Multiple Assessment Scenarios
 * 
 * Runs assessment with different accuracy levels and compares results
 * 
 * Usage:
 *   TOKEN="your-firebase-token" node scripts/test-multiple-scenarios.js
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');
const axios = require('axios');

const BASE_URL = process.env.TEST_API_URL || 'http://localhost:3000';

// Get token from environment
const token = process.env.TOKEN;

if (!token) {
  console.error('❌ Error: Firebase ID token required!');
  console.error('   Set TOKEN environment variable');
  console.error('   Example: TOKEN="eyJ..." node scripts/test-multiple-scenarios.js');
  process.exit(1);
}

/**
 * Get questions from API
 */
async function getQuestions(token) {
  const response = await axios.get(`${BASE_URL}/api/assessment/questions`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  
  if (!response.data.success || !response.data.questions) {
    throw new Error('Invalid response format');
  }
  
  return response.data.questions;
}

/**
 * Get correct answers from Firestore
 */
async function getCorrectAnswers(questionIds) {
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
  
  return answerMap;
}

/**
 * Create test responses with specified accuracy
 */
function createTestResponses(questions, correctAnswers, accuracyLevel) {
  const responses = [];
  let correctCount = 0;
  
  questions.forEach((question) => {
    const correctAnswer = correctAnswers.get(question.question_id);
    const shouldBeCorrect = Math.random() < accuracyLevel;
    const questionType = question.question_type || 'mcq_single';
    
    let studentAnswer;
    if (shouldBeCorrect && correctAnswer) {
      studentAnswer = correctAnswer;
      correctCount++;
    } else {
      if (questionType === 'numerical') {
        const correctNum = parseFloat(correctAnswer);
        if (!isNaN(correctNum)) {
          const wrongNum = correctNum + (Math.random() > 0.5 ? 1 : -1) * (10 + Math.random() * 20);
          studentAnswer = wrongNum.toFixed(2);
        } else {
          studentAnswer = (Math.random() * 100).toFixed(2);
        }
      } else {
        const options = question.options || ['A', 'B', 'C', 'D'];
        const wrongOptions = options.filter(opt => opt !== correctAnswer);
        studentAnswer = wrongOptions[Math.floor(Math.random() * wrongOptions.length)] || 'A';
      }
    }
    
    const timeTaken = 60 + Math.floor(Math.random() * 120);
    
    responses.push({
      question_id: question.question_id,
      student_answer: studentAnswer,
      time_taken_seconds: timeTaken
    });
  });
  
  return { responses, actualAccuracy: correctCount / responses.length };
}

/**
 * Submit assessment
 */
async function submitAssessment(token, responses) {
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
  
  return response.data;
}

/**
 * Format chapter name for display
 */
function formatChapterName(chapterKey) {
  return chapterKey
    .replace(/^(physics|chemistry|mathematics)_/, '')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, l => l.toUpperCase());
}

/**
 * Display results for a scenario
 */
function displayScenarioResults(scenarioName, accuracy, results) {
  console.log(`\n${'═'.repeat(80)}`);
  console.log(`📊 SCENARIO: ${scenarioName} (Target: ${(accuracy * 100).toFixed(0)}% accuracy)`);
  console.log(`${'═'.repeat(80)}`);
  
  console.log(`\n🎯 Overall Performance:`);
  console.log(`   Theta: ${results.overall_theta?.toFixed(3)}`);
  console.log(`   Percentile: ${results.overall_percentile?.toFixed(2)}%`);
  console.log(`   Chapters Explored: ${results.chapters_explored}`);
  console.log(`   Chapters Confident: ${results.chapters_confident}`);
  
  // Subject-level theta
  if (results.theta_by_subject) {
    console.log(`\n📚 Subject-Level Theta:`);
    for (const [subject, data] of Object.entries(results.theta_by_subject)) {
      if (data.status === 'tested') {
        console.log(`   ${subject.toUpperCase()}:`);
        console.log(`      Theta: ${data.theta?.toFixed(3)}`);
        console.log(`      Percentile: ${data.percentile?.toFixed(2)}%`);
        console.log(`      Chapters Tested: ${data.chapters_tested}`);
        if (data.weak_chapters && data.weak_chapters.length > 0) {
          console.log(`      Weak Chapters: ${data.weak_chapters.map(c => formatChapterName(c)).join(', ')}`);
        }
        if (data.strong_chapters && data.strong_chapters.length > 0) {
          console.log(`      Strong Chapters: ${data.strong_chapters.map(c => formatChapterName(c)).join(', ')}`);
        }
      } else {
        console.log(`   ${subject.toUpperCase()}: ${data.message || 'Not tested'}`);
      }
    }
  }
  
  // Chapter-level theta (sorted by theta)
  if (results.theta_by_chapter) {
    const chapters = Object.entries(results.theta_by_chapter)
      .sort((a, b) => b[1].theta - a[1].theta);
    
    console.log(`\n📈 Chapter-Level Theta (sorted by performance):`);
    chapters.forEach(([chapterKey, data]) => {
      const chapterName = formatChapterName(chapterKey);
      const subject = chapterKey.startsWith('physics_') ? 'Physics' : 
                     chapterKey.startsWith('chemistry_') ? 'Chemistry' : 'Mathematics';
      
      console.log(`   ${subject} - ${chapterName}:`);
      console.log(`      Theta: ${data.theta?.toFixed(3)}`);
      console.log(`      Percentile: ${data.percentile?.toFixed(2)}%`);
      console.log(`      Accuracy: ${(data.accuracy * 100).toFixed(1)}%`);
      console.log(`      Attempts: ${data.attempts}`);
      console.log(`      SE: ${data.confidence_SE?.toFixed(3)}`);
    });
  }
}

/**
 * Run a single scenario
 */
async function runScenario(scenarioName, accuracyLevel) {
  try {
    console.log(`\n🔄 Running scenario: ${scenarioName}...`);
    
    // Get questions
    const questions = await getQuestions(token);
    
    // Get correct answers
    const questionIds = questions.map(q => q.question_id);
    const correctAnswers = await getCorrectAnswers(questionIds);
    
    // Create responses
    const { responses, actualAccuracy } = createTestResponses(questions, correctAnswers, accuracyLevel);
    console.log(`   Created responses with ${(actualAccuracy * 100).toFixed(1)}% actual accuracy`);
    
    // Submit assessment
    const results = await submitAssessment(token, responses);
    
    return { results, actualAccuracy };
  } catch (error) {
    if (error.response?.status === 400 && error.response?.data?.error?.includes('already completed')) {
      console.log(`   ⚠️  Assessment already completed for this user.`);
      console.log(`   💡 To run multiple scenarios, you need different Firebase users.`);
      console.log(`   💡 Alternative: Clear the assessment status in Firestore for this user.`);
      
      // Try to get existing results instead
      try {
        const userId = token.split('.')[1]; // Extract user ID from token (simplified)
        const response = await axios.get(
          `${BASE_URL}/api/assessment/results/${userId}`,
          { headers: { 'Authorization': `Bearer ${token}` } }
        );
        if (response.data.success) {
          console.log(`   📊 Using existing assessment results for comparison...`);
          return { 
            results: response.data, 
            actualAccuracy: null,
            note: 'Using existing results - accuracy unknown'
          };
        }
      } catch (e) {
        // Ignore errors fetching existing results
      }
      
      return null;
    }
    throw error;
  }
}

/**
 * Main function
 */
async function runAllScenarios() {
  console.log('🧪 Multiple Assessment Scenarios Test');
  console.log('═'.repeat(80));
  console.log(`📍 Base URL: ${BASE_URL}`);
  console.log(`⏰ ${new Date().toISOString()}`);
  
  const scenarios = [
    { name: 'High Performer', accuracy: 0.90 },
    { name: 'Average Student', accuracy: 0.75 },
    { name: 'Struggling Student', accuracy: 0.50 }
  ];
  
  const allResults = [];
  
  for (const scenario of scenarios) {
    try {
      const result = await runScenario(scenario.name, scenario.accuracy);
      if (result) {
        allResults.push({
          scenario: scenario.name,
          accuracy: scenario.accuracy,
          actualAccuracy: result.actualAccuracy,
          results: result.results
        });
        
        displayScenarioResults(scenario.name, scenario.accuracy, result.results);
      }
    } catch (error) {
      console.error(`\n❌ Error in scenario ${scenario.name}:`, error.message);
      if (error.response?.data) {
        console.error('   Details:', JSON.stringify(error.response.data, null, 2));
      }
    }
  }
  
  // Summary comparison
  if (allResults.length > 0) {
    console.log(`\n${'═'.repeat(80)}`);
    console.log('📊 SUMMARY COMPARISON');
    console.log(`${'═'.repeat(80)}`);
    
    console.log(`\nOverall Theta Comparison:`);
    allResults.forEach(r => {
      console.log(`   ${r.scenario.padEnd(20)} (${(r.actualAccuracy * 100).toFixed(1)}% accuracy): ` +
                  `Theta = ${r.results.overall_theta?.toFixed(3)}, ` +
                  `Percentile = ${r.results.overall_percentile?.toFixed(2)}%`);
    });
    
    console.log(`\nSubject-Level Theta Comparison:`);
    const subjects = ['physics', 'chemistry', 'mathematics'];
    subjects.forEach(subject => {
      console.log(`\n   ${subject.toUpperCase()}:`);
      allResults.forEach(r => {
        const subjectData = r.results.theta_by_subject?.[subject];
        if (subjectData && subjectData.status === 'tested') {
          console.log(`      ${r.scenario.padEnd(20)}: Theta = ${subjectData.theta?.toFixed(3)}, ` +
                      `Percentile = ${subjectData.percentile?.toFixed(2)}%`);
        }
      });
    });
  }
  
  console.log(`\n${'═'.repeat(80)}`);
  if (allResults.length === scenarios.length) {
    console.log('✅ All scenarios completed successfully!');
  } else {
    console.log(`⚠️  Completed ${allResults.length}/${scenarios.length} scenarios`);
  }
}

// Run
if (require.main === module) {
  runAllScenarios().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { runAllScenarios };
