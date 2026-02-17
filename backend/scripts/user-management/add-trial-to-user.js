/**
 * Manually add trial to an existing user
 * Usage: node scripts/add-trial-to-user.js <userId>
 */

const { db, admin } = require('../src/config/firebase');

async function addTrialToUser(userId) {
  if (!userId) {
    console.error('Usage: node scripts/add-trial-to-user.js <userId>');
    process.exit(1);
  }

  try {
    console.log(`Adding trial to user: ${userId}\n`);

    // Get user
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userData = userDoc.data();

    // Check if already has trial
    if (userData.trial) {
      console.log('⚠️  User already has trial!');
      console.log(`   Active: ${userData.trial.is_active}`);
      console.log(`   Ends: ${userData.trial.ends_at?.toDate?.()?.toISOString()}`);
      process.exit(1);
    }

    // Create trial
    const now = admin.firestore.Timestamp.now();
    const endsAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
    );

    const trialData = {
      tier_id: 'pro',
      started_at: now,
      ends_at: endsAt,
      is_active: true,
      notifications_sent: {},
      converted_to_paid: false,
      eligibility_phone: userData.phoneNumber
    };

    // Update user
    await db.collection('users').doc(userId).update({
      trial: trialData,
      updated_at: now
    });

    console.log('✅ Trial added successfully!');
    console.log(`   Tier: PRO`);
    console.log(`   Started: ${now.toDate().toISOString()}`);
    console.log(`   Ends: ${endsAt.toDate().toISOString()}`);
    console.log(`   Days: 30`);

    // Log event
    await db.collection('trial_events').add({
      user_id: userId,
      event_type: 'trial_started_manual',
      timestamp: now,
      data: {
        tier_id: 'pro',
        duration_days: 30,
        ends_at: endsAt.toDate().toISOString()
      }
    });

    console.log('\n✅ Trial event logged');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

const userId = process.argv[2];
addTrialToUser(userId);
