/**
 * Tag Chapter Practice Questions with Micro-Skill IDs
 *
 * Reads question_to_micro_skill_map from atlas_question_skill_map collection
 * (populated by upload-cognitive-mastery.js) and writes micro_skill_ids
 * onto the matching documents in the questions collection.
 *
 * Idempotent: safe to re-run. Only writes when micro_skill_ids differs.
 *
 * Usage:
 *   node scripts/tag-questions-micro-skills.js
 *   node scripts/tag-questions-micro-skills.js --chapter physics_electrostatics
 *   node scripts/tag-questions-micro-skills.js --dry-run
 */

const { db } = require('../src/config/firebase');

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const chapterArg = args.find(a => a.startsWith('--chapter'));
const TARGET_CHAPTER = chapterArg ? (chapterArg.split('=')[1] || args[args.indexOf(chapterArg) + 1]) : null;

function log(msg) {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}

async function main() {
  log('=== Tag Questions with Micro-Skill IDs ===');
  if (DRY_RUN) log('DRY RUN — no Firestore writes');
  if (TARGET_CHAPTER) log(`Targeting chapter: ${TARGET_CHAPTER}`);

  // 1. Load all question-skill maps from Firestore
  let mapsQuery = db.collection('atlas_question_skill_map');
  if (TARGET_CHAPTER) mapsQuery = mapsQuery.where('chapter_key', '==', TARGET_CHAPTER);

  const mapsSnapshot = await mapsQuery.get();
  if (mapsSnapshot.empty) {
    log('❌ No question-skill maps found. Run upload-cognitive-mastery.js first.');
    process.exit(1);
  }

  log(`Found ${mapsSnapshot.size} chapter map(s)`);

  let totalTagged = 0;
  let totalSkipped = 0;
  let totalNotFound = 0;

  for (const mapDoc of mapsSnapshot.docs) {
    const { chapter_key, map: questionSkillMap } = mapDoc.data();
    const questionIds = Object.keys(questionSkillMap || {});
    log(`\nChapter: ${chapter_key} — ${questionIds.length} questions to tag`);

    // 2. Fetch those questions from Firestore in batches of 30 (Firestore 'in' limit)
    const CHUNK_SIZE = 30;
    for (let i = 0; i < questionIds.length; i += CHUNK_SIZE) {
      const chunk = questionIds.slice(i, i + CHUNK_SIZE);
      const snapshot = await db.collection('questions')
        .where('question_id', 'in', chunk)
        .get();

      const foundIds = new Set(snapshot.docs.map(d => d.data().question_id));

      // Report missing questions
      for (const qId of chunk) {
        if (!foundIds.has(qId)) {
          log(`  ⚠️  Not found in questions collection: ${qId}`);
          totalNotFound++;
        }
      }

      // 3. Write micro_skill_ids to each found question
      if (!DRY_RUN && !snapshot.empty) {
        const batch = db.batch();
        let batchCount = 0;

        for (const doc of snapshot.docs) {
          const existing = doc.data();
          const newSkillIds = questionSkillMap[existing.question_id] || [];
          const existingSkillIds = existing.micro_skill_ids || [];

          // Skip if already tagged with same skills
          const same = existingSkillIds.length === newSkillIds.length &&
            newSkillIds.every(id => existingSkillIds.includes(id));

          if (same) {
            totalSkipped++;
            continue;
          }

          batch.update(doc.ref, {
            micro_skill_ids: newSkillIds,
            micro_skills_tagged_at: new Date().toISOString(),
          });
          batchCount++;
          totalTagged++;
        }

        if (batchCount > 0) await batch.commit();
        log(`  Tagged: ${batchCount}, Skipped (already tagged): ${snapshot.size - batchCount - (chunk.length - foundIds.size)}`);
      } else if (DRY_RUN) {
        for (const doc of snapshot.docs) {
          const existing = doc.data();
          const newSkillIds = questionSkillMap[existing.question_id] || [];
          log(`  [DRY RUN] Would tag ${existing.question_id} with: ${newSkillIds.join(', ')}`);
          totalTagged++;
        }
      }
    }
  }

  log(`\n=== Summary ===`);
  log(`Questions tagged:      ${totalTagged}`);
  log(`Questions skipped:     ${totalSkipped} (already had correct micro_skill_ids)`);
  log(`Questions not found:   ${totalNotFound} (in map but not in questions collection)`);
  log(DRY_RUN ? '\n✅ Dry run complete — no Firestore changes made' : '\n✅ Tagging complete');
  process.exit(0);
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
