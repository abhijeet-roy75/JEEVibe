/**
 * Set all users to ULTRA tier for testing phase
 * Also sets trial expiry to far future to ensure full access
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function setUltraTier() {
  try {
    console.log('========== Setting All Users to ULTRA Tier (Testing Phase) ==========\n');

    const usersSnapshot = await db.collection('users').get();

    if (usersSnapshot.empty) {
      console.log('❌ No users found in database');
      process.exit(0);
    }

    console.log(`📊 Total users: ${usersSnapshot.size}\n`);

    let updatedCount = 0;
    let alreadyUltraCount = 0;

    // Set trial to expire in 1 year (for testing)
    const trialExpiry = new Date();
    trialExpiry.setFullYear(trialExpiry.getFullYear() + 1);

    for (const doc of usersSnapshot.docs) {
      const userId = doc.id;
      const userData = doc.data();
      const phone = userData.phoneNumber || 'N/A';
      const name = userData.firstName || userData.displayName || 'N/A';

      if (userData.subscriptionTier === 'ULTRA') {
        console.log(`✓ User ${name} (${phone}) already ULTRA`);
        alreadyUltraCount++;
        continue;
      }

      console.log(`Updating user ${name} (${phone})...`);
      console.log(`  Current tier: ${userData.subscriptionTier || 'none'}`);

      await doc.ref.update({
        subscriptionTier: 'ULTRA',
        trialEndsAt: admin.firestore.Timestamp.fromDate(trialExpiry),
        subscriptionStatus: 'trial', // or 'active' if you prefer
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      updatedCount++;
      console.log(`  ✅ Set to ULTRA tier (trial until ${trialExpiry.toDateString()})\n`);
    }

    console.log('========== Summary ==========');
    console.log(`✅ Updated to ULTRA: ${updatedCount} users`);
    console.log(`ℹ️  Already ULTRA: ${alreadyUltraCount} users`);
    console.log(`📅 Trial expiry: ${trialExpiry.toDateString()}`);
    console.log('\n✅ All done! All users now have ULTRA access for testing.');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

setUltraTier();
