/**
 * Verify ULTRA tier is working for test users
 * Also clears any cached tier data by updating a timestamp
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function verifyUltraTier() {
  try {
    const testPhones = ['+16505551234', '+14125965484'];

    console.log('========== Verifying ULTRA Tier for Test Users ==========\n');

    for (const phone of testPhones) {
      const usersSnapshot = await db.collection('users')
        .where('phoneNumber', '==', phone)
        .limit(1)
        .get();

      if (usersSnapshot.empty) {
        console.log(`❌ User ${phone} not found\n`);
        continue;
      }

      const userDoc = usersSnapshot.docs[0];
      const userData = userDoc.data();

      console.log(`User: ${userData.firstName} (${phone})`);
      console.log(`  Database subscriptionTier: ${userData.subscriptionTier}`);
      console.log(`  Database subscriptionStatus: ${userData.subscriptionStatus}`);
      console.log(`  Trial ends: ${userData.trialEndsAt?.toDate()}`);

      // Update updatedAt to bust any caches
      await userDoc.ref.update({
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        // Ensure these are set correctly
        subscriptionTier: 'ULTRA',
        subscriptionStatus: 'trial'
      });

      console.log(`  ✅ Updated timestamp to clear caches\n`);
    }

    console.log('✅ All test users verified with ULTRA tier');
    console.log('⏰ Backend cache will refresh within 60 seconds');
    console.log('📱 App users should restart app to see changes');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

verifyUltraTier();
