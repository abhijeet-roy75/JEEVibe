/**
 * Find questions with contradictory question_type and data
 *
 * Pattern: question_type = "numerical" but has MCQ-style data
 * - Has options array with A, B, C, D
 * - Has correct_answer as a letter (A, B, C, D)
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

async function findBadQuestionTypes() {
  console.log('======================================================================');
  console.log('🔍 Finding questions with contradictory type/data');
  console.log('======================================================================\n');

  const snapshot = await db.collection('questions').get();

  const problems = {
    numericalWithMcqOptions: [],
    mcqWithoutOptions: [],
    numericalWithLetterAnswer: [],
    otherIssues: []
  };

  snapshot.docs.forEach(doc => {
    const d = doc.data();
    const questionId = doc.id;
    const questionType = d.question_type;
    const hasOptions = d.options && Array.isArray(d.options) && d.options.length > 0;
    const correctAnswer = d.correct_answer;
    const answerType = d.answer_type;

    // Check if correct_answer is a letter (MCQ style)
    const isLetterAnswer = correctAnswer && /^[A-Da-d]$/.test(String(correctAnswer).trim());

    // Pattern 1: numerical type but has options array
    if (questionType === 'numerical' && hasOptions) {
      problems.numericalWithMcqOptions.push({
        id: questionId,
        subject: d.subject,
        chapter: d.chapter,
        question_type: questionType,
        options_count: d.options.length,
        correct_answer: correctAnswer,
        answer_type: answerType,
        question_text: (d.question_text || '').substring(0, 80) + '...'
      });
    }

    // Pattern 2: numerical type with letter answer
    if (questionType === 'numerical' && isLetterAnswer) {
      // Only add if not already in numericalWithMcqOptions
      const alreadyFound = problems.numericalWithMcqOptions.some(p => p.id === questionId);
      if (!alreadyFound) {
        problems.numericalWithLetterAnswer.push({
          id: questionId,
          subject: d.subject,
          chapter: d.chapter,
          correct_answer: correctAnswer,
          answer_type: answerType
        });
      }
    }

    // Pattern 3: MCQ type but no options
    if (questionType === 'mcq_single' && !hasOptions) {
      problems.mcqWithoutOptions.push({
        id: questionId,
        subject: d.subject,
        chapter: d.chapter
      });
    }
  });

  // Report findings
  console.log(`Total questions scanned: ${snapshot.size}\n`);

  console.log('=== NUMERICAL TYPE WITH MCQ OPTIONS ===');
  console.log(`Found: ${problems.numericalWithMcqOptions.length}\n`);

  if (problems.numericalWithMcqOptions.length > 0) {
    // Group by chapter
    const byChapter = {};
    problems.numericalWithMcqOptions.forEach(p => {
      const key = `${p.subject} / ${p.chapter}`;
      if (!byChapter[key]) byChapter[key] = [];
      byChapter[key].push(p);
    });

    Object.entries(byChapter).forEach(([chapter, questions]) => {
      console.log(`\n📁 ${chapter} (${questions.length} questions)`);
      questions.forEach(q => {
        console.log(`   ${q.id}`);
        console.log(`      type: ${q.question_type}, options: ${q.options_count}, answer: "${q.correct_answer}", answer_type: ${q.answer_type}`);
      });
    });
  }

  console.log('\n\n=== NUMERICAL TYPE WITH LETTER ANSWER (no options) ===');
  console.log(`Found: ${problems.numericalWithLetterAnswer.length}`);
  problems.numericalWithLetterAnswer.slice(0, 10).forEach(p => {
    console.log(`   ${p.id}: answer="${p.correct_answer}"`);
  });

  console.log('\n\n=== MCQ TYPE WITHOUT OPTIONS ===');
  console.log(`Found: ${problems.mcqWithoutOptions.length}`);
  problems.mcqWithoutOptions.slice(0, 10).forEach(p => {
    console.log(`   ${p.id}`);
  });

  // Summary
  console.log('\n\n======================================================================');
  console.log('📊 Summary');
  console.log('======================================================================');
  console.log(`Numerical with MCQ options: ${problems.numericalWithMcqOptions.length}`);
  console.log(`Numerical with letter answer: ${problems.numericalWithLetterAnswer.length}`);
  console.log(`MCQ without options: ${problems.mcqWithoutOptions.length}`);

  // Return IDs for potential fix
  return problems;
}

findBadQuestionTypes()
  .then(problems => {
    if (problems.numericalWithMcqOptions.length > 0) {
      console.log('\n\n--- Question IDs needing fix (numerical → mcq_single) ---');
      console.log(problems.numericalWithMcqOptions.map(p => p.id).join('\n'));
    }
    process.exit(0);
  })
  .catch(e => { console.error(e); process.exit(1); });
