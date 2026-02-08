/**
 * Add missing subscriptionTier field to all users
 * Sets to 'FREE' by default (can be upgraded later)
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function addSubscriptionTier() {
  try {
    console.log('========== Adding Missing subscriptionTier ==========\n');

    const usersSnapshot = await db.collection('users').get();

    if (usersSnapshot.empty) {
      console.log('❌ No users found in database');
      process.exit(0);
    }

    console.log(`📊 Total users: ${usersSnapshot.size}\n`);

    let updatedCount = 0;
    let alreadyHasCount = 0;

    for (const doc of usersSnapshot.docs) {
      const userId = doc.id;
      const userData = doc.data();

      if (!userData.subscriptionTier) {
        console.log(`Updating user ${userId} (${userData.phoneNumber})...`);

        await doc.ref.update({
          subscriptionTier: 'FREE',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        updatedCount++;
        console.log(`  ✅ Set subscriptionTier to FREE`);
      } else {
        console.log(`User ${userId} already has subscriptionTier: ${userData.subscriptionTier}`);
        alreadyHasCount++;
      }
    }

    console.log('\n========== Summary ==========');
    console.log(`✅ Updated: ${updatedCount} users`);
    console.log(`ℹ️  Already had tier: ${alreadyHasCount} users`);
    console.log('\n✅ All done!');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

addSubscriptionTier();
