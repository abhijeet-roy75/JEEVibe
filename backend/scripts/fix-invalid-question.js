/**
 * Fix Invalid Question CHEM_PURC_E_028
 *
 * This question has correct_answer_exact set to "C2H4O2" (a chemical formula)
 * instead of a numeric value, causing validation errors.
 *
 * Usage: node backend/scripts/fix-invalid-question.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
} else {
  // Try to load from local service account file
  const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  try {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } catch (err) {
    console.error('Error: Could not find service account credentials.');
    console.error('Either set GOOGLE_APPLICATION_CREDENTIALS env var or place serviceAccountKey.json in backend/');
    process.exit(1);
  }
}

const db = admin.firestore();

async function fixInvalidQuestion() {
  const questionId = 'CHEM_PURC_E_028';

  try {
    console.log(`\n🔍 Fetching question ${questionId}...`);

    const questionRef = db.collection('questions').doc(questionId);
    const questionDoc = await questionRef.get();

    if (!questionDoc.exists) {
      console.error(`❌ Question ${questionId} not found!`);
      process.exit(1);
    }

    const questionData = questionDoc.data();
    console.log('\n📄 Current question data:');
    console.log('Question Type:', questionData.question_type);
    console.log('Correct Answer:', questionData.correct_answer);
    console.log('Correct Answer Exact:', questionData.correct_answer_exact);
    console.log('Answer Range:', questionData.answer_range);

    // Check if this is an MCQ or numerical question
    if (questionData.question_type === 'mcq_single') {
      console.log('\n✅ This is an MCQ question');
      console.log('For MCQ questions, we should remove correct_answer_exact');

      // Remove the invalid field
      await questionRef.update({
        correct_answer_exact: admin.firestore.FieldValue.delete()
      });

      console.log('\n✅ Removed correct_answer_exact field');
      console.log('The correct_answer field will be used for validation');

    } else if (questionData.question_type === 'numerical') {
      console.log('\n⚠️  This is a numerical question');
      console.log('For numerical questions, correct_answer_exact should be numeric');

      // If it's supposed to be numerical, we need to know what the actual answer is
      console.log('\n❓ Please manually verify what the correct numeric answer should be');
      console.log('For now, removing correct_answer_exact and keeping correct_answer');

      await questionRef.update({
        correct_answer_exact: admin.firestore.FieldValue.delete()
      });

      console.log('\n✅ Removed invalid correct_answer_exact field');

    } else {
      console.log('\n⚠️  Unknown question type:', questionData.question_type);
      console.log('Removing correct_answer_exact to prevent validation errors');

      await questionRef.update({
        correct_answer_exact: admin.firestore.FieldValue.delete()
      });

      console.log('\n✅ Removed correct_answer_exact field');
    }

    // Verify the fix
    const updatedDoc = await questionRef.get();
    const updatedData = updatedDoc.data();

    console.log('\n📄 Updated question data:');
    console.log('Question Type:', updatedData.question_type);
    console.log('Correct Answer:', updatedData.correct_answer);
    console.log('Correct Answer Exact:', updatedData.correct_answer_exact || '(removed)');
    console.log('Answer Range:', updatedData.answer_range);

    console.log('\n✅ Question fixed successfully!');

  } catch (error) {
    console.error('\n❌ Error fixing question:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

fixInvalidQuestion();
