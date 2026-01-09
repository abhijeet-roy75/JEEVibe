const { db } = require("../src/config/firebase");

async function analyzeQuestionCoverage() {
  console.log("=== QUESTION BANK COVERAGE ANALYSIS ===\n");

  // Get all questions from question bank
  const questionsSnap = await db.collection("questions").get();
  console.log("Total questions in bank:", questionsSnap.size);

  // Group by chapter and subject
  const chapterCounts = new Map();
  const subjectCounts = new Map();
  const chapterBySubject = new Map();

  questionsSnap.forEach(doc => {
    const data = doc.data();
    const chapter = data.chapter || "unknown";
    const subject = data.subject || "unknown";

    // Count by chapter
    chapterCounts.set(chapter, (chapterCounts.get(chapter) || 0) + 1);

    // Count by subject
    subjectCounts.set(subject, (subjectCounts.get(subject) || 0) + 1);

    // Track chapter-subject mapping
    if (!chapterBySubject.has(chapter)) {
      chapterBySubject.set(chapter, subject);
    }
  });

  // Sort chapters by count (ascending - lowest first)
  const sortedChapters = [...chapterCounts.entries()].sort((a, b) => a[1] - b[1]);

  console.log("\n=== CHAPTERS WITH INSUFFICIENT QUESTIONS (< 20) ===\n");
  const insufficientChapters = sortedChapters.filter(([_, count]) => count < 20);

  if (insufficientChapters.length === 0) {
    console.log("All chapters have 20+ questions!");
  } else {
    console.log("Chapter | Subject | Count | Needed");
    console.log("-".repeat(80));
    insufficientChapters.forEach(([chapter, count]) => {
      const subject = chapterBySubject.get(chapter) || "unknown";
      const needed = 20 - count;
      console.log(`${chapter} | ${subject} | ${count} | +${needed} needed`);
    });
  }

  console.log("\n=== CHAPTERS WITH 0 QUESTIONS ===\n");
  const emptyChapters = sortedChapters.filter(([_, count]) => count === 0);
  if (emptyChapters.length === 0) {
    console.log("No empty chapters found in question bank.");
  } else {
    emptyChapters.forEach(([chapter]) => {
      console.log(`- ${chapter}`);
    });
  }

  console.log("\n=== QUESTIONS BY SUBJECT ===\n");
  for (const [subject, count] of subjectCounts.entries()) {
    console.log(`${subject}: ${count} questions`);
  }

  console.log("\n=== ALL CHAPTERS (sorted by count) ===\n");
  console.log("Chapter | Subject | Count");
  console.log("-".repeat(80));
  sortedChapters.forEach(([chapter, count]) => {
    const subject = chapterBySubject.get(chapter) || "unknown";
    const status = count < 10 ? " ⚠️ CRITICAL" : count < 20 ? " ⚡ LOW" : "";
    console.log(`${chapter} | ${subject} | ${count}${status}`);
  });

  // Also check initial_assessment_questions
  console.log("\n\n=== INITIAL ASSESSMENT QUESTIONS ===\n");
  const assessmentSnap = await db.collection("initial_assessment_questions").get();
  console.log("Total assessment questions:", assessmentSnap.size);

  const assessmentChapters = new Map();
  assessmentSnap.forEach(doc => {
    const data = doc.data();
    const chapter = data.chapter || "unknown";
    assessmentChapters.set(chapter, (assessmentChapters.get(chapter) || 0) + 1);
  });

  const sortedAssessment = [...assessmentChapters.entries()].sort((a, b) => a[1] - b[1]);
  console.log("\nChapter | Count");
  console.log("-".repeat(60));
  sortedAssessment.forEach(([chapter, count]) => {
    const status = count < 5 ? " ⚠️ CRITICAL" : count < 10 ? " ⚡ LOW" : "";
    console.log(`${chapter} | ${count}${status}`);
  });

  // Check which chapters from user's assessment are missing from question bank
  console.log("\n\n=== COVERAGE CHECK ===\n");
  console.log("Checking if all chapters tested in assessments have questions in the daily quiz bank...\n");

  const missingInQuestionBank = [];
  for (const [chapter] of assessmentChapters.entries()) {
    if (!chapterCounts.has(chapter) || chapterCounts.get(chapter) === 0) {
      missingInQuestionBank.push(chapter);
    }
  }

  if (missingInQuestionBank.length > 0) {
    console.log("⚠️ CHAPTERS TESTED IN ASSESSMENT BUT MISSING FROM DAILY QUIZ BANK:");
    missingInQuestionBank.forEach(ch => console.log(`  - ${ch}`));
  } else {
    console.log("✅ All assessment chapters have questions in the daily quiz bank.");
  }

  process.exit(0);
}

analyzeQuestionCoverage().catch(e => { console.error(e); process.exit(1); });
