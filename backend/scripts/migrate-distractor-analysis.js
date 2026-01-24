/**
 * Migration script to add distractor_analysis from source JSON files to database
 *
 * The fresh_load import missed the distractor_analysis field.
 * This script reads the source JSON files and updates the database.
 *
 * Usage:
 *   node scripts/migrate-distractor-analysis.js
 *   node scripts/migrate-distractor-analysis.js --dry-run
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { db } = require('../src/config/firebase');

const FRESH_LOAD_DIR = path.join(__dirname, '../../inputs/fresh_load');
const BATCH_SIZE = 500;

async function migrateDistractorAnalysis(dryRun = false) {
  console.log('======================================================================');
  console.log('🔧 Migrating distractor_analysis from source JSON to database');
  console.log('======================================================================\n');
  console.log(`Mode: ${dryRun ? 'DRY RUN' : 'LIVE'}\n`);

  // Find all JSON files in fresh_load directory
  const jsonFiles = findJsonFiles(FRESH_LOAD_DIR);
  console.log(`Found ${jsonFiles.length} JSON files\n`);

  let totalQuestions = 0;
  let updated = 0;
  let skipped = 0;
  let notFound = 0;
  let errors = 0;

  for (const filePath of jsonFiles) {
    console.log(`\n📖 Processing: ${path.relative(FRESH_LOAD_DIR, filePath)}`);

    try {
      const jsonData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      const questions = Object.entries(jsonData);

      for (const [questionId, questionData] of questions) {
        totalQuestions++;

        // Skip if no distractor_analysis in source
        if (!questionData.distractor_analysis) {
          skipped++;
          continue;
        }

        // Check if question exists in database
        const docRef = db.collection('questions').doc(questionId);

        if (dryRun) {
          console.log(`  [DRY RUN] Would update ${questionId} with distractor_analysis`);
          updated++;
        } else {
          try {
            const doc = await docRef.get();
            if (!doc.exists) {
              console.log(`  ⚠️ ${questionId} not found in database`);
              notFound++;
              continue;
            }

            // Update with distractor_analysis
            await docRef.update({
              distractor_analysis: questionData.distractor_analysis
            });
            updated++;

            if (updated % 100 === 0) {
              console.log(`  ✅ Updated ${updated} questions...`);
            }
          } catch (error) {
            console.error(`  ❌ Error updating ${questionId}: ${error.message}`);
            errors++;
          }
        }
      }
    } catch (error) {
      console.error(`  ❌ Error processing file: ${error.message}`);
      errors++;
    }
  }

  console.log('\n======================================================================');
  console.log('📊 Migration Summary');
  console.log('======================================================================');
  console.log(`Total questions in JSON files: ${totalQuestions}`);
  console.log(`Updated with distractor_analysis: ${updated}`);
  console.log(`Skipped (no distractor_analysis in source): ${skipped}`);
  console.log(`Not found in database: ${notFound}`);
  console.log(`Errors: ${errors}`);

  if (dryRun) {
    console.log('\n⚠️ DRY RUN - No changes were made to the database');
    console.log('Run without --dry-run to apply changes');
  }
}

function findJsonFiles(dir) {
  const files = [];

  function walk(currentDir) {
    const items = fs.readdirSync(currentDir);
    for (const item of items) {
      const fullPath = path.join(currentDir, item);
      const stat = fs.statSync(fullPath);

      if (stat.isDirectory()) {
        walk(fullPath);
      } else if (item.endsWith('.json') && item.startsWith('questions')) {
        files.push(fullPath);
      }
    }
  }

  walk(dir);
  return files;
}

// CLI
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');

migrateDistractorAnalysis(dryRun)
  .then(() => {
    console.log('\n✅ Migration complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n❌ Migration failed:', error);
    process.exit(1);
  });
