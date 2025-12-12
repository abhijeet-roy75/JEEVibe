/**
 * Stratified Randomization Service
 * 
 * Implements stratified randomization for assessment questions:
 * - Block 1 (Q1-10):  Warmup - Easy-Medium difficulty (b: 0.6-0.8)
 * - Block 2 (Q11-22): Core - Medium difficulty (b: 0.8-1.1)
 * - Block 3 (Q23-30): Challenge - Medium-Hard difficulty (b: 1.1-1.3)
 * 
 * Within each block:
 * - Randomizes question order (deterministic per user)
 * - Maintains subject interleaving (no 3+ consecutive same subject)
 * 
 * @version 2.0
 */

const crypto = require('crypto');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');

// ============================================================================
// CONSTANTS
// ============================================================================

// Block definitions based on IRT difficulty_b
const BLOCK_CONFIG = {
  warmup: {
    name: 'Warmup',
    difficulty_min: 0.6,
    difficulty_max: 0.8,
    target_count: 10,
    position_start: 1,
    position_end: 10
  },
  core: {
    name: 'Core Assessment',
    difficulty_min: 0.8,
    difficulty_max: 1.1,
    target_count: 12,
    position_start: 11,
    position_end: 22
  },
  challenge: {
    name: 'Challenge',
    difficulty_min: 1.1,
    difficulty_max: 1.3,
    target_count: 8,
    position_start: 23,
    position_end: 30
  }
};

// Subject distribution targets per block
const BLOCK_SUBJECT_DISTRIBUTION = {
  warmup: { physics: 3, chemistry: 3, mathematics: 4 },    // 10 total
  core: { physics: 4, chemistry: 4, mathematics: 4 },      // 12 total
  challenge: { physics: 3, chemistry: 3, mathematics: 2 }  // 8 total
};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Generate deterministic seed from user ID
 * Same user ID will always produce the same seed
 * 
 * @param {string} userId - Firebase Auth UID
 * @returns {number} Seed value
 */
function generateSeedFromUserId(userId) {
  const hash = crypto.createHash('md5').update(userId).digest('hex');
  return parseInt(hash.substring(0, 8), 16);
}

/**
 * Seeded random number generator (Linear Congruential Generator)
 * Same seed will produce the same sequence
 * 
 * @param {number} seed - Seed value
 * @returns {Function} Random function that returns [0, 1)
 */
function seededRandom(seed) {
  let state = seed;
  const a = 1664525;
  const c = 1013904223;
  const m = Math.pow(2, 32);
  
  return function() {
    state = (a * state + c) % m;
    return state / m;
  };
}

/**
 * Shuffle array using Fisher-Yates algorithm with seeded random
 * 
 * @param {Array} array - Array to shuffle
 * @param {Function} randomFn - Random function (0 to 1)
 * @returns {Array} Shuffled array (new array, original unchanged)
 */
function seededShuffle(array, randomFn) {
  const shuffled = [...array];
  
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(randomFn() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  
  return shuffled;
}

/**
 * Determine which block a question belongs to based on difficulty_b
 * 
 * @param {Object} question - Question object with irt_parameters
 * @returns {string} Block name ('warmup', 'core', 'challenge')
 */
function getQuestionBlock(question) {
  const difficultyB = question.irt_parameters?.difficulty_b || 
                      question.difficulty_b || 
                      0.9; // Default to medium
  
  if (difficultyB <= 0.8) {
    return 'warmup';
  } else if (difficultyB <= 1.1) {
    return 'core';
  } else {
    return 'challenge';
  }
}

/**
 * Find questions in adjacent difficulty range when block is short
 * Tries to maintain difficulty progression by selecting from nearby ranges
 * 
 * @param {Array} allQuestions - All available questions
 * @param {Object} blockConfig - Block configuration
 * @param {Set} selectedIds - Already selected question IDs (across ALL blocks)
 * @param {number} needed - Number of questions needed
 * @returns {Array} Questions from adjacent difficulty ranges
 */
function findQuestionsInAdjacentRange(allQuestions, blockConfig, selectedIds, needed) {
  const extras = [];
  const available = allQuestions.filter(q => !selectedIds.has(q.question_id));
  
  // Try to find questions close to the block's difficulty range
  // For warmup (0.6-0.8), try 0.5-0.9
  // For core (0.8-1.1), try 0.7-1.2
  // For challenge (1.1-1.3), try 1.0-1.4
  let minRange, maxRange;
  if (blockConfig.name === 'Warmup') {
    minRange = 0.5;
    maxRange = 0.9;
  } else if (blockConfig.name === 'Core Assessment') {
    minRange = 0.7;
    maxRange = 1.2;
  } else { // Challenge
    minRange = 1.0;
    maxRange = 1.4;
  }
  
  // Filter questions in adjacent range, sorted by distance from block range
  const candidates = available
    .map(q => {
      const difficultyB = q.irt_parameters?.difficulty_b || q.difficulty_b || 0.9;
      return {
        question: q,
        difficulty: difficultyB,
        distance: Math.abs(difficultyB - (blockConfig.difficulty_min + blockConfig.difficulty_max) / 2)
      };
    })
    .filter(item => item.difficulty >= minRange && item.difficulty <= maxRange)
    .sort((a, b) => a.distance - b.distance)
    .slice(0, needed)
    .map(item => item.question);
  
  return candidates;
}

/**
 * Calculate average difficulty of questions in a sequence
 * 
 * @param {Array} questions - Array of question objects
 * @returns {number} Average difficulty_b
 */
function calculateAverageDifficulty(questions) {
  if (questions.length === 0) return 0;
  
  const sum = questions.reduce((acc, q) => {
    const difficultyB = q.irt_parameters?.difficulty_b || q.difficulty_b || 0.9;
    return acc + difficultyB;
  }, 0);
  
  return sum / questions.length;
}

/**
 * Validate difficulty progression in final sequence
 * 
 * @param {Array} sequence - Final question sequence
 * @returns {Object} Validation result with warnings
 */
function validateDifficultyProgression(sequence) {
  const warmupAvg = calculateAverageDifficulty(sequence.slice(0, 10));
  const coreAvg = calculateAverageDifficulty(sequence.slice(10, 22));
  const challengeAvg = calculateAverageDifficulty(sequence.slice(22));
  
  const warnings = [];
  
  if (warmupAvg > coreAvg) {
    warnings.push(`Warmup block avg difficulty (${warmupAvg.toFixed(2)}) > Core block (${coreAvg.toFixed(2)})`);
  }
  
  if (coreAvg > challengeAvg) {
    warnings.push(`Core block avg difficulty (${coreAvg.toFixed(2)}) > Challenge block (${challengeAvg.toFixed(2)})`);
  }
  
  return {
    valid: warnings.length === 0,
    warnings,
    stats: {
      warmup_avg: warmupAvg.toFixed(2),
      core_avg: coreAvg.toFixed(2),
      challenge_avg: challengeAvg.toFixed(2)
    }
  };
}

/**
 * Group questions by subject
 * 
 * @param {Array} questions - Array of question objects
 * @returns {Object} { physics: [], chemistry: [], mathematics: [] }
 */
function groupBySubject(questions) {
  const groups = {
    physics: [],
    chemistry: [],
    mathematics: []
  };
  
  for (const question of questions) {
    const subject = question.subject?.toLowerCase() || 'unknown';
    if (groups[subject]) {
      groups[subject].push(question);
    }
  }
  
  return groups;
}

/**
 * Select questions with balanced subject distribution
 * 
 * @param {Object} subjectGroups - { physics: [], chemistry: [], mathematics: [] }
 * @param {Object} targetDistribution - { physics: 3, chemistry: 3, mathematics: 4 }
 * @param {Function} randomFn - Seeded random function
 * @returns {Array} Selected questions
 */
function selectBalancedQuestions(subjectGroups, targetDistribution, randomFn) {
  const selected = [];
  const selectedIds = new Set(); // Track IDs within this selection to prevent duplicates
  
  for (const [subject, targetCount] of Object.entries(targetDistribution)) {
    const available = (subjectGroups[subject] || [])
      .filter(q => !selectedIds.has(q.question_id)); // Exclude already selected in this batch
    const shuffled = seededShuffle(available, randomFn);
    const toSelect = shuffled.slice(0, Math.min(targetCount, shuffled.length));
    
    // Add to tracking
    toSelect.forEach(q => selectedIds.add(q.question_id));
    selected.push(...toSelect);
  }
  
  return selected;
}

/**
 * Interleave questions to prevent 3+ consecutive same subject
 * 
 * @param {Array} questions - Array of questions
 * @param {Function} randomFn - Seeded random function
 * @returns {Array} Interleaved questions
 */
function interleaveBySubject(questions, randomFn) {
  if (questions.length <= 2) {
    return questions;
  }
  
  const result = [];
  const remaining = [...questions];
  
  while (remaining.length > 0) {
    // Get subjects of last 2 questions
    const recentSubjects = result.slice(-2).map(q => q.subject?.toLowerCase());
    
    // Find questions that won't create 3+ consecutive same subject
    let validNext = remaining.filter(q => {
      const subject = q.subject?.toLowerCase();
      // If last 2 are same subject, don't allow that subject
      if (recentSubjects.length >= 2 && 
          recentSubjects[0] === recentSubjects[1] && 
          recentSubjects[0] === subject) {
        return false;
      }
      return true;
    });
    
    // If no valid options (shouldn't happen often), take any
    if (validNext.length === 0) {
      validNext = remaining;
    }
    
    // Randomly select from valid options
    const randomIndex = Math.floor(randomFn() * validNext.length);
    const chosen = validNext[randomIndex];
    
    // Validate chosen question is in remaining array
    const chosenIndex = remaining.indexOf(chosen);
    if (chosenIndex === -1) {
      throw new Error(
        'Interleaving logic error: Selected question not found in remaining array. ' +
        `This indicates a bug in the interleaving algorithm.`
      );
    }
    
    result.push(chosen);
    remaining.splice(chosenIndex, 1);
  }
  
  return result;
}

// ============================================================================
// MAIN FUNCTIONS
// ============================================================================

/**
 * Stratified randomization of assessment questions using block structure
 * 
 * Algorithm:
 * 1. Categorize questions by difficulty block (warmup/core/challenge)
 * 2. Within each block, group by subject
 * 3. Select balanced questions per subject per block
 * 4. Shuffle and interleave within each block
 * 5. Concatenate blocks in order
 * 
 * @param {Array} questions - Array of 30 assessment questions
 * @param {string} userId - Firebase Auth UID (for deterministic ordering)
 * @returns {Object} { sequence: [...], metadata: {...} }
 */
function stratifyAndRandomize(questions, userId) {
  if (!questions || questions.length === 0) {
    throw new Error('Questions array is required');
  }
  
  if (!userId) {
    throw new Error('User ID is required for deterministic randomization');
  }
  
  // Generate deterministic seed
  const seed = generateSeedFromUserId(userId);
  const randomFn = seededRandom(seed);
  
  // Step 1: Categorize questions by difficulty block
  // First, deduplicate questions by question_id (in case of duplicates in input)
  const uniqueQuestions = [];
  const seenIds = new Set();
  for (const question of questions) {
    const qId = question.question_id;
    if (seenIds.has(qId)) {
      console.warn(`Duplicate question_id in input array: ${qId}, skipping duplicate`);
      continue;
    }
    seenIds.add(qId);
    uniqueQuestions.push(question);
  }
  
  const questionsByBlock = {
    warmup: [],
    core: [],
    challenge: []
  };
  
  // Track questions added to blocks to prevent same question in multiple blocks
  const questionsInBlocks = new Set();
  
  for (const question of uniqueQuestions) {
    const qId = question.question_id;
    
    // Skip if already added to a block (shouldn't happen, but defensive)
    if (questionsInBlocks.has(qId)) {
      console.warn(`Question ${qId} already categorized into a block, skipping duplicate`);
      continue;
    }
    
    const block = getQuestionBlock(question);
    questionsByBlock[block].push(question);
    questionsInBlocks.add(qId);
  }
  
  // Step 2-4: Process each block
  const processedBlocks = {};
  // Track ALL selected question IDs across ALL blocks to prevent duplicates
  const allSelectedIds = new Set();
  
  for (const [blockName, blockConfig] of Object.entries(BLOCK_CONFIG)) {
    const blockQuestions = questionsByBlock[blockName];
    const targetDistribution = BLOCK_SUBJECT_DISTRIBUTION[blockName];
    
    // Deduplicate blockQuestions (defensive - in case same question appears multiple times)
    const uniqueBlockQuestions = [];
    const blockQuestionIds = new Set();
    for (const q of blockQuestions) {
      if (!blockQuestionIds.has(q.question_id)) {
        blockQuestionIds.add(q.question_id);
        uniqueBlockQuestions.push(q);
      }
    }
    
    // Group by subject
    const subjectGroups = groupBySubject(uniqueBlockQuestions);
    
    // Select balanced questions (excluding already selected questions)
    let selected = selectBalancedQuestions(subjectGroups, targetDistribution, randomFn)
      .filter(q => !allSelectedIds.has(q.question_id));
    
    // If not enough questions in block, supplement from adjacent difficulty ranges
    if (selected.length < blockConfig.target_count) {
      const needed = blockConfig.target_count - selected.length;
      const blockSelectedIds = new Set(selected.map(q => q.question_id));
      
      // Try to find questions in adjacent difficulty range first (excluding all previously selected)
      const extras = findQuestionsInAdjacentRange(questions, blockConfig, allSelectedIds, needed);
      
      // If still not enough, log warning and use any available questions
      if (selected.length + extras.length < blockConfig.target_count) {
        const stillNeeded = blockConfig.target_count - selected.length - extras.length;
        const currentBlockIds = new Set([...blockSelectedIds, ...extras.map(q => q.question_id)]);
        const fallback = questions
          .filter(q => !allSelectedIds.has(q.question_id) && !currentBlockIds.has(q.question_id))
          .slice(0, stillNeeded);
        
        console.warn(
          `Block ${blockName} has only ${selected.length + extras.length} questions, ` +
          `need ${blockConfig.target_count}. Using ${fallback.length} fallback questions.`
        );
        
        selected = [...selected, ...extras, ...fallback];
      } else {
        selected = [...selected, ...extras];
      }
    }
    
    // Final deduplication pass for selected (defensive - should not be needed)
    const deduplicatedSelected = [];
    const blockSelectedIds = new Set();
    for (const q of selected) {
      if (blockSelectedIds.has(q.question_id)) {
        console.error(`CRITICAL: Duplicate question in block ${blockName} after selection: ${q.question_id}, removing duplicate`);
        continue; // Skip duplicate
      }
      if (allSelectedIds.has(q.question_id)) {
        console.error(`CRITICAL: Question ${q.question_id} already selected in previous block, removing`);
        continue; // Skip
      }
      blockSelectedIds.add(q.question_id);
      allSelectedIds.add(q.question_id);
      deduplicatedSelected.push(q);
    }
    
    // If we removed duplicates, we might be short on questions - supplement if needed
    if (deduplicatedSelected.length < selected.length) {
      const removedCount = selected.length - deduplicatedSelected.length;
      console.warn(
        `Block ${blockName}: Removed ${removedCount} duplicate(s). ` +
        `Had ${selected.length}, now have ${deduplicatedSelected.length}, need ${blockConfig.target_count}`
      );
      
      // If we're now short, supplement with more questions
      if (deduplicatedSelected.length < blockConfig.target_count) {
        const stillNeeded = blockConfig.target_count - deduplicatedSelected.length;
        const currentBlockIds = new Set(deduplicatedSelected.map(q => q.question_id));
        const supplement = questions
          .filter(q => !allSelectedIds.has(q.question_id) && !currentBlockIds.has(q.question_id))
          .slice(0, stillNeeded);
        
        console.warn(
          `Block ${blockName}: Supplementing with ${supplement.length} additional question(s) after duplicate removal`
        );
        
        // Add supplements to tracking and selected
        supplement.forEach(q => {
          allSelectedIds.add(q.question_id);
          deduplicatedSelected.push(q);
        });
      }
    }
    
    selected = deduplicatedSelected;
    
    // Shuffle within block
    selected = seededShuffle(selected, randomFn);
    
    // Interleave to prevent subject clustering
    selected = interleaveBySubject(selected, randomFn);
    
    processedBlocks[blockName] = selected;
  }
  
  // Step 5: Concatenate blocks in order
  const finalSequence = [
    ...processedBlocks.warmup,
    ...processedBlocks.core,
    ...processedBlocks.challenge
  ];
  
  // Final deduplication pass (defensive - should not be needed if code is correct)
  const finalDeduplicated = [];
  const finalSeenIds = new Set();
  for (const question of finalSequence) {
    if (finalSeenIds.has(question.question_id)) {
      console.error(`CRITICAL: Duplicate question in final sequence: ${question.question_id}`);
      continue; // Skip duplicate
    }
    finalSeenIds.add(question.question_id);
    finalDeduplicated.push(question);
  }
  
  // Validate final sequence has exactly 30 questions
  if (finalDeduplicated.length !== 30) {
    throw new Error(
      `Invalid sequence: expected 30 questions, got ${finalDeduplicated.length}. ` +
      `Block counts: warmup=${processedBlocks.warmup.length}, ` +
      `core=${processedBlocks.core.length}, challenge=${processedBlocks.challenge.length}. ` +
      `${finalSequence.length - finalDeduplicated.length} duplicate(s) removed.`
    );
  }
  
  // Validate no duplicate questions (should pass after deduplication)
  const questionIds = new Set();
  for (const question of finalDeduplicated) {
    if (questionIds.has(question.question_id)) {
      throw new Error(`Duplicate question found in sequence after deduplication: ${question.question_id}`);
    }
    questionIds.add(question.question_id);
  }
  
  // Validate difficulty progression
  const progressionCheck = validateDifficultyProgression(finalSequence);
  if (!progressionCheck.valid) {
    console.warn('Difficulty progression warnings:', progressionCheck.warnings);
    console.warn('Difficulty stats:', progressionCheck.stats);
  }
  
  // Add position and block metadata to each question
  let position = 1;
  for (const question of finalDeduplicated) {
    question._position = position;
    question._block = position <= 10 ? 'warmup' : (position <= 22 ? 'core' : 'challenge');
    question._block_position = position <= 10 ? position : (position <= 22 ? position - 10 : position - 22);
    position++;
  }
  
  return finalDeduplicated;
}

/**
 * Get assessment questions with stratified randomization
 * Fetches from Firestore and applies block-based randomization
 * 
 * @param {string} userId - Firebase Auth UID
 * @param {Object} db - Firestore instance
 * @returns {Promise<Array>} Randomized questions array
 */
async function getRandomizedAssessmentQuestions(userId, db) {
  try {
    // Fetch all assessment questions with retry
    const questionsRef = db.collection('initial_assessment_questions');
    const snapshot = await retryFirestoreOperation(async () => {
      return await questionsRef.get();
    });
    
    if (snapshot.empty) {
      throw new Error('No assessment questions found in database');
    }
    
    const questions = [];
    const questionIdSet = new Set(); // Track to prevent duplicates
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const questionId = data.question_id || doc.id;
      
      // Skip if we've already seen this question_id (database might have duplicates)
      if (questionIdSet.has(questionId)) {
        console.warn(`Duplicate question_id found in database: ${questionId}, skipping duplicate`);
        return;
      }
      
      questionIdSet.add(questionId);
      questions.push({
        question_id: questionId,
        subject: data.subject,
        chapter: data.chapter,
        difficulty: data.difficulty,
        irt_parameters: data.irt_parameters,
        ...data // Include all question data
      });
    });
    
    // Validate question count before processing
    if (questions.length < 30) {
      throw new Error(
        `Insufficient questions: Expected at least 30 assessment questions, found ${questions.length}. ` +
        `Please ensure database has at least 30 questions in initial_assessment_questions collection.`
      );
    }
    
    if (questions.length > 30) {
      console.warn(
        `More than 30 questions found (${questions.length}). Using first 30 unique questions.`
      );
      // Take first 30 unique questions
      const unique30 = [];
      const seen = new Set();
      for (const q of questions) {
        if (unique30.length >= 30) break;
        if (!seen.has(q.question_id)) {
          seen.add(q.question_id);
          unique30.push(q);
        }
      }
      questions = unique30;
    }
    
    // Apply stratified randomization
    const randomized = stratifyAndRandomize(questions, userId);
    
    return randomized;
  } catch (error) {
    console.error('Error fetching randomized assessment questions:', error);
    throw error;
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  // Main functions
  stratifyAndRandomize,
  getRandomizedAssessmentQuestions,
  
  // Helper functions
  generateSeedFromUserId,
  getQuestionBlock,
  groupBySubject,
  interleaveBySubject,
  findQuestionsInAdjacentRange,
  calculateAverageDifficulty,
  validateDifficultyProgression,
  
  // Constants
  BLOCK_CONFIG,
  BLOCK_SUBJECT_DISTRIBUTION
};
