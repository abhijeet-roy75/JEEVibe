/**
 * Detailed check of distractor_analysis field in database
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

async function checkDistractorDetailed() {
  console.log('Checking distractor_analysis field in detail...\n');

  const snapshot = await db.collection('questions').limit(20).get();

  snapshot.docs.forEach((doc, i) => {
    const data = doc.data();
    console.log(`${i + 1}. ${doc.id}`);
    console.log(`   distractor_analysis: ${JSON.stringify(data.distractor_analysis)}`);
    console.log(`   metadata.common_mistakes: ${JSON.stringify(data.metadata?.common_mistakes)}`);
    console.log(`   metadata.key_insight: ${data.metadata?.key_insight}`);
    console.log('');
  });

  process.exit(0);
}

checkDistractorDetailed().catch(e => { console.error(e); process.exit(1); });
