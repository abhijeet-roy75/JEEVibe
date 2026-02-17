/**
 * Test FCM notification sending
 *
 * This script helps diagnose FCM issues by:
 * 1. Checking if Firebase Admin SDK is initialized
 * 2. Verifying FCM tokens exist for a user
 * 3. Attempting to send a test notification
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function testFcmNotification() {
  try {
    // Test phone number
    const testPhone = '+14125965484';

    console.log('========== FCM Notification Test ==========\n');
    console.log(`Testing with phone: ${testPhone}\n`);

    // 1. Get user
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

    console.log(`✅ User found: ${userData.firstName} (${userId})\n`);

    // 2. Check FCM tokens
    console.log('📱 Checking FCM tokens:');
    const fcmTokens = userData.fcm_tokens || {};
    const tokenCount = Object.keys(fcmTokens).length;

    console.log(`   Token count: ${tokenCount}`);

    if (tokenCount === 0) {
      console.log('   ❌ No FCM tokens found!');
      console.log('\n   This means:');
      console.log('   - Device has not registered FCM token yet');
      console.log('   - Or PushNotificationService.initialize() was not called');
      console.log('   - Or FCM token registration failed');
      process.exit(1);
    }

    console.log('\n   Tokens by device:');
    for (const [deviceId, token] of Object.entries(fcmTokens)) {
      console.log(`   - Device: ${deviceId}`);
      console.log(`     Token: ${token.substring(0, 30)}...`);
    }

    // 3. Check active session
    console.log('\n🔐 Active Session:');
    const activeSession = userData?.auth?.active_session;
    if (activeSession) {
      console.log(`   Device ID: ${activeSession.device_id}`);
      console.log(`   Device Name: ${activeSession.device_name}`);
      console.log(`   Created: ${activeSession.created_at?.toDate?.()}`);
    } else {
      console.log('   ⚠️  No active session');
    }

    // 4. Try to send test notification to EACH device
    console.log('\n📤 Sending test notifications:\n');

    for (const [deviceId, token] of Object.entries(fcmTokens)) {
      console.log(`   Testing device: ${deviceId}`);

      try {
        const message = {
          token: token,
          notification: {
            title: '🧪 FCM Test Notification',
            body: 'This is a test from the backend. If you see this, FCM is working!'
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
        console.log(`   ✅ Notification sent successfully!`);
        console.log(`      Message ID: ${response}`);
      } catch (error) {
        console.log(`   ❌ Failed to send notification`);
        console.log(`      Error: ${error.message}`);
        console.log(`      Code: ${error.code}`);

        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
          console.log(`      ⚠️  Token is invalid or expired - device needs to re-register`);
        }
      }
      console.log('');
    }

    console.log('========== Test Complete ==========');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

testFcmNotification();
