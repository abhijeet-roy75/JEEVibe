/**
 * Migrate old fcm_token field to new fcm_tokens map structure
 *
 * This script:
 * 1. Finds all users with old fcm_token field
 * 2. Migrates to fcm_tokens map using active_session.device_id as key
 * 3. Keeps old fcm_token field for backwards compatibility
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function migrateFcmTokens() {
  try {
    console.log('========== Migrating FCM Tokens ==========\n');

    // Get all users with old fcm_token field
    const usersSnapshot = await db.collection('users')
      .where('fcm_token', '!=', null)
      .get();

    console.log(`Found ${usersSnapshot.size} users with old fcm_token field\n`);

    let migratedCount = 0;
    let skippedCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      const oldToken = userData.fcm_token;

      console.log(`\nUser: ${userData.firstName || 'Unknown'} (${userId})`);
      console.log(`  Old token: ${oldToken.substring(0, 30)}...`);

      // Check if already has fcm_tokens map
      if (userData.fcm_tokens && Object.keys(userData.fcm_tokens).length > 0) {
        console.log('  ⏭️  Already has fcm_tokens map - skipping');
        skippedCount++;
        continue;
      }

      // Get active session to find device_id
      const activeSession = userData?.auth?.active_session;

      if (!activeSession || !activeSession.device_id) {
        console.log('  ⚠️  No active session - cannot migrate (device_id unknown)');
        skippedCount++;
        continue;
      }

      const deviceId = activeSession.device_id;
      console.log(`  Device ID: ${deviceId}`);

      // Migrate token to new structure
      try {
        await db.collection('users').doc(userId).update({
          [`fcm_tokens.${deviceId}`]: oldToken,
          // Keep old token for backwards compatibility with older app versions
          fcm_token_migrated_at: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log('  ✅ Migrated successfully');
        migratedCount++;
      } catch (error) {
        console.log(`  ❌ Migration failed: ${error.message}`);
        skippedCount++;
      }
    }

    console.log('\n========== Migration Complete ==========');
    console.log(`Migrated: ${migratedCount}`);
    console.log(`Skipped: ${skippedCount}`);
    console.log(`Total: ${usersSnapshot.size}`);

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

migrateFcmTokens();
