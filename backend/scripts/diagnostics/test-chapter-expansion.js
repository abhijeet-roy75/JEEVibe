#!/usr/bin/env node
/**
 * Test script to verify chapter expansion logic
 * Simulates assessment processing with broad chapters
 */

require('dotenv').config();

const {
  expandBroadChaptersToSpecific,
  isBroadChapter,
  getSpecificChapters,
  BROAD_TO_SPECIFIC_CHAPTER_MAP
} = require('../src/services/thetaCalculationService');

console.log('=' .repeat(70));
console.log('📊 Testing Broad-to-Specific Chapter Expansion');
console.log('=' .repeat(70));
console.log();

// Simulate theta estimates from initial assessment (with broad chapters)
const mockThetaEstimates = {
  // Physics - 3 specific, 3 broad
  "physics_current_electricity": {
    theta: 0.5,
    percentile: 69.15,
    confidence_SE: 0.35,
    attempts: 1,
    accuracy: 1.0
  },
  "physics_electrostatics": {
    theta: -0.5,
    percentile: 30.85,
    confidence_SE: 0.35,
    attempts: 2,
    accuracy: 0.5
  },
  "physics_electromagnetic_induction": {
    theta: 0.5,
    percentile: 69.15,
    confidence_SE: 0.35,
    attempts: 1,
    accuracy: 1.0
  },
  "physics_magnetism": {  // BROAD - should expand
    theta: 0.5,
    percentile: 69.15,
    confidence_SE: 0.35,
    attempts: 1,
    accuracy: 1.0
  },
  "physics_mechanics": {  // BROAD - should expand to 6 specific chapters
    theta: -0.5,
    percentile: 30.85,
    confidence_SE: 0.3,
    attempts: 4,
    accuracy: 0.5
  },
  "physics_modern_physics": {  // BROAD - should expand to 3 specific chapters
    theta: 1.5,
    percentile: 93.32,
    confidence_SE: 0.35,
    attempts: 1,
    accuracy: 1.0
  },

  // Chemistry - 3 broad
  "chemistry_inorganic_chemistry": {
    theta: -0.5,
    percentile: 30.85,
    confidence_SE: 0.32,
    attempts: 3,
    accuracy: 0.33
  },
  "chemistry_organic_chemistry": {
    theta: 0.5,
    percentile: 69.15,
    confidence_SE: 0.32,
    attempts: 3,
    accuracy: 0.67
  },
  "chemistry_physical_chemistry": {
    theta: -1.5,
    percentile: 6.68,
    confidence_SE: 0.3,
    attempts: 4,
    accuracy: 0.25
  },

  // Mathematics - 3 broad
  "mathematics_algebra": {
    theta: 0.5,
    percentile: 69.15,
    confidence_SE: 0.3,
    attempts: 4,
    accuracy: 0.75
  },
  "mathematics_calculus": {
    theta: -0.5,
    percentile: 30.85,
    confidence_SE: 0.3,
    attempts: 4,
    accuracy: 0.5
  },
  "mathematics_coordinate_geometry": {
    theta: 1.5,
    percentile: 93.32,
    confidence_SE: 0.35,
    attempts: 2,
    accuracy: 1.0
  }
};

console.log('📋 Input: Mock assessment theta estimates\n');
console.log('   Original Chapters:');
for (const [key, data] of Object.entries(mockThetaEstimates)) {
  const isBroad = isBroadChapter(key);
  const marker = isBroad ? '🔶 BROAD' : '  specific';
  console.log(`   ${marker} ${key}: θ=${data.theta.toFixed(1)}`);
}

console.log('\n' + '='.repeat(70));
console.log('📊 Expansion Results\n');

// Test the expansion function
const expanded = expandBroadChaptersToSpecific(mockThetaEstimates);

// Count statistics
const originalCount = Object.keys(mockThetaEstimates).length;
const expandedCount = Object.keys(expanded).length;
const broadCount = Object.keys(mockThetaEstimates).filter(k => isBroadChapter(k)).length;
const specificDerivedCount = Object.values(expanded).filter(d => d.is_derived).length;

console.log(`   Original chapters: ${originalCount}`);
console.log(`   Broad chapters: ${broadCount}`);
console.log(`   After expansion: ${expandedCount} chapters`);
console.log(`   - Original specific: ${originalCount - broadCount}`);
console.log(`   - Derived from broad: ${specificDerivedCount}`);
console.log(`   - Broad chapters kept: ${broadCount}`);
console.log();

// Show expanded chapters by subject
console.log('📋 Expanded Chapters by Subject:\n');

for (const subject of ['physics', 'chemistry', 'mathematics']) {
  const subjectChapters = Object.entries(expanded)
    .filter(([k, _]) => k.startsWith(`${subject}_`))
    .sort((a, b) => a[0].localeCompare(b[0]));

  console.log(`   ${subject.toUpperCase()} (${subjectChapters.length} chapters):`);

  for (const [key, data] of subjectChapters) {
    let status = '';
    if (data.is_broad_category) {
      status = '🔶 BROAD';
    } else if (data.is_derived) {
      status = `   ↳ from ${data.source_chapter.split('_').slice(1).join('_')}`;
    } else {
      status = '✅ original';
    }
    console.log(`     ${key.padEnd(45)} θ=${data.theta.toFixed(1).padStart(5)} ${status}`);
  }
  console.log();
}

// Verify daily quiz can find questions
console.log('='.repeat(70));
console.log('📊 Daily Quiz Chapter Coverage Check\n');

const { db } = require('../src/config/firebase');

async function verifyDailyQuizCoverage() {
  try {
    const questionsSnapshot = await db.collection('questions').get();

    const dailyQuizChapters = new Set();
    questionsSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.chapter_key) {
        dailyQuizChapters.add(data.chapter_key);
      }
    });

    console.log(`   Daily quiz has ${dailyQuizChapters.size} unique chapter_keys\n`);

    // Check coverage
    let covered = 0;
    let missing = 0;
    const missingChapters = [];

    for (const chapterKey of Object.keys(expanded)) {
      // Skip broad categories (they're for reference only)
      if (expanded[chapterKey].is_broad_category) continue;

      if (dailyQuizChapters.has(chapterKey)) {
        covered++;
      } else {
        missing++;
        missingChapters.push(chapterKey);
      }
    }

    console.log(`   ✅ Covered in daily quiz: ${covered} chapters`);
    console.log(`   ❌ Missing from daily quiz: ${missing} chapters`);

    if (missingChapters.length > 0) {
      console.log('\n   Missing chapters:');
      for (const ch of missingChapters) {
        console.log(`     - ${ch}`);
      }
    }

    console.log('\n' + '='.repeat(70));
    console.log('✅ Test Complete');
    console.log('='.repeat(70));

  } catch (error) {
    console.error('Error:', error.message);
  }
}

verifyDailyQuizCoverage().then(() => process.exit(0));
