/**
 * Script to adjust trial period for testing notifications
 *
 * Usage:
 *   node scripts/adjust-trial-for-testing.js <phoneNumber> <daysRemaining>
 *
 * Example:
 *   node scripts/adjust-trial-for-testing.js +17035319704 2
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccountPath),
});

const db = admin.firestore();

async function adjustTrialPeriod(phoneNumber, daysRemaining) {
  try {
    console.log(`\n🔍 Searching for user with phone: ${phoneNumber}`);

    // Find user by phone number
    const usersSnapshot = await db.collection('users')
      .where('phoneNumber', '==', phoneNumber)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.error(`❌ No user found with phone number: ${phoneNumber}`);
      process.exit(1);
    }

    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`✅ Found user: ${userId}`);
    console.log(`   Name: ${userData.firstName || 'N/A'}`);
    console.log(`   Email: ${userData.email || 'N/A'}`);

    // Check current trial status
    if (!userData.trial) {
      console.log('\n⚠️  User has no trial data. Creating trial...');

      const now = new Date();
      const endsAt = new Date(now.getTime() + (daysRemaining * 24 * 60 * 60 * 1000));
      const startedAt = new Date(now.getTime() - (30 - daysRemaining) * 24 * 60 * 60 * 1000);

      await userDoc.ref.update({
        trial: {
          tier_id: 'pro',
          started_at: admin.firestore.Timestamp.fromDate(startedAt),
          ends_at: admin.firestore.Timestamp.fromDate(endsAt),
          is_active: true,
          notifications_sent: {},
          converted_to_paid: false,
          eligibility_phone: phoneNumber
        },
        subscription: {
          tier: 'free',
          source: 'trial',
          created_at: admin.firestore.FieldValue.serverTimestamp()
        }
      });

      console.log(`✅ Trial created with ${daysRemaining} days remaining`);
      console.log(`   Started: ${startedAt.toISOString()}`);
      console.log(`   Ends: ${endsAt.toISOString()}`);

    } else {
      console.log('\n📊 Current trial status:');
      console.log(`   Active: ${userData.trial.is_active}`);
      console.log(`   Started: ${userData.trial.started_at?.toDate().toISOString()}`);
      console.log(`   Ends: ${userData.trial.ends_at?.toDate().toISOString()}`);

      const now = new Date();
      const currentDaysRemaining = Math.ceil(
        (userData.trial.ends_at.toDate() - now) / (1000 * 60 * 60 * 24)
      );
      console.log(`   Days remaining: ${currentDaysRemaining}`);

      // Calculate new end date
      const newEndsAt = new Date(now.getTime() + (daysRemaining * 24 * 60 * 60 * 1000));

      console.log(`\n🔧 Adjusting trial to ${daysRemaining} days remaining...`);

      // Update trial end date
      await userDoc.ref.update({
        'trial.ends_at': admin.firestore.Timestamp.fromDate(newEndsAt),
        'trial.is_active': true,
        'subscription.source': 'trial'
      });

      console.log(`✅ Trial adjusted successfully`);
      console.log(`   New end date: ${newEndsAt.toISOString()}`);
    }

    console.log('\n📧 To test notifications:');
    console.log(`   1. Run the trial processing service`);
    console.log(`   2. Check for email/push notification for day ${daysRemaining}`);
    console.log(`   3. Check Firestore: trial.notifications_sent should update`);

    console.log('\n✨ Done!\n');
    process.exit(0);

  } catch (error) {
    console.error('❌ Error adjusting trial:', error);
    process.exit(1);
  }
}

// Parse command line arguments
const args = process.argv.slice(2);

if (args.length !== 2) {
  console.error('\n❌ Invalid arguments');
  console.log('\nUsage:');
  console.log('  node scripts/adjust-trial-for-testing.js <phoneNumber> <daysRemaining>');
  console.log('\nExample:');
  console.log('  node scripts/adjust-trial-for-testing.js +17035319704 2');
  console.log('\nDays remaining options:');
  console.log('  23 - Week 1 milestone (email only)');
  console.log('   5 - Urgency notification (email + push)');
  console.log('   2 - Final warning (email + push)');
  console.log('   0 - Trial expired (email + push + dialog)\n');
  process.exit(1);
}

const phoneNumber = args[0];
const daysRemaining = parseInt(args[1], 10);

if (isNaN(daysRemaining) || daysRemaining < 0) {
  console.error('❌ Days remaining must be a non-negative number');
  process.exit(1);
}

adjustTrialPeriod(phoneNumber, daysRemaining);
