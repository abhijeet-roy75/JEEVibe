#!/usr/bin/env node
/**
 * Question Bank Coverage & Difficulty Distribution Verification Script
 *
 * This script checks:
 * 1. Whether all chapters tested in initial assessment have corresponding daily quiz questions
 * 2. The difficulty distribution (b values) in the question bank
 * 3. Whether recovery quiz thresholds are feasible
 *
 * Usage:
 *   cd backend && node scripts/verify-question-bank-coverage.js
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

// Recovery quiz difficulty thresholds from circuitBreakerService.js
const EASY_DIFFICULTY_MAX = 0.0;
const MEDIUM_DIFFICULTY_MAX = 0.5;

// Spec difficulty ranges
const SPEC_EASY_MIN = 0.4;
const SPEC_EASY_MAX = 0.7;
const SPEC_MEDIUM_MIN = 0.8;
const SPEC_MEDIUM_MAX = 1.3;
const SPEC_HARD_MIN = 1.4;
const SPEC_HARD_MAX = 2.6;

async function verifyQuestionBankCoverage() {
  console.log('=' .repeat(70));
  console.log('📊 JEEVibe Question Bank Coverage & Difficulty Verification');
  console.log('=' .repeat(70));
  console.log();

  try {
    // ========================================
    // 1. Get Initial Assessment Questions
    // ========================================
    console.log('📋 Step 1: Fetching Initial Assessment Questions...\n');

    const assessmentSnapshot = await db.collection('initial_assessment_questions').get();

    if (assessmentSnapshot.empty) {
      console.log('⚠️  No questions found in initial_assessment_questions collection');
      console.log('   This collection should contain the 30 assessment questions.\n');
    } else {
      console.log(`   Found ${assessmentSnapshot.size} initial assessment questions\n`);
    }

    // Extract unique chapters from assessment
    const assessmentChapters = new Map(); // chapter_key -> { subject, chapter, count }

    assessmentSnapshot.forEach(doc => {
      const data = doc.data();
      const subject = data.subject?.toLowerCase() || 'unknown';
      const chapter = data.chapter || 'unknown';
      const chapterKey = `${subject}_${chapter.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')}`;

      if (!assessmentChapters.has(chapterKey)) {
        assessmentChapters.set(chapterKey, {
          subject: data.subject,
          chapter: chapter,
          count: 0
        });
      }
      assessmentChapters.get(chapterKey).count++;
    });

    console.log('   Chapters covered in Initial Assessment:');
    console.log('   ' + '-'.repeat(60));
    assessmentChapters.forEach((info, key) => {
      console.log(`   ${key}: ${info.count} questions (${info.subject} / ${info.chapter})`);
    });
    console.log();

    // ========================================
    // 2. Get Daily Quiz Questions
    // ========================================
    console.log('📋 Step 2: Fetching Daily Quiz Questions...\n');

    const questionsSnapshot = await db.collection('questions').get();

    if (questionsSnapshot.empty) {
      console.log('❌ No questions found in questions collection!');
      console.log('   Daily quizzes will not work without questions.\n');
      return;
    }

    console.log(`   Found ${questionsSnapshot.size} daily quiz questions\n`);

    // Analyze question bank
    const dailyQuizChapters = new Map(); // chapter_key -> { subject, chapter, count, difficulties }
    const allDifficulties = [];
    const subjectCounts = { physics: 0, chemistry: 0, mathematics: 0 };

    questionsSnapshot.forEach(doc => {
      const data = doc.data();
      const subject = data.subject?.toLowerCase() || 'unknown';
      const chapter = data.chapter || 'unknown';
      const chapterKey = data.chapter_key ||
        `${subject}_${chapter.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')}`;

      // Get difficulty_b
      const difficultyB = data.irt_parameters?.difficulty_b ?? data.difficulty_irt ?? null;

      if (!dailyQuizChapters.has(chapterKey)) {
        dailyQuizChapters.set(chapterKey, {
          subject: data.subject,
          chapter: chapter,
          count: 0,
          difficulties: []
        });
      }

      const chapterData = dailyQuizChapters.get(chapterKey);
      chapterData.count++;
      if (difficultyB !== null) {
        chapterData.difficulties.push(difficultyB);
        allDifficulties.push(difficultyB);
      }

      // Subject counts
      if (subjectCounts[subject] !== undefined) {
        subjectCounts[subject]++;
      }
    });

    // ========================================
    // 3. Coverage Analysis
    // ========================================
    console.log('📋 Step 3: Coverage Analysis\n');
    console.log('   Checking if assessment chapters have daily quiz questions...\n');

    const missingChapters = [];
    const coveredChapters = [];

    assessmentChapters.forEach((assessmentInfo, assessmentKey) => {
      // Try to find matching chapter in daily quiz questions
      let found = false;
      let matchedKey = null;
      let matchedCount = 0;

      // Direct match
      if (dailyQuizChapters.has(assessmentKey)) {
        found = true;
        matchedKey = assessmentKey;
        matchedCount = dailyQuizChapters.get(assessmentKey).count;
      } else {
        // Try fuzzy match (different naming conventions)
        for (const [dailyKey, dailyInfo] of dailyQuizChapters) {
          if (dailyKey.includes(assessmentKey) || assessmentKey.includes(dailyKey) ||
              dailyInfo.chapter?.toLowerCase() === assessmentInfo.chapter?.toLowerCase()) {
            found = true;
            matchedKey = dailyKey;
            matchedCount = dailyInfo.count;
            break;
          }
        }
      }

      if (found) {
        coveredChapters.push({
          assessmentKey,
          matchedKey,
          assessmentCount: assessmentInfo.count,
          dailyQuizCount: matchedCount
        });
      } else {
        missingChapters.push({
          key: assessmentKey,
          subject: assessmentInfo.subject,
          chapter: assessmentInfo.chapter,
          assessmentCount: assessmentInfo.count
        });
      }
    });

    console.log('   ✅ Covered Chapters:');
    console.log('   ' + '-'.repeat(60));
    coveredChapters.forEach(c => {
      const status = c.dailyQuizCount >= 10 ? '✅' : '⚠️ ';
      console.log(`   ${status} ${c.assessmentKey}: ${c.dailyQuizCount} daily quiz questions`);
    });
    console.log();

    if (missingChapters.length > 0) {
      console.log('   ❌ MISSING Chapters (in assessment but NO daily quiz questions):');
      console.log('   ' + '-'.repeat(60));
      missingChapters.forEach(m => {
        console.log(`   ❌ ${m.key} (${m.subject} / ${m.chapter}) - ${m.assessmentCount} assessment questions`);
      });
      console.log();
    } else {
      console.log('   ✅ All assessment chapters have daily quiz questions!\n');
    }

    // ========================================
    // 4. Difficulty Distribution Analysis
    // ========================================
    console.log('📋 Step 4: Difficulty Distribution Analysis\n');

    if (allDifficulties.length === 0) {
      console.log('   ⚠️  No difficulty values found in questions!');
      console.log('   Questions may be missing irt_parameters.difficulty_b field.\n');
    } else {
      // Statistics
      const sorted = [...allDifficulties].sort((a, b) => a - b);
      const min = sorted[0];
      const max = sorted[sorted.length - 1];
      const median = sorted[Math.floor(sorted.length / 2)];
      const mean = allDifficulties.reduce((a, b) => a + b, 0) / allDifficulties.length;

      console.log('   Overall Statistics:');
      console.log('   ' + '-'.repeat(40));
      console.log(`   Total questions with difficulty: ${allDifficulties.length}`);
      console.log(`   Min difficulty (b): ${min.toFixed(3)}`);
      console.log(`   Max difficulty (b): ${max.toFixed(3)}`);
      console.log(`   Mean difficulty (b): ${mean.toFixed(3)}`);
      console.log(`   Median difficulty (b): ${median.toFixed(3)}`);
      console.log();

      // Distribution by ranges
      const distribution = {
        veryEasy: allDifficulties.filter(d => d <= EASY_DIFFICULTY_MAX).length,          // ≤ 0.0 (current code)
        easy: allDifficulties.filter(d => d > EASY_DIFFICULTY_MAX && d <= MEDIUM_DIFFICULTY_MAX).length, // 0.0 < b ≤ 0.5
        specEasy: allDifficulties.filter(d => d >= SPEC_EASY_MIN && d <= SPEC_EASY_MAX).length,    // 0.4-0.7 (spec)
        specMedium: allDifficulties.filter(d => d >= SPEC_MEDIUM_MIN && d <= SPEC_MEDIUM_MAX).length, // 0.8-1.3 (spec)
        specHard: allDifficulties.filter(d => d >= SPEC_HARD_MIN && d <= SPEC_HARD_MAX).length,    // 1.4-2.6 (spec)
        medium: allDifficulties.filter(d => d > 0.5 && d <= 1.0).length,
        hard: allDifficulties.filter(d => d > 1.0 && d <= 1.5).length,
        veryHard: allDifficulties.filter(d => d > 1.5).length
      };

      console.log('   Distribution by Current Code Thresholds:');
      console.log('   ' + '-'.repeat(50));
      console.log(`   Very Easy (b ≤ 0.0):     ${distribution.veryEasy.toString().padStart(4)} questions (${(distribution.veryEasy/allDifficulties.length*100).toFixed(1)}%)`);
      console.log(`   Easy (0.0 < b ≤ 0.5):    ${distribution.easy.toString().padStart(4)} questions (${(distribution.easy/allDifficulties.length*100).toFixed(1)}%)`);
      console.log(`   Medium (0.5 < b ≤ 1.0):  ${distribution.medium.toString().padStart(4)} questions (${(distribution.medium/allDifficulties.length*100).toFixed(1)}%)`);
      console.log(`   Hard (1.0 < b ≤ 1.5):    ${distribution.hard.toString().padStart(4)} questions (${(distribution.hard/allDifficulties.length*100).toFixed(1)}%)`);
      console.log(`   Very Hard (b > 1.5):     ${distribution.veryHard.toString().padStart(4)} questions (${(distribution.veryHard/allDifficulties.length*100).toFixed(1)}%)`);
      console.log();

      console.log('   Distribution by Spec Thresholds:');
      console.log('   ' + '-'.repeat(50));
      console.log(`   Easy (0.4-0.7):          ${distribution.specEasy.toString().padStart(4)} questions (${(distribution.specEasy/allDifficulties.length*100).toFixed(1)}%)`);
      console.log(`   Medium (0.8-1.3):        ${distribution.specMedium.toString().padStart(4)} questions (${(distribution.specMedium/allDifficulties.length*100).toFixed(1)}%)`);
      console.log(`   Hard (1.4-2.6):          ${distribution.specHard.toString().padStart(4)} questions (${(distribution.specHard/allDifficulties.length*100).toFixed(1)}%)`);
      console.log();

      // ========================================
      // 5. Recovery Quiz Feasibility
      // ========================================
      console.log('📋 Step 5: Recovery Quiz Feasibility Analysis\n');

      console.log('   Current circuitBreakerService.js thresholds:');
      console.log(`   - EASY: b ≤ ${EASY_DIFFICULTY_MAX}`);
      console.log(`   - MEDIUM: ${EASY_DIFFICULTY_MAX} < b ≤ ${MEDIUM_DIFFICULTY_MAX}\n`);

      if (distribution.veryEasy < 7) {
        console.log(`   ⚠️  WARNING: Only ${distribution.veryEasy} questions with b ≤ 0.0`);
        console.log('      Recovery quiz needs 7 "easy" questions!');
        console.log('      Consider adjusting EASY_DIFFICULTY_MAX threshold.\n');
      } else {
        console.log(`   ✅ Sufficient easy questions (${distribution.veryEasy}) for recovery quiz\n`);
      }

      if (distribution.easy < 2) {
        console.log(`   ⚠️  WARNING: Only ${distribution.easy} questions with 0.0 < b ≤ 0.5`);
        console.log('      Recovery quiz needs 2 "medium" questions!');
        console.log('      Consider adjusting MEDIUM_DIFFICULTY_MAX threshold.\n');
      } else {
        console.log(`   ✅ Sufficient medium questions (${distribution.easy}) for recovery quiz\n`);
      }

      // Recommendation
      if (distribution.veryEasy < 7 || distribution.easy < 2) {
        console.log('   📝 RECOMMENDATION:');
        console.log('   ' + '-'.repeat(50));

        // Find better thresholds
        const sortedDiffs = [...allDifficulties].sort((a, b) => a - b);
        const p20 = sortedDiffs[Math.floor(sortedDiffs.length * 0.20)]; // 20th percentile
        const p40 = sortedDiffs[Math.floor(sortedDiffs.length * 0.40)]; // 40th percentile

        console.log(`   Your question bank 20th percentile: b = ${p20.toFixed(2)}`);
        console.log(`   Your question bank 40th percentile: b = ${p40.toFixed(2)}`);
        console.log();
        console.log('   Suggested adjustments for circuitBreakerService.js:');
        console.log(`   const EASY_DIFFICULTY_MAX = ${p20.toFixed(1)};  // Was 0.0`);
        console.log(`   const MEDIUM_DIFFICULTY_MAX = ${p40.toFixed(1)}; // Was 0.5`);
        console.log();
      }
    }

    // ========================================
    // 6. Subject Distribution
    // ========================================
    console.log('📋 Step 6: Subject Distribution\n');
    console.log('   Questions by Subject:');
    console.log('   ' + '-'.repeat(40));
    const total = subjectCounts.physics + subjectCounts.chemistry + subjectCounts.mathematics;
    console.log(`   Physics:     ${subjectCounts.physics.toString().padStart(4)} (${(subjectCounts.physics/total*100).toFixed(1)}%)`);
    console.log(`   Chemistry:   ${subjectCounts.chemistry.toString().padStart(4)} (${(subjectCounts.chemistry/total*100).toFixed(1)}%)`);
    console.log(`   Mathematics: ${subjectCounts.mathematics.toString().padStart(4)} (${(subjectCounts.mathematics/total*100).toFixed(1)}%)`);
    console.log();

    // ========================================
    // 7. Per-Chapter Question Counts
    // ========================================
    console.log('📋 Step 7: Questions Per Chapter (Daily Quiz Bank)\n');

    const chaptersArray = Array.from(dailyQuizChapters.entries())
      .map(([key, data]) => ({ key, ...data }))
      .sort((a, b) => b.count - a.count);

    console.log('   Chapter'.padEnd(50) + 'Count'.padStart(6) + '  Avg Diff');
    console.log('   ' + '-'.repeat(70));

    chaptersArray.forEach(ch => {
      const avgDiff = ch.difficulties.length > 0
        ? (ch.difficulties.reduce((a, b) => a + b, 0) / ch.difficulties.length).toFixed(2)
        : 'N/A';
      const status = ch.count < 10 ? '⚠️' : '  ';
      console.log(`   ${status}${ch.key.padEnd(47)} ${ch.count.toString().padStart(4)}    ${avgDiff}`);
    });
    console.log();

    // ========================================
    // Summary
    // ========================================
    console.log('=' .repeat(70));
    console.log('📊 SUMMARY');
    console.log('=' .repeat(70));
    console.log();
    console.log(`   Initial Assessment Questions: ${assessmentSnapshot.size}`);
    console.log(`   Daily Quiz Questions: ${questionsSnapshot.size}`);
    console.log(`   Assessment Chapters: ${assessmentChapters.size}`);
    console.log(`   Daily Quiz Chapters: ${dailyQuizChapters.size}`);
    console.log(`   Missing Chapters: ${missingChapters.length}`);
    console.log();

    if (missingChapters.length > 0) {
      console.log('   ❌ ACTION REQUIRED: Add questions for missing chapters');
    }
    if (allDifficulties.length > 0 && allDifficulties.filter(d => d <= 0).length < 7) {
      console.log('   ⚠️  ACTION SUGGESTED: Adjust recovery quiz difficulty thresholds');
    }
    if (missingChapters.length === 0 && (allDifficulties.length === 0 || allDifficulties.filter(d => d <= 0).length >= 7)) {
      console.log('   ✅ Question bank looks good!');
    }
    console.log();

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the verification
verifyQuestionBankCoverage()
  .then(() => {
    console.log('✅ Verification complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Verification failed:', error);
    process.exit(1);
  });
