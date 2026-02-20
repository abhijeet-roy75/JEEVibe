#!/usr/bin/env node
/**
 * Tier Management Script
 *
 * Grant or revoke tier access for users.
 * Supports both user IDs and phone numbers.
 *
 * Usage:
 *   node scripts/manage-tier.js <tier> <phone_or_id1> [phone_or_id2] ...
 *
 * Examples:
 *   # Grant Ultra access using phone numbers (90 days)
 *   node scripts/manage-tier.js ultra +919876543210 +919123456789
 *
 *   # Grant Ultra access using user IDs
 *   node scripts/manage-tier.js ultra user123 user456
 *
 *   # Mix phone numbers and user IDs
 *   node scripts/manage-tier.js ultra +919876543210 user456
 *
 *   # Grant Pro access (90 days)
 *   node scripts/manage-tier.js pro +919876543210
 *
 *   # Revoke access (back to Free)
 *   node scripts/manage-tier.js free +919876543210
 *
 *   # Custom duration (in days)
 *   node scripts/manage-tier.js ultra --days=30 +919876543210
 *
 *   # With custom reason
 *   node scripts/manage-tier.js ultra --reason="Beta Wave 2" +919876543210
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin (uses service account from environment or file)
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
    // Script is in backend/scripts/user-management/, go up two levels to backend/
    const serviceAccountPath = path.join(__dirname, '..', '..', 'serviceAccountKey.json');
    try {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } catch (e) {
      console.error('Error: Could not find Firebase credentials.');
      console.error('Either set GOOGLE_APPLICATION_CREDENTIALS env var or place serviceAccountKey.json in backend/');
      process.exit(1);
    }
  }

  return admin.app();
}

// Check if input looks like a phone number
function isPhoneNumber(input) {
  // Phone numbers start with + or are purely numeric with 10+ digits
  return input.startsWith('+') || /^\d{10,15}$/.test(input);
}

// Normalize phone number to E.164 format
function normalizePhoneNumber(phone) {
  // Remove any spaces or dashes
  let normalized = phone.replace(/[\s-]/g, '');

  // If it doesn't start with +, assume Indian number and add +91
  if (!normalized.startsWith('+')) {
    // If it starts with 0, remove it
    if (normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }
    // If it's a 10-digit number, add +91
    if (normalized.length === 10) {
      normalized = '+91' + normalized;
    }
  }

  return normalized;
}

// Look up user ID by phone number
async function getUserIdByPhone(db, phoneNumber) {
  const normalized = normalizePhoneNumber(phoneNumber);

  // Query users collection for matching phone number
  const snapshot = await db.collection('users')
    .where('phoneNumber', '==', normalized)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return null;
  }

  const userDoc = snapshot.docs[0];
  return {
    userId: userDoc.id,
    name: userDoc.data().firstName || userDoc.data().name || 'Unknown',
    phone: normalized
  };
}

// Parse command line arguments
function parseArgs(args) {
  const options = {
    tier: null,
    identifiers: [], // Can be phone numbers or user IDs
    days: 90,
    reason: 'Admin script',
  };

  for (const arg of args) {
    if (arg.startsWith('--days=')) {
      options.days = parseInt(arg.split('=')[1], 10);
    } else if (arg.startsWith('--reason=')) {
      options.reason = arg.split('=')[1];
    } else if (['free', 'pro', 'ultra'].includes(arg.toLowerCase())) {
      options.tier = arg.toLowerCase();
    } else if (!arg.startsWith('--')) {
      options.identifiers.push(arg);
    }
  }

  return options;
}

// Grant tier access to a user
async function grantAccess(db, userId, tier, days, reason) {
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + days);

  const overrideType = tier === 'ultra' ? 'beta_tester' : 'promotional';

  await db.collection('users').doc(userId).set({
    subscription: {
      tier: tier,
      override: {
        type: overrideType,
        tier_id: tier,
        granted_by: 'admin_script',
        expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
        reason: reason,
        granted_at: admin.firestore.FieldValue.serverTimestamp(),
      }
    }
  }, { merge: true });

  // Force cache invalidation by calling the subscription service
  // This ensures the mobile app gets fresh data on next API call
  try {
    const { invalidateTierCache } = require('../src/services/subscriptionService');
    invalidateTierCache(userId);
  } catch (e) {
    // Ignore if service not available in script context
  }

  return expiresAt;
}

// Revoke tier access (back to free)
async function revokeAccess(db, userId) {
  // Remove override AND expire trial by setting ends_at to past date
  const pastDate = new Date();
  pastDate.setDate(pastDate.getDate() - 1); // Yesterday

  await db.collection('users').doc(userId).update({
    'subscription.tier': 'free',
    'subscription.override': admin.firestore.FieldValue.delete(),
    'trial.is_active': false,
    'trial.ends_at': admin.firestore.Timestamp.fromDate(pastDate),
    'trialEndsAt': admin.firestore.Timestamp.fromDate(pastDate) // Support old format too
  });

  // Force cache invalidation by calling the subscription service
  // This ensures the mobile app gets fresh data on next API call
  try {
    const { invalidateTierCache } = require('../src/services/subscriptionService');
    invalidateTierCache(userId);
  } catch (e) {
    // Ignore if service not available in script context
  }
}

// Main function
async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log(`
Tier Management Script
======================

Usage:
  node scripts/manage-tier.js <tier> [options] <phone_or_id1> [phone_or_id2] ...

Tiers:
  ultra   - Grant Ultra tier (unlimited everything, AI tutor)
  pro     - Grant Pro tier (10 snaps, 10 quizzes, full analytics)
  free    - Revoke access (remove override, back to free)

Options:
  --days=N       Duration in days (default: 90)
  --reason=TEXT  Reason for grant (default: "Admin script")
  --help, -h     Show this help

Identifiers:
  You can use either phone numbers or user IDs:
  - Phone numbers: +919876543210, 9876543210, 09876543210
  - User IDs: abc123xyz (Firebase UID)

  Phone numbers are automatically normalized:
  - 9876543210 → +919876543210 (assumes India)
  - 09876543210 → +919876543210

Examples:
  # Grant Ultra using phone numbers
  node scripts/manage-tier.js ultra +919876543210 +919123456789

  # Grant Pro for 30 days
  node scripts/manage-tier.js pro --days=30 +919876543210

  # Revoke access (back to free)
  node scripts/manage-tier.js free +919876543210

  # Mix phone numbers and user IDs
  node scripts/manage-tier.js ultra +919876543210 user456

  # With custom reason
  node scripts/manage-tier.js ultra --reason="Beta Wave 1" +919876543210

  # List from file (one phone/ID per line)
  cat beta-users.txt | xargs node scripts/manage-tier.js ultra
`);
    process.exit(0);
  }

  const options = parseArgs(args);

  if (!options.tier) {
    console.error('Error: Must specify a tier (ultra, pro, or free)');
    process.exit(1);
  }

  if (options.identifiers.length === 0) {
    console.error('Error: Must specify at least one phone number or user ID');
    process.exit(1);
  }

  // Initialize Firebase
  initFirebase();
  const db = admin.firestore();

  console.log(`\n${'='.repeat(60)}`);
  console.log(`Tier Management: ${options.tier.toUpperCase()}`);
  console.log(`${'='.repeat(60)}`);
  console.log(`Identifiers: ${options.identifiers.length}`);
  if (options.tier !== 'free') {
    console.log(`Duration: ${options.days} days`);
    console.log(`Reason: ${options.reason}`);
  }
  console.log(`${'='.repeat(60)}\n`);

  let successCount = 0;
  let errorCount = 0;

  for (const identifier of options.identifiers) {
    try {
      let userId = identifier;
      let displayName = identifier;

      // Check if it's a phone number and resolve to user ID
      if (isPhoneNumber(identifier)) {
        const userInfo = await getUserIdByPhone(db, identifier);
        if (!userInfo) {
          console.log(`[SKIP] ${identifier} - Phone number not found`);
          errorCount++;
          continue;
        }
        userId = userInfo.userId;
        displayName = `${userInfo.name} (${userInfo.phone})`;
      } else {
        // It's a user ID - verify user exists
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          console.log(`[SKIP] ${userId} - User ID not found`);
          errorCount++;
          continue;
        }
        const userData = userDoc.data();
        displayName = `${userData.firstName || userData.name || 'Unknown'} (${userId.substring(0, 8)}...)`;
      }

      if (options.tier === 'free') {
        await revokeAccess(db, userId);
        console.log(`[REVOKED] ${displayName} - Back to FREE tier`);
      } else {
        const expiresAt = await grantAccess(db, userId, options.tier, options.days, options.reason);
        console.log(`[GRANTED] ${displayName} - ${options.tier.toUpperCase()} until ${expiresAt.toISOString().split('T')[0]}`);
      }
      successCount++;
    } catch (error) {
      console.log(`[ERROR] ${identifier} - ${error.message}`);
      errorCount++;
    }
  }

  console.log(`\n${'='.repeat(60)}`);
  console.log(`Summary: ${successCount} succeeded, ${errorCount} failed`);
  console.log(`${'='.repeat(60)}\n`);

  process.exit(errorCount > 0 ? 1 : 0);
}

main().catch(console.error);
