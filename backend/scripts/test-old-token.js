/**
 * Test sending notification to old fcm_token field
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function testOldToken() {
  const testPhone = '+14125965484';

  const usersSnapshot = await db.collection('users')
    .where('phoneNumber', '==', testPhone)
    .limit(1)
    .get();

  const userData = usersSnapshot.docs[0].data();
  const oldToken = userData.fcm_token;

  console.log(`Sending test notification to old token: ${oldToken.substring(0, 30)}...`);

  try {
    const message = {
      token: oldToken,
      notification: {
        title: '🧪 FCM Test (Old Token)',
        body: 'Testing if FCM works with old token format. Check your device!'
      },
      data: {
        type: 'test'
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
    console.log(`✅ Notification sent! Message ID: ${response}`);
    console.log('\nCheck your device - you should see a notification now!');
  } catch (error) {
    console.log(`❌ Failed: ${error.message} (${error.code})`);
  }
}

testOldToken();
