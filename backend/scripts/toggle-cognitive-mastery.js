#!/usr/bin/env node

/**
 * Toggle Cognitive Mastery Feature Flag
 *
 * Usage:
 *   node scripts/toggle-cognitive-mastery.js [on|off]
 *
 * Examples:
 *   node scripts/toggle-cognitive-mastery.js on    # Enable the feature
 *   node scripts/toggle-cognitive-mastery.js off   # Disable the feature
 *   node scripts/toggle-cognitive-mastery.js       # Show current status
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../jeevibe-firebase-adminsdk.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccountPath)
});

const db = admin.firestore();

async function getCurrentStatus() {
  const doc = await db.collection('tier_config').doc('active').get();

  if (!doc.exists) {
    console.log('❌ tier_config/active document does not exist');
    return null;
  }

  const data = doc.data();
  const featureFlags = data.feature_flags || {};
  const currentStatus = featureFlags.show_cognitive_mastery || false;

  return currentStatus;
}

async function setStatus(enable) {
  const doc = db.collection('tier_config').doc('active');

  await doc.set({
    feature_flags: {
      show_cognitive_mastery: enable
    }
  }, { merge: true });

  console.log(`✅ Cognitive Mastery feature flag set to: ${enable ? 'ENABLED' : 'DISABLED'}`);
}

async function main() {
  const args = process.argv.slice(2);
  const command = args[0]?.toLowerCase();

  // Show current status
  const currentStatus = await getCurrentStatus();

  if (currentStatus === null) {
    console.log('⚠️  Creating tier_config/active document with default flags...');
    await setStatus(false);
    process.exit(0);
  }

  console.log(`📊 Current status: ${currentStatus ? 'ENABLED ✅' : 'DISABLED ❌'}`);
  console.log('');

  // If no command, just show status
  if (!command) {
    console.log('Usage:');
    console.log('  node scripts/toggle-cognitive-mastery.js on   # Enable');
    console.log('  node scripts/toggle-cognitive-mastery.js off  # Disable');
    process.exit(0);
  }

  // Toggle based on command
  if (command === 'on' || command === 'enable') {
    if (currentStatus) {
      console.log('ℹ️  Already enabled. No changes made.');
    } else {
      await setStatus(true);
      console.log('');
      console.log('🎉 Cognitive Mastery is now LIVE!');
      console.log('   - Active Weak Spots card will show on home screen');
      console.log('   - Users can see detected weak spots and work through lessons');
    }
  } else if (command === 'off' || command === 'disable') {
    if (!currentStatus) {
      console.log('ℹ️  Already disabled. No changes made.');
    } else {
      await setStatus(false);
      console.log('');
      console.log('🔒 Cognitive Mastery is now HIDDEN');
      console.log('   - Active Weak Spots card will not appear on home screen');
      console.log('   - Feature is still operational but not visible to users');
    }
  } else {
    console.log('❌ Invalid command. Use "on" or "off"');
    process.exit(1);
  }

  process.exit(0);
}

main().catch(error => {
  console.error('❌ Error:', error.message);
  process.exit(1);
});
