const { db } = require("../src/config/firebase");

async function checkDuplicates() {
  const snapshot = await db.collection("initial_assessment_questions").get();

  const questionIds = new Map();

  snapshot.forEach(doc => {
    const data = doc.data();
    const qId = data.question_id || doc.id;

    if (!questionIds.has(qId)) {
      questionIds.set(qId, []);
    }
    questionIds.get(qId).push(doc.id);
  });

  console.log("Total documents:", snapshot.size);
  console.log("Unique question_ids:", questionIds.size);

  const duplicates = [];
  for (const [qId, docIds] of questionIds.entries()) {
    if (docIds.length > 1) {
      duplicates.push({ question_id: qId, doc_ids: docIds, count: docIds.length });
    }
  }

  if (duplicates.length > 0) {
    console.log("\n=== DUPLICATES FOUND ===");
    duplicates.forEach(d => {
      console.log(d.question_id + ": " + d.count + " copies");
      console.log("  Doc IDs: " + d.doc_ids.join(", "));
    });
  } else {
    console.log("\nNo duplicates found in database.");
  }

  process.exit(0);
}

checkDuplicates().catch(e => { console.error(e); process.exit(1); });
