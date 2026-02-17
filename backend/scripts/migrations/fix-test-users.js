/**
 * Fix test users - ensure currentClass is string and all required fields exist
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function fixUsers() {
  try {
    const phones = ['+16505551234', '+14125965484'];

    for (const phone of phones) {
      console.log(`\nFixing user ${phone}...`);

      const usersSnapshot = await db.collection('users')
        .where('phoneNumber', '==', phone)
        .limit(1)
        .get();

      if (usersSnapshot.empty) {
        console.log(`  ❌ User not found`);
        continue;
      }

      const userDoc = usersSnapshot.docs[0];
      const userData = userDoc.data();
      const updates = {};

      // Fix currentClass if it's numeric
      if (userData.currentClass !== undefined && typeof userData.currentClass === 'number') {
        updates.currentClass = userData.currentClass.toString();
        console.log(`  ✓ Converting currentClass from ${userData.currentClass} to "${updates.currentClass}"`);
      }

      // Ensure currentClass exists (set to "12" if missing and has jeeTargetExamDate)
      if (!userData.currentClass && userData.jeeTargetExamDate) {
        updates.currentClass = "12";
        console.log(`  ✓ Setting missing currentClass to "12"`);
      }

      // Update if needed
      if (Object.keys(updates).length > 0) {
        await userDoc.ref.update(updates);
        console.log(`  ✅ Updated ${userDoc.id}`);
      } else {
        console.log(`  ✅ No updates needed`);
      }
    }

    console.log('\n✅ All done!');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

fixUsers();
