const { db } = require("../src/config/firebase");

// Mapping from broad assessment categories to specific daily quiz chapters
const CHAPTER_MAPPING = {
  // Chemistry - map to representative chapters with good question counts
  "Inorganic Chemistry": "p-Block Elements",           // 55 questions
  "Organic Chemistry": "General Organic Chemistry",    // 50 questions
  "Physical Chemistry": "Equilibrium",                 // 55 questions

  // Mathematics - map to representative chapters
  "Algebra": "Complex Numbers",                        // 50 questions
  "Calculus": "Limits, Continuity & Differentiability", // 50 questions
  "Coordinate Geometry": "Straight Lines",             // 35 questions

  // Physics - map to representative chapters
  "Magnetism": "Magnetic Effects & Magnetism",         // 49 questions
  "Mechanics": "Kinematics",                           // 61 questions
  "Modern Physics": "Atoms & Nuclei",                  // 40 questions

  // These already match - no change needed
  "Current Electricity": "Current Electricity",
  "Electrostatics": "Electrostatics",
  "Electromagnetic Induction": "Electromagnetic Induction"
};

async function updateAssessmentChapters(dryRun = true) {
  console.log(dryRun ? "=== DRY RUN MODE ===" : "=== UPDATING DATABASE ===");
  console.log("");

  const assessmentSnap = await db.collection("initial_assessment_questions").get();

  console.log("Total assessment questions:", assessmentSnap.size);
  console.log("");

  const updates = [];

  assessmentSnap.forEach(doc => {
    const data = doc.data();
    const currentChapter = data.chapter;
    const newChapter = CHAPTER_MAPPING[currentChapter];

    if (newChapter && newChapter !== currentChapter) {
      updates.push({
        docId: doc.id,
        questionId: data.question_id,
        oldChapter: currentChapter,
        newChapter: newChapter
      });
    }
  });

  if (updates.length === 0) {
    console.log("No updates needed - all chapters already match.");
    process.exit(0);
  }

  console.log("Updates to make:");
  updates.forEach(u => {
    console.log(`  ${u.questionId}: "${u.oldChapter}" -> "${u.newChapter}"`);
  });
  console.log("");
  console.log("Total updates:", updates.length);

  if (!dryRun) {
    console.log("\nApplying updates...");

    const batch = db.batch();
    updates.forEach(u => {
      const docRef = db.collection("initial_assessment_questions").doc(u.docId);
      batch.update(docRef, { chapter: u.newChapter });
    });

    await batch.commit();
    console.log("Updates applied successfully!");
  } else {
    console.log("\nThis was a dry run. Run with 'node update_assessment_chapters.js --apply' to apply changes.");
  }

  process.exit(0);
}

// Check for --apply flag
const applyMode = process.argv.includes("--apply");
updateAssessmentChapters(!applyMode).catch(e => { console.error(e); process.exit(1); });
