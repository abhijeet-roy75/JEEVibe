/**
 * Merge Parabola Chapters
 *
 * Merges mathematics_parabola (9 harder questions) into
 * mathematics_conic_sections_parabola (26 easier questions)
 *
 * This gives students a total of 35 parabola questions with varied difficulty.
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function mergeParabolaChapters() {
  console.log('🔀 MERGING PARABOLA CHAPTERS');
  console.log('='.repeat(80));
  console.log('');

  // 1. Get all questions from mathematics_parabola
  const parabolaSnap = await db.collection('questions')
    .where('active', '==', true)
    .where('chapter_key', '==', 'mathematics_parabola')
    .get();

  console.log('📊 Found', parabolaSnap.size, 'questions in mathematics_parabola');
  console.log('');

  if (parabolaSnap.size === 0) {
    console.log('✅ No questions to merge - already done or none exist');
    process.exit(0);
  }

  // 2. Show what will be updated
  console.log('📝 Questions to update:');
  parabolaSnap.docs.forEach((doc, i) => {
    const data = doc.data();
    console.log(`   ${i + 1}. ${doc.id} - ${data.difficulty || 'unknown'}`);
  });
  console.log('');

  console.log('🔄 Will update these questions:');
  console.log('   FROM: chapter_key = "mathematics_parabola"');
  console.log('   TO:   chapter_key = "mathematics_conic_sections_parabola"');
  console.log('         chapter = "Conic Sections (Parabola)"');
  console.log('');

  // 3. Perform the update
  console.log('⏳ Updating questions...');

  const batch = db.batch();
  let updateCount = 0;

  parabolaSnap.docs.forEach(doc => {
    batch.update(doc.ref, {
      chapter_key: 'mathematics_conic_sections_parabola',
      chapter: 'Conic Sections (Parabola)',
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      merge_note: 'Merged from mathematics_parabola to mathematics_conic_sections_parabola on 2026-02-08'
    });
    updateCount++;
  });

  await batch.commit();

  console.log('✅ Successfully updated', updateCount, 'questions');
  console.log('');

  // 4. Verify the merge
  const verifyOld = await db.collection('questions')
    .where('active', '==', true)
    .where('chapter_key', '==', 'mathematics_parabola')
    .get();

  const verifyNew = await db.collection('questions')
    .where('active', '==', true)
    .where('chapter_key', '==', 'mathematics_conic_sections_parabola')
    .get();

  console.log('📊 VERIFICATION:');
  console.log('   mathematics_parabola:', verifyOld.size, 'questions (should be 0)');
  console.log('   mathematics_conic_sections_parabola:', verifyNew.size, 'questions (should be 35)');
  console.log('');

  if (verifyOld.size === 0 && verifyNew.size === 35) {
    console.log('🎉 MERGE COMPLETE!');
    console.log('');
    console.log('Students now have 35 total parabola questions:');
    console.log('   - 7 easy');
    console.log('   - 14 medium');
    console.log('   - 5 hard');
    console.log('   - 9 medium-hard/hard (newly merged)');
  } else {
    console.log('⚠️  Verification counts unexpected. Please check manually.');
  }

  process.exit(0);
}

mergeParabolaChapters().catch(error => {
  console.error('❌ Error:', error);
  process.exit(1);
});
