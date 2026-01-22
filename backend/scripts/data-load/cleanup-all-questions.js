/**
 * Cleanup All Questions Script
 *
 * Safely deletes or archives ALL questions from both Firestore collections:
 * - questions (daily quiz / chapter practice)
 * - initial_assessment_questions (diagnostic assessment)
 *
 * Features:
 * - Preview mode (dry run)
 * - Archive mode (soft delete - sets active: false)
 * - Backup to JSON before deletion
 * - Collection-specific deletion
 * - Safety confirmation required
 *
 * Usage:
 *   # Preview what will be deleted (safe)
 *   node scripts/data-load/cleanup-all-questions.js --preview
 *
 *   # Delete all with backup (RECOMMENDED)
 *   node scripts/data-load/cleanup-all-questions.js --backup
 *
 *   # Archive instead of delete (soft delete - sets active: false)
 *   node scripts/data-load/cleanup-all-questions.js --archive --reason "Replaced with v2 question bank"
 *
 *   # Delete only questions collection
 *   node scripts/data-load/cleanup-all-questions.js --collection questions --backup
 *
 *   # Delete only initial assessment questions
 *   node scripts/data-load/cleanup-all-questions.js --collection initial_assessment_questions --backup
 *
 *   # Force delete without confirmation (DANGEROUS)
 *   node scripts/data-load/cleanup-all-questions.js --backup --force
 */

const path = require('path');
const fs = require('fs');
const { db, admin } = require('../../src/config/firebase');

// ============================================================================
// CONFIGURATION
// ============================================================================

const BATCH_SIZE = 500;
const BACKUP_DIR = path.join(__dirname, '../../../backups/data-load');
const COLLECTIONS = ['questions', 'initial_assessment_questions'];

// ============================================================================
// BACKUP OPERATIONS
// ============================================================================

/**
 * Backup a collection to JSON file
 */
async function backupCollection(collectionName) {
  console.log(`\n📦 Backing up ${collectionName}...`);

  const snapshot = await db.collection(collectionName).get();

  if (snapshot.empty) {
    console.log(`   ⚠️  Collection ${collectionName} is empty, nothing to backup`);
    return null;
  }

  // Ensure backup directory exists
  if (!fs.existsSync(BACKUP_DIR)) {
    fs.mkdirSync(BACKUP_DIR, { recursive: true });
  }

  // Convert to JSON-serializable format
  const data = {};
  snapshot.forEach(doc => {
    const docData = doc.data();
    // Convert Firestore Timestamps to ISO strings
    Object.keys(docData).forEach(key => {
      if (docData[key] && docData[key].toDate) {
        docData[key] = docData[key].toDate().toISOString();
      }
    });
    data[doc.id] = docData;
  });

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const fileName = `backup_${collectionName}_${timestamp}.json`;
  const filePath = path.join(BACKUP_DIR, fileName);

  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));

  console.log(`   ✅ Backed up ${snapshot.size} documents to: ${fileName}`);

  return {
    filePath,
    count: snapshot.size
  };
}

// ============================================================================
// ARCHIVE OPERATIONS
// ============================================================================

/**
 * Archive all documents in a collection (soft delete - sets active: false)
 */
async function archiveCollection(collectionName, reason = null, preview = false) {
  console.log(`\n${preview ? '👀' : '📦'} ${preview ? 'Previewing archive of' : 'Archiving'} ${collectionName}...`);

  const collectionRef = db.collection(collectionName);
  // Only archive active questions
  const snapshot = await collectionRef.where('active', '!=', false).get();

  if (snapshot.empty) {
    console.log(`   ⚠️  No active questions in ${collectionName}`);
    return { total: 0, archived: 0 };
  }

  const total = snapshot.size;
  console.log(`   Found ${total} active documents`);

  if (preview) {
    const samples = snapshot.docs.slice(0, 5);
    console.log(`   Sample documents to archive:`);
    samples.forEach(doc => {
      const data = doc.data();
      console.log(`     - ${doc.id} (${data.subject || 'N/A'} / ${data.chapter || 'N/A'})`);
    });
    if (total > 5) {
      console.log(`     ... and ${total - 5} more`);
    }
    return { total, archived: 0 };
  }

  // Archive in batches
  let archived = 0;
  const docs = snapshot.docs;
  const archiveTimestamp = admin.firestore.FieldValue.serverTimestamp();

  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = docs.slice(i, i + BATCH_SIZE);

    chunk.forEach(doc => {
      batch.update(doc.ref, {
        active: false,
        archived_at: archiveTimestamp,
        archived_reason: reason || 'Batch archive via cleanup script'
      });
    });

    await batch.commit();
    archived += chunk.length;

    const progress = Math.round((archived / total) * 100);
    console.log(`   Progress: ${archived}/${total} (${progress}%)`);

    await new Promise(resolve => setTimeout(resolve, 100));
  }

  console.log(`   ✅ Archived ${archived} documents in ${collectionName}`);

  return { total, archived };
}

// ============================================================================
// DELETE OPERATIONS
// ============================================================================

/**
 * Delete all documents in a collection using batched writes
 */
async function deleteCollection(collectionName, preview = false) {
  console.log(`\n${preview ? '👀' : '🗑️ '} ${preview ? 'Previewing' : 'Deleting'} ${collectionName}...`);

  const collectionRef = db.collection(collectionName);
  const snapshot = await collectionRef.get();

  if (snapshot.empty) {
    console.log(`   ⚠️  Collection ${collectionName} is empty`);
    return { total: 0, deleted: 0 };
  }

  const total = snapshot.size;
  console.log(`   Found ${total} documents`);

  if (preview) {
    // Show sample documents
    const samples = snapshot.docs.slice(0, 5);
    console.log(`   Sample documents:`);
    samples.forEach(doc => {
      const data = doc.data();
      console.log(`     - ${doc.id} (${data.subject || 'N/A'} / ${data.chapter || 'N/A'})`);
    });
    if (total > 5) {
      console.log(`     ... and ${total - 5} more`);
    }
    return { total, deleted: 0 };
  }

  // Delete in batches
  let deleted = 0;
  const docs = snapshot.docs;

  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = docs.slice(i, i + BATCH_SIZE);

    chunk.forEach(doc => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    deleted += chunk.length;

    const progress = Math.round((deleted / total) * 100);
    console.log(`   Progress: ${deleted}/${total} (${progress}%)`);

    // Small delay to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  console.log(`   ✅ Deleted ${deleted} documents from ${collectionName}`);

  return { total, deleted };
}

// ============================================================================
// CONFIRMATION
// ============================================================================

async function confirmAction(totalCount, collections, isArchive = false) {
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  const action = isArchive ? 'archive' : 'delete';
  const confirmPhrase = isArchive ? 'ARCHIVE ALL' : 'DELETE ALL';

  return new Promise((resolve) => {
    console.log('\n' + '='.repeat(60));
    if (isArchive) {
      console.log('⚠️  WARNING: This will archive all questions (set active: false)');
    } else {
      console.log('⚠️  WARNING: This will permanently delete questions!');
    }
    console.log('='.repeat(60));
    console.log(`Collections: ${collections.join(', ')}`);
    console.log(`Total documents to ${action}: ${totalCount}`);
    console.log('='.repeat(60));

    rl.question(
      `\nType '${confirmPhrase}' to confirm (or anything else to cancel): `,
      (answer) => {
        rl.close();
        resolve(answer.trim() === confirmPhrase);
      }
    );
  });
}

// Backward compatibility alias
async function confirmDeletion(totalCount, collections) {
  return confirmAction(totalCount, collections, false);
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

async function main() {
  try {
    console.log('🧹 Cleanup All Questions Script\n');
    console.log('=' .repeat(60));

    // Parse arguments
    const args = process.argv.slice(2);
    const options = {
      preview: args.includes('--preview'),
      backup: args.includes('--backup'),
      force: args.includes('--force'),
      archive: args.includes('--archive'),
      collection: null,
      reason: null
    };

    // Parse --collection option
    if (args.includes('--collection')) {
      const idx = args.indexOf('--collection');
      options.collection = args[idx + 1];

      if (!COLLECTIONS.includes(options.collection)) {
        console.error(`❌ Invalid collection: ${options.collection}`);
        console.error(`   Valid collections: ${COLLECTIONS.join(', ')}`);
        process.exit(1);
      }
    }

    // Parse --reason option (for archive mode)
    if (args.includes('--reason')) {
      const idx = args.indexOf('--reason');
      options.reason = args[idx + 1];
    }

    // Determine which collections to process
    const collectionsToProcess = options.collection
      ? [options.collection]
      : COLLECTIONS;

    console.log(`Collections: ${collectionsToProcess.join(', ')}`);
    console.log(`Mode: ${options.preview ? 'PREVIEW (no changes)' : (options.archive ? 'ARCHIVE (soft delete)' : 'DELETE')}`);
    console.log(`Backup: ${options.backup ? 'Yes' : 'No'}`);
    if (options.archive && options.reason) {
      console.log(`Archive reason: ${options.reason}`);
    }
    console.log('=' .repeat(60));

    // Get counts first
    let totalCount = 0;
    const counts = {};

    for (const collection of collectionsToProcess) {
      const snapshot = await db.collection(collection).get();
      counts[collection] = snapshot.size;
      totalCount += snapshot.size;
    }

    console.log('\n📊 Current state:');
    for (const [collection, count] of Object.entries(counts)) {
      console.log(`   ${collection}: ${count} documents`);
    }
    console.log(`   Total: ${totalCount} documents`);

    if (totalCount === 0) {
      console.log('\n✅ All collections are already empty. Nothing to do.\n');
      return;
    }

    // Preview mode
    if (options.preview) {
      console.log('\n' + '='.repeat(60));
      console.log('👀 PREVIEW MODE - No changes will be made');
      console.log('='.repeat(60));

      for (const collection of collectionsToProcess) {
        if (options.archive) {
          await archiveCollection(collection, options.reason, true);
        } else {
          await deleteCollection(collection, true);
        }
      }

      console.log('\n💡 To actually execute, run without --preview');
      console.log('💡 To backup before deleting, add --backup');
      console.log('💡 To archive instead of delete, add --archive\n');
      return;
    }

    // Backup if requested
    if (options.backup) {
      console.log('\n📦 Creating backups...');

      for (const collection of collectionsToProcess) {
        await backupCollection(collection);
      }
    }

    // Confirmation (unless --force)
    if (!options.force) {
      const actionWord = options.archive ? 'ARCHIVE ALL' : 'DELETE ALL';
      const confirmed = await confirmAction(totalCount, collectionsToProcess, options.archive);
      if (!confirmed) {
        console.log(`\n❌ ${options.archive ? 'Archive' : 'Deletion'} cancelled.\n`);
        return;
      }
    }

    // Execute archive or delete
    if (options.archive) {
      // Archive mode (soft delete)
      console.log('\n📦 Starting archive...');

      const results = {};
      for (const collection of collectionsToProcess) {
        results[collection] = await archiveCollection(collection, options.reason, false);
      }

      // Summary
      console.log('\n' + '='.repeat(60));
      console.log('📊 Archive Summary');
      console.log('='.repeat(60));

      let totalArchived = 0;
      for (const [collection, result] of Object.entries(results)) {
        console.log(`${collection}: ${result.archived}/${result.total} archived`);
        totalArchived += result.archived;
      }

      console.log(`Total archived: ${totalArchived}`);
      console.log('\n✅ Archive complete! Questions are now inactive but preserved.\n');
    } else {
      // Delete mode (hard delete)
      console.log('\n🗑️  Starting deletion...');

      const results = {};
      for (const collection of collectionsToProcess) {
        results[collection] = await deleteCollection(collection, false);
      }

      // Summary
      console.log('\n' + '='.repeat(60));
      console.log('📊 Deletion Summary');
      console.log('='.repeat(60));

      let totalDeleted = 0;
      for (const [collection, result] of Object.entries(results)) {
        console.log(`${collection}: ${result.deleted}/${result.total} deleted`);
        totalDeleted += result.deleted;
      }

      console.log(`Total deleted: ${totalDeleted}`);
      console.log('\n✅ Cleanup complete!\n');
    }

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
  backupCollection,
  deleteCollection,
  archiveCollection
};
