/**
 * Daily Quiz Generation Verifier
 * 
 * This script simulates the daily quiz generation logic for a specific user
 * and reports exactly why questions might be missing for specific chapters.
 * 
 * Usage: node scripts/verify_quiz_generation.js [userId]
 */

require('dotenv').config();
const { db, admin } = require('../src/config/firebase');
const { selectChaptersForExploration, selectChaptersForExploitation } = require('../src/services/dailyQuizService');
const { getDatabaseNames, initializeMappings } = require('../src/services/chapterMappingService');

async function verifyQuizGeneration(userId) {
  try {
    console.log('--- Daily Quiz Generation Verifier ---\n');

    // 0. Initialize Mappings
    const allMappings = await initializeMappings();
    console.log(`Step 0: Initialized ${allMappings.size} dynamic mappings.\n`);

    if (!userId) {
      console.log('No userId provided. Looking for a recent user who completed a quiz...');
      const recentQuiz = await db.collectionGroup('quizzes')
        .where('status', '==', 'completed')
        .orderBy('completed_at', 'desc')
        .limit(1)
        .get();

      if (recentQuiz.empty) {
        console.error('No recent users found. Please provide a userId as an argument.');
        process.exit(1);
      }
      userId = recentQuiz.docs[0].ref.parent.parent.id;
      console.log(`Using recent user: ${userId}\n`);
    }

    // 1. Fetch User Profile
    console.log(`Step 1: Fetching profile for user: ${userId}...`);
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.error(`User ${userId} not found.`);
      process.exit(1);
    }
    const userData = userDoc.data();
    const completedQuizCount = userData.completed_quiz_count || 0;
    const learningPhase = completedQuizCount < 14 ? 'exploration' : 'exploitation';
    const chapterThetas = userData.theta_by_chapter || {};

    console.log(`- Completed Quizzes: ${completedQuizCount}`);
    console.log(`- Learning Phase: ${learningPhase}`);
    console.log(`- Chapters with assessed theta: ${Object.keys(chapterThetas).length}\n`);

    // 2. Simulate Chapter Selection
    console.log('Step 2: Simulating Chapter Selection...');
    let selectedChapters = [];
    if (learningPhase === 'exploration') {
      selectedChapters = selectChaptersForExploration(chapterThetas, 7);
    } else {
      selectedChapters = selectChaptersForExploitation(chapterThetas, 6);
    }
    console.log(`- Selected Chapters (${selectedChapters.length}): ${JSON.stringify(selectedChapters)}\n`);

    // 3. Simulate Full Quiz Generation
    console.log('Step 3: Simulating Full Quiz Generation...');
    const { generateDailyQuiz } = require('../src/services/dailyQuizService');
    const quiz = await generateDailyQuiz(userId);

    console.log(`- Quiz ID: ${quiz.quiz_id}`);
    console.log(`- Questions: ${quiz.questions.length}`);
    let schemaErrors = 0;
    quiz.questions.forEach((q, i) => {
      const issues = [];
      if (!q.question_id) issues.push('missing question_id');
      if (!q.question_text) issues.push('missing question_text');
      if (!q.subject) issues.push('missing subject');
      if (!q.chapter) issues.push('missing chapter');

      const isNumerical = q.question_type === 'numerical';

      if (!isNumerical) {
        if (!Array.isArray(q.options)) {
          issues.push(`options is ${typeof q.options} (expected Array for MCQ)`);
        } else if (q.options.length === 0) {
          issues.push('options array is empty');
        } else {
          q.options.forEach((opt, oi) => {
            if (!opt.option_id) issues.push(`option[${oi}] missing option_id`);
            if (!opt.text) issues.push(`option[${oi}] missing text`);
          });
        }
      }

      if (issues.length > 0) {
        console.log(`  [!] Question ${i + 1} (${q.question_id}): ${issues.join(', ')}`);
        schemaErrors++;
      }

      // Debug: log types for first question
      if (i === 0) {
        console.log('\n--- Debug: First Question Types ---');
        ['question_id', 'subject', 'chapter', 'question_type', 'question_text', 'chapter_key', 'options'].forEach(key => {
          console.log(`${key}: ${typeof q[key]} (${q[key] === null ? 'null' : (q[key] === undefined ? 'undefined' : 'value present')})`);
        });
        if (q.options && q.options.length > 0) {
          console.log('--- Debug: First Option Types ---');
          ['option_id', 'text'].forEach(key => {
            console.log(`  ${key}: ${typeof q.options[0][key]} (${q.options[0][key] === null ? 'null' : (q.options[0][key] === undefined ? 'undefined' : 'value present')})`);
          });
        }
        console.log('--------------------------------\n');
      }
    });

    if (schemaErrors === 0) {
      console.log('✅ All generated questions passed schema validation.\n');
    } else {
      console.log(`❌ Found ${schemaErrors} questions with schema issues.\n`);
    }

    // 4. Summary
    console.log('--- Final Summary ---');
    if (schemaErrors > 0) {
      console.log('❌ ISSUE: Schema mismatch detected. Mobile app will likely crash.');
    } else if (quiz.questions.length === 0) {
      console.log('⚠️ WARNING: No questions were generated.');
    } else {
      console.log('✅ Success: Quiz generated with valid schema.');
    }

    process.exit(0);
  } catch (error) {
    console.error('Error running verifier:', error);
    process.exit(1);
  }
}

const targetUserId = process.argv[2];
verifyQuizGeneration(targetUserId);
