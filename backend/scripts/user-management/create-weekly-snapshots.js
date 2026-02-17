/**
 * Weekly Snapshot Creation Script
 * 
 * Creates weekly theta snapshots for all users.
 * Can be run manually or scheduled via cron.
 * 
 * Usage:
 *   node scripts/create-weekly-snapshots.js
 *   node scripts/create-weekly-snapshots.js --date 2024-12-10
 */

require('dotenv').config();
const { createWeeklySnapshotsForAllUsers } = require('../src/services/weeklySnapshotService');
const logger = require('../src/utils/logger');

async function main() {
  try {
    // Parse command line arguments
    const args = process.argv.slice(2);
    let snapshotDate = new Date();
    
    if (args.includes('--date')) {
      const dateIndex = args.indexOf('--date');
      if (dateIndex + 1 < args.length) {
        snapshotDate = new Date(args[dateIndex + 1]);
        if (isNaN(snapshotDate.getTime())) {
          throw new Error(`Invalid date: ${args[dateIndex + 1]}`);
        }
      }
    }
    
    logger.info('Starting weekly snapshot creation', {
      snapshotDate: snapshotDate.toISOString()
    });
    
    const results = await createWeeklySnapshotsForAllUsers(snapshotDate);
    
    console.log('\n=== Weekly Snapshot Creation Results ===');
    console.log(`Total users: ${results.total}`);
    console.log(`Snapshots created: ${results.created}`);
    console.log(`Errors: ${results.errors}`);
    
    if (results.errorDetails.length > 0) {
      console.log('\nError details:');
      results.errorDetails.forEach(({ userId, error }) => {
        console.log(`  - ${userId}: ${error}`);
      });
    }
    
    process.exit(0);
  } catch (error) {
    logger.error('Fatal error in weekly snapshot creation', {
      error: error.message,
      stack: error.stack
    });
    console.error('Fatal error:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { main };

