#!/usr/bin/env node
const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function debugUser(phoneInput) {
  let phone = phoneInput;
  if (!phone.startsWith('+')) {
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.length === 10) phone = '+91' + phone;
    else if (phone.length === 11) phone = '+' + phone;
  }

  console.log(`\n╔════════════════════════════════════════════════════════════`);
  console.log(`║ USER DEBUG REPORT`);
  console.log(`╚════════════════════════════════════════════════════════════\n`);

  const usersSnap = await db.collection('users').where('phoneNumber', '==', phone).limit(1).get();

  if (usersSnap.empty) {
    console.log(`❌ User not found with phone: ${phone}\n`);
    process.exit(1);
  }

  const userDoc = usersSnap.docs[0];
  const userData = userDoc.data();
  const userId = userDoc.id;

  // User Info
  console.log(`📱 USER INFO`);
  console.log(`   Name: ${userData.firstName || 'N/A'}`);
  console.log(`   Phone: ${userData.phoneNumber || 'N/A'}`);
  console.log(`   Email: ${userData.email || 'N/A'}`);
  console.log(`   User ID: ${userId}`);
  console.log(`   Created: ${userData.createdAt ? new Date(userData.createdAt._seconds * 1000).toLocaleString() : 'N/A'}\n`);

  // Subscription & Tier
  console.log(`🎯 SUBSCRIPTION & TIER`);
  const sub = userData.subscription || {};
  const trial = userData.trial || {};

  let tier = 'free';
  let source = 'default';
  if (sub.override) {
    tier = sub.override.tier_id || 'free';
    source = `override (${sub.override.reason || 'N/A'})`;
  } else if (sub.tier) {
    tier = sub.tier;
    source = 'subscription';
  } else if (trial.is_active) {
    tier = 'pro';
    source = 'trial';
  }

  console.log(`   Effective Tier: ${tier.toUpperCase()}`);
  console.log(`   Tier Source: ${source}`);

  if (trial.is_active) {
    const endsAt = trial.ends_at ? new Date(trial.ends_at._seconds * 1000) : null;
    console.log(`   Trial Status: ACTIVE`);
    if (endsAt) {
      const days = Math.ceil((endsAt - new Date()) / 86400000);
      console.log(`   Trial Expires: ${endsAt.toLocaleDateString()} (${days} days remaining)`);
    }
  } else {
    console.log(`   Trial Status: ${trial.ends_at ? 'EXPIRED' : 'NOT STARTED'}`);
  }
  console.log('');

  // Theta Data
  console.log(`📊 THETA DATA`);
  if (userData.overall_theta) {
    console.log(`   Overall Theta: ${userData.overall_theta.toFixed(2)} (${(userData.overall_percentile || 0).toFixed(1)}th percentile)`);

    const subjects = ['physics', 'chemistry', 'mathematics'];
    if (userData.theta_by_subject) {
      subjects.forEach(s => {
        if (userData.theta_by_subject[s]) {
          const theta = userData.theta_by_subject[s].theta.toFixed(2);
          console.log(`   ${s.charAt(0).toUpperCase() + s.slice(1)}: ${theta}`);
        }
      });
    }

    if (userData.assessment_baseline && userData.assessment_baseline.overall_theta) {
      const baseline = userData.assessment_baseline.overall_theta.toFixed(2);
      const current = userData.overall_theta.toFixed(2);
      const change = (userData.overall_theta - userData.assessment_baseline.overall_theta).toFixed(2);
      console.log(`\n   Baseline: ${baseline} → Current: ${current} (${change >= 0 ? '+' : ''}${change})`);
    }
  } else {
    console.log(`   ⚠️  No theta data (assessment not completed)`);
  }
  console.log('');

  // Activity
  console.log(`📚 ACTIVITY`);

  const quizzesSnap = await db.collection('users').doc(userId).collection('daily_quizzes').get();
  console.log(`   Daily Quizzes: ${quizzesSnap.size} completed`);

  const sessionsSnap = await db.collection('users').doc(userId).collection('chapter_sessions')
    .where('status', '==', 'completed').get();
  let totalQ = 0, totalCorrect = 0;
  sessionsSnap.forEach(doc => {
    const d = doc.data();
    totalQ += d.total_questions || 0;
    totalCorrect += d.correct_count || 0;
  });
  const accuracy = totalQ > 0 ? ((totalCorrect / totalQ) * 100).toFixed(1) : 0;
  console.log(`   Chapter Practice: ${sessionsSnap.size} sessions, ${totalQ} questions (${accuracy}% correct)`);

  console.log(`\n════════════════════════════════════════════════════════════\n`);

  process.exit(0);
}

const phone = process.argv[2];
if (!phone) {
  console.error('Usage: node script.js <phone_number>');
  process.exit(1);
}

debugUser(phone).catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
