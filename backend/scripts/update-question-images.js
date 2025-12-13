/**
 * Update Question Images Script
 * 
 * Updates the 4 assessment questions with image URLs after manual upload to Firebase Storage
 */

const { db } = require('../src/config/firebase');

// Firebase Storage base URL
const STORAGE_BASE_URL = 'https://firebasestorage.googleapis.com/v0/b/jeevibe.firebasestorage.app/o';
const STORAGE_FOLDER = 'initial_assessment';

// Questions with images
const QUESTIONS_WITH_IMAGES = [
  'ASSESS_PHY_MECH_003',
  'ASSESS_PHY_EMI_001',
  'ASSESS_CHEM_ORG_001',
  'ASSESS_MATH_COORD_001'
];

/**
 * Generate Firebase Storage public URL
 * 
 * @param {string} fileName - Image file name (e.g., "ASSESS_PHY_MECH_003.svg")
 * @returns {string} Public URL
 */
function generateImageUrl(fileName) {
  // URL encode the path
  const encodedPath = encodeURIComponent(`${STORAGE_FOLDER}/${fileName}`);
  // Public URL format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media
  return `${STORAGE_BASE_URL}/${encodedPath}?alt=media`;
}

/**
 * Update image URL for a question
 */
async function updateQuestionImage(questionId) {
  try {
    const questionRef = db.collection('initial_assessment_questions').doc(questionId);
    const questionDoc = await questionRef.get();
    
    if (!questionDoc.exists) {
      console.warn(`⚠️  Question ${questionId} not found in Firestore`);
      return { success: false, questionId, error: 'Question not found' };
    }
    
    const questionData = questionDoc.data();
    
    // Check if question should have an image
    if (!questionData.has_image) {
      console.warn(`⚠️  Question ${questionId} has has_image=false, skipping`);
      return { success: false, questionId, error: 'Question does not have image' };
    }
    
    // Generate image URL
    const imageFileName = `${questionId}.svg`;
    const imageUrl = generateImageUrl(imageFileName);
    
    // Update question with image URL
    await questionRef.update({
      image_url: imageUrl,
      image_type: questionData.image_type || 'diagram'
    });
    
    console.log(`✓ Updated ${questionId} with image URL: ${imageUrl}`);
    return { success: true, questionId, imageUrl };
  } catch (error) {
    console.error(`❌ Error updating ${questionId}:`, error.message);
    return { success: false, questionId, error: error.message };
  }
}

/**
 * Main function
 */
async function main() {
  try {
    console.log('🚀 Starting Image URL Update...\n');
    console.log(`Storage Base: ${STORAGE_BASE_URL}`);
    console.log(`Folder: ${STORAGE_FOLDER}\n`);
    
    const results = {
      total: QUESTIONS_WITH_IMAGES.length,
      success: 0,
      errors: 0
    };
    
    for (const questionId of QUESTIONS_WITH_IMAGES) {
      const result = await updateQuestionImage(questionId);
      
      if (result.success) {
        results.success++;
      } else {
        results.errors++;
      }
      
      // Small delay
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 Update Summary');
    console.log('='.repeat(60));
    console.log(`Total questions: ${results.total}`);
    console.log(`✓ Successfully updated: ${results.success}`);
    console.log(`❌ Errors: ${results.errors}`);
    console.log('\n✅ Image URL update complete!');
    
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

module.exports = { updateQuestionImage, generateImageUrl };
