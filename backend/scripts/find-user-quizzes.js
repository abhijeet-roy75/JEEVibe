#!/usr/bin/env node
const { db } = require('../src/config/firebase');

(async () => {
  const userId = 'whXKoBgqYQaD6NQafUDKGZcC5J42';

  console.log('Searching for completed quizzes...\n');

  // Direct query to daily_quizzes collection
  const quizzesSnap = await db.collection('daily_quizzes')
    .doc(userId)
    .collection('quizzes')
    .get(); // Get all without ordering

  console.log(`Found ${quizzesSnap.size} quiz documents\n`);

  if (quizzesSnap.size > 0) {
    const unlockedChapters = new Set([
      'physics_units_measurements', 'physics_kinematics',
      'chemistry_basic_concepts', 'chemistry_atomic_structure', 'chemistry_chemical_bonding',
      'mathematics_sets_relations_functions', 'mathematics_trigonometry'
    ]);

    const quizzes = quizzesSnap.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    })).sort((a, b) => {
      const aTime = a.created_at?.toDate() || new Date(0);
      const bTime = b.created_at?.toDate() || new Date(0);
      return bTime - aTime;
    });

    for (const [idx, quiz] of quizzes.entries()) {
      console.log(`${'='.repeat(70)}`);
      console.log(`📝 Quiz ${idx + 1}: ${quiz.id}`);
      console.log(`   Status: ${quiz.status}`);
      console.log(`   Created: ${quiz.created_at?.toDate()}`);
      console.log(`   Completed: ${quiz.completed_at?.toDate() || 'Not completed'}`);
      console.log(`   Score: ${quiz.score || 0}/${quiz.questions?.length || 0}`);
      console.log(`   Accuracy: ${(quiz.accuracy * 100).toFixed(1)}%`);
      console.log(`   Questions: ${quiz.questions?.length || 0}`);

      // Fetch questions from subcollection
      const questionsSnap = await db.collection('daily_quizzes')
        .doc(userId)
        .collection('quizzes')
        .doc(quiz.id)
        .collection('questions')
        .orderBy('position', 'asc')
        .get();

      const questions = questionsSnap.docs.map(doc => doc.data());

      console.log(`   Questions in subcollection: ${questions.length}`);

      if (questions.length > 0) {
        const violations = [];
        console.log('\n   Chapter breakdown:');
        questions.forEach((q, qIdx) => {
          const ch = q.chapter_key || q.chapter || 'Unknown';
          const isUnlocked = unlockedChapters.has(ch);
          const status = isUnlocked ? '✅' : '🔒';
          console.log(`     Q${qIdx + 1}: ${status} ${ch.padEnd(45)} (${q.subject || 'Unknown'})`);

          if (!isUnlocked && ch !== 'Unknown') {
            violations.push({ q: qIdx + 1, ch, subject: q.subject });
          }
        });

        if (violations.length > 0) {
          console.log(`\n   🚨 VIOLATIONS: ${violations.length} questions from LOCKED chapters:`);
          violations.forEach(v => {
            console.log(`      Q${v.q}: ${v.ch} (${v.subject})`);
          });
        } else {
          console.log('\n   ✅ All questions from unlocked chapters');
        }
      }
      console.log('');
    }

    // Summary
    console.log('='.repeat(70));
    console.log('\n📊 SUMMARY:');
    console.log(`   Total quizzes found: ${quizzes.length}`);
    console.log(`   Completed quizzes: ${quizzes.filter(q => q.status === 'completed').length}`);
    console.log(`   Active quizzes: ${quizzes.filter(q => q.status === 'active').length}`);

    const totalViolations = quizzes.reduce((sum, quiz) => {
      if (!quiz.questions) return sum;
      return sum + quiz.questions.filter(q => {
        const ch = q.chapter_key || q.chapter || 'Unknown';
        return !unlockedChapters.has(ch) && ch !== 'Unknown';
      }).length;
    }, 0);

    console.log(`   Total unlock violations: ${totalViolations}`);
  }

  process.exit(0);
})();
