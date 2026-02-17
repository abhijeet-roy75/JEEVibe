#!/usr/bin/env node
/**
 * Mock Test Readiness Verification Script
 *
 * Checks if the questions collection has enough questions to create
 * 2-3 mock test templates (90 questions each = 180-270 total minimum).
 *
 * Requirements per template:
 * - 30 questions per subject (Physics, Chemistry, Mathematics)
 * - 20 MCQ + 10 Numerical per subject
 * - Questions distributed across chapters by JEE weightage
 *
 * Usage:
 *   cd backend && node scripts/verifyMockTestReadiness.js
 *
 * @version 1.0
 * @phase Phase 0 - Mock Test Data Creation
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

// Requirements for mock tests
const TEMPLATE_COUNT = 3;
const QUESTIONS_PER_SUBJECT = 30;
const MCQ_PER_SUBJECT = 20;
const NVQ_PER_SUBJECT = 10;

// Minimum requirements (for 3 templates with no overlap)
const MIN_MCQ_PER_SUBJECT = MCQ_PER_SUBJECT * TEMPLATE_COUNT;  // 60
const MIN_NVQ_PER_SUBJECT = NVQ_PER_SUBJECT * TEMPLATE_COUNT;  // 30
const MIN_TOTAL_PER_SUBJECT = QUESTIONS_PER_SUBJECT * TEMPLATE_COUNT;  // 90

async function verifyMockTestReadiness() {
  console.log('='.repeat(70));
  console.log('📋 JEEVibe Mock Test Readiness Verification');
  console.log('='.repeat(70));
  console.log();
  console.log(`Checking if question bank can support ${TEMPLATE_COUNT} mock test templates...`);
  console.log(`Each template: 90 questions (30/subject × 3 subjects)`);
  console.log(`Question types: 20 MCQ + 10 Numerical per subject`);
  console.log();

  try {
    // Fetch all questions
    console.log('📊 Fetching questions from Firestore...\n');
    const questionsSnapshot = await db.collection('questions').get();

    if (questionsSnapshot.empty) {
      console.log('❌ No questions found in "questions" collection!');
      console.log('   Cannot create mock tests without questions.\n');
      process.exit(1);
    }

    console.log(`   Total questions in bank: ${questionsSnapshot.size}\n`);

    // Analyze questions by subject and type
    const analysis = {
      Physics: { mcq_single: [], numerical: [], other: [] },
      Chemistry: { mcq_single: [], numerical: [], other: [] },
      Mathematics: { mcq_single: [], numerical: [], other: [] }
    };

    const chapterCounts = {};
    const issues = [];

    questionsSnapshot.forEach(doc => {
      const data = doc.data();
      const subject = data.subject;
      const questionType = data.question_type;
      const chapterKey = data.chapter_key;

      // Validate subject
      if (!analysis[subject]) {
        issues.push(`Unknown subject "${subject}" for question ${doc.id}`);
        return;
      }

      // Categorize by question type
      if (questionType === 'mcq_single' || questionType === 'mcq') {
        analysis[subject].mcq_single.push({
          id: doc.id,
          question_id: data.question_id,
          chapter_key: chapterKey,
          difficulty: data.irt_parameters?.difficulty_b || data.difficulty_irt
        });
      } else if (questionType === 'numerical' || questionType === 'integer') {
        analysis[subject].numerical.push({
          id: doc.id,
          question_id: data.question_id,
          chapter_key: chapterKey,
          difficulty: data.irt_parameters?.difficulty_b || data.difficulty_irt
        });
      } else {
        analysis[subject].other.push({
          id: doc.id,
          question_type: questionType
        });
      }

      // Track chapter distribution
      if (chapterKey) {
        chapterCounts[chapterKey] = (chapterCounts[chapterKey] || 0) + 1;
      }
    });

    // Display results
    console.log('📊 Question Count by Subject and Type:');
    console.log('-'.repeat(70));
    console.log();

    let overallReady = true;
    const summary = {};

    for (const subject of ['Physics', 'Chemistry', 'Mathematics']) {
      const mcqCount = analysis[subject].mcq_single.length;
      const nvqCount = analysis[subject].numerical.length;
      const otherCount = analysis[subject].other.length;
      const totalCount = mcqCount + nvqCount;

      const mcqOk = mcqCount >= MIN_MCQ_PER_SUBJECT;
      const nvqOk = nvqCount >= MIN_NVQ_PER_SUBJECT;
      const totalOk = totalCount >= MIN_TOTAL_PER_SUBJECT;

      summary[subject] = { mcqCount, nvqCount, totalCount, mcqOk, nvqOk, totalOk };

      console.log(`   ${subject}:`);
      console.log(`      MCQ (Single):  ${mcqCount.toString().padStart(4)} / ${MIN_MCQ_PER_SUBJECT} required  ${mcqOk ? '✅' : '❌'}`);
      console.log(`      Numerical:     ${nvqCount.toString().padStart(4)} / ${MIN_NVQ_PER_SUBJECT} required  ${nvqOk ? '✅' : '❌'}`);
      console.log(`      Total:         ${totalCount.toString().padStart(4)} / ${MIN_TOTAL_PER_SUBJECT} required  ${totalOk ? '✅' : '❌'}`);
      if (otherCount > 0) {
        console.log(`      Other types:   ${otherCount.toString().padStart(4)} (not used in mock tests)`);
      }
      console.log();

      if (!mcqOk || !nvqOk) {
        overallReady = false;
      }
    }

    // Chapter distribution check
    console.log('📊 Chapter Distribution:');
    console.log('-'.repeat(70));
    console.log();

    const sortedChapters = Object.entries(chapterCounts)
      .sort((a, b) => b[1] - a[1]);

    const lowChapters = sortedChapters.filter(([_, count]) => count < 5);
    const goodChapters = sortedChapters.filter(([_, count]) => count >= 5);

    console.log(`   Chapters with 5+ questions: ${goodChapters.length}`);
    console.log(`   Chapters with <5 questions: ${lowChapters.length}`);
    console.log();

    if (lowChapters.length > 0) {
      console.log('   ⚠️  Low question count chapters:');
      lowChapters.slice(0, 10).forEach(([chapter, count]) => {
        console.log(`      - ${chapter}: ${count} questions`);
      });
      if (lowChapters.length > 10) {
        console.log(`      ... and ${lowChapters.length - 10} more`);
      }
      console.log();
    }

    // Issues
    if (issues.length > 0) {
      console.log('⚠️  Data Issues Found:');
      console.log('-'.repeat(70));
      issues.slice(0, 10).forEach(issue => console.log(`   - ${issue}`));
      if (issues.length > 10) {
        console.log(`   ... and ${issues.length - 10} more issues`);
      }
      console.log();
    }

    // Final verdict
    console.log('='.repeat(70));
    console.log('📋 VERDICT');
    console.log('='.repeat(70));
    console.log();

    if (overallReady) {
      console.log('   ✅ READY FOR MOCK TESTS!');
      console.log();
      console.log('   You can create up to 3 mock test templates with unique questions.');
      console.log();
      console.log('   Next step: Run createMockTestTemplates.js');
      console.log('   cd backend && node scripts/createMockTestTemplates.js');
      console.log();
    } else {
      console.log('   ❌ NOT READY - Need more questions');
      console.log();
      console.log('   Missing questions:');
      for (const subject of ['Physics', 'Chemistry', 'Mathematics']) {
        const s = summary[subject];
        if (!s.mcqOk) {
          console.log(`   - ${subject} MCQ: need ${MIN_MCQ_PER_SUBJECT - s.mcqCount} more`);
        }
        if (!s.nvqOk) {
          console.log(`   - ${subject} Numerical: need ${MIN_NVQ_PER_SUBJECT - s.nvqCount} more`);
        }
      }
      console.log();
      console.log('   Options:');
      console.log('   1. Add more questions to the "questions" collection');
      console.log('   2. Create fewer templates (reduce TEMPLATE_COUNT in this script)');
      console.log('   3. Allow question reuse between templates (not recommended)');
      console.log();
    }

    // Return analysis for programmatic use
    return {
      ready: overallReady,
      summary,
      chapterCounts,
      totalQuestions: questionsSnapshot.size
    };

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the verification
verifyMockTestReadiness()
  .then((result) => {
    console.log('Verification complete.');
    process.exit(result.ready ? 0 : 1);
  })
  .catch(error => {
    console.error('❌ Verification failed:', error);
    process.exit(1);
  });
