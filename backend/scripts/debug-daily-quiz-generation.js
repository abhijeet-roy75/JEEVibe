#!/usr/bin/env node
/**
 * Debug script to trace daily quiz generation
 * Identifies why only 3 questions are being returned instead of 10
 */

require('dotenv').config();

const { db } = require('../src/config/firebase');
const { formatChapterKey } = require('../src/services/thetaCalculationService');
const { getDatabaseNames } = require('../src/services/chapterMappingService');

async function debugQuizGeneration() {
  console.log('=' .repeat(70));
  console.log('🔍 Debug: Daily Quiz Question Selection');
  console.log('=' .repeat(70));
  console.log();

  // 1. Get a test user's theta_by_chapter
  const usersSnapshot = await db.collection('users')
    .where('assessment.status', '==', 'completed')
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.log('❌ No users with completed assessment found');
    return;
  }

  const userDoc = usersSnapshot.docs[0];
  const userData = userDoc.data();
  const userId = userDoc.id;
  const thetaByChapter = userData.theta_by_chapter || {};

  console.log(`📋 User: ${userId}`);
  console.log(`📊 Chapters with theta: ${Object.keys(thetaByChapter).length}`);
  console.log();

  // 2. List all user's chapters
  console.log('📋 User\'s theta_by_chapter:');
  for (const [key, data] of Object.entries(thetaByChapter)) {
    console.log(`   ${key}: θ=${data.theta?.toFixed(2) || 'N/A'}, is_derived=${data.is_derived || false}`);
  }
  console.log();

  // 3. Check chapter mapping for each
  console.log('=' .repeat(70));
  console.log('🔗 Chapter Key → Database Mapping');
  console.log('=' .repeat(70));
  console.log();

  const mappingResults = {};
  for (const chapterKey of Object.keys(thetaByChapter)) {
    const mapping = await getDatabaseNames(chapterKey);
    mappingResults[chapterKey] = mapping;

    if (mapping) {
      console.log(`✅ ${chapterKey}`);
      console.log(`   → Subject: "${mapping.subject}", Chapter: "${mapping.chapter}"`);
    } else {
      console.log(`❌ ${chapterKey}`);
      console.log(`   → NO MAPPING FOUND`);
    }
  }
  console.log();

  // 4. For each mapped chapter, count questions in question bank
  console.log('=' .repeat(70));
  console.log('📊 Question Counts by Mapped Chapter');
  console.log('=' .repeat(70));
  console.log();

  let totalQuestionsAvailable = 0;
  let chaptersWithQuestions = 0;
  let chaptersWithoutQuestions = 0;

  for (const [chapterKey, mapping] of Object.entries(mappingResults)) {
    if (!mapping) {
      console.log(`⏭️ ${chapterKey}: Skipped (no mapping)`);
      chaptersWithoutQuestions++;
      continue;
    }

    // Query questions for this exact subject/chapter combination
    const questionsSnapshot = await db.collection('questions')
      .where('subject', '==', mapping.subject)
      .where('chapter', '==', mapping.chapter)
      .get();

    const count = questionsSnapshot.size;
    totalQuestionsAvailable += count;

    if (count > 0) {
      chaptersWithQuestions++;
      console.log(`✅ ${chapterKey}: ${count} questions`);
    } else {
      chaptersWithoutQuestions++;
      console.log(`❌ ${chapterKey}: 0 questions (subject="${mapping.subject}", chapter="${mapping.chapter}")`);
    }
  }

  console.log();
  console.log('=' .repeat(70));
  console.log('📊 Summary');
  console.log('=' .repeat(70));
  console.log(`   User chapters: ${Object.keys(thetaByChapter).length}`);
  console.log(`   Chapters with questions: ${chaptersWithQuestions}`);
  console.log(`   Chapters without questions: ${chaptersWithoutQuestions}`);
  console.log(`   Total questions available: ${totalQuestionsAvailable}`);
  console.log();

  // 5. Show what questions collection actually has
  console.log('=' .repeat(70));
  console.log('📋 All Unique Subject/Chapter Combinations in Questions Collection');
  console.log('=' .repeat(70));
  console.log();

  const allQuestionsSnapshot = await db.collection('questions')
    .select('subject', 'chapter')
    .get();

  const uniqueCombos = new Map();
  allQuestionsSnapshot.forEach(doc => {
    const data = doc.data();
    const key = `${data.subject}|||${data.chapter}`;
    if (!uniqueCombos.has(key)) {
      uniqueCombos.set(key, { subject: data.subject, chapter: data.chapter, count: 0 });
    }
    uniqueCombos.get(key).count++;
  });

  const sortedCombos = Array.from(uniqueCombos.values())
    .sort((a, b) => a.subject.localeCompare(b.subject) || a.chapter.localeCompare(b.chapter));

  for (const combo of sortedCombos) {
    const generatedKey = formatChapterKey(combo.subject, combo.chapter);
    const hasMatch = thetaByChapter[generatedKey];
    const marker = hasMatch ? '✅' : '  ';
    console.log(`${marker} "${combo.subject}" / "${combo.chapter}" (${combo.count} questions) → ${generatedKey}`);
  }

  console.log();
  console.log('=' .repeat(70));
  console.log('✅ Debug Complete');
  console.log('=' .repeat(70));
}

debugQuizGeneration()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
  });
