/**
 * Test the actual Firestore query for question selection
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

async function testQuery() {
  console.log('Testing question selection query...\n');

  // Test the exact query used in questionSelectionService
  const subject = 'Physics';
  const chapter = 'Laws of Motion';

  console.log(`Query: active != false, subject = "${subject}", chapter = "${chapter}"`);
  console.log('Order by: irt_parameters.discrimination_a DESC\n');

  try {
    const snapshot = await db.collection('questions')
      .where('active', '==', true)
      .where('subject', '==', subject)
      .where('chapter', '==', chapter)
      .orderBy('irt_parameters.discrimination_a', 'desc')
      .limit(10)
      .get();

    console.log(`✅ Query succeeded! Found ${snapshot.size} questions`);

    if (snapshot.size > 0) {
      console.log('\nFirst 3 questions:');
      snapshot.docs.slice(0, 3).forEach((doc, i) => {
        const d = doc.data();
        console.log(`  ${i + 1}. ${doc.id} - ${d.subject}/${d.chapter} (a=${d.irt_parameters?.discrimination_a})`);
      });
    }
  } catch (error) {
    console.log(`❌ Query FAILED: ${error.message}`);

    if (error.message.includes('index')) {
      console.log('\n⚠️  INDEX ISSUE DETECTED');
      console.log('The error suggests the composite index is missing or still building.');
    }
  }

  // Also test without the active filter to compare
  console.log('\n--- Testing WITHOUT active filter ---');
  try {
    const snapshot2 = await db.collection('questions')
      .where('subject', '==', subject)
      .where('chapter', '==', chapter)
      .orderBy('irt_parameters.discrimination_a', 'desc')
      .limit(10)
      .get();

    console.log(`✅ Query (no active filter) found ${snapshot2.size} questions`);
  } catch (error) {
    console.log(`❌ Query (no active filter) FAILED: ${error.message}`);
  }

  // Check if questions have 'active' field set
  console.log('\n--- Checking active field values ---');
  const sampleSnap = await db.collection('questions').limit(5).get();
  sampleSnap.docs.forEach(doc => {
    const d = doc.data();
    console.log(`  ${doc.id}: active = ${d.active} (type: ${typeof d.active})`);
  });

  process.exit(0);
}

testQuery().catch(e => { console.error(e); process.exit(1); });
