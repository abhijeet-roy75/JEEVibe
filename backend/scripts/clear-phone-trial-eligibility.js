/**
 * Clear trial eligibility for a phone number
 * Allows the phone to be used for trial again (for testing)
 *
 * Usage: node scripts/clear-phone-trial-eligibility.js <phoneNumber>
 */

const { db } = require('../src/config/firebase');

async function clearPhoneEligibility(phoneNumber) {
  if (!phoneNumber) {
    console.error('Usage: node scripts/clear-phone-trial-eligibility.js <phoneNumber>');
    console.error('Example: node scripts/clear-phone-trial-eligibility.js +17035319704');
    process.exit(1);
  }

  try {
    console.log(`Clearing trial eligibility for phone: ${phoneNumber}\n`);

    // Find all users with this phone in their trial
    const usersSnapshot = await db.collection('users')
      .where('trial.eligibility_phone', '==', phoneNumber)
      .get();

    if (usersSnapshot.empty) {
      console.log('✅ No users found with this phone marked for trial');
      console.log('   Phone is already eligible for new trial');
      process.exit(0);
    }

    console.log(`Found ${usersSnapshot.size} user(s) with this phone in trial eligibility`);

    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();
      console.log(`\n📝 User: ${doc.id}`);
      console.log(`   Trial active: ${userData.trial?.is_active}`);
      console.log(`   Trial ends: ${userData.trial?.ends_at?.toDate?.()?.toISOString()}`);

      // Remove the trial field entirely
      await db.collection('users').doc(doc.id).update({
        trial: null,
        updated_at: new Date()
      });

      console.log('   ✅ Trial eligibility cleared');
    }

    console.log('\n✅ Phone is now eligible for new trial');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

const phoneNumber = process.argv[2];
clearPhoneEligibility(phoneNumber);
