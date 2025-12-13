/**
 * Update Question Images Script
 * 
 * Updates image URLs for questions that have has_image=true but image_url=null
 * This script can be run after Firebase Storage is enabled to upload missing images.
 * 
 * Usage:
 *   node scripts/update-question-images.js
 *   node scripts/update-question-images.js --question-id PHY_MAGN_E_004
 *   node scripts/update-question-images.js --subject Physics --chapter "Magnetic Effects & Magnetism"
 */

const path = require('path');
const fs = require('fs');
const { db, storage, admin } = require('../src/config/firebase');
const { retryFirestoreOperation } = require('../src/utils/firestoreRetry');

// Configuration
const IMAGES_DIR = path.join(__dirname, '../../inputs/question_bank/processed'); // Images were moved here
const STORAGE_BASE_PATH = 'questions/daily_quiz';

/**
 * Upload image to Firebase Storage
 */
async function uploadImage(questionId, imageFileName) {
  try {
    // Try both processed folder and original folder
    const processedPath = path.join(IMAGES_DIR, imageFileName);
    const originalPath = path.join(__dirname, '../../inputs/question_bank', imageFileName);
    
    let localImagePath;
    if (fs.existsSync(processedPath)) {
      localImagePath = processedPath;
    } else if (fs.existsSync(originalPath)) {
      localImagePath = originalPath;
    } else {
      console.warn(`  ⚠️  Image file not found: ${imageFileName}`);
      return null;
    }
    
    // Get bucket
    let bucket = storage.bucket();
    
    // Try to verify bucket exists
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
              console.log(`  ℹ️  Using bucket: ${bucketName}`);
              break;
            }
          } catch (e) {
            continue;
          }
        }
      }
    } catch (checkError) {
      console.warn(`  ⚠️  Could not verify bucket: ${checkError.message}`);
    }
    
    const storagePath = `${STORAGE_BASE_PATH}/${imageFileName}`;
    const file = bucket.file(storagePath);
    
    // Check if already uploaded
    try {
      const [exists] = await file.exists();
      if (exists) {
        console.log(`  ✓ Image already exists in Storage: ${storagePath}`);
        try {
          await file.makePublic();
        } catch (e) {
          // Already public
        }
        const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
        return publicUrl;
      }
    } catch (e) {
      // Continue to upload
    }
    
    // Upload file
    console.log(`  📤 Uploading image: ${imageFileName}...`);
    await bucket.upload(localImagePath, {
      destination: storagePath,
      metadata: {
        contentType: 'image/svg+xml',
        metadata: {
          questionId: questionId,
          uploadedBy: 'update-question-images-script',
          uploadedAt: new Date().toISOString()
        }
      }
    });
    
    // Make public
    try {
      await file.makePublic();
    } catch (e) {
      console.warn(`  ⚠️  Could not make public: ${e.message}`);
    }
    
    // Get public URL
    let publicUrl;
    if (bucket.name.includes('firebasestorage.app')) {
      const encodedPath = encodeURIComponent(storagePath);
      publicUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media`;
    } else {
      publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
    }
    
    console.log(`  ✓ Image uploaded: ${publicUrl}`);
    return publicUrl;
  } catch (error) {
    console.error(`  ❌ Error uploading image ${imageFileName}:`, error.message);
    if (error.code === 404) {
      console.error(`  💡 Make sure Firebase Storage is enabled in Firebase Console`);
    }
    return null;
  }
}

/**
 * Update image URL for a single question
 */
async function updateQuestionImage(questionId) {
  try {
    const questionRef = db.collection('questions').doc(questionId);
    const questionDoc = await retryFirestoreOperation(async () => {
      return await questionRef.get();
    });
    
    if (!questionDoc.exists) {
      console.error(`  ❌ Question not found: ${questionId}`);
      return { success: false, error: 'Question not found' };
    }
    
    const questionData = questionDoc.data();
    
    // Check if question needs image update
    if (!questionData.has_image) {
      console.log(`  ⏭️  Question ${questionId} does not have has_image=true, skipping`);
      return { success: false, skipped: true };
    }
    
    if (questionData.image_url) {
      console.log(`  ✓ Question ${questionId} already has image_url: ${questionData.image_url}`);
      return { success: true, skipped: true, imageUrl: questionData.image_url };
    }
    
    // Upload image
    const imageFileName = `${questionId}.svg`;
    const imageUrl = await uploadImage(questionId, imageFileName);
    
    if (!imageUrl) {
      return { success: false, error: 'Image upload failed' };
    }
    
    // Update question document
    await retryFirestoreOperation(async () => {
      return await questionRef.update({
        image_url: imageUrl
      });
    });
    
    console.log(`  ✓ Updated question ${questionId} with image URL`);
    return { success: true, imageUrl };
  } catch (error) {
    console.error(`  ❌ Error updating question ${questionId}:`, error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Update all questions that need images
 */
async function updateAllQuestionImages() {
  try {
    console.log('🔍 Finding questions that need image updates...\n');
    
    // Query questions with has_image=true and image_url=null
    const questionsRef = db.collection('questions')
      .where('has_image', '==', true);
    
    const snapshot = await retryFirestoreOperation(async () => {
      return await questionsRef.get();
    });
    
    const questions = snapshot.docs
      .map(doc => ({ id: doc.id, ...doc.data() }))
      .filter(q => !q.image_url || q.image_url === null);
    
    if (questions.length === 0) {
      console.log('✓ No questions need image updates');
      return;
    }
    
    console.log(`Found ${questions.length} questions that need image updates\n`);
    
    let success = 0;
    let failed = 0;
    
    for (const question of questions) {
      console.log(`\n📝 Processing: ${question.id}`);
      const result = await updateQuestionImage(question.id);
      
      if (result.success && !result.skipped) {
        success++;
      } else if (!result.success && !result.skipped) {
        failed++;
      }
      
      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('📊 Update Summary');
    console.log('='.repeat(60));
    console.log(`Total questions processed: ${questions.length}`);
    console.log(`✓ Successfully updated: ${success}`);
    console.log(`❌ Failed: ${failed}`);
    console.log(`⏭️  Skipped (already have URLs): ${questions.length - success - failed}`);
    
  } catch (error) {
    console.error('\n❌ Error updating question images:', error);
    throw error;
  }
}

/**
 * Main function
 */
async function main() {
  try {
    const args = process.argv.slice(2);
    
    if (args.includes('--question-id')) {
      const index = args.indexOf('--question-id');
      const questionId = args[index + 1];
      if (!questionId) {
        console.error('❌ Please provide a question ID');
        process.exit(1);
      }
      await updateQuestionImage(questionId);
    } else if (args.includes('--subject') && args.includes('--chapter')) {
      const subjectIndex = args.indexOf('--subject');
      const chapterIndex = args.indexOf('--chapter');
      const subject = args[subjectIndex + 1];
      const chapter = args[chapterIndex + 1];
      
      console.log(`🔍 Finding questions for ${subject} / ${chapter}...\n`);
      
      const questionsRef = db.collection('questions')
        .where('subject', '==', subject)
        .where('chapter', '==', chapter)
        .where('has_image', '==', true);
      
      const snapshot = await retryFirestoreOperation(async () => {
        return await questionsRef.get();
      });
      
      const questions = snapshot.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .filter(q => !q.image_url || q.image_url === null);
      
      console.log(`Found ${questions.length} questions to update\n`);
      
      for (const question of questions) {
        await updateQuestionImage(question.id);
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    } else {
      await updateAllQuestionImages();
    }
    
    console.log('\n✅ Script completed successfully');
  } catch (error) {
    console.error('\n❌ Script failed:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  updateQuestionImage,
  updateAllQuestionImages,
  uploadImage
};
