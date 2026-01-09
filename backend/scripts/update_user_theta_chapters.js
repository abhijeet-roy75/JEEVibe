const { db } = require("../src/config/firebase");
const admin = require("firebase-admin");

// Same mapping as assessment questions
const CHAPTER_MAPPING = {
  "Inorganic Chemistry": "p-Block Elements",
  "Organic Chemistry": "General Organic Chemistry",
  "Physical Chemistry": "Equilibrium",
  "Algebra": "Complex Numbers",
  "Calculus": "Limits, Continuity & Differentiability",
  "Coordinate Geometry": "Straight Lines",
  "Magnetism": "Magnetic Effects & Magnetism",
  "Mechanics": "Kinematics",
  "Modern Physics": "Atoms & Nuclei"
};

async function updateUserThetaChapters(phoneNumber) {
  // Get user ID from phone
  const authUser = await admin.auth().getUserByPhoneNumber(phoneNumber);
  const userId = authUser.uid;

  console.log("User ID:", userId);

  // Get user profile
  const userRef = db.collection("users").doc(userId);
  const userDoc = await userRef.get();
  const userData = userDoc.data();

  if (!userData) {
    console.log("User not found");
    process.exit(1);
  }

  // Update theta_by_chapter
  const oldThetas = userData.theta_by_chapter || {};
  const newThetas = {};
  let updatedCount = 0;

  console.log("\n=== THETA_BY_CHAPTER UPDATES ===\n");

  for (const [chapter, data] of Object.entries(oldThetas)) {
    const newChapter = CHAPTER_MAPPING[chapter] || chapter;
    if (newChapter !== chapter) {
      console.log(`"${chapter}" -> "${newChapter}"`);
      updatedCount++;
    }
    newThetas[newChapter] = data;
  }

  // Also update assessment_responses if they exist
  const responsesRef = db.collection("assessment_responses").doc(userId).collection("responses");
  const responsesSnap = await responsesRef.get();

  let responseUpdates = 0;
  const batch = db.batch();

  responsesSnap.forEach(doc => {
    const data = doc.data();
    const oldChapter = data.chapter;
    const newChapter = CHAPTER_MAPPING[oldChapter];

    if (newChapter) {
      batch.update(doc.ref, { chapter: newChapter });
      responseUpdates++;
    }
  });

  console.log("\nTheta chapters to update:", updatedCount);
  console.log("Response chapters to update:", responseUpdates);

  if (updatedCount > 0 || responseUpdates > 0) {
    // Update user document
    await userRef.update({ theta_by_chapter: newThetas });
    console.log("\nUpdated theta_by_chapter");

    // Update responses
    if (responseUpdates > 0) {
      await batch.commit();
      console.log("Updated assessment_responses");
    }

    console.log("\nDone!");
  } else {
    console.log("\nNo updates needed.");
  }

  process.exit(0);
}

const phoneNumber = process.argv[2] || "+14127211768";
updateUserThetaChapters(phoneNumber).catch(e => { console.error(e); process.exit(1); });
