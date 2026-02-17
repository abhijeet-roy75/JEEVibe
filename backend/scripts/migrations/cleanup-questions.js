/**
 * Question Cleanup Script
 * 
 * Safely delete questions from Firestore with preview and backup options.
 * 
 * Features:
 * 1. Delete by subject (e.g., Chemistry, Math)
 * 2. Delete by chapter (e.g., Chemical Bonding)
 * 3. Delete by chapter_key (e.g., chemistry_chemical_bonding)
 * 4. Delete by question ID pattern
 * 5. Preview mode (dry run) - see what will be deleted without actually deleting
 * 6. Backup option - export questions before deletion
 * 
 * Usage Examples:
 *   # Preview what will be deleted (safe - doesn't delete anything)
 *   node scripts/cleanup-questions.js --subject Chemistry --preview
 *   node scripts/cleanup-questions.js --chapter "Chemical Bonding" --preview
 *   node scripts/cleanup-questions.js --chapter-key chemistry_chemical_bonding --preview
 *   
 *   # Delete with backup (saves to backup file before deleting)
 *   node scripts/cleanup-questions.js --subject Math --backup
 *   node scripts/cleanup-questions.js --chapter-key math_matrices_determinants --backup
 *   
 *   # Delete without backup (be careful!)
 *   node scripts/cleanup-questions.js --subject Chemistry
 *   
 *   # Delete specific question IDs
 *   node scripts/cleanup-questions.js --ids CHEM_BOND_E_001,CHEM_BOND_E_002
 *   
 *   # Delete by ID pattern (RegEx)
 *   node scripts/cleanup-questions.js --pattern "^CHEM_BOND_.*" --preview
 *   
 *   # List all subjects and chapters (to help you decide what to delete)
 *   node scripts/cleanup-questions.js --list
 */

const path = require('path');
const fs = require('fs');
const { db, admin } = require('../src/config/firebase');

// ============================================================================
// CONFIGURATION
// ============================================================================

const BATCH_SIZE = 500; // Firestore batch write limit
const BACKUP_DIR = path.join(__dirname, '../../backups/questions');

// ============================================================================
// QUERY BUILDERS
// ============================================================================

/**
 * Build query based on filters
 * 
 * @param {Object} filters
 * @returns {Query} Firestore query
 */
function buildQuery(filters) {
  let query = db.collection('questions');
  
  if (filters.subject) {
    query = query.where('subject', '==', filters.subject);
  }
  
  if (filters.chapter) {
    query = query.where('chapter', '==', filters.chapter);
  }
  
  if (filters.chapterKey) {
    query = query.where('chapter_key', '==', filters.chapterKey);
  }
  
  return query;
}

/**
 * Get questions by IDs
 * 
 * @param {Array<string>} ids - Question IDs
 * @returns {Promise<Array>} Question documents
 */
async function getQuestionsByIds(ids) {
  const questions = [];
  
  // Process in chunks of 10 (Firestore getAll limit)
  for (let i = 0; i < ids.length; i += 10) {
    const chunk = ids.slice(i, i + 10);
    const refs = chunk.map(id => db.collection('questions').doc(id));
    
    const docs = await db.getAll(...refs);
    
    for (const doc of docs) {
      if (doc.exists) {
        questions.push({
          id: doc.id,
          data: doc.data()
        });
      }
    }
  }
  
  return questions;
}

/**
 * Get questions by pattern (RegEx on ID)
 * 
 * @param {string} pattern - RegEx pattern
 * @returns {Promise<Array>} Question documents
 */
async function getQuestionsByPattern(pattern) {
  const regex = new RegExp(pattern);
  const snapshot = await db.collection('questions').get();
  
  const questions = [];
  snapshot.forEach(doc => {
    if (regex.test(doc.id)) {
      questions.push({
        id: doc.id,
        data: doc.data()
      });
    }
  });
  
  return questions;
}

// ============================================================================
// LIST OPERATIONS
// ============================================================================

/**
 * List all subjects and chapters in the database
 * 
 * @returns {Promise<Object>} Summary of subjects and chapters
 */
async function listSubjectsAndChapters() {
  console.log('\n📊 Analyzing questions in database...\n');
  
  const snapshot = await db.collection('questions').get();
  
  const subjects = {};
  const chapterKeys = new Set();
  
  snapshot.forEach(doc => {
    const data = doc.data();
    const subject = data.subject || 'Unknown';
    const chapter = data.chapter || 'Unknown';
    const chapterKey = data.chapter_key || 'unknown';
    
    if (!subjects[subject]) {
      subjects[subject] = {
        count: 0,
        chapters: {}
      };
    }
    
    subjects[subject].count++;
    
    if (!subjects[subject].chapters[chapter]) {
      subjects[subject].chapters[chapter] = {
        count: 0,
        chapter_key: chapterKey
      };
    }
    
    subjects[subject].chapters[chapter].count++;
    chapterKeys.add(chapterKey);
  });
  
  console.log('📚 Total Questions:', snapshot.size);
  console.log('\n📖 Breakdown by Subject and Chapter:\n');
  
  Object.entries(subjects).sort().forEach(([subject, info]) => {
    console.log(`\n${subject} (${info.count} questions)`);
    
    Object.entries(info.chapters).sort().forEach(([chapter, chapterInfo]) => {
      console.log(`  └─ ${chapter}`);
      console.log(`     • Count: ${chapterInfo.count}`);
      console.log(`     • Chapter Key: ${chapterInfo.chapter_key}`);
    });
  });
  
  console.log('\n' + '='.repeat(60));
  console.log('💡 Tip: Use --subject, --chapter, or --chapter-key to filter questions');
  console.log('💡 Example: node scripts/cleanup-questions.js --subject Math --preview');
  console.log('='.repeat(60) + '\n');
}

// ============================================================================
// BACKUP OPERATIONS
// ============================================================================

/**
 * Backup questions to JSON file
 * 
 * @param {Array} questions - Questions to backup
 * @param {string} backupName - Backup file name
 * @returns {Promise<string>} Backup file path
 */
async function backupQuestions(questions, backupName) {
  try {
    // Ensure backup directory exists
    if (!fs.existsSync(BACKUP_DIR)) {
      fs.mkdirSync(BACKUP_DIR, { recursive: true });
    }
    
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const fileName = `${backupName}_${timestamp}.json`;
    const filePath = path.join(BACKUP_DIR, fileName);
    
    // Convert Firestore data to plain JSON
    const jsonData = {};
    questions.forEach(q => {
      jsonData[q.id] = q.data;
    });
    
    fs.writeFileSync(filePath, JSON.stringify(jsonData, null, 2));
    
    console.log(`✅ Backup saved: ${filePath}`);
    console.log(`   ${questions.length} questions backed up\n`);
    
    return filePath;
  } catch (error) {
    console.error('❌ Error creating backup:', error.message);
    throw error;
  }
}

// ============================================================================
// DELETE OPERATIONS
// ============================================================================

/**
 * Delete questions in batches
 * 
 * @param {Array} questions - Questions to delete
 * @returns {Promise<Object>} Results
 */
async function deleteQuestions(questions) {
  const results = {
    total: questions.length,
    deleted: 0,
    errors: 0,
    errorDetails: []
  };
  
  // Process in batches
  for (let i = 0; i < questions.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = questions.slice(i, i + BATCH_SIZE);
    
    console.log(`🗑️  Deleting batch ${Math.floor(i / BATCH_SIZE) + 1} (${chunk.length} questions)...`);
    
    chunk.forEach(q => {
      const ref = db.collection('questions').doc(q.id);
      batch.delete(ref);
    });
    
    try {
      await batch.commit();
      results.deleted += chunk.length;
      console.log(`   ✓ Deleted ${chunk.length} questions`);
    } catch (error) {
      console.error(`   ❌ Error deleting batch:`, error.message);
      results.errors += chunk.length;
      results.errorDetails.push({
        batch: Math.floor(i / BATCH_SIZE) + 1,
        error: error.message
      });
    }
    
    // Small delay to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  
  return results;
}

// ============================================================================
// PREVIEW OPERATIONS
// ============================================================================

/**
 * Preview questions that will be deleted
 * 
 * @param {Array} questions - Questions to preview
 */
function previewQuestions(questions) {
  console.log('\n' + '='.repeat(60));
  console.log('👀 PREVIEW MODE - No questions will be deleted');
  console.log('='.repeat(60) + '\n');
  
  console.log(`📊 Found ${questions.length} questions matching criteria:\n`);
  
  // Group by subject and chapter
  const grouped = {};
  questions.forEach(q => {
    const subject = q.data.subject || 'Unknown';
    const chapter = q.data.chapter || 'Unknown';
    
    if (!grouped[subject]) {
      grouped[subject] = {};
    }
    if (!grouped[subject][chapter]) {
      grouped[subject][chapter] = [];
    }
    
    grouped[subject][chapter].push(q.id);
  });
  
  // Display grouped questions
  Object.entries(grouped).forEach(([subject, chapters]) => {
    console.log(`\n${subject}`);
    Object.entries(chapters).forEach(([chapter, ids]) => {
      console.log(`  └─ ${chapter} (${ids.length} questions)`);
      
      // Show first 5 IDs as examples
      const examples = ids.slice(0, 5);
      examples.forEach(id => {
        console.log(`     • ${id}`);
      });
      
      if (ids.length > 5) {
        console.log(`     ... and ${ids.length - 5} more`);
      }
    });
  });
  
  console.log('\n' + '='.repeat(60));
  console.log('💡 To actually delete these questions, run the command without --preview');
  console.log('💡 To backup before deleting, add --backup flag');
  console.log('='.repeat(60) + '\n');
}

// ============================================================================
// CONFIRMATION
// ============================================================================

/**
 * Ask for confirmation before deleting
 * 
 * @param {number} count - Number of questions to delete
 * @returns {Promise<boolean>} User confirmed
 */
async function confirmDeletion(count) {
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  return new Promise((resolve) => {
    rl.question(
      `\n⚠️  You are about to delete ${count} questions. This action cannot be undone!\n` +
      `   Type 'DELETE' to confirm (or anything else to cancel): `,
      (answer) => {
        rl.close();
        resolve(answer.trim() === 'DELETE');
      }
    );
  });
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

async function main() {
  try {
    console.log('🧹 Question Cleanup Script\n');
    
    // Parse command line arguments
    const args = process.argv.slice(2);
    
    const options = {
      subject: null,
      chapter: null,
      chapterKey: null,
      ids: null,
      pattern: null,
      preview: args.includes('--preview'),
      backup: args.includes('--backup'),
      list: args.includes('--list'),
      force: args.includes('--force') // Skip confirmation
    };
    
    // Parse arguments
    if (args.includes('--subject')) {
      const idx = args.indexOf('--subject');
      options.subject = args[idx + 1];
    }
    
    if (args.includes('--chapter')) {
      const idx = args.indexOf('--chapter');
      options.chapter = args[idx + 1];
    }
    
    if (args.includes('--chapter-key')) {
      const idx = args.indexOf('--chapter-key');
      options.chapterKey = args[idx + 1];
    }
    
    if (args.includes('--ids')) {
      const idx = args.indexOf('--ids');
      options.ids = args[idx + 1].split(',').map(id => id.trim());
    }
    
    if (args.includes('--pattern')) {
      const idx = args.indexOf('--pattern');
      options.pattern = args[idx + 1];
    }
    
    // Handle --list command
    if (options.list) {
      await listSubjectsAndChapters();
      return;
    }
    
    // Validate options
    if (!options.subject && !options.chapter && !options.chapterKey && !options.ids && !options.pattern) {
      console.error('❌ Error: Please specify what to delete using one of these options:');
      console.error('   --subject <subject>');
      console.error('   --chapter <chapter>');
      console.error('   --chapter-key <chapter_key>');
      console.error('   --ids <id1,id2,id3>');
      console.error('   --pattern <regex>');
      console.error('\n💡 Or use --list to see all subjects and chapters\n');
      process.exit(1);
    }
    
    // Get questions to delete
    let questions = [];
    
    if (options.ids) {
      console.log(`🔍 Finding questions by IDs...`);
      questions = await getQuestionsByIds(options.ids);
    } else if (options.pattern) {
      console.log(`🔍 Finding questions matching pattern: ${options.pattern}`);
      questions = await getQuestionsByPattern(options.pattern);
    } else {
      console.log('🔍 Querying database...');
      const query = buildQuery({
        subject: options.subject,
        chapter: options.chapter,
        chapterKey: options.chapterKey
      });
      
      const snapshot = await query.get();
      questions = snapshot.docs.map(doc => ({
        id: doc.id,
        data: doc.data()
      }));
    }
    
    if (questions.length === 0) {
      console.log('\n✅ No questions found matching criteria. Nothing to delete.\n');
      return;
    }
    
    console.log(`\n✓ Found ${questions.length} questions\n`);
    
    // Preview mode
    if (options.preview) {
      previewQuestions(questions);
      return;
    }
    
    // Backup before deletion
    if (options.backup) {
      const backupName = options.subject 
        ? `cleanup_${options.subject.toLowerCase()}`
        : options.chapterKey 
          ? `cleanup_${options.chapterKey}`
          : 'cleanup';
      
      await backupQuestions(questions, backupName);
    }
    
    // Confirm deletion (unless --force)
    if (!options.force) {
      const confirmed = await confirmDeletion(questions.length);
      if (!confirmed) {
        console.log('\n❌ Deletion cancelled.\n');
        return;
      }
    }
    
    // Delete questions
    console.log('\n🗑️  Starting deletion...\n');
    const results = await deleteQuestions(questions);
    
    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 Deletion Summary');
    console.log('='.repeat(60));
    console.log(`Total questions: ${results.total}`);
    console.log(`✓ Deleted: ${results.deleted}`);
    console.log(`❌ Errors: ${results.errors}`);
    
    if (results.errors > 0 && results.errorDetails.length > 0) {
      console.log('\n❌ Error Details:');
      results.errorDetails.forEach(({ batch, error }) => {
        console.log(`  - Batch ${batch}: ${error}`);
      });
    }
    
    console.log('\n✅ Cleanup complete!\n');
    
  } catch (error) {
    console.error('\n❌ Fatal error:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main()
    .then(() => {
      console.log('🎉 Script completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('💥 Script failed:', error);
      process.exit(1);
    });
}

module.exports = {
  listSubjectsAndChapters,
  deleteQuestions,
  backupQuestions,
  getQuestionsByIds,
  getQuestionsByPattern
};

