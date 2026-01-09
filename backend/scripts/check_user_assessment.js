const { db } = require("../src/config/firebase");
const admin = require("firebase-admin");

async function checkUserData() {
  // First get user ID from phone
  const authUser = await admin.auth().getUserByPhoneNumber("+14127211768");
  const userId = authUser.uid;

  console.log("=== USER ID ===");
  console.log(userId);

  // Get user profile
  const userDoc = await db.collection("users").doc(userId).get();
  const userData = userDoc.data();

  console.log("\n=== ASSESSMENT STATUS ===");
  console.log("completed_at:", userData?.assessment?.completed_at);

  console.log("\n=== OVERALL THETA ===");
  console.log("overall_theta:", userData?.overall_theta);
  console.log("overall_percentile:", userData?.overall_percentile);

  console.log("\n=== SUBJECT THETAS ===");
  const subjects = userData?.theta_by_subject || {};
  for (const [subject, data] of Object.entries(subjects)) {
    console.log(subject + ":", "theta=" + data?.theta, "percentile=" + data?.percentile, "chapters_tested=" + data?.chapters_tested);
  }

  console.log("\n=== CHAPTER THETAS ===");
  const chapters = userData?.theta_by_chapter || {};
  console.log("Total chapters:", Object.keys(chapters).length);
  for (const [key, data] of Object.entries(chapters)) {
    console.log(key + ":", "theta=" + data?.theta, "attempts=" + data?.attempts, "accuracy=" + data?.accuracy);
  }

  console.log("\n=== ASSESSMENT BASELINE ===");
  const baseline = userData?.assessment_baseline || {};
  console.log("Has baseline:", Object.keys(baseline).length > 0);
  console.log("Baseline chapters:", Object.keys(baseline.theta_by_chapter || {}).length);

  console.log("\n=== ASSESSMENT RESPONSES ===");
  const responsesSnap = await db.collection("assessment_responses").doc(userId).collection("responses").get();
  console.log("Total responses:", responsesSnap.size);

  // Show sample response
  if (responsesSnap.size > 0) {
    const sample = responsesSnap.docs[0].data();
    console.log("\nSample response:");
    console.log("  question_id:", sample.question_id);
    console.log("  is_correct:", sample.is_correct);
    console.log("  subject:", sample.subject);
    console.log("  chapter:", sample.chapter);
  }

  process.exit(0);
}

checkUserData().catch(e => { console.error(e); process.exit(1); });
