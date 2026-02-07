/**
 * List All Chapter Keys from Firestore
 *
 * Fetches all unique chapter_key values from the questions collection
 * and organizes them by subject.
 *
 * Usage:
 *   node backend/scripts/list-all-chapter-keys.js
 */

const { db } = require('../src/config/firebase');
const { retryFirestoreOperation } = require('../src/utils/firestoreRetry');

async function listAllChapterKeys() {
  try {
    console.log('🔍 Fetching all chapter keys from Firestore...\n');
    console.log('='.repeat(80));

    // Fetch all active questions
    const snapshot = await retryFirestoreOperation(async () => {
      return await db.collection('questions')
        .where('active', '==', true)
        .select('chapter_key', 'chapter', 'subject')
        .get();
    });

    console.log(`✅ Found ${snapshot.size} active questions\n`);

    // Collect unique chapter keys organized by subject
    const chaptersBySubject = {
      'Physics': new Map(),
      'Chemistry': new Map(),
      'Mathematics': new Map()
    };

    snapshot.forEach(doc => {
      const data = doc.data();
      const chapterKey = data.chapter_key;
      const chapterName = data.chapter;
      const subject = data.subject;

      if (chapterKey && subject && chaptersBySubject[subject]) {
        if (!chaptersBySubject[subject].has(chapterKey)) {
          chaptersBySubject[subject].set(chapterKey, chapterName || 'Unknown');
        }
      }
    });

    // Print organized results
    console.log('📚 ALL CHAPTER KEYS BY SUBJECT');
    console.log('='.repeat(80));
    console.log('\nCopy these exact strings to your JSON file:\n');

    for (const [subject, chaptersMap] of Object.entries(chaptersBySubject)) {
      const chapters = Array.from(chaptersMap.entries()).sort((a, b) => a[0].localeCompare(b[0]));

      if (chapters.length === 0) continue;

      console.log(`\n${'─'.repeat(80)}`);
      console.log(`${subject.toUpperCase()} (${chapters.length} chapters)`);
      console.log('─'.repeat(80));

      chapters.forEach(([key, name], index) => {
        console.log(`${(index + 1).toString().padStart(2)}. "${key}"`);
        console.log(`    Chapter Name: ${name}`);
      });
    }

    // Print summary counts
    console.log('\n' + '='.repeat(80));
    console.log('📊 SUMMARY');
    console.log('='.repeat(80));
    console.log(`Physics chapters:     ${chaptersBySubject['Physics'].size}`);
    console.log(`Chemistry chapters:   ${chaptersBySubject['Chemistry'].size}`);
    console.log(`Mathematics chapters: ${chaptersBySubject['Mathematics'].size}`);
    console.log(`Total chapters:       ${
      chaptersBySubject['Physics'].size +
      chaptersBySubject['Chemistry'].size +
      chaptersBySubject['Mathematics'].size
    }`);
    console.log('='.repeat(80));

    // Print JSON format example
    console.log('\n\n📝 JSON FORMAT EXAMPLE:');
    console.log('─'.repeat(80));
    console.log('Use this format in your countdown_24month_schedule.json:\n');
    console.log(JSON.stringify({
      "month_1": {
        "physics": [
          Array.from(chaptersBySubject['Physics'].keys()).slice(0, 2)
        ].flat(),
        "chemistry": [
          Array.from(chaptersBySubject['Chemistry'].keys()).slice(0, 2)
        ].flat(),
        "mathematics": [
          Array.from(chaptersBySubject['Mathematics'].keys()).slice(0, 1)
        ].flat()
      }
    }, null, 2));

    console.log('\n✅ Complete!\n');

  } catch (error) {
    console.error('\n❌ Error:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run
if (require.main === module) {
  listAllChapterKeys()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('💥 Script failed:', error);
      process.exit(1);
    });
}

module.exports = { listAllChapterKeys };
