/**
 * Fix Physics Month 14 Unlock Schedule
 *
 * Problem: Month 14 has "physics_emi_ac_circuits" which doesn't exist in database.
 * This causes 4 physics chapters to remain locked even when they should be unlocked.
 *
 * Solution: Replace the invalid key with 4 actual chapter keys:
 * - physics_electromagnetic_induction (21 questions)
 * - physics_ac_circuits (22 questions)
 * - physics_eddy_currents (3 questions)
 * - physics_transformers (4 questions)
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function fixPhysicsMonth14() {
  console.log('⚡ FIXING PHYSICS MONTH 14 UNLOCK SCHEDULE');
  console.log('='.repeat(80));
  console.log('');

  // 1. Get the active unlock schedule
  const scheduleSnap = await db.collection('unlock_schedules')
    .where('type', '==', 'countdown_24month')
    .where('active', '==', true)
    .limit(1)
    .get();

  if (scheduleSnap.empty) {
    console.error('❌ No active unlock schedule found');
    process.exit(1);
  }

  const scheduleDoc = scheduleSnap.docs[0];
  const schedule = scheduleDoc.data();
  const currentMonth14 = schedule.timeline.month_14;

  console.log('📅 CURRENT MONTH 14:');
  console.log('   Physics:', currentMonth14.physics);
  console.log('   Chemistry:', currentMonth14.chemistry);
  console.log('   Mathematics:', currentMonth14.mathematics);
  console.log('');

  // 2. Verify the problematic key exists
  if (!currentMonth14.physics.includes('physics_emi_ac_circuits')) {
    console.log('✅ Month 14 already fixed or issue not present');
    console.log('   Current physics chapters:', currentMonth14.physics);
    process.exit(0);
  }

  // 3. Define the new physics chapters for month 14
  const newPhysicsChapters = [
    'physics_electromagnetic_induction',
    'physics_ac_circuits',
    'physics_eddy_currents',
    'physics_transformers'
  ];

  console.log('🔄 PROPOSED CHANGE:');
  console.log('   REMOVE: physics_emi_ac_circuits');
  console.log('   ADD:');
  newPhysicsChapters.forEach(ch => console.log('     -', ch));
  console.log('');

  // 4. Verify all new chapters exist in database
  console.log('✅ VERIFYING CHAPTERS IN DATABASE:');
  for (const chapterKey of newPhysicsChapters) {
    const questionsSnap = await db.collection('questions')
      .where('active', '==', true)
      .where('chapter_key', '==', chapterKey)
      .limit(1)
      .get();

    if (questionsSnap.empty) {
      console.error('❌ Chapter', chapterKey, 'not found in database!');
      process.exit(1);
    }
    console.log('   ✓', chapterKey, '- exists');
  }
  console.log('');

  // 5. Update the schedule
  console.log('⏳ Updating unlock schedule...');

  await scheduleDoc.ref.update({
    'timeline.month_14.physics': newPhysicsChapters,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
    last_fix: 'Replaced physics_emi_ac_circuits with 4 actual chapter keys (2026-02-08)'
  });

  console.log('✅ Schedule updated successfully');
  console.log('');

  // 6. Verify the update
  const verifySnap = await scheduleDoc.ref.get();
  const verifyData = verifySnap.data();
  const verifyMonth14 = verifyData.timeline.month_14;

  console.log('📊 VERIFICATION - NEW MONTH 14:');
  console.log('   Physics:', verifyMonth14.physics);
  console.log('');

  const hasInvalidKey = verifyMonth14.physics.includes('physics_emi_ac_circuits');
  const hasAllNewKeys = newPhysicsChapters.every(k => verifyMonth14.physics.includes(k));

  if (hasInvalidKey) {
    console.error('❌ Verification failed - invalid key still present');
    process.exit(1);
  }

  if (!hasAllNewKeys) {
    console.error('❌ Verification failed - not all new keys present');
    process.exit(1);
  }

  console.log('✅ Verification passed!');
  console.log('');
  console.log('🎉 FIX COMPLETE!');
  console.log('');
  console.log('IMPACT:');
  console.log('   - Students at month 14+ will now unlock 4 physics chapters');
  console.log('   - Total questions unlocked: ~50 (21+22+3+4)');
  console.log('   - Chapters: EMI, AC Circuits, Eddy Currents, Transformers');

  process.exit(0);
}

fixPhysicsMonth14().catch(error => {
  console.error('❌ Error:', error);
  process.exit(1);
});
