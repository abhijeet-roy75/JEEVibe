/**
 * Batch Import Questions Script
 *
 * Imports questions from a nested folder structure:
 *   Subject/
 *     Chapter/
 *       *.json (any JSON file with questions)
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
 * - Validate mode (checks for missing images & data issues)
 * - Supports InitialAssessment special folder
 *
 * Usage:
 *   # VALIDATE ONLY - Check for missing images & data issues (RECOMMENDED FIRST STEP)
 *   node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load --validate
 *
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
 *         questions_mechanics.json   <- Any JSON filename accepted
 *         PHY_MECH_001.svg
 *         PHY_MECH_002.svg
 *       Thermodynamics/
 *         *.json                     <- Any JSON filename accepted
 *         *.svg
 *     Chemistry/
 *       ...
 *     Mathematics/
 *       ...
 *     InitialAssessment/             <- Special folder for assessment questions
 *       questions.json
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

      // Check if it has any JSON file (question file)
      const jsonFiles = fs.readdirSync(subItemPath).filter(f =>
        f.endsWith('.json') && !f.startsWith('.')
      );

      if (jsonFiles.length > 0) {
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
 * Accepts any JSON file (not just specific names)
 */
function findQuestionFile(folderPath) {
  // First try the standard names for backwards compatibility
  for (const name of QUESTION_FILE_NAMES) {
    const filePath = path.join(folderPath, name);
    if (fs.existsSync(filePath)) {
      return filePath;
    }
  }

  // Otherwise, find any JSON file in the folder
  const files = fs.readdirSync(folderPath);
  const jsonFiles = files.filter(f => f.endsWith('.json') && !f.startsWith('.'));

  if (jsonFiles.length > 0) {
    // If multiple JSON files, prefer ones with "question" in the name
    const questionFile = jsonFiles.find(f => f.toLowerCase().includes('question'));
    return path.join(folderPath, questionFile || jsonFiles[0]);
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
// VALIDATION OPERATIONS (No DB changes)
// ============================================================================

/**
 * Validate a chapter's questions and images (no DB operations)
 * Returns detailed report of all issues found
 */
function validateChapter(chapterPath, subject, chapterName) {
  const report = {
    subject,
    chapter: chapterName,
    path: chapterPath,
    totalQuestions: 0,
    validQuestions: 0,
    issues: []
  };

  const jsonFile = findQuestionFile(chapterPath);
  if (!jsonFile) {
    report.issues.push({
      type: 'MISSING_JSON',
      severity: 'ERROR',
      message: `No JSON file found in folder`
    });
    return report;
  }

  let questions;
  try {
    questions = parseQuestionsFile(jsonFile);
  } catch (error) {
    report.issues.push({
      type: 'INVALID_JSON',
      severity: 'ERROR',
      message: `Failed to parse JSON: ${error.message}`
    });
    return report;
  }

  report.totalQuestions = questions.length;

  if (questions.length === 0) {
    report.issues.push({
      type: 'EMPTY_FILE',
      severity: 'WARNING',
      message: 'No questions found in file'
    });
    return report;
  }

  // Validate each question
  for (const { questionId, questionData } of questions) {
    // 1. Validate required fields
    const validation = validateQuestion(questionId, questionData);
    if (!validation.valid) {
      report.issues.push({
        type: 'INVALID_QUESTION',
        severity: 'ERROR',
        questionId,
        message: validation.errors.join(', ')
      });
      continue;
    }

    // 2. Check for missing images
    if (questionData.has_image === true) {
      const imageFileName = `${questionId}.svg`;
      const imagePath = path.join(chapterPath, imageFileName);

      if (!fs.existsSync(imagePath)) {
        report.issues.push({
          type: 'MISSING_IMAGE',
          severity: 'ERROR',
          questionId,
          expectedPath: imagePath,
          message: `Question has_image=true but image file not found: ${imageFileName}`
        });
        continue;
      }

      // Check if image file is not empty
      const stats = fs.statSync(imagePath);
      if (stats.size === 0) {
        report.issues.push({
          type: 'EMPTY_IMAGE',
          severity: 'ERROR',
          questionId,
          message: `Image file is empty (0 bytes): ${imageFileName}`
        });
        continue;
      }
    }

    // 3. Check for orphan images (image exists but has_image is false/missing)
    const potentialImage = path.join(chapterPath, `${questionId}.svg`);
    if (fs.existsSync(potentialImage) && !questionData.has_image) {
      report.issues.push({
        type: 'ORPHAN_IMAGE',
        severity: 'WARNING',
        questionId,
        message: `Image file exists but has_image is not true - image won't be uploaded`
      });
    }

    // 4. Validate MCQ options
    if (questionData.question_type === 'mcq_single') {
      if (!questionData.options || Object.keys(questionData.options).length < 2) {
        report.issues.push({
          type: 'INVALID_OPTIONS',
          severity: 'ERROR',
          questionId,
          message: 'MCQ question must have at least 2 options'
        });
        continue;
      }
    }

    // 5. Validate correct_answer matches options for MCQ
    if (questionData.question_type === 'mcq_single' && questionData.options) {
      const optionKeys = Array.isArray(questionData.options)
        ? questionData.options.map((_, i) => String.fromCharCode(65 + i))
        : Object.keys(questionData.options);

      if (!optionKeys.includes(String(questionData.correct_answer))) {
        report.issues.push({
          type: 'INVALID_ANSWER',
          severity: 'WARNING',
          questionId,
          message: `correct_answer "${questionData.correct_answer}" not in options: [${optionKeys.join(', ')}]`
        });
      }
    }

    report.validQuestions++;
  }

  return report;
}

/**
 * Validate initial assessment folder
 */
function validateAssessment(folderPath) {
  return validateChapter(folderPath, 'Assessment', 'InitialAssessment');
}

/**
 * Run full validation and generate report
 */
function runValidation(rootDir, subjectsToProcess, structure) {
  console.log('\n' + '='.repeat(60));
  console.log('🔍 VALIDATION MODE - Checking for issues (no DB changes)');
  console.log('='.repeat(60));

  const allReports = [];
  const summary = {
    totalChapters: 0,
    totalQuestions: 0,
    validQuestions: 0,
    errors: 0,
    warnings: 0,
    missingImages: [],
    invalidQuestions: [],
    otherIssues: []
  };

  // Validate subjects
  for (const subject of subjectsToProcess) {
    console.log(`\n📚 ${subject}`);

    for (const chapter of structure.chapters[subject]) {
      const report = validateChapter(chapter.path, subject, chapter.name);
      allReports.push(report);
      summary.totalChapters++;
      summary.totalQuestions += report.totalQuestions;
      summary.validQuestions += report.validQuestions;

      const errorCount = report.issues.filter(i => i.severity === 'ERROR').length;
      const warnCount = report.issues.filter(i => i.severity === 'WARNING').length;

      if (errorCount > 0 || warnCount > 0) {
        console.log(`   ❌ ${chapter.name}: ${report.totalQuestions} questions, ${errorCount} errors, ${warnCount} warnings`);
      } else {
        console.log(`   ✅ ${chapter.name}: ${report.totalQuestions} questions - OK`);
      }

      // Categorize issues
      for (const issue of report.issues) {
        if (issue.severity === 'ERROR') summary.errors++;
        if (issue.severity === 'WARNING') summary.warnings++;

        if (issue.type === 'MISSING_IMAGE') {
          summary.missingImages.push({
            subject,
            chapter: chapter.name,
            questionId: issue.questionId,
            expectedPath: issue.expectedPath
          });
        } else if (issue.type === 'INVALID_QUESTION') {
          summary.invalidQuestions.push({
            subject,
            chapter: chapter.name,
            questionId: issue.questionId,
            error: issue.message
          });
        } else {
          summary.otherIssues.push({
            subject,
            chapter: chapter.name,
            ...issue
          });
        }
      }
    }
  }

  // Validate assessment
  if (structure.assessmentFolder) {
    console.log(`\n📋 InitialAssessment`);
    const report = validateAssessment(structure.assessmentFolder.path);
    allReports.push(report);
    summary.totalChapters++;
    summary.totalQuestions += report.totalQuestions;
    summary.validQuestions += report.validQuestions;

    const errorCount = report.issues.filter(i => i.severity === 'ERROR').length;
    const warnCount = report.issues.filter(i => i.severity === 'WARNING').length;

    if (errorCount > 0 || warnCount > 0) {
      console.log(`   ❌ InitialAssessment: ${report.totalQuestions} questions, ${errorCount} errors, ${warnCount} warnings`);
    } else {
      console.log(`   ✅ InitialAssessment: ${report.totalQuestions} questions - OK`);
    }

    for (const issue of report.issues) {
      if (issue.severity === 'ERROR') summary.errors++;
      if (issue.severity === 'WARNING') summary.warnings++;

      if (issue.type === 'MISSING_IMAGE') {
        summary.missingImages.push({
          subject: 'Assessment',
          chapter: 'InitialAssessment',
          questionId: issue.questionId,
          expectedPath: issue.expectedPath
        });
      } else if (issue.type === 'INVALID_QUESTION') {
        summary.invalidQuestions.push({
          subject: 'Assessment',
          chapter: 'InitialAssessment',
          questionId: issue.questionId,
          error: issue.message
        });
      } else {
        summary.otherIssues.push({
          subject: 'Assessment',
          chapter: 'InitialAssessment',
          ...issue
        });
      }
    }
  }

  // Print detailed report
  console.log('\n' + '='.repeat(60));
  console.log('📊 VALIDATION SUMMARY');
  console.log('='.repeat(60));

  console.log(`\nTotal chapters: ${summary.totalChapters}`);
  console.log(`Total questions: ${summary.totalQuestions}`);
  console.log(`Valid questions: ${summary.validQuestions}`);
  console.log(`Errors: ${summary.errors}`);
  console.log(`Warnings: ${summary.warnings}`);

  // Missing images detail
  if (summary.missingImages.length > 0) {
    console.log('\n' + '-'.repeat(60));
    console.log(`🖼️  MISSING IMAGES (${summary.missingImages.length}):`);
    console.log('-'.repeat(60));
    for (const img of summary.missingImages) {
      console.log(`   ${img.subject}/${img.chapter}/${img.questionId}.svg`);
    }
  }

  // Invalid questions detail
  if (summary.invalidQuestions.length > 0) {
    console.log('\n' + '-'.repeat(60));
    console.log(`❌ INVALID QUESTIONS (${summary.invalidQuestions.length}):`);
    console.log('-'.repeat(60));
    for (const q of summary.invalidQuestions) {
      console.log(`   ${q.subject}/${q.chapter}/${q.questionId}: ${q.error}`);
    }
  }

  // Other issues
  if (summary.otherIssues.length > 0) {
    console.log('\n' + '-'.repeat(60));
    console.log(`⚠️  OTHER ISSUES (${summary.otherIssues.length}):`);
    console.log('-'.repeat(60));
    for (const issue of summary.otherIssues) {
      const prefix = issue.severity === 'ERROR' ? '❌' : '⚠️';
      const location = issue.questionId
        ? `${issue.subject}/${issue.chapter}/${issue.questionId}`
        : `${issue.subject}/${issue.chapter}`;
      console.log(`   ${prefix} ${location}: [${issue.type}] ${issue.message}`);
    }
  }

  // Final verdict
  console.log('\n' + '='.repeat(60));
  if (summary.errors === 0) {
    console.log('✅ VALIDATION PASSED - Ready for import!');
    console.log('   Run without --validate to import');
  } else {
    console.log('❌ VALIDATION FAILED - Fix errors before importing');
    console.log(`   ${summary.errors} error(s) must be fixed`);
  }
  console.log('='.repeat(60) + '\n');

  return summary;
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
      validate: args.includes('--validate'),
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
    const modeDisplay = options.validate ? 'VALIDATE (check only)' :
                        options.preview ? 'PREVIEW (no changes)' : 'IMPORT';
    console.log(`Mode: ${modeDisplay}`);
    if (!options.validate) {
      console.log(`Skip images: ${options.skipImages ? 'Yes' : 'No'}`);
    }
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

    // VALIDATE MODE - Just check for issues, no DB operations
    if (options.validate) {
      const summary = runValidation(rootDir, subjectsToProcess, structure);
      process.exit(summary.errors > 0 ? 1 : 0);
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
      console.log('💡 To validate first (check for missing images), use --validate');
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
  importAssessment,
  validateChapter,
  runValidation
};
