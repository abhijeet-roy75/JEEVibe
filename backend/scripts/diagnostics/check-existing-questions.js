/**
 * Check Existing Questions
 *
 * Checks which questions from your JSON files already exist in Firebase
 * and provides a detailed report of what was skipped during import.
 *
 * Usage:
 *   node scripts/check-existing-questions.js --dir ../inputs/incremental_load1
 */

const path = require('path');
const fs = require('fs');
const { db } = require('../src/config/firebase');
const { retryFirestoreOperation } = require('../src/utils/firestoreRetry');

// ============================================================================
// FILE PARSING
// ============================================================================

/**
 * Find all JSON files in a directory
 */
function findQuestionFiles(folderPath) {
  const files = fs.readdirSync(folderPath);
  const jsonFiles = files.filter(f =>
    f.endsWith('.json') && !f.startsWith('.') && f !== 'processed'
  );
  return jsonFiles.map(f => path.join(folderPath, f));
}

/**
 * Parse questions from JSON file
 */
function parseQuestionsFile(filePath) {
  const jsonData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const questions = [];

  if (Array.isArray(jsonData)) {
    jsonData.forEach(q => {
      const questionId = q.question_id || q.id;
      if (questionId) {
        questions.push({ questionId, questionData: q });
      }
    });
  } else if (jsonData.questions && Array.isArray(jsonData.questions)) {
    jsonData.questions.forEach(q => {
      const questionId = q.question_id || q.id;
      if (questionId) {
        questions.push({ questionId, questionData: q });
      }
    });
  } else {
    Object.entries(jsonData).forEach(([questionId, questionData]) => {
      if (typeof questionData === 'object' && questionData !== null) {
        questions.push({ questionId, questionData });
      }
    });
  }

  return questions;
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

async function main() {
  try {
    console.log('🔍 Checking Existing Questions\n');
    console.log('='.repeat(60));

    // Parse arguments
    const args = process.argv.slice(2);
    let dirPath = null;

    if (args.includes('--dir')) {
      const idx = args.indexOf('--dir');
      dirPath = args[idx + 1];
    }

    if (!dirPath) {
      console.error('❌ Error: Please specify directory with --dir');
      console.error('   Example: node scripts/check-existing-questions.js --dir ../inputs/incremental_load1');
      process.exit(1);
    }

    // Resolve path
    const rootDir = path.isAbsolute(dirPath)
      ? dirPath
      : path.join(process.cwd(), dirPath);

    if (!fs.existsSync(rootDir)) {
      console.error(`❌ Error: Directory not found: ${rootDir}`);
      process.exit(1);
    }

    console.log(`Directory: ${rootDir}`);
    console.log('='.repeat(60));

    // Find all JSON files
    const jsonFiles = findQuestionFiles(rootDir);
    console.log(`\n📄 Found ${jsonFiles.length} JSON file(s)\n`);

    // Collect all questions
    const allQuestions = [];
    const fileMap = new Map(); // questionId -> fileName

    for (const jsonFile of jsonFiles) {
      const fileName = path.basename(jsonFile);
      console.log(`   Reading ${fileName}...`);

      try {
        const questions = parseQuestionsFile(jsonFile);
        for (const { questionId, questionData } of questions) {
          allQuestions.push(questionId);
          fileMap.set(questionId, fileName);
        }
      } catch (error) {
        console.error(`   ❌ Error parsing ${fileName}: ${error.message}`);
      }
    }

    console.log(`\n✅ Total questions in JSON files: ${allQuestions.length}`);

    // Check which exist in Firebase
    console.log('\n🔄 Checking Firebase database...\n');

    const BATCH_SIZE = 500;
    const existingQuestions = [];
    const missingQuestions = [];

    // Process in batches
    for (let i = 0; i < allQuestions.length; i += BATCH_SIZE) {
      const batch = allQuestions.slice(i, i + BATCH_SIZE);
      const questionRefs = batch.map(id => db.collection('questions').doc(id));

      const docs = await retryFirestoreOperation(() => db.getAll(...questionRefs));

      for (let j = 0; j < docs.length; j++) {
        const doc = docs[j];
        const questionId = batch[j];

        if (doc.exists) {
          existingQuestions.push({
            id: questionId,
            file: fileMap.get(questionId),
            data: doc.data()
          });
        } else {
          missingQuestions.push({
            id: questionId,
            file: fileMap.get(questionId)
          });
        }
      }
    }

    // Print results
    console.log('='.repeat(60));
    console.log('📊 RESULTS');
    console.log('='.repeat(60));

    console.log(`\n✅ Existing in Firebase: ${existingQuestions.length} (would be skipped)`);
    console.log(`❌ Not in Firebase: ${missingQuestions.length} (would be imported)`);

    if (existingQuestions.length > 0) {
      console.log('\n' + '-'.repeat(60));
      console.log(`🔵 EXISTING QUESTIONS (${existingQuestions.length}) - These were SKIPPED:`);
      console.log('-'.repeat(60));

      // Group by file
      const byFile = new Map();
      for (const q of existingQuestions) {
        if (!byFile.has(q.file)) {
          byFile.set(q.file, []);
        }
        byFile.get(q.file).push(q);
      }

      for (const [fileName, questions] of byFile) {
        console.log(`\n   📄 ${fileName}: ${questions.length} existing`);
        questions.forEach(q => {
          const subject = q.data?.subject || 'Unknown';
          const chapter = q.data?.chapter || 'Unknown';
          console.log(`      • ${q.id} (${subject} - ${chapter})`);
        });
      }
    }

    if (missingQuestions.length > 0) {
      console.log('\n' + '-'.repeat(60));
      console.log(`🆕 NEW QUESTIONS (${missingQuestions.length}) - These WOULD BE imported:`);
      console.log('-'.repeat(60));

      // Group by file
      const byFile = new Map();
      for (const q of missingQuestions) {
        if (!byFile.has(q.file)) {
          byFile.set(q.file, []);
        }
        byFile.get(q.file).push(q.id);
      }

      for (const [fileName, questionIds] of byFile) {
        console.log(`\n   📄 ${fileName}: ${questionIds.length} new`);
        questionIds.slice(0, 10).forEach(id => {
          console.log(`      • ${id}`);
        });
        if (questionIds.length > 10) {
          console.log(`      ... and ${questionIds.length - 10} more`);
        }
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('✅ Check complete!\n');

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

module.exports = { main };
