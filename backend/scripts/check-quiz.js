const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();
const userId = 'Ap5Ah9o9aNV4tI9QDrq19E8Vmmz1';
const quizId = 'quiz_1_2026-01-24';

async function checkQuiz() {
  console.log('Checking quiz at: daily_quizzes/' + userId + '/quizzes/' + quizId);

  // Check the exact path
  const quizRef = db.collection('daily_quizzes')
    .doc(userId)
    .collection('quizzes')
    .doc(quizId);

  const quizDoc = await quizRef.get();

  if (quizDoc.exists) {
    console.log('QUIZ FOUND:');
    console.log(JSON.stringify(quizDoc.data(), null, 2));
  } else {
    console.log('QUIZ NOT FOUND at this path');

    // List all quizzes for this user
    console.log('\nListing all quizzes for user:');
    const allQuizzes = await db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .get();

    if (allQuizzes.empty) {
      console.log('No quizzes found for this user');
    } else {
      allQuizzes.forEach(doc => {
        console.log('- Quiz ID:', doc.id, '| Status:', doc.data().status);
      });
    }
  }

  // Also check if the user doc exists
  console.log('\nChecking user doc at daily_quizzes/' + userId);
  const userDoc = await db.collection('daily_quizzes').doc(userId).get();
  console.log('User doc exists:', userDoc.exists);
}

checkQuiz().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
