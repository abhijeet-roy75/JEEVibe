#!/usr/bin/env node
const { db } = require('../src/config/firebase');

(async () => {
  const userId = 'whXKoBgqYQaD6NQafUDKGZcC5J42';

  console.log('Deep search for quiz data...\n');

  // 1. Check user document for quiz counters
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();

  console.log('User document quiz metadata:');
  console.log('  completed_quiz_count:', userData.completed_quiz_count);
  console.log('  total_questions_solved:', userData.total_questions_solved);
  console.log('  last_quiz_completed_at:', userData.last_quiz_completed_at?.toDate());
  console.log('  learning_phase:', userData.learning_phase);
  console.log('  current_day:', userData.current_day);

  // 2. Check quiz_responses collection (where individual answers are stored)
  console.log('\n' + '='.repeat(70));
  console.log('Checking quiz_responses collection...\n');

  const responsesSnap = await db.collection('quiz_responses')
    .where('user_id', '==', userId)
    .orderBy('answered_at', 'desc')
    .limit(20)
    .get();

  console.log(`Found ${responsesSnap.size} question responses`);

  if (responsesSnap.size > 0) {
    const quizIds = new Set();
    const unlockedChapters = new Set([
      'physics_units_measurements', 'physics_kinematics',
      'chemistry_basic_concepts', 'chemistry_atomic_structure', 'chemistry_chemical_bonding',
      'mathematics_sets_relations_functions', 'mathematics_trigonometry'
    ]);

    responsesSnap.docs.forEach(doc => {
      const response = doc.data();
      quizIds.add(response.quiz_id);
    });

    console.log(`\nUnique quiz IDs: ${quizIds.size}`);
    console.log('Quiz IDs:', Array.from(quizIds));

    // Now fetch the actual quizzes and check for violations
    for (const quizId of quizIds) {
      const quizDoc = await db.collection('daily_quizzes')
        .doc(userId)
        .collection('quizzes')
        .doc(quizId)
        .get();

      if (quizDoc.exists) {
        const quiz = quizDoc.data();
        console.log(`\n${'='.repeat(70)}`);
        console.log(`📝 Quiz: ${quizId}`);
        console.log(`   Status: ${quiz.status}`);
        console.log(`   Created: ${quiz.created_at?.toDate()}`);
        console.log(`   Completed: ${quiz.completed_at?.toDate()}`);
        console.log(`   Score: ${quiz.score || 0}/${quiz.questions?.length || 0}`);
        console.log(`   Questions: ${quiz.questions?.length || 0}`);

        if (quiz.questions) {
          const violations = [];
          console.log('\n   Chapter breakdown:');
          quiz.questions.forEach((q, idx) => {
            const ch = q.chapter_key || q.chapter || 'Unknown';
            const isUnlocked = unlockedChapters.has(ch);
            const status = isUnlocked ? '✅' : '🔒';
            console.log(`     Q${idx + 1}: ${status} ${ch} (${q.subject || 'Unknown'})`);

            if (!isUnlocked && ch !== 'Unknown') {
              violations.push({ q: idx + 1, ch, subject: q.subject });
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
      } else {
        console.log(`\n❌ Quiz document ${quizId} not found in daily_quizzes/{userId}/quizzes`);
      }
    }
  } else {
    console.log('\nNo quiz responses found. User may not have completed any quizzes yet.');
  }

  process.exit(0);
})();
