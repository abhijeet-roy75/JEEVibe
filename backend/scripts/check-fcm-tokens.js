/**
 * Check FCM tokens and session data for test users
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function checkFcmTokens() {
  try {
    const testPhones = ['+16505551234', '+14125965484'];

    console.log('========== Checking FCM Tokens and Sessions ==========\n');

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

      console.log(`\n📱 User: ${userData.firstName} (${phone})`);
      console.log(`   User ID: ${userDoc.id}`);
      console.log(`\n🔔 FCM Token:`);
      console.log(`   Has FCM token: ${!!userData.fcm_token}`);
      if (userData.fcm_token) {
        console.log(`   Token (first 20 chars): ${userData.fcm_token.substring(0, 20)}...`);
        console.log(`   Token updated: ${userData.fcm_token_updated_at?.toDate?.()}`);
      } else {
        console.log(`   ⚠️  NO FCM TOKEN REGISTERED`);
      }

      console.log(`\n🔐 Session Data:`);
      const session = userData.auth?.active_session;
      if (session) {
        console.log(`   Has active session: YES`);
        console.log(`   Device ID: ${session.device_id}`);
        console.log(`   Device name: ${session.device_name}`);
        console.log(`   Created: ${session.created_at?.toDate?.()}`);
        console.log(`   Last active: ${session.last_active_at?.toDate?.()}`);
        console.log(`   Session token (first 15 chars): ${session.token?.substring(0, 15)}...`);
      } else {
        console.log(`   ⚠️  NO ACTIVE SESSION`);
      }

      console.log('\n' + '='.repeat(60));
    }

    console.log('\n✅ Check complete!');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkFcmTokens();
