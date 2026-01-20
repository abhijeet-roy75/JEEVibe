/**
 * JEEVibe - OpenAI API Service
 * Handles Vision API for OCR/solution and Text API for follow-up questions
 */

const OpenAI = require('openai');
const { BASE_PROMPT_TEMPLATE } = require('../prompts/priya_maam_base');
const { SNAP_SOLVE_FOLLOWUP_PROMPT } = require('../prompts/snap_solve');
const { getSyllabusAlignedTopic, JEE_SYLLABUS } = require('../prompts/jee_syllabus_reference');
const { validateAndNormalizeLaTeX, validateDelimiters, validateAndReject, validateSolutionResponse } = require('./latex-validator');
const { createOpenAICircuitBreaker } = require('../utils/circuitBreaker');
const { withTimeout } = require('../utils/timeout');
const logger = require('../utils/logger');

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// Timeout configurations (in milliseconds)
const OPENAI_VISION_TIMEOUT = 120000; // 2 minutes for image processing
const OPENAI_TEXT_TIMEOUT = 60000;    // 1 minute for text generation

/**
 * Wrapper for OpenAI chat completion with timeout
 * @param {Object} params - OpenAI chat completion parameters
 * @param {number} timeout - Timeout in milliseconds
 * @returns {Promise<Object>} OpenAI response
 */
async function openaiChatWithTimeout(params, timeout) {
  return withTimeout(
    openai.chat.completions.create(params),
    timeout,
    'OpenAI API request timed out'
  );
}

// Create circuit breaker wrapped versions of OpenAI calls
const openaiVisionBreaker = createOpenAICircuitBreaker(
  async (params) => openaiChatWithTimeout(params, OPENAI_VISION_TIMEOUT),
  { timeout: OPENAI_VISION_TIMEOUT + 5000, name: 'OpenAI-Vision' } // Circuit breaker timeout slightly higher
);

const openaiTextBreaker = createOpenAICircuitBreaker(
  async (params) => openaiChatWithTimeout(params, OPENAI_TEXT_TIMEOUT),
  { timeout: OPENAI_TEXT_TIMEOUT + 5000, name: 'OpenAI-Text' }
);

/**
 * Solve question from image using Vision API
 * @param {Buffer} imageBuffer - Image buffer
 * @returns {Promise<Object>} Solution object with question, solution, topic, difficulty
 */
async function solveQuestionFromImage(imageBuffer) {
  try {
    // Convert buffer to base64
    const base64Image = imageBuffer.toString('base64');

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
7. CRITICAL: Provide the solution in the SAME LANGUAGE as the question (e.g., if question is in Hindi, the solution approach and steps should be in Hindi).
8. Provide a clear final answer.

CRITICAL SPACING REQUIREMENTS:
- ALL step descriptions MUST have proper word spacing
- Write naturally: "Step 1: Draw the structure" NOT "Step1:Drawthestructure"
- Add spaces in compound names: "3,3-dimethyl hex-1-ene-4-yne" NOT "3,3-dimethylhex-1-ene-4-yne"
- Chemistry terms must be spaced: "paramagnetic with three unpaired electrons"
- Never concatenate words - every word must be separated by a space

JEE MAIN 2025 SYLLABUS REFERENCE:
Mathematics has 14 units: Sets/Relations/Functions, Complex Numbers, Matrices, Permutations, Binomial Theorem, Sequences, Limits/Differentiability, Integral Calculus, Differential Equations, Coordinate Geometry, 3D Geometry, Vector Algebra, Statistics/Probability, Trigonometry.
Physics includes: Units/Measurements, Kinematics, Laws of Motion, Work/Energy/Power, Rotational Motion, Gravitation, Properties of Solids/Liquids, Thermodynamics, and more.
Chemistry includes: Physical, Organic, and Inorganic Chemistry topics.

OUTPUT FORMAT (strict JSON):
{
  "recognizedQuestion": "Full question text as extracted from image",
  "subject": "Mathematics|Physics|Chemistry",
  "topic": "Syllabus-aligned topic name (e.g., 'Integral Calculus', 'Kinematics', 'Organic Chemistry - Reactions')",
  "difficulty": "easy|medium|hard",
  "language": "en|hi",
  "solution": {
    "approach": "Brief strategy (1-2 sentences)",
    "steps": [
      "Step 1: ...",
      "Step 2: ...",
      "Step 3: ..."
    ],
    "finalAnswer": "Clear statement of answer with units",
    "priyaMaamTip": "Encouraging/strategic tip in Priya's voice"
  }
}`;

    // Use circuit breaker for OpenAI Vision API call
    const response = await openaiVisionBreaker.fire({
      model: "gpt-4o-mini",  // Switched from gpt-4o for 40-45% faster responses + 94% cost savings
      messages: [
        {
          role: "system",
          content: systemPrompt
        },
        {
          role: "user",
          content: [
            {
              type: "image_url",
              image_url: {
                url: `data:image/jpeg;base64,${base64Image}`
              }
            },
            {
              type: "text",
              text: "Please solve this JEE question step-by-step as Priya Ma'am. Extract the question, identify the topic and difficulty, and provide a complete solution. IMPORTANT: Use LaTeX format \\(...\\) for ALL mathematical expressions. For chemical formulas, use LaTeX with \\mathrm{} (e.g., \\(\\mathrm{H}_{2}\\mathrm{SO}_{4}\\), \\(\\mathrm{CO}_{2}\\)). Do NOT use Unicode subscripts/superscripts - always use LaTeX format."
            }
          ]
        }
      ],
      max_tokens: 2000,
      temperature: 0.7,
      response_format: { type: "json_object" }
    });

    const content = response.choices[0].message.content;
    const solutionData = JSON.parse(content);

    // COMPREHENSIVE VALIDATION: Validate entire solution response
    console.log('[LaTeX Validation] Validating solution response...');
    const fullValidation = validateSolutionResponse(solutionData);

    if (!fullValidation.valid) {
      console.error('[LaTeX Validation] Issues found:', fullValidation.errors);
      console.warn('[LaTeX Validation] Content has been normalized, continuing with processed data');
    } else {
      console.log('[LaTeX Validation] ✓ All LaTeX formatting passed validation');
    }

    // Helper: strip LaTeX-ish tokens to produce plain text fallback for UI (used for Hindi)
    const stripLaTeX = (text) => {
      if (!text || typeof text !== 'string') return text;

      // Remove inline/display delimiters and common LaTeX commands
      let t = text;
      t = t.replace(/\\\(|\\\)|\\\[|\\\]/g, ''); // remove \( \) \[ \]
      t = t.replace(/\\[a-zA-Z]+/g, ''); // remove \frac, \sqrt, \mathrm, etc.
      t = t.replace(/[{}]/g, ''); // remove braces
      t = t.replace(/\^\{([^}]*)\}/g, '^$1'); // convert ^{x} -> ^x
      t = t.replace(/_\{([^}]*)\}/g, '_$1'); // convert _{x} -> _x
      t = t.replace(/\s{2,}/g, ' ');
      return t.trim();
    };

    // Normalize LaTeX markers in solution data using validator service
    const normalizeLaTeX = (text) => {
      if (typeof text !== 'string') return text;

      try {
        const normalized = validateAndNormalizeLaTeX(text);

        // Validate delimiters and log any issues
        const validation = validateDelimiters(normalized);
        if (!validation.balanced) {
          console.warn('[LaTeX] Delimiter balance warning:', validation.errors);
        }

        return normalized;
      } catch (error) {
        console.error('[LaTeX] Normalization error:', error);
        return text; // Return original on error
      }
    };

    // Validate LaTeX formatting
    const validateLaTeX = (text, fieldName = 'unknown') => {
      if (typeof text !== 'string') return;

      // Check for balanced delimiters
      const openInline = (text.match(/\\\(/g) || []).length;
      const closeInline = (text.match(/\\\)/g) || []).length;
      const openDisplay = (text.match(/\\\[/g) || []).length;
      const closeDisplay = (text.match(/\\\]/g) || []).length;

      if (openInline !== closeInline) {
        console.warn(`LaTeX validation warning [${fieldName}]: Unbalanced inline delimiters (${openInline} open, ${closeInline} close)`);
      }
      if (openDisplay !== closeDisplay) {
        console.warn(`LaTeX validation warning [${fieldName}]: Unbalanced display delimiters (${openDisplay} open, ${closeDisplay} close)`);
      }

      // Check for unescaped special characters outside delimiters
      const outsideDelimiters = text.replace(/\\\(.*?\\\)/g, '').replace(/\\\[.*?\\\]/g, '');
      const hasUnescapedSpecial = /[_^{}]/.test(outsideDelimiters);

      if (hasUnescapedSpecial) {
        console.warn(`LaTeX validation warning [${fieldName}]: Special characters outside delimiters detected`);
      }
    };


    // Normalize recognized question
    const normalizedQuestion = solutionData.recognizedQuestion
      ? normalizeLaTeX(solutionData.recognizedQuestion)
      : "Question extracted from image";
    validateLaTeX(normalizedQuestion, 'recognizedQuestion');

    // UI-safe fallback for Hindi: if language detected as Hindi and LaTeX validation
    // failed (anywhere), strip LaTeX from the recognized question to avoid
    // KaTeX/parser errors on the mobile UI. We keep solutions in Hindi as-is but
    // provide a plain-text recognizedQuestion for rendering.
    let finalRecognizedQuestion = normalizedQuestion;
    if ((solutionData.language === 'hi' || solutionData.language === 'hi-IN') && !fullValidation.valid) {
      console.warn('[Hindi fallback] LaTeX validation failed for Hindi content; stripping LaTeX for UI safety');
      try {
        const stripped = stripLaTeX(solutionData.recognizedQuestion || normalizedQuestion);
        if (stripped && stripped.length > 0) {
          finalRecognizedQuestion = stripped;
        }
      } catch (err) {
        console.error('[Hindi fallback] Error stripping LaTeX:', err);
      }
    }

    // Normalize solution steps
    let normalizedSolution = solutionData.solution || {
      approach: "Let's solve this step by step.",
      steps: ["Step-by-step solution will be provided."],
      finalAnswer: "Answer to be determined.",
      priyaMaamTip: "Great question! Let's work through this together."
    };

    if (normalizedSolution.approach) {
      normalizedSolution.approach = normalizeLaTeX(normalizedSolution.approach);
      validateLaTeX(normalizedSolution.approach, 'approach');
    }
    if (Array.isArray(normalizedSolution.steps)) {
      normalizedSolution.steps = normalizedSolution.steps.map((step, idx) => {
        const normalized = normalizeLaTeX(step);
        validateLaTeX(normalized, `step[${idx}]`);
        return normalized;
      });
    }
    if (normalizedSolution.finalAnswer) {
      normalizedSolution.finalAnswer = normalizeLaTeX(normalizedSolution.finalAnswer);
      validateLaTeX(normalizedSolution.finalAnswer, 'finalAnswer');
    }
    if (normalizedSolution.priyaMaamTip) {
      normalizedSolution.priyaMaamTip = normalizeLaTeX(normalizedSolution.priyaMaamTip);
      validateLaTeX(normalizedSolution.priyaMaamTip, 'priyaMaamTip');
    }


    // Align topic with JEE syllabus structure
    const alignedTopic = getSyllabusAlignedTopic(
      solutionData.topic || "General",
      solutionData.subject || "Mathematics"
    );

    return {
      recognizedQuestion: finalRecognizedQuestion,
      subject: solutionData.subject || "Mathematics",
      topic: alignedTopic,
      difficulty: solutionData.difficulty || "medium",
      language: solutionData.language || "en",
      solution: normalizedSolution
    };
  } catch (error) {
    console.error('Error solving question from image:', error);
    throw error;
  }
}

/**
 * Generate 3 follow-up questions based on solved question
 * @param {string} originalQuestion - Original question text
 * @param {string} solution - Solution text
 * @param {string} topic - Topic name
 * @param {string} difficulty - Difficulty level
 * @returns {Promise<Array>} Array of 3 follow-up questions
 */
async function generateFollowUpQuestions(originalQuestion, solution, topic, difficulty, language = 'en') {
  try {
    const prompt = SNAP_SOLVE_FOLLOWUP_PROMPT(originalQuestion, solution, topic, difficulty, language);

    // Use circuit breaker for OpenAI Text API call
    const response = await openaiTextBreaker.fire({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: BASE_PROMPT_TEMPLATE
        },
        {
          role: "user",
          content: prompt
        }
      ],
      max_tokens: 3000,
      temperature: 0.7,
      response_format: { type: "json_object" }
    });

    const content = response.choices[0].message.content;
    logger.debug('Raw OpenAI response', { preview: content.substring(0, 500) });

    const data = JSON.parse(content);

    // Handle both array and object with questions property
    let questions = [];
    if (Array.isArray(data)) {
      questions = data;
    } else if (data.questions && Array.isArray(data.questions)) {
      questions = data.questions;
    } else if (data.question) {
      // If single question object, wrap in array
      questions = [data];
    } else {
      console.error('Unexpected response format:', Object.keys(data));
      throw new Error('Invalid response format from OpenAI');
    }

    console.log(`Parsed ${questions.length} follow-up questions`);

    // Ensure we have exactly 3 questions
    if (questions.length < 3) {
      console.warn(`Only received ${questions.length} follow-up questions, expected 3`);
      console.warn('Response data:', JSON.stringify(data, null, 2));
    }

    // Normalize LaTeX markers in all questions using validator service
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

      // Normalize question text
      if (normalized.question) {
        normalized.question = normalizeLaTeX(normalized.question);
      }

      // Normalize options
      if (normalized.options && typeof normalized.options === 'object') {
        const normalizedOptions = {};
        Object.keys(normalized.options).forEach(key => {
          normalizedOptions[key] = normalizeLaTeX(normalized.options[key]);
        });
        normalized.options = normalizedOptions;
      }

      // Normalize explanation
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

      return normalized;
    });

    // Validate each question has required fields
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

    return validQuestions.slice(0, 3); // Return max 3 valid questions
  } catch (error) {
    console.error('Error generating follow-up questions:', error);
    throw error;
  }
}

/**
 * Generate a single follow-up question (for lazy loading)
 * @param {string} originalQuestion - Original question text
 * @param {string} solution - Solution text
 * @param {string} topic - Topic name
 * @param {string} difficulty - Difficulty level
 * @param {number} questionNumber - Question number (1, 2, or 3)
 * @returns {Promise<Object>} Single follow-up question
 */
async function generateSingleFollowUpQuestion(originalQuestion, solution, topic, difficulty, questionNumber, language = 'en') {
  try {
    const difficultyDescriptions = {
      1: 'SIMILAR difficulty, same core concept, different numbers/scenario',
      2: 'SLIGHTLY HARDER, add one complexity layer',
      3: 'HARDER, combine with related concept or multi-step'
    };

    const prompt = `${BASE_PROMPT_TEMPLATE}

CONTEXT: A student just used Snap & Solve on this JEE Main 2025 question:
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
- Each question MUST include a comprehensive, detailed explanation that helps students understand the concept deeply
- "approach": Provide 3-5 sentences explaining the overall strategy, key concepts involved, why this method works, and common pitfalls to avoid
- "steps": Each step should be 2-3 sentences with clear calculations, reasoning, and explanations. Include ALL necessary steps to reach the solution
- "finalAnswer": Provide the final answer with proper units and a brief verification or check
- Explanations should be educational and thorough, especially helpful when students get questions wrong
- Use Priya Ma'am's encouraging tone throughout explanations
- Include conceptual insights, not just procedural steps

OUTPUT FORMAT (strict JSON object):
{
  "question": "Question text with LaTeX \\(...\\)",
  "options": {
    "A": "Option A",
    "B": "Option B",
    "C": "Option C",
    "D": "Option D"
  },
  "correctAnswer": "A|B|C|D",
      "explanation": {
        "approach": "Comprehensive strategy explanation (3-5 sentences explaining the overall approach, key concepts involved, and why this method works)",
        "steps": ["Detailed step 1 with calculations and reasoning (2-3 sentences)", "Detailed step 2 with calculations and reasoning (2-3 sentences)", "Continue with all necessary steps, each with clear explanations"],
        "finalAnswer": "Final answer with units and brief verification"
      },
  "priyaMaamNote": "Encouraging tip"
}

Generate Question ${questionNumber} NOW in strict JSON object format.`;

    // Use circuit breaker for OpenAI Text API call
    const response = await openaiTextBreaker.fire({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: BASE_PROMPT_TEMPLATE
        },
        {
          role: "user",
          content: prompt
        }
      ],
      max_tokens: 1500,
      temperature: 0.7,
      response_format: { type: "json_object" }
    });

    const content = response.choices[0].message.content;
    logger.debug(`Raw response for Q${questionNumber}`, { preview: content.substring(0, 300) });

    let data;
    try {
      data = JSON.parse(content);
    } catch (parseError) {
      console.error(`JSON parse error for Q${questionNumber}:`, parseError);
      console.error('Content preview:', content.substring(0, 500));

      // Try to repair common JSON issues
      try {
        let repairedContent = content;

        // Remove any trailing incomplete data after the last valid closing brace
        const lastBrace = repairedContent.lastIndexOf('}');
        if (lastBrace > 0) {
          repairedContent = repairedContent.substring(0, lastBrace + 1);
        }

        // Try parsing the repaired content
        data = JSON.parse(repairedContent);
        logger.info(`JSON repair succeeded for Q${questionNumber}`);
      } catch (repairError) {
        // If repair fails, try extracting JSON object from the content
        const jsonMatch = content.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          try {
            data = JSON.parse(jsonMatch[0]);
            logger.info(`JSON extraction succeeded for Q${questionNumber}`);
          } catch (extractError) {
            throw new Error(`Failed to parse JSON response: ${parseError.message}`);
          }
        } else {
          throw new Error(`Failed to parse JSON response: ${parseError.message}`);
        }
      }
    }

    // Validate question structure
    if (!data.question || !data.options || !data.correctAnswer) {
      console.error(`Invalid question structure for Q${questionNumber}:`, data);
      throw new Error('Invalid question structure from OpenAI');
    }

    // Normalize LaTeX markers using validator service
    const normalizeLaTeX = (text) => {
      if (typeof text !== 'string') return text;

      try {
        return validateAndNormalizeLaTeX(text);
      } catch (error) {
        console.error('Error normalizing LaTeX in single question:', error);
        return text;
      }
    };

    // Normalize question text
    if (data.question) {
      data.question = normalizeLaTeX(data.question);
    }

    // Normalize LaTeX in options
    if (data.options) {
      Object.keys(data.options).forEach(key => {
        data.options[key] = normalizeLaTeX(data.options[key]);
      });
    }

    // Normalize LaTeX in explanation
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

    console.log(`Successfully parsed and normalized question ${questionNumber}`);
    return data;
  } catch (error) {
    console.error(`Error generating question ${questionNumber}:`, error);
    throw error;
  }
}

module.exports = {
  solveQuestionFromImage,
  generateFollowUpQuestions,
  generateSingleFollowUpQuestion
};

