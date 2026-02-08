/**
 * Check test users in Firestore
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function checkUsers() {
  try {
    // Check both test phone numbers
    const phones = ['+16505551234', '+14125965484'];

    for (const phone of phones) {
      console.log(`\n========== Checking ${phone} ==========`);

      // Search by phone number
      const usersSnapshot = await db.collection('users')
        .where('phoneNumber', '==', phone)
        .limit(1)
        .get();

      if (usersSnapshot.empty) {
        console.log(`❌ No user found with phone ${phone}`);
      } else {
        const userDoc = usersSnapshot.docs[0];
        const userData = userDoc.data();
        console.log(`✅ User found: ${userDoc.id}`);
        console.log(`   Name: ${userData.firstName || 'N/A'} ${userData.lastName || ''}`);
        console.log(`   Phone: ${userData.phoneNumber || 'N/A'}`);
        console.log(`   Class: ${userData.currentClass || 'N/A'}`);
        console.log(`   JEE Target: ${userData.jeeTargetExamDate || 'N/A'}`);
        console.log(`   High Water Mark: ${userData.chapterUnlockHighWaterMark || 0}`);
        console.log(`   Created: ${userData.created_at?.toDate().toISOString() || 'N/A'}`);
      }
    }

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkUsers();
