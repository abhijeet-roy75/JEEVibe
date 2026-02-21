const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.join(__dirname, '..', 'serviceAccountKey.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkQuestion() {
  try {
    const doc = await db.collection('questions').doc('MATH_STAT_M_002').get();
    
    if (!doc.exists) {
      console.log('❌ Question MATH_STAT_M_002 not found in Firestore');
      return;
    }
    
    const data = doc.data();
    console.log('✅ Question found in Firestore');
    console.log('question_type:', data.question_type);
    console.log('answer_type:', data.answer_type);
    console.log('correct_answer:', data.correct_answer);
    console.log('answer_range:', data.answer_range);
    
    if (!data.answer_type || data.answer_type !== 'text') {
      console.log('\n⚠️  answer_type field is missing or wrong! Updating...');
      await db.collection('questions').doc('MATH_STAT_M_002').update({
        answer_type: 'text'
      });
      console.log('✅ Updated answer_type to "text"');
    } else {
      console.log('\n✅ answer_type is already set to "text"');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkQuestion();
