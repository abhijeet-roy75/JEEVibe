const { db } = require("../src/config/firebase");
const admin = require("firebase-admin");

async function cleanupDuplicateResponses() {
  // Get user ID from phone
  const authUser = await admin.auth().getUserByPhoneNumber("+14127211768");
  const userId = authUser.uid;

  console.log("User ID:", userId);

  // Get all responses
  const responsesRef = db.collection("assessment_responses").doc(userId).collection("responses");
  const responsesSnap = await responsesRef.get();

  console.log("Total responses before cleanup:", responsesSnap.size);

  if (responsesSnap.size <= 30) {
    console.log("No cleanup needed - 30 or fewer responses");
    process.exit(0);
  }

  // Group by question_id, keep only the latest one
  const responsesByQuestion = new Map();

  responsesSnap.forEach(doc => {
    const data = doc.data();
    const qId = data.question_id;
    const timestamp = data.answered_at || data.created_at || "1970-01-01";

    if (!responsesByQuestion.has(qId)) {
      responsesByQuestion.set(qId, []);
    }
    responsesByQuestion.get(qId).push({ docId: doc.id, timestamp, data });
  });

  // Find duplicates to delete (keep the latest for each question)
  const toDelete = [];

  for (const [qId, responses] of responsesByQuestion.entries()) {
    if (responses.length > 1) {
      // Sort by timestamp descending, keep the first (latest)
      responses.sort((a, b) => String(b.timestamp).localeCompare(String(a.timestamp)));
      // Mark all but the first for deletion
      for (let i = 1; i < responses.length; i++) {
        toDelete.push(responses[i].docId);
      }
      console.log(`Question ${qId}: keeping 1, deleting ${responses.length - 1}`);
    }
  }

  console.log("\nTotal responses to delete:", toDelete.length);

  if (toDelete.length > 0) {
    // Delete in batches
    const batchSize = 500;
    for (let i = 0; i < toDelete.length; i += batchSize) {
      const batch = db.batch();
      const chunk = toDelete.slice(i, i + batchSize);
      chunk.forEach(docId => {
        batch.delete(responsesRef.doc(docId));
      });
      await batch.commit();
      console.log(`Deleted batch ${Math.floor(i / batchSize) + 1}`);
    }
    console.log("Cleanup complete!");
  }

  // Verify
  const finalSnap = await responsesRef.get();
  console.log("Total responses after cleanup:", finalSnap.size);

  process.exit(0);
}

cleanupDuplicateResponses().catch(e => { console.error(e); process.exit(1); });
