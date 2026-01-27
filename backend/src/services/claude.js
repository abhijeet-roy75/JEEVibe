/**
 * JEEVibe - Claude API Service
 * Handles Vision API for OCR/solution and Text API for follow-up questions
 * Using Claude Sonnet 4 for vision and Haiku 3.5 for text generation
 */

const Anthropic = require('@anthropic-ai/sdk');
const { BASE_PROMPT_TEMPLATE } = require('../prompts/priya_maam_base');
const { SNAP_SOLVE_FOLLOWUP_PROMPT } = require('../prompts/snap_solve');
const { getSyllabusAlignedTopic } = require('../prompts/jee_syllabus_reference');
const { validateAndNormalizeLaTeX, validateDelimiters, validateSolutionResponse } = require('./latex-validator');
const { createOpenAICircuitBreaker } = require('../utils/circuitBreaker');
const { withTimeout } = require('../utils/timeout');
const logger = require('../utils/logger');

// Initialize Anthropic client
const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY
});

/**
 * Sanitize JSON string to fix LaTeX backslashes before parsing
 *
 * Problem: Claude returns JSON with LaTeX like \frac, \theta which contains
 * sequences that look like invalid JSON escapes:
 * - \f in \frac is interpreted as form-feed (valid escape but wrong)
 * - \t in \theta, \tan is interpreted as tab (valid escape but wrong)
 * - \n in \nabla is interpreted as newline (valid escape but wrong)
 *
 * Solution: Find and double-escape backslashes that are followed by LaTeX
 * command names to ensure they're preserved as literal backslashes.
 */
function sanitizeJsonForLatex(jsonString) {
  if (!jsonString || typeof jsonString !== 'string') {
    return jsonString;
  }

  // Replace LaTeX commands that start with JSON escape characters
  // We need to be careful to only match inside string values

  // Common LaTeX patterns that conflict with JSON escapes:
  // \frac, \forall (conflicts with \f form-feed)
  // \theta, \tan, \tanh, \times, \text, \to (conflicts with \t tab)
  // \nabla, \neq, \nu, \not, \ne, \neg (conflicts with \n newline)
  // \rho, \rightarrow, \right, \Re (conflicts with \r carriage return)
  // \beta, \bar, \binom, \begin, \big (conflicts with \b backspace)

  let result = jsonString;

  // Strategy: Match LaTeX-like patterns and ensure backslashes are escaped
  // Pattern: backslash + letter that forms a LaTeX command (2+ letters following)

  // Use a regex to find unescaped backslashes followed by LaTeX commands
  // inside JSON strings (between quotes)

  // Process character by character to handle string context properly
  let output = '';
  let i = 0;
  let inString = false;

  while (i < result.length) {
    const char = result[i];

    // Track string boundaries (but not escaped quotes)
    if (char === '"' && (i === 0 || result[i - 1] !== '\\')) {
      inString = !inString;
      output += char;
      i++;
      continue;
    }

    // Handle backslashes inside strings
    if (inString && char === '\\') {
      const nextChar = result[i + 1];

      // Check if this is already an escaped backslash
      if (nextChar === '\\') {
        // Already escaped, pass through both
        output += '\\\\';
        i += 2;
        continue;
      }

      // Check if next char is a valid JSON escape that's likely a LaTeX command
      // (e.g., \frac starts with \f which is a valid JSON escape)
      if (['f', 't', 'n', 'r', 'b'].includes(nextChar)) {
        // Look ahead to see if this is a LaTeX command (more letters follow)
        let j = i + 2;
        while (j < result.length && /[a-zA-Z]/.test(result[j])) {
          j++;
        }
        const commandLength = j - (i + 1); // Length of potential command

        if (commandLength >= 2) {
          // This is likely a LaTeX command, escape the backslash
          output += '\\\\';
          i++;
          continue;
        }
      }

      // For other backslash sequences, check if it's a valid JSON escape
      if (nextChar && !/["\\\/bfnrtu]/.test(nextChar)) {
        // Not a valid JSON escape - need to escape the backslash
        output += '\\\\';
        i++;
        continue;
      }
    }

    output += char;
    i++;
  }

  return output;
}

// Model configuration
const CLAUDE_VISION_MODEL = 'claude-sonnet-4-20250514';  // Best for vision + complex reasoning
const CLAUDE_TEXT_MODEL = 'claude-3-haiku-20240307';     // Fast and cost-effective for text

/**
 * Normalize subject name to standard format
 */
function normalizeSubject(subject) {
  if (!subject) return 'Mathematics';
  const lower = subject.toLowerCase().trim();
  if (lower === 'math' || lower === 'maths' || lower === 'mathematics') {
    return 'Mathematics';
  }
  if (lower === 'physics' || lower === 'phy') {
    return 'Physics';
  }
  if (lower === 'chemistry' || lower === 'chem') {
    return 'Chemistry';
  }
  return subject.charAt(0).toUpperCase() + subject.slice(1).toLowerCase();
}

// Timeout configurations (in milliseconds)
const CLAUDE_VISION_TIMEOUT = 120000; // 2 minutes for image processing
const CLAUDE_TEXT_TIMEOUT = 60000;    // 1 minute for text generation

/**
 * Wrapper for Claude API call with timeout
 */
async function claudeWithTimeout(params, timeout) {
  return withTimeout(
    anthropic.messages.create(params),
    timeout,
    'Claude API request timed out'
  );
}

// Create circuit breaker wrapped versions of Claude calls
const claudeVisionBreaker = createOpenAICircuitBreaker(
  async (params) => claudeWithTimeout(params, CLAUDE_VISION_TIMEOUT),
  { timeout: CLAUDE_VISION_TIMEOUT + 5000, name: 'Claude-Vision' }
);

const claudeTextBreaker = createOpenAICircuitBreaker(
  async (params) => claudeWithTimeout(params, CLAUDE_TEXT_TIMEOUT),
  { timeout: CLAUDE_TEXT_TIMEOUT + 5000, name: 'Claude-Text' }
);

/**
 * Solve question from image using Claude Vision API
 * @param {Buffer} imageBuffer - Image buffer
 * @returns {Promise<Object>} Solution object with question, solution, topic, difficulty
 */
async function solveQuestionFromImage(imageBuffer) {
  try {
    const base64Image = imageBuffer.toString('base64');

    // Detect image type from buffer magic bytes
    let mediaType = 'image/jpeg';
    if (imageBuffer[0] === 0x89 && imageBuffer[1] === 0x50) {
      mediaType = 'image/png';
    } else if (imageBuffer[0] === 0x47 && imageBuffer[1] === 0x49) {
      mediaType = 'image/gif';
    } else if (imageBuffer[0] === 0x52 && imageBuffer[1] === 0x49) {
      mediaType = 'image/webp';
    }

    const systemPrompt = `${BASE_PROMPT_TEMPLATE}

You are solving a JEE Main 2025 level question from a photo. Your task:
1. Extract the question text accurately (including all math notation)
2. Identify the subject (Mathematics, Physics, or Chemistry)
3. Identify the specific topic - MUST align with JEE Main 2025 syllabus structure:
   - Mathematics: Use exact unit names (e.g., "Integral Calculus", "Co-ordinate Geometry", "Differential Equations")
   - Physics: Use exact unit names (e.g., "Kinematics", "Laws of Motion", "Thermodynamics")
   - Chemistry: Use exact unit names (e.g., "Organic Chemistry - Reactions", "Physical Chemistry - Thermodynamics")
4. Determine difficulty level based on JEE Main standards:
   - Easy: 70%+ students can solve (straightforward application)
   - Medium: 40-70% students can solve (requires concept understanding)
   - Hard: 20-40% students can solve (multi-step, complex reasoning)
5. Detect the language of the question (English or Hindi).
6. Solve the question step-by-step in Priya Ma'am's voice.
7. CRITICAL: Provide the solution in the SAME LANGUAGE as the question.
8. Provide a clear final answer.

STEP FORMAT REQUIREMENTS (CRITICAL):
- Each step MUST start with a simple English title (NO formulas in the title)
- Format: "Step N: [Simple English Title] - [Detailed explanation with formulas]"
- Good: "Step 1: Identify when the function equals zero - For \\(x \\neq 0\\), we have \\(f(x) = 0\\) when..."
- Good: "Step 2: Apply the sine function property - The sine function equals zero when its argument is \\(n\\pi\\)..."
- Bad: "Step 1: For \\(x \\neq 0\\), we have \\(f(x) = 0\\)..." (starts with formula)
- The title before the dash should be plain English describing what you're doing
- Examples of good titles: "Set up the equation", "Apply the formula", "Simplify the expression", "Calculate the result"

CRITICAL SPACING REQUIREMENTS:
- ALL step descriptions MUST have proper word spacing
- Write naturally: "Step 1: Draw the structure" NOT "Step1:Drawthestructure"
- Chemistry terms must be spaced: "paramagnetic with three unpaired electrons"
- Never concatenate words - every word must be separated by a space

JEE MAIN 2025 SYLLABUS REFERENCE:
Mathematics has 14 units: Sets/Relations/Functions, Complex Numbers, Matrices, Permutations, Binomial Theorem, Sequences, Limits/Differentiability, Integral Calculus, Differential Equations, Coordinate Geometry, 3D Geometry, Vector Algebra, Statistics/Probability, Trigonometry.
Physics includes: Units/Measurements, Kinematics, Laws of Motion, Work/Energy/Power, Rotational Motion, Gravitation, Properties of Solids/Liquids, Thermodynamics, and more.
Chemistry includes: Physical, Organic, and Inorganic Chemistry topics.

You MUST respond with ONLY a valid JSON object in this exact format (no markdown, no explanation outside JSON):
{
  "recognizedQuestion": "Full question text as extracted from image",
  "subject": "Mathematics|Physics|Chemistry",
  "topic": "Syllabus-aligned topic name",
  "difficulty": "easy|medium|hard",
  "language": "en|hi",
  "solution": {
    "approach": "Brief strategy (1-2 sentences)",
    "steps": ["Step 1: ...", "Step 2: ...", "Step 3: ..."],
    "finalAnswer": "Clear statement of answer with units",
    "priyaMaamTip": "Encouraging/strategic tip in Priya's voice"
  }
}`;

    const userPrompt = `Please solve this JEE question step-by-step as Priya Ma'am. Extract the question, identify the topic and difficulty, and provide a complete solution.

IMPORTANT: Use LaTeX format \\(...\\) for ALL mathematical expressions. For chemical formulas, use LaTeX with \\mathrm{} (e.g., \\(\\mathrm{H}_{2}\\mathrm{SO}_{4}\\)). Do NOT use Unicode subscripts/superscripts - always use LaTeX format.

Respond with ONLY a valid JSON object, no other text.`;

    const response = await claudeVisionBreaker.fire({
      model: CLAUDE_VISION_MODEL,
      max_tokens: 4000, // Increased from 2500 to allow complete step-by-step solutions
      system: systemPrompt,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: mediaType,
                data: base64Image
              }
            },
            {
              type: 'text',
              text: userPrompt
            }
          ]
        }
      ]
    });

    // Extract text content from Claude response
    const content = response.content[0].type === 'text' ? response.content[0].text : '';

    // Parse JSON from response (Claude might include markdown code blocks)
    let jsonContent = content;
    const jsonMatch = content.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) {
      jsonContent = jsonMatch[1].trim();
    }

    // Sanitize JSON to escape LaTeX backslashes that conflict with JSON escapes
    const sanitizedJson = sanitizeJsonForLatex(jsonContent);
    const solutionData = JSON.parse(sanitizedJson);

    // Validate solution response
    console.log('[Claude LaTeX Validation] Validating solution response...');
    const fullValidation = validateSolutionResponse(solutionData);

    if (!fullValidation.valid) {
      console.error('[Claude LaTeX Validation] Issues found:', fullValidation.errors);
      console.warn('[Claude LaTeX Validation] Content has been normalized, continuing with processed data');
    } else {
      console.log('[Claude LaTeX Validation] ✓ All LaTeX formatting passed validation');
    }

    // Helper functions for LaTeX processing
    const stripLaTeX = (text) => {
      if (!text || typeof text !== 'string') return text;
      let t = text;
      t = t.replace(/\\\(|\\\)|\\\[|\\\]/g, '');
      t = t.replace(/\\[a-zA-Z]+/g, '');
      t = t.replace(/[{}]/g, '');
      t = t.replace(/\^\{([^}]*)\}/g, '^$1');
      t = t.replace(/_\{([^}]*)\}/g, '_$1');
      t = t.replace(/\s{2,}/g, ' ');
      return t.trim();
    };

    const normalizeLaTeX = (text) => {
      if (typeof text !== 'string') return text;
      try {
        const normalized = validateAndNormalizeLaTeX(text);
        const validation = validateDelimiters(normalized);
        if (!validation.balanced) {
          console.warn('[Claude LaTeX] Delimiter balance warning:', validation.errors);
        }
        return normalized;
      } catch (error) {
        console.error('[Claude LaTeX] Normalization error:', error);
        return text;
      }
    };

    // Normalize recognized question
    const normalizedQuestion = solutionData.recognizedQuestion
      ? normalizeLaTeX(solutionData.recognizedQuestion)
      : "Question extracted from image";

    // Hindi fallback
    let finalRecognizedQuestion = normalizedQuestion;
    if ((solutionData.language === 'hi' || solutionData.language === 'hi-IN') && !fullValidation.valid) {
      console.warn('[Claude Hindi fallback] LaTeX validation failed; stripping LaTeX for UI safety');
      try {
        const stripped = stripLaTeX(solutionData.recognizedQuestion || normalizedQuestion);
        if (stripped && stripped.length > 0) {
          finalRecognizedQuestion = stripped;
        }
      } catch (err) {
        console.error('[Claude Hindi fallback] Error stripping LaTeX:', err);
      }
    }

    // Normalize solution
    let normalizedSolution = solutionData.solution || {
      approach: "Let's solve this step by step.",
      steps: ["Step-by-step solution will be provided."],
      finalAnswer: "Answer to be determined.",
      priyaMaamTip: "Great question! Let's work through this together."
    };

    if (normalizedSolution.approach) {
      normalizedSolution.approach = normalizeLaTeX(normalizedSolution.approach);
    }
    if (Array.isArray(normalizedSolution.steps)) {
      normalizedSolution.steps = normalizedSolution.steps.map(step => normalizeLaTeX(step));
    }
    if (normalizedSolution.finalAnswer) {
      normalizedSolution.finalAnswer = normalizeLaTeX(normalizedSolution.finalAnswer);
    }
    if (normalizedSolution.priyaMaamTip) {
      normalizedSolution.priyaMaamTip = normalizeLaTeX(normalizedSolution.priyaMaamTip);
    }

    const normalizedSubject = normalizeSubject(solutionData.subject);
    const alignedTopic = getSyllabusAlignedTopic(
      solutionData.topic || "General",
      normalizedSubject
    );

    return {
      recognizedQuestion: finalRecognizedQuestion,
      subject: normalizedSubject,
      topic: alignedTopic,
      difficulty: solutionData.difficulty || "medium",
      language: solutionData.language || "en",
      solution: normalizedSolution
    };
  } catch (error) {
    console.error('Error solving question from image with Claude:', error);
    throw error;
  }
}

/**
 * Generate 3 follow-up questions based on solved question
 */
async function generateFollowUpQuestions(originalQuestion, solution, topic, difficulty, language = 'en') {
  try {
    const prompt = SNAP_SOLVE_FOLLOWUP_PROMPT(originalQuestion, solution, topic, difficulty, language);

    const response = await claudeTextBreaker.fire({
      model: CLAUDE_TEXT_MODEL,
      max_tokens: 3000,
      system: BASE_PROMPT_TEMPLATE + '\n\nYou MUST respond with ONLY a valid JSON object, no markdown code blocks or other text.',
      messages: [
        {
          role: 'user',
          content: prompt + '\n\nRespond with ONLY a valid JSON object containing the questions array.'
        }
      ]
    });

    const content = response.content[0].type === 'text' ? response.content[0].text : '';
    logger.debug('Raw Claude response', { preview: content.substring(0, 500) });

    // Parse JSON (handle potential markdown code blocks)
    let jsonContent = content.trim();
    const jsonMatch = content.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) {
      jsonContent = jsonMatch[1].trim();
    }

    // Sanitize JSON to escape LaTeX backslashes that conflict with JSON escapes
    const sanitizedJson = sanitizeJsonForLatex(jsonContent);
    const data = JSON.parse(sanitizedJson);

    // Handle response format variations
    let questions = [];
    if (Array.isArray(data)) {
      questions = data;
    } else if (data.questions && Array.isArray(data.questions)) {
      questions = data.questions;
    } else if (data.question) {
      questions = [data];
    } else {
      console.error('Unexpected response format:', Object.keys(data));
      throw new Error('Invalid response format from Claude');
    }

    console.log(`Parsed ${questions.length} follow-up questions from Claude`);

    const normalizeLaTeX = (text) => {
      if (typeof text !== 'string') return text;
      try {
        return validateAndNormalizeLaTeX(text);
      } catch (error) {
        console.error('Error normalizing LaTeX in follow-up questions:', error);
        return text;
      }
    };

    const normalizedQuestions = questions.map(q => {
      const normalized = { ...q };
      if (normalized.question) {
        normalized.question = normalizeLaTeX(normalized.question);
      }
      if (normalized.options && typeof normalized.options === 'object') {
        const normalizedOptions = {};
        Object.keys(normalized.options).forEach(key => {
          normalizedOptions[key] = normalizeLaTeX(normalized.options[key]);
        });
        normalized.options = normalizedOptions;
      }
      if (normalized.explanation) {
        if (normalized.explanation.approach) {
          normalized.explanation.approach = normalizeLaTeX(normalized.explanation.approach);
        }
        if (Array.isArray(normalized.explanation.steps)) {
          normalized.explanation.steps = normalized.explanation.steps.map(step => normalizeLaTeX(step));
        }
        if (normalized.explanation.finalAnswer) {
          normalized.explanation.finalAnswer = normalizeLaTeX(normalized.explanation.finalAnswer);
        }
      }
      // Normalize common mistakes (array of strings)
      if (Array.isArray(normalized.commonMistakes)) {
        normalized.commonMistakes = normalized.commonMistakes.map(mistake => normalizeLaTeX(mistake));
      }
      // Normalize key takeaway (string)
      if (normalized.keyTakeaway) {
        normalized.keyTakeaway = normalizeLaTeX(normalized.keyTakeaway);
      }
      return normalized;
    });

    const validQuestions = normalizedQuestions.filter(q => {
      const hasQuestion = q.question && q.question.trim().length > 0;
      const hasOptions = q.options && typeof q.options === 'object';
      const hasCorrectAnswer = q.correctAnswer && ['A', 'B', 'C', 'D'].includes(q.correctAnswer);
      if (!hasQuestion || !hasOptions || !hasCorrectAnswer) {
        console.warn('Invalid question structure:', JSON.stringify(q, null, 2));
      }
      return hasQuestion && hasOptions && hasCorrectAnswer;
    });

    if (validQuestions.length < 3) {
      console.warn(`Only ${validQuestions.length} valid questions after validation`);
    }

    return validQuestions.slice(0, 3);
  } catch (error) {
    console.error('Error generating follow-up questions with Claude:', error);
    throw error;
  }
}

/**
 * Generate a single follow-up question (for lazy loading)
 */
async function generateSingleFollowUpQuestion(originalQuestion, solution, topic, difficulty, questionNumber, language = 'en') {
  try {
    const difficultyDescriptions = {
      1: 'SIMILAR difficulty, same core concept, different numbers/scenario',
      2: 'SLIGHTLY HARDER, add one complexity layer',
      3: 'HARDER, combine with related concept or multi-step'
    };

    const prompt = `CONTEXT: A student just used Snap & Solve on this JEE Main 2025 question:
QUESTION: ${originalQuestion}
TOPIC: ${topic} (from JEE Main 2025 syllabus)
DIFFICULTY: ${difficulty}
LANGUAGE: ${language === 'hi' ? 'Hindi' : 'English'}

TASK: Generate Question ${questionNumber} of 3 follow-up practice questions.
IMPORTANT: Generate questions and explanations in ${language === 'hi' ? 'Hindi (or Hinglish if appropriate for technical terms)' : 'English'}.

REQUIREMENTS:
- Question ${questionNumber}: ${difficultyDescriptions[questionNumber]}
- Same topic domain: ${topic} (must align with JEE Main 2025 syllabus)
- JEE Main 2025 difficulty standards:
  * Easy: 70%+ students can solve
  * Medium: 40-70% students can solve
  * Hard: 20-40% students can solve
- Priya Ma'am's encouraging tone
- Question must be standalone (don't reference other questions)
- Use JEE Main question format and style

EXPLANATION REQUIREMENTS (CRITICAL):
- "approach": Provide 3-5 sentences explaining the overall strategy, key concepts involved, why this method works
- "steps": Each step should be 2-3 sentences with clear calculations, reasoning, and explanations
- "finalAnswer": Provide the final answer with proper units and a brief verification
- Use Priya Ma'am's encouraging tone throughout explanations

Respond with ONLY this JSON object format (no markdown, no other text):
{
  "question": "Question text with LaTeX \\\\(...\\\\)",
  "options": {
    "A": "Option A",
    "B": "Option B",
    "C": "Option C",
    "D": "Option D"
  },
  "correctAnswer": "A|B|C|D",
  "explanation": {
    "approach": "Comprehensive strategy explanation",
    "steps": ["Step 1 with reasoning", "Step 2 with reasoning"],
    "finalAnswer": "Final answer with units"
  },
  "priyaMaamNote": "Encouraging tip",
  "commonMistakes": [
    "Common mistake 1 students make in this type of problem",
    "Common mistake 2 that leads to wrong answers",
    "Common mistake 3 to avoid"
  ],
  "keyTakeaway": "One-sentence key insight or formula to remember for similar problems"
}`;

    const response = await claudeTextBreaker.fire({
      model: CLAUDE_TEXT_MODEL,
      max_tokens: 4000, // Increased from 2500 to allow complete step-by-step solutions
      system: BASE_PROMPT_TEMPLATE + '\n\nYou MUST respond with ONLY a valid JSON object, no markdown code blocks or other text.',
      messages: [
        {
          role: 'user',
          content: prompt
        }
      ]
    });

    const content = response.content[0].type === 'text' ? response.content[0].text : '';
    const stopReason = response.stop_reason;
    logger.debug(`Raw Claude response for Q${questionNumber}`, {
      preview: content.substring(0, 300),
      stopReason,
      contentLength: content.length
    });

    if (stopReason === 'max_tokens') {
      logger.warn(`Response truncated for Q${questionNumber}, may have incomplete JSON`);
    }

    // Parse JSON (handle potential markdown code blocks)
    let jsonContent = content.trim();
    const jsonMatch = content.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) {
      jsonContent = jsonMatch[1].trim();
    }

    // Sanitize JSON to escape LaTeX backslashes that conflict with JSON escapes
    const sanitizedJson = sanitizeJsonForLatex(jsonContent);

    let data;
    try {
      data = JSON.parse(sanitizedJson);
    } catch (parseError) {
      console.error(`JSON parse error for Q${questionNumber}:`, parseError);
      console.error('Content preview:', content.substring(0, 500));

      // Try to repair JSON
      try {
        let repairedContent = sanitizedJson;
        const lastBrace = repairedContent.lastIndexOf('}');
        if (lastBrace > 0) {
          repairedContent = repairedContent.substring(0, lastBrace + 1);
        }
        data = JSON.parse(repairedContent);
        logger.info(`JSON repair succeeded for Q${questionNumber}`);
      } catch (repairError) {
        const jsonExtract = content.match(/\{[\s\S]*\}/);
        if (jsonExtract) {
          try {
            // Also sanitize extracted JSON
            const sanitizedExtract = sanitizeJsonForLatex(jsonExtract[0]);
            data = JSON.parse(sanitizedExtract);
            logger.info(`JSON extraction succeeded for Q${questionNumber}`);
          } catch (extractError) {
            logger.error(`All JSON repair attempts failed for Q${questionNumber}`);
            throw new Error(`Failed to parse JSON response: ${parseError.message}`);
          }
        } else {
          throw new Error(`Failed to parse JSON response: ${parseError.message}`);
        }
      }
    }

    if (!data.question || !data.options || !data.correctAnswer) {
      console.error(`Invalid question structure for Q${questionNumber}:`, data);
      throw new Error('Invalid question structure from Claude');
    }

    const normalizeLaTeX = (text) => {
      if (typeof text !== 'string') return text;
      try {
        return validateAndNormalizeLaTeX(text);
      } catch (error) {
        console.error('Error normalizing LaTeX in single question:', error);
        return text;
      }
    };

    if (data.question) {
      // Remove "Q##" or "Q#" prefix (e.g., "Q23", "Q1", "Q2", etc.)
      data.question = data.question.replace(/^Q\d+\.?\s*/i, '').trim();
      data.question = normalizeLaTeX(data.question);
    }
    if (data.options) {
      Object.keys(data.options).forEach(key => {
        data.options[key] = normalizeLaTeX(data.options[key]);
      });
    }
    if (data.explanation) {
      if (data.explanation.approach) {
        data.explanation.approach = normalizeLaTeX(data.explanation.approach);
      }
      if (Array.isArray(data.explanation.steps)) {
        data.explanation.steps = data.explanation.steps.map(step => normalizeLaTeX(step));
      }
      if (data.explanation.finalAnswer) {
        data.explanation.finalAnswer = normalizeLaTeX(data.explanation.finalAnswer);
      }
    }
    // Normalize common mistakes (array of strings)
    if (Array.isArray(data.commonMistakes)) {
      data.commonMistakes = data.commonMistakes.map(mistake => normalizeLaTeX(mistake));
    }
    // Normalize key takeaway (string)
    if (data.keyTakeaway) {
      data.keyTakeaway = normalizeLaTeX(data.keyTakeaway);
    }

    console.log(`Successfully parsed and normalized question ${questionNumber} from Claude`);
    return data;
  } catch (error) {
    console.error(`Error generating question ${questionNumber} with Claude:`, error);
    throw error;
  }
}

module.exports = {
  solveQuestionFromImage,
  generateFollowUpQuestions,
  generateSingleFollowUpQuestion
};
