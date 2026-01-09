const { db } = require("../src/config/firebase");
const admin = require("firebase-admin");

async function getUserFullData(phoneNumber) {
  console.log("=".repeat(80));
  console.log("FULL USER DATA REPORT");
  console.log("Phone:", phoneNumber);
  console.log("Generated:", new Date().toISOString());
  console.log("=".repeat(80));

  // Get user ID from phone
  const authUser = await admin.auth().getUserByPhoneNumber(phoneNumber);
  const userId = authUser.uid;

  console.log("\n## 1. AUTH INFO");
  console.log("-".repeat(40));
  console.log("User ID:", userId);
  console.log("Phone:", authUser.phoneNumber);
  console.log("Created:", authUser.metadata.creationTime);
  console.log("Last Sign In:", authUser.metadata.lastSignInTime);

  // Get user profile
  const userDoc = await db.collection("users").doc(userId).get();
  const userData = userDoc.data();

  if (!userData) {
    console.log("\nERROR: User profile not found in Firestore");
    process.exit(1);
  }

  console.log("\n## 2. USER PROFILE");
  console.log("-".repeat(40));
  console.log("Name:", userData.name || "Not set");
  console.log("Email:", userData.email || "Not set");
  console.log("Target Exam:", userData.target_exam || "Not set");
  console.log("Exam Year:", userData.exam_year || "Not set");
  console.log("Created At:", userData.created_at || "Not set");

  console.log("\n## 3. ASSESSMENT STATUS");
  console.log("-".repeat(40));
  console.log("Status:", userData.assessment?.status || "not_started");
  console.log("Completed At:", userData.assessment?.completed_at || "N/A");
  console.log("Time Taken (sec):", userData.assessment?.time_taken_seconds || 0);

  console.log("\n## 4. OVERALL METRICS");
  console.log("-".repeat(40));
  console.log("Overall Theta:", userData.overall_theta?.toFixed(3) || "N/A");
  console.log("Overall Percentile:", userData.overall_percentile?.toFixed(1) || "N/A");
  console.log("Completed Quiz Count:", userData.completed_quiz_count || 0);
  console.log("Current Day:", userData.current_day || 0);
  console.log("Learning Phase:", userData.learning_phase || "N/A");
  console.log("Total Questions Solved:", userData.total_questions_solved || 0);
  console.log("Total Time Spent (min):", userData.total_time_spent_minutes || 0);

  console.log("\n## 5. SUBJECT-LEVEL THETA");
  console.log("-".repeat(40));
  const subjects = userData.theta_by_subject || {};
  for (const [subject, data] of Object.entries(subjects)) {
    console.log(`${subject}:`);
    console.log(`  Theta: ${data.theta?.toFixed(3) || "N/A"}`);
    console.log(`  Percentile: ${data.percentile?.toFixed(1) || "N/A"}`);
    console.log(`  Chapters Tested: ${data.chapters_tested || 0}`);
  }

  console.log("\n## 6. SUBJECT ACCURACY");
  console.log("-".repeat(40));
  const subjectAccuracy = userData.subject_accuracy || {};
  for (const [subject, data] of Object.entries(subjectAccuracy)) {
    console.log(`${subject}: ${data.correct || 0}/${data.total || 0} = ${data.accuracy || 0}%`);
  }

  console.log("\n## 7. CHAPTER-LEVEL THETA (sorted by theta, ascending = weakest first)");
  console.log("-".repeat(40));
  const chapters = userData.theta_by_chapter || {};
  const sortedChapters = Object.entries(chapters)
    .sort((a, b) => (a[1].theta || 0) - (b[1].theta || 0));

  console.log("Chapter | Theta | Percentile | Attempts | Accuracy");
  for (const [key, data] of sortedChapters) {
    const theta = data.theta?.toFixed(2) || "N/A";
    const percentile = data.percentile?.toFixed(0) || "N/A";
    const attempts = data.attempts || 0;
    const accuracy = ((data.accuracy || 0) * 100).toFixed(0);
    console.log(`${key} | ${theta} | ${percentile}% | ${attempts} | ${accuracy}%`);
  }

  console.log("\n## 8. ASSESSMENT BASELINE (snapshot at assessment completion)");
  console.log("-".repeat(40));
  const baseline = userData.assessment_baseline || {};
  console.log("Captured At:", baseline.captured_at || "N/A");
  console.log("Baseline Overall Theta:", baseline.overall_theta?.toFixed(3) || "N/A");
  console.log("Baseline Chapters:", Object.keys(baseline.theta_by_chapter || {}).length);

  console.log("\n## 9. ASSESSMENT RESPONSES");
  console.log("-".repeat(40));
  const assessmentResponsesSnap = await db
    .collection("assessment_responses")
    .doc(userId)
    .collection("responses")
    .get();

  console.log("Total Responses:", assessmentResponsesSnap.size);

  if (assessmentResponsesSnap.size > 0) {
    let correct = 0;
    let total = 0;
    const bySubject = { physics: { c: 0, t: 0 }, chemistry: { c: 0, t: 0 }, mathematics: { c: 0, t: 0 } };

    assessmentResponsesSnap.docs.forEach(doc => {
      const data = doc.data();
      total++;
      if (data.is_correct) correct++;

      const subject = (data.subject || "").toLowerCase();
      if (bySubject[subject]) {
        bySubject[subject].t++;
        if (data.is_correct) bySubject[subject].c++;
      }
    });

    console.log(`Accuracy: ${correct}/${total} = ${((correct/total)*100).toFixed(1)}%`);
    console.log("By Subject:");
    for (const [subject, data] of Object.entries(bySubject)) {
      if (data.t > 0) {
        console.log(`  ${subject}: ${data.c}/${data.t} = ${((data.c/data.t)*100).toFixed(1)}%`);
      }
    }
  }

  console.log("\n## 10. DAILY QUIZZES");
  console.log("-".repeat(40));
  const quizzesSnap = await db
    .collection("daily_quizzes")
    .doc(userId)
    .collection("quizzes")
    .orderBy("generated_at", "desc")
    .get();

  console.log("Total Quizzes:", quizzesSnap.size);

  if (quizzesSnap.size > 0) {
    console.log("\nQuiz | Status | Score | Accuracy | Time(s) | Phase | Completed At");
    console.log("-".repeat(80));

    quizzesSnap.docs.forEach(doc => {
      const data = doc.data();
      const quizNum = data.quiz_number || "?";
      const status = data.status || "unknown";
      const score = data.score || 0;
      const total = data.total_questions || 0;
      const accuracy = data.accuracy ? (data.accuracy * 100).toFixed(0) : "N/A";
      const time = data.total_time_seconds || 0;
      const phase = data.learning_phase || "N/A";
      const completed = data.completed_at?.toDate?.()?.toISOString()?.split("T")[0] || "N/A";

      console.log(`#${quizNum} | ${status} | ${score}/${total} | ${accuracy}% | ${time}s | ${phase} | ${completed}`);
    });
  }

  console.log("\n## 11. DAILY QUIZ RESPONSES (last 30 days)");
  console.log("-".repeat(40));
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - 30);

  const quizResponsesSnap = await db
    .collection("daily_quiz_responses")
    .doc(userId)
    .collection("responses")
    .where("answered_at", ">=", admin.firestore.Timestamp.fromDate(cutoffDate))
    .get();

  console.log("Responses (last 30 days):", quizResponsesSnap.size);

  if (quizResponsesSnap.size > 0) {
    let correct = 0;
    const byChapter = {};

    quizResponsesSnap.docs.forEach(doc => {
      const data = doc.data();
      if (data.is_correct) correct++;

      const chapter = data.chapter_key || "unknown";
      if (!byChapter[chapter]) {
        byChapter[chapter] = { c: 0, t: 0 };
      }
      byChapter[chapter].t++;
      if (data.is_correct) byChapter[chapter].c++;
    });

    console.log(`Overall Accuracy: ${correct}/${quizResponsesSnap.size} = ${((correct/quizResponsesSnap.size)*100).toFixed(1)}%`);
    console.log("\nBy Chapter:");
    Object.entries(byChapter)
      .sort((a, b) => b[1].t - a[1].t)
      .slice(0, 10)
      .forEach(([chapter, data]) => {
        console.log(`  ${chapter}: ${data.c}/${data.t} = ${((data.c/data.t)*100).toFixed(0)}%`);
      });
  }

  console.log("\n## 12. SNAP HISTORY");
  console.log("-".repeat(40));
  const snapHistorySnap = await db
    .collection("snap_history")
    .doc(userId)
    .collection("snaps")
    .orderBy("created_at", "desc")
    .limit(20)
    .get();

  console.log("Recent Snaps:", snapHistorySnap.size);

  if (snapHistorySnap.size > 0) {
    let totalSnaps = 0;
    snapHistorySnap.docs.forEach(doc => {
      totalSnaps++;
    });

    // Get today's count
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todaySnaps = snapHistorySnap.docs.filter(doc => {
      const createdAt = doc.data().created_at?.toDate?.();
      return createdAt && createdAt >= today;
    }).length;

    console.log("Snaps Today:", todaySnaps);
    console.log("Last 20 Snaps Retrieved:", totalSnaps);
  }

  console.log("\n## 13. STREAK DATA");
  console.log("-".repeat(40));
  const streakDoc = await db.collection("user_streaks").doc(userId).get();
  const streakData = streakDoc.data();

  if (streakData) {
    console.log("Current Streak:", streakData.current_streak || 0);
    console.log("Longest Streak:", streakData.longest_streak || 0);
    console.log("Last Activity:", streakData.last_activity_date || "N/A");
  } else {
    console.log("No streak data found");
  }

  console.log("\n## 14. CUMULATIVE STATS");
  console.log("-".repeat(40));
  const cumulativeStats = userData.cumulative_stats || {};
  console.log("Total Questions Correct:", cumulativeStats.total_questions_correct || 0);
  console.log("Total Questions Attempted:", cumulativeStats.total_questions_attempted || 0);
  if (cumulativeStats.total_questions_attempted > 0) {
    const overallAcc = (cumulativeStats.total_questions_correct / cumulativeStats.total_questions_attempted * 100).toFixed(1);
    console.log("Cumulative Accuracy:", overallAcc + "%");
  }

  console.log("\n" + "=".repeat(80));
  console.log("END OF REPORT");
  console.log("=".repeat(80));

  process.exit(0);
}

const phoneNumber = process.argv[2] || "+14127211768";
getUserFullData(phoneNumber).catch(e => { console.error(e); process.exit(1); });
