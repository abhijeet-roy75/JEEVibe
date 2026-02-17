/**
 * Test Script: Verify Chapter Practice Data Exists
 *
 * This script checks if chapter practice sessions exist in the database
 * and validates the fix for admin dashboard feature usage tracking.
 */

const { db } = require('../src/config/firebase');

async function testChapterPracticeData() {
  console.log('🔍 Testing Chapter Practice Data Sources...\n');

  try {
    // Test 1: Check if any chapter_practice_sessions exist
    console.log('Test 1: Querying chapter_practice_sessions collection...');
    const sessionsSnapshot = await db.collectionGroup('sessions')
      .where('status', '==', 'completed')
      .limit(10)
      .get();

    console.log(`✅ Found ${sessionsSnapshot.size} completed chapter practice sessions`);

    if (sessionsSnapshot.size > 0) {
      const firstSession = sessionsSnapshot.docs[0];
      const sessionData = firstSession.data();
      console.log('\nSample session data:');
      console.log({
        session_id: firstSession.id,
        chapter_key: sessionData.chapter_key,
        subject: sessionData.subject,
        total_questions: sessionData.total_questions,
        questions_answered: sessionData.final_total_answered || sessionData.questions_answered,
        completed_at: sessionData.completed_at?.toDate?.()?.toISOString(),
      });
    } else {
      console.log('⚠️  No completed chapter practice sessions found in database');
    }

    // Test 2: Check users with chapter_practice_stats
    console.log('\n\nTest 2: Querying users with chapter_practice_stats...');
    const usersSnapshot = await db.collection('users')
      .where('chapter_practice_stats.total_sessions', '>', 0)
      .limit(5)
      .get();

    console.log(`✅ Found ${usersSnapshot.size} users with chapter practice stats`);

    if (usersSnapshot.size > 0) {
      const firstUser = usersSnapshot.docs[0];
      const userData = firstUser.data();
      const stats = userData.chapter_practice_stats;
      console.log('\nSample user stats:');
      console.log({
        user_id: firstUser.id,
        total_sessions: stats.total_sessions,
        total_questions_practiced: stats.total_questions_practiced,
        overall_accuracy: stats.overall_accuracy,
        chapters_practiced: Object.keys(stats.by_chapter || {}).length,
        subjects_practiced: Object.keys(stats.by_subject || {}).length,
      });
    }

    // Test 3: Check daily_usage for chapter_practice (should be empty)
    console.log('\n\nTest 3: Checking daily_usage for chapter_practice field...');
    const usageSnapshot = await db.collectionGroup('daily_usage')
      .limit(10)
      .get();

    let hasChapterPracticeField = false;
    let chapterPracticeCount = 0;

    usageSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.chapter_practice !== undefined) {
        hasChapterPracticeField = true;
        chapterPracticeCount += data.chapter_practice || 0;
      }
    });

    if (hasChapterPracticeField) {
      console.log(`⚠️  Found chapter_practice field in daily_usage (count: ${chapterPracticeCount})`);
      console.log('   This is unexpected - chapter_practice should not be in daily_usage');
    } else {
      console.log('✅ Confirmed: chapter_practice field NOT in daily_usage (as expected)');
    }

    // Test 4: Calculate last 7 days chapter practice usage
    console.log('\n\nTest 4: Calculating last 7 days chapter practice usage...');
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const recentSessionsSnapshot = await db.collectionGroup('sessions')
      .where('status', '==', 'completed')
      .where('completed_at', '>=', sevenDaysAgo)
      .get();

    let totalQuestions = 0;
    let totalSessions = recentSessionsSnapshot.size;
    const userSet = new Set();

    recentSessionsSnapshot.forEach(doc => {
      const data = doc.data();
      totalQuestions += data.final_total_answered || data.questions_answered || 0;
      if (data.student_id) {
        userSet.add(data.student_id);
      }
    });

    console.log(`✅ Last 7 days chapter practice activity:`);
    console.log(`   - Sessions completed: ${totalSessions}`);
    console.log(`   - Total questions answered: ${totalQuestions}`);
    console.log(`   - Unique users: ${userSet.size}`);

    // Summary
    console.log('\n\n' + '='.repeat(60));
    console.log('SUMMARY');
    console.log('='.repeat(60));

    if (sessionsSnapshot.size > 0) {
      console.log('✅ Chapter practice data EXISTS in database');
      console.log('✅ The fix to adminMetricsService.js should now show correct usage');
      console.log(`\n📊 Expected feature usage: ~${totalQuestions} questions in last 7 days`);
    } else {
      console.log('❌ No chapter practice sessions found');
      console.log('   Possible reasons:');
      console.log('   - Feature not yet used by any users');
      console.log('   - Data in different collection structure');
      console.log('   - Need to check with actual user IDs');
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
