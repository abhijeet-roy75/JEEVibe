#!/usr/bin/env node
/**
 * Activate Questions for a Chapter
 *
 * Sets active: true for all questions in a specific chapter
 *
 * Usage:
 *   node scripts/activate-chapter-questions.js physics_current_electricity
 *   node scripts/activate-chapter-questions.js physics_current_electricity --dry-run
 */

require('dotenv').config();
const { db, FieldValue } = require('../src/config/firebase');

async function activateChapter(chapterKey, dryRun = false) {
  console.log(`\n🔧 Activating questions for: ${chapterKey}`);
  if (dryRun) {
    console.log('🧪 DRY RUN MODE - No changes will be made\n');
  } else {
    console.log('⚠️  LIVE MODE - Questions will be activated\n');
  }

  // Parse chapter key
  const parts = chapterKey.split('_');
  const subject = parts[0].charAt(0).toUpperCase() + parts[0].slice(1);
  const chapter = parts.slice(1).map(p => p.charAt(0).toUpperCase() + p.slice(1)).join(' ');

  console.log(`Looking for:`);
  console.log(`  Subject: ${subject}`);
  console.log(`  Chapter: ${chapter}\n`);

  // Find all questions for this chapter (active and inactive)
  const snapshot = await db.collection('questions')
    .where('chapter_key', '==', chapterKey)
    .get();

  if (snapshot.empty) {
    console.log('❌ No questions found with chapter_key:', chapterKey);
    console.log('\nTrying fallback query with subject/chapter...\n');

    // Fallback: query by subject and chapter
    const fallbackSnapshot = await db.collection('questions')
      .where('subject', '==', subject)
      .where('chapter', '==', chapter)
      .get();

    if (fallbackSnapshot.empty) {
      console.log('❌ No questions found with subject/chapter:', subject, '/', chapter);
      process.exit(1);
    }

    console.log(`✅ Found ${fallbackSnapshot.size} questions via fallback query\n`);
    await processQuestions(fallbackSnapshot, dryRun, chapterKey);
  } else {
    console.log(`✅ Found ${snapshot.size} questions\n`);
    await processQuestions(snapshot, dryRun, chapterKey);
  }
}

async function processQuestions(snapshot, dryRun, chapterKey) {
  const inactive = [];
  const active = [];

  snapshot.forEach(doc => {
    const data = doc.data();
    if (data.active === false || data.active === undefined) {
      inactive.push({ id: doc.id, data });
    } else {
      active.push({ id: doc.id, data });
    }
  });

  console.log(`Status breakdown:`);
  console.log(`  ✅ Already active: ${active.length}`);
  console.log(`  ❌ Inactive: ${inactive.length}\n`);

  if (inactive.length === 0) {
    console.log('✨ All questions are already active!\n');
    process.exit(0);
  }

  if (dryRun) {
    console.log('📋 Questions that WOULD be activated:');
    inactive.slice(0, 5).forEach(q => {
      console.log(`  - ${q.id}: ${q.data.question_text?.substring(0, 60)}...`);
    });
    if (inactive.length > 5) {
      console.log(`  ... and ${inactive.length - 5} more`);
    }
    console.log('\n💡 Run without --dry-run to activate these questions\n');
    process.exit(0);
  }

  // Activate questions in batches
  console.log(`🔄 Activating ${inactive.length} questions...\n`);

  const batchSize = 500;
  let updated = 0;

  for (let i = 0; i < inactive.length; i += batchSize) {
    const batch = db.batch();
    const chunk = inactive.slice(i, i + batchSize);

    chunk.forEach(q => {
      const ref = db.collection('questions').doc(q.id);
      batch.update(ref, {
        active: true,
        chapter_key: chapterKey, // Ensure chapter_key is set
        updated_at: FieldValue.serverTimestamp()
      });
    });

    await batch.commit();
    updated += chunk.length;
    console.log(`  ✅ Batch ${Math.floor(i / batchSize) + 1}: Activated ${chunk.length} questions (total: ${updated}/${inactive.length})`);
  }

  console.log(`\n✅ Successfully activated ${updated} questions for ${chapterKey}\n`);
  process.exit(0);
}

const args = process.argv.slice(2);
const chapterKey = args.find(arg => !arg.startsWith('--'));
const dryRun = args.includes('--dry-run');

if (!chapterKey) {
  console.error('❌ Error: Please provide a chapter key');
  console.log('\nUsage:');
  console.log('  node scripts/activate-chapter-questions.js physics_current_electricity');
  console.log('  node scripts/activate-chapter-questions.js physics_current_electricity --dry-run');
  process.exit(1);
}

activateChapter(chapterKey, dryRun).catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
