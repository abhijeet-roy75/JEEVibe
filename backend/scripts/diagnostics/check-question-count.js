/**
 * Quick script to check question count in Firestore
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

async function checkQuestionCount() {
  try {
    console.log('Checking question count in Firestore...\n');
    
    const questionsRef = db.collection('initial_assessment_questions');
    const snapshot = await questionsRef.get();
    
    console.log(`Total documents: ${snapshot.size}`);
    
    // Check for duplicates by question_id
    const questionIds = new Map();
    const duplicates = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const questionId = data.question_id || doc.id;
      
      if (questionIds.has(questionId)) {
        duplicates.push({
          question_id: questionId,
          doc_id_1: questionIds.get(questionId),
          doc_id_2: doc.id
        });
      } else {
        questionIds.set(questionId, doc.id);
      }
    });
    
    console.log(`Unique question_ids: ${questionIds.size}`);
    
    if (duplicates.length > 0) {
      console.log(`\n⚠️  Found ${duplicates.length} duplicate question_ids:`);
      duplicates.forEach(dup => {
        console.log(`  - ${dup.question_id}: doc IDs ${dup.doc_id_1}, ${dup.doc_id_2}`);
      });
    } else {
      console.log('\n✅ No duplicate question_ids found');
    }
    
    // Check difficulty distribution
    const byBlock = { warmup: 0, core: 0, challenge: 0, unknown: 0 };
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const difficultyB = data.irt_parameters?.difficulty_b || data.difficulty_b || 0.9;
      
      if (difficultyB <= 0.8) {
        byBlock.warmup++;
      } else if (difficultyB <= 1.1) {
        byBlock.core++;
      } else if (difficultyB <= 1.3) {
        byBlock.challenge++;
      } else {
        byBlock.unknown++;
      }
    });
    
    console.log('\n📊 Difficulty distribution:');
    console.log(`  Warmup (≤0.8): ${byBlock.warmup}`);
    console.log(`  Core (0.8-1.1): ${byBlock.core}`);
    console.log(`  Challenge (1.1-1.3): ${byBlock.challenge}`);
    console.log(`  Unknown (>1.3): ${byBlock.unknown}`);
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkQuestionCount();
