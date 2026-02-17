/**
 * Script to initialize the trial_config/active document in Firestore
 * Run once to set up the trial-first signup system
 *
 * Usage: node scripts/initialize-trial-config.js
 */

const admin = require('firebase-admin');
const { db } = require('../src/config/firebase');

const DEFAULT_TRIAL_CONFIG = {
  enabled: true,
  trial_tier_id: 'pro',
  duration_days: 30,

  eligibility: {
    one_per_phone: true,
    check_existing_subscription: true
  },

  notification_schedule: [
    {
      days_remaining: 23,
      channels: ['email'],
      template: 'trial_week_1'
    },
    {
      days_remaining: 5,
      channels: ['email', 'push'],
      template: 'trial_urgency_5'
    },
    {
      days_remaining: 2,
      channels: ['email', 'push'],
      template: 'trial_urgency_2'
    },
    {
      days_remaining: 0,
      channels: ['email', 'push', 'in_app_dialog'],
      template: 'trial_expired'
    }
  ],

  notifications: {
    email: {
      enabled: true,
      milestones: [23, 5, 2, 0]
    },
    push: {
      enabled: true,
      milestones: [5, 2, 0]
    },
    in_app_banner: {
      enabled: true,
      urgency_threshold: 5
    },
    in_app_dialog: {
      enabled: true
    }
  },

  expiry: {
    downgrade_to_tier: 'free',
    grace_period_days: 0,
    show_discount_offer: true,
    discount_code: 'TRIAL2PRO',
    discount_valid_days: 7
  },

  // Metadata
  created_at: admin.firestore.FieldValue.serverTimestamp(),
  updated_at: admin.firestore.FieldValue.serverTimestamp(),
  version: '1.0.0'
};

async function initializeTrialConfig() {
  try {
    console.log('Initializing trial configuration...');

    const configRef = db.collection('trial_config').doc('active');
    const configDoc = await configRef.get();

    if (configDoc.exists) {
      console.log('⚠️  Trial config already exists. Current config:');
      console.log(JSON.stringify(configDoc.data(), null, 2));

      const readline = require('readline').createInterface({
        input: process.stdin,
        output: process.stdout
      });

      return new Promise((resolve) => {
        readline.question('\nOverwrite existing config? (yes/no): ', async (answer) => {
          readline.close();

          if (answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y') {
            await configRef.set({
              ...DEFAULT_TRIAL_CONFIG,
              updated_at: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log('✅ Trial config updated successfully!');
          } else {
            console.log('❌ Operation cancelled.');
          }
          resolve();
        });
      });
    } else {
      await configRef.set(DEFAULT_TRIAL_CONFIG);
      console.log('✅ Trial config created successfully!');
      console.log('\nConfiguration:');
      console.log(`- Enabled: ${DEFAULT_TRIAL_CONFIG.enabled}`);
      console.log(`- Trial Tier: ${DEFAULT_TRIAL_CONFIG.trial_tier_id.toUpperCase()}`);
      console.log(`- Duration: ${DEFAULT_TRIAL_CONFIG.duration_days} days`);
      console.log(`- Notifications: Email at day ${DEFAULT_TRIAL_CONFIG.notifications.email.milestones.join(', ')}`);
      console.log(`- Push: At day ${DEFAULT_TRIAL_CONFIG.notifications.push.milestones.join(', ')}`);
      console.log(`- Discount Code: ${DEFAULT_TRIAL_CONFIG.expiry.discount_code}`);
    }

  } catch (error) {
    console.error('❌ Error initializing trial config:', error);
    throw error;
  }
}

// Run the script
initializeTrialConfig()
  .then(() => {
    console.log('\n✅ Script completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Script failed:', error);
    process.exit(1);
  });
