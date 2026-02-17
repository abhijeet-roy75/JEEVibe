/**
 * Verify Chapter Weights Fix
 *
 * This script verifies that all newly added chapter keys are properly recognized
 * and have the correct weights assigned.
 */

const {
  JEE_CHAPTER_WEIGHTS,
  formatChapterKey,
  calculateWeightedOverallTheta
} = require('../src/services/thetaCalculationService');

// Test cases: chapters that were causing warnings in the logs
const TEST_CASES = [
  { subject: 'Chemistry', chapter: 'Basic Concepts', expectedKey: 'chemistry_basic_concepts', expectedWeight: 0.8 },
  { subject: 'Chemistry', chapter: 'Classification and Periodicity', expectedKey: 'chemistry_classification_and_periodicity', expectedWeight: 0.6 },
  { subject: 'Chemistry', chapter: 'Principles of Practical Chemistry', expectedKey: 'chemistry_principles_of_practical_chemistry', expectedWeight: 0.4 },
  { subject: 'Mathematics', chapter: 'Three-Dimensional Geometry', expectedKey: 'mathematics_threedimensional_geometry', expectedWeight: 0.8 },
  { subject: 'Mathematics', chapter: 'Inverse Trigonometry', expectedKey: 'mathematics_inverse_trigonometry', expectedWeight: 0.6 },
  { subject: 'Mathematics', chapter: 'Conic Sections (Parabola)', expectedKey: 'mathematics_conic_sections_parabola', expectedWeight: 1.0 },
  { subject: 'Mathematics', chapter: 'Parabola', expectedKey: 'mathematics_parabola', expectedWeight: 1.0 },
  { subject: 'Physics', chapter: 'Transformers', expectedKey: 'physics_transformers', expectedWeight: 0.4 },
  { subject: 'Physics', chapter: 'Eddy Currents', expectedKey: 'physics_eddy_currents', expectedWeight: 0.4 },
  { subject: 'Physics', chapter: 'Experimental Skills', expectedKey: 'physics_experimental_skills', expectedWeight: 0.4 },
  { subject: 'Physics', chapter: 'Kinetic Theory of Gases', expectedKey: 'physics_kinetic_theory_of_gases', expectedWeight: 0.6 },
  { subject: 'Physics', chapter: 'Oscillations & Waves', expectedKey: 'physics_oscillations_waves', expectedWeight: 0.8 }
];

console.log('='.repeat(70));
console.log('CHAPTER WEIGHTS VERIFICATION');
console.log('='.repeat(70));
console.log('');

let passedCount = 0;
let failedCount = 0;
const failures = [];

TEST_CASES.forEach(({ subject, chapter, expectedKey, expectedWeight }) => {
  const generatedKey = formatChapterKey(subject, chapter);
  const actualWeight = JEE_CHAPTER_WEIGHTS[generatedKey];

  const keyMatch = generatedKey === expectedKey;
  const weightMatch = actualWeight === expectedWeight;
  const hasWeight = actualWeight !== undefined;

  if (keyMatch && weightMatch && hasWeight) {
    console.log(`✓ PASS: ${subject} / "${chapter}"`);
    console.log(`  Key: ${generatedKey}`);
    console.log(`  Weight: ${actualWeight}`);
    passedCount++;
  } else {
    console.log(`✗ FAIL: ${subject} / "${chapter}"`);
    console.log(`  Expected key: ${expectedKey}`);
    console.log(`  Generated key: ${generatedKey} ${keyMatch ? '✓' : '✗'}`);
    console.log(`  Expected weight: ${expectedWeight}`);
    console.log(`  Actual weight: ${actualWeight || 'MISSING'} ${weightMatch ? '✓' : '✗'}`);
    failedCount++;
    failures.push({ subject, chapter, generatedKey, actualWeight });
  }
  console.log('');
});

console.log('='.repeat(70));
console.log('SUMMARY');
console.log('='.repeat(70));
console.log(`Total tests: ${TEST_CASES.length}`);
console.log(`Passed: ${passedCount}`);
console.log(`Failed: ${failedCount}`);
console.log('');

if (failedCount === 0) {
  console.log('✓ ALL TESTS PASSED! Chapter weights are correctly configured.');
  console.log('');
  console.log('Next steps:');
  console.log('1. Deploy the updated backend to production');
  console.log('2. Run the migration script to recalculate user thetas:');
  console.log('   node backend/scripts/fix-chapter-weights.js');
  process.exit(0);
} else {
  console.log('✗ SOME TESTS FAILED. Please review the failures above.');
  console.log('');
  console.log('Failed chapters:');
  failures.forEach(({ subject, chapter, generatedKey, actualWeight }) => {
    console.log(`  - ${subject} / "${chapter}" → ${generatedKey} (weight: ${actualWeight || 'MISSING'})`);
  });
  process.exit(1);
}
