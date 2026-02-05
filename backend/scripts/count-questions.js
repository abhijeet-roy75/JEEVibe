/**
 * Count Questions in Database
 *
 * Provides statistics on questions in Firebase:
 * - Total count
 * - Count by subject
 * - Count by chapter (optional)
 *
 * Usage:
 *   node scripts/count-questions.js
 *   node scripts/count-questions.js --by-chapter
 */

const { db } = require('../src/config/firebase');

async function main() {
  try {
    console.log('📊 Question Database Statistics\n');
    console.log('='.repeat(60));

    // Get all questions
    const snapshot = await db.collection('questions').get();
    const totalCount = snapshot.size;

    console.log(`\n✅ Total Questions: ${totalCount}\n`);
    console.log('='.repeat(60));

    // Count by subject
    const bySubject = {
      Physics: 0,
      Chemistry: 0,
      Mathematics: 0,
      Other: 0
    };

    // Count by chapter (optional)
    const byChapter = {};
    const showByChapter = process.argv.includes('--by-chapter');

    snapshot.forEach(doc => {
      const data = doc.data();
      const subject = data.subject || 'Other';

      // Count by subject
      if (bySubject.hasOwnProperty(subject)) {
        bySubject[subject]++;
      } else {
        bySubject.Other++;
      }

      // Count by chapter
      if (showByChapter) {
        const chapter = data.chapter || 'Unknown';
        const key = `${subject} - ${chapter}`;
        byChapter[key] = (byChapter[key] || 0) + 1;
      }
    });

    // Display by subject
    console.log('\n📚 By Subject:');
    console.log('-'.repeat(60));
    Object.entries(bySubject).forEach(([subject, count]) => {
      if (count > 0) {
        const percentage = ((count / totalCount) * 100).toFixed(1);
        console.log(`   ${subject.padEnd(15)} ${count.toString().padStart(5)} (${percentage}%)`);
      }
    });

    // Display by chapter (if requested)
    if (showByChapter) {
      console.log('\n📖 By Chapter:');
      console.log('-'.repeat(60));

      // Group by subject first
      const chaptersBySubject = {};
      Object.entries(byChapter).forEach(([key, count]) => {
        const [subject] = key.split(' - ');
        if (!chaptersBySubject[subject]) {
          chaptersBySubject[subject] = [];
        }
        chaptersBySubject[subject].push({ key, count });
      });

      // Display grouped
      Object.entries(chaptersBySubject).forEach(([subject, chapters]) => {
        console.log(`\n   ${subject}:`);
        chapters
          .sort((a, b) => b.count - a.count) // Sort by count descending
          .forEach(({ key, count }) => {
            const chapter = key.split(' - ')[1];
            console.log(`      ${chapter.padEnd(35)} ${count.toString().padStart(4)}`);
          });
      });
    }

    console.log('\n' + '='.repeat(60));
    console.log('✅ Statistics complete!\n');

    if (!showByChapter) {
      console.log('💡 Tip: Use --by-chapter to see chapter-level breakdown\n');
    }

  } catch (error) {
    console.error('\n❌ Error:', error);
    console.error(error.stack);
    process.exit(1);
  }
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

module.exports = { main };
