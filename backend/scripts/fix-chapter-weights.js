#!/usr/bin/env node
/**
 * Fix Chapter Weights Migration Script
 *
 * This script recalculates overall_theta and theta_by_subject for all users
 * who have answered questions in the newly-added chapter keys.
 *
 * Newly added chapters:
 * - chemistry_basic_concepts
 * - chemistry_classification_and_periodicity
 * - chemistry_principles_of_practical_chemistry
 * - mathematics_inverse_trigonometry
 * - mathematics_conic_sections_parabola
 * - mathematics_parabola
 * - mathematics_threedimensional_geometry
 * - physics_transformers
 * - physics_eddy_currents
 * - physics_experimental_skills
 * - physics_kinetic_theory_of_gases
 * - physics_oscillations_waves
 *
 * Run: node backend/scripts/fix-chapter-weights.js
 */

require('dotenv').config();

const admin = require('firebase-admin');
const { db } = require('../src/config/firebase');

// Import theta calculation service
const {
  calculateWeightedOverallTheta,
  calculateSubjectTheta,
  thetaToPercentile
} = require('../src/services/thetaCalculationService');

// Chapters that were previously using default weight (0.5)
const AFFECTED_CHAPTERS = [
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

async function recalculateUserTheta(userId, userData) {
  const thetaByChapter = userData.theta_by_chapter || {};

  // Check if user has any of the affected chapters
  const hasAffectedChapters = Object.keys(thetaByChapter).some(chapter =>
    AFFECTED_CHAPTERS.includes(chapter)
  );

  if (!hasAffectedChapters) {
    return null; // Skip this user
  }

  // Recalculate overall theta with new weights
  const newOverallTheta = calculateWeightedOverallTheta(thetaByChapter);
  const newOverallPercentile = thetaToPercentile(newOverallTheta);

  // Recalculate subject thetas
  const newPhysicsTheta = calculateSubjectTheta(thetaByChapter, 'physics');
  const newChemistryTheta = calculateSubjectTheta(thetaByChapter, 'chemistry');
  const newMathematicsTheta = calculateSubjectTheta(thetaByChapter, 'mathematics');

  const thetaBySubject = {
    physics: newPhysicsTheta,
    chemistry: newChemistryTheta,
    mathematics: newMathematicsTheta
  };

  const updateData = {
    overall_theta: newOverallTheta,
    overall_percentile: newOverallPercentile,
    theta_by_subject: thetaBySubject,
    weights_migration_applied: true,
    weights_migration_date: new Date()
  };

  return updateData;
}

async function migrateAllUsers() {
  console.log('Starting chapter weights migration...\n');
  console.log('Affected chapters:', AFFECTED_CHAPTERS.join(', '));
  console.log('');

  const usersRef = db.collection('users');
  const snapshot = await usersRef.get();

  console.log(`Found ${snapshot.size} total users`);

  let processedCount = 0;
  let updatedCount = 0;
  let errorCount = 0;
  const errors = [];

  // Use batch writes (max 500 operations per batch)
  let batch = db.batch();
  let batchOpsCount = 0;
  const BATCH_SIZE = 500;

  for (const doc of snapshot.docs) {
    try {
      const userId = doc.id;
      const userData = doc.data();

      const updateData = await recalculateUserTheta(userId, userData);

      if (updateData) {
        batch.update(doc.ref, updateData);
        batchOpsCount++;
        updatedCount++;

        console.log(`✓ Queued update for user ${userId} (overall_theta: ${userData.overall_theta?.toFixed(2)} → ${updateData.overall_theta.toFixed(2)})`);

        // Commit batch if it reaches max size
        if (batchOpsCount >= BATCH_SIZE) {
          await batch.commit();
          console.log(`  → Committed batch of ${batchOpsCount} updates`);
          batch = db.batch();
          batchOpsCount = 0;
        }
      }

      processedCount++;

      if (processedCount % 100 === 0) {
        console.log(`Progress: ${processedCount}/${snapshot.size} users processed`);
      }

    } catch (error) {
      errorCount++;
      errors.push({ userId: doc.id, error: error.message });
      console.error(`✗ Error processing user ${doc.id}:`, error.message);
    }
  }

  // Commit remaining batch
  if (batchOpsCount > 0) {
    await batch.commit();
    console.log(`  → Committed final batch of ${batchOpsCount} updates`);
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('MIGRATION COMPLETE');
  console.log('='.repeat(60));
  console.log(`Total users processed: ${processedCount}`);
  console.log(`Users updated: ${updatedCount}`);
  console.log(`Users skipped (no affected chapters): ${processedCount - updatedCount - errorCount}`);
  console.log(`Errors: ${errorCount}`);

  if (errors.length > 0) {
    console.log('\nErrors:');
    errors.forEach(({ userId, error }) => {
      console.log(`  - User ${userId}: ${error}`);
    });
  }

  console.log('');
  process.exit(0);
}

// Run migration
migrateAllUsers().catch(error => {
  console.error('Migration failed:', error);
  process.exit(1);
});
