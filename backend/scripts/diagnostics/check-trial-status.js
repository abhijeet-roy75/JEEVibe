/**
 * Check trial status for a phone number
 *
 * Usage: node scripts/check-trial-status.js <phoneNumber>
 */

const { db } = require('../src/config/firebase');

async function checkTrialStatus(phoneNumber) {
  try {
    console.log(`\n🔍 Checking trial status for: ${phoneNumber}\n`);

    const usersSnapshot = await db.collection('users')
      .where('phoneNumber', '==', phoneNumber)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();

    console.log(`✅ User ID: ${userDoc.id}`);
    console.log(`   Name: ${userData.firstName} ${userData.lastName || ''}`);
    console.log(`   Email: ${userData.email}`);
    console.log('\n📊 Trial Data:');
    console.log(JSON.stringify(userData.trial, null, 2));

    if (userData.trial) {
      const now = new Date();
      const endsAt = userData.trial.ends_at?.toDate
        ? userData.trial.ends_at.toDate()
        : new Date(userData.trial.ends_at);

      const daysRemaining = Math.ceil((endsAt - now) / (1000 * 60 * 60 * 24));

      console.log('\n📅 Calculated:');
      console.log(`   Days remaining: ${daysRemaining}`);
      console.log(`   Ends at: ${endsAt.toISOString()}`);
      console.log(`   Is active: ${userData.trial.is_active}`);
      console.log(`   Should process: ${userData.trial.is_active === true ? 'YES' : 'NO'}`);
    } else {
      console.log('\n⚠️  No trial data found');
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

const phoneNumber = process.argv[2];

if (!phoneNumber) {
  console.error('\n❌ Usage: node scripts/check-trial-status.js <phoneNumber>');
  console.error('   Example: node scripts/check-trial-status.js +17035319704\n');
  process.exit(1);
}

checkTrialStatus(phoneNumber);
