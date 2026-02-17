const { db } = require('../src/config/firebase');

async function checkQuestions() {
    console.log('Checking initial_assessment_questions for non-array options...');
    const snapshot = await db.collection('initial_assessment_questions').get();
    let count = 0;

    snapshot.forEach(doc => {
        const data = doc.data();
        const options = data.options;
        if (options && (typeof options !== 'object' || !Array.isArray(options))) {
            console.log(`Question ${doc.id} has weird options:`, typeof options, options);
            count++;
        }
    });

    console.log(`Finished. Found ${count} questions with non-array options.`);
    process.exit(0);
}

checkQuestions();
