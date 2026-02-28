#!/usr/bin/env node
const { getUnlockedChapters } = require('../src/services/chapterUnlockService');

(async () => {
  const userId = 'whXKoBgqYQaD6NQafUDKGZcC5J42';

  console.log('Calling getUnlockedChapters service...\n');
  const unlockResult = await getUnlockedChapters(userId);

  console.log('UNLOCK RESULT:');
  console.log('- Current month:', unlockResult.currentMonth);
  console.log('- Months until exam:', unlockResult.monthsUntilExam);
  console.log('- Total unlocked:', unlockResult.unlockedChapterKeys.length);
  console.log('- Is legacy user:', unlockResult.isLegacyUser);

  console.log('\nUNLOCKED CHAPTERS:');
  const bySubject = { physics: [], chemistry: [], mathematics: [] };
  unlockResult.unlockedChapterKeys.forEach(ch => {
    if (ch.startsWith('physics_')) bySubject.physics.push(ch);
    else if (ch.startsWith('chemistry_')) bySubject.chemistry.push(ch);
    else if (ch.startsWith('mathematics_')) bySubject.mathematics.push(ch);
  });

  console.log(`\nPhysics (${bySubject.physics.length}):`);
  bySubject.physics.forEach(ch => console.log(`  - ${ch}`));
  console.log(`\nChemistry (${bySubject.chemistry.length}):`);
  bySubject.chemistry.forEach(ch => console.log(`  - ${ch}`));
  console.log(`\nMathematics (${bySubject.mathematics.length}):`);
  bySubject.mathematics.forEach(ch => console.log(`  - ${ch}`));

  process.exit(0);
})().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
