#!/usr/bin/env node

/**
 * Isar Update Checker
 *
 * Checks pub.dev for new versions of isar_flutter_libs and alerts if SDK 36 support is available.
 *
 * Usage:
 *   node scripts/check-isar-update.js
 *
 * Background:
 *   isar_flutter_libs 3.1.0+1 is incompatible with Android SDK 36 (lStar attribute error).
 *   We're waiting for an update that supports SDK 36 before re-enabling offline mode.
 */

const https = require('https');

const PACKAGE_NAME = 'isar_flutter_libs';
const CURRENT_VERSION = '3.1.0+1';
const PUB_DEV_API = `https://pub.dev/api/packages/${PACKAGE_NAME}`;

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

function compareVersions(v1, v2) {
  // Simple version comparison (handles x.y.z+build format)
  const parts1 = v1.split(/[.+]/).map(Number);
  const parts2 = v2.split(/[.+]/).map(Number);

  for (let i = 0; i < Math.max(parts1.length, parts2.length); i++) {
    const p1 = parts1[i] || 0;
    const p2 = parts2[i] || 0;
    if (p1 > p2) return 1;
    if (p1 < p2) return -1;
  }
  return 0;
}

async function checkForUpdates() {
  console.log(`🔍 Checking for ${PACKAGE_NAME} updates...\n`);

  try {
    const data = await fetchJson(PUB_DEV_API);
    const latestVersion = data.latest.version;
    const publishedDate = new Date(data.latest.published).toLocaleDateString();

    console.log(`📦 Current version: ${CURRENT_VERSION}`);
    console.log(`📦 Latest version:  ${latestVersion} (published ${publishedDate})\n`);

    const comparison = compareVersions(latestVersion, CURRENT_VERSION);

    if (comparison > 0) {
      console.log('🎉 NEW VERSION AVAILABLE!\n');
      console.log('Next steps:');
      console.log('1. Check changelog: https://pub.dev/packages/isar_flutter_libs/changelog');
      console.log('2. Look for "Android SDK 36" or "compileSdk 36" mentions');
      console.log('3. If supported, update pubspec.yaml:');
      console.log(`   isar_flutter_libs: ^${latestVersion}`);
      console.log('4. Test Android build:');
      console.log('   cd mobile && flutter clean && flutter pub get && flutter build apk\n');

      // Fetch recent versions to show changelog
      const versions = data.versions.slice(-3).reverse();
      console.log('Recent versions:');
      versions.forEach(v => {
        console.log(`  - ${v.version} (${new Date(v.published).toLocaleDateString()})`);
      });

    } else if (comparison === 0) {
      console.log('✅ You\'re on the latest version.');
      console.log('⏳ Still waiting for Android SDK 36 support.');
      console.log('💡 Check again in 1-2 weeks, or watch: https://github.com/isar/isar/releases\n');

    } else {
      console.log(`⚠️  You're ahead of pub.dev (local: ${CURRENT_VERSION}, pub: ${latestVersion})`);
      console.log('This shouldn\'t happen unless you\'re using a git dependency.\n');
    }

    console.log('📚 Package page: https://pub.dev/packages/isar_flutter_libs');
    console.log('🐛 GitHub issues: https://github.com/isar/isar/issues');

  } catch (error) {
    console.error('❌ Error fetching package data:', error.message);
    console.error('Make sure you have internet connectivity.\n');
    process.exit(1);
  }
}

// Run the check
checkForUpdates();
