/**
 * Assessment Service
 *
 * Handles initial assessment processing:
 * - Groups responses by chapter
 * - Calculates theta estimates per chapter
 * - Updates user profile with assessment results
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const {
  accuracyToThetaMapping,
  calculateInitialSE,
  calculateWeightedOverallTheta,
  calculateSubjectTheta,
  thetaToPercentile,
  boundTheta,
  calculateSubjectBalance,
  getSubjectFromChapter,
  formatChapterKey,
  expandBroadChaptersToSpecific,
  isBroadChapter
} = require('./thetaCalculationService');

// ============================================================================
// ASSESSMENT PROCESSING
// ============================================================================

/**
 * Calculate subject-level accuracy (percentage of correct answers per subject)
 * 
 * @param {Array} responses - Array of enriched response objects with is_correct and subject
 * @returns {Object} Dict of {subject: {accuracy: number, correct: number, total: number}}
 */
function calculateSubjectAccuracy(responses) {
  const subjectStats = {
    physics: { correct: 0, total: 0 },
    chemistry: { correct: 0, total: 0 },
    mathematics: { correct: 0, total: 0 }
  };
  
  for (const response of responses) {
    const { subject, is_correct } = response;
    
    if (!subject || typeof is_correct !== 'boolean') {
      continue;
    }
    
    const subjectLower = subject.toLowerCase();
    if (subjectStats[subjectLower]) {
      subjectStats[subjectLower].total++;
      if (is_correct) {
        subjectStats[subjectLower].correct++;
      }
    }
  }
  
  // Calculate accuracy percentages
  const result = {};
  for (const [subject, stats] of Object.entries(subjectStats)) {
    if (stats.total > 0) {
      result[subject] = {
        accuracy: Math.round((stats.correct / stats.total) * 100), // Percentage (0-100)
        correct: stats.correct,
        total: stats.total
      };
    } else {
      result[subject] = {
        accuracy: null,
        correct: 0,
        total: 0
      };
    }
  }
  
  return result;
}

/**
 * Group assessment responses by chapter
 * 
 * @param {Array} responses - Array of response objects
 * @returns {Object} Dict of {chapter_key: [responses]}
 */
function groupResponsesByChapter(responses) {
  const chapterGroups = {};
  const skippedResponses = [];
  
  for (const response of responses) {
    const { subject, chapter } = response;
    if (!subject || !chapter) {
      console.warn(`Response ${response.question_id} missing subject or chapter`);
      skippedResponses.push(response.question_id);
      continue;
    }
    
    // Format: {subject}_{chapter} (e.g., "physics_mechanics")
    const chapterKey = formatChapterKey(subject, chapter);
    
    // Validate chapter key is valid format
    if (!chapterKey || chapterKey.length < 3 || !chapterKey.includes('_')) {
      console.warn(
        `Invalid chapter key generated for question ${response.question_id}: ` +
        `"${chapterKey}" from subject="${subject}", chapter="${chapter}"`
      );
      skippedResponses.push(response.question_id);
      continue;
    }
    
    if (!chapterGroups[chapterKey]) {
      chapterGroups[chapterKey] = [];
    }
    
    chapterGroups[chapterKey].push(response);
  }
  
  // Log if any responses were skipped
  if (skippedResponses.length > 0) {
    console.warn(
      `Skipped ${skippedResponses.length} responses due to missing/invalid subject/chapter: ` +
      skippedResponses.join(', ')
    );
  }
  
  return chapterGroups;
}

/**
 * Process initial assessment and calculate theta estimates
 * 
 * @param {string} userId - Firebase Auth UID
 * @param {Array} enrichedResponses - Array of enriched response objects with:
 *   - question_id: string
 *   - student_answer: string
 *   - correct_answer: string (from question data)
 *   - is_correct: boolean (calculated)
 *   - time_taken_seconds: number
 *   - subject: string (from question data)
 *   - chapter: string (from question data)
 * @returns {Promise<Object>} Assessment results with theta estimates
 */
async function processInitialAssessment(userId, enrichedResponses) {
  try {
    // Validate input
    if (!userId || !enrichedResponses || !Array.isArray(enrichedResponses)) {
      throw new Error('Invalid input: userId and enrichedResponses array required');
    }
    
    if (enrichedResponses.length !== 30) {
      throw new Error(`Expected 30 responses, got ${enrichedResponses.length}`);
    }
    
    // Step 1: Group responses by chapter
    const chapterGroups = groupResponsesByChapter(enrichedResponses);
    
    // Validate that we have at least some chapters
    if (Object.keys(chapterGroups).length === 0) {
      throw new Error(
        'No valid chapters found in responses. ' +
        'All responses may be missing subject or chapter fields. ' +
        'Please ensure all questions have valid subject and chapter data.'
      );
    }
    
    console.log(`Grouped responses into ${Object.keys(chapterGroups).length} chapters`);
    
    // Step 2: Calculate per-chapter theta estimates
    const thetaEstimates = {};
    const chapterAttemptCounts = {};
    
    for (const [chapterKey, chapterResponses] of Object.entries(chapterGroups)) {
      // Validate chapter has responses
      if (!chapterResponses || chapterResponses.length === 0) {
        console.warn(`Chapter ${chapterKey} has no responses, skipping`);
        continue;
      }
      
      const correctCount = chapterResponses.filter(r => r.is_correct === true).length;
      const totalCount = chapterResponses.length;
      
      // Validate totalCount > 0 (defensive check)
      if (totalCount === 0) {
        console.warn(`Chapter ${chapterKey} has zero total count, skipping`);
        continue;
      }
      
      const accuracy = correctCount / totalCount;
      
      // Validate accuracy is a valid number
      if (isNaN(accuracy) || !isFinite(accuracy)) {
        throw new Error(
          `Invalid accuracy calculated for chapter ${chapterKey}: ` +
          `correctCount=${correctCount}, totalCount=${totalCount}`
        );
      }
      
      // Map accuracy to initial theta
      const initialTheta = accuracyToThetaMapping(accuracy, totalCount);
      
      // Calculate standard error
      const standardError = calculateInitialSE(totalCount, accuracy);
      
      // Store theta estimate (with rounded values)
      thetaEstimates[chapterKey] = {
        theta: boundTheta(initialTheta),
        percentile: thetaToPercentile(initialTheta),
        confidence_SE: standardError,
        attempts: totalCount,
        accuracy: Math.round(accuracy * 1000) / 1000, // 3 decimal places
        last_updated: new Date().toISOString()
      };
      
      chapterAttemptCounts[chapterKey] = totalCount;
    }

    // Step 2.5: Expand broad chapters to specific chapters
    // This distributes theta from "Mechanics" to kinematics, laws_of_motion, etc.
    const broadChapterCount = Object.keys(thetaEstimates).filter(k => isBroadChapter(k)).length;
    const expandedThetaEstimates = expandBroadChaptersToSpecific(thetaEstimates);

    console.log(
      `Expanded ${broadChapterCount} broad chapters to ${Object.keys(expandedThetaEstimates).length} total chapters`
    );

    // Use expanded estimates for all subsequent calculations
    const finalThetaEstimates = expandedThetaEstimates;

    // Step 3: Calculate subject-level theta estimates (using expanded chapters)
    const thetaBySubject = {
      physics: calculateSubjectTheta(finalThetaEstimates, 'physics'),
      chemistry: calculateSubjectTheta(finalThetaEstimates, 'chemistry'),
      mathematics: calculateSubjectTheta(finalThetaEstimates, 'mathematics')
    };
    
    // Step 3.5: Calculate subject-level accuracy (percentage of correct answers)
    const subjectAccuracy = calculateSubjectAccuracy(enrichedResponses);

    // Step 4: Calculate weighted overall theta (by JEE chapter importance)
    const overallTheta = calculateWeightedOverallTheta(finalThetaEstimates);
    const overallPercentile = thetaToPercentile(overallTheta);

    // Step 5: Calculate subject balance
    const subjectBalance = calculateSubjectBalance(finalThetaEstimates);

    // Step 6: Count chapters explored (count expanded specific chapters)
    const chaptersExplored = Object.keys(finalThetaEstimates).length;
    const chaptersConfident = Object.values(finalThetaEstimates).filter(
      c => c.attempts >= 2 || c.is_derived // Derived chapters inherit confidence
    ).length;
    
    // Step 7: Prepare assessment results
    const assessmentResults = {
      assessment: {
        status: 'completed',
        started_at: null, // Should be set when assessment starts
        completed_at: new Date().toISOString(),
        time_taken_seconds: enrichedResponses.reduce((sum, r) => {
          const time = r.time_taken_seconds || 0;
          // Validate time is a valid number
          if (isNaN(time) || time < 0) {
            console.warn(`Invalid time_taken_seconds for question ${r.question_id}: ${time}, using 0`);
            return sum;
          }
          return sum + time;
        }, 0),
        responses: enrichedResponses.map(r => ({
          question_id: r.question_id,
          response_id: r.response_id || `resp_${userId}_${r.question_id}_${Date.now()}`,
          is_correct: r.is_correct,
          time_taken_seconds: r.time_taken_seconds
        }))
      },
      // Chapter-level theta (PRIMARY - used for quiz generation)
      // Contains both original broad chapters AND expanded specific chapters
      theta_by_chapter: finalThetaEstimates,
      // Subject-level theta (DERIVED - for mobile app display)
      theta_by_subject: thetaBySubject,
      // Subject-level accuracy (percentage of correct answers per subject)
      subject_accuracy: subjectAccuracy,
      // Overall metrics
      overall_theta: overallTheta,
      overall_percentile: overallPercentile,
      completed_quiz_count: 0,
      current_day: 0,
      learning_phase: 'exploration',
      phase_switched_at_quiz: null,
      assessment_completed_at: new Date().toISOString(),
      last_quiz_completed_at: null,
      total_questions_solved: 30, // Initial assessment
      total_time_spent_minutes: Math.round(
        enrichedResponses.reduce((sum, r) => {
          const time = r.time_taken_seconds || 0;
          if (isNaN(time) || time < 0) {
            return sum;
          }
          return sum + time;
        }, 0) / 60
      ),
      chapter_attempt_counts: chapterAttemptCounts,
      chapters_explored: chaptersExplored,
      chapters_confident: chaptersConfident,
      subject_balance: subjectBalance
    };
    
    // Step 8 & 9: Update user profile and save responses atomically in transaction
    await saveAssessmentWithTransaction(userId, assessmentResults, enrichedResponses);
    
    return assessmentResults;
  } catch (error) {
    console.error('Error processing initial assessment:', {
      userId,
      responseCount: enrichedResponses?.length,
      error: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    });
    throw error;
  }
}

/**
 * Save assessment results atomically using Firestore transaction
 * Updates user profile and saves responses in a single atomic operation
 *
 * @param {string} userId - Firebase Auth UID
 * @param {Object} assessmentResults - Assessment results object
 * @param {Array} responses - Array of response objects
 */
async function saveAssessmentWithTransaction(userId, assessmentResults, responses) {
  // Validate transaction size before attempting
  // Firestore limit: 500 writes per transaction
  // We write: 1 user document + N response documents
  const totalWrites = 1 + responses.length;
  if (totalWrites > 450) { // Safety margin (90% of limit)
    throw new Error(
      `Transaction too large: ${totalWrites} writes (max 450 for safety, Firestore limit 500). ` +
      `Cannot save ${responses.length} responses in single transaction.`
    );
  }

  // Clear old responses BEFORE transaction (for retakes during testing)
  // This must happen outside the transaction since we can't mix regular deletes with transaction writes
  const oldResponsesRef = db.collection('assessment_responses')
    .doc(userId)
    .collection('responses');

  try {
    const oldResponsesSnap = await oldResponsesRef.get();
    if (!oldResponsesSnap.empty) {
      // Delete in batches of 500 (Firestore batch limit)
      const batchSize = 500;
      const batches = [];
      let currentBatch = db.batch();
      let operationCounter = 0;

      oldResponsesSnap.docs.forEach((doc) => {
        currentBatch.delete(doc.ref);
        operationCounter++;

        if (operationCounter === batchSize) {
          batches.push(currentBatch.commit());
          currentBatch = db.batch();
          operationCounter = 0;
        }
      });

      // Commit the last batch if it has operations
      if (operationCounter > 0) {
        batches.push(currentBatch.commit());
      }

      await Promise.all(batches);
      logger.info('Cleared old assessment responses', { userId, deletedCount: oldResponsesSnap.size });
    }
  } catch (deleteError) {
    // Log but don't fail - we can still save new responses
    logger.error('Error clearing old responses (continuing anyway)', {
      userId,
      error: deleteError.message
    });
  }

  // Now run the transaction to save user profile and new responses
  await retryFirestoreOperation(async () => {
    return await db.runTransaction(async (transaction) => {
      const userRef = db.collection('users').doc(userId);

      // TEMPORARILY DISABLED FOR TESTING: Allow overwriting completed assessments
      // TODO: Re-enable this check before production
      // Read user document to check status and prevent race conditions
      const userDoc = await transaction.get(userRef);

      // if (userDoc.exists) {
      //   const userData = userDoc.data();
      //   if (userData.assessment?.status === 'completed') {
      //     // Check error code to provide better message
      //     const error = new Error('Assessment already completed. Cannot submit again.');
      //     error.code = 'ASSESSMENT_ALREADY_COMPLETED';
      //     error.statusCode = 400;
      //     throw error;
      //   }
      // }

      // Create baseline snapshot (deep copy for preservation)
      const baselineSnapshot = {
        theta_by_chapter: JSON.parse(JSON.stringify(assessmentResults.theta_by_chapter)),
        theta_by_subject: JSON.parse(JSON.stringify(assessmentResults.theta_by_subject)),
        overall_theta: assessmentResults.overall_theta,
        overall_percentile: assessmentResults.overall_percentile,
        captured_at: assessmentResults.assessment_completed_at
      };

      // Update user profile atomically
      transaction.set(userRef, {
        assessment: assessmentResults.assessment,
        theta_by_chapter: assessmentResults.theta_by_chapter,
        theta_by_subject: assessmentResults.theta_by_subject,
        subject_accuracy: assessmentResults.subject_accuracy,
        overall_theta: assessmentResults.overall_theta,
        overall_percentile: assessmentResults.overall_percentile,
        completed_quiz_count: assessmentResults.completed_quiz_count,
        current_day: assessmentResults.current_day,
        learning_phase: assessmentResults.learning_phase,
        phase_switched_at_quiz: assessmentResults.phase_switched_at_quiz,
        assessment_completed_at: assessmentResults.assessment_completed_at,
        last_quiz_completed_at: assessmentResults.last_quiz_completed_at,
        total_questions_solved: assessmentResults.total_questions_solved,
        total_time_spent_minutes: assessmentResults.total_time_spent_minutes,
        chapter_attempt_counts: assessmentResults.chapter_attempt_counts,
        chapters_explored: assessmentResults.chapters_explored,
        chapters_confident: assessmentResults.chapters_confident,
        subject_balance: assessmentResults.subject_balance,
        assessment_baseline: baselineSnapshot  // Add baseline snapshot
      }, { merge: true });

      // Save individual responses in the same transaction
      const responsesRef = db.collection('assessment_responses')
        .doc(userId)
        .collection('responses');

      responses.forEach((response, index) => {
        // Validate response_id if provided by client
        let responseId;
        if (response.response_id) {
          // Validate format (alphanumeric, underscore, dash, 1-200 chars)
          if (!/^[a-zA-Z0-9_-]{1,200}$/.test(response.response_id)) {
            throw new Error(
              `Invalid response_id format for question ${response.question_id}: ` +
              `"${response.response_id}". Must be alphanumeric, underscore, or dash, 1-200 characters.`
            );
          }
          responseId = response.response_id;
        } else {
          // Generate unique ID with random component to prevent collisions
          const randomSuffix = Math.random().toString(36).substring(2, 9);
          responseId = `resp_${userId}_${response.question_id}_${Date.now()}_${index}_${randomSuffix}`;
        }

        const responseDoc = {
          response_id: responseId,
          student_id: userId,
          question_id: response.question_id,
          student_answer: response.student_answer,
          correct_answer: response.correct_answer,
          is_correct: response.is_correct,
          time_taken_seconds: response.time_taken_seconds,
          subject: response.subject,
          chapter: response.chapter,
          chapter_key: formatChapterKey(response.subject, response.chapter),
          answered_at: admin.firestore.FieldValue.serverTimestamp(),
          created_at: admin.firestore.FieldValue.serverTimestamp()
        };

        transaction.set(responsesRef.doc(responseId), responseDoc);
      });

      // Transaction will commit automatically if no errors
      console.log(`Transaction prepared: updating user profile and saving ${responses.length} responses for ${userId}`);
    });
  });

  console.log(`Successfully saved assessment results for ${userId}`);
}

/**
 * Validate raw assessment responses from client
 * (Before enrichment with question data)
 * 
 * @param {Array} responses - Array of raw response objects from client
 * @returns {Object} {valid: boolean, errors: string[]}
 */
function validateAssessmentResponses(responses) {
  const errors = [];
  
  if (!Array.isArray(responses)) {
    errors.push('Responses must be an array');
    return { valid: false, errors };
  }
  
  if (responses.length !== 30) {
    errors.push(`Expected 30 responses, got ${responses.length}`);
  }
  
  // Check for duplicate question_ids
  const questionIds = new Set();
  
  for (let i = 0; i < responses.length; i++) {
    const r = responses[i];
    
    if (!r.question_id) {
      errors.push(`Response ${i + 1}: missing question_id`);
    } else {
      // Check for duplicates
      if (questionIds.has(r.question_id)) {
        errors.push(`Response ${i + 1}: Duplicate question_id ${r.question_id}`);
      }
      questionIds.add(r.question_id);
    }
    
    if (r.student_answer === undefined || r.student_answer === null) {
      errors.push(`Response ${i + 1}: missing student_answer`);
    }
    
    // Note: correct_answer, is_correct, subject, chapter are added during enrichment
    // They are not validated here as they come from question data, not client input
  }
  
  return {
    valid: errors.length === 0,
    errors
  };
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  processInitialAssessment,
  groupResponsesByChapter,
  validateAssessmentResponses,
  saveAssessmentWithTransaction,
  calculateSubjectAccuracy
};
