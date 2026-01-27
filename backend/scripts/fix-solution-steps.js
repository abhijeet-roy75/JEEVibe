/**
 * Fix Solution Steps Field Names
 *
 * This script normalizes the field names in solution_steps to ensure
 * consistency across all questions. It maps various field names to the
 * standard format expected by the frontend.
 *
 * Standard format:
 * {
 *   step_number: number,
 *   description: string (optional - step title/heading),
 *   explanation: string (required - the actual explanation text)
 * }
 *
 * Run: node backend/scripts/fix-solution-steps.js
 */

const { db } = require('../src/config/firebase');

/**
 * Normalize a single solution step to standard format
 */
function normalizeStep(step, index) {
  const normalized = {};

  // 1. Normalize step_number
  if (step.step_number !== undefined && step.step_number !== null) {
    normalized.step_number = step.step_number;
  } else if (step.step !== undefined && step.step !== null) {
    normalized.step_number = step.step;
  } else {
    // If no step number provided, use index + 1
    normalized.step_number = index + 1;
  }

  // 2. Normalize description (optional field - usually a heading/title)
  if (step.description) {
    normalized.description = step.description;
  } else if (step.title) {
    normalized.description = step.title;
  }
  // If no description/title, leave it undefined (it's optional)

  // 3. Normalize explanation (required field - the actual explanation)
  if (step.explanation) {
    normalized.explanation = step.explanation;
  } else if (step.step_explanation) {
    normalized.explanation = step.step_explanation;
  } else if (step.step_text) {
    normalized.explanation = step.step_text;
  } else if (step.calc) {
    // calc field contains calculation explanation
    normalized.explanation = step.calc;
  } else if (step.result && !step.explanation && !step.calc) {
    // If only result exists, use it as explanation
    normalized.explanation = step.result;
  } else {
    // Fallback: try to construct explanation from available fields
    const parts = [];
    if (step.calc) parts.push(step.calc);
    if (step.result) parts.push(`Result: ${step.result}`);
    if (parts.length > 0) {
      normalized.explanation = parts.join('. ');
    } else {
      // Last resort: stringify the step
      normalized.explanation = JSON.stringify(step);
    }
  }

  // 4. Preserve any additional useful fields (formula, result, etc.)
  if (step.formula && !normalized.explanation.includes(step.formula)) {
    // Keep formula as separate field if it's not already in explanation
    normalized.formula = step.formula;
  }

  return normalized;
}

/**
 * Check if a step needs normalization
 */
function needsNormalization(step) {
  // Check if step_number is missing (even if no alternate exists)
  if (step.step_number === undefined || step.step_number === null) {
    return true; // Always normalize if step_number is missing
  }

  // Check if description/explanation is missing
  if (!step.description && !step.explanation) {
    // Check if it has alternate field names
    if (step.calc || step.result || step.step_text || step.step_explanation || step.title) {
      return true;
    }
  }

  return false;
}

async function fixSolutionSteps(dryRun = true) {
  console.log('Starting solution steps fix...');
  console.log(`Mode: ${dryRun ? 'DRY RUN (no changes will be made)' : 'LIVE (will update database)'}\n`);

  try {
    // Get all questions
    console.log('Fetching all questions from questions collection...');
    const questionsRef = db.collection('questions');
    const snapshot = await questionsRef.get();

    if (snapshot.empty) {
      console.log('No questions found in questions collection.');
      return;
    }

    console.log(`Total questions found: ${snapshot.size}\n`);

    let questionsToFix = 0;
    let questionsFixed = 0;
    let questionsFailed = 0;
    const fixDetails = [];

    // Iterate through all questions
    for (const doc of snapshot.docs) {
      const questionId = doc.id;
      const data = doc.data();

      // Skip if no solution_steps or not an array
      if (!data.solution_steps || !Array.isArray(data.solution_steps)) {
        continue;
      }

      // Check if any step needs normalization
      const needsFix = data.solution_steps.some(step => needsNormalization(step));

      if (!needsFix) {
        continue;
      }

      questionsToFix++;

      // Normalize all steps
      const normalizedSteps = data.solution_steps.map((step, index) =>
        normalizeStep(step, index)
      );

      // Store fix details for reporting
      fixDetails.push({
        question_id: questionId,
        subject: data.subject,
        chapter: data.chapter,
        chapter_key: data.chapter_key,
        before: data.solution_steps,
        after: normalizedSteps,
      });

      // Update in database (if not dry run)
      if (!dryRun) {
        try {
          await doc.ref.update({
            solution_steps: normalizedSteps,
            updated_at: new Date(),
          });
          questionsFixed++;
          console.log(`✅ Fixed: ${questionId}`);
        } catch (error) {
          questionsFailed++;
          console.error(`❌ Failed to fix ${questionId}:`, error.message);
        }
      } else {
        console.log(`[DRY RUN] Would fix: ${questionId}`);
        console.log('  Before:', JSON.stringify(data.solution_steps[0], null, 2));
        console.log('  After:', JSON.stringify(normalizedSteps[0], null, 2));
        console.log('');
      }
    }

    // Print summary
    console.log('\n' + '='.repeat(80));
    console.log('FIX SUMMARY');
    console.log('='.repeat(80));
    console.log(`Total questions scanned: ${snapshot.size}`);
    console.log(`Questions needing fix: ${questionsToFix}`);

    if (!dryRun) {
      console.log(`Questions successfully fixed: ${questionsFixed}`);
      console.log(`Questions failed to fix: ${questionsFailed}`);
      console.log(`Success rate: ${questionsToFix > 0 ? ((questionsFixed / questionsToFix) * 100).toFixed(2) : 0}%`);
    } else {
      console.log(`\nTo apply these fixes, run: node backend/scripts/fix-solution-steps.js --live`);
    }

    // Save detailed report
    const fs = require('fs');
    const reportPath = './solution-steps-fix-report.json';
    const report = {
      timestamp: new Date().toISOString(),
      mode: dryRun ? 'dry_run' : 'live',
      summary: {
        totalQuestionsScanned: snapshot.size,
        questionsNeedingFix: questionsToFix,
        questionsFixed: dryRun ? 0 : questionsFixed,
        questionsFailed: dryRun ? 0 : questionsFailed,
      },
      fixes: fixDetails,
    };

    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    console.log(`\nDetailed report saved to: ${reportPath}`);

    console.log('\n' + '='.repeat(80));
    console.log('Fix complete!');
    console.log('='.repeat(80));

  } catch (error) {
    console.error('Error during fix:', error);
    throw error;
  }
}

// Parse command line arguments
const args = process.argv.slice(2);
const isLive = args.includes('--live') || args.includes('-l');

// Run the fix
fixSolutionSteps(!isLive)
  .then(() => {
    console.log('\nExiting...');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Fix failed:', error);
    process.exit(1);
  });
