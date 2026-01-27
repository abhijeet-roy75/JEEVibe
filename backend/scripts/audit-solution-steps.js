/**
 * Audit Solution Steps in Question Bank
 *
 * This script checks all questions in the daily_quiz_questions collection
 * for missing or incomplete solution steps data.
 *
 * Checks:
 * 1. Questions without solution_steps field
 * 2. Questions with empty solution_steps array
 * 3. Questions with malformed solution_steps (not an array)
 * 4. Questions with solution_steps that have missing required fields
 *
 * Run: node backend/scripts/audit-solution-steps.js
 */

const { db } = require('../src/config/firebase');

async function auditSolutionSteps() {
  console.log('Starting solution steps audit...\n');

  try {
    // Get all questions from questions collection (main question bank)
    console.log('Fetching all questions from questions collection...');
    const questionsRef = db.collection('questions');
    const snapshot = await questionsRef.get();

    if (snapshot.empty) {
      console.log('No questions found in questions collection.');
      return;
    }

    console.log(`Total questions found: ${snapshot.size}\n`);

    // Track issues
    const issues = {
      missingSolutionSteps: [],
      emptySolutionSteps: [],
      malformedSolutionSteps: [],
      incompleteSolutionSteps: [],
    };

    let totalQuestions = 0;
    let questionsWithValidSteps = 0;

    // Iterate through all questions
    for (const doc of snapshot.docs) {
      totalQuestions++;
      const questionId = doc.id;
      const data = doc.data();

      // Check 1: Missing solution_steps field
      if (!data.solution_steps) {
        issues.missingSolutionSteps.push({
          question_id: questionId,
          subject: data.subject,
          chapter: data.chapter,
          chapter_key: data.chapter_key,
          difficulty: data.difficulty,
          question_type: data.question_type,
        });
        continue;
      }

      // Check 2: Malformed solution_steps (not an array)
      if (!Array.isArray(data.solution_steps)) {
        issues.malformedSolutionSteps.push({
          question_id: questionId,
          subject: data.subject,
          chapter: data.chapter,
          chapter_key: data.chapter_key,
          type: typeof data.solution_steps,
          value: JSON.stringify(data.solution_steps),
        });
        continue;
      }

      // Check 3: Empty solution_steps array
      if (data.solution_steps.length === 0) {
        issues.emptySolutionSteps.push({
          question_id: questionId,
          subject: data.subject,
          chapter: data.chapter,
          chapter_key: data.chapter_key,
          difficulty: data.difficulty,
          question_type: data.question_type,
        });
        continue;
      }

      // Check 4: Incomplete solution_steps (missing required fields in steps)
      let hasIssue = false;
      const stepIssues = [];

      data.solution_steps.forEach((step, index) => {
        const stepIssuesForThis = [];

        // Check for step_number
        if (step.step_number === undefined || step.step_number === null) {
          stepIssuesForThis.push('missing step_number');
        }

        // Check for either description or explanation
        if (!step.description && !step.explanation) {
          stepIssuesForThis.push('missing description/explanation');
        }

        // If step has issues, record them
        if (stepIssuesForThis.length > 0) {
          hasIssue = true;
          stepIssues.push({
            stepIndex: index,
            issues: stepIssuesForThis,
            step: step,
          });
        }
      });

      if (hasIssue) {
        issues.incompleteSolutionSteps.push({
          question_id: questionId,
          subject: data.subject,
          chapter: data.chapter,
          chapter_key: data.chapter_key,
          difficulty: data.difficulty,
          question_type: data.question_type,
          stepCount: data.solution_steps.length,
          stepIssues: stepIssues,
        });
      } else {
        questionsWithValidSteps++;
      }
    }

    // Print summary
    console.log('='.repeat(80));
    console.log('AUDIT SUMMARY');
    console.log('='.repeat(80));
    console.log(`Total questions: ${totalQuestions}`);
    console.log(`Questions with valid solution steps: ${questionsWithValidSteps}`);
    console.log(`Questions with issues: ${totalQuestions - questionsWithValidSteps}`);
    console.log(`Success rate: ${((questionsWithValidSteps / totalQuestions) * 100).toFixed(2)}%\n`);

    // Print detailed issues
    if (issues.missingSolutionSteps.length > 0) {
      console.log('='.repeat(80));
      console.log(`MISSING solution_steps field (${issues.missingSolutionSteps.length} questions):`);
      console.log('='.repeat(80));
      issues.missingSolutionSteps.forEach((q, index) => {
        console.log(`${index + 1}. ${q.question_id}`);
        console.log(`   Subject: ${q.subject}`);
        console.log(`   Chapter: ${q.chapter} (${q.chapter_key})`);
        console.log(`   Difficulty: ${q.difficulty}`);
        console.log(`   Type: ${q.question_type}`);
        console.log('');
      });
    }

    if (issues.emptySolutionSteps.length > 0) {
      console.log('='.repeat(80));
      console.log(`EMPTY solution_steps array (${issues.emptySolutionSteps.length} questions):`);
      console.log('='.repeat(80));
      issues.emptySolutionSteps.forEach((q, index) => {
        console.log(`${index + 1}. ${q.question_id}`);
        console.log(`   Subject: ${q.subject}`);
        console.log(`   Chapter: ${q.chapter} (${q.chapter_key})`);
        console.log(`   Difficulty: ${q.difficulty}`);
        console.log(`   Type: ${q.question_type}`);
        console.log('');
      });
    }

    if (issues.malformedSolutionSteps.length > 0) {
      console.log('='.repeat(80));
      console.log(`MALFORMED solution_steps (${issues.malformedSolutionSteps.length} questions):`);
      console.log('='.repeat(80));
      issues.malformedSolutionSteps.forEach((q, index) => {
        console.log(`${index + 1}. ${q.question_id}`);
        console.log(`   Subject: ${q.subject}`);
        console.log(`   Chapter: ${q.chapter} (${q.chapter_key})`);
        console.log(`   Expected: array, Actual: ${q.type}`);
        console.log(`   Value: ${q.value}`);
        console.log('');
      });
    }

    if (issues.incompleteSolutionSteps.length > 0) {
      console.log('='.repeat(80));
      console.log(`INCOMPLETE solution_steps (${issues.incompleteSolutionSteps.length} questions):`);
      console.log('='.repeat(80));
      issues.incompleteSolutionSteps.forEach((q, index) => {
        console.log(`${index + 1}. ${q.question_id}`);
        console.log(`   Subject: ${q.subject}`);
        console.log(`   Chapter: ${q.chapter} (${q.chapter_key})`);
        console.log(`   Difficulty: ${q.difficulty}`);
        console.log(`   Type: ${q.question_type}`);
        console.log(`   Step count: ${q.stepCount}`);
        console.log(`   Issues:`);
        q.stepIssues.forEach(stepIssue => {
          console.log(`      Step ${stepIssue.stepIndex}: ${stepIssue.issues.join(', ')}`);
          console.log(`         Data: ${JSON.stringify(stepIssue.step)}`);
        });
        console.log('');
      });
    }

    // Export to JSON for easier analysis
    const reportPath = './solution-steps-audit-report.json';
    const report = {
      timestamp: new Date().toISOString(),
      summary: {
        totalQuestions,
        questionsWithValidSteps,
        questionsWithIssues: totalQuestions - questionsWithValidSteps,
        successRate: ((questionsWithValidSteps / totalQuestions) * 100).toFixed(2) + '%',
      },
      issues,
    };

    const fs = require('fs');
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    console.log(`\nDetailed report saved to: ${reportPath}`);

    // Print actionable recommendations
    console.log('\n' + '='.repeat(80));
    console.log('RECOMMENDATIONS');
    console.log('='.repeat(80));

    if (issues.missingSolutionSteps.length > 0) {
      console.log(`\n1. Add solution_steps field to ${issues.missingSolutionSteps.length} questions`);
      console.log('   These questions need solution_steps added to show explanations.');
    }

    if (issues.emptySolutionSteps.length > 0) {
      console.log(`\n2. Populate solution_steps for ${issues.emptySolutionSteps.length} questions`);
      console.log('   These questions have an empty array and need step-by-step solutions.');
    }

    if (issues.malformedSolutionSteps.length > 0) {
      console.log(`\n3. Fix malformed solution_steps in ${issues.malformedSolutionSteps.length} questions`);
      console.log('   These questions have solution_steps in wrong format (should be array).');
    }

    if (issues.incompleteSolutionSteps.length > 0) {
      console.log(`\n4. Complete solution_steps in ${issues.incompleteSolutionSteps.length} questions`);
      console.log('   These questions have steps missing required fields (step_number, description/explanation).');
    }

    console.log('\n' + '='.repeat(80));
    console.log('Audit complete!');
    console.log('='.repeat(80));

  } catch (error) {
    console.error('Error during audit:', error);
    throw error;
  }
}

// Run the audit
auditSolutionSteps()
  .then(() => {
    console.log('\nExiting...');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Audit failed:', error);
    process.exit(1);
  });
