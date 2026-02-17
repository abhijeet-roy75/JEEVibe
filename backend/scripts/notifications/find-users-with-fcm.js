/**
 * Find all users with FCM tokens in new structure
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function findUsersWithFcm() {
  console.log('========== Finding Users with FCM Tokens ==========\n');

  // Get all users
  const usersSnapshot = await db.collection('users').get();

  console.log(`Total users: ${usersSnapshot.size}\n`);

  const usersWithNewTokens = [];
  const usersWithOldTokens = [];
  const usersWithNoTokens = [];

  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    const userId = userDoc.id;

    const hasNewTokens = userData.fcm_tokens && Object.keys(userData.fcm_tokens).length > 0;
    const hasOldToken = !!userData.fcm_token;

    if (hasNewTokens) {
      usersWithNewTokens.push({
        id: userId,
        name: userData.firstName,
        phone: userData.phoneNumber,
        tokenCount: Object.keys(userData.fcm_tokens).length,
        deviceIds: Object.keys(userData.fcm_tokens)
      });
    } else if (hasOldToken) {
      usersWithOldTokens.push({
        id: userId,
        name: userData.firstName,
        phone: userData.phoneNumber
      });
    } else {
      usersWithNoTokens.push({
        id: userId,
        name: userData.firstName,
        phone: userData.phoneNumber
      });
    }
  }

  console.log('✅ Users with NEW fcm_tokens structure:');
  if (usersWithNewTokens.length === 0) {
    console.log('   None\n');
  } else {
    for (const user of usersWithNewTokens) {
      console.log(`   - ${user.name} (${user.phone})`);
      console.log(`     Devices: ${user.deviceIds.join(', ')}`);
    }
    console.log('');
  }

  console.log('⚠️  Users with OLD fcm_token only:');
  if (usersWithOldTokens.length === 0) {
    console.log('   None\n');
  } else {
    for (const user of usersWithOldTokens) {
      console.log(`   - ${user.name} (${user.phone})`);
    }
    console.log('');
  }

  console.log('❌ Users with NO FCM tokens:');
  if (usersWithNoTokens.length === 0) {
    console.log('   None\n');
  } else {
    for (const user of usersWithNoTokens) {
      console.log(`   - ${user.name} (${user.phone})`);
    }
    console.log('');
  }

  console.log('Summary:');
  console.log(`  With new tokens: ${usersWithNewTokens.length}`);
  console.log(`  With old tokens only: ${usersWithOldTokens.length}`);
  console.log(`  With no tokens: ${usersWithNoTokens.length}`);

  process.exit(0);
}

findUsersWithFcm();
