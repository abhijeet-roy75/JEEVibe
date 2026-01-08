#!/usr/bin/env node
/**
 * Migration Script: Fix user theta_by_chapter keys
 *
 * Problem: Users who completed assessment before the chapter key normalization
 * was added have mismatched chapter keys (e.g., "physics_mechanics" instead of
 * "physics_laws_of_motion").
 *
 * Solution: Apply the same normalization and expansion logic to existing users.
 */

require('dotenv').config();

const { db } = require('../src/config/firebase');
const {
  formatChapterKey,
  expandBroadChaptersToSpecific,
  isBroadChapter,
  CHAPTER_NAME_NORMALIZATIONS
} = require('../src/services/thetaCalculationService');

// Map from old chapter keys to the correct question bank chapter keys
// These are specific mismatches between assessment chapters and daily quiz chapters
const CHAPTER_KEY_MIGRATIONS = {
  // Assessment chapters that need direct mapping to daily quiz chapters
  "physics_mechanics": "physics_laws_of_motion", // Primary mechanics chapter
  "physics_dual_nature": "physics_dual_nature_of_radiation",
  "physics_magnetic_effects": "physics_magnetic_effects_magnetism",
  "chemistry_physical_chemistry": "chemistry_thermodynamics", // Primary physical chem chapter
  "chemistry_organic_basics": "chemistry_general_organic_chemistry",
  "chemistry_classification_elements": "chemistry_classification_periodicity",
  "mathematics_limits_continuity": "mathematics_limits_continuity_differentiability",
  "mathematics_coordinate_geometry": "mathematics_straight_lines", // Primary coord geo chapter

  // Broad chapters that should expand (handled by expandBroadChaptersToSpecific)
  // These are listed here for completeness but will be expanded
};

async function migrateUserThetaChapters(dryRun = true) {
  console.log('=' .repeat(70));
  console.log('📊 User Theta Chapter Migration');
  console.log('=' .repeat(70));
  console.log(`Mode: ${dryRun ? 'DRY RUN (no changes)' : 'LIVE MIGRATION'}`);
  console.log();

  // Get all users with completed assessments
  const usersSnapshot = await db.collection('users')
    .where('assessment.status', '==', 'completed')
    .get();

  console.log(`Found ${usersSnapshot.size} users with completed assessments`);
  console.log();

  let usersNeedingMigration = 0;
  let usersMigrated = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();
    const oldThetaByChapter = userData.theta_by_chapter || {};

    // Check if this user needs migration
    const oldKeys = Object.keys(oldThetaByChapter);
    const needsMigration = oldKeys.some(key => {
      // Check if key is in migration map or is a broad chapter that should expand
      return CHAPTER_KEY_MIGRATIONS[key] || isBroadChapter(key);
    });

    if (!needsMigration) {
      continue;
    }

    usersNeedingMigration++;
    console.log(`\n📋 User: ${userId}`);
    console.log(`   Assessment completed: ${userData.assessment?.completed_at}`);
    console.log(`   Old chapter count: ${oldKeys.length}`);

    // Step 1: Apply direct key migrations
    const migratedTheta = {};
    for (const [oldKey, thetaData] of Object.entries(oldThetaByChapter)) {
      if (CHAPTER_KEY_MIGRATIONS[oldKey]) {
        const newKey = CHAPTER_KEY_MIGRATIONS[oldKey];
        migratedTheta[newKey] = {
          ...thetaData,
          migrated_from: oldKey,
          migrated_at: new Date().toISOString()
        };
        console.log(`   ✅ ${oldKey} → ${newKey}`);
      } else {
        // Keep as-is (already correct or will be expanded)
        migratedTheta[oldKey] = thetaData;
      }
    }

    // Step 2: Expand broad chapters to specific chapters
    const expandedTheta = expandBroadChaptersToSpecific(migratedTheta);

    console.log(`   New chapter count: ${Object.keys(expandedTheta).length}`);

    // Show expansion results
    const derivedCount = Object.values(expandedTheta).filter(d => d.is_derived).length;
    if (derivedCount > 0) {
      console.log(`   Derived from broad: ${derivedCount} chapters`);
    }

    // Step 3: Update user document (if not dry run)
    if (!dryRun) {
      try {
        await db.collection('users').doc(userId).update({
          theta_by_chapter: expandedTheta,
          theta_migrated_at: new Date().toISOString(),
          theta_migrated_from_version: 'v1_broad_chapters'
        });
        usersMigrated++;
        console.log(`   ✅ MIGRATED`);
      } catch (error) {
        console.error(`   ❌ ERROR: ${error.message}`);
      }
    } else {
      console.log(`   (DRY RUN - no changes made)`);
    }
  }

  console.log();
  console.log('=' .repeat(70));
  console.log('📊 Migration Summary');
  console.log('=' .repeat(70));
  console.log(`   Total users with completed assessment: ${usersSnapshot.size}`);
  console.log(`   Users needing migration: ${usersNeedingMigration}`);
  if (!dryRun) {
    console.log(`   Users successfully migrated: ${usersMigrated}`);
  }
  console.log();

  if (dryRun && usersNeedingMigration > 0) {
    console.log('To apply migration, run with --live flag:');
    console.log('  node scripts/migrate-user-theta-chapters.js --live');
  }
}

// Parse command line args
const args = process.argv.slice(2);
const isLive = args.includes('--live');

migrateUserThetaChapters(!isLive)
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Migration failed:', err.message);
    process.exit(1);
  });
