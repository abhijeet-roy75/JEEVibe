/**
 * Check which questions have distractor_analysis and common_mistakes fields
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

async function checkQuestionFields() {
  console.log('======================================================================');
  console.log('🔍 Checking question fields: distractor_analysis & common_mistakes');
  console.log('======================================================================\n');

  const questionsSnap = await db.collection('questions').get();

  let total = 0;
  let hasDistractorAnalysis = 0;
  let hasCommonMistakes = 0;
  let hasBoth = 0;
  let hasNeither = 0;

  const sampleWithDistractor = [];
  const sampleWithMistakes = [];

  questionsSnap.docs.forEach(doc => {
    const data = doc.data();
    total++;

    const hasDA = data.distractor_analysis &&
                  (typeof data.distractor_analysis === 'object' ||
                   (typeof data.distractor_analysis === 'string' && data.distractor_analysis.length > 0));
    const hasCM = data.common_mistakes &&
                  (Array.isArray(data.common_mistakes) ? data.common_mistakes.length > 0 : true);

    if (hasDA) {
      hasDistractorAnalysis++;
      if (sampleWithDistractor.length < 3) {
        sampleWithDistractor.push({
          id: doc.id,
          distractor_analysis: data.distractor_analysis
        });
      }
    }

    if (hasCM) {
      hasCommonMistakes++;
      if (sampleWithMistakes.length < 3) {
        sampleWithMistakes.push({
          id: doc.id,
          common_mistakes: data.common_mistakes
        });
      }
    }

    if (hasDA && hasCM) hasBoth++;
    if (!hasDA && !hasCM) hasNeither++;
  });

  console.log(`Total questions: ${total}`);
  console.log(`\n--- Field Presence ---`);
  console.log(`Has distractor_analysis: ${hasDistractorAnalysis} (${(hasDistractorAnalysis/total*100).toFixed(1)}%)`);
  console.log(`Has common_mistakes: ${hasCommonMistakes} (${(hasCommonMistakes/total*100).toFixed(1)}%)`);
  console.log(`Has both: ${hasBoth} (${(hasBoth/total*100).toFixed(1)}%)`);
  console.log(`Has neither: ${hasNeither} (${(hasNeither/total*100).toFixed(1)}%)`);

  if (sampleWithDistractor.length > 0) {
    console.log('\n--- Sample questions with distractor_analysis ---');
    sampleWithDistractor.forEach(q => {
      console.log(`\n${q.id}:`);
      console.log(JSON.stringify(q.distractor_analysis, null, 2).substring(0, 500));
    });
  }

  if (sampleWithMistakes.length > 0) {
    console.log('\n--- Sample questions with common_mistakes ---');
    sampleWithMistakes.forEach(q => {
      console.log(`\n${q.id}:`);
      console.log(JSON.stringify(q.common_mistakes, null, 2).substring(0, 500));
    });
  }

  // Also check what other solution-related fields exist
  console.log('\n--- Checking solution-related fields ---');
  const sampleDoc = questionsSnap.docs[0];
  if (sampleDoc) {
    const data = sampleDoc.data();
    console.log(`\nSample question ${sampleDoc.id} has:`);
    console.log(`  solution_text: ${data.solution_text ? 'YES' : 'NO'}`);
    console.log(`  solution_steps: ${data.solution_steps?.length || 0} steps`);
    console.log(`  key_insight: ${data.key_insight ? 'YES' : 'NO'}`);
    console.log(`  concepts_tested: ${data.concepts_tested?.length || 0} concepts`);
    console.log(`  distractor_analysis: ${data.distractor_analysis ? 'YES' : 'NO'}`);
    console.log(`  common_mistakes: ${data.common_mistakes ? 'YES' : 'NO'}`);
  }

  process.exit(0);
}

checkQuestionFields().catch(e => { console.error(e); process.exit(1); });
