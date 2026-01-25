#!/usr/bin/env node
/**
 * Mock Test Template Creation Script
 *
 * Creates 2-3 mock test templates from the existing questions collection.
 * Each template contains 90 questions (30 per subject) with proper
 * chapter distribution based on JEE weightage.
 *
 * Template Structure:
 * - 30 questions per subject (Physics, Chemistry, Mathematics)
 * - 20 MCQ (Single Correct) + 10 Numerical per subject
 * - Questions distributed by JEE chapter weightage
 * - No question overlap between templates
 *
 * Usage:
 *   cd backend && node scripts/createMockTestTemplates.js
 *
 * Prerequisites:
 *   Run verifyMockTestReadiness.js first to ensure sufficient questions
 *
 * @version 1.0
 * @phase Phase 0 - Mock Test Data Creation
 */

require('dotenv').config();
const { db, FieldValue } = require('../src/config/firebase');
const {
  PHYSICS_CHAPTERS,
  CHEMISTRY_CHAPTERS,
  MATHEMATICS_CHAPTERS,
  JEE_CHAPTER_WEIGHTS,
  DEFAULT_CHAPTER_WEIGHT
} = require('../../docs/engine/jee_chapter_weightage');

// Configuration
const TEMPLATE_COUNT = 3;
const QUESTIONS_PER_SUBJECT = 30;
const MCQ_PER_SUBJECT = 20;
const NVQ_PER_SUBJECT = 10;
const TOTAL_QUESTIONS = 90;

// JEE Main Mock Test Configuration
const MOCK_TEST_CONFIG = {
  duration_seconds: 10800, // 3 hours
  total_marks: 300,
  passing_marks: null, // No passing marks concept in JEE
  marking_scheme: {
    mcq_correct: 4,
    mcq_incorrect: -1,
    mcq_unattempted: 0,
    nvq_correct: 4,
    nvq_incorrect: 0, // NO negative marking for NVQ
    nvq_unattempted: 0
  },
  sections: [
    { name: 'Physics', question_count: 30, mcq_count: 20, nvq_count: 10 },
    { name: 'Chemistry', question_count: 30, mcq_count: 20, nvq_count: 10 },
    { name: 'Mathematics', question_count: 30, mcq_count: 20, nvq_count: 10 }
  ]
};

/**
 * Calculate chapter quotas based on JEE weightage
 * @param {Object} chapterWeights - Chapter weights from jee_chapter_weightage.js
 * @param {number} totalQuestions - Total questions to distribute
 * @returns {Object} Chapter quotas
 */
function calculateChapterQuotas(chapterWeights, totalQuestions) {
  const chapters = Object.keys(chapterWeights);
  const totalWeight = Object.values(chapterWeights).reduce((sum, w) => sum + w, 0);

  const quotas = {};
  let assigned = 0;

  // Calculate raw quotas
  for (const chapter of chapters) {
    const weight = chapterWeights[chapter];
    const rawQuota = (weight / totalWeight) * totalQuestions;
    quotas[chapter] = Math.floor(rawQuota);
    assigned += quotas[chapter];
  }

  // Distribute remaining questions to highest-weight chapters
  let remaining = totalQuestions - assigned;
  const sortedByWeight = chapters.sort((a, b) => chapterWeights[b] - chapterWeights[a]);

  for (const chapter of sortedByWeight) {
    if (remaining <= 0) break;
    quotas[chapter]++;
    remaining--;
  }

  // Filter out zero-quota chapters
  return Object.fromEntries(
    Object.entries(quotas).filter(([_, count]) => count > 0)
  );
}

/**
 * Get chapter weights for a specific subject
 */
function getSubjectChapterWeights(subject) {
  const chapterMap = {
    'Physics': PHYSICS_CHAPTERS,
    'Chemistry': CHEMISTRY_CHAPTERS,
    'Mathematics': MATHEMATICS_CHAPTERS
  };

  const chapters = chapterMap[subject] || {};
  const weights = {};

  for (const [key, value] of Object.entries(chapters)) {
    weights[key] = value.weight;
  }

  return weights;
}

/**
 * Select questions for a template based on quotas and type requirements
 */
function selectQuestionsForTemplate(
  availableQuestions,
  subject,
  mcqCount,
  nvqCount,
  chapterQuotas,
  usedQuestionIds
) {
  const selected = [];
  const subjectQuestions = availableQuestions.filter(
    q => q.subject === subject && !usedQuestionIds.has(q.id)
  );

  // Separate MCQ and NVQ
  const mcqQuestions = subjectQuestions.filter(
    q => q.question_type === 'mcq_single' || q.question_type === 'mcq'
  );
  const nvqQuestions = subjectQuestions.filter(
    q => q.question_type === 'numerical' || q.question_type === 'integer'
  );

  // Calculate quotas for MCQ and NVQ separately
  const chapterWeights = getSubjectChapterWeights(subject);
  const mcqQuotas = calculateChapterQuotas(chapterWeights, mcqCount);
  const nvqQuotas = calculateChapterQuotas(chapterWeights, nvqCount);

  // Select MCQs by chapter
  const selectedMcq = selectByChapterQuota(mcqQuestions, mcqQuotas, mcqCount, usedQuestionIds);
  selected.push(...selectedMcq);

  // Select NVQs by chapter
  const selectedNvq = selectByChapterQuota(nvqQuestions, nvqQuotas, nvqCount, usedQuestionIds);
  selected.push(...selectedNvq);

  return selected;
}

/**
 * Select questions according to chapter quotas
 */
function selectByChapterQuota(questions, quotas, totalNeeded, usedQuestionIds) {
  const selected = [];
  const questionsByChapter = {};

  // Group questions by chapter
  for (const q of questions) {
    const chapter = q.chapter_key || 'unknown';
    if (!questionsByChapter[chapter]) {
      questionsByChapter[chapter] = [];
    }
    questionsByChapter[chapter].push(q);
  }

  // Select from each chapter according to quota
  for (const [chapter, quota] of Object.entries(quotas)) {
    const available = (questionsByChapter[chapter] || []).filter(
      q => !usedQuestionIds.has(q.id)
    );

    // Shuffle for randomness
    shuffleArray(available);

    const toSelect = Math.min(quota, available.length);
    for (let i = 0; i < toSelect; i++) {
      selected.push(available[i]);
      usedQuestionIds.add(available[i].id);
    }
  }

  // If we don't have enough, fill from any available chapter
  if (selected.length < totalNeeded) {
    const allAvailable = questions.filter(q => !usedQuestionIds.has(q.id));
    shuffleArray(allAvailable);

    const needed = totalNeeded - selected.length;
    for (let i = 0; i < Math.min(needed, allAvailable.length); i++) {
      selected.push(allAvailable[i]);
      usedQuestionIds.add(allAvailable[i].id);
    }
  }

  return selected;
}

/**
 * Fisher-Yates shuffle
 */
function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
  return array;
}

/**
 * Format question for mock test template
 * Handles undefined values to avoid Firestore errors
 */
function formatQuestionForTemplate(question, index, sectionIndex) {
  const formatted = {
    question_number: index + 1,
    section_index: sectionIndex,
    question_id: question.question_id || question.id,
    firestore_doc_id: question.id,
    question_type: question.question_type || 'mcq_single',
    subject: question.subject || 'Unknown',
    chapter_key: question.chapter_key || null,
    chapter: question.chapter || null,

    // Question content
    question_text: question.question_text || '',
    question_text_html: question.question_text_html || null,
    image_url: question.image_url || null,

    // Options (for MCQ only)
    options: question.options || null,

    // Answer
    correct_answer: question.correct_answer || null,

    // IRT parameters (for analytics)
    irt_parameters: question.irt_parameters || {
      difficulty_b: question.difficulty_irt || 0.9,
      discrimination_a: 1.0,
      guessing_c: question.question_type === 'numerical' ? 0 : 0.25
    },

    // Marking scheme
    marks_correct: question.question_type === 'numerical' || question.question_type === 'integer' ? 4 : 4,
    marks_incorrect: question.question_type === 'numerical' || question.question_type === 'integer' ? 0 : -1,
    marks_unattempted: 0
  };

  // Only add optional fields if they exist (avoid undefined)
  if (question.solution_text) {
    formatted.solution_text = question.solution_text;
  }
  if (question.solution_steps) {
    formatted.solution_steps = question.solution_steps;
  }
  if (question.key_insight) {
    formatted.key_insight = question.key_insight;
  }
  if (question.common_mistakes) {
    formatted.common_mistakes = question.common_mistakes;
  }
  if (question.distractor_analysis) {
    formatted.distractor_analysis = question.distractor_analysis;
  }

  return formatted;
}

/**
 * Create a mock test template
 */
function createTemplate(templateNumber, questions, totalQuestionCount) {
  const now = new Date();
  const templateId = `MOCK_MAIN_${String(templateNumber).padStart(3, '0')}`;

  // Organize questions by subject
  const physics = questions.filter(q => q.subject === 'Physics');
  const chemistry = questions.filter(q => q.subject === 'Chemistry');
  const mathematics = questions.filter(q => q.subject === 'Mathematics');

  // Arrange MCQs first (1-20), then NVQs (21-30) within each subject
  const arrangeSection = (sectionQuestions, sectionIndex) => {
    const mcqs = sectionQuestions.filter(q => q.question_type === 'mcq_single' || q.question_type === 'mcq');
    const nvqs = sectionQuestions.filter(q => q.question_type === 'numerical' || q.question_type === 'integer');

    return [...mcqs, ...nvqs].map((q, idx) => formatQuestionForTemplate(q, idx, sectionIndex));
  };

  const physicsSection = arrangeSection(physics, 0);
  const chemistrySection = arrangeSection(chemistry, 1);
  const mathematicsSection = arrangeSection(mathematics, 2);

  // Calculate difficulty stats
  const allQuestions = [...physicsSection, ...chemistrySection, ...mathematicsSection];
  const avgDifficulty = allQuestions.reduce((sum, q) => sum + (q.irt_parameters?.difficulty_b || 0.9), 0) / allQuestions.length;

  return {
    template_id: templateId,
    name: `JEE Main Mock Test ${templateNumber}`,
    description: `Full-length JEE Main simulation with ${TOTAL_QUESTIONS} questions across Physics, Chemistry, and Mathematics.`,
    exam_type: 'JEE_MAIN',
    version: 1,

    // Configuration
    config: MOCK_TEST_CONFIG,

    // Questions (will be stored in subcollection for large templates)
    question_count: allQuestions.length,

    // Sections summary
    sections: [
      {
        name: 'Physics',
        subject: 'Physics',
        question_count: physicsSection.length,
        mcq_count: physicsSection.filter(q => q.question_type === 'mcq_single' || q.question_type === 'mcq').length,
        nvq_count: physicsSection.filter(q => q.question_type === 'numerical' || q.question_type === 'integer').length,
        start_index: 0,
        end_index: physicsSection.length - 1
      },
      {
        name: 'Chemistry',
        subject: 'Chemistry',
        question_count: chemistrySection.length,
        mcq_count: chemistrySection.filter(q => q.question_type === 'mcq_single' || q.question_type === 'mcq').length,
        nvq_count: chemistrySection.filter(q => q.question_type === 'numerical' || q.question_type === 'integer').length,
        start_index: physicsSection.length,
        end_index: physicsSection.length + chemistrySection.length - 1
      },
      {
        name: 'Mathematics',
        subject: 'Mathematics',
        question_count: mathematicsSection.length,
        mcq_count: mathematicsSection.filter(q => q.question_type === 'mcq_single' || q.question_type === 'mcq').length,
        nvq_count: mathematicsSection.filter(q => q.question_type === 'numerical' || q.question_type === 'integer').length,
        start_index: physicsSection.length + chemistrySection.length,
        end_index: allQuestions.length - 1
      }
    ],

    // Questions array (for small templates, else use subcollection)
    questions: allQuestions,

    // Metadata
    stats: {
      avg_difficulty: avgDifficulty.toFixed(2),
      physics_avg_difficulty: (physicsSection.reduce((sum, q) => sum + (q.irt_parameters?.difficulty_b || 0.9), 0) / physicsSection.length).toFixed(2),
      chemistry_avg_difficulty: (chemistrySection.reduce((sum, q) => sum + (q.irt_parameters?.difficulty_b || 0.9), 0) / chemistrySection.length).toFixed(2),
      mathematics_avg_difficulty: (mathematicsSection.reduce((sum, q) => sum + (q.irt_parameters?.difficulty_b || 0.9), 0) / mathematicsSection.length).toFixed(2)
    },

    // Status
    active: true,
    use_count: 0,
    created_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),

    // Source tracking
    source: 'auto_generated',
    source_collection: 'questions',
    generation_date: now.toISOString()
  };
}

/**
 * Save template to Firestore with chunking for large question sets
 */
async function saveTemplateToFirestore(template) {
  const CHUNK_SIZE = 15; // Questions per chunk (to stay under 1MB limit)

  const templateRef = db.collection('mock_test_templates').doc(template.template_id);

  // Separate questions from template document
  const questions = template.questions;
  delete template.questions;

  // Add chunk metadata
  template.uses_chunking = questions.length > CHUNK_SIZE;
  template.chunk_size = CHUNK_SIZE;
  template.total_chunks = Math.ceil(questions.length / CHUNK_SIZE);

  // Save main template document
  await templateRef.set(template);

  // Save questions in chunks
  const chunksRef = templateRef.collection('question_chunks');

  for (let i = 0; i < questions.length; i += CHUNK_SIZE) {
    const chunkIndex = Math.floor(i / CHUNK_SIZE);
    const chunkQuestions = questions.slice(i, i + CHUNK_SIZE);

    await chunksRef.doc(`chunk_${String(chunkIndex).padStart(2, '0')}`).set({
      chunk_index: chunkIndex,
      start_question: i + 1,
      end_question: Math.min(i + CHUNK_SIZE, questions.length),
      questions: chunkQuestions,
      question_count: chunkQuestions.length
    });
  }

  console.log(`   Saved ${template.total_chunks} chunks for template ${template.template_id}`);
}

/**
 * Main function to create mock test templates
 */
async function createMockTestTemplates() {
  console.log('='.repeat(70));
  console.log('📝 JEEVibe Mock Test Template Creator');
  console.log('='.repeat(70));
  console.log();
  console.log(`Creating ${TEMPLATE_COUNT} mock test templates...`);
  console.log(`Each template: ${TOTAL_QUESTIONS} questions (${QUESTIONS_PER_SUBJECT}/subject)`);
  console.log(`Question types: ${MCQ_PER_SUBJECT} MCQ + ${NVQ_PER_SUBJECT} Numerical per subject`);
  console.log();

  try {
    // Fetch all questions from the questions collection
    console.log('📊 Fetching questions from Firestore...\n');
    const questionsSnapshot = await db.collection('questions').get();

    if (questionsSnapshot.empty) {
      console.log('❌ No questions found in "questions" collection!');
      console.log('   Please run verifyMockTestReadiness.js first.\n');
      process.exit(1);
    }

    // Convert to array
    const allQuestions = [];
    questionsSnapshot.forEach(doc => {
      allQuestions.push({
        id: doc.id,
        ...doc.data()
      });
    });

    console.log(`   Total questions available: ${allQuestions.length}\n`);

    // Track used questions across templates
    const usedQuestionIds = new Set();
    const createdTemplates = [];

    // Create templates
    for (let t = 1; t <= TEMPLATE_COUNT; t++) {
      console.log('-'.repeat(70));
      console.log(`📋 Creating Template ${t}...`);
      console.log();

      const templateQuestions = [];

      for (const subject of ['Physics', 'Chemistry', 'Mathematics']) {
        console.log(`   Selecting ${subject} questions...`);

        const chapterWeights = getSubjectChapterWeights(subject);

        const selected = selectQuestionsForTemplate(
          allQuestions,
          subject,
          MCQ_PER_SUBJECT,
          NVQ_PER_SUBJECT,
          chapterWeights,
          usedQuestionIds
        );

        const mcqCount = selected.filter(q => q.question_type === 'mcq_single' || q.question_type === 'mcq').length;
        const nvqCount = selected.filter(q => q.question_type === 'numerical' || q.question_type === 'integer').length;

        console.log(`      Selected: ${selected.length} (${mcqCount} MCQ + ${nvqCount} NVQ)`);
        templateQuestions.push(...selected);
      }

      // Verify we have enough questions
      if (templateQuestions.length < TOTAL_QUESTIONS) {
        console.log();
        console.log(`   ⚠️  Warning: Only found ${templateQuestions.length}/${TOTAL_QUESTIONS} questions`);

        if (templateQuestions.length < TOTAL_QUESTIONS * 0.8) {
          console.log(`   ❌ Not enough questions for template ${t}. Stopping.`);
          break;
        }
      }

      // Create template object
      const template = createTemplate(t, templateQuestions, templateQuestions.length);

      // Save to Firestore
      console.log();
      console.log(`   💾 Saving to Firestore...`);
      await saveTemplateToFirestore(template);

      createdTemplates.push({
        id: template.template_id,
        name: template.name,
        question_count: template.question_count,
        sections: template.sections.map(s => ({
          name: s.name,
          mcq: s.mcq_count,
          nvq: s.nvq_count
        }))
      });

      console.log(`   ✅ Template ${t} created: ${template.template_id}`);
      console.log();
    }

    // Summary
    console.log('='.repeat(70));
    console.log('📋 SUMMARY');
    console.log('='.repeat(70));
    console.log();
    console.log(`   Templates created: ${createdTemplates.length}`);
    console.log(`   Total questions used: ${usedQuestionIds.size}`);
    console.log();

    for (const t of createdTemplates) {
      console.log(`   ${t.id}: ${t.question_count} questions`);
      for (const s of t.sections) {
        console.log(`      - ${s.name}: ${s.mcq} MCQ + ${s.nvq} NVQ`);
      }
    }

    console.log();
    console.log('   ✅ Templates saved to "mock_test_templates" collection');
    console.log();
    console.log('   Next steps:');
    console.log('   1. Verify templates in Firebase Console');
    console.log('   2. Proceed to Phase 1A (Backend Services)');
    console.log();

    return {
      success: true,
      templates: createdTemplates,
      totalQuestionsUsed: usedQuestionIds.size
    };

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the script
createMockTestTemplates()
  .then((result) => {
    console.log('Template creation complete.');
    process.exit(result.success ? 0 : 1);
  })
  .catch(error => {
    console.error('❌ Template creation failed:', error);
    process.exit(1);
  });
