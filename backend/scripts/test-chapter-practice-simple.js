/**
 * Simple Test: Verify Chapter Practice Data Exists
 * (No composite indexes required)
 */

const { db } = require('../src/config/firebase');

async function testChapterPracticeData() {
  console.log('🔍 Testing Chapter Practice Data Sources...\n');

  try {
    // Test 1: Check users with chapter_practice_stats
    console.log('Test 1: Querying users with chapter_practice_stats...');
    const usersSnapshot = await db.collection('users')
      .limit(100)
      .get();

    let usersWithStats = 0;
    let totalSessions = 0;
    let totalQuestions = 0;
    let sampleUser = null;

    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      if (userData.chapter_practice_stats && userData.chapter_practice_stats.total_sessions > 0) {
        usersWithStats++;
        totalSessions += userData.chapter_practice_stats.total_sessions;
        totalQuestions += userData.chapter_practice_stats.total_questions_practiced || 0;
        if (!sampleUser) {
          sampleUser = {
            user_id: doc.id,
            stats: userData.chapter_practice_stats
          };
        }
      }
    });

    console.log(`✅ Found ${usersWithStats} users with chapter practice stats (out of ${usersSnapshot.size} users checked)`);
    console.log(`   Total sessions: ${totalSessions}`);
    console.log(`   Total questions: ${totalQuestions}`);

    if (sampleUser) {
      console.log('\nSample user stats:');
      console.log({
        user_id: sampleUser.user_id,
        total_sessions: sampleUser.stats.total_sessions,
        total_questions_practiced: sampleUser.stats.total_questions_practiced,
        overall_accuracy: sampleUser.stats.overall_accuracy,
        chapters_practiced: Object.keys(sampleUser.stats.by_chapter || {}).length,
        subjects_practiced: Object.keys(sampleUser.stats.by_subject || {}).length,
      });

      // Test 2: Query actual sessions for this user
      console.log('\n\nTest 2: Querying chapter_practice_sessions for sample user...');
      const sessionsSnapshot = await db
        .collection('chapter_practice_sessions')
        .doc(sampleUser.user_id)
        .collection('sessions')
        .where('status', '==', 'completed')
        .limit(5)
        .get();

      console.log(`✅ Found ${sessionsSnapshot.size} completed sessions for user ${sampleUser.user_id}`);

      if (sessionsSnapshot.size > 0) {
        const firstSession = sessionsSnapshot.docs[0];
        const sessionData = firstSession.data();
        console.log('\nSample session data:');
        console.log({
          session_id: firstSession.id,
          chapter_key: sessionData.chapter_key,
          chapter_name: sessionData.chapter_name,
          subject: sessionData.subject,
          total_questions: sessionData.total_questions,
          questions_answered: sessionData.final_total_answered || sessionData.questions_answered,
          correct_count: sessionData.final_correct_count || sessionData.correct_count,
          accuracy: sessionData.final_accuracy,
          completed_at: sessionData.completed_at?.toDate?.()?.toISOString(),
        });
      }
    }

    // Test 3: Check daily_usage for chapter_practice (should NOT exist)
    console.log('\n\nTest 3: Checking daily_usage for chapter_practice field...');

    // Get first user and check their daily_usage
    if (usersSnapshot.size > 0) {
      const firstUser = usersSnapshot.docs[0];
      const dailyUsageSnapshot = await db
        .collection('users')
        .doc(firstUser.id)
        .collection('daily_usage')
        .limit(5)
        .get();

      let hasChapterPracticeField = false;
      dailyUsageSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.chapter_practice !== undefined) {
          hasChapterPracticeField = true;
          console.log(`   Found chapter_practice in daily_usage: ${data.chapter_practice}`);
        }
      });

      if (hasChapterPracticeField) {
        console.log('⚠️  Found chapter_practice field in daily_usage');
        console.log('   This is unexpected - chapter_practice should NOT be in daily_usage');
      } else {
        console.log('✅ Confirmed: chapter_practice field NOT in daily_usage (as expected)');
      }
    }

    // Summary
    console.log('\n\n' + '='.repeat(60));
    console.log('SUMMARY');
    console.log('='.repeat(60));

    if (usersWithStats > 0) {
      console.log('✅ Chapter practice data EXISTS in database');
      console.log('✅ The fix to adminMetricsService.js should now show correct usage');
      console.log(`\n📊 Statistics:`);
      console.log(`   - Users who practiced: ${usersWithStats}`);
      console.log(`   - Total sessions: ${totalSessions}`);
      console.log(`   - Total questions: ${totalQuestions}`);
      console.log(`   - Avg questions/session: ${totalSessions > 0 ? Math.round(totalQuestions / totalSessions) : 0}`);
    } else {
      console.log('⚠️  No chapter practice usage found in first 100 users');
      console.log('   This could mean:');
      console.log('   - Feature is not actively used yet');
      console.log('   - Need to check more users');
    }

    console.log('\n✅ Test completed successfully\n');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }

  process.exit(0);
}

// Run the test
testChapterPracticeData();
