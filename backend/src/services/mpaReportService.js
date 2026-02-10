const admin = require('firebase-admin');
const db = admin.firestore();
const moment = require('moment-timezone');

/**
 * MPA Report Service
 * Generates Weekly and Daily Mistake Pattern Analytics reports
 *
 * Based on: /docs/11-reports/JEEVibe_Weekly_MPA_Report_Specification.md
 */

// Chapter relationship mappings for clustering
const CHAPTER_CLUSTERS = {
  physics: {
    mechanics: ['physics_laws_of_motion', 'physics_work_energy_power', 'physics_rotational_motion',
                'physics_gravitation', 'physics_kinematics', 'physics_system_of_particles_and_rigid_body_dynamics'],
    electricity: ['physics_electrostatics', 'physics_current_electricity', 'physics_capacitance',
                  'physics_magnetic_effects_of_current'],
    waves_optics: ['physics_waves', 'physics_ray_optics', 'physics_wave_optics'],
    modern: ['physics_dual_nature_of_matter', 'physics_atoms_and_nuclei', 'physics_semiconductor_electronics']
  },
  chemistry: {
    physical: ['chemistry_thermodynamics', 'chemistry_chemical_kinetics', 'chemistry_equilibrium',
               'chemistry_electrochemistry', 'chemistry_solutions', 'chemistry_solid_state'],
    inorganic: ['chemistry_chemical_bonding', 'chemistry_periodic_table', 'chemistry_coordination_compounds',
                'chemistry_hydrogen', 'chemistry_s_block_elements', 'chemistry_p_block_elements', 'd_and_f_block_elements'],
    organic: ['chemistry_general_organic_chemistry', 'chemistry_hydrocarbons', 'chemistry_organic_compounds_containing_halogens',
              'chemistry_organic_compounds_containing_oxygen', 'chemistry_organic_compounds_containing_nitrogen',
              'chemistry_biomolecules', 'chemistry_polymers']
  },
  mathematics: {
    calculus: ['mathematics_differential_calculus', 'mathematics_integral_calculus', 'mathematics_limits_and_continuity',
               'mathematics_application_of_derivatives', 'mathematics_application_of_integrals', 'mathematics_differential_equations'],
    algebra: ['mathematics_quadratic_equations', 'mathematics_complex_numbers', 'mathematics_sequences_and_series',
              'mathematics_binomial_theorem', 'mathematics_permutations_and_combinations', 'mathematics_mathematical_induction'],
    coordinate_geometry: ['mathematics_straight_lines', 'mathematics_circles', 'mathematics_conic_sections',
                          'mathematics_parabola', 'mathematics_ellipse', 'mathematics_hyperbola', '3d_geometry'],
    trigonometry_vectors: ['mathematics_trigonometry', 'mathematics_inverse_trigonometric_functions', 'mathematics_vectors']
  }
};

/**
 * Generate Weekly MPA Report
 */
async function generateWeeklyReport(userId, weekStart, weekEnd) {
  try {
    console.log(`Generating weekly MPA report for user ${userId} (${weekStart} to ${weekEnd})`);

    // 1. Fetch all responses from the week
    const responses = await fetchWeekResponses(userId, weekStart, weekEnd);

    if (responses.length < 40) {
      console.log(`Insufficient data for ${userId}: ${responses.length} questions`);
      return null;
    }

    // 2. Calculate summary statistics
    const summary = calculateSummary(responses);

    // 3. Get user profile and baseline data
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    // 4. Get baseline from assessment
    const baseline = await getBaselineData(userId);

    // 5. Detect wins
    const wins = await detectWins({
      responses,
      summary,
      userData,
      baseline,
      timeframe: 'weekly'
    });

    // 6. Identify top 3 issues
    const incorrectResponses = responses.filter(r => !r.is_correct);
    const topIssues = await identifyTopIssues(incorrectResponses, summary, userData);

    // 7. Calculate potential improvement
    const potentialImprovement = calculatePotentialImprovement(summary, topIssues);

    // 8. Determine adaptive tone
    const tone = adaptContentToStudentLevel(summary.accuracy);

    return {
      week_id: `week_${moment(weekStart).format('YYYY-MM-DD')}`,
      week_start: moment(weekStart).format('YYYY-MM-DD'),
      week_end: moment(weekEnd).format('YYYY-MM-DD'),
      generated_at: admin.firestore.FieldValue.serverTimestamp(),

      summary,
      wins,
      top_issues: topIssues,
      potential_improvement: potentialImprovement,
      tone,

      email_sent: false,
      email_sent_at: null,
      email_opened: false,
      email_clicked: false
    };
  } catch (error) {
    console.error(`Error generating weekly report for ${userId}:`, error);
    throw error;
  }
}

/**
 * Generate Daily MPA Report (condensed version)
 */
async function generateDailyReport(userId, date) {
  try {
    const startOfDay = moment(date).startOf('day').toDate();
    const endOfDay = moment(date).endOf('day').toDate();

    console.log(`Generating daily MPA report for user ${userId} (${moment(date).format('YYYY-MM-DD')})`);

    // Fetch yesterday's responses
    const responses = await fetchWeekResponses(userId, startOfDay, endOfDay);

    // Always generate a report (even for 0 questions - re-engagement email)
    const hadActivity = responses.length > 0;

    const summary = calculateSummary(responses);
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    // Detect wins (return top 1)
    const allWins = await detectWins({
      responses,
      summary,
      userData,
      baseline: null,
      timeframe: 'daily'
    });
    const topWin = allWins[0] || createEffortWin(responses.length);

    // Detect issues (return top 1)
    const incorrectResponses = responses.filter(r => !r.is_correct);
    const allIssues = await identifyTopIssues(incorrectResponses, summary, userData);
    const topIssue = allIssues[0] || null;

    // Get streak data
    const streakDoc = await db.collection('practice_streaks').doc(userId).get();
    const streak = streakDoc.exists ? streakDoc.data() : { current_streak: 0 };

    // For zero activity, create a re-engagement win
    let finalWin = topWin;
    if (!hadActivity) {
      finalWin = {
        type: 'comeback',
        title: 'Time to Come Back!',
        metric: 'No practice yesterday',
        insight: 'Every day you skip makes it harder to build momentum. Even just 1 quiz can restart your progress!'
      };
    }

    return {
      date: moment(date).format('YYYY-MM-DD'),
      summary,
      win: finalWin,
      issue: hadActivity ? topIssue : null,
      streak: streak.current_streak || 0,
      hadActivity,
      cta: generateCTA(topIssue?.affected_chapters?.[0])
    };
  } catch (error) {
    console.error(`Error generating daily report for ${userId}:`, error);
    throw error;
  }
}

/**
 * Fetch responses for a given time period
 */
async function fetchWeekResponses(userId, startDate, endDate) {
  const responses = [];

  // Fetch from daily_quiz_responses
  const dailyQuizSnapshot = await db
    .collection('daily_quiz_responses')
    .doc(userId)
    .collection('responses')
    .where('answered_at', '>=', admin.firestore.Timestamp.fromDate(startDate))
    .where('answered_at', '<=', admin.firestore.Timestamp.fromDate(endDate))
    .get();

  dailyQuizSnapshot.forEach(doc => {
    responses.push({ ...doc.data(), response_id: doc.id });
  });

  // Fetch from chapter_practice_responses
  const chapterPracticeSnapshot = await db
    .collection('chapter_practice_responses')
    .doc(userId)
    .collection('responses')
    .where('answered_at', '>=', admin.firestore.Timestamp.fromDate(startDate))
    .where('answered_at', '<=', admin.firestore.Timestamp.fromDate(endDate))
    .get();

  chapterPracticeSnapshot.forEach(doc => {
    responses.push({ ...doc.data(), response_id: doc.id });
  });

  return responses;
}

/**
 * Calculate summary statistics
 */
function calculateSummary(responses) {
  const correct = responses.filter(r => r.is_correct).length;
  const incorrect = responses.length - correct;
  const accuracy = responses.length > 0 ? (correct / responses.length) * 100 : 0;

  // Group by subject
  const bySubject = {};
  ['Physics', 'Chemistry', 'Mathematics'].forEach(subject => {
    const subjectResponses = responses.filter(r => r.subject === subject);
    const subjectCorrect = subjectResponses.filter(r => r.is_correct).length;
    bySubject[subject.toLowerCase()] = {
      total: subjectResponses.length,
      correct: subjectCorrect,
      accuracy: subjectResponses.length > 0 ? (subjectCorrect / subjectResponses.length) * 100 : 0
    };
  });

  // Calculate days practiced
  const uniqueDates = new Set(
    responses.map(r => moment(r.answered_at.toDate()).format('YYYY-MM-DD'))
  );

  // Calculate total time
  const totalTime = responses.reduce((sum, r) => sum + (r.time_taken_seconds || 0), 0);

  return {
    total_questions: responses.length,
    correct,
    incorrect,
    accuracy: Math.round(accuracy * 10) / 10,
    by_subject: bySubject,
    days_practiced: uniqueDates.size,
    total_time_seconds: totalTime
  };
}

/**
 * Get baseline assessment data
 */
async function getBaselineData(userId) {
  try {
    const assessmentSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('assessments')
      .orderBy('completed_at', 'asc')
      .limit(1)
      .get();

    if (assessmentSnapshot.empty) {
      return null;
    }

    const assessment = assessmentSnapshot.docs[0].data();
    return {
      accuracy: assessment.overall_accuracy || 0,
      date: assessment.completed_at
    };
  } catch (error) {
    console.error('Error fetching baseline:', error);
    return null;
  }
}

/**
 * WIN DETECTION ALGORITHM
 * Returns top 2-3 wins calibrated to student level
 */
async function detectWins({ responses, summary, userData, baseline, timeframe }) {
  const wins = [];

  // WIN TYPE 1: Subject/Chapter Mastery (60%+ subject or 80%+ chapter)
  Object.entries(summary.by_subject).forEach(([subject, stats]) => {
    if (stats.accuracy >= 60 && stats.total >= 5) {
      // Find perfect chapters (80%+)
      const subjectResponses = responses.filter(r => r.subject.toLowerCase() === subject);
      const chapterStats = {};

      subjectResponses.forEach(r => {
        if (!chapterStats[r.chapter]) {
          chapterStats[r.chapter] = { total: 0, correct: 0 };
        }
        chapterStats[r.chapter].total++;
        if (r.is_correct) chapterStats[r.chapter].correct++;
      });

      const perfectChapters = Object.entries(chapterStats)
        .filter(([_, stats]) => stats.total >= 3 && (stats.correct / stats.total) >= 0.8)
        .map(([chapter, stats]) => ({
          chapter,
          accuracy: Math.round((stats.correct / stats.total) * 100)
        }))
        .sort((a, b) => b.accuracy - a.accuracy)
        .slice(0, 3);

      wins.push({
        rank: wins.length + 1,
        type: 'mastery',
        title: `${subject.charAt(0).toUpperCase() + subject.slice(1)} Mastery`,
        metric: `${Math.round(stats.accuracy)}% accuracy`,
        details: `You're crushing ${subject.charAt(0).toUpperCase() + subject.slice(1)}! ${stats.correct} out of ${stats.total} correct.`,
        top_chapters: perfectChapters,
        insight: generateMasteryInsight(subject, stats)
      });
    }
  });

  // WIN TYPE 2: Improvement from baseline (10%+ improvement)
  if (baseline && baseline.accuracy) {
    const improvement = summary.accuracy - baseline.accuracy;
    if (improvement >= 10) {
      wins.push({
        rank: wins.length + 1,
        type: 'improvement',
        title: 'Visible Improvement',
        metric: `+${Math.round(improvement)}% from assessment`,
        baseline: {
          label: 'Assessment',
          accuracy: Math.round(baseline.accuracy)
        },
        current: {
          label: timeframe === 'daily' ? 'Yesterday' : 'This week',
          accuracy: Math.round(summary.accuracy)
        },
        insight: `You improved ${Math.round(improvement)}% - practice is working!`
      });
    }
  }

  // WIN TYPE 3: Consistency (3+ days for weekly, 1 day for daily)
  const minDays = timeframe === 'daily' ? 1 : 3;
  if (summary.days_practiced >= minDays) {
    wins.push({
      rank: wins.length + 1,
      type: 'consistency',
      title: 'Practice Consistency',
      metric: timeframe === 'daily' ? `${summary.total_questions} questions` : `${summary.days_practiced}/7 days`,
      details: timeframe === 'daily'
        ? `You showed up yesterday and completed ${summary.total_questions} questions.`
        : `You showed up ${summary.days_practiced} days this week.`,
      insight: "Building this daily habit is how you'll reach your JEE goals."
    });
  }

  // WIN TYPE 4: Tough Questions (2+ correct with IRT > 2.0)
  const hardCorrect = responses.filter(r =>
    r.is_correct && (r.difficulty_b > 2.0 || r.question_irt_params?.b > 2.0)
  );
  if (hardCorrect.length >= 2) {
    wins.push({
      rank: wins.length + 1,
      type: 'tough_questions',
      title: 'Tough Questions Mastered',
      metric: `${hardCorrect.length} advanced questions`,
      insight: `You got ${hardCorrect.length} advanced questions right - only top 30% manage this!`
    });
  }

  // FALLBACK: If no wins, create effort win
  if (wins.length === 0) {
    wins.push(createEffortWin(summary.total_questions));
  }

  // Return top 2-3 wins
  return wins.slice(0, timeframe === 'daily' ? 1 : 3);
}

function createEffortWin(questionCount) {
  return {
    rank: 1,
    type: 'effort',
    title: 'You Showed Up',
    metric: `${questionCount} questions`,
    insight: "Consistency beats perfection. You're building the habit!"
  };
}

function generateMasteryInsight(subject, stats) {
  return `Your conceptual understanding and problem-solving skills are strong. This is your superpower!`;
}

/**
 * ISSUE DETECTION ALGORITHM
 * Returns top 3 issues ranked by ROI score
 */
async function identifyTopIssues(incorrectResponses, summary, userData) {
  if (incorrectResponses.length === 0) {
    return [];
  }

  const allPatterns = [];

  // PATTERN GROUP 1: Chapter Clusters
  const chapterClusters = groupByChapterClusters(incorrectResponses);
  chapterClusters.forEach(cluster => {
    if (cluster.questions.length >= 2) {
      allPatterns.push({
        type: 'chapter_cluster',
        title: cluster.title,
        frequency: cluster.questions.length,
        questions: cluster.questions,
        affected_chapters: cluster.chapters,
        fix_difficulty: estimateFixDifficulty(cluster)
      });
    }
  });

  // PATTERN GROUP 2: Concept Gaps
  const conceptGroups = groupByConcepts(incorrectResponses);
  Object.entries(conceptGroups).forEach(([concept, questions]) => {
    if (questions.length >= 2) {
      allPatterns.push({
        type: 'concept_gap',
        title: concept,
        frequency: questions.length,
        questions,
        affected_chapters: [...new Set(questions.map(q => q.chapter))],
        fix_difficulty: 'medium'
      });
    }
  });

  // Calculate ROI for each pattern
  allPatterns.forEach(pattern => {
    pattern.roi_score = calculateROIScore(pattern, incorrectResponses.length);
    pattern.percentage = Math.round((pattern.frequency / incorrectResponses.length) * 100);
    pattern.potential_gain = estimateImprovement(pattern, summary.total_questions);
  });

  // Sort by ROI and return top 3
  allPatterns.sort((a, b) => b.roi_score - a.roi_score);
  const top3 = allPatterns.slice(0, 3);

  // Assign priority and generate content
  return top3.map((issue, index) => generateIssueContent(issue, index, summary, userData));
}

/**
 * Group mistakes by chapter clusters
 */
function groupByChapterClusters(incorrectResponses) {
  const clusters = [];

  Object.entries(CHAPTER_CLUSTERS).forEach(([subject, groups]) => {
    Object.entries(groups).forEach(([groupName, chapterKeys]) => {
      const questionsInCluster = incorrectResponses.filter(r =>
        chapterKeys.includes(r.chapter_key)
      );

      if (questionsInCluster.length >= 2) {
        clusters.push({
          subject,
          groupName,
          title: `${subject.charAt(0).toUpperCase() + subject.slice(1)} ${groupName.charAt(0).toUpperCase() + groupName.slice(1)}`,
          questions: questionsInCluster,
          chapters: [...new Set(questionsInCluster.map(q => q.chapter))]
        });
      }
    });
  });

  return clusters;
}

/**
 * Group mistakes by concepts tested
 */
function groupByConcepts(incorrectResponses) {
  const conceptMap = {};

  incorrectResponses.forEach(r => {
    const concepts = r.concepts_tested || r.sub_topics || [];
    concepts.forEach(concept => {
      if (!conceptMap[concept]) {
        conceptMap[concept] = [];
      }
      conceptMap[concept].push(r);
    });
  });

  return conceptMap;
}

/**
 * Calculate ROI Score
 * Formula: ROI = (frequency × 0.4) + (impact × 0.3) + (ease_of_fix × 0.3)
 */
function calculateROIScore(pattern, totalMistakes) {
  // Frequency score (0-1)
  const frequencyScore = Math.min(pattern.frequency / totalMistakes, 1.0);

  // Impact score (0-1) - based on potential improvement
  const expectedImprovement = pattern.frequency / totalMistakes * 70; // 70% success rate
  const impactScore = Math.min(expectedImprovement / 20, 1.0);

  // Difficulty score (0-1) - easier = higher score
  const difficultyMap = {
    'easy': 1.0,
    'medium': 0.7,
    'hard': 0.4
  };
  const difficultyScore = difficultyMap[pattern.fix_difficulty] || 0.5;

  return (frequencyScore * 0.4) + (impactScore * 0.3) + (difficultyScore * 0.3);
}

/**
 * Estimate improvement percentage if pattern is fixed
 */
function estimateImprovement(pattern, totalQuestions) {
  const potentialImprovement = (pattern.frequency / totalQuestions) * 100;
  return Math.round(potentialImprovement * 0.7); // 70% success rate
}

/**
 * Estimate fix difficulty
 */
function estimateFixDifficulty(cluster) {
  if (cluster.questions.length >= 5) return 'hard';
  if (cluster.questions.length >= 3) return 'medium';
  return 'easy';
}

/**
 * Generate detailed issue content
 */
function generateIssueContent(issue, index, summary, userData) {
  const priorities = ['highest', 'medium', 'low'];
  const icons = ['🥇', '🥈', '🥉'];

  // Find strongest subject for contrast
  const strongestSubject = Object.entries(summary.by_subject)
    .sort((a, b) => b[1].accuracy - a[1].accuracy)[0];

  return {
    rank: index + 1,
    priority: priorities[index],
    icon: icons[index],
    title: issue.title,
    frequency: issue.frequency,
    percentage: issue.percentage,
    potential_gain: issue.potential_gain,
    roi_score: Math.round(issue.roi_score * 100) / 100,

    what_wrong: generateWhatWrong(issue),
    root_cause: generateRootCause(issue, strongestSubject),
    what_to_study: generateStudyTopics(issue),
    suggested_practice: generatePracticeSuggestion(issue),

    affected_chapters: issue.affected_chapters.slice(0, 5)
  };
}

function generateWhatWrong(issue) {
  if (issue.type === 'chapter_cluster') {
    const chapters = issue.affected_chapters.slice(0, 3).join(', ');
    return `You got ${issue.frequency} questions wrong across ${chapters}.`;
  } else if (issue.type === 'concept_gap') {
    return `You struggled with ${issue.title} across ${issue.affected_chapters.length} chapters.`;
  }
  return `You made ${issue.frequency} similar mistakes.`;
}

function generateRootCause(issue, strongestSubject) {
  if (issue.type === 'chapter_cluster') {
    return `Missing fundamental concepts. Your ${strongestSubject[0]} score (${Math.round(strongestSubject[1].accuracy)}%) proves you can solve problems - you just need to build these foundations.`;
  } else if (issue.type === 'concept_gap') {
    return `You know the basics, but struggle applying ${issue.title} to different problem types.`;
  }
  return `This is a systematic pattern in your approach - fixable with focused practice.`;
}

function generateStudyTopics(issue) {
  // Extract unique concepts from questions
  const allConcepts = [];
  issue.questions.forEach(q => {
    if (q.concepts_tested) allConcepts.push(...q.concepts_tested);
    if (q.sub_topics) allConcepts.push(...q.sub_topics);
  });

  // Count frequency
  const conceptFreq = {};
  allConcepts.forEach(c => {
    conceptFreq[c] = (conceptFreq[c] || 0) + 1;
  });

  // Get top 4 concepts
  const topConcepts = Object.entries(conceptFreq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 4)
    .map(([concept]) => `${concept} - review fundamentals and practice applications`);

  return topConcepts.length > 0 ? topConcepts : [
    'Review chapter basics',
    'Practice similar problems',
    'Focus on common mistake patterns',
    'Retry questions you got wrong'
  ];
}

function generatePracticeSuggestion(issue) {
  const difficultyMap = {
    'easy': '10-12 problems',
    'medium': '15-20 problems',
    'hard': '8-10 multi-step problems'
  };

  const numProblems = difficultyMap[issue.fix_difficulty] || '12-15 problems';

  if (issue.type === 'chapter_cluster') {
    return `${numProblems} on fundamentals, then retry JEEVibe chapter practice on ${issue.affected_chapters[0]}.`;
  } else if (issue.type === 'concept_gap') {
    return `${numProblems} specifically on ${issue.title} applications across different scenarios.`;
  }

  return `Practice ${numProblems} with focus on accuracy over speed.`;
}

/**
 * Calculate potential improvement if all issues are fixed
 */
function calculatePotentialImprovement(summary, topIssues) {
  const totalPotentialGain = topIssues.reduce((sum, issue) => sum + issue.potential_gain, 0);
  const potentialAccuracy = Math.min(summary.accuracy + totalPotentialGain, 95);

  // Estimate percentile projection (rough approximation)
  let percentileProjection = 50;
  if (potentialAccuracy >= 85) percentileProjection = 5;
  else if (potentialAccuracy >= 75) percentileProjection = 15;
  else if (potentialAccuracy >= 65) percentileProjection = 30;

  return {
    current_accuracy: Math.round(summary.accuracy),
    potential_accuracy: Math.round(potentialAccuracy),
    percentile_projection: percentileProjection
  };
}

/**
 * Adapt content tone based on student level
 */
function adaptContentToStudentLevel(accuracy) {
  if (accuracy >= 75) {
    return {
      greeting: 'Excellent week of practice!',
      tone: 'challenging',
      encouragement_level: 'moderate'
    };
  } else if (accuracy >= 55) {
    return {
      greeting: 'Great week of practice!',
      tone: 'balanced',
      encouragement_level: 'high'
    };
  } else {
    return {
      greeting: 'Good effort this week!',
      tone: 'supportive',
      encouragement_level: 'very_high',
      extra_message: 'Every question you practice is progress. Keep showing up!'
    };
  }
}

/**
 * Generate CTA based on issue
 */
function generateCTA(chapterKey) {
  if (!chapterKey) {
    return {
      primary: 'Start Today\'s Quiz',
      secondary: 'View Dashboard'
    };
  }

  return {
    primary: 'Start Today\'s Quiz',
    secondary: `Practice ${chapterKey.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}`
  };
}

/**
 * Store weekly report to Firestore
 */
async function storeWeeklyReport(userId, reportData) {
  try {
    const weekId = reportData.week_id;
    await db.collection('users').doc(userId)
      .collection('weekly_reports').doc(weekId)
      .set(reportData);

    console.log(`Stored weekly report for ${userId}: ${weekId}`);
    return true;
  } catch (error) {
    console.error(`Error storing weekly report for ${userId}:`, error);
    throw error;
  }
}

/**
 * Store daily report to Firestore (optional)
 */
async function storeDailyReport(userId, reportData) {
  try {
    const dateId = `daily_${reportData.date}`;
    await db.collection('users').doc(userId)
      .collection('daily_reports').doc(dateId)
      .set(reportData);

    console.log(`Stored daily report for ${userId}: ${dateId}`);
    return true;
  } catch (error) {
    console.error(`Error storing daily report for ${userId}:`, error);
    throw error;
  }
}

module.exports = {
  generateWeeklyReport,
  generateDailyReport,
  storeWeeklyReport,
  storeDailyReport
};
