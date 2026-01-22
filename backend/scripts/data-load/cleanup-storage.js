/**
 * Cleanup Firebase Storage Script
 *
 * Deletes files from Firebase Storage folders used for question images:
 * - questions/daily_quiz/
 * - questions/initial_assessment/
 *
 * Features:
 * - Preview mode (dry run)
 * - Delete specific folders
 * - List files before deletion
 * - Safety confirmation required
 *
 * Usage:
 *   # Preview what will be deleted (safe)
 *   node scripts/data-load/cleanup-storage.js --preview
 *
 *   # Delete all question images
 *   node scripts/data-load/cleanup-storage.js
 *
 *   # Delete specific folder only
 *   node scripts/data-load/cleanup-storage.js --folder questions/daily_quiz
 *   node scripts/data-load/cleanup-storage.js --folder questions/initial_assessment
 *
 *   # Force delete without confirmation
 *   node scripts/data-load/cleanup-storage.js --force
 */

const { storage, admin } = require('../../src/config/firebase');

// ============================================================================
// CONFIGURATION
// ============================================================================

const DEFAULT_FOLDERS = [
  'questions/daily_quiz',
  'questions/initial_assessment'
];

// ============================================================================
// STORAGE OPERATIONS
// ============================================================================

/**
 * Get bucket instance (handles different bucket name formats)
 */
async function getBucket() {
  let bucket = storage.bucket();

  try {
    const [exists] = await bucket.exists();
    if (!exists) {
      // Try alternative bucket name formats
      const projectId = admin.app().options.projectId || 'jeevibe';
      const bucketNames = [
        `${projectId}.appspot.com`,
        `${projectId}.firebasestorage.app`,
        projectId
      ];

      for (const bucketName of bucketNames) {
        try {
          const testBucket = storage.bucket(bucketName);
          const [testExists] = await testBucket.exists();
          if (testExists) {
            bucket = testBucket;
            console.log(`Using bucket: ${bucketName}`);
            break;
          }
        } catch (e) {
          continue;
        }
      }
    }
  } catch (error) {
    console.warn(`⚠️  Could not verify bucket existence, proceeding anyway`);
  }

  return bucket;
}

/**
 * List files in a folder
 */
async function listFiles(bucket, folderPath) {
  try {
    const [files] = await bucket.getFiles({
      prefix: folderPath.endsWith('/') ? folderPath : `${folderPath}/`
    });

    return files.filter(file => !file.name.endsWith('/'));
  } catch (error) {
    console.error(`Error listing files in ${folderPath}:`, error.message);
    return [];
  }
}

/**
 * Delete files in a folder
 */
async function deleteFolder(bucket, folderPath, preview = false) {
  console.log(`\n${preview ? '👀' : '🗑️ '} ${preview ? 'Previewing' : 'Deleting'} ${folderPath}...`);

  const files = await listFiles(bucket, folderPath);

  if (files.length === 0) {
    console.log(`   ⚠️  No files found in ${folderPath}`);
    return { total: 0, deleted: 0 };
  }

  console.log(`   Found ${files.length} files`);

  if (preview) {
    // Show sample files
    const samples = files.slice(0, 10);
    console.log(`   Sample files:`);
    samples.forEach(file => {
      console.log(`     - ${file.name}`);
    });
    if (files.length > 10) {
      console.log(`     ... and ${files.length - 10} more`);
    }
    return { total: files.length, deleted: 0 };
  }

  // Delete files
  let deleted = 0;
  let errors = 0;

  for (const file of files) {
    try {
      await file.delete();
      deleted++;

      // Progress update every 50 files
      if (deleted % 50 === 0 || deleted === files.length) {
        const progress = Math.round((deleted / files.length) * 100);
        console.log(`   Progress: ${deleted}/${files.length} (${progress}%)`);
      }
    } catch (error) {
      console.error(`   ❌ Error deleting ${file.name}: ${error.message}`);
      errors++;
    }
  }

  console.log(`   ✅ Deleted ${deleted} files from ${folderPath}`);

  if (errors > 0) {
    console.log(`   ⚠️  ${errors} files failed to delete`);
  }

  return { total: files.length, deleted, errors };
}

// ============================================================================
// CONFIRMATION
// ============================================================================

async function confirmDeletion(totalCount, folders) {
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise((resolve) => {
    console.log('\n' + '='.repeat(60));
    console.log('⚠️  WARNING: This will permanently delete files from Storage!');
    console.log('='.repeat(60));
    console.log(`Folders: ${folders.join(', ')}`);
    console.log(`Total files to delete: ${totalCount}`);
    console.log('='.repeat(60));

    rl.question(
      `\nType 'DELETE FILES' to confirm (or anything else to cancel): `,
      (answer) => {
        rl.close();
        resolve(answer.trim() === 'DELETE FILES');
      }
    );
  });
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

async function main() {
  try {
    console.log('🧹 Cleanup Firebase Storage Script\n');
    console.log('='.repeat(60));

    // Parse arguments
    const args = process.argv.slice(2);
    const options = {
      preview: args.includes('--preview'),
      force: args.includes('--force'),
      folder: null
    };

    // Parse --folder option
    if (args.includes('--folder')) {
      const idx = args.indexOf('--folder');
      options.folder = args[idx + 1];
    }

    // Determine which folders to process
    const foldersToProcess = options.folder
      ? [options.folder]
      : DEFAULT_FOLDERS;

    console.log(`Folders: ${foldersToProcess.join(', ')}`);
    console.log(`Mode: ${options.preview ? 'PREVIEW (no changes)' : 'DELETE'}`);
    console.log('='.repeat(60));

    // Get bucket
    const bucket = await getBucket();
    console.log(`\nUsing bucket: ${bucket.name}`);

    // Get counts first
    let totalCount = 0;
    const counts = {};

    for (const folder of foldersToProcess) {
      const files = await listFiles(bucket, folder);
      counts[folder] = files.length;
      totalCount += files.length;
    }

    console.log('\n📊 Current state:');
    for (const [folder, count] of Object.entries(counts)) {
      console.log(`   ${folder}: ${count} files`);
    }
    console.log(`   Total: ${totalCount} files`);

    if (totalCount === 0) {
      console.log('\n✅ All folders are already empty. Nothing to do.\n');
      return;
    }

    // Preview mode
    if (options.preview) {
      console.log('\n' + '='.repeat(60));
      console.log('👀 PREVIEW MODE - No files will be deleted');
      console.log('='.repeat(60));

      for (const folder of foldersToProcess) {
        await deleteFolder(bucket, folder, true);
      }

      console.log('\n💡 To actually delete, run without --preview');
      return;
    }

    // Confirmation (unless --force)
    if (!options.force) {
      const confirmed = await confirmDeletion(totalCount, foldersToProcess);
      if (!confirmed) {
        console.log('\n❌ Deletion cancelled.\n');
        return;
      }
    }

    // Delete folders
    console.log('\n🗑️  Starting deletion...');

    const results = {};
    for (const folder of foldersToProcess) {
      results[folder] = await deleteFolder(bucket, folder, false);
    }

    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 Deletion Summary');
    console.log('='.repeat(60));

    let totalDeleted = 0;
    for (const [folder, result] of Object.entries(results)) {
      console.log(`${folder}: ${result.deleted}/${result.total} deleted`);
      totalDeleted += result.deleted;
    }

    console.log(`Total deleted: ${totalDeleted}`);
    console.log('\n✅ Storage cleanup complete!\n');

  } catch (error) {
    console.error('\n❌ Fatal error:', error);
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

module.exports = {
  getBucket,
  listFiles,
  deleteFolder
};
