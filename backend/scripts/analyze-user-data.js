const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();
const phoneNumber = '+14125965484';

async function analyzeUserData() {
  console.log('=== Analyzing data for phone: ' + phoneNumber + ' ===\n');

  // 1. Find user by phone number
  console.log('1. USERS COLLECTION');
  console.log('-'.repeat(50));
  const usersSnapshot = await db.collection('users').where('phoneNumber', '==', phoneNumber).get();

  if (usersSnapshot.empty) {
    console.log('No user found with this phone number');
    return;
  }

  let userId = null;
  usersSnapshot.forEach(doc => {
    userId = doc.id;
    const data = doc.data();
    console.log('User ID:', doc.id);
    console.log('Data:', JSON.stringify(data, null, 2));
  });

  if (!userId) return;

  // 2. Check daily_quizzes subcollection
  console.log('\n2. DAILY QUIZZES (subcollection)');
  console.log('-'.repeat(50));
  const dailyQuizzesSnapshot = await db.collection('users').doc(userId).collection('daily_quizzes').get();
  console.log('Count:', dailyQuizzesSnapshot.size);
  dailyQuizzesSnapshot.forEach(doc => {
    console.log('  Quiz ID:', doc.id);
    const data = doc.data();
    console.log('  Status:', data.status, '| Score:', data.score, '/', data.totalQuestions);
    console.log('  Created:', data.createdAt?.toDate?.() || data.createdAt);
  });

  // 3. Check quiz_sessions collection
  console.log('\n3. QUIZ SESSIONS (top-level)');
  console.log('-'.repeat(50));
  const quizSessionsSnapshot = await db.collection('quiz_sessions').where('userId', '==', userId).get();
  console.log('Count:', quizSessionsSnapshot.size);
  quizSessionsSnapshot.forEach(doc => {
    const data = doc.data();
    console.log('  Session ID:', doc.id);
    console.log('  Status:', data.status, '| Score:', data.score, '/', data.totalQuestions);
  });

  // 4. Check chapter_practice_sessions
  console.log('\n4. CHAPTER PRACTICE SESSIONS');
  console.log('-'.repeat(50));
  const practiceSnapshot = await db.collection('chapter_practice_sessions').where('userId', '==', userId).get();
  console.log('Count:', practiceSnapshot.size);
  practiceSnapshot.forEach(doc => {
    const data = doc.data();
    console.log('  Session ID:', doc.id);
    console.log('  Chapter:', data.chapterName, '| Status:', data.status);
    console.log('  Score:', data.correctCount, '/', data.totalQuestions);
  });

  // 5. Check user_question_history
  console.log('\n5. USER QUESTION HISTORY');
  console.log('-'.repeat(50));
  const historySnapshot = await db.collection('user_question_history').where('userId', '==', userId).limit(10).get();
  console.log('Count (showing max 10):', historySnapshot.size);

  // 6. Check snap_solve_history
  console.log('\n6. SNAP SOLVE HISTORY');
  console.log('-'.repeat(50));
  const snapSnapshot = await db.collection('snap_solve_history').where('userId', '==', userId).get();
  console.log('Count:', snapSnapshot.size);

  // 7. Check user_mastery subcollection
  console.log('\n7. USER MASTERY (subcollection)');
  console.log('-'.repeat(50));
  const masterySnapshot = await db.collection('users').doc(userId).collection('mastery').get();
  console.log('Count:', masterySnapshot.size);
  masterySnapshot.forEach(doc => {
    const data = doc.data();
    console.log('  Topic:', doc.id, '| Level:', data.masteryLevel, '| Correct:', data.correctCount, '/', data.totalAttempts);
  });

  console.log('\n=== Analysis Complete ===');
}

analyzeUserData().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
