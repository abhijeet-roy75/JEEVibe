/**
 * Manually test session expired notification
 *
 * This simulates what happens when Device B logs in while Device A is active
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function testSessionExpired() {
  // Test with user who has fcm_tokens
  const testPhone = '+919970244498';

  console.log('========== Testing Session Expired Notification ==========\n');

  const usersSnapshot = await db.collection('users')
    .where('phoneNumber', '==', testPhone)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.log('❌ User not found');
    process.exit(1);
  }

  const userData = usersSnapshot.docs[0].data();
  const fcmTokens = userData.fcm_tokens || {};

  if (Object.keys(fcmTokens).length === 0) {
    console.log('❌ No FCM tokens for this user');
    process.exit(1);
  }

  console.log(`Testing with: ${userData.firstName} (${testPhone})`);
  console.log(`FCM tokens: ${Object.keys(fcmTokens).length}\n`);

  // Get first token
  const [deviceId, token] = Object.entries(fcmTokens)[0];

  console.log(`Sending to device: ${deviceId}`);
  console.log(`Token: ${token.substring(0, 30)}...\n`);

  try {
    const message = {
      token: token,
      notification: {
        title: 'Logged in on another device',
        body: "You've been logged in on Samsung Galaxy S21. Tap to continue."
      },
      data: {
        type: 'session_expired',
        new_device: 'Samsung Galaxy S21',
        old_device: deviceId
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
    console.log('✅ Notification sent successfully!');
    console.log(`   Message ID: ${response}\n`);
    console.log('Check the device - you should see the notification!');
    console.log('When tapped, it should show session expired dialog.');
  } catch (error) {
    console.log(`❌ Failed to send: ${error.message} (${error.code})`);
  }

  process.exit(0);
}

testSessionExpired();
