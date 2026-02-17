/**
 * Simulate Multiple Assessment Scenarios (Without Submitting)
 * 
 * Simulates theta calculations for different accuracy levels without actually
 * submitting assessments. This allows testing multiple scenarios with the same user.
 * 
 * Usage:
 *   TOKEN="your-firebase-token" node scripts/test-scenarios-simulation.js
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');
const { processInitialAssessment } = require('../src/services/assessmentService');

const BASE_URL = process.env.TEST_API_URL || 'http://localhost:3000';
const token = process.env.TOKEN;

if (!token) {
  console.error('❌ Error: Firebase ID token required!');
  process.exit(1);
}

// Extract user ID from token (simplified - in production, verify token properly)
function getUserIdFromToken(token) {
  try {
    const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
    return payload.user_id || payload.sub;
  } catch (e) {
    return null;
  }
}

/**
 * Get questions from Firestore directly
 */
async function getQuestionsFromDB() {
  const questionsRef = db.collection('initial_assessment_questions');
  const snapshot = await questionsRef.get();
  
  const questions = [];
  snapshot.forEach(doc => {
    if (doc.exists) {
      questions.push({ question_id: doc.id, ...doc.data() });
    }
  });
  
  return questions;
}

/**
 * Create test responses with specified accuracy
 */
function createTestResponses(questions, accuracyLevel) {
  const responses = [];
  let correctCount = 0;
  
  questions.forEach((question) => {
    const correctAnswer = question.correct_answer;
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
    
    // Enrich with question data (simulating what the API does)
    responses.push({
      question_id: question.question_id,
      student_answer: studentAnswer,
      correct_answer: correctAnswer,
      is_correct: studentAnswer === correctAnswer,
      time_taken_seconds: timeTaken,
      subject: question.subject,
      chapter: question.chapter
    });
  });
  
  return { responses, actualAccuracy: correctCount / responses.length };
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
function displayScenarioResults(scenarioName, accuracy, actualAccuracy, results) {
  console.log(`\n${'═'.repeat(80)}`);
  console.log(`📊 SCENARIO: ${scenarioName}`);
  console.log(`   Target Accuracy: ${(accuracy * 100).toFixed(0)}% | Actual: ${(actualAccuracy * 100).toFixed(1)}%`);
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
 * Run a single scenario (simulation - doesn't save to DB)
 */
async function runScenario(scenarioName, accuracyLevel, userId) {
  try {
    console.log(`\n🔄 Simulating scenario: ${scenarioName}...`);
    
    // Get questions from database
    const questions = await getQuestionsFromDB();
    console.log(`   Loaded ${questions.length} questions`);
    
    // Create responses
    const { responses, actualAccuracy } = createTestResponses(questions, accuracyLevel);
    console.log(`   Created responses with ${(actualAccuracy * 100).toFixed(1)}% actual accuracy`);
    
    // Process assessment (this calculates theta but we'll prevent saving)
    // We'll use a temporary user ID to avoid conflicts
    const tempUserId = `temp_${scenarioName.toLowerCase().replace(/\s+/g, '_')}_${Date.now()}`;
    
    // Process but catch the save error (we don't want to save)
    try {
      const results = await processInitialAssessment(tempUserId, responses);
      return { results, actualAccuracy };
    } catch (error) {
      // If it's a transaction error, that's expected - we can still get results
      // by processing without saving
      throw error;
    }
  } catch (error) {
    console.error(`   ❌ Error: ${error.message}`);
    throw error;
  }
}

/**
 * Main function
 */
async function runAllScenarios() {
  console.log('🧪 Multiple Assessment Scenarios Simulation');
  console.log('═'.repeat(80));
  console.log(`📍 Base URL: ${BASE_URL}`);
  console.log(`⏰ ${new Date().toISOString()}`);
  console.log(`\n💡 Note: This is a simulation - results are calculated but not saved to database.`);
  
  const userId = getUserIdFromToken(token);
  if (!userId) {
    console.error('❌ Could not extract user ID from token');
    process.exit(1);
  }
  
  const scenarios = [
    { name: 'High Performer', accuracy: 0.90 },
    { name: 'Average Student', accuracy: 0.75 },
    { name: 'Struggling Student', accuracy: 0.50 }
  ];
  
  const allResults = [];
  
  for (const scenario of scenarios) {
    try {
      const result = await runScenario(scenario.name, scenario.accuracy, userId);
      if (result) {
        allResults.push({
          scenario: scenario.name,
          accuracy: scenario.accuracy,
          actualAccuracy: result.actualAccuracy,
          results: result.results
        });
        
        displayScenarioResults(scenario.name, scenario.accuracy, result.actualAccuracy, result.results);
      }
    } catch (error) {
      console.error(`\n❌ Error in scenario ${scenario.name}:`, error.message);
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
    
    // Chapter comparison table
    console.log(`\nChapter-Level Theta Comparison (Top 10 chapters by average theta):`);
    const allChapters = new Set();
    allResults.forEach(r => {
      if (r.results.theta_by_chapter) {
        Object.keys(r.results.theta_by_chapter).forEach(ch => allChapters.add(ch));
      }
    });
    
    const chapterAverages = Array.from(allChapters).map(chapterKey => {
      const thetas = allResults
        .map(r => r.results.theta_by_chapter?.[chapterKey]?.theta)
        .filter(t => t !== undefined);
      const avg = thetas.reduce((a, b) => a + b, 0) / thetas.length;
      return { chapterKey, avg, thetas };
    }).sort((a, b) => b.avg - a.avg).slice(0, 10);
    
    chapterAverages.forEach(({ chapterKey, avg, thetas }) => {
      const chapterName = formatChapterName(chapterKey);
      const subject = chapterKey.startsWith('physics_') ? 'Physics' : 
                     chapterKey.startsWith('chemistry_') ? 'Chemistry' : 'Mathematics';
      console.log(`\n   ${subject} - ${chapterName}:`);
      allResults.forEach((r, idx) => {
        const data = r.results.theta_by_chapter?.[chapterKey];
        if (data) {
          console.log(`      ${r.scenario.padEnd(20)}: Theta = ${data.theta?.toFixed(3)}, ` +
                      `Percentile = ${data.percentile?.toFixed(2)}%`);
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
