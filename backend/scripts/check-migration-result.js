#!/usr/bin/env node
/**
 * Check Migration Result
 * Verifies that the chapter weights migration was applied correctly
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

async function checkMigrationResult(userId) {
  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    console.log(`User ${userId} not found`);
    return;
  }

  const userData = userDoc.data();

  console.log('='.repeat(70));
  console.log(`USER: ${userId}`);
  console.log('='.repeat(70));
  console.log('');

  console.log('Migration Status:');
  console.log(`  Applied: ${userData.weights_migration_applied || false}`);
  console.log(`  Date: ${userData.weights_migration_date ? new Date(userData.weights_migration_date.seconds * 1000).toISOString() : 'N/A'}`);
  console.log('');

  console.log('Overall Theta:');
  console.log(`  Theta: ${userData.overall_theta?.toFixed(3) || 'N/A'}`);
  console.log(`  Percentile: ${userData.overall_percentile?.toFixed(2) || 'N/A'}`);
  console.log('');

  console.log('Subject Theta:');
  if (userData.theta_by_subject) {
    ['physics', 'chemistry', 'mathematics'].forEach(subject => {
      const subjectData = userData.theta_by_subject[subject];
      if (subjectData && subjectData.theta !== null) {
        console.log(`  ${subject}: θ=${subjectData.theta.toFixed(3)}, %ile=${subjectData.percentile?.toFixed(1) || 'N/A'}`);
      }
    });
  } else {
    console.log('  No subject theta data');
  }
  console.log('');

  console.log('Affected Chapters Present:');
  const affectedChapters = [
    'chemistry_basic_concepts',
    'chemistry_classification_and_periodicity',
    'chemistry_principles_of_practical_chemistry',
    'mathematics_inverse_trigonometry',
    'mathematics_conic_sections_parabola',
    'mathematics_parabola',
    'mathematics_threedimensional_geometry',
    'physics_transformers',
    'physics_eddy_currents',
    'physics_experimental_skills',
    'physics_kinetic_theory_of_gases',
    'physics_oscillations_waves'
  ];

  const thetaByChapter = userData.theta_by_chapter || {};
  const userAffectedChapters = Object.keys(thetaByChapter).filter(ch =>
    affectedChapters.includes(ch)
  );

  if (userAffectedChapters.length > 0) {
    userAffectedChapters.forEach(ch => {
      const chData = thetaByChapter[ch];
      console.log(`  ${ch}: θ=${chData.theta.toFixed(3)}, questions=${chData.questions_answered || 0}`);
    });
  } else {
    console.log('  None');
  }
  console.log('');
}

// Check the first migrated user
checkMigrationResult('8qsiYYoMqISyFukczgN17x3Qhgm2')
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
