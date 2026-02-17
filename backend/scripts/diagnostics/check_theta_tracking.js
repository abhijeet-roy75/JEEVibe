const { db } = require("../src/config/firebase");
const admin = require("firebase-admin");

async function checkThetaTracking(phoneNumber) {
  const authUser = await admin.auth().getUserByPhoneNumber(phoneNumber);
  const userId = authUser.uid;

  const userDoc = await db.collection("users").doc(userId).get();
  const userData = userDoc.data();

  console.log("=== BASELINE THETA (from initial assessment) ===\n");

  const baseline = userData.assessment_baseline || {};
  console.log("Captured At:", baseline.captured_at || "N/A");
  console.log("Overall Theta:", baseline.overall_theta?.toFixed(3) || "N/A");
  console.log("Overall Percentile:", baseline.overall_percentile?.toFixed(1) || "N/A");

  console.log("\nBaseline Chapter Thetas:");
  const baselineChapters = baseline.theta_by_chapter || {};
  Object.entries(baselineChapters)
    .sort((a, b) => (a[1].theta || 0) - (b[1].theta || 0))
    .forEach(([key, data]) => {
      console.log(`  ${key}: theta=${data.theta?.toFixed(2)}, percentile=${data.percentile?.toFixed(0)}%`);
    });

  console.log("\n=== CURRENT THETA (after daily quizzes) ===\n");
  console.log("Overall Theta:", userData.overall_theta?.toFixed(3) || "N/A");
  console.log("Overall Percentile:", userData.overall_percentile?.toFixed(1) || "N/A");

  console.log("\nCurrent Chapter Thetas:");
  const currentChapters = userData.theta_by_chapter || {};
  Object.entries(currentChapters)
    .sort((a, b) => (a[1].theta || 0) - (b[1].theta || 0))
    .forEach(([key, data]) => {
      console.log(`  ${key}: theta=${data.theta?.toFixed(2)}, percentile=${data.percentile?.toFixed(0)}%`);
    });

  console.log("\n=== THETA CHANGES (Current - Baseline) ===\n");

  const overallChange = (userData.overall_theta || 0) - (baseline.overall_theta || 0);
  console.log(`Overall Theta Change: ${overallChange >= 0 ? '+' : ''}${overallChange.toFixed(3)}`);

  console.log("\nChapter Changes:");
  const allChapters = new Set([
    ...Object.keys(baselineChapters),
    ...Object.keys(currentChapters)
  ]);

  const changes = [];
  for (const chapter of allChapters) {
    const baselineTheta = baselineChapters[chapter]?.theta || 0;
    const currentTheta = currentChapters[chapter]?.theta || 0;
    const change = currentTheta - baselineTheta;
    changes.push({ chapter, baselineTheta, currentTheta, change });
  }

  changes.sort((a, b) => a.change - b.change);

  console.log("\nDeclines (negative change):");
  changes.filter(c => c.change < -0.01).forEach(c => {
    console.log(`  ${c.chapter}: ${c.baselineTheta.toFixed(2)} -> ${c.currentTheta.toFixed(2)} (${c.change.toFixed(2)})`);
  });

  console.log("\nNo Change:");
  changes.filter(c => Math.abs(c.change) <= 0.01).forEach(c => {
    console.log(`  ${c.chapter}: ${c.baselineTheta.toFixed(2)} -> ${c.currentTheta.toFixed(2)}`);
  });

  console.log("\nImprovements (positive change):");
  changes.filter(c => c.change > 0.01).forEach(c => {
    console.log(`  ${c.chapter}: ${c.baselineTheta.toFixed(2)} -> ${c.currentTheta.toFixed(2)} (+${c.change.toFixed(2)})`);
  });

  console.log("\n=== THETA HISTORY TRACKING ===\n");

  // Check if we have a theta_history collection
  const thetaHistoryRef = db.collection("theta_history").doc(userId).collection("snapshots");
  const historySnap = await thetaHistoryRef.orderBy("captured_at", "desc").limit(10).get();

  if (historySnap.empty) {
    console.log("NO THETA HISTORY COLLECTION FOUND");
    console.log("Currently, we only track:");
    console.log("  1. assessment_baseline - snapshot at assessment completion");
    console.log("  2. theta_by_chapter - current values (overwritten on each quiz)");
    console.log("\nWe do NOT track historical theta values over time.");
  } else {
    console.log("Theta History Snapshots:");
    historySnap.docs.forEach(doc => {
      const data = doc.data();
      console.log(`  ${data.captured_at}: overall_theta=${data.overall_theta?.toFixed(3)}`);
    });
  }

  process.exit(0);
}

const phoneNumber = process.argv[2] || "+14127211768";
checkThetaTracking(phoneNumber).catch(e => { console.error(e); process.exit(1); });
