/**
 * Single Question Update Script
 *
 * Updates a single question in Firestore from a JSON file.
 *
 * Features:
 * 1. Reads question data from JSON file
 * 2. Validates question structure
 * 3. Computes chapter_key from subject + chapter if needed
 * 4. Uploads image to Firebase Storage (if has_image: true)
 * 5. Updates question in Firestore (merges with existing data)
 *
 * Usage:
 *   node backend/scripts/update-single-question.js <question-id> <json-file-path>
 *
 * Examples:
 *   node backend/scripts/update-single-question.js CHEM_PURC_E_028 inputs/questions/CHEM_PURC_E_028.json
 *   node backend/scripts/update-single-question.js PHY_MECH_M_001 inputs/questions/physics_mechanics.json
 */

const path = require('path');
const fs = require('fs');
const { db, storage, admin } = require('../src/config/firebase');
const { retryFirestoreOperation } = require('../src/utils/firestoreRetry');

// ============================================================================
// CONFIGURATION
// ============================================================================

const STORAGE_BASE_PATH = 'questions/daily_quiz'; // Firebase Storage path

// Chapter key mappings (from thetaCalculationService.js)
const SUBJECT_PREFIXES = {
  'Physics': 'physics',
  'Chemistry': 'chemistry',
  'Mathematics': 'mathematics',
  'Math': 'mathematics', // Alternative
};

/**
 * Generate chapter_key from subject and chapter name
 * Converts "Physics" + "Electrostatics" -> "physics_electrostatics"
 */
function generateChapterKey(subject, chapter) {
  const subjectPrefix = SUBJECT_PREFIXES[subject] || subject.toLowerCase();
  const chapterSlug = chapter
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');

  return `${subjectPrefix}_${chapterSlug}`;
}

// ============================================================================
// IMAGE UPLOAD
// ============================================================================

/**
 * Upload image to Firebase Storage
 * Returns public URL or null if upload fails
 */
async function uploadImage(questionId, imageFileName, imagesDir) {
  try {
    const localImagePath = path.join(imagesDir, imageFileName);

    // Check if file exists
    if (!fs.existsSync(localImagePath)) {
      console.warn(`  ⚠️  Image file not found: ${localImagePath}`);
      return null;
    }

    // Get bucket
    let bucket = storage.bucket();

    // Storage path: questions/daily_quiz/{questionId}.svg
    const storagePath = `${STORAGE_BASE_PATH}/${questionId}.svg`;
    const file = bucket.file(storagePath);

    // Upload file
    await file.save(fs.readFileSync(localImagePath), {
      metadata: {
        contentType: 'image/svg+xml',
        metadata: {
          questionId: questionId,
        },
      },
      public: true,
    });

    // Make file publicly accessible
    await file.makePublic();

    // Return public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
    console.log(`  ✅ Image uploaded: ${publicUrl}`);

    return publicUrl;
  } catch (error) {
    console.error(`  ❌ Image upload failed for ${questionId}:`, error.message);
    return null;
  }
}

// ============================================================================
// QUESTION VALIDATION
// ============================================================================

/**
 * Validate question structure
 */
function validateQuestion(question, questionId) {
  const required = ['subject', 'chapter', 'question_type'];
  const missing = required.filter(field => !question[field]);

  if (missing.length > 0) {
    throw new Error(`Question ${questionId} missing required fields: ${missing.join(', ')}`);
  }

  // Validate question_type
  if (!['mcq_single', 'numerical'].includes(question.question_type)) {
    throw new Error(`Question ${questionId} has invalid question_type: ${question.question_type}`);
  }

  // MCQ questions should have options and correct_answer
  if (question.question_type === 'mcq_single') {
    if (!question.options || question.options.length === 0) {
      throw new Error(`MCQ question ${questionId} missing options`);
    }
    if (!question.correct_answer) {
      throw new Error(`MCQ question ${questionId} missing correct_answer`);
    }
  }

  // Numerical questions should have correct_answer or answer_range
  if (question.question_type === 'numerical') {
    if (!question.correct_answer && !question.answer_range && !question.correct_answer_exact) {
      throw new Error(`Numerical question ${questionId} missing answer data`);
    }
  }

  return true;
}

// ============================================================================
// QUESTION PROCESSING
// ============================================================================

/**
 * Process and prepare question data for Firestore
 */
function processQuestion(question, questionId) {
  // Compute chapter_key if not present
  if (!question.chapter_key) {
    question.chapter_key = generateChapterKey(question.subject, question.chapter);
  }

  // Ensure question_id is set
  question.question_id = questionId;

  // Set active flag (default true)
  if (question.active === undefined) {
    question.active = true;
  }

  // Add timestamps
  question.updated_at = admin.firestore.FieldValue.serverTimestamp();

  return question;
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

async function updateSingleQuestion() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.error('❌ Usage: node update-single-question.js <question-id> <json-file-path>');
    console.error('');
    console.error('Examples:');
    console.error('  node backend/scripts/update-single-question.js CHEM_PURC_E_028 inputs/questions/CHEM_PURC_E_028.json');
    console.error('  node backend/scripts/update-single-question.js PHY_MECH_M_001 inputs/questions/physics_mechanics.json');
    process.exit(1);
  }

  const questionId = args[0];
  const jsonFilePath = args[1];

  console.log('\n🔄 Single Question Update');
  console.log('═══════════════════════════════════════════════════════════');
  console.log(`Question ID: ${questionId}`);
  console.log(`JSON File:   ${jsonFilePath}`);
  console.log('═══════════════════════════════════════════════════════════\n');

  // Resolve file path
  const resolvedPath = path.isAbsolute(jsonFilePath)
    ? jsonFilePath
    : path.join(process.cwd(), jsonFilePath);

  // Check if file exists
  if (!fs.existsSync(resolvedPath)) {
    console.error(`❌ File not found: ${resolvedPath}`);
    process.exit(1);
  }

  try {
    // Read JSON file
    console.log('📖 Reading JSON file...');
    const fileContent = fs.readFileSync(resolvedPath, 'utf8');
    const jsonData = JSON.parse(fileContent);

    // Handle two formats:
    // 1. Single question object: { question_id: "...", subject: "...", ... }
    // 2. Array of questions: [{ question_id: "...", ... }]
    // 3. Object with questions array: { questions: [...] }

    let questionData = null;

    if (Array.isArray(jsonData)) {
      // Format 2: Array of questions
      questionData = jsonData.find(q => q.question_id === questionId);
    } else if (jsonData.questions && Array.isArray(jsonData.questions)) {
      // Format 3: Object with questions array
      questionData = jsonData.questions.find(q => q.question_id === questionId);
    } else if (jsonData.question_id === questionId || Object.keys(jsonData).length > 0) {
      // Format 1: Single question object
      questionData = jsonData;
    }

    if (!questionData) {
      console.error(`❌ Question ${questionId} not found in JSON file`);
      console.error('   File contains:', Array.isArray(jsonData) ? `${jsonData.length} questions` : 'single question object');
      process.exit(1);
    }

    console.log(`✅ Found question data`);

    // Validate question
    console.log('🔍 Validating question...');
    validateQuestion(questionData, questionId);
    console.log('✅ Validation passed');

    // Process question
    console.log('⚙️  Processing question data...');
    const processedQuestion = processQuestion(questionData, questionId);
    console.log(`✅ Chapter key: ${processedQuestion.chapter_key}`);

    // Handle image upload if needed
    if (processedQuestion.has_image) {
      console.log('📸 Uploading image...');
      const imageFileName = `${questionId}.svg`;
      const imagesDir = path.dirname(resolvedPath); // Look for image in same directory as JSON
      const imageUrl = await uploadImage(questionId, imageFileName, imagesDir);

      if (imageUrl) {
        processedQuestion.image_url = imageUrl;
      }
    }

    // Update in Firestore
    console.log('💾 Updating Firestore...');
    const questionRef = db.collection('questions').doc(questionId);

    await retryFirestoreOperation(async () => {
      await questionRef.set(processedQuestion, { merge: true });
    });

    console.log('✅ Question updated successfully!');
    console.log('');
    console.log('📊 Summary:');
    console.log(`   Question ID:  ${questionId}`);
    console.log(`   Subject:      ${processedQuestion.subject}`);
    console.log(`   Chapter:      ${processedQuestion.chapter}`);
    console.log(`   Chapter Key:  ${processedQuestion.chapter_key}`);
    console.log(`   Type:         ${processedQuestion.question_type}`);
    console.log(`   Active:       ${processedQuestion.active}`);
    if (processedQuestion.image_url) {
      console.log(`   Image URL:    ${processedQuestion.image_url}`);
    }
    console.log('');
    console.log('✅ Done!');

    process.exit(0);

  } catch (error) {
    console.error('');
    console.error('❌ Error updating question:');
    console.error('   ', error.message);
    console.error('');
    if (error.stack) {
      console.error('Stack trace:');
      console.error(error.stack);
    }
    process.exit(1);
  }
}

// Run the script
updateSingleQuestion();
