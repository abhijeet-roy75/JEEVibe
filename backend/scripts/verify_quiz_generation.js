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

    // 3. Check Question Bank for Selected Chapters
    console.log('Step 3: Checking Question Bank Density...');
    const findings = [];

    for (const chapterKey of selectedChapters) {
      const mapping = await getDatabaseNames(chapterKey);
      let subject, chapterName;

      if (mapping) {
        subject = mapping.subject;
        chapterName = mapping.chapter;
        console.log(`  - [FOUND MAPPING] ${chapterKey} -> [${subject}] ${chapterName}`);
      } else {
        const parts = chapterKey.split('_');
        subject = parts[0].charAt(0).toUpperCase() + parts[0].slice(1).toLowerCase();
        chapterName = parts.slice(1).join(' ').replace(/_/g, ' ');
        console.log(`  - [NO MAPPING] ${chapterKey} -> falling back to [${subject}] ${chapterName}`);
      }

      const questionsCountResult = await db.collection('questions')
        .where('subject', '==', subject)
        .where('chapter', '==', chapterName)
        .count()
        .get();

      const count = questionsCountResult.data().count;
      findings.push({ chapterKey, subject, chapterName, count });

      console.log(`    Result: ${count} questions found`);
    }

    // 4. Summary
    console.log('\n--- Final Summary ---');
    const sparseChapters = findings.filter(f => f.count === 0);
    const totalQuestionsAvailable = findings.reduce((sum, f) => sum + f.count, 0);

    if (sparseChapters.length > 0) {
      console.log(`\n❌ ISSUE: ${sparseChapters.length} out of ${findings.length} selected chapters have ZERO questions.`);
      console.log('Chapters with 0 questions:');
      sparseChapters.forEach(f => console.log(`  - ${f.chapterKey}`));
    } else {
      console.log('\n✅ All selected chapters have questions.');
    }

    console.log(`\nTotal questions available for this batch: ${totalQuestionsAvailable}`);

    process.exit(0);
  } catch (error) {
    console.error('Error running verifier:', error);
    process.exit(1);
  }
}

const targetUserId = process.argv[2];
verifyQuizGeneration(targetUserId);
