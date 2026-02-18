/**
 * Cognitive Mastery Data Upload Script
 *
 * Uploads atlas nodes, capsules, retrieval pools, retrieval questions,
 * and micro-skill maps from a data folder into Firestore.
 *
 * Generic — works for any chapter. Run once per data folder drop from product team.
 * Idempotent: re-running overwrites with latest data (safe to re-run).
 *
 * File naming conventions detected automatically:
 *   atlas_nodes_{chapter}.json          → atlas_nodes collection
 *   CAP_{id}.json                       → capsules collection
 *   RQ_{id}.json                        → retrieval_questions collection (individual files)
 *   {chapter}_pools_v*.json             → retrieval_pools collection
 *   {chapter}_micro_skill_map_*.json    → atlas_micro_skills collection
 *   {chapter}_remediation_questions_*.json → retrieval_questions collection (bulk file)
 *
 * Usage:
 *   node scripts/upload-cognitive-mastery.js
 *   node scripts/upload-cognitive-mastery.js --dir inputs/cognitive_mastery/data2
 *   node scripts/upload-cognitive-mastery.js --dry-run
 */

const path = require('path');
const fs = require('fs');
const { db } = require('../../src/config/firebase');

// ============================================================================
// CONFIGURATION
// ============================================================================

const DEFAULT_DATA_DIR = path.join(__dirname, '../../../inputs/cognitive_mastery/data1');
const BATCH_SIZE = 500;

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const dirArg = args.find(a => a.startsWith('--dir'));
const DATA_DIR = dirArg ? path.resolve(dirArg.split('=')[1] || args[args.indexOf(dirArg) + 1]) : DEFAULT_DATA_DIR;

// ============================================================================
// HELPERS
// ============================================================================

function loadJson(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  return JSON.parse(raw);
}

function log(msg) {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}

async function batchWrite(collection, docs) {
  if (DRY_RUN) {
    log(`  [DRY RUN] Would write ${docs.length} docs to ${collection}`);
    return;
  }
  let written = 0;
  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const chunk = docs.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const { id, data } of chunk) {
      const ref = db.collection(collection).doc(id);
      batch.set(ref, { ...data, uploaded_at: new Date().toISOString() }, { merge: true });
    }
    await batch.commit();
    written += chunk.length;
  }
  log(`  ✅ Wrote ${written} docs to ${collection}`);
}

// ============================================================================
// UPLOADERS — one per file type
// ============================================================================

async function uploadAtlasNodes(filePath) {
  const data = loadJson(filePath);
  const nodes = data.atlas_nodes || [];
  log(`Atlas nodes: ${nodes.length} nodes from ${path.basename(filePath)}`);

  const docs = nodes.map(node => ({
    id: node.atlas_node_id,
    data: node,
  }));
  await batchWrite('atlas_nodes', docs);
}

async function uploadCapsule(filePath) {
  const data = loadJson(filePath);
  const id = data.capsule_id;
  if (!id) {
    log(`  ⚠️  Skipping ${path.basename(filePath)} — no capsule_id field`);
    return;
  }
  log(`Capsule: ${id}`);
  await batchWrite('capsules', [{ id, data }]);
}

async function uploadPools(filePath) {
  const data = loadJson(filePath);
  const pools = data.pools || [];
  log(`Retrieval pools: ${pools.length} pools from ${path.basename(filePath)}`);

  const docs = pools.map(pool => ({
    id: pool.pool_id,
    data: pool,
  }));
  await batchWrite('retrieval_pools', docs);
}

async function uploadMicroSkillMap(filePath) {
  const data = loadJson(filePath);
  const skills = data.micro_skills || [];
  const chapterKey = deriveChapterKey(data.subject, data.chapter);
  log(`Micro-skills: ${skills.length} skills for ${chapterKey}`);

  // Store the full map as a single doc keyed by chapter
  // Also build question_to_skill_map from the file if present
  const questionToSkillMap = data.question_to_micro_skill_map || {};

  // Write micro_skills as individual docs
  const skillDocs = skills.map(skill => ({
    id: skill.micro_skill_id,
    data: { ...skill, chapter_key: chapterKey },
  }));
  await batchWrite('atlas_micro_skills', skillDocs);

  // Write question→skill map as a single doc per chapter
  if (Object.keys(questionToSkillMap).length > 0) {
    log(`Question-skill map: ${Object.keys(questionToSkillMap).length} questions for ${chapterKey}`);
    if (!DRY_RUN) {
      await db.collection('atlas_question_skill_map').doc(chapterKey).set(
        { chapter_key: chapterKey, map: questionToSkillMap, uploaded_at: new Date().toISOString() },
        { merge: true }
      );
      log(`  ✅ Wrote question-skill map for ${chapterKey}`);
    } else {
      log(`  [DRY RUN] Would write question-skill map for ${chapterKey}`);
    }
  }
}

async function uploadRemediationQuestions(filePath) {
  const data = loadJson(filePath);
  // Bulk file: { remediation_questions: [...] }
  const questions = data.remediation_questions || [];
  log(`Remediation questions (bulk): ${questions.length} from ${path.basename(filePath)}`);

  const docs = questions.map(q => ({
    id: q.question_id,
    data: q,
  }));
  await batchWrite('retrieval_questions', docs);
}

async function uploadRetrievalQuestionFile(filePath) {
  const data = loadJson(filePath);
  // Individual RQ file: top-level array
  const questions = Array.isArray(data) ? data : [data];
  log(`Retrieval questions (RQ file): ${questions.length} from ${path.basename(filePath)}`);

  const docs = questions.map(q => ({
    id: q.question_id,
    data: q,
  }));
  await batchWrite('retrieval_questions', docs);
}

// ============================================================================
// CHAPTER KEY DERIVATION
// ============================================================================

function deriveChapterKey(subject, chapter) {
  if (!subject || !chapter) return 'unknown';
  return `${subject.toLowerCase().replace(/\s+/g, '_')}_${chapter.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '')}`;
}

// ============================================================================
// FILE ROUTING — detect file type by name pattern
// ============================================================================

function routeFile(fileName) {
  if (fileName.startsWith('atlas_nodes_')) return 'atlas_nodes';
  if (fileName.startsWith('CAP_')) return 'capsule';
  if (fileName.startsWith('RQ_')) return 'rq_file';
  if (fileName.includes('_pools_')) return 'pools';
  if (fileName.includes('_micro_skill_map_')) return 'micro_skill_map';
  if (fileName.includes('_remediation_questions_')) return 'remediation_questions';
  return null;
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  log(`=== Cognitive Mastery Upload ===`);
  log(`Data dir: ${DATA_DIR}`);
  if (DRY_RUN) log(`DRY RUN — no Firestore writes`);

  if (!fs.existsSync(DATA_DIR)) {
    console.error(`❌ Directory not found: ${DATA_DIR}`);
    process.exit(1);
  }

  const files = fs.readdirSync(DATA_DIR)
    .filter(f => f.endsWith('.json'))
    .sort(); // deterministic order

  log(`Found ${files.length} JSON files\n`);

  const stats = { atlas_nodes: 0, capsules: 0, pools: 0, micro_skills: 0, rq_files: 0, remediation: 0, skipped: 0 };

  for (const fileName of files) {
    const filePath = path.join(DATA_DIR, fileName);
    const type = routeFile(fileName);

    if (!type) {
      log(`⚠️  Skipping unrecognized file: ${fileName}`);
      stats.skipped++;
      continue;
    }

    try {
      switch (type) {
        case 'atlas_nodes':
          await uploadAtlasNodes(filePath);
          stats.atlas_nodes++;
          break;
        case 'capsule':
          await uploadCapsule(filePath);
          stats.capsules++;
          break;
        case 'rq_file':
          await uploadRetrievalQuestionFile(filePath);
          stats.rq_files++;
          break;
        case 'pools':
          await uploadPools(filePath);
          stats.pools++;
          break;
        case 'micro_skill_map':
          await uploadMicroSkillMap(filePath);
          stats.micro_skills++;
          break;
        case 'remediation_questions':
          await uploadRemediationQuestions(filePath);
          stats.remediation++;
          break;
      }
    } catch (err) {
      log(`❌ Error processing ${fileName}: ${err.message}`);
      console.error(err);
    }
  }

  log(`\n=== Summary ===`);
  log(`Atlas node files:         ${stats.atlas_nodes}`);
  log(`Capsule files:            ${stats.capsules}`);
  log(`Pool files:               ${stats.pools}`);
  log(`Micro-skill map files:    ${stats.micro_skills}`);
  log(`RQ files (individual):    ${stats.rq_files}`);
  log(`Remediation bulk files:   ${stats.remediation}`);
  log(`Skipped (unrecognized):   ${stats.skipped}`);
  log(DRY_RUN ? '\n✅ Dry run complete — no Firestore changes made' : '\n✅ Upload complete');
  process.exit(0);
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
