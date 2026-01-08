#!/usr/bin/env node
/**
 * Check what chapter names are used in initial assessment questions
 */

require('dotenv').config();

const { db } = require('../src/config/firebase');
const { formatChapterKey } = require('../src/services/thetaCalculationService');

async function checkAssessmentChapters() {
  console.log('=' .repeat(70));
  console.log('📋 Initial Assessment Questions - Chapter Names');
  console.log('=' .repeat(70));
  console.log();

  const snapshot = await db.collection('initial_assessment_questions').get();
  const chapters = new Map();

  snapshot.forEach(doc => {
    const data = doc.data();
    const key = data.subject + '|||' + data.chapter;
    if (!chapters.has(key)) {
      chapters.set(key, { subject: data.subject, chapter: data.chapter, count: 0 });
    }
    chapters.get(key).count++;
  });

  console.log('Subject / Chapter → Generated Key:');
  for (const [_, data] of chapters.entries()) {
    const generatedKey = formatChapterKey(data.subject, data.chapter);
    console.log(`  "${data.subject}" / "${data.chapter}" (${data.count}q) → ${generatedKey}`);
  }

  console.log();
  console.log('=' .repeat(70));
  console.log('📋 Daily Quiz Questions - Chapter Names');
  console.log('=' .repeat(70));
  console.log();

  const quizSnapshot = await db.collection('questions').select('subject', 'chapter').get();
  const quizChapters = new Map();

  quizSnapshot.forEach(doc => {
    const data = doc.data();
    const key = data.subject + '|||' + data.chapter;
    if (!quizChapters.has(key)) {
      quizChapters.set(key, { subject: data.subject, chapter: data.chapter, count: 0 });
    }
    quizChapters.get(key).count++;
  });

  console.log('Subject / Chapter → Generated Key:');
  for (const [_, data] of quizChapters.entries()) {
    const generatedKey = formatChapterKey(data.subject, data.chapter);
    console.log(`  "${data.subject}" / "${data.chapter}" (${data.count}q) → ${generatedKey}`);
  }
}

checkAssessmentChapters()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
  });
