/**
 * Population Script for Initial Assessment Questions
 * 
 * This script:
 * 1. Reads initial_assessment_with_diagrams_IRT.json
 * 2. Extracts topic from sub_topics (first sub-topic)
 * 3. Uploads images to Firebase Storage (if has_image: true)
 * 4. Populates Firestore with 30 assessment questions
 * 5. Idempotent: Skips existing questions
 */

const path = require('path');
const fs = require('fs');
const { db, storage, admin } = require('../src/config/firebase');

// Paths
const JSON_FILE_PATH = path.join(__dirname, '../../docs/engine/initial_assessment_with_diagrams_IRT.json');
const IMAGES_DIR = path.join(__dirname, '../../docs/engine');
const STORAGE_BASE_PATH = 'questions/initial_assessment';

// Topic extraction removed - we calculate theta at chapter level

/**
 * Upload image to Firebase Storage
 * Returns public URL or null if upload fails
 */
async function uploadImage(questionId, imageFileName) {
  try {
    const localImagePath = path.join(IMAGES_DIR, imageFileName);
    
    // Check if file exists
    if (!fs.existsSync(localImagePath)) {
      console.warn(`⚠️  Image file not found: ${localImagePath}`);
      return null;
    }
    
    // Storage path
    const storagePath = `${STORAGE_BASE_PATH}/${imageFileName}`;
    const bucket = storage.bucket();
    const file = bucket.file(storagePath);
    
    // Check if already uploaded
    const [exists] = await file.exists();
    if (exists) {
      console.log(`  ✓ Image already exists in Storage: ${storagePath}`);
      // Get public URL
      await file.makePublic();
      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
      return publicUrl;
    }
    
    // Upload file
    console.log(`  📤 Uploading image: ${imageFileName}...`);
    await bucket.upload(localImagePath, {
      destination: storagePath,
      metadata: {
        contentType: 'image/svg+xml',
        metadata: {
          questionId: questionId,
          uploadedBy: 'population-script',
          uploadedAt: new Date().toISOString()
        }
      }
    });
    
    // Make public
    await file.makePublic();
    
    // Get public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
    console.log(`  ✓ Image uploaded: ${publicUrl}`);
    
    return publicUrl;
  } catch (error) {
    console.error(`  ❌ Error uploading image ${imageFileName}:`, error.message);
    return null;
  }
}

/**
 * Process and upload a single question
 */
async function processQuestion(questionId, questionData) {
  try {
    // Check if question already exists (idempotent)
    const questionRef = db.collection('initial_assessment_questions').doc(questionId);
    const existingDoc = await questionRef.get();
    
    if (existingDoc.exists) {
      console.log(`  ⏭️  Skipping existing question: ${questionId}`);
      return { skipped: true, questionId };
    }
    
    console.log(`  📝 Processing: ${questionId} → ${questionData.subject} / ${questionData.chapter}`);
    
    // Prepare question document
    const questionDoc = {
      // Identifiers
      question_id: questionId,
      assessment_id: 'initial_diagnostic_v1',
      version: '1.0',
      
      // Classification
      subject: questionData.subject,
      chapter: questionData.chapter,
      unit: questionData.unit || null,
      sub_topics: questionData.sub_topics || [],
      
      // Difficulty & Priority
      difficulty: questionData.difficulty,
      difficulty_irt: questionData.difficulty_irt || null,
      priority: questionData.priority || 'MEDIUM',
      weightage_marks: questionData.weightage_marks || 4,
      
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
      answer_type: questionData.answer_type,
      answer_range: questionData.answer_range || null,
      alternate_correct_answers: questionData.alternate_correct_answers || [],
      
      // Solution
      solution_text: questionData.solution_text,
      solution_steps: questionData.solution_steps || [],
      concepts_tested: questionData.concepts_tested || [],
      
      // IRT Parameters (CRITICAL)
      irt_parameters: {
        difficulty_b: questionData.irt_parameters?.difficulty_b || questionData.difficulty_irt || 0.0,
        discrimination_a: questionData.irt_parameters?.discrimination_a || 1.5,
        guessing_c: questionData.irt_parameters?.guessing_c || (questionData.question_type === 'mcq_single' ? 0.25 : 0.0),
        calibration_status: questionData.irt_parameters?.calibration_status || 'estimated',
        calibration_method: questionData.irt_parameters?.calibration_method || 'rule_based',
        calibration_sample_size: questionData.irt_parameters?.calibration_sample_size || 0,
        last_calibration: questionData.irt_parameters?.last_calibration || null,
        calibration_notes: questionData.irt_parameters?.calibration_notes || null
      },
      
      // Image (handle separately)
      has_image: questionData.has_image || false,
      image_url: null, // Will be set after upload
      image_type: questionData.has_image ? (questionData.image_type || 'diagram') : null,
      image_description: questionData.image_description || null,
      image_alt_text: questionData.image_alt_text || null,
      image_generation_method: questionData.image_generation_method || null,
      diagram_code_python: questionData.diagram_code_python || null,
      diagram_config: questionData.diagram_config || null,
      
      // Metadata
      time_estimate: questionData.time_estimate || 90,
      jee_year_similar: questionData.jee_year_similar || null,
      jee_pattern: questionData.jee_pattern || null,
      created_date: questionData.created_date 
        ? admin.firestore.Timestamp.fromDate(new Date(questionData.created_date))
        : admin.firestore.FieldValue.serverTimestamp(),
      created_by: questionData.created_by || 'claude_ai',
      validated_by: questionData.validated_by || null,
      validation_status: questionData.validation_status || 'approved',
      validation_date: questionData.validation_date 
        ? admin.firestore.Timestamp.fromDate(new Date(questionData.validation_date))
        : null,
      validation_notes: questionData.validation_notes || null,
      
      metadata: questionData.metadata || {},
      distractor_analysis: questionData.distractor_analysis || null,
      tags: questionData.tags || [],
      
      // Usage Statistics (initialize to zero)
      usage_stats: {
        times_shown: 0,
        times_correct: 0,
        times_incorrect: 0,
        avg_time_taken: null,
        accuracy_rate: null,
        last_shown: null
      }
    };
    
    // Upload image if needed
    if (questionData.has_image && questionData.image_url === null) {
      // Determine image filename from question_id
      // Format: ASSESS_PHY_MECH_003.svg
      const imageFileName = `${questionId}.svg`;
      const imageUrl = await uploadImage(questionId, imageFileName);
      questionDoc.image_url = imageUrl;
    } else if (questionData.image_url) {
      // Already has URL (from JSON)
      questionDoc.image_url = questionData.image_url;
    }
    
    // Save to Firestore
    await questionRef.set(questionDoc);
    console.log(`  ✓ Saved to Firestore: ${questionId}`);
    
    return { success: true, questionId };
  } catch (error) {
    console.error(`  ❌ Error processing question ${questionId}:`, error.message);
    return { error: true, questionId, errorMessage: error.message };
  }
}

/**
 * Main function
 */
async function main() {
  try {
    console.log('🚀 Starting Initial Assessment Questions Population...\n');
    
    // Read JSON file
    console.log(`📖 Reading JSON file: ${JSON_FILE_PATH}`);
    if (!fs.existsSync(JSON_FILE_PATH)) {
      throw new Error(`JSON file not found: ${JSON_FILE_PATH}`);
    }
    
    const jsonData = JSON.parse(fs.readFileSync(JSON_FILE_PATH, 'utf8'));
    const questions = jsonData.questions;
    
    if (!questions || Object.keys(questions).length === 0) {
      throw new Error('No questions found in JSON file');
    }
    
    console.log(`✓ Found ${Object.keys(questions).length} questions\n`);
    
    // Process each question
    const results = {
      total: Object.keys(questions).length,
      success: 0,
      skipped: 0,
      errors: 0
    };
    
    for (const [questionId, questionData] of Object.entries(questions)) {
      const result = await processQuestion(questionId, questionData);
      
      if (result.skipped) {
        results.skipped++;
      } else if (result.success) {
        results.success++;
      } else {
        results.errors++;
      }
      
      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 Population Summary');
    console.log('='.repeat(60));
    console.log(`Total questions: ${results.total}`);
    console.log(`✓ Successfully added: ${results.success}`);
    console.log(`⏭️  Skipped (already exist): ${results.skipped}`);
    console.log(`❌ Errors: ${results.errors}`);
    console.log('\n✅ Population complete!');
    
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

module.exports = { processQuestion };
