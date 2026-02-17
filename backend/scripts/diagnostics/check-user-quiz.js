/**
 * Check the actual quiz stored for a user
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

async function checkUserQuiz(userId) {
  console.log('======================================================================');
  console.log('🔍 Checking stored quiz for user');
  console.log('======================================================================\n');

  // Get the user's quizzes
  const quizzesSnap = await db.collection('daily_quizzes')
    .doc(userId)
    .collection('quizzes')
    .orderBy('generated_at', 'desc')
    .limit(1)
    .get();

  if (quizzesSnap.empty) {
    console.log('No quizzes found for user');
    process.exit(0);
  }

  const quizDoc = quizzesSnap.docs[0];
  const quizData = quizDoc.data();

  console.log(`Quiz ID: ${quizDoc.id}`);
  console.log(`Status: ${quizData.status}`);
  console.log(`Generated at: ${quizData.generated_at}`);
  console.log(`Learning phase: ${quizData.learning_phase}`);
  console.log(`Total questions: ${quizData.total_questions}`);

  // Get questions subcollection
  const questionsSnap = await db.collection('daily_quizzes')
    .doc(userId)
    .collection('quizzes')
    .doc(quizDoc.id)
    .collection('questions')
    .orderBy('position', 'asc')
    .get();

  console.log(`\nQuestions in quiz: ${questionsSnap.size}`);
  console.log('\n--- Questions ---');

  const subjectCounts = { Physics: 0, Chemistry: 0, Mathematics: 0 };

  questionsSnap.docs.forEach((doc, i) => {
    const q = doc.data();
    console.log(`${i + 1}. ${q.question_id}`);
    console.log(`   Subject: ${q.subject}, Chapter: ${q.chapter}`);
    console.log(`   Selection reason: ${q.selection_reason || 'N/A'}`);
    console.log(`   Chapter key: ${q.chapter_key || 'N/A'}`);

    if (subjectCounts[q.subject] !== undefined) {
      subjectCounts[q.subject]++;
    }
  });

  console.log('\n--- Subject Distribution ---');
  console.log(`Physics: ${subjectCounts.Physics}`);
  console.log(`Chemistry: ${subjectCounts.Chemistry}`);
  console.log(`Mathematics: ${subjectCounts.Mathematics}`);

  // Also check responses
  console.log('\n--- Quiz Responses ---');
  const responsesSnap = await db.collection('daily_quiz_responses')
    .doc(userId)
    .collection('responses')
    .where('quiz_id', '==', quizDoc.id)
    .get();

  console.log(`Total responses: ${responsesSnap.size}`);

  const responseSubjectCounts = { Physics: 0, Chemistry: 0, Mathematics: 0 };
  responsesSnap.docs.forEach(doc => {
    const r = doc.data();
    const subject = r.subject;
    if (responseSubjectCounts[subject] !== undefined) {
      responseSubjectCounts[subject]++;
    }
  });

  console.log(`Physics: ${responseSubjectCounts.Physics}`);
  console.log(`Chemistry: ${responseSubjectCounts.Chemistry}`);
  console.log(`Mathematics: ${responseSubjectCounts.Mathematics}`);

  process.exit(0);
}

const userId = process.argv[2] || 'z93J7wOVYOPzYqin3NkS4aukX4b2';
checkUserQuiz(userId).catch(e => { console.error(e); process.exit(1); });
