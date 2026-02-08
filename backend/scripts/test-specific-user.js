/**
 * Test FCM notification for specific user
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function testUser() {
  const testPhone = '+16505551234';

  console.log('========== Testing User ==========\n');
  console.log(`Phone: ${testPhone}\n`);

  const usersSnapshot = await db.collection('users')
    .where('phoneNumber', '==', testPhone)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.log('❌ User not found');
    process.exit(1);
  }

  const userDoc = usersSnapshot.docs[0];
  const userData = userDoc.data();
  const userId = userDoc.id;

  console.log(`User: ${userData.firstName} (${userId})\n`);

  // Check FCM tokens (new structure)
  console.log('📱 FCM Tokens (new structure):');
  const fcmTokens = userData.fcm_tokens || {};
  console.log(`   Count: ${Object.keys(fcmTokens).length}`);

  if (Object.keys(fcmTokens).length > 0) {
    for (const [deviceId, token] of Object.entries(fcmTokens)) {
      console.log(`   - Device: ${deviceId}`);
      console.log(`     Token: ${token.substring(0, 30)}...`);
    }
  } else {
    console.log('   ⚠️  No tokens in fcm_tokens map');
  }

  // Check old FCM token
  console.log('\n📱 Old FCM Token:');
  if (userData.fcm_token) {
    console.log(`   Token: ${userData.fcm_token.substring(0, 30)}...`);
    console.log(`   Updated: ${userData.fcm_token_updated_at?.toDate?.()}`);
  } else {
    console.log('   ⚠️  No old fcm_token field');
  }

  // Check active session
  console.log('\n🔐 Active Session:');
  const activeSession = userData?.auth?.active_session;
  if (activeSession) {
    console.log(`   Device ID: ${activeSession.device_id}`);
    console.log(`   Device Name: ${activeSession.device_name}`);
    console.log(`   Created: ${activeSession.created_at?.toDate?.()}`);
    console.log(`   Last active: ${activeSession.last_active_at?.toDate?.()}`);
  } else {
    console.log('   ⚠️  No active session');
  }

  // Try sending test notification if tokens exist
  if (Object.keys(fcmTokens).length > 0) {
    console.log('\n📤 Sending test notifications:\n');

    for (const [deviceId, token] of Object.entries(fcmTokens)) {
      console.log(`   Testing device: ${deviceId}`);

      try {
        const message = {
          token: token,
          notification: {
            title: '🧪 FCM Test Notification',
            body: 'This is a test. If you see this, FCM is working!'
          },
          data: {
            type: 'test',
            timestamp: Date.now().toString()
          },
          android: {
            priority: 'high',
          },
          apns: {
            headers: {
              'apns-priority': '10'
            }
          }
        };

        const response = await admin.messaging().send(message);
        console.log(`   ✅ Sent! Message ID: ${response}`);
      } catch (error) {
        console.log(`   ❌ Failed: ${error.message} (${error.code})`);
      }
      console.log('');
    }
  }

  console.log('========== Done ==========');
  process.exit(0);
}

testUser();
