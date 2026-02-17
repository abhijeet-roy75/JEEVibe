#!/usr/bin/env node
/**
 * Diagnose Chapter Names in Questions Collection
 *
 * Checks what chapter names actually exist in Firestore for a given chapter key
 * to help debug "No questions found" errors.
 *
 * Usage:
 *   node scripts/diagnose-chapter-names.js physics_current_electricity
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');

async function diagnoseChapter(chapterKey) {
  console.log(`\n🔍 Diagnosing chapter: ${chapterKey}\n`);

  // Parse chapter key
  const parts = chapterKey.split('_');
  const subjectPart = parts[0];
  const chapterPart = parts.slice(1).join(' ');

  console.log('Parsed:');
  console.log(`  Subject part: ${subjectPart}`);
  console.log(`  Chapter part: ${chapterPart}\n`);

  // Get all unique subject/chapter combinations (including inactive)
  console.log('📊 Checking ALL questions (including inactive)...\n');
  const snapshot = await db.collection('questions')
    .select('subject', 'chapter', 'chapter_key', 'active')
    .get();

  const combinations = new Map();

  snapshot.forEach(doc => {
    const data = doc.data();
    const key = `${data.subject}:::${data.chapter}:::${data.chapter_key || 'null'}:::${data.active}`;
    if (!combinations.has(key)) {
      combinations.set(key, {
        subject: data.subject,
        chapter: data.chapter,
        chapter_key: data.chapter_key || null,
        active: data.active,
        count: 0
      });
    }
    combinations.get(key).count++;
  });

  console.log(`Total active questions: ${snapshot.size}`);
  console.log(`Unique subject/chapter combinations: ${combinations.size}\n`);

  // Filter to similar subjects (physics variants)
  const subjectLower = subjectPart.toLowerCase();
  const chapterLower = chapterPart.toLowerCase();

  const matches = Array.from(combinations.values())
    .filter(c =>
      c.subject.toLowerCase().includes(subjectLower) ||
      c.chapter.toLowerCase().includes(chapterLower)
    )
    .sort((a, b) => b.count - a.count);

  if (matches.length === 0) {
    console.log('❌ No matching subjects or chapters found!\n');
    console.log('Sample of what IS in the database:');
    const sample = Array.from(combinations.values()).slice(0, 10);
    sample.forEach(c => {
      console.log(`  "${c.subject}" / "${c.chapter}" [${c.chapter_key}] (${c.count} questions)`);
    });
  } else {
    console.log(`✅ Found ${matches.length} potential matches:\n`);
    matches.forEach(c => {
      const isExactSubject = c.subject.toLowerCase() === subjectLower;
      const isExactChapter = c.chapter.toLowerCase() === chapterLower;
      const marker = (isExactSubject && isExactChapter) ? '🎯' : '📍';
      const activeStatus = c.active ? '✅' : '❌';
      console.log(`${marker} ${activeStatus} "${c.subject}" / "${c.chapter}" [${c.chapter_key}] (${c.count} questions)`);
    });
  }

  console.log('\n');
  process.exit(0);
}

const chapterKey = process.argv[2] || 'physics_current_electricity';
diagnoseChapter(chapterKey).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
