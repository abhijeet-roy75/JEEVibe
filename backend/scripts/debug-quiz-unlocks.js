#!/usr/bin/env node
/**
 * Debug Daily Quiz Chapter Unlocks
 *
 * Checks if daily quiz questions are coming from unlocked chapters only.
 * Usage: node scripts/debug-quiz-unlocks.js <phone_number>
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function debugUser(phone) {
  console.log('╔════════════════════════════════════════════════════════════');
  console.log('║ DAILY QUIZ UNLOCK DEBUG');
  console.log('╚════════════════════════════════════════════════════════════\n');

  // Find user by phone
  const usersSnapshot = await db.collection('users')
    .where('phoneNumber', '==', phone)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.log('❌ User not found with phone:', phone);
    process.exit(1);
  }

  const userDoc = usersSnapshot.docs[0];
  const userId = userDoc.id;
  const userData = userDoc.data();

  console.log('📱 USER INFO');
  console.log('   User ID:', userId);
  console.log('   Phone:', userData.phoneNumber);
  console.log('   Name:', userData.firstName || 'Unknown');
  console.log('   JEE Exam Date:', userData.jee_exam_date?.toDate().toISOString().split('T')[0] || 'Not set');
  console.log('   Enrolled in Coaching:', userData.isEnrolledInCoaching ? 'Yes' : 'No');
  console.log('');

  // Get unlocked chapters
  const unlockedChapters = userData.unlocked_chapters || [];
  console.log('🔓 UNLOCKED CHAPTERS');
  if (unlockedChapters.length === 0) {
    console.log('   ⚠️  NO CHAPTERS UNLOCKED!');
  } else {
    console.log(`   Total: ${unlockedChapters.length} chapters`);

    // Group by subject
    const bySubject = { physics: [], chemistry: [], mathematics: [] };
    unlockedChapters.forEach(ch => {
      if (ch.startsWith('physics_')) bySubject.physics.push(ch);
      else if (ch.startsWith('chemistry_')) bySubject.chemistry.push(ch);
      else if (ch.startsWith('mathematics_')) bySubject.mathematics.push(ch);
    });

    console.log(`\n   Physics (${bySubject.physics.length}):`);
    bySubject.physics.forEach(ch => console.log(`     • ${ch}`));
    console.log(`\n   Chemistry (${bySubject.chemistry.length}):`);
    bySubject.chemistry.forEach(ch => console.log(`     • ${ch}`));
    console.log(`\n   Mathematics (${bySubject.mathematics.length}):`);
    bySubject.mathematics.forEach(ch => console.log(`     • ${ch}`));
  }
  console.log('');

  // Get recent daily quizzes
  console.log('📊 RECENT DAILY QUIZZES (Last 5)');
  console.log('═'.repeat(60));
  const quizzesSnapshot = await db.collection('users')
    .doc(userId)
    .collection('daily_quizzes')
    .orderBy('created_at', 'desc')
    .limit(5)
    .get();

  if (quizzesSnapshot.empty) {
    console.log('   No daily quizzes found');
  } else {
    let totalViolations = 0;

    for (const quizDoc of quizzesSnapshot.docs) {
      const quiz = quizDoc.data();
      const date = quiz.created_at ? quiz.created_at.toDate().toISOString().split('T')[0] : 'Unknown';
      const questions = quiz.questions || [];

      console.log(`\n📝 Quiz: ${date}`);
      console.log(`   ID: ${quizDoc.id}`);
      console.log(`   Questions: ${questions.length}`);

      // Analyze chapters
      const chapterAnalysis = {};
      const violations = [];

      questions.forEach((q, idx) => {
        const chapter = q.chapter_key || q.chapter || 'Unknown';
        const questionId = q.question_id || q.id || 'Unknown';

        if (!chapterAnalysis[chapter]) {
          chapterAnalysis[chapter] = {
            count: 0,
            isUnlocked: unlockedChapters.includes(chapter),
            questions: []
          };
        }

        chapterAnalysis[chapter].count++;
        chapterAnalysis[chapter].questions.push({ idx: idx + 1, questionId });

        // Check if locked
        if (!chapterAnalysis[chapter].isUnlocked && chapter !== 'Unknown') {
          violations.push({
            questionNum: idx + 1,
            chapter,
            questionId
          });
        }
      });

      console.log('\n   Chapters:');
      Object.entries(chapterAnalysis).forEach(([chapter, info]) => {
        const status = info.isUnlocked ? '✅ UNLOCKED' : '🔒 LOCKED  ';
        console.log(`   ${status}  ${chapter.padEnd(35)} ${info.count} question(s)`);
      });

      if (violations.length > 0) {
        console.log(`\n   ⚠️  VIOLATIONS: ${violations.length} questions from LOCKED chapters:`);
        violations.forEach(v => {
          console.log(`      Q${v.questionNum}: ${v.questionId}`);
          console.log(`           Chapter: ${v.chapter}`);
        });
        totalViolations += violations.length;
      } else {
        console.log('\n   ✅ All questions from unlocked chapters');
      }
    }

    console.log('\n' + '═'.repeat(60));
    if (totalViolations > 0) {
      console.log(`\n🚨 TOTAL VIOLATIONS: ${totalViolations} questions from locked chapters`);
    } else {
      console.log('\n✅ No violations found - all quiz questions from unlocked chapters');
    }
  }

  console.log('\n✅ Debug complete\n');
}

// Main
const phone = process.argv[2];
if (!phone) {
  console.error('Usage: node scripts/debug-quiz-unlocks.js <phone_number>');
  console.error('Example: node scripts/debug-quiz-unlocks.js +14125965484');
  process.exit(1);
}

debugUser(phone)
  .then(() => process.exit(0))
  .catch(err => {
    console.error('❌ Error:', err.message);
    console.error(err.stack);
    process.exit(1);
  });
