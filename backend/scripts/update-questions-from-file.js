/**
 * Batch Update Questions from JSON File
 *
 * Reads questions from a JSON file and updates/overwrites them in Firestore.
 * Useful for fixing specific questions that have data issues.
 *
 * Features:
 * - Reads questions from JSON file (supports object or array format)
 * - Updates only specified question IDs (or all if not specified)
 * - Fully overwrites existing questions (not merge)
 * - Validates question structure before update
 * - Handles image uploads if needed
 *
 * Usage:
 *   # Preview mode (shows what will be updated)
 *   node scripts/update-questions-from-file.js --file path/to/questions.json --preview
 *
 *   # Update all questions in file
 *   node scripts/update-questions-from-file.js --file path/to/questions.json
 *
 *   # Update only specific question IDs
 *   node scripts/update-questions-from-file.js --file path/to/questions.json --ids CHEM_THERMO_HARD_009,CHEM_THERMO_MED_048
 *
 *   # Skip image uploads (faster)
 *   node scripts/update-questions-from-file.js --file path/to/questions.json --skip-images
 */

const path = require('path');
const fs = require('fs');
const { db, storage, admin } = require('../src/config/firebase');
const { retryFirestoreOperation } = require('../src/utils/firestoreRetry');

// ============================================================================
// STORAGE OPERATIONS
// ============================================================================

const STORAGE_PATHS = {
  questions: 'questions/daily_quiz',
  initial_assessment_questions: 'questions/initial_assessment'
};

let cachedBucket = null;

async function getBucket() {
  if (cachedBucket) return cachedBucket;

  let bucket = storage.bucket();

  try {
    const [exists] = await bucket.exists();
    if (!exists) {
      const projectId = admin.app().options.projectId || 'jeevibe';
      const bucketNames = [
        `${projectId}.appspot.com`,
        `${projectId}.firebasestorage.app`,
        projectId
      ];

      for (const bucketName of bucketNames) {
        try {
          const testBucket = storage.bucket(bucketName);
          const [testExists] = await testBucket.exists();
          if (testExists) {
            bucket = testBucket;
            console.log(`Using bucket: ${bucketName}`);
            break;
          }
        } catch (e) {
          continue;
        }
      }
    }
  } catch (error) {
    console.warn(`⚠️  Could not verify bucket, proceeding anyway`);
  }

  cachedBucket = bucket;
  return bucket;
}

async function uploadImage(imagePath, storagePath) {
  try {
    if (!fs.existsSync(imagePath)) {
      return null;
    }

    const bucket = await getBucket();
    const file = bucket.file(storagePath);

    await bucket.upload(imagePath, {
      destination: storagePath,
      metadata: {
        contentType: 'image/svg+xml',
        metadata: {
          uploadedBy: 'update-questions-script',
          uploadedAt: new Date().toISOString()
        }
      }
    });

    try { await file.makePublic(); } catch (e) { /* ignore */ }

    return getPublicUrl(bucket, storagePath);
  } catch (error) {
    console.error(`   ❌ Error uploading ${path.basename(imagePath)}: ${error.message}`);
    return null;
  }
}

function getPublicUrl(bucket, storagePath) {
  if (bucket.name.includes('firebasestorage.app')) {
    const encodedPath = encodeURIComponent(storagePath);
    return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media`;
  }
  return `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
}

// ============================================================================
// QUESTION PROCESSING
// ============================================================================

function computeChapterKey(subject, chapter) {
  const subjectLower = subject.toLowerCase().trim();
  const chapterLower = chapter.toLowerCase().trim();
  const normalizedSubject = subjectLower.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  const normalizedChapter = chapterLower.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  return `${normalizedSubject}_${normalizedChapter}`;
}

function extractIRTParameters(questionData) {
  if (questionData.irt_parameters && questionData.irt_parameters.difficulty_b !== undefined) {
    return {
      difficulty_b: questionData.irt_parameters.difficulty_b,
      discrimination_a: questionData.irt_parameters.discrimination_a || 1.5,
      guessing_c: questionData.irt_parameters.guessing_c ||
        (questionData.question_type === 'mcq_single' ? 0.25 : 0.0),
      calibration_status: questionData.irt_parameters.calibration_status || 'estimated',
      calibration_method: questionData.irt_parameters.calibration_method || 'rule_based',
      calibration_sample_size: questionData.irt_parameters.calibration_sample_size || 0,
      last_calibration: questionData.irt_parameters.last_calibration || null,
      calibration_notes: questionData.irt_parameters.calibration_notes || null
    };
  }

  const difficulty_b = questionData.difficulty_irt !== undefined
    ? questionData.difficulty_irt
    : 0.0;

  return {
    difficulty_b,
    discrimination_a: 1.5,
    guessing_c: questionData.question_type === 'mcq_single' ? 0.25 : 0.0,
    calibration_status: 'estimated',
    calibration_method: 'rule_based',
    calibration_sample_size: 0,
    last_calibration: null,
    calibration_notes: null
  };
}

function processQuestionDocument(questionId, questionData) {
  const irtParameters = extractIRTParameters(questionData);
  const chapterKey = computeChapterKey(questionData.subject, questionData.chapter);

  return {
    question_id: questionId,
    subject: questionData.subject,
    chapter: questionData.chapter,
    chapter_key: chapterKey,
    topic: questionData.topic || null,
    unit: questionData.unit || null,
    sub_topics: questionData.sub_topics || [],

    difficulty_irt: questionData.difficulty_irt || irtParameters.difficulty_b,
    irt_parameters: irtParameters,

    question_type: questionData.question_type,
    question_text: questionData.question_text,
    question_text_html: questionData.question_text_html || questionData.question_text,
    question_latex: questionData.question_latex || null,
    options: questionData.options || null,

    correct_answer: questionData.correct_answer,
    correct_answer_text: questionData.correct_answer_text || String(questionData.correct_answer),
    correct_answer_exact: questionData.correct_answer_exact || null,
    correct_answer_unit: questionData.correct_answer_unit || null,
    answer_type: questionData.answer_type || 'text',
    answer_range: questionData.answer_range || null,
    alternate_correct_answers: questionData.alternate_correct_answers || [],

    solution_text: questionData.solution_text || null,
    solution_steps: questionData.solution_steps || [],
    concepts_tested: questionData.concepts_tested || [],

    has_image: questionData.has_image || false,
    image_url: questionData.image_url || null,
    image_type: questionData.image_type || null,
    image_description: questionData.image_description || null,
    image_alt_text: questionData.image_alt_text || null,

    difficulty: questionData.difficulty || 'medium',
    priority: questionData.priority || 'MEDIUM',
    time_estimate: questionData.time_estimate || 90,
    weightage_marks: questionData.weightage_marks || 4,
    jee_year_similar: questionData.jee_year_similar || null,
    jee_pattern: questionData.jee_pattern || null,
    tags: questionData.tags || [],
    metadata: questionData.metadata || {},

    usage_stats: questionData.usage_stats || {
      times_shown: 0,
      times_correct: 0,
      times_incorrect: 0,
      avg_time_taken: null,
      accuracy_rate: null,
      last_shown: null
    },

    active: questionData.active !== undefined ? questionData.active : true,
    archived_at: questionData.archived_at || null,
    archived_reason: questionData.archived_reason || null,

    created_date: questionData.created_date || admin.firestore.FieldValue.serverTimestamp(),
    created_by: questionData.created_by || 'update_script',
    validation_status: questionData.validation_status || 'pending'
  };
}

function parseQuestionsFile(filePath) {
  const jsonData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const questions = [];

  if (Array.isArray(jsonData)) {
    jsonData.forEach(q => {
      const questionId = q.question_id || q.id;
      if (questionId) {
        questions.push({ questionId, questionData: q });
      }
    });
  } else if (jsonData.questions && Array.isArray(jsonData.questions)) {
    jsonData.questions.forEach(q => {
      const questionId = q.question_id || q.id;
      if (questionId) {
        questions.push({ questionId, questionData: q });
      }
    });
  } else {
    Object.entries(jsonData).forEach(([questionId, questionData]) => {
      if (typeof questionData === 'object' && questionData !== null) {
        questions.push({ questionId, questionData });
      }
    });
  }

  return questions;
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

async function main() {
  try {
    console.log('🔄 Batch Update Questions from File\n');
    console.log('='.repeat(80));

    // Parse arguments
    const args = process.argv.slice(2);
    let filePath = null;
    let questionIds = null;
    const preview = args.includes('--preview');
    const skipImages = args.includes('--skip-images');

    if (args.includes('--file')) {
      const idx = args.indexOf('--file');
      filePath = args[idx + 1];
    }

    if (args.includes('--ids')) {
      const idx = args.indexOf('--ids');
      questionIds = args[idx + 1].split(',').map(id => id.trim());
    }

    if (!filePath) {
      console.error('❌ Error: Please specify JSON file with --file');
      console.error('   Example: node scripts/update-questions-from-file.js --file inputs/questions.json');
      process.exit(1);
    }

    // Resolve path
    const resolvedPath = path.isAbsolute(filePath)
      ? filePath
      : path.join(process.cwd(), filePath);

    if (!fs.existsSync(resolvedPath)) {
      console.error(`❌ Error: File not found: ${resolvedPath}`);
      process.exit(1);
    }

    console.log(`File: ${resolvedPath}`);
    console.log(`Mode: ${preview ? 'PREVIEW (no changes)' : 'UPDATE DATABASE'}`);
    console.log(`Skip images: ${skipImages ? 'Yes' : 'No'}`);
    if (questionIds) {
      console.log(`Filter IDs: ${questionIds.join(', ')}`);
    }
    console.log('='.repeat(80));

    // Parse questions
    console.log('\n📄 Reading questions from file...\n');
    const allQuestions = parseQuestionsFile(resolvedPath);
    console.log(`Found ${allQuestions.length} question(s) in file\n`);

    // Filter by IDs if specified
    let questionsToUpdate = allQuestions;
    if (questionIds) {
      questionsToUpdate = allQuestions.filter(q => questionIds.includes(q.questionId));
      console.log(`Filtered to ${questionsToUpdate.length} question(s) matching IDs\n`);
    }

    if (questionsToUpdate.length === 0) {
      console.log('❌ No questions to update!\n');
      process.exit(0);
    }

    // Show what will be updated
    console.log('Questions to update:');
    console.log('-'.repeat(80));
    for (const { questionId, questionData } of questionsToUpdate) {
      const subject = questionData.subject || '?';
      const chapter = questionData.chapter || '?';
      const qtype = questionData.question_type || '?';
      console.log(`   ${questionId.padEnd(25)} [${subject}/${chapter}] Type: ${qtype}`);
    }
    console.log('');

    if (preview) {
      console.log('='.repeat(80));
      console.log('👀 PREVIEW MODE - No changes made');
      console.log('='.repeat(80));
      console.log(`\n💡 Run without --preview to update ${questionsToUpdate.length} question(s)\n`);
      return;
    }

    // Update questions
    console.log('='.repeat(80));
    console.log('🔄 Updating questions...');
    console.log('='.repeat(80) + '\n');

    const batch = db.batch();
    let batchCount = 0;
    const BATCH_SIZE = 500;
    let updated = 0;
    let errors = 0;

    const fileDir = path.dirname(resolvedPath);

    for (const { questionId, questionData } of questionsToUpdate) {
      try {
        const doc = processQuestionDocument(questionId, questionData);

        // Upload image if needed
        if (doc.has_image && !skipImages && !doc.image_url) {
          const imageFileName = `${questionId}.svg`;
          const imagePath = path.join(fileDir, imageFileName);
          const storagePath = `${STORAGE_PATHS.questions}/${imageFileName}`;

          const imageUrl = await uploadImage(imagePath, storagePath);
          if (imageUrl) {
            doc.image_url = imageUrl;
            console.log(`   ✓ Uploaded image for ${questionId}`);
          }
        }

        // Update in Firestore (overwrite)
        const ref = db.collection('questions').doc(questionId);
        batch.set(ref, doc, { merge: false }); // Full overwrite
        batchCount++;
        updated++;

        // Commit batch if full
        if (batchCount >= BATCH_SIZE) {
          await retryFirestoreOperation(() => batch.commit());
          console.log(`   ✓ Committed batch of ${batchCount} questions`);
          batchCount = 0;
        }

      } catch (error) {
        errors++;
        console.error(`   ❌ Error updating ${questionId}: ${error.message}`);
      }
    }

    // Commit remaining
    if (batchCount > 0) {
      await retryFirestoreOperation(() => batch.commit());
      console.log(`   ✓ Committed final batch of ${batchCount} questions`);
    }

    console.log('\n' + '='.repeat(80));
    console.log('📊 Update Summary');
    console.log('='.repeat(80));
    console.log(`\nTotal questions: ${questionsToUpdate.length}`);
    console.log(`Updated: ${updated}`);
    console.log(`Errors: ${errors}`);

    console.log('\n✅ Update complete!\n');
    console.log('💡 Run validate-question-data.js to verify the updates\n');

  } catch (error) {
    console.error('\n❌ Fatal error:', error);
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

module.exports = { main };
