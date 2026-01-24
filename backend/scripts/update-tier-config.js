#!/usr/bin/env node
/**
 * Tier Config Update Script
 *
 * Updates the tier_config/active document in Firestore.
 * The Firestore document is the SINGLE SOURCE OF TRUTH for tier limits.
 * tierConfigService.js has fallback defaults, but Firestore takes precedence.
 *
 * IMPORTANT: When updating tier limits, update BOTH:
 *   1. This script (UPDATED_TIER_CONFIG)
 *   2. tierConfigService.js (DEFAULT_TIER_CONFIG) - for fallback consistency
 *
 * Usage:
 *   cd backend && node scripts/update-tier-config.js
 *
 * Version History:
 *   1.0.0 - Initial tier config
 *   1.2.0 - Added chapter_practice_enabled for free tier
 *   1.3.0 - Added max_devices (anti-abuse), ultra soft caps (50/25/100)
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
function initFirebase() {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  // Try to use GOOGLE_APPLICATION_CREDENTIALS env var first
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  } else {
    // Try to load from local service account file
    const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
    try {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } catch (err) {
      console.error('Error: Could not find service account credentials.');
      console.error('Either set GOOGLE_APPLICATION_CREDENTIALS env var or place serviceAccountKey.json in backend/');
      process.exit(1);
    }
  }

  return admin.app();
}

// The updated tier configuration - MUST match tierConfigService.js DEFAULT_TIER_CONFIG
// This is the source of truth for Firestore tier_config/active document
const UPDATED_TIER_CONFIG = {
  version: '1.3.0',  // Bumped for max_devices and ultra soft caps
  tiers: {
    free: {
      tier_id: 'free',
      display_name: 'Free',
      is_active: true,
      is_purchasable: false,
      limits: {
        snap_solve_daily: 5,
        daily_quiz_daily: 1,
        solution_history_days: 7,
        ai_tutor_enabled: false,
        ai_tutor_messages_daily: 0,
        chapter_practice_enabled: true,           // ENABLED for free tier
        chapter_practice_per_chapter: 15,         // 15 questions per chapter
        chapter_practice_weekly_per_subject: 1,   // 1 chapter per subject per week
        mock_tests_monthly: 1,
        pyq_years_access: 2,
        offline_enabled: false,
        offline_solutions_limit: 0,
        max_devices: 1  // P0: Single session for all tiers (P1 will keep 1 for free)
      },
      features: {
        analytics_access: 'basic'
      }
    },
    pro: {
      tier_id: 'pro',
      display_name: 'Pro',
      is_active: true,
      is_purchasable: true,
      limits: {
        snap_solve_daily: 10,
        daily_quiz_daily: 10,
        solution_history_days: 30,
        ai_tutor_enabled: false,
        ai_tutor_messages_daily: 0,
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 20,
        chapter_practice_weekly_per_subject: -1,  // Unlimited
        mock_tests_monthly: 5,
        pyq_years_access: 5,
        offline_enabled: true,
        offline_solutions_limit: -1,
        max_devices: 1  // P0: Single session for all tiers (P1 will change to 2)
      },
      features: {
        analytics_access: 'full'
      },
      pricing: {
        monthly: {
          price: 29900,
          display_price: '299',
          per_month_price: '299',
          duration_days: 30,
          savings_percent: 0,
          badge: null
        },
        quarterly: {
          price: 74700,
          display_price: '747',
          per_month_price: '249',
          duration_days: 90,
          savings_percent: 17,
          badge: 'MOST POPULAR'
        },
        annual: {
          price: 238800,
          display_price: '2,388',
          per_month_price: '199',
          duration_days: 365,
          savings_percent: 33,
          badge: 'SAVE 33%'
        }
      }
    },
    ultra: {
      tier_id: 'ultra',
      display_name: 'Ultra',
      is_active: true,
      is_purchasable: true,
      limits: {
        // Soft caps instead of truly unlimited (-1) to prevent bot abuse
        // These are high enough that no legitimate user would hit them
        snap_solve_daily: 50,           // Was -1, now 50/day
        daily_quiz_daily: 25,           // Was -1, now 25/day
        solution_history_days: 365,     // Was -1, now 1 year
        ai_tutor_enabled: true,
        ai_tutor_messages_daily: 100,   // Was -1, now 100/day
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 50,     // Was -1, high cap
        chapter_practice_weekly_per_subject: -1,  // Keep unlimited for weekly
        mock_tests_monthly: 15,         // Was -1, now 15/month
        pyq_years_access: -1,           // Keep unlimited for PYQ years
        offline_enabled: true,
        offline_solutions_limit: -1,    // Keep unlimited for offline
        max_devices: 1  // P0: Single session for all tiers (P1 will change to 2)
      },
      features: {
        analytics_access: 'full'
      },
      pricing: {
        monthly: {
          price: 49900,
          display_price: '499',
          per_month_price: '499',
          duration_days: 30,
          savings_percent: 0,
          badge: null
        },
        quarterly: {
          price: 119700,
          display_price: '1,197',
          per_month_price: '399',
          duration_days: 90,
          savings_percent: 20,
          badge: 'MOST POPULAR'
        },
        annual: {
          price: 358800,
          display_price: '3,588',
          per_month_price: '299',
          duration_days: 365,
          savings_percent: 40,
          badge: 'BEST VALUE'
        }
      }
    }
  }
};

async function updateTierConfig() {
  console.log('Initializing Firebase...');
  initFirebase();

  const db = admin.firestore();
  const configRef = db.collection('tier_config').doc('active');

  console.log('\nFetching current tier config...');
  const currentDoc = await configRef.get();

  if (currentDoc.exists) {
    const currentData = currentDoc.data();
    console.log('Current version:', currentData.version || 'unknown');
    console.log('Current tiers:', Object.keys(currentData.tiers || {}).join(', '));

    // Check if chapter_practice_enabled already exists
    const freeHasField = currentData.tiers?.free?.limits?.chapter_practice_enabled !== undefined;
    if (freeHasField) {
      console.log('\nchapter_practice_enabled field already exists in config.');
      console.log('Current values:');
      console.log('  - free:', currentData.tiers?.free?.limits?.chapter_practice_enabled);
      console.log('  - pro:', currentData.tiers?.pro?.limits?.chapter_practice_enabled);
      console.log('  - ultra:', currentData.tiers?.ultra?.limits?.chapter_practice_enabled);

      const readline = require('readline');
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      });

      const answer = await new Promise(resolve => {
        rl.question('\nOverwrite with new config? (y/N): ', resolve);
      });
      rl.close();

      if (answer.toLowerCase() !== 'y') {
        console.log('Aborted.');
        process.exit(0);
      }
    }
  } else {
    console.log('No existing tier config found. Will create new one.');
  }

  console.log('\nUpdating tier config...');
  await configRef.set({
    ...UPDATED_TIER_CONFIG,
    updated_at: new Date().toISOString(),
    updated_by: 'update-tier-config script'
  }, { merge: false });

  console.log('\nTier config updated successfully!');
  console.log('New version:', UPDATED_TIER_CONFIG.version);

  console.log('\nmax_devices (anti-abuse):');
  console.log('  - free:', UPDATED_TIER_CONFIG.tiers.free.limits.max_devices);
  console.log('  - pro:', UPDATED_TIER_CONFIG.tiers.pro.limits.max_devices);
  console.log('  - ultra:', UPDATED_TIER_CONFIG.tiers.ultra.limits.max_devices);

  console.log('\nultra soft caps (anti-bot):');
  console.log('  - snap_solve_daily:', UPDATED_TIER_CONFIG.tiers.ultra.limits.snap_solve_daily);
  console.log('  - daily_quiz_daily:', UPDATED_TIER_CONFIG.tiers.ultra.limits.daily_quiz_daily);
  console.log('  - ai_tutor_messages_daily:', UPDATED_TIER_CONFIG.tiers.ultra.limits.ai_tutor_messages_daily);
  console.log('  - mock_tests_monthly:', UPDATED_TIER_CONFIG.tiers.ultra.limits.mock_tests_monthly);

  console.log('\nDone!');
  process.exit(0);
}

// Run the script
updateTierConfig().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
