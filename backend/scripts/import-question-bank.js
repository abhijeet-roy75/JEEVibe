/**
 * Question Bank Import Script
 * 
 * Imports daily quiz questions from JSON files to Firestore.
 * 
 * Features:
 * 1. Reads JSON files from inputs/question_bank folder
 * 2. Validates question structure
 * 3. Extracts IRT parameters from difficulty_irt
 * 4. Computes chapter_key from subject + chapter
 * 5. Uploads SVG images to Firebase Storage (if has_image: true)
 * 6. Batch writes to Firestore (500 per batch for efficiency)
 * 7. Idempotent: Skips existing questions
 * 8. Moves processed files (JSON + images) to processed subfolder
 * 
 * Usage:
 *   node scripts/import-question-bank.js
 *   node scripts/import-question-bank.js --file inputs/question_bank/questions_electrostatistics_production.json
 *   node scripts/import-question-bank.js --dir inputs/question_bank
 */

const path = require('path');
const fs = require('fs');
const { db, storage, admin } = require('../src/config/firebase');
const { retryFirestoreOperation } = require('../src/utils/firestoreRetry');
// Using console for script output (logger not needed for import script)
const logger = console;

// ============================================================================
// CONFIGURATION
// ============================================================================

// Default paths
const DEFAULT_JSON_DIR = path.join(__dirname, '../../inputs/question_bank');
const IMAGES_DIR = path.join(__dirname, '../../inputs/question_bank'); // Same directory as JSON files
const PROCESSED_DIR = path.join(__dirname, '../../inputs/question_bank/processed'); // Processed files folder
const STORAGE_BASE_PATH = 'questions/daily_quiz'; // Firebase Storage path

// Batch size for Firestore writes (Firestore limit: 500 per batch)
const BATCH_SIZE = 500;

// ============================================================================
// IMAGE UPLOAD
// ============================================================================

/**
 * Upload image to Firebase Storage
 * Returns public URL or null if upload fails
 * 
 * @param {string} questionId - Question ID
 * @param {string} imageFileName - Image file name (e.g., "PHY_ELEC_E_001.svg")
 * @returns {Promise<string|null>} Public URL or null
 */
async function uploadImage(questionId, imageFileName) {
  try {
    const localImagePath = path.join(IMAGES_DIR, imageFileName);
    
    // Check if file exists
    if (!fs.existsSync(localImagePath)) {
      console.warn(`  ⚠️  Image file not found: ${localImagePath}`);
      return null;
    }
    
    // Get bucket - try default first, then try common bucket name formats
    let bucket = storage.bucket();
    
    // If bucket doesn't exist, try to get it by name
    try {
      const [exists] = await bucket.exists();
      if (!exists) {
        // Try alternative bucket name formats
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
              console.log(`  ℹ️  Using bucket: ${bucketName}`);
              break;
            }
          } catch (e) {
            // Try next bucket name
            continue;
          }
        }
      }
    } catch (checkError) {
      console.warn(`  ⚠️  Could not verify bucket existence, proceeding anyway: ${checkError.message}`);
    }
    
    // Storage path
    const storagePath = `${STORAGE_BASE_PATH}/${imageFileName}`;
    const file = bucket.file(storagePath);
    
    // Check if already uploaded
    try {
      const [exists] = await file.exists();
      if (exists) {
        console.log(`  ✓ Image already exists in Storage: ${storagePath}`);
        // Get public URL
        try {
          await file.makePublic();
        } catch (publicError) {
          // File might already be public, continue
          console.log(`  ℹ️  File may already be public: ${publicError.message}`);
        }
        const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
        return publicUrl;
      }
    } catch (checkError) {
      console.warn(`  ⚠️  Could not check if file exists, will attempt upload: ${checkError.message}`);
    }
    
    // Upload file
    console.log(`  📤 Uploading image: ${imageFileName} to bucket: ${bucket.name}...`);
    await bucket.upload(localImagePath, {
      destination: storagePath,
      metadata: {
        contentType: 'image/svg+xml',
        metadata: {
          questionId: questionId,
          uploadedBy: 'question-bank-import-script',
          uploadedAt: new Date().toISOString()
        }
      }
    });
    
    // Make public
    try {
      await file.makePublic();
    } catch (publicError) {
      console.warn(`  ⚠️  Could not make file public (may already be public): ${publicError.message}`);
    }
    
    // Get public URL - try different URL formats
    let publicUrl;
    if (bucket.name.includes('firebasestorage.app')) {
      // New Firebase Storage format
      const encodedPath = encodeURIComponent(storagePath);
      publicUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media`;
    } else {
      // Legacy format
      publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
    }
    
    console.log(`  ✓ Image uploaded: ${publicUrl}`);
    
    return publicUrl;
  } catch (error) {
    console.error(`  ❌ Error uploading image ${imageFileName}:`, error.message);
    if (error.code === 404) {
      console.error(`  💡 Tip: Make sure Firebase Storage is enabled in your Firebase project`);
      console.error(`  💡 Go to Firebase Console → Storage → Get Started`);
    }
    return null;
  }
}

// ============================================================================
// QUESTION VALIDATION
// ============================================================================

/**
 * Validate question structure
 * 
 * @param {string} questionId
 * @param {Object} questionData
 * @returns {Object} { valid: boolean, errors: string[] }
 */
function validateQuestion(questionId, questionData) {
  const errors = [];
  
  // Required fields
  if (!questionData.subject) {
    errors.push('Missing subject');
  }
  if (!questionData.chapter) {
    errors.push('Missing chapter');
  }
  if (!questionData.question_type) {
    errors.push('Missing question_type');
  }
  if (!questionData.question_text) {
    errors.push('Missing question_text');
  }
  if (!questionData.correct_answer) {
    errors.push('Missing correct_answer');
  }
  
  // IRT parameters
  if (questionData.difficulty_irt === undefined && 
      (!questionData.irt_parameters || questionData.irt_parameters.difficulty_b === undefined)) {
    errors.push('Missing difficulty_irt or irt_parameters.difficulty_b');
  }
  
  // Question type validation
  if (questionData.question_type === 'mcq_single' && !questionData.options) {
    errors.push('MCQ questions must have options');
  }
  
  // Numerical questions must have answer_range or correct_answer_exact
  if (questionData.question_type === 'numerical') {
    if (!questionData.answer_range && !questionData.correct_answer_exact) {
      errors.push('Numerical questions must have answer_range or correct_answer_exact');
    }
  }
  
  return {
    valid: errors.length === 0,
    errors
  };
}

// ============================================================================
// IRT PARAMETER EXTRACTION
// ============================================================================

/**
 * Extract IRT parameters from question data
 * 
 * @param {Object} questionData
 * @returns {Object} IRT parameters
 */
function extractIRTParameters(questionData) {
  // Use existing irt_parameters if available
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
  
  // Extract from difficulty_irt (legacy field)
  const difficulty_b = questionData.difficulty_irt !== undefined 
    ? questionData.difficulty_irt 
    : 0.0;
  
  return {
    difficulty_b: difficulty_b,
    discrimination_a: 1.5, // Default discrimination
    guessing_c: questionData.question_type === 'mcq_single' ? 0.25 : 0.0,
    calibration_status: 'estimated',
    calibration_method: 'rule_based',
    calibration_sample_size: 0,
    last_calibration: null,
    calibration_notes: null
  };
}

// ============================================================================
// CHAPTER KEY COMPUTATION
// ============================================================================

/**
 * Compute chapter_key from subject and chapter
 * Format: {subject}_{chapter} (lowercase, spaces replaced with underscores)
 * 
 * @param {string} subject
 * @param {string} chapter
 * @returns {string} chapter_key
 */
function computeChapterKey(subject, chapter) {
  const subjectLower = subject.toLowerCase().trim();
  const chapterLower = chapter.toLowerCase().trim();
  
  // Normalize: replace spaces and special chars with underscores
  const normalizedSubject = subjectLower.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  const normalizedChapter = chapterLower.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  
  return `${normalizedSubject}_${normalizedChapter}`;
}

// ============================================================================
// QUESTION PROCESSING
// ============================================================================

/**
 * Process and prepare a single question for Firestore
 * 
 * @param {string} questionId
 * @param {Object} questionData
 * @returns {Promise<Object>} Processed question document
 */
async function processQuestion(questionId, questionData) {
  // Validate question
  const validation = validateQuestion(questionId, questionData);
  if (!validation.valid) {
    throw new Error(`Validation failed: ${validation.errors.join(', ')}`);
  }
  
  // Extract IRT parameters
  const irtParameters = extractIRTParameters(questionData);
  
  // Compute chapter_key
  const chapterKey = computeChapterKey(questionData.subject, questionData.chapter);
  
  // Prepare question document
  const questionDoc = {
    // Identifiers
    question_id: questionId,
    
    // Classification
    subject: questionData.subject,
    chapter: questionData.chapter,
    chapter_key: chapterKey, // Computed field for queries
    topic: questionData.topic || null, // For metadata, not theta tracking
    unit: questionData.unit || null,
    sub_topics: questionData.sub_topics || [],
    
    // IRT Parameters (CRITICAL)
    difficulty_irt: questionData.difficulty_irt || irtParameters.difficulty_b, // Legacy field
    irt_parameters: irtParameters,
    
    // Question Content
    question_type: questionData.question_type,
    question_text: questionData.question_text,
    question_text_html: questionData.question_text_html || questionData.question_text,
    question_latex: questionData.question_latex || null,
    options: questionData.options || null,
    
    // Answer
    correct_answer: questionData.correct_answer,
    correct_answer_text: questionData.correct_answer_text || questionData.correct_answer,
    correct_answer_exact: questionData.correct_answer_exact || null,
    correct_answer_unit: questionData.correct_answer_unit || null,
    answer_type: questionData.answer_type || 'text',
    answer_range: questionData.answer_range || null,
    alternate_correct_answers: questionData.alternate_correct_answers || [],
    
    // Solution
    solution_text: questionData.solution_text || null,
    solution_steps: questionData.solution_steps || [],
    concepts_tested: questionData.concepts_tested || [],
    
    // Image (will be set after upload)
    has_image: questionData.has_image || false,
    image_url: null, // Will be set after upload
    image_type: questionData.image_type || null,
    image_description: questionData.image_description || null,
    image_alt_text: questionData.image_alt_text || null,
    image_generation_method: questionData.image_generation_method || null,
    diagram_code_python: questionData.diagram_code_python || null,
    diagram_config: questionData.diagram_config || null,
    
    // Metadata
    difficulty: questionData.difficulty || 'medium',
    priority: questionData.priority || 'MEDIUM',
    time_estimate: questionData.time_estimate || 90,
    weightage_marks: questionData.weightage_marks || 4,
    jee_year_similar: questionData.jee_year_similar || null,
    jee_pattern: questionData.jee_pattern || null,
    tags: questionData.tags || [],
    metadata: questionData.metadata || {},
    distractor_analysis: questionData.distractor_analysis || null,
    
    // Usage Statistics (initialize to zero)
    usage_stats: {
      times_shown: 0,
      times_correct: 0,
      times_incorrect: 0,
      avg_time_taken: null,
      accuracy_rate: null,
      last_shown: null
    },
    
    // Creation metadata
    created_date: questionData.created_date 
      ? admin.firestore.Timestamp.fromDate(new Date(questionData.created_date))
      : admin.firestore.FieldValue.serverTimestamp(),
    created_by: questionData.created_by || 'claude_ai',
    validated_by: questionData.validated_by || null,
    validation_status: questionData.validation_status || 'pending',
    validation_date: questionData.validation_date 
      ? admin.firestore.Timestamp.fromDate(new Date(questionData.validation_date))
      : null,
    validation_notes: questionData.validation_notes || null
  };
  
  // Upload image if needed
  if (questionData.has_image) {
    if (questionData.image_url) {
      // Already has URL (from JSON)
      questionDoc.image_url = questionData.image_url;
      console.log(`  ✓ Using existing image URL: ${questionData.image_url}`);
    } else {
      // Need to upload image
      // Determine image filename from question_id
      // Format: PHY_ELEC_E_001.svg
      const imageFileName = `${questionId}.svg`;
      const imageUrl = await uploadImage(questionId, imageFileName);
      questionDoc.image_url = imageUrl;
      
      if (!imageUrl) {
        console.warn(`  ⚠️  Question ${questionId} has has_image=true but image upload failed`);
      }
    }
  }
  
  return questionDoc;
}

// ============================================================================
// BATCH PROCESSING
// ============================================================================

/**
 * Process questions in batches and write to Firestore
 * 
 * @param {Array} questions - Array of { questionId, questionData }
 * @returns {Promise<Object>} Results summary
 */
async function processBatch(questions) {
  const results = {
    total: questions.length,
    success: 0,
    skipped: 0,
    errors: 0,
    errorDetails: []
  };
  
  // Check which questions already exist (batch read)
  const questionIds = questions.map(q => q.questionId);
  const questionRefs = questionIds.map(id => db.collection('questions').doc(id));
  
  const existingDocs = await retryFirestoreOperation(async () => {
    return await db.getAll(...questionRefs);
  });
  
  const existingIds = new Set(
    existingDocs.filter(doc => doc.exists).map(doc => doc.id)
  );
  
  // Process each question
  const batch = db.batch();
  let batchWriteCount = 0;
  
  for (const { questionId, questionData } of questions) {
    try {
      // Skip if already exists
      if (existingIds.has(questionId)) {
        console.log(`  ⏭️  Skipping existing question: ${questionId}`);
        results.skipped++;
        continue;
      }
      
      // Process question
      console.log(`  📝 Processing: ${questionId} → ${questionData.subject} / ${questionData.chapter}`);
      const questionDoc = await processQuestion(questionId, questionData);
      
      // Add to batch
      const questionRef = db.collection('questions').doc(questionId);
      batch.set(questionRef, questionDoc);
      batchWriteCount++;
      results.success++;
      
      // Commit batch if we reach the limit
      if (batchWriteCount >= BATCH_SIZE) {
        await retryFirestoreOperation(async () => {
          return await batch.commit();
        });
        console.log(`  ✓ Committed batch of ${batchWriteCount} questions`);
        batchWriteCount = 0;
      }
      
      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 50));
      
    } catch (error) {
      console.error(`  ❌ Error processing question ${questionId}:`, error.message);
      results.errors++;
      results.errorDetails.push({
        questionId,
        error: error.message
      });
    }
  }
  
  // Commit remaining batch
  if (batchWriteCount > 0) {
    await retryFirestoreOperation(async () => {
      return await batch.commit();
    });
    console.log(`  ✓ Committed final batch of ${batchWriteCount} questions`);
  }
  
  return results;
}

// ============================================================================
// FILE MOVING
// ============================================================================

/**
 * Move processed files (JSON + related images) to processed folder
 * 
 * @param {string} jsonFilePath - Path to JSON file
 * @param {Array<string>} questionIds - Array of question IDs from the JSON file
 * @returns {Promise<void>}
 */
async function moveProcessedFiles(jsonFilePath, questionIds) {
  try {
    // Ensure processed directory exists
    if (!fs.existsSync(PROCESSED_DIR)) {
      fs.mkdirSync(PROCESSED_DIR, { recursive: true });
      console.log(`  📁 Created processed directory: ${PROCESSED_DIR}`);
    }
    
    const jsonFileName = path.basename(jsonFilePath);
    const jsonDir = path.dirname(jsonFilePath);
    const processedJsonPath = path.join(PROCESSED_DIR, jsonFileName);
    
    // Move JSON file
    if (fs.existsSync(jsonFilePath)) {
      fs.renameSync(jsonFilePath, processedJsonPath);
      console.log(`  ✓ Moved JSON file to processed: ${jsonFileName}`);
    }
    
    // Move related SVG images
    let movedImages = 0;
    for (const questionId of questionIds) {
      const imageFileName = `${questionId}.svg`;
      const imagePath = path.join(jsonDir, imageFileName);
      const processedImagePath = path.join(PROCESSED_DIR, imageFileName);
      
      if (fs.existsSync(imagePath)) {
        fs.renameSync(imagePath, processedImagePath);
        movedImages++;
      }
    }
    
    if (movedImages > 0) {
      console.log(`  ✓ Moved ${movedImages} image file(s) to processed folder`);
    }
    
  } catch (error) {
    console.error(`  ⚠️  Warning: Could not move files to processed folder:`, error.message);
    // Don't throw - file moving is not critical
  }
}

// ============================================================================
// FILE PROCESSING
// ============================================================================

/**
 * Process a single JSON file
 * 
 * @param {string} filePath - Path to JSON file
 * @returns {Promise<Object>} Results summary
 */
async function processFile(filePath) {
  try {
    console.log(`\n📖 Reading file: ${filePath}`);
    
    if (!fs.existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    
    const jsonData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    
    // Handle both formats: { "Q1": {...}, "Q2": {...} } or { questions: [...] }
    let questions;
    let questionIds = [];
    
    if (Array.isArray(jsonData)) {
      // Array format: [{ question_id: "Q1", ... }, { question_id: "Q2", ... }]
      questions = jsonData.map(q => {
        const questionId = q.question_id || q.id;
        if (!questionId) {
          throw new Error('Question missing question_id or id field');
        }
        return {
          questionId,
          questionData: q
        };
      });
      questionIds = questions.map(q => q.questionId);
    } else if (jsonData.questions && Array.isArray(jsonData.questions)) {
      // Object with questions array: { questions: [{ question_id: "Q1", ... }] }
      questions = jsonData.questions.map(q => {
        const questionId = q.question_id || q.id;
        if (!questionId) {
          throw new Error('Question missing question_id or id field');
        }
        return {
          questionId,
          questionData: q
        };
      });
      questionIds = questions.map(q => q.questionId);
    } else {
      // Object format: { "Q1": {...}, "Q2": {...} }
      questions = Object.entries(jsonData).map(([questionId, questionData]) => ({
        questionId,
        questionData
      }));
      questionIds = questions.map(q => q.questionId);
    }
    
    if (!questions || questions.length === 0) {
      throw new Error('No questions found in JSON file');
    }
    
    console.log(`✓ Found ${questions.length} questions\n`);
    
    // Process in batches
    const allResults = {
      total: questions.length,
      success: 0,
      skipped: 0,
      errors: 0,
      errorDetails: []
    };
    
    // Process in chunks of BATCH_SIZE
    for (let i = 0; i < questions.length; i += BATCH_SIZE) {
      const batch = questions.slice(i, i + BATCH_SIZE);
      console.log(`\n📦 Processing batch ${Math.floor(i / BATCH_SIZE) + 1} (${batch.length} questions)...`);
      
      const batchResults = await processBatch(batch);
      
      allResults.success += batchResults.success;
      allResults.skipped += batchResults.skipped;
      allResults.errors += batchResults.errors;
      allResults.errorDetails.push(...batchResults.errorDetails);
    }
    
    // Move files to processed folder if processing was successful
    // Only move if we had at least some successful imports (not all skipped)
    if (allResults.success > 0 || (allResults.skipped === allResults.total && allResults.errors === 0)) {
      console.log(`\n📦 Moving processed files to processed folder...`);
      await moveProcessedFiles(filePath, questionIds);
    } else if (allResults.errors > 0) {
      console.log(`\n⚠️  Skipping file move due to errors. Files remain in original location.`);
    }
    
    return allResults;
    
  } catch (error) {
    console.error(`\n❌ Error processing file ${filePath}:`, error.message);
    throw error;
  }
}

/**
 * Process all JSON files in a directory
 * 
 * @param {string} dirPath - Directory path
 * @returns {Promise<Object>} Combined results
 */
async function processDirectory(dirPath) {
  // Get all files, excluding subdirectories and the processed folder
  const allItems = fs.readdirSync(dirPath);
  const files = allItems
    .filter(item => {
      const itemPath = path.join(dirPath, item);
      const stat = fs.statSync(itemPath);
      // Skip directories (including processed folder)
      if (stat.isDirectory()) {
        return false;
      }
      // Only process JSON files starting with 'questions_'
      return item.endsWith('.json') && item.startsWith('questions_');
    });
  
  if (files.length === 0) {
    throw new Error(`No question JSON files found in ${dirPath}`);
  }
  
  console.log(`\n📁 Found ${files.length} JSON files in directory\n`);
  
  const allResults = {
    total: 0,
    success: 0,
    skipped: 0,
    errors: 0,
    errorDetails: [],
    files: {}
  };
  
  for (const file of files) {
    const filePath = path.join(dirPath, file);
    try {
      const results = await processFile(filePath);
      allResults.total += results.total;
      allResults.success += results.success;
      allResults.skipped += results.skipped;
      allResults.errors += results.errors;
      allResults.errorDetails.push(...results.errorDetails);
      allResults.files[file] = results;
    } catch (error) {
      console.error(`\n❌ Failed to process ${file}:`, error.message);
      allResults.errors++;
      allResults.errorDetails.push({
        file,
        error: error.message
      });
    }
  }
  
  return allResults;
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

async function main() {
  try {
    console.log('🚀 Starting Question Bank Import...\n');
    
    // Parse command line arguments
    const args = process.argv.slice(2);
    let targetPath = DEFAULT_JSON_DIR;
    let isFile = false;
    
    if (args.includes('--file')) {
      const fileIndex = args.indexOf('--file');
      if (fileIndex + 1 < args.length) {
        targetPath = args[fileIndex + 1];
        isFile = true;
      }
    } else if (args.includes('--dir')) {
      const dirIndex = args.indexOf('--dir');
      if (dirIndex + 1 < args.length) {
        targetPath = args[dirIndex + 1];
      }
    }
    
    // Resolve absolute path
    if (!path.isAbsolute(targetPath)) {
      targetPath = path.join(process.cwd(), targetPath);
    }
    
    let results;
    
    if (isFile || fs.statSync(targetPath).isFile()) {
      // Process single file
      results = await processFile(targetPath);
    } else {
      // Process directory
      results = await processDirectory(targetPath);
    }
    
    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 Import Summary');
    console.log('='.repeat(60));
    console.log(`Total questions: ${results.total}`);
    console.log(`✓ Successfully added: ${results.success}`);
    console.log(`⏭️  Skipped (already exist): ${results.skipped}`);
    console.log(`❌ Errors: ${results.errors}`);
    
    if (results.errors > 0 && results.errorDetails.length > 0) {
      console.log('\n❌ Error Details:');
      results.errorDetails.slice(0, 10).forEach(({ questionId, error }) => {
        console.log(`  - ${questionId}: ${error}`);
      });
      if (results.errorDetails.length > 10) {
        console.log(`  ... and ${results.errorDetails.length - 10} more errors`);
      }
    }
    
    console.log('\n✅ Import complete!');
    
  } catch (error) {
    console.error('\n❌ Fatal error:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main()
    .then(() => {
      console.log('\n🎉 Script completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('\n💥 Script failed:', error);
      process.exit(1);
    });
}

module.exports = {
  processQuestion,
  processFile,
  processDirectory,
  uploadImage,
  validateQuestion,
  extractIRTParameters,
  computeChapterKey
};

