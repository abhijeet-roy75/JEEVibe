/**
 * Quality Validation Script: Chapter Schedule Validator
 *
 * Validates the countdown_24month_schedule.json against database
 * Checks for missing chapters, duplicate keys, coverage gaps
 *
 * Usage: node backend/scripts/validate-chapter-schedule.js
 */

const path = require('path');
const fs = require('fs');
const { db } = require('../src/config/firebase');
const { retryFirestoreOperation } = require('../src/utils/firestoreRetry');

// Expected JEE syllabus chapter counts (based on NCERT + JEE Main/Advanced)
const EXPECTED_CHAPTER_COUNTS = {
  physics: {
    '11th': 10,  // Units to Kinetic Theory
    '12th': 9,   // Electrostatics to Electronic Devices
    total: 19
  },
  chemistry: {
    '11th': 10,  // Basic Concepts to Hydrocarbons
    '12th': 12,  // Solutions to Biomolecules
    total: 22
  },
  mathematics: {
    '11th': 13,  // Sets to Probability
    '12th': 11,  // Inverse Trig to Probability (some overlap)
    total: 20    // Some chapters shared between 11th/12th
  }
};

async function validateSchedule() {
  console.log('🔍 QUALITY VALIDATION: Chapter Schedule\n');
  console.log('='.repeat(80));

  const errors = [];
  const warnings = [];
  const info = [];

  try {
    // Load schedule file
    const scheduleFilePath = path.join(__dirname, '../../inputs/chapter_unlock/countdown_24month_schedule_CORRECTED.json');

    if (!fs.existsSync(scheduleFilePath)) {
      console.error(`❌ CRITICAL: Schedule file not found at ${scheduleFilePath}`);
      process.exit(1);
    }

    const scheduleData = JSON.parse(fs.readFileSync(scheduleFilePath, 'utf8'));
    console.log('✅ Schedule file loaded\n');

    // Fetch all active chapters from database
    console.log('📊 Fetching database chapters...');
    const snapshot = await retryFirestoreOperation(async () => {
      return await db.collection('questions')
        .where('active', '==', true)
        .select('chapter_key', 'chapter', 'subject')
        .get();
    });

    const dbChapters = {
      physics: new Set(),
      chemistry: new Set(),
      mathematics: new Set()
    };

    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.chapter_key && data.subject) {
        const subject = data.subject.toLowerCase();
        if (dbChapters[subject]) {
          dbChapters[subject].add(data.chapter_key);
        }
      }
    });

    console.log(`✅ Database chapters loaded:`);
    console.log(`   Physics: ${dbChapters.physics.size} chapters`);
    console.log(`   Chemistry: ${dbChapters.chemistry.size} chapters`);
    console.log(`   Mathematics: ${dbChapters.mathematics.size} chapters\n`);

    // Collect all chapters from schedule
    const scheduleChapters = {
      physics: new Set(),
      chemistry: new Set(),
      mathematics: new Set()
    };

    const monthlyDistribution = [];

    for (let i = 1; i <= 24; i++) {
      const monthKey = `month_${i}`;
      const monthData = scheduleData.timeline[monthKey];

      if (!monthData) {
        errors.push(`CRITICAL: Missing ${monthKey} in timeline`);
        continue;
      }

      const monthStats = {
        month: i,
        physics: monthData.physics?.length || 0,
        chemistry: monthData.chemistry?.length || 0,
        mathematics: monthData.mathematics?.length || 0,
        total: 0
      };

      ['physics', 'chemistry', 'mathematics'].forEach(subject => {
        if (!Array.isArray(monthData[subject])) {
          errors.push(`CRITICAL: ${monthKey}.${subject} is not an array`);
          return;
        }

        monthData[subject].forEach(chapterKey => {
          scheduleChapters[subject].add(chapterKey);

          // Validate chapter exists in database
          if (!dbChapters[subject].has(chapterKey)) {
            errors.push(`CRITICAL: ${monthKey}.${subject} references unknown chapter: ${chapterKey}`);
          }
        });
      });

      monthStats.total = monthStats.physics + monthStats.chemistry + monthStats.mathematics;
      monthlyDistribution.push(monthStats);
    }

    console.log('='.repeat(80));
    console.log('📋 VALIDATION RESULTS\n');

    // 1. Check for missing chapters (chapters in DB but not in schedule)
    console.log('1️⃣ COVERAGE CHECK: Missing Chapters from Schedule\n');

    ['physics', 'chemistry', 'mathematics'].forEach(subject => {
      const missing = [];
      dbChapters[subject].forEach(chapterKey => {
        if (!scheduleChapters[subject].has(chapterKey)) {
          missing.push(chapterKey);
        }
      });

      if (missing.length > 0) {
        warnings.push(`${subject.toUpperCase()}: ${missing.length} chapters in database not in schedule`);
        console.log(`⚠️  ${subject.toUpperCase()}: ${missing.length} chapters missing from schedule:`);
        missing.forEach(ch => console.log(`    - ${ch}`));
        console.log('');
      } else {
        console.log(`✅ ${subject.toUpperCase()}: All database chapters included\n`);
      }
    });

    // 2. Check for duplicate chapters in same month
    console.log('2️⃣ DUPLICATE CHECK: Same Chapter in Same Month\n');

    for (let i = 1; i <= 24; i++) {
      const monthKey = `month_${i}`;
      const monthData = scheduleData.timeline[monthKey];

      ['physics', 'chemistry', 'mathematics'].forEach(subject => {
        const chapters = monthData[subject] || [];
        const seen = new Set();
        const duplicates = [];

        chapters.forEach(ch => {
          if (seen.has(ch)) {
            duplicates.push(ch);
          }
          seen.add(ch);
        });

        if (duplicates.length > 0) {
          errors.push(`${monthKey}.${subject} has duplicate chapters: ${duplicates.join(', ')}`);
        }
      });
    }

    if (errors.filter(e => e.includes('duplicate')).length === 0) {
      console.log('✅ No duplicate chapters within same month\n');
    }

    // 3. Coverage distribution analysis
    console.log('3️⃣ DISTRIBUTION ANALYSIS: Chapters Per Month\n');

    const contentMonths = monthlyDistribution.filter(m => m.total > 0);
    const revisionMonths = monthlyDistribution.filter(m => m.total === 0);

    console.log(`📊 Content months: ${contentMonths.length}`);
    console.log(`📊 Revision months: ${revisionMonths.length}`);
    console.log(`📊 Total unique chapters in schedule:`);
    console.log(`   Physics: ${scheduleChapters.physics.size}`);
    console.log(`   Chemistry: ${scheduleChapters.chemistry.size}`);
    console.log(`   Mathematics: ${scheduleChapters.mathematics.size}\n`);

    // Check for months with too many chapters (cognitive overload)
    const overloadedMonths = monthlyDistribution.filter(m => m.total > 6);
    if (overloadedMonths.length > 0) {
      warnings.push(`${overloadedMonths.length} months have >6 chapters (potential cognitive overload)`);
      console.log(`⚠️  Months with >6 chapters (cognitive overload risk):`);
      overloadedMonths.forEach(m => {
        console.log(`    Month ${m.month}: ${m.total} chapters (P:${m.physics} C:${m.chemistry} M:${m.mathematics})`);
      });
      console.log('');
    }

    // 4. Check for long gaps without content
    console.log('4️⃣ GAP ANALYSIS: Extended Periods Without New Chapters\n');

    ['physics', 'chemistry', 'mathematics'].forEach(subject => {
      let consecutiveEmpty = 0;
      let maxGap = 0;
      let gapLocation = 0;

      for (let i = 1; i <= 19; i++) { // Only check content months (1-19)
        const monthData = scheduleData.timeline[`month_${i}`];
        const hasContent = monthData[subject]?.length > 0;

        if (hasContent) {
          consecutiveEmpty = 0;
        } else {
          consecutiveEmpty++;
          if (consecutiveEmpty > maxGap) {
            maxGap = consecutiveEmpty;
            gapLocation = i;
          }
        }
      }

      if (maxGap > 3) {
        warnings.push(`${subject}: ${maxGap} consecutive months without content (months ${gapLocation - maxGap + 1}-${gapLocation})`);
        console.log(`⚠️  ${subject.toUpperCase()}: ${maxGap} month gap at months ${gapLocation - maxGap + 1}-${gapLocation}`);
      }
    });

    console.log('');

    // 5. Check expected chapter counts
    console.log('5️⃣ SYLLABUS COMPLETENESS: Expected vs Actual\n');

    Object.keys(EXPECTED_CHAPTER_COUNTS).forEach(subject => {
      const actual = scheduleChapters[subject].size;
      const expected = EXPECTED_CHAPTER_COUNTS[subject].total;
      const diff = expected - actual;

      if (diff > 0) {
        warnings.push(`${subject}: Expected ${expected} chapters, found ${actual} (${diff} missing)`);
        console.log(`⚠️  ${subject.toUpperCase()}: ${actual}/${expected} chapters (${diff} missing)`);
      } else if (diff < 0) {
        info.push(`${subject}: Found ${actual} chapters (${-diff} more than expected ${expected})`);
        console.log(`ℹ️  ${subject.toUpperCase()}: ${actual}/${expected} chapters (${-diff} extra)`);
      } else {
        console.log(`✅ ${subject.toUpperCase()}: ${actual}/${expected} chapters (complete)`);
      }
    });

    console.log('');

    // 6. Timeline validation
    console.log('6️⃣ TIMELINE VALIDATION: Month Key Structure\n');

    for (let i = 1; i <= 24; i++) {
      const monthKey = `month_${i}`;
      if (!scheduleData.timeline[monthKey]) {
        errors.push(`CRITICAL: Missing ${monthKey} in timeline`);
      }
    }

    if (errors.filter(e => e.includes('Missing month')).length === 0) {
      console.log('✅ All 24 months present in timeline\n');
    }

    // 7. Check for orphaned keys
    console.log('7️⃣ ORPHANED KEYS CHECK: Extra Keys in Timeline\n');

    const validMonthKeys = Array.from({length: 24}, (_, i) => `month_${i + 1}`);
    const actualKeys = Object.keys(scheduleData.timeline);
    const orphanedKeys = actualKeys.filter(k => !validMonthKeys.includes(k));

    if (orphanedKeys.length > 0) {
      warnings.push(`Found ${orphanedKeys.length} orphaned keys: ${orphanedKeys.join(', ')}`);
      console.log(`⚠️  Orphaned keys found: ${orphanedKeys.join(', ')}\n`);
    } else {
      console.log('✅ No orphaned keys in timeline\n');
    }

    // 8. Print monthly distribution
    console.log('8️⃣ MONTHLY DISTRIBUTION TABLE\n');
    console.log('Month | Physics | Chemistry | Math | Total | Status');
    console.log('------|---------|-----------|------|-------|-------');

    monthlyDistribution.forEach(m => {
      const status = m.total === 0 ? 'Revision' : 'Content';
      const indicator = m.total > 6 ? '⚠️ ' : m.total === 0 ? '📚' : '✓';
      console.log(
        `${m.month.toString().padStart(5)} | ${m.physics.toString().padStart(7)} | ` +
        `${m.chemistry.toString().padStart(9)} | ${m.mathematics.toString().padStart(4)} | ` +
        `${m.total.toString().padStart(5)} | ${indicator} ${status}`
      );
    });

    console.log('');

    // Final summary
    console.log('='.repeat(80));
    console.log('📊 FINAL SUMMARY\n');

    console.log(`❌ ERRORS: ${errors.length}`);
    if (errors.length > 0) {
      errors.forEach(e => console.log(`   - ${e}`));
      console.log('');
    }

    console.log(`⚠️  WARNINGS: ${warnings.length}`);
    if (warnings.length > 0) {
      warnings.forEach(w => console.log(`   - ${w}`));
      console.log('');
    }

    console.log(`ℹ️  INFO: ${info.length}`);
    if (info.length > 0) {
      info.forEach(i => console.log(`   - ${i}`));
      console.log('');
    }

    console.log('='.repeat(80));

    if (errors.length === 0 && warnings.length === 0) {
      console.log('✅ VALIDATION PASSED: Schedule is production-ready!\n');
      process.exit(0);
    } else if (errors.length === 0) {
      console.log('⚠️  VALIDATION PASSED WITH WARNINGS: Review warnings before production\n');
      process.exit(0);
    } else {
      console.log('❌ VALIDATION FAILED: Fix critical errors before proceeding\n');
      process.exit(1);
    }

  } catch (error) {
    console.error('\n❌ FATAL ERROR:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run
if (require.main === module) {
  validateSchedule()
    .catch((error) => {
      console.error('💥 Validation script failed:', error);
      process.exit(1);
    });
}

module.exports = { validateSchedule };
