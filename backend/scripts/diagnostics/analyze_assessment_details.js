const { db } = require("../src/config/firebase");

async function analyze() {
  // Get all assessment questions to see their exact chapter names
  const assessmentSnap = await db.collection("initial_assessment_questions").get();

  console.log("=== ASSESSMENT QUESTIONS DETAILS ===\n");

  const byChapter = new Map();
  assessmentSnap.forEach(doc => {
    const data = doc.data();
    const chapter = data.chapter || "unknown";
    const subject = data.subject || "unknown";
    if (!byChapter.has(chapter)) {
      byChapter.set(chapter, { subject, questions: [] });
    }
    byChapter.get(chapter).questions.push({
      docId: doc.id,
      question_id: data.question_id,
      difficulty: data.difficulty,
      topic: data.topic || (data.tags && data.tags[0]) || "none"
    });
  });

  for (const [chapter, info] of byChapter.entries()) {
    console.log("\n" + chapter + " (" + info.subject + ") - " + info.questions.length + " questions:");
    info.questions.forEach(q => {
      console.log("  - " + q.question_id + " | diff: " + q.difficulty + " | topic: " + q.topic);
    });
  }

  // Now get unique chapters from daily quiz bank for comparison
  console.log("\n\n=== DAILY QUIZ CHAPTERS BY SUBJECT ===\n");

  const quizSnap = await db.collection("questions").get();
  const quizChapters = new Map();

  quizSnap.forEach(doc => {
    const data = doc.data();
    const chapter = data.chapter || "unknown";
    const subject = data.subject || "unknown";

    if (!quizChapters.has(subject)) {
      quizChapters.set(subject, new Set());
    }
    quizChapters.get(subject).add(chapter);
  });

  for (const [subject, chapters] of quizChapters.entries()) {
    console.log(subject + ":");
    [...chapters].sort().forEach(ch => console.log("  - " + ch));
  }

  process.exit(0);
}

analyze().catch(e => { console.error(e); process.exit(1); });
