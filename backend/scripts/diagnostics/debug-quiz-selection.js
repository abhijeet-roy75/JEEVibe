/**
 * Debug script to simulate and trace daily quiz question selection
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');
const {
  selectChaptersForExploration,
  balanceSubjects
} = require('../src/services/dailyQuizService');
const {
  selectQuestionsForChapters,
  selectQuestionsForChapter
} = require('../src/services/questionSelectionService');
const { initializeMappings, getDatabaseNames } = require('../src/services/chapterMappingService');

async function debugQuizSelection(userId) {
  console.log('======================================================================');
  console.log('🔍 Debug: Quiz Selection Trace');
  console.log('======================================================================\n');

  // 1. Get user data
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();
  const thetaByChapter = userData.theta_by_chapter || {};

  console.log(`📋 User: ${userId}`);
  console.log(`📊 User has ${Object.keys(thetaByChapter).length} chapters in theta_by_chapter`);
  console.log(`📈 Completed quiz count: ${userData.completed_quiz_count || 0}`);
  console.log(`📚 Learning phase: ${userData.learning_phase || 'exploration'}\n`);

  // 2. Get all chapter mappings
  console.log('Loading chapter mappings from question bank...');
  const allChapterMappings = await initializeMappings();
  console.log(`✅ Loaded ${allChapterMappings.size} chapters from question bank\n`);

  // Count by subject in question bank
  const qbSubjectCounts = { physics: 0, chemistry: 0, mathematics: 0 };
  for (const [key, value] of allChapterMappings) {
    const subject = key.split('_')[0]?.toLowerCase();
    if (qbSubjectCounts[subject] !== undefined) {
      qbSubjectCounts[subject]++;
    }
  }
  console.log('Question bank chapters by subject:');
  console.log(`  Physics: ${qbSubjectCounts.physics}`);
  console.log(`  Chemistry: ${qbSubjectCounts.chemistry}`);
  console.log(`  Mathematics: ${qbSubjectCounts.mathematics}\n`);

  // 3. Simulate chapter selection for exploration
  console.log('======================================================================');
  console.log('📋 Step 1: selectChaptersForExploration');
  console.log('======================================================================\n');

  const selectedChapters = selectChaptersForExploration(thetaByChapter, 12, {
    recentChapters: new Set(),
    maxOverlap: 4,
    allChapterMappings
  });

  console.log(`Selected ${selectedChapters.length} chapters:`);

  // Count by subject
  const selectedBySubject = { physics: 0, chemistry: 0, mathematics: 0 };
  selectedChapters.forEach(ch => {
    console.log(`  - ${ch}`);
    const subject = ch.split('_')[0]?.toLowerCase();
    if (subject === 'maths') {
      selectedBySubject.mathematics++;
    } else if (selectedBySubject[subject] !== undefined) {
      selectedBySubject[subject]++;
    }
  });

  console.log('\nSelected chapters by subject:');
  console.log(`  Physics: ${selectedBySubject.physics}`);
  console.log(`  Chemistry: ${selectedBySubject.chemistry}`);
  console.log(`  Mathematics: ${selectedBySubject.mathematics}\n`);

  // 4. Build chapter thetas map
  const chapterThetasMap = {};
  selectedChapters.forEach(chapterKey => {
    const chapterData = thetaByChapter[chapterKey];
    chapterThetasMap[chapterKey] = chapterData?.theta || 0.0;
  });

  // 5. Try to select questions for each chapter
  console.log('======================================================================');
  console.log('📋 Step 2: selectQuestionsForChapters');
  console.log('======================================================================\n');

  const excludeQuestionIds = new Set();

  for (const [chapterKey, theta] of Object.entries(chapterThetasMap)) {
    console.log(`\n🔍 Selecting from ${chapterKey} (theta: ${theta})`);

    // Check mapping
    const mapping = await getDatabaseNames(chapterKey);
    if (mapping) {
      console.log(`   ✅ Mapping: subject="${mapping.subject}", chapter="${mapping.chapter}"`);
    } else {
      console.log(`   ❌ NO MAPPING FOUND - Questions won't be found!`);
    }

    try {
      const questions = await selectQuestionsForChapter(chapterKey, theta, excludeQuestionIds, 1);
      if (questions.length > 0) {
        console.log(`   ✅ Found ${questions.length} question(s)`);
        console.log(`      - ${questions[0].question_id}: "${questions[0].chapter}" by ${questions[0].subject}`);
      } else {
        console.log(`   ❌ No questions found!`);
      }
    } catch (error) {
      console.log(`   ❌ Error: ${error.message}`);
    }
  }

  console.log('\n======================================================================');
  console.log('✅ Debug Complete');
  console.log('======================================================================');

  process.exit(0);
}

const userId = process.argv[2] || 'z93J7wOVYOPzYqin3NkS4aukX4b2';
debugQuizSelection(userId).catch(e => { console.error(e); process.exit(1); });
