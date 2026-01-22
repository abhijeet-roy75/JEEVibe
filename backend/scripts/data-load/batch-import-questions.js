/**
 * Batch Import Questions Script
 *
 * Imports questions from a nested folder structure:
 *   Subject/
 *     Chapter/
 *       question_list.json (or questions.json)
 *       *.svg (image files)
 *
 * Supports both collections:
 * - questions (daily quiz / chapter practice)
 * - initial_assessment_questions (diagnostic assessment)
 *
 * Features:
 * - Processes nested Subject/Chapter folders
 * - Handles SVG images in each chapter folder
 * - Validates all questions before import
 * - Preview mode (dry run)
 * - Supports InitialAssessment special folder
 *
 * Usage:
 *   # Preview import (safe, no changes)
 *   node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load --preview
 *
 *   # Import all questions
 *   node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load
 *
 *   # Import specific subject only
 *   node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load --subject Physics
 *
 *   # Skip image upload (just import JSON data)
 *   node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load --skip-images
 *
 * Expected Folder Structure:
 *   inputs/fresh_load/
 *     Physics/
 *       Mechanics/
 *         question_list.json
 *         PHY_MECH_001.svg
 *         PHY_MECH_002.svg
 *       Thermodynamics/
 *         question_list.json
 *         *.svg
 *     Chemistry/
 *       ...
 *     Mathematics/
 *       ...
 *     InitialAssessment/    <- Special folder for assessment questions
 *       assessment_questions.json
 *       ASSESS_*.svg
 */

const path = require('path');
const fs = require('fs');
const { db, storage, admin } = require('../../src/config/firebase');
const { retryFirestoreOperation } = require('../../src/utils/firestoreRetry');

// ============================================================================
// CONFIGURATION
// ============================================================================

const BATCH_SIZE = 500;
const STORAGE_PATHS = {
  questions: 'questions/daily_quiz',
  initial_assessment_questions: 'questions/initial_assessment'
};

// JSON file names to look for in chapter folders
const QUESTION_FILE_NAMES = [
  'question_list.json',
  'questions.json',
  'question_bank.json',
  'assessment_questions.json'
];

// ============================================================================
// STORAGE OPERATIONS
// ============================================================================

let cachedBucket = null;

/**
 * Get bucket instance (cached for performance)
 */
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

/**
 * Upload image to Firebase Storage
 */
async function uploadImage(imagePath, storagePath) {
  try {
    if (!fs.existsSync(imagePath)) {
      return null;
    }

    const bucket = await getBucket();
    const file = bucket.file(storagePath);

    // Check if already exists
    try {
      const [exists] = await file.exists();
      if (exists) {
        try { await file.makePublic(); } catch (e) { /* ignore */ }
        return getPublicUrl(bucket, storagePath);
      }
    } catch (e) { /* proceed with upload */ }

    // Upload
    await bucket.upload(imagePath, {
      destination: storagePath,
      metadata: {
        contentType: 'image/svg+xml',
        metadata: {
          uploadedBy: 'batch-import-script',
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

/**
 * Get public URL for a storage path
 */
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

/**
 * Compute chapter_key from subject and chapter
 */
function computeChapterKey(subject, chapter) {
  const subjectLower = subject.toLowerCase().trim();
  const chapterLower = chapter.toLowerCase().trim();
  const normalizedSubject = subjectLower.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  const normalizedChapter = chapterLower.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  return `${normalizedSubject}_${normalizedChapter}`;
}

/**
 * Extract IRT parameters from question data
 */
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

/**
 * Validate question structure
 */
function validateQuestion(questionId, questionData) {
  const errors = [];

  if (!questionData.subject) errors.push('Missing subject');
  if (!questionData.chapter) errors.push('Missing chapter');
  if (!questionData.question_type) errors.push('Missing question_type');
  if (!questionData.question_text) errors.push('Missing question_text');
  if (!questionData.correct_answer && questionData.correct_answer !== 0) errors.push('Missing correct_answer');

  if (questionData.difficulty_irt === undefined &&
    (!questionData.irt_parameters || questionData.irt_parameters.difficulty_b === undefined)) {
    errors.push('Missing difficulty_irt or irt_parameters.difficulty_b');
  }

  if (questionData.question_type === 'mcq_single' && !questionData.options) {
    errors.push('MCQ questions must have options');
  }

  return { valid: errors.length === 0, errors };
}

/**
 * Process a single question for Firestore
 */
function processQuestionDocument(questionId, questionData, isAssessment = false) {
  const irtParameters = extractIRTParameters(questionData);
  const chapterKey = computeChapterKey(questionData.subject, questionData.chapter);

  const doc = {
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
    image_url: null, // Set during import
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

    usage_stats: {
      times_shown: 0,
      times_correct: 0,
      times_incorrect: 0,
      avg_time_taken: null,
      accuracy_rate: null,
      last_shown: null
    },

    // Lifecycle management
    active: true, // Set to false to archive without deleting
    archived_at: null,
    archived_reason: null,

    created_date: admin.firestore.FieldValue.serverTimestamp(),
    created_by: questionData.created_by || 'batch_import',
    validation_status: isAssessment ? 'approved' : (questionData.validation_status || 'pending')
  };

  if (isAssessment) {
    doc.assessment_id = 'initial_diagnostic_v1';
  }

  return doc;
}

// ============================================================================
// FOLDER DISCOVERY
// ============================================================================

/**
 * Discover subjects and chapters from folder structure
 */
function discoverFolders(rootDir) {
  const structure = {
    subjects: [],
    chapters: {},
    assessmentFolder: null
  };

  if (!fs.existsSync(rootDir)) {
    throw new Error(`Root directory not found: ${rootDir}`);
  }

  const items = fs.readdirSync(rootDir);

  for (const item of items) {
    const itemPath = path.join(rootDir, item);
    const stat = fs.statSync(itemPath);

    if (!stat.isDirectory()) continue;

    // Check for InitialAssessment special folder
    if (item.toLowerCase() === 'initialassessment' || item.toLowerCase() === 'initial_assessment') {
      structure.assessmentFolder = {
        name: item,
        path: itemPath
      };
      continue;
    }

    // Regular subject folder
    structure.subjects.push(item);
    structure.chapters[item] = [];

    // Find chapters within subject
    const subItems = fs.readdirSync(itemPath);
    for (const subItem of subItems) {
      const subItemPath = path.join(itemPath, subItem);
      const subStat = fs.statSync(subItemPath);

      if (!subStat.isDirectory()) continue;

      // Check if it has a question JSON file
      const hasQuestionFile = QUESTION_FILE_NAMES.some(name =>
        fs.existsSync(path.join(subItemPath, name))
      );

      if (hasQuestionFile) {
        structure.chapters[item].push({
          name: subItem,
          path: subItemPath
        });
      }
    }
  }

  return structure;
}

/**
 * Find question JSON file in a folder
 */
function findQuestionFile(folderPath) {
  for (const name of QUESTION_FILE_NAMES) {
    const filePath = path.join(folderPath, name);
    if (fs.existsSync(filePath)) {
      return filePath;
    }
  }
  return null;
}

/**
 * Parse questions from JSON file
 */
function parseQuestionsFile(filePath) {
  const jsonData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const questions = [];

  if (Array.isArray(jsonData)) {
    // Array format: [{ question_id: "Q1", ... }]
    jsonData.forEach(q => {
      const questionId = q.question_id || q.id;
      if (questionId) {
        questions.push({ questionId, questionData: q });
      }
    });
  } else if (jsonData.questions && Array.isArray(jsonData.questions)) {
    // Object with questions array: { questions: [...] }
    jsonData.questions.forEach(q => {
      const questionId = q.question_id || q.id;
      if (questionId) {
        questions.push({ questionId, questionData: q });
      }
    });
  } else {
    // Object format: { "Q1": {...}, "Q2": {...} }
    Object.entries(jsonData).forEach(([questionId, questionData]) => {
      if (typeof questionData === 'object' && questionData !== null) {
        questions.push({ questionId, questionData });
      }
    });
  }

  return questions;
}

// ============================================================================
// IMPORT OPERATIONS
// ============================================================================

/**
 * Import a chapter's questions
 */
async function importChapter(chapterPath, subject, chapterName, options) {
  const results = {
    total: 0,
    imported: 0,
    skipped: 0,
    errors: 0,
    errorDetails: []
  };

  const jsonFile = findQuestionFile(chapterPath);
  if (!jsonFile) {
    console.log(`   ⚠️  No question file found in ${chapterName}`);
    return results;
  }

  console.log(`   📖 Processing ${chapterName}...`);

  const questions = parseQuestionsFile(jsonFile);
  results.total = questions.length;

  if (questions.length === 0) {
    console.log(`   ⚠️  No questions found in ${chapterName}`);
    return results;
  }

  // Check which questions already exist
  const questionIds = questions.map(q => q.questionId);
  const questionRefs = questionIds.map(id => db.collection('questions').doc(id));
  const existingDocs = await retryFirestoreOperation(() => db.getAll(...questionRefs));
  const existingIds = new Set(existingDocs.filter(doc => doc.exists).map(doc => doc.id));

  // Process questions
  const batch = db.batch();
  let batchCount = 0;

  for (const { questionId, questionData } of questions) {
    try {
      // Skip existing
      if (existingIds.has(questionId)) {
        results.skipped++;
        continue;
      }

      // Validate
      const validation = validateQuestion(questionId, questionData);
      if (!validation.valid) {
        results.errors++;
        results.errorDetails.push({ questionId, error: validation.errors.join(', ') });
        continue;
      }

      if (options.preview) {
        results.imported++;
        continue;
      }

      // Process document
      const doc = processQuestionDocument(questionId, questionData, false);

      // Upload image if needed
      if (doc.has_image && !options.skipImages) {
        const imageFileName = `${questionId}.svg`;
        const imagePath = path.join(chapterPath, imageFileName);
        const storagePath = `${STORAGE_PATHS.questions}/${imageFileName}`;

        const imageUrl = await uploadImage(imagePath, storagePath);
        doc.image_url = imageUrl;
      }

      // Add to batch
      const ref = db.collection('questions').doc(questionId);
      batch.set(ref, doc);
      batchCount++;
      results.imported++;

      // Commit batch if full
      if (batchCount >= BATCH_SIZE) {
        await retryFirestoreOperation(() => batch.commit());
        batchCount = 0;
      }

    } catch (error) {
      results.errors++;
      results.errorDetails.push({ questionId, error: error.message });
    }
  }

  // Commit remaining
  if (batchCount > 0 && !options.preview) {
    await retryFirestoreOperation(() => batch.commit());
  }

  console.log(`      ✅ ${results.imported} imported, ${results.skipped} skipped, ${results.errors} errors`);

  return results;
}

/**
 * Import initial assessment questions
 */
async function importAssessment(folderPath, options) {
  const results = {
    total: 0,
    imported: 0,
    skipped: 0,
    errors: 0,
    errorDetails: []
  };

  const jsonFile = findQuestionFile(folderPath);
  if (!jsonFile) {
    console.log(`   ⚠️  No question file found in InitialAssessment`);
    return results;
  }

  console.log(`   📖 Processing InitialAssessment...`);

  const questions = parseQuestionsFile(jsonFile);
  results.total = questions.length;

  if (questions.length === 0) {
    return results;
  }

  // Check which questions already exist
  const questionIds = questions.map(q => q.questionId);
  const questionRefs = questionIds.map(id => db.collection('initial_assessment_questions').doc(id));
  const existingDocs = await retryFirestoreOperation(() => db.getAll(...questionRefs));
  const existingIds = new Set(existingDocs.filter(doc => doc.exists).map(doc => doc.id));

  // Process questions
  const batch = db.batch();
  let batchCount = 0;

  for (const { questionId, questionData } of questions) {
    try {
      if (existingIds.has(questionId)) {
        results.skipped++;
        continue;
      }

      const validation = validateQuestion(questionId, questionData);
      if (!validation.valid) {
        results.errors++;
        results.errorDetails.push({ questionId, error: validation.errors.join(', ') });
        continue;
      }

      if (options.preview) {
        results.imported++;
        continue;
      }

      const doc = processQuestionDocument(questionId, questionData, true);

      // Upload image if needed
      if (doc.has_image && !options.skipImages) {
        const imageFileName = `${questionId}.svg`;
        const imagePath = path.join(folderPath, imageFileName);
        const storagePath = `${STORAGE_PATHS.initial_assessment_questions}/${imageFileName}`;

        const imageUrl = await uploadImage(imagePath, storagePath);
        doc.image_url = imageUrl;
      }

      const ref = db.collection('initial_assessment_questions').doc(questionId);
      batch.set(ref, doc);
      batchCount++;
      results.imported++;

      if (batchCount >= BATCH_SIZE) {
        await retryFirestoreOperation(() => batch.commit());
        batchCount = 0;
      }

    } catch (error) {
      results.errors++;
      results.errorDetails.push({ questionId, error: error.message });
    }
  }

  if (batchCount > 0 && !options.preview) {
    await retryFirestoreOperation(() => batch.commit());
  }

  console.log(`      ✅ ${results.imported} imported, ${results.skipped} skipped, ${results.errors} errors`);

  return results;
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

async function main() {
  try {
    console.log('📦 Batch Import Questions Script\n');
    console.log('='.repeat(60));

    // Parse arguments
    const args = process.argv.slice(2);
    const options = {
      preview: args.includes('--preview'),
      skipImages: args.includes('--skip-images'),
      dir: null,
      subject: null
    };

    // Parse --dir
    if (args.includes('--dir')) {
      const idx = args.indexOf('--dir');
      options.dir = args[idx + 1];
    }

    // Parse --subject
    if (args.includes('--subject')) {
      const idx = args.indexOf('--subject');
      options.subject = args[idx + 1];
    }

    if (!options.dir) {
      console.error('❌ Error: Please specify root directory with --dir');
      console.error('   Example: node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load');
      process.exit(1);
    }

    // Resolve path
    const rootDir = path.isAbsolute(options.dir)
      ? options.dir
      : path.join(process.cwd(), options.dir);

    console.log(`Root directory: ${rootDir}`);
    console.log(`Mode: ${options.preview ? 'PREVIEW (no changes)' : 'IMPORT'}`);
    console.log(`Skip images: ${options.skipImages ? 'Yes' : 'No'}`);
    console.log('='.repeat(60));

    // Discover folder structure
    console.log('\n🔍 Discovering folder structure...\n');
    const structure = discoverFolders(rootDir);

    console.log('📊 Found:');
    for (const subject of structure.subjects) {
      console.log(`   ${subject}: ${structure.chapters[subject].length} chapters`);
      for (const chapter of structure.chapters[subject]) {
        console.log(`      └─ ${chapter.name}`);
      }
    }
    if (structure.assessmentFolder) {
      console.log(`   InitialAssessment: 1 folder`);
    }

    // Filter by subject if specified
    let subjectsToProcess = structure.subjects;
    if (options.subject) {
      subjectsToProcess = structure.subjects.filter(
        s => s.toLowerCase() === options.subject.toLowerCase()
      );
      if (subjectsToProcess.length === 0) {
        console.error(`\n❌ Subject not found: ${options.subject}`);
        console.error(`   Available: ${structure.subjects.join(', ')}`);
        process.exit(1);
      }
    }

    // Import
    console.log('\n' + '='.repeat(60));
    console.log(options.preview ? '👀 PREVIEW MODE' : '🚀 Starting import...');
    console.log('='.repeat(60));

    const allResults = {
      questions: { total: 0, imported: 0, skipped: 0, errors: 0 },
      assessment: { total: 0, imported: 0, skipped: 0, errors: 0 }
    };

    // Import subjects
    for (const subject of subjectsToProcess) {
      console.log(`\n📚 ${subject}`);

      for (const chapter of structure.chapters[subject]) {
        const results = await importChapter(chapter.path, subject, chapter.name, options);
        allResults.questions.total += results.total;
        allResults.questions.imported += results.imported;
        allResults.questions.skipped += results.skipped;
        allResults.questions.errors += results.errors;
      }
    }

    // Import assessment
    if (structure.assessmentFolder && !options.subject) {
      console.log(`\n📋 InitialAssessment`);
      const results = await importAssessment(structure.assessmentFolder.path, options);
      allResults.assessment.total += results.total;
      allResults.assessment.imported += results.imported;
      allResults.assessment.skipped += results.skipped;
      allResults.assessment.errors += results.errors;
    }

    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 Import Summary');
    console.log('='.repeat(60));

    console.log('\nQuestions collection:');
    console.log(`   Total: ${allResults.questions.total}`);
    console.log(`   Imported: ${allResults.questions.imported}`);
    console.log(`   Skipped: ${allResults.questions.skipped}`);
    console.log(`   Errors: ${allResults.questions.errors}`);

    if (allResults.assessment.total > 0) {
      console.log('\nInitial Assessment collection:');
      console.log(`   Total: ${allResults.assessment.total}`);
      console.log(`   Imported: ${allResults.assessment.imported}`);
      console.log(`   Skipped: ${allResults.assessment.skipped}`);
      console.log(`   Errors: ${allResults.assessment.errors}`);
    }

    if (options.preview) {
      console.log('\n💡 To actually import, run without --preview');
    }

    console.log('\n✅ Import complete!\n');

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

module.exports = {
  discoverFolders,
  importChapter,
  importAssessment
};
