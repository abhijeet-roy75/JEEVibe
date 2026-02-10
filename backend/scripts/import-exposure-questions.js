/**
 * Import Chapter Exposure Questions
 *
 * Imports exposure questions from JSON files in inputs/chapter_exposure/
 * Each file contains 5 questions used for the chapter unlock quiz feature.
 *
 * Usage: node backend/scripts/import-exposure-questions.js
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

/**
 * Compute chapter_key from subject and chapter name
 * Reuses normalization logic from thetaCalculationService.js
 */
function computeChapterKey(subject, chapterName) {
  const subjectLower = subject.toLowerCase().trim();
  const chapterLower = chapterName.toLowerCase().trim();

  // Normalize: remove special chars, convert spaces to underscores
  const normalizedSubject = subjectLower.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  const normalizedChapter = chapterLower.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');

  return `${normalizedSubject}_${normalizedChapter}`;
}

/**
 * Validate question object
 */
function validateQuestion(question, filename) {
  const errors = [];

  // Required fields
  const requiredFields = [
    'question_id',
    'subject',
    'chapter',
    'question_text',
    'options',
    'correct_answer'
  ];

  for (const field of requiredFields) {
    if (!question[field]) {
      errors.push(`Missing required field: ${field}`);
    }
  }

  // Validate options (should be 5: 4 answers + "I haven't studied")
  if (question.options && question.options.length !== 5) {
    errors.push(`Expected 5 options, found ${question.options.length}`);
  }

  // Validate correct_answer is valid option
  if (question.correct_answer && question.options) {
    const validOptions = question.options.map(opt => opt.option_id);
    if (!validOptions.includes(question.correct_answer)) {
      errors.push(`correct_answer "${question.correct_answer}" not in options [${validOptions.join(', ')}]`);
    }
  }

  return errors;
}

/**
 * Import exposure questions from a single file
 */
async function importFile(filePath, filename) {
  console.log(`\n📄 Processing: ${filename}`);

  try {
    // Read and parse JSON
    const fileContent = fs.readFileSync(filePath, 'utf8');
    const fileData = JSON.parse(fileContent);

    // Extract questions (files use object map format)
    const questions = Object.values(fileData);

    if (questions.length === 0) {
      return { success: false, error: 'No questions found in file', count: 0 };
    }

    if (questions.length !== 5) {
      console.log(`   ⚠️  Warning: Expected 5 questions, found ${questions.length}`);
    }

    // Derive chapter_key from first question
    const firstQuestion = questions[0];
    const chapterKey = computeChapterKey(firstQuestion.subject, firstQuestion.chapter);

    console.log(`   Subject: ${firstQuestion.subject}`);
    console.log(`   Chapter: ${firstQuestion.chapter}`);
    console.log(`   Chapter Key: ${chapterKey}`);
    console.log(`   Questions: ${questions.length}`);

    // Validate all questions
    const allErrors = [];
    questions.forEach((q, idx) => {
      const errors = validateQuestion(q, filename);
      if (errors.length > 0) {
        allErrors.push(`Question ${idx + 1} (${q.question_id}): ${errors.join(', ')}`);
      }
    });

    if (allErrors.length > 0) {
      console.log(`   ❌ Validation errors:`);
      allErrors.forEach(err => console.log(`      - ${err}`));
      return { success: false, error: 'Validation failed', count: 0 };
    }

    // Batch write to Firestore
    const batch = db.batch();

    questions.forEach(question => {
      const docRef = db
        .collection('chapter_exposure')
        .doc(chapterKey)
        .collection('questions')
        .doc(question.question_id);

      batch.set(docRef, {
        ...question,
        chapter_key: chapterKey, // Add normalized key
        active: true,
        imported_at: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    await batch.commit();

    console.log(`   ✅ Imported ${questions.length} questions`);

    return { success: true, count: questions.length, chapterKey };

  } catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
    return { success: false, error: error.message, count: 0 };
  }
}

/**
 * Main import function
 */
async function importAllExposureQuestions() {
  console.log('='.repeat(60));
  console.log('IMPORTING CHAPTER EXPOSURE QUESTIONS');
  console.log('='.repeat(60));

  // Get input directory
  const inputDir = path.join(__dirname, '../../inputs/chapter_exposure');

  if (!fs.existsSync(inputDir)) {
    console.error(`❌ Input directory not found: ${inputDir}`);
    process.exit(1);
  }

  // Get all JSON files
  const files = fs.readdirSync(inputDir)
    .filter(f => f.endsWith('.json'))
    .sort();

  console.log(`\nFound ${files.length} JSON files\n`);

  // Track results
  let totalImported = 0;
  let successCount = 0;
  let failCount = 0;
  const errors = [];
  const chapterKeys = new Set();

  // Process each file
  for (const file of files) {
    const filePath = path.join(inputDir, file);
    const result = await importFile(filePath, file);

    if (result.success) {
      totalImported += result.count;
      successCount++;
      chapterKeys.add(result.chapterKey);
    } else {
      failCount++;
      errors.push(`${file}: ${result.error}`);
    }
  }

  // Print summary
  console.log('\n' + '='.repeat(60));
  console.log('IMPORT SUMMARY');
  console.log('='.repeat(60));
  console.log(`Files processed: ${files.length}`);
  console.log(`Files imported: ${successCount} ✅`);
  console.log(`Files failed: ${failCount} ❌`);
  console.log(`Total questions imported: ${totalImported}`);
  console.log(`Unique chapters: ${chapterKeys.size}`);
  console.log(`Expected questions: ${files.length * 5} (${files.length} files × 5 questions)`);

  if (totalImported === files.length * 5) {
    console.log('\n✅ All questions imported successfully!');
  } else {
    console.log(`\n⚠️  Warning: Expected ${files.length * 5} questions, imported ${totalImported}`);
  }

  if (errors.length > 0) {
    console.log('\n' + '='.repeat(60));
    console.log(`ERRORS (${errors.length})`);
    console.log('='.repeat(60));
    errors.forEach(err => console.log(`  - ${err}`));
  }

  console.log('\n' + '='.repeat(60));
  console.log('FIRESTORE COLLECTION STRUCTURE:');
  console.log('='.repeat(60));
  console.log('chapter_exposure/');
  console.log('  {chapter_key}/');
  console.log('    questions/');
  console.log('      {question_id} (5 questions per chapter)');
  console.log('\nExample: chapter_exposure/physics_electrostatics/questions/PHY_ELEC_EXP_001');

  return {
    totalFiles: files.length,
    successCount,
    failCount,
    totalImported,
    uniqueChapters: chapterKeys.size
  };
}

// Run import
importAllExposureQuestions()
  .then(result => {
    console.log('\n✅ Import completed');
    process.exit(result.failCount > 0 ? 1 : 0);
  })
  .catch(error => {
    console.error('\n❌ Import failed:', error);
    process.exit(1);
  });
