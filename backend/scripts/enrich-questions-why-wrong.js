/**
 * Enrich questions with distractor_analysis and common_mistakes fields
 *
 * This script uses Claude AI to generate "why you got this wrong" content
 * for questions that are missing these fields.
 *
 * Usage:
 *   node scripts/enrich-questions-why-wrong.js
 *   node scripts/enrich-questions-why-wrong.js --limit 100
 *   node scripts/enrich-questions-why-wrong.js --subject Physics
 *   node scripts/enrich-questions-why-wrong.js --dry-run
 */

require('dotenv').config();
const { db } = require('../src/config/firebase');
const Anthropic = require('@anthropic-ai/sdk');

// ============================================================================
// CONFIGURATION
// ============================================================================

const BATCH_SIZE = 10; // Process 10 questions at a time
const DELAY_BETWEEN_BATCHES = 2000; // 2 seconds between batches to avoid rate limits
const DEFAULT_LIMIT = 50; // Default number of questions to process

// ============================================================================
// CLAUDE AI CLIENT
// ============================================================================

// Check for API key
if (!process.env.ANTHROPIC_API_KEY) {
  console.error('❌ ANTHROPIC_API_KEY not found in environment variables.');
  console.error('');
  console.error('To run this script:');
  console.error('  1. Set the ANTHROPIC_API_KEY environment variable, or');
  console.error('  2. Add ANTHROPIC_API_KEY=your_key to your .env file');
  console.error('');
  console.error('Example: ANTHROPIC_API_KEY=sk-ant-xxx node scripts/enrich-questions-why-wrong.js');
  process.exit(1);
}

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY
});

// ============================================================================
// PROMPT TEMPLATES
// ============================================================================

const MCQ_PROMPT = `You are a JEE exam expert. Analyze this MCQ question and provide distractor analysis explaining why each wrong option is incorrect.

Question: {question_text}

Options:
A: {option_a}
B: {option_b}
C: {option_c}
D: {option_d}

Correct Answer: {correct_answer}

Provide a JSON object with distractor analysis for EACH WRONG OPTION. The analysis should:
1. Explain the misconception or error that leads to selecting this wrong answer
2. Be educational and help students understand their mistake
3. Be concise (1-2 sentences)

Format your response as ONLY a JSON object (no markdown, no explanation):
{
  "distractor_analysis": {
    "A": "explanation why A is wrong (if A is wrong)",
    "B": "explanation why B is wrong (if B is wrong)",
    "C": "explanation why C is wrong (if C is wrong)",
    "D": "explanation why D is wrong (if D is wrong)"
  }
}

Only include entries for the WRONG options (not the correct answer).`;

const NUMERICAL_PROMPT = `You are a JEE exam expert. Analyze this numerical question and identify common mistakes students make when solving it.

Question: {question_text}

Correct Answer: {correct_answer}

Provide a JSON object with common mistakes. Each mistake should:
1. Describe a specific error students commonly make
2. Be educational and help students avoid the mistake
3. Be concise (1 sentence each)

Format your response as ONLY a JSON object (no markdown, no explanation):
{
  "common_mistakes": [
    "Common mistake 1: specific error description",
    "Common mistake 2: specific error description",
    "Common mistake 3: specific error description"
  ]
}

Provide 2-4 common mistakes relevant to this problem type.`;

// ============================================================================
// AI GENERATION
// ============================================================================

async function generateWhyWrongContent(question) {
  const isMcq = question.question_type === 'mcq_single' || question.options;

  let prompt;
  if (isMcq) {
    const options = question.options || {};
    prompt = MCQ_PROMPT
      .replace('{question_text}', question.question_text || '')
      .replace('{option_a}', options.A || options.a || 'N/A')
      .replace('{option_b}', options.B || options.b || 'N/A')
      .replace('{option_c}', options.C || options.c || 'N/A')
      .replace('{option_d}', options.D || options.d || 'N/A')
      .replace('{correct_answer}', question.correct_answer || '');
  } else {
    prompt = NUMERICAL_PROMPT
      .replace('{question_text}', question.question_text || '')
      .replace('{correct_answer}', question.correct_answer || '');
  }

  try {
    const response = await anthropic.messages.create({
      model: 'claude-3-5-haiku-latest',
      max_tokens: 500,
      messages: [{ role: 'user', content: prompt }]
    });

    const content = response.content[0].text.trim();

    // Parse JSON response
    const parsed = JSON.parse(content);

    if (isMcq) {
      return { distractor_analysis: parsed.distractor_analysis || null };
    } else {
      return { common_mistakes: parsed.common_mistakes || null };
    }
  } catch (error) {
    console.error(`  ❌ AI generation failed: ${error.message}`);
    return null;
  }
}

// ============================================================================
// MAIN PROCESSING
// ============================================================================

async function enrichQuestions(options = {}) {
  const { limit = DEFAULT_LIMIT, subject = null, dryRun = false } = options;

  console.log('======================================================================');
  console.log('🔧 Enriching questions with "Why Wrong" content');
  console.log('======================================================================\n');
  console.log(`Options: limit=${limit}, subject=${subject || 'all'}, dryRun=${dryRun}\n`);

  // Build query for questions missing these fields
  let query = db.collection('questions');

  if (subject) {
    query = query.where('subject', '==', subject);
  }

  // Get questions
  const snapshot = await query.limit(limit * 2).get(); // Get more than needed to filter

  // Filter to questions missing the relevant fields
  const questionsToProcess = [];

  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const isMcq = data.question_type === 'mcq_single' || data.options;

    // Check if missing relevant field
    if (isMcq && !data.distractor_analysis) {
      questionsToProcess.push({ id: doc.id, ...data });
    } else if (!isMcq && !data.common_mistakes) {
      questionsToProcess.push({ id: doc.id, ...data });
    }

    if (questionsToProcess.length >= limit) return;
  });

  console.log(`Found ${questionsToProcess.length} questions needing enrichment\n`);

  if (questionsToProcess.length === 0) {
    console.log('✅ All questions already have "why wrong" content!');
    return;
  }

  // Process in batches
  let processed = 0;
  let updated = 0;
  let errors = 0;

  for (let i = 0; i < questionsToProcess.length; i += BATCH_SIZE) {
    const batch = questionsToProcess.slice(i, i + BATCH_SIZE);
    console.log(`\n📦 Processing batch ${Math.floor(i / BATCH_SIZE) + 1}...`);

    for (const question of batch) {
      processed++;
      const isMcq = question.question_type === 'mcq_single' || question.options;
      const type = isMcq ? 'MCQ' : 'Numerical';

      console.log(`  ${processed}. ${question.question_id || question.id} (${type})`);

      const enrichment = await generateWhyWrongContent(question);

      if (enrichment) {
        if (dryRun) {
          console.log(`     [DRY RUN] Would update with:`, JSON.stringify(enrichment).substring(0, 100));
        } else {
          try {
            await db.collection('questions').doc(question.id).update(enrichment);
            console.log(`     ✅ Updated`);
            updated++;
          } catch (updateError) {
            console.log(`     ❌ Update failed: ${updateError.message}`);
            errors++;
          }
        }
      } else {
        errors++;
      }

      // Small delay between questions
      await new Promise(resolve => setTimeout(resolve, 200));
    }

    // Delay between batches
    if (i + BATCH_SIZE < questionsToProcess.length) {
      console.log(`  ⏳ Waiting ${DELAY_BETWEEN_BATCHES / 1000}s before next batch...`);
      await new Promise(resolve => setTimeout(resolve, DELAY_BETWEEN_BATCHES));
    }
  }

  console.log('\n======================================================================');
  console.log('📊 Summary');
  console.log('======================================================================');
  console.log(`Processed: ${processed}`);
  console.log(`Updated: ${updated}`);
  console.log(`Errors: ${errors}`);

  if (dryRun) {
    console.log('\n⚠️  DRY RUN - No changes were made to the database');
  }
}

// ============================================================================
// CLI
// ============================================================================

async function main() {
  const args = process.argv.slice(2);

  const options = {
    limit: DEFAULT_LIMIT,
    subject: null,
    dryRun: false
  };

  // Parse arguments
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--limit' && args[i + 1]) {
      options.limit = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--subject' && args[i + 1]) {
      options.subject = args[i + 1];
      i++;
    } else if (args[i] === '--dry-run') {
      options.dryRun = true;
    }
  }

  await enrichQuestions(options);
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
