/**
 * Fix MCQ Question Type
 *
 * Updates all questions with question_type "mcq" to "mcq_single"
 * Ignores other invalid types (mcq_multiple, assertion_reason)
 *
 * Usage:
 *   node scripts/fix-mcq-question-type.js --preview
 *   node scripts/fix-mcq-question-type.js
 */

const { db } = require('../src/config/firebase');

async function fixMcqQuestionType(preview = false) {
  try {
    console.log('🔧 Fix MCQ Question Type\n');
    console.log('='.repeat(80));
    console.log(`Mode: ${preview ? 'PREVIEW (no changes)' : 'UPDATE DATABASE'}`);
    console.log('='.repeat(80));

    // Get all questions with question_type = "mcq"
    const snapshot = await db.collection('questions')
      .where('question_type', '==', 'mcq')
      .get();

    console.log(`\n📊 Found ${snapshot.size} question(s) with question_type: "mcq"\n`);

    if (snapshot.size === 0) {
      console.log('✅ No questions to fix!\n');
      return;
    }

    // List all questions to be updated
    console.log('Questions to be updated:');
    console.log('-'.repeat(80));

    const questionsToUpdate = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      const subject = data.subject || 'Unknown';
      const chapter = data.chapter || 'Unknown';

      console.log(`   ${doc.id.padEnd(25)} [${subject}/${chapter}]`);
      questionsToUpdate.push({
        id: doc.id,
        ref: doc.ref,
        subject,
        chapter
      });
    });

    if (preview) {
      console.log('\n' + '='.repeat(80));
      console.log('👀 PREVIEW MODE - No changes made');
      console.log('='.repeat(80));
      console.log(`\n💡 Run without --preview to update ${snapshot.size} question(s)\n`);
      return;
    }

    // Update questions
    console.log('\n' + '='.repeat(80));
    console.log('🔄 Updating questions...');
    console.log('='.repeat(80) + '\n');

    const batch = db.batch();
    let batchCount = 0;
    const BATCH_SIZE = 500;

    for (const q of questionsToUpdate) {
      batch.update(q.ref, { question_type: 'mcq_single' });
      batchCount++;

      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        console.log(`   ✓ Updated ${batchCount} questions...`);
        batchCount = 0;
      }
    }

    // Commit remaining
    if (batchCount > 0) {
      await batch.commit();
      console.log(`   ✓ Updated ${batchCount} questions...`);
    }

    console.log('\n' + '='.repeat(80));
    console.log(`✅ Successfully updated ${questionsToUpdate.length} question(s)!`);
    console.log('='.repeat(80));
    console.log('\n💡 Run validate-question-data.js to verify the fixes\n');

  } catch (error) {
    console.error('\n❌ Error:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

async function main() {
  const args = process.argv.slice(2);
  const preview = args.includes('--preview');

  await fixMcqQuestionType(preview);
}

// Run
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('💥 Script failed:', error);
      process.exit(1);
    });
}

module.exports = { fixMcqQuestionType };
