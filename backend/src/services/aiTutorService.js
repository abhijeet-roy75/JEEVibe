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
  getConversationWithMessages
} = require('./tutorConversationService');
const { validateAndNormalizeLaTeX } = require('./latex-validator');

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// Model configuration
const MODEL = 'gpt-4o-mini';
const MAX_TOKENS = 1500;
const TEMPERATURE = 0.7;
const ROLLING_WINDOW_SIZE = 20; // Max messages to send to LLM

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
    // Ensure conversation exists
    await getOrCreateConversation(userId);

    // Get student profile for personalization
    const studentProfile = await getStudentProfile(userId);

    // Get most recent context for the system prompt
    const recentContext = await getMostRecentContext(userId);

    // Get recent messages for conversation history (rolling window)
    const recentMessages = await getRecentMessagesForLLM(userId, ROLLING_WINDOW_SIZE);

    // Build system prompt
    const systemPrompt = buildSystemPrompt(
      studentProfile,
      recentContext ? {
        type: recentContext.contextType,
        title: recentContext.contextTitle,
        snapshot: recentContext.contextSnapshot
      } : { type: 'general' }
    );

    // Add user message to conversation
    await addUserMessage(userId, message);

    // Build messages array for OpenAI
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

    // Validate and normalize LaTeX in response
    try {
      responseContent = validateAndNormalizeLaTeX(responseContent);
    } catch (latexError) {
      logger.warn('LaTeX validation warning', { userId, error: latexError.message });
      // Continue with original response if validation fails
    }

    // Save assistant response to conversation
    await addAssistantMessage(userId, responseContent);

    // Determine quick actions based on current context
    const contextType = recentContext?.contextType || 'general';
    const quickActions = getQuickActions(contextType);

    return {
      response: responseContent,
      quickActions: quickActions,
      tokensUsed: completion.usage?.total_tokens || 0
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
    // Ensure conversation exists
    await getOrCreateConversation(userId);

    // Build context from the source
    const context = await buildContext(contextType, contextId, userId);

    if (!context) {
      throw new Error(`Could not build context for ${contextType}:${contextId}`);
    }

    // Get student profile for personalization
    const studentProfile = await getStudentProfile(userId);

    // Add context marker to conversation
    const contextMarker = await addContextMarker(userId, context);

    // Generate contextual greeting
    const greetingData = buildGreetingData(context);
    const greeting = getContextGreeting(contextType, greetingData);

    // Generate the greeting as an assistant message
    const systemPrompt = buildSystemPrompt(studentProfile, context);

    const greetingPrompt = `The student just opened a chat about: ${context.title}.
Generate a brief, warm greeting (2-3 sentences max) acknowledging what they're looking at and inviting them to ask questions.
Don't solve anything yet - just welcome them and show you understand the context.`;

    const completion = await openai.chat.completions.create({
      model: MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: greetingPrompt }
      ],
      max_tokens: 300,
      temperature: 0.8
    });

    let greetingResponse = completion.choices[0]?.message?.content || greeting;

    // Validate LaTeX in greeting
    try {
      greetingResponse = validateAndNormalizeLaTeX(greetingResponse);
    } catch (latexError) {
      logger.warn('LaTeX validation warning in greeting', { userId, error: latexError.message });
    }

    // Save greeting as assistant message
    await addAssistantMessage(userId, greetingResponse);

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
      tokensUsed: completion.usage?.total_tokens || 0
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
      max_tokens: 200,
      temperature: 0.8
    });

    let welcomeMessage = completion.choices[0]?.message?.content ||
      "Hello! I'm Priya Ma'am, your AI tutor for JEE preparation. How can I help you today?";

    // Save welcome as assistant message
    await addAssistantMessage(userId, welcomeMessage);

    const quickActions = getQuickActions('general');

    return {
      message: welcomeMessage,
      quickActions: quickActions,
      tokensUsed: completion.usage?.total_tokens || 0
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
