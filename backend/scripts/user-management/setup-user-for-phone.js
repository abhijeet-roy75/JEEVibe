/**
 * Complete setup for a phone number:
 * 1. Delete any existing Firebase Auth users with this phone
 * 2. Delete any Firestore users with this phone
 * 3. Create fresh Firebase Auth user
 * 4. Create complete Firestore profile with trial
 *
 * Usage: node scripts/setup-user-for-phone.js <phoneNumber> <firstName> <lastName> <email>
 * Example: node scripts/setup-user-for-phone.js +17035319704 Abhijeet Roy aroy75@gmail.com
 */

const { db, admin } = require('../src/config/firebase');

async function setupUser(phoneNumber, firstName, lastName, email) {
  if (!phoneNumber || !firstName || !email) {
    console.error('Usage: node scripts/setup-user-for-phone.js <phoneNumber> <firstName> <lastName> <email>');
    console.error('Example: node scripts/setup-user-for-phone.js +17035319704 Abhijeet Roy aroy75@gmail.com');
    process.exit(1);
  }

  console.log(`\n🔧 Complete setup for: ${phoneNumber}\n`);

  try {
    // Step 1: Find and delete Firebase Auth users with this phone
    console.log('Step 1: Checking Firebase Auth users...');
    try {
      const userRecord = await admin.auth().getUserByPhoneNumber(phoneNumber);
      console.log(`  Found Firebase Auth user: ${userRecord.uid}`);
      await admin.auth().deleteUser(userRecord.uid);
      console.log(`  ✅ Deleted Firebase Auth user: ${userRecord.uid}`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log('  No Firebase Auth user found (OK)');
      } else {
        throw error;
      }
    }

    // Step 2: Find and delete Firestore users with this phone
    console.log('\nStep 2: Checking Firestore users...');
    const usersSnapshot = await db.collection('users')
      .where('phoneNumber', '==', phoneNumber)
      .get();

    if (usersSnapshot.empty) {
      console.log('  No Firestore users found (OK)');
    } else {
      for (const doc of usersSnapshot.docs) {
        await db.collection('users').doc(doc.id).delete();
        console.log(`  ✅ Deleted Firestore user: ${doc.id}`);
      }
    }

    // Step 3: Create fresh Firebase Auth user
    console.log('\nStep 3: Creating Firebase Auth user...');
    const newUserRecord = await admin.auth().createUser({
      phoneNumber: phoneNumber,
      email: email,
      emailVerified: true,
    });
    console.log(`  ✅ Created Firebase Auth user: ${newUserRecord.uid}`);

    // Step 4: Create Firestore profile with trial
    console.log('\nStep 4: Creating Firestore profile...');
    const now = admin.firestore.Timestamp.now();
    const endsAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
    );

    const userData = {
      uid: newUserRecord.uid,
      phoneNumber: phoneNumber,
      firstName: firstName,
      lastName: lastName || '',
      email: email,
      targetYear: '2026',
      targetExam: 'JEE Main',
      state: '',
      dreamBranch: '',
      studySetup: [],
      createdAt: now,
      lastActive: now,
      updated_at: now,
      isProfileCompleted: true,

      // Trial
      trial: {
        tier_id: 'pro',
        started_at: now,
        ends_at: endsAt,
        is_active: true,
        notifications_sent: {},
        converted_to_paid: false,
        eligibility_phone: phoneNumber
      },

      // Subscription
      subscription: {
        source: 'trial'
      }
    };

    await db.collection('users').doc(newUserRecord.uid).set(userData);
    console.log('  ✅ Created Firestore profile with trial');

    // Step 5: Log trial event
    await db.collection('trial_events').add({
      user_id: newUserRecord.uid,
      event_type: 'trial_started_manual',
      timestamp: now,
      data: {
        tier_id: 'pro',
        duration_days: 30,
        ends_at: endsAt.toDate().toISOString()
      }
    });

    console.log('\n✅ COMPLETE! User ready to use:');
    console.log(`   UID: ${newUserRecord.uid}`);
    console.log(`   Phone: ${phoneNumber}`);
    console.log(`   Email: ${email}`);
    console.log(`   Name: ${firstName} ${lastName}`);
    console.log(`   Trial: 30-day PRO (ends ${endsAt.toDate().toISOString()})`);
    console.log('\n📱 Now sign in on the app with this phone number!');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

const [phoneNumber, firstName, lastName, email] = process.argv.slice(2);
setupUser(phoneNumber, firstName, lastName || '', email);
