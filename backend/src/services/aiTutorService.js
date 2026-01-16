/**
 * AI Tutor Service
 * Core service for AI Tutor (Priya Ma'am) conversations
 * Handles prompt construction, OpenAI API calls, and response processing
 */

const OpenAI = require('openai');
const logger = require('../utils/logger');
const {
  AI_TUTOR_SYSTEM_PROMPT,
  buildStudentContext,
  buildCurrentContext,
  getContextGreeting,
  getQuickActions
} = require('../prompts/ai_tutor_prompts');
const { buildContext, getStudentProfile } = require('./aiTutorContextService');
const {
  getOrCreateConversation,
  addUserMessage,
  addAssistantMessage,
  addContextMarker,
  getRecentMessagesForLLM,
  getMostRecentContext,
  clearConversation,
  getConversationWithMessages,
  updateTokenUsage
} = require('./tutorConversationService');
const { validateAndNormalizeLaTeX } = require('./latex-validator');

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// Model configuration - loaded from environment with defaults
const MODEL = process.env.AI_TUTOR_MODEL || 'gpt-4o-mini';
const MAX_TOKENS = parseInt(process.env.AI_TUTOR_MAX_TOKENS, 10) || 1500;
const TEMPERATURE = parseFloat(process.env.AI_TUTOR_TEMPERATURE) || 0.7;
const ROLLING_WINDOW_SIZE = parseInt(process.env.AI_TUTOR_ROLLING_WINDOW, 10) || 20;
const GREETING_MAX_TOKENS = parseInt(process.env.AI_TUTOR_GREETING_MAX_TOKENS, 10) || 300;
const WELCOME_MAX_TOKENS = parseInt(process.env.AI_TUTOR_WELCOME_MAX_TOKENS, 10) || 200;

/**
 * Build the system prompt with student and context data injected
 * @param {Object} studentData - Student profile data
 * @param {Object} contextData - Current context (solution/quiz/etc)
 * @returns {string} Complete system prompt
 */
function buildSystemPrompt(studentData, contextData) {
  let prompt = AI_TUTOR_SYSTEM_PROMPT;

  // Inject student context
  const studentContextStr = buildStudentContext(studentData);
  prompt = prompt.replace('{{STUDENT_CONTEXT}}', studentContextStr);

  // Inject current context
  const currentContextStr = buildCurrentContext(contextData);
  prompt = prompt.replace('{{CURRENT_CONTEXT}}', currentContextStr);

  return prompt;
}

/**
 * Send a message to the AI tutor and get a response
 * @param {string} userId - User ID
 * @param {string} message - User's message
 * @returns {Promise<Object>} Response with message and quick actions
 */
async function sendMessage(userId, message) {
  try {
    // Ensure conversation exists first (required before other operations)
    await getOrCreateConversation(userId);

    // Parallelize independent database reads for better performance
    const [studentProfile, recentContext, recentMessages] = await Promise.all([
      getStudentProfile(userId),
      getMostRecentContext(userId),
      getRecentMessagesForLLM(userId, ROLLING_WINDOW_SIZE)
    ]);

    // Build system prompt
    const systemPrompt = buildSystemPrompt(
      studentProfile,
      recentContext ? {
        type: recentContext.contextType,
        title: recentContext.contextTitle,
        snapshot: recentContext.contextSnapshot
      } : { type: 'general' }
    );

    // Build messages array for OpenAI (include user message at the end)
    // Note: We add to DB AFTER building the array to avoid race condition
    // where recentMessages might not include the just-added message
    const messages = [
      { role: 'system', content: systemPrompt },
      ...recentMessages,
      { role: 'user', content: message }
    ];

    // Call OpenAI API
    const completion = await openai.chat.completions.create({
      model: MODEL,
      messages: messages,
      max_tokens: MAX_TOKENS,
      temperature: TEMPERATURE
    });

    let responseContent = completion.choices[0]?.message?.content || '';

    // Validate and normalize LaTeX in response (run async to not block)
    // Using setImmediate pattern to yield to event loop for long operations
    responseContent = await new Promise((resolve) => {
      setImmediate(() => {
        try {
          resolve(validateAndNormalizeLaTeX(responseContent));
        } catch (latexError) {
          logger.warn('LaTeX validation warning', { userId, error: latexError.message });
          resolve(responseContent); // Return original on error
        }
      });
    });

    // Save both messages to conversation AFTER successful API call
    // This ensures we don't save partial data on API failure
    const tokensUsed = completion.usage?.total_tokens || 0;
    await Promise.all([
      addUserMessage(userId, message),
      addAssistantMessage(userId, responseContent),
      updateTokenUsage(userId, tokensUsed, MODEL)
    ]);

    // Determine quick actions based on current context
    const contextType = recentContext?.contextType || 'general';
    const quickActions = getQuickActions(contextType);

    return {
      response: responseContent,
      quickActions: quickActions,
      tokensUsed: tokensUsed
    };
  } catch (error) {
    logger.error('Error in AI Tutor sendMessage', { userId, error: error.message });
    throw error;
  }
}

/**
 * Inject context and get a contextual greeting
 * Called when user opens chat from solution/quiz/analytics screen
 * @param {string} userId - User ID
 * @param {string} contextType - 'solution', 'quiz', 'analytics', or 'general'
 * @param {string} contextId - ID of the context item (solution/quiz ID)
 * @returns {Promise<Object>} Greeting, context marker, and quick actions
 */
async function injectContext(userId, contextType, contextId) {
  try {
    // Ensure conversation exists first
    await getOrCreateConversation(userId);

    // Parallelize context building and student profile fetch
    const [context, studentProfile] = await Promise.all([
      buildContext(contextType, contextId, userId),
      getStudentProfile(userId)
    ]);

    if (!context) {
      throw new Error(`Could not build context for ${contextType}:${contextId}`);
    }

    // Add context marker to conversation
    const contextMarker = await addContextMarker(userId, context);

    // Generate contextual greeting
    const greetingData = buildGreetingData(context);
    const greeting = getContextGreeting(contextType, greetingData);

    // Generate the greeting as an assistant message
    const systemPrompt = buildSystemPrompt(studentProfile, context);

    // Build a context-aware greeting prompt
    let greetingPrompt;
    if (contextType === 'solution' && context.snapshot?.question) {
      // For solutions, acknowledge the specific question
      const questionPreview = context.snapshot.question.length > 150
        ? context.snapshot.question.substring(0, 150) + '...'
        : context.snapshot.question;
      greetingPrompt = `The student just opened a chat about a ${context.snapshot.topic || 'problem'} in ${context.snapshot.subject || 'their subject'}.

The question they're working on is:
"${questionPreview}"

Generate a brief, warm greeting (2-3 sentences) that:
1. Acknowledges you can see the specific problem they're working on
2. Briefly mentions what the question is about (don't repeat the whole question)
3. Invites them to ask about any part of the solution they'd like to understand better

Don't solve anything yet - just welcome them and show you understand what they're looking at.`;
    } else if (contextType === 'quiz' && context.snapshot) {
      greetingPrompt = `The student just finished a quiz and scored ${context.snapshot.score}/${context.snapshot.total}.
Generate a brief, warm greeting (2-3 sentences) acknowledging their performance and offering to help review questions they missed.`;
    } else if (contextType === 'analytics') {
      greetingPrompt = `The student is looking at their overall progress analytics.
Generate a brief, warm greeting (2-3 sentences) acknowledging you can see their performance data and offering to discuss study strategies.`;
    } else {
      greetingPrompt = `The student just opened a chat about: ${context.title}.
Generate a brief, warm greeting (2-3 sentences max) acknowledging what they're looking at and inviting them to ask questions.
Don't solve anything yet - just welcome them and show you understand the context.`;
    }

    const completion = await openai.chat.completions.create({
      model: MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: greetingPrompt }
      ],
      max_tokens: GREETING_MAX_TOKENS,
      temperature: 0.8
    });

    let greetingResponse = completion.choices[0]?.message?.content || greeting;

    // Validate LaTeX in greeting
    try {
      greetingResponse = validateAndNormalizeLaTeX(greetingResponse);
    } catch (latexError) {
      logger.warn('LaTeX validation warning in greeting', { userId, error: latexError.message });
    }

    // Save greeting and track token usage
    const tokensUsed = completion.usage?.total_tokens || 0;
    await Promise.all([
      addAssistantMessage(userId, greetingResponse),
      updateTokenUsage(userId, tokensUsed, MODEL)
    ]);

    // Get quick actions for this context type
    const quickActions = getQuickActions(contextType);

    return {
      greeting: greetingResponse,
      contextMarker: {
        id: contextMarker.id,
        type: contextMarker.contextType,
        title: contextMarker.contextTitle,
        timestamp: contextMarker.timestamp
      },
      quickActions: quickActions,
      tokensUsed: tokensUsed
    };
  } catch (error) {
    logger.error('Error in AI Tutor injectContext', { userId, contextType, contextId, error: error.message });
    throw error;
  }
}

/**
 * Build greeting template data from context
 * @param {Object} context - Context object
 * @returns {Object} Data for greeting template interpolation
 */
function buildGreetingData(context) {
  const data = {};

  if (context.snapshot) {
    // Solution context
    if (context.type === 'solution') {
      data.subject = context.snapshot.subject || 'this subject';
      data.topic = context.snapshot.topic || 'this topic';
    }

    // Quiz context
    if (context.type === 'quiz') {
      data.score = context.snapshot.score || 0;
      data.total = context.snapshot.total || 0;
    }

    // Analytics context
    if (context.type === 'analytics') {
      if (context.snapshot.strongestSubject) {
        data.strongSubject = context.snapshot.strongestSubject.subject;
      }
      if (context.snapshot.focusAreas && context.snapshot.focusAreas.length > 0) {
        data.weakArea = context.snapshot.focusAreas[0].chapter;
      }
    }
  }

  return data;
}

/**
 * Get conversation with messages for display
 * @param {string} userId - User ID
 * @param {number} limit - Max messages to return
 * @returns {Promise<Object>} Conversation with messages
 */
async function getConversation(userId, limit = 50) {
  try {
    const conversation = await getConversationWithMessages(userId, limit);
    const recentContext = await getMostRecentContext(userId);

    return {
      messages: conversation.messages,
      messageCount: conversation.messageCount,
      currentContext: recentContext ? {
        type: recentContext.contextType,
        id: recentContext.contextId,
        title: recentContext.contextTitle
      } : null
    };
  } catch (error) {
    logger.error('Error getting conversation', { userId, error: error.message });
    throw error;
  }
}

/**
 * Clear conversation and start fresh
 * @param {string} userId - User ID
 * @returns {Promise<void>}
 */
async function resetConversation(userId) {
  try {
    await clearConversation(userId);
    logger.info('Conversation reset', { userId });
  } catch (error) {
    logger.error('Error resetting conversation', { userId, error: error.message });
    throw error;
  }
}

/**
 * Generate a welcome message for new users
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Welcome message and quick actions
 */
async function generateWelcomeMessage(userId) {
  try {
    const studentProfile = await getStudentProfile(userId);

    const systemPrompt = buildSystemPrompt(studentProfile, { type: 'general' });

    const welcomePrompt = `Generate a warm, brief welcome message (2-3 sentences) for a JEE aspirant who is opening the chat for the first time.
Introduce yourself as Priya Ma'am and let them know you're here to help with their JEE preparation.
Be encouraging but concise.`;

    const completion = await openai.chat.completions.create({
      model: MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: welcomePrompt }
      ],
      max_tokens: WELCOME_MAX_TOKENS,
      temperature: 0.8
    });

    let welcomeMessage = completion.choices[0]?.message?.content ||
      "Hello! I'm Priya Ma'am, your AI tutor for JEE preparation. How can I help you today?";

    // Save welcome message and track token usage
    const tokensUsed = completion.usage?.total_tokens || 0;
    await Promise.all([
      addAssistantMessage(userId, welcomeMessage),
      updateTokenUsage(userId, tokensUsed, MODEL)
    ]);

    const quickActions = getQuickActions('general');

    return {
      message: welcomeMessage,
      quickActions: quickActions,
      tokensUsed: tokensUsed
    };
  } catch (error) {
    logger.error('Error generating welcome message', { userId, error: error.message });
    throw error;
  }
}

module.exports = {
  sendMessage,
  injectContext,
  getConversation,
  resetConversation,
  generateWelcomeMessage
};
