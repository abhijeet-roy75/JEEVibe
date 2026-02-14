/**
 * Analyze Question Difficulty Distribution
 *
 * Provides detailed statistics on questions broken down by:
 * - Subject → Chapter → Difficulty (easy/medium/hard)
 * - Shows counts and percentages
 * - Identifies chapters with insufficient questions at each difficulty level
 *
 * Usage:
 *   node scripts/analyze-question-difficulty.js
 *   node scripts/analyze-question-difficulty.js --detailed
 *   node scripts/analyze-question-difficulty.js --csv
 *   node scripts/analyze-question-difficulty.js --gaps-only
 */

const { db } = require('../src/config/firebase');
const fs = require('fs');
const path = require('path');

// Minimum recommended questions per difficulty level per chapter
const MINIMUM_PER_DIFFICULTY = 5;

async function main() {
  try {
    console.log('📊 Question Difficulty Distribution Analysis\n');
    console.log('='.repeat(80));

    // Parse arguments
    const args = process.argv.slice(2);
    const detailed = args.includes('--detailed');
    const csvOutput = args.includes('--csv');
    const gapsOnly = args.includes('--gaps-only');

    // Get all questions
    const snapshot = await db.collection('questions').where('active', '==', true).get();
    const totalCount = snapshot.size;

    console.log(`\n✅ Total Active Questions: ${totalCount}\n`);
    console.log('='.repeat(80));

    // Data structures
    const data = {
      bySubject: {},
      byChapter: {},
      byDifficulty: { easy: 0, medium: 0, hard: 0, unknown: 0 }
    };

    const csvData = [];

    // Process each question
    snapshot.forEach(doc => {
      const q = doc.data();
      const subject = q.subject || 'Unknown';
      const chapter = q.chapter || 'Unknown';
      const difficulty = (q.difficulty || 'unknown').toLowerCase();

      // Initialize structures
      if (!data.bySubject[subject]) {
        data.bySubject[subject] = {
          total: 0,
          byDifficulty: { easy: 0, medium: 0, hard: 0, unknown: 0 },
          chapters: {}
        };
      }

      const chapterKey = `${subject} → ${chapter}`;
      if (!data.byChapter[chapterKey]) {
        data.byChapter[chapterKey] = {
          subject,
          chapter,
          total: 0,
          easy: 0,
          medium: 0,
          hard: 0,
          unknown: 0
        };
      }

      // Count
      data.bySubject[subject].total++;
      data.byChapter[chapterKey].total++;

      if (difficulty === 'easy' || difficulty === 'medium' || difficulty === 'hard') {
        data.bySubject[subject].byDifficulty[difficulty]++;
        data.byChapter[chapterKey][difficulty]++;
        data.byDifficulty[difficulty]++;
      } else {
        data.bySubject[subject].byDifficulty.unknown++;
        data.byChapter[chapterKey].unknown++;
        data.byDifficulty.unknown++;
      }

      // Track chapter in subject
      if (!data.bySubject[subject].chapters[chapter]) {
        data.bySubject[subject].chapters[chapter] = {
          easy: 0,
          medium: 0,
          hard: 0,
          unknown: 0,
          total: 0
        };
      }
      data.bySubject[subject].chapters[chapter].total++;
      if (difficulty === 'easy' || difficulty === 'medium' || difficulty === 'hard') {
        data.bySubject[subject].chapters[chapter][difficulty]++;
      } else {
        data.bySubject[subject].chapters[chapter].unknown++;
      }
    });

    // Overall difficulty distribution
    if (!gapsOnly) {
      console.log('\n📈 Overall Difficulty Distribution:');
      console.log('-'.repeat(80));
      const total = totalCount;
      console.log(`   Easy:    ${data.byDifficulty.easy.toString().padStart(5)} (${((data.byDifficulty.easy / total) * 100).toFixed(1)}%)`);
      console.log(`   Medium:  ${data.byDifficulty.medium.toString().padStart(5)} (${((data.byDifficulty.medium / total) * 100).toFixed(1)}%)`);
      console.log(`   Hard:    ${data.byDifficulty.hard.toString().padStart(5)} (${((data.byDifficulty.hard / total) * 100).toFixed(1)}%)`);
      if (data.byDifficulty.unknown > 0) {
        console.log(`   Unknown: ${data.byDifficulty.unknown.toString().padStart(5)} (${((data.byDifficulty.unknown / total) * 100).toFixed(1)}%)`);
      }
    }

    // By Subject breakdown
    if (!gapsOnly) {
      console.log('\n📚 By Subject:');
      console.log('='.repeat(80));

      const subjects = ['Physics', 'Chemistry', 'Mathematics'].filter(s => data.bySubject[s]);

      for (const subject of subjects) {
        const subjectData = data.bySubject[subject];
        console.log(`\n${subject} (${subjectData.total} questions):`);
        console.log('-'.repeat(80));
        console.log(`   Easy:    ${subjectData.byDifficulty.easy.toString().padStart(5)} (${((subjectData.byDifficulty.easy / subjectData.total) * 100).toFixed(1)}%)`);
        console.log(`   Medium:  ${subjectData.byDifficulty.medium.toString().padStart(5)} (${((subjectData.byDifficulty.medium / subjectData.total) * 100).toFixed(1)}%)`);
        console.log(`   Hard:    ${subjectData.byDifficulty.hard.toString().padStart(5)} (${((subjectData.byDifficulty.hard / subjectData.total) * 100).toFixed(1)}%)`);
        if (subjectData.byDifficulty.unknown > 0) {
          console.log(`   Unknown: ${subjectData.byDifficulty.unknown.toString().padStart(5)} (${((subjectData.byDifficulty.unknown / subjectData.total) * 100).toFixed(1)}%)`);
        }

        // Chapter breakdown
        if (detailed) {
          console.log('\n   Chapters:');
          const chapters = Object.entries(subjectData.chapters).sort((a, b) => b[1].total - a[1].total);
          for (const [chapter, chapterData] of chapters) {
            console.log(`      ${chapter.padEnd(40)} E:${chapterData.easy.toString().padStart(3)} M:${chapterData.medium.toString().padStart(3)} H:${chapterData.hard.toString().padStart(3)} Total:${chapterData.total.toString().padStart(4)}`);
          }
        }
      }
    }

    // Detailed chapter breakdown
    if (detailed && !gapsOnly) {
      console.log('\n\n📖 Detailed Chapter Breakdown:');
      console.log('='.repeat(80));

      const subjects = ['Physics', 'Chemistry', 'Mathematics'];

      for (const subject of subjects) {
        if (!data.bySubject[subject]) continue;

        console.log(`\n${subject}:`);
        console.log('-'.repeat(80));
        console.log('   Chapter'.padEnd(45) + 'Easy  Med  Hard  Total');
        console.log('-'.repeat(80));

        const chapters = Object.entries(data.bySubject[subject].chapters)
          .sort((a, b) => b[1].total - a[1].total);

        for (const [chapter, chapterData] of chapters) {
          const easyStr = chapterData.easy.toString().padStart(4);
          const mediumStr = chapterData.medium.toString().padStart(4);
          const hardStr = chapterData.hard.toString().padStart(4);
          const totalStr = chapterData.total.toString().padStart(5);

          console.log(`   ${chapter.padEnd(42)} ${easyStr}  ${mediumStr}  ${hardStr}  ${totalStr}`);
        }
      }
    }

    // Identify gaps
    console.log('\n\n🔍 Gap Analysis (chapters with < ' + MINIMUM_PER_DIFFICULTY + ' questions per difficulty):');
    console.log('='.repeat(80));

    const gaps = [];
    for (const [chapterKey, chapterData] of Object.entries(data.byChapter)) {
      const issues = [];

      if (chapterData.easy < MINIMUM_PER_DIFFICULTY) {
        issues.push(`Easy: ${chapterData.easy}/${MINIMUM_PER_DIFFICULTY}`);
      }
      if (chapterData.medium < MINIMUM_PER_DIFFICULTY) {
        issues.push(`Medium: ${chapterData.medium}/${MINIMUM_PER_DIFFICULTY}`);
      }
      if (chapterData.hard < MINIMUM_PER_DIFFICULTY) {
        issues.push(`Hard: ${chapterData.hard}/${MINIMUM_PER_DIFFICULTY}`);
      }

      if (issues.length > 0) {
        gaps.push({
          key: chapterKey,
          subject: chapterData.subject,
          chapter: chapterData.chapter,
          issues: issues,
          easy: chapterData.easy,
          medium: chapterData.medium,
          hard: chapterData.hard,
          total: chapterData.total
        });
      }
    }

    if (gaps.length === 0) {
      console.log('\n✅ All chapters have sufficient questions at each difficulty level!');
    } else {
      console.log(`\n⚠️  Found ${gaps.length} chapter(s) with gaps:\n`);

      // Group by subject
      const gapsBySubject = {};
      for (const gap of gaps) {
        if (!gapsBySubject[gap.subject]) {
          gapsBySubject[gap.subject] = [];
        }
        gapsBySubject[gap.subject].push(gap);
      }

      for (const subject of ['Physics', 'Chemistry', 'Mathematics']) {
        if (!gapsBySubject[subject]) continue;

        console.log(`${subject}:`);
        console.log('-'.repeat(80));

        for (const gap of gapsBySubject[subject]) {
          console.log(`   ${gap.chapter.padEnd(40)} [${gap.issues.join(', ')}]`);
        }
        console.log('');
      }
    }

    // CSV export
    if (csvOutput) {
      console.log('\n📄 Generating CSV export...');

      const csvRows = [
        ['Subject', 'Chapter', 'Easy', 'Medium', 'Hard', 'Unknown', 'Total', 'Has Gaps']
      ];

      const sortedChapters = Object.entries(data.byChapter)
        .sort((a, b) => {
          if (a[1].subject !== b[1].subject) {
            return a[1].subject.localeCompare(b[1].subject);
          }
          return a[1].chapter.localeCompare(b[1].chapter);
        });

      for (const [_, chapterData] of sortedChapters) {
        const hasGaps =
          chapterData.easy < MINIMUM_PER_DIFFICULTY ||
          chapterData.medium < MINIMUM_PER_DIFFICULTY ||
          chapterData.hard < MINIMUM_PER_DIFFICULTY ? 'Yes' : 'No';

        csvRows.push([
          chapterData.subject,
          chapterData.chapter,
          chapterData.easy,
          chapterData.medium,
          chapterData.hard,
          chapterData.unknown,
          chapterData.total,
          hasGaps
        ]);
      }

      const csvContent = csvRows.map(row => row.join(',')).join('\n');
      const csvPath = path.join(process.cwd(), 'question-difficulty-report.csv');
      fs.writeFileSync(csvPath, csvContent);
      console.log(`   ✅ CSV saved to: ${csvPath}`);
    }

    console.log('\n' + '='.repeat(80));
    console.log('✅ Analysis complete!\n');

    if (!detailed && !gapsOnly) {
      console.log('💡 Tip: Use --detailed for chapter-level breakdown');
    }
    if (!csvOutput) {
      console.log('💡 Tip: Use --csv to export to CSV file');
    }
    if (!gapsOnly) {
      console.log('💡 Tip: Use --gaps-only to see only chapters with missing questions\n');
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
