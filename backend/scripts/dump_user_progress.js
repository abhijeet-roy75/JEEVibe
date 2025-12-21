
require('dotenv').config();
const { db, admin } = require('../src/config/firebase');

async function dumpUserProgress(userId) {
    try {
        console.log('--- User Progress Diagnostic ---\n');

        if (!userId) {
            console.log('No userId provided. Looking for a recent user who completed a quiz...');
            const recentQuiz = await db.collectionGroup('quizzes')
                .where('status', '==', 'completed')
                .orderBy('completed_at', 'desc')
                .limit(1)
                .get();

            if (recentQuiz.empty) {
                console.error('No recent users found. Please provide a userId as an argument.');
                process.exit(1);
            }
            userId = recentQuiz.docs[0].ref.parent.parent.id;
            console.log(`Using recent user: ${userId}\n`);
        }

        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            console.error(`User ${userId} not found.`);
            process.exit(1);
        }

        const userData = userDoc.data();

        console.log('--- Global Stats ---');
        console.log(`- completed_quiz_count: ${userData.completed_quiz_count}`);
        console.log(`- total_questions_solved: ${userData.total_questions_solved}`);
        console.log(`- overall_theta: ${userData.overall_theta}`);
        console.log(`- overall_percentile: ${userData.overall_percentile}\n`);

        console.log('--- theta_by_subject ---');
        console.log(JSON.stringify(userData.theta_by_subject || {}, null, 2));
        console.log('\n');

        console.log('--- subject_accuracy (If exists) ---');
        console.log(JSON.stringify(userData.subject_accuracy || {}, null, 2));
        console.log('\n');

        console.log('--- theta_by_chapter (Summary) ---');
        const chapters = userData.theta_by_chapter || {};
        const chapterKeys = Object.keys(chapters);
        console.log(`Total chapters tracked: ${chapterKeys.length}`);
        if (chapterKeys.length > 0) {
            console.log('Sample chapter data (first 3):');
            chapterKeys.slice(0, 3).forEach(key => {
                console.log(`  - ${key}: ${JSON.stringify(chapters[key])}`);
            });
        }

        process.exit(0);
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
}

const targetUserId = process.argv[2];
dumpUserProgress(targetUserId);
