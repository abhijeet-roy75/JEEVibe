/**
 * Check if corrupt user exists in Firebase Auth
 */

const { admin } = require('../src/config/firebase');

async function checkAuthUser() {
  const userId = 'Q0xzVR6olZbqPNYEA1LLcTEkoaF3';

  console.log(`🔍 Checking Firebase Auth for user: ${userId}\n`);

  try {
    const userRecord = await admin.auth().getUser(userId);

    console.log('✅ User EXISTS in Firebase Auth\n');
    console.log('User details:');
    console.log({
      uid: userRecord.uid,
      email: userRecord.email || 'NO EMAIL',
      phoneNumber: userRecord.phoneNumber || 'NO PHONE',
      displayName: userRecord.displayName || 'NO NAME',
      emailVerified: userRecord.emailVerified,
      disabled: userRecord.disabled,
      metadata: {
        creationTime: userRecord.metadata.creationTime,
        lastSignInTime: userRecord.metadata.lastSignInTime,
        lastRefreshTime: userRecord.metadata.lastRefreshTime
      },
      providerData: userRecord.providerData.map(p => ({
        providerId: p.providerId,
        uid: p.uid,
        email: p.email,
        phoneNumber: p.phoneNumber
      }))
    });

    console.log('\n' + '='.repeat(60));
    console.log('RECOMMENDATION');
    console.log('='.repeat(60));

    if (!userRecord.email && !userRecord.phoneNumber) {
      console.log('❌ No email or phone in Firebase Auth either');
      console.log('→ SAFE TO DELETE: This is an orphaned/test account');
    } else {
      console.log('⚠️  Has contact info in Firebase Auth');
      console.log('→ SYNC DATA: Copy auth data to Firestore users collection');
    }

  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.log('❌ User NOT found in Firebase Auth');
      console.log('→ ORPHANED RECORD: Firestore doc exists but no auth user');
      console.log('→ SAFE TO DELETE: This user cannot log in');
    } else {
      console.error('Error checking auth:', error.message);
      process.exit(1);
    }
  }

  process.exit(0);
}

checkAuthUser();
