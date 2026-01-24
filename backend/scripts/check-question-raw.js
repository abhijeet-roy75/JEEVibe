/**
 * Check raw question document from Firebase
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

async function checkRaw() {
  // Get a question that should have distractor_analysis
  const doc = await db.collection('questions').doc('PHY_LOM_E_001').get();

  if (!doc.exists) {
    console.log('PHY_LOM_E_001 not found');
    process.exit(0);
  }

  const data = doc.data();

  console.log('Full question document:');
  console.log(JSON.stringify(data, null, 2));

  process.exit(0);
}

checkRaw().catch(e => { console.error(e); process.exit(1); });
