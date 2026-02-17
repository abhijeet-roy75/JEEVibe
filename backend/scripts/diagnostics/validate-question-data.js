/**
 * Validate Question Data Integrity
 *
 * Checks all questions in the database for data integrity issues:
 * - Invalid correct_answer (not matching options for MCQ)
 * - Missing required fields
 * - Invalid question_type values
 * - MCQ questions without options
 * - Numerical questions without answer_range
 * - Invalid difficulty values
 * - Broken image URLs
 * - Invalid IRT parameters
 *
 * Usage:
 *   node scripts/validate-question-data.js
 *   node scripts/validate-question-data.js --collection questions
 *   node scripts/validate-question-data.js --collection initial_assessment_questions
 *   node scripts/validate-question-data.js --fix-answer-mismatch (updates incorrect answers)
 */

const { db } = require('../src/config/firebase');

// Validation rules
const VALID_QUESTION_TYPES = ['mcq_single', 'numerical'];
const VALID_DIFFICULTIES = ['easy', 'medium', 'hard', 'medium-hard', 'medium_hard', 'med-hard'];
const VALID_MCQ_ANSWERS = ['A', 'B', 'C', 'D'];

// Issue severity
const SEVERITY = {
  CRITICAL: 'CRITICAL',  // Breaks functionality
  ERROR: 'ERROR',        // Data integrity issue
  WARNING: 'WARNING'     // Potential issue
};

async function validateQuestions(collectionName = 'questions', fixAnswerMismatch = false) {
  console.log('🔍 Question Data Validation\n');
  console.log('='.repeat(80));
  console.log(`Collection: ${collectionName}`);
  if (fixAnswerMismatch) {
    console.log('Mode: FIX ANSWER MISMATCH (will update database)');
  } else {
    console.log('Mode: READ-ONLY (no changes)');
  }
  console.log('='.repeat(80));

  // Get all questions
  const snapshot = await db.collection(collectionName).get();
  console.log(`\n📊 Total questions in ${collectionName}: ${snapshot.size}\n`);

  // Issue tracking
  const issues = {
    [SEVERITY.CRITICAL]: [],
    [SEVERITY.ERROR]: [],
    [SEVERITY.WARNING]: []
  };

  const stats = {
    total: snapshot.size,
    valid: 0,
    hasIssues: 0,
    fixed: 0
  };

  // Validate each question
  const batch = db.batch();
  let batchCount = 0;
  const BATCH_SIZE = 500;

  for (const doc of snapshot.docs) {
    const questionId = doc.id;
    const data = doc.data();
    let hasIssue = false;
    let shouldUpdate = false;
    const updates = {};

    // 1. Check required fields
    if (!data.subject) {
      issues[SEVERITY.CRITICAL].push({
        questionId,
        issue: 'Missing required field: subject',
        chapter: data.chapter || 'Unknown'
      });
      hasIssue = true;
    }

    if (!data.chapter) {
      issues[SEVERITY.CRITICAL].push({
        questionId,
        issue: 'Missing required field: chapter',
        subject: data.subject || 'Unknown'
      });
      hasIssue = true;
    }

    if (!data.question_type) {
      issues[SEVERITY.CRITICAL].push({
        questionId,
        issue: 'Missing required field: question_type',
        subject: data.subject,
        chapter: data.chapter
      });
      hasIssue = true;
    }

    if (!data.question_text) {
      issues[SEVERITY.CRITICAL].push({
        questionId,
        issue: 'Missing required field: question_text',
        subject: data.subject,
        chapter: data.chapter
      });
      hasIssue = true;
    }

    if (data.correct_answer === undefined && data.correct_answer !== 0) {
      issues[SEVERITY.CRITICAL].push({
        questionId,
        issue: 'Missing required field: correct_answer',
        subject: data.subject,
        chapter: data.chapter
      });
      hasIssue = true;
    }

    // 2. Validate question_type
    if (data.question_type && !VALID_QUESTION_TYPES.includes(data.question_type)) {
      issues[SEVERITY.ERROR].push({
        questionId,
        issue: `Invalid question_type: "${data.question_type}" (expected: ${VALID_QUESTION_TYPES.join(', ')})`,
        subject: data.subject,
        chapter: data.chapter
      });
      hasIssue = true;
    }

    // 3. Validate MCQ questions
    if (data.question_type === 'mcq_single') {
      // Check for options
      if (!data.options) {
        issues[SEVERITY.CRITICAL].push({
          questionId,
          issue: 'MCQ question missing options field',
          subject: data.subject,
          chapter: data.chapter
        });
        hasIssue = true;
      } else {
        // Get option keys
        let optionKeys;
        if (Array.isArray(data.options)) {
          // Array format: ["option1", "option2", ...]
          optionKeys = data.options.map((_, i) => String.fromCharCode(65 + i)); // A, B, C, D
        } else if (typeof data.options === 'object') {
          // Object format: { "A": "option1", "B": "option2", ... }
          optionKeys = Object.keys(data.options);
        } else {
          issues[SEVERITY.ERROR].push({
            questionId,
            issue: `Invalid options format: ${typeof data.options}`,
            subject: data.subject,
            chapter: data.chapter
          });
          hasIssue = true;
          optionKeys = [];
        }

        // Check if correct_answer matches options
        if (optionKeys.length > 0) {
          const correctAnswer = String(data.correct_answer);

          if (!optionKeys.includes(correctAnswer)) {
            const issue = {
              questionId,
              issue: `correct_answer "${correctAnswer}" not in options: [${optionKeys.join(', ')}]`,
              subject: data.subject,
              chapter: data.chapter,
              optionKeys,
              currentAnswer: correctAnswer
            };

            issues[SEVERITY.ERROR].push(issue);
            hasIssue = true;

            // Auto-fix logic: if answer is "1", "2", "3", "4" convert to "A", "B", "C", "D"
            if (fixAnswerMismatch && /^[1-4]$/.test(correctAnswer)) {
              const numericAnswer = parseInt(correctAnswer);
              const fixedAnswer = String.fromCharCode(64 + numericAnswer); // 1->A, 2->B, 3->C, 4->D

              if (optionKeys.includes(fixedAnswer)) {
                updates.correct_answer = fixedAnswer;
                shouldUpdate = true;
                console.log(`   ✓ Fixing ${questionId}: "${correctAnswer}" → "${fixedAnswer}"`);
              }
            }
          }
        }

        // Check minimum options
        if (optionKeys.length < 2) {
          issues[SEVERITY.ERROR].push({
            questionId,
            issue: `MCQ question has only ${optionKeys.length} option(s) (minimum 2 required)`,
            subject: data.subject,
            chapter: data.chapter
          });
          hasIssue = true;
        }
      }
    }

    // 4. Validate numerical questions
    if (data.question_type === 'numerical') {
      if (!data.answer_range && !data.correct_answer_exact) {
        issues[SEVERITY.WARNING].push({
          questionId,
          issue: 'Numerical question missing both answer_range and correct_answer_exact',
          subject: data.subject,
          chapter: data.chapter
        });
        hasIssue = true;
      }
    }

    // 5. Validate difficulty
    if (data.difficulty && !VALID_DIFFICULTIES.includes(data.difficulty.toLowerCase())) {
      issues[SEVERITY.WARNING].push({
        questionId,
        issue: `Invalid difficulty: "${data.difficulty}" (expected: ${VALID_DIFFICULTIES.join(', ')})`,
        subject: data.subject,
        chapter: data.chapter
      });
      hasIssue = true;
    }

    // 6. Validate IRT parameters
    if (!data.irt_parameters || data.irt_parameters.difficulty_b === undefined) {
      issues[SEVERITY.WARNING].push({
        questionId,
        issue: 'Missing IRT parameters or difficulty_b',
        subject: data.subject,
        chapter: data.chapter
      });
      hasIssue = true;
    } else {
      const b = data.irt_parameters.difficulty_b;
      if (typeof b !== 'number' || b < -3 || b > 3) {
        issues[SEVERITY.WARNING].push({
          questionId,
          issue: `IRT difficulty_b out of range: ${b} (expected: -3 to +3)`,
          subject: data.subject,
          chapter: data.chapter
        });
        hasIssue = true;
      }
    }

    // 7. Check image consistency
    if (data.has_image === true && !data.image_url) {
      issues[SEVERITY.WARNING].push({
        questionId,
        issue: 'has_image=true but image_url is missing',
        subject: data.subject,
        chapter: data.chapter
      });
      hasIssue = true;
    }

    // Apply fixes if needed
    if (shouldUpdate && Object.keys(updates).length > 0) {
      batch.update(doc.ref, updates);
      batchCount++;
      stats.fixed++;

      // Commit batch if full
      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        batchCount = 0;
      }
    }

    // Update stats
    if (hasIssue) {
      stats.hasIssues++;
    } else {
      stats.valid++;
    }
  }

  // Commit remaining updates
  if (batchCount > 0) {
    await batch.commit();
    console.log(`\n✅ Fixed ${stats.fixed} question(s)\n`);
  }

  // Print results
  console.log('='.repeat(80));
  console.log('📊 VALIDATION RESULTS');
  console.log('='.repeat(80));

  console.log(`\nTotal questions: ${stats.total}`);
  console.log(`Valid (no issues): ${stats.valid} (${((stats.valid / stats.total) * 100).toFixed(1)}%)`);
  console.log(`With issues: ${stats.hasIssues} (${((stats.hasIssues / stats.total) * 100).toFixed(1)}%)`);
  if (fixAnswerMismatch && stats.fixed > 0) {
    console.log(`Fixed: ${stats.fixed}`);
  }

  // Print issues by severity
  for (const severity of [SEVERITY.CRITICAL, SEVERITY.ERROR, SEVERITY.WARNING]) {
    const severityIssues = issues[severity];
    if (severityIssues.length === 0) continue;

    console.log('\n' + '='.repeat(80));
    console.log(`${severity} ISSUES (${severityIssues.length}):`);
    console.log('='.repeat(80));

    // Group by issue type
    const grouped = {};
    for (const issue of severityIssues) {
      const key = issue.issue.split(':')[0]; // Group by issue prefix
      if (!grouped[key]) {
        grouped[key] = [];
      }
      grouped[key].push(issue);
    }

    for (const [issueType, issueList] of Object.entries(grouped)) {
      console.log(`\n${issueType} (${issueList.length}):`);

      // Show all issues (no limit)
      for (const issue of issueList) {
        const location = `${issue.subject || '?'}/${issue.chapter || '?'}`;
        console.log(`   ${issue.questionId.padEnd(25)} [${location}] ${issue.issue}`);
      }
    }
  }

  console.log('\n' + '='.repeat(80));
  console.log('✅ Validation complete!\n');

  if (!fixAnswerMismatch && issues[SEVERITY.ERROR].some(i => i.issue.includes('correct_answer'))) {
    console.log('💡 Tip: Use --fix-answer-mismatch to automatically fix numeric answer mismatches (1→A, 2→B, etc.)\n');
  }

  return {
    stats,
    issues
  };
}

async function main() {
  try {
    const args = process.argv.slice(2);

    // Parse collection
    let collectionName = 'questions';
    if (args.includes('--collection')) {
      const idx = args.indexOf('--collection');
      collectionName = args[idx + 1];
    }

    // Parse fix flag
    const fixAnswerMismatch = args.includes('--fix-answer-mismatch');

    // Validate
    await validateQuestions(collectionName, fixAnswerMismatch);

  } catch (error) {
    console.error('\n❌ Error:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('💥 Script failed:', error);
      process.exit(1);
    });
}

module.exports = { validateQuestions };
