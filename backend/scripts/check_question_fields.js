
require('dotenv').config();
const { db } = require('../src/config/firebase');

async function checkQuestionFields() {
    try {
        const snapshot = await db.collection('questions').limit(1).get();
        if (snapshot.empty) {
            console.log('No questions found in database.');
            process.exit(0);
        }

        const question = snapshot.docs[0].data();
        console.log('--- Question Data ---');
        console.log(JSON.stringify(question, null, 2));

        console.log('\n--- Field Checks ---');
        console.log('question_type:', question.question_type, `(${typeof question.question_type})`);
        console.log('subject:', question.subject, `(${typeof question.subject})`);
        console.log('chapter:', question.chapter, `(${typeof question.chapter})`);
        console.log('question_text:', question.question_text, `(${typeof question.question_text})`);

        if (question.options) {
            console.log('Options count:', question.options.length);
            if (question.options.length > 0) {
                console.log('Sample option:', JSON.stringify(question.options[0], null, 2));
            }
        }

        process.exit(0);
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
}

checkQuestionFields();
