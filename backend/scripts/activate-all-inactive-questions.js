#!/usr/bin/env node
/**
 * Activate All Inactive Questions
 *
 * Sets active: true for all questions where active is false or undefined
 *
 * Usage:
 *   node scripts/activate-all-inactive-questions.js --dry-run  (preview only)
 *   node scripts/activate-all-inactive-questions.js             (actually activate)
 */

require('dotenv').config();
const { db, FieldValue } = require('../src/config/firebase');

async function activateAllInactive(dryRun = false) {
  console.log('\n🔧 Activating ALL inactive questions');
  if (dryRun) {
    console.log('🧪 DRY RUN MODE - No changes will be made\n');
  } else {
    console.log('⚠️  LIVE MODE - Questions will be activated\n');
  }

  // Find all inactive questions (active === false or active === undefined)
  console.log('📊 Scanning questions collection...\n');

  const snapshot = await db.collection('questions').get();

  const inactive = [];
  const active = [];
  const byChapter = new Map();

  snapshot.forEach(doc => {
    const data = doc.data();
    const isActive = data.active === true;

    if (!isActive) {
      inactive.push({ id: doc.id, data });

      // Group by chapter_key for reporting
      const chapterKey = data.chapter_key || 'unknown';
      if (!byChapter.has(chapterKey)) {
        byChapter.set(chapterKey, {
          subject: data.subject,
          chapter: data.chapter,
          count: 0
        });
      }
      byChapter.get(chapterKey).count++;
    } else {
      active.push(doc.id);
    }
  });

  console.log('Status summary:');
  console.log(`  Total questions: ${snapshot.size}`);
  console.log(`  ✅ Already active: ${active.length}`);
  console.log(`  ❌ Inactive: ${inactive.length}\n`);

  if (inactive.length === 0) {
    console.log('✨ All questions are already active!\n');
    process.exit(0);
  }

  // Show breakdown by chapter
  console.log('📋 Inactive questions by chapter:\n');
  const sortedChapters = Array.from(byChapter.entries())
    .sort((a, b) => b[1].count - a[1].count);

  sortedChapters.forEach(([key, info]) => {
    console.log(`  ❌ ${key}`);
    console.log(`     ${info.subject} / ${info.chapter} (${info.count} questions)`);
  });
  console.log('');

  if (dryRun) {
    console.log('💡 Run without --dry-run to activate these questions\n');
    process.exit(0);
  }

  // Confirm activation
  console.log(`⚠️  About to activate ${inactive.length} questions across ${byChapter.size} chapters`);
  console.log('🔄 Starting activation...\n');

  // Activate questions in batches of 500 (Firestore batch limit)
  const batchSize = 500;
  let updated = 0;

  for (let i = 0; i < inactive.length; i += batchSize) {
    const batch = db.batch();
    const chunk = inactive.slice(i, i + batchSize);

    chunk.forEach(q => {
      const ref = db.collection('questions').doc(q.id);
      batch.update(ref, {
        active: true,
        updated_at: FieldValue.serverTimestamp()
      });
    });

    await batch.commit();
    updated += chunk.length;

    const progress = Math.round((updated / inactive.length) * 100);
    console.log(`  ✅ Batch ${Math.floor(i / batchSize) + 1}: Activated ${chunk.length} questions (${updated}/${inactive.length} - ${progress}%)`);
  }

  console.log(`\n✅ Successfully activated ${updated} questions!\n`);
  console.log('📊 Summary by chapter:\n');
  sortedChapters.forEach(([key, info]) => {
    console.log(`  ✅ ${key} (${info.count} questions)`);
  });
  console.log('');

  process.exit(0);
}

const dryRun = process.argv.includes('--dry-run');

activateAllInactive(dryRun).catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
