/**
 * AI Tutor Service Test Suite
 * Tests for core AI tutor functionality: prompt building, message sending, context injection
 */

// Create a mock OpenAI instance that will be shared
const mockOpenAICreate = jest.fn();

// Mock dependencies before requiring the service
jest.mock('openai', () => {
  return jest.fn().mockImplementation(() => ({
    chat: {
      completions: {
        create: mockOpenAICreate
      }
    }
  }));
});

jest.mock('../../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
}));

jest.mock('../../../../src/services/aiTutorContextService', () => ({
  buildContext: jest.fn(),
  getStudentProfile: jest.fn()
}));

jest.mock('../../../../src/services/tutorConversationService', () => ({
  getOrCreateConversation: jest.fn(),
  addUserMessage: jest.fn(),
  addAssistantMessage: jest.fn(),
  addContextMarker: jest.fn(),
  getRecentMessagesForLLM: jest.fn(),
  getMostRecentContext: jest.fn(),
  clearConversation: jest.fn(),
  getConversationWithMessages: jest.fn(),
  updateTokenUsage: jest.fn()
}));

jest.mock('../../../../src/services/latex-validator', () => ({
  validateAndNormalizeLaTeX: jest.fn((text) => text)
}));

jest.mock('../../../../src/prompts/ai_tutor_prompts', () => ({
  AI_TUTOR_SYSTEM_PROMPT: 'System prompt template {{STUDENT_CONTEXT}} {{CURRENT_CONTEXT}}',
  buildStudentContext: jest.fn(() => 'Student context string'),
  buildCurrentContext: jest.fn(() => 'Current context string'),
  getContextGreeting: jest.fn(() => 'Hello student!'),
  getQuickActions: jest.fn(() => [{ label: 'Test action', prompt: 'Test prompt' }])
}));

const logger = require('../../../../src/utils/logger');
const { buildContext, getStudentProfile } = require('../../../../src/services/aiTutorContextService');
const {
  getOrCreateConversation,
  addUserMessage,
  addAssistantMessage,
  addContextMarker,
  getRecentMessagesForLLM,
  getMostRecentContext,
  clearConversation,
  getConversationWithMessages
} = require('../../../../src/services/tutorConversationService');
const { validateAndNormalizeLaTeX } = require('../../../../src/services/latex-validator');
const { getQuickActions } = require('../../../../src/prompts/ai_tutor_prompts');

const {
  sendMessage,
  injectContext,
  getConversation,
  resetConversation,
  generateWelcomeMessage
} = require('../../../../src/services/aiTutorService');

describe('AI Tutor Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('sendMessage', () => {
    const userId = 'user123';
    const message = 'What is projectile motion?';

    beforeEach(() => {
      getOrCreateConversation.mockResolvedValue({});
      getStudentProfile.mockResolvedValue({
        firstName: 'Rahul',
        overallPercentile: 70,
        strengths: ['Kinematics'],
        weaknesses: ['Thermodynamics']
      });
      getMostRecentContext.mockResolvedValue(null);
      getRecentMessagesForLLM.mockResolvedValue([]);
      addUserMessage.mockResolvedValue({});
      addAssistantMessage.mockResolvedValue({});
    });

    test('should send message and return response with quick actions', async () => {
      const mockResponse = 'Projectile motion is the motion of an object thrown into the air...';
      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: mockResponse } }],
        usage: { total_tokens: 150 }
      });

      const result = await sendMessage(userId, message);

      expect(getOrCreateConversation).toHaveBeenCalledWith(userId);
      expect(getStudentProfile).toHaveBeenCalledWith(userId);
      expect(addUserMessage).toHaveBeenCalledWith(userId, message);
      expect(addAssistantMessage).toHaveBeenCalledWith(userId, mockResponse);
      expect(result.response).toBe(mockResponse);
      expect(result.quickActions).toBeDefined();
      expect(result.tokensUsed).toBe(150);
    });

    test('should include recent context in system prompt', async () => {
      getMostRecentContext.mockResolvedValue({
        contextType: 'solution',
        contextTitle: 'Kinematics - Physics',
        contextSnapshot: { question: 'A ball is thrown...' }
      });

      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: 'Response' } }],
        usage: { total_tokens: 100 }
      });

      await sendMessage(userId, message);

      expect(getMostRecentContext).toHaveBeenCalledWith(userId);
      expect(getQuickActions).toHaveBeenCalledWith('solution');
    });

    test('should include recent messages in conversation history', async () => {
      const recentMessages = [
        { role: 'user', content: 'Previous question' },
        { role: 'assistant', content: 'Previous answer' }
      ];
      getRecentMessagesForLLM.mockResolvedValue(recentMessages);

      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: 'Response' } }],
        usage: { total_tokens: 100 }
      });

      await sendMessage(userId, message);

      expect(getRecentMessagesForLLM).toHaveBeenCalledWith(userId, 20);
      expect(mockOpenAICreate).toHaveBeenCalledWith(
        expect.objectContaining({
          messages: expect.arrayContaining([
            expect.objectContaining({ role: 'system' }),
            ...recentMessages,
            expect.objectContaining({ role: 'user', content: message })
          ])
        })
      );
    });

    test('should validate and normalize LaTeX in response', async () => {
      const responseWithLatex = 'The formula is \\(v = u + at\\)';
      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: responseWithLatex } }],
        usage: { total_tokens: 100 }
      });

      await sendMessage(userId, message);

      expect(validateAndNormalizeLaTeX).toHaveBeenCalledWith(responseWithLatex);
    });

    test('should handle LaTeX validation errors gracefully', async () => {
      const response = 'Some response with bad latex';
      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: response } }],
        usage: { total_tokens: 100 }
      });
      validateAndNormalizeLaTeX.mockImplementation(() => {
        throw new Error('Invalid LaTeX');
      });

      const result = await sendMessage(userId, message);

      expect(logger.warn).toHaveBeenCalledWith(
        'LaTeX validation warning',
        expect.objectContaining({ userId })
      );
      expect(result.response).toBe(response);
    });

    test('should throw error on OpenAI API failure', async () => {
      mockOpenAICreate.mockRejectedValue(
        new Error('API Error')
      );

      await expect(sendMessage(userId, message)).rejects.toThrow('API Error');
      expect(logger.error).toHaveBeenCalledWith(
        'Error in AI Tutor sendMessage',
        expect.objectContaining({ userId })
      );
    });
  });

  describe('injectContext', () => {
    const userId = 'user123';
    const contextType = 'solution';
    const contextId = 'snap123';

    beforeEach(() => {
      getOrCreateConversation.mockResolvedValue({});
      buildContext.mockResolvedValue({
        type: 'solution',
        contextId: 'snap123',
        title: 'Kinematics - Physics',
        snapshot: {
          question: 'A ball is thrown vertically upward...',
          subject: 'physics',
          topic: 'Kinematics',
          approach: 'Using kinematic equations',
          steps: ['Step 1', 'Step 2'],
          finalAnswer: 'Maximum height = 20m'
        }
      });
      getStudentProfile.mockResolvedValue({
        firstName: 'Rahul',
        overallPercentile: 70
      });
      addContextMarker.mockResolvedValue({
        id: 'marker123',
        contextType: 'solution',
        contextTitle: 'Kinematics - Physics',
        timestamp: new Date()
      });
      addAssistantMessage.mockResolvedValue({});
    });

    test('should inject context and return greeting with quick actions', async () => {
      const greetingResponse = "Hello! I see you're working on a Kinematics problem...";
      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: greetingResponse } }],
        usage: { total_tokens: 80 }
      });

      const result = await injectContext(userId, contextType, contextId);

      expect(getOrCreateConversation).toHaveBeenCalledWith(userId);
      expect(buildContext).toHaveBeenCalledWith(contextType, contextId, userId);
      expect(addContextMarker).toHaveBeenCalled();
      expect(result.greeting).toBe(greetingResponse);
      expect(result.contextMarker).toBeDefined();
      expect(result.contextMarker.type).toBe('solution');
      expect(result.quickActions).toBeDefined();
    });

    test('should throw error if context cannot be built', async () => {
      buildContext.mockResolvedValue(null);

      await expect(injectContext(userId, contextType, contextId))
        .rejects.toThrow(`Could not build context for ${contextType}:${contextId}`);
    });

    test('should generate solution-specific greeting prompt', async () => {
      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: 'Greeting' } }],
        usage: { total_tokens: 50 }
      });

      await injectContext(userId, 'solution', contextId);

      const callArgs = mockOpenAICreate.mock.calls[0][0];
      const userPrompt = callArgs.messages.find(m => m.role === 'user').content;

      expect(userPrompt).toContain('question');
      expect(userPrompt).toContain('Kinematics');
    });

    test('should generate quiz-specific greeting prompt', async () => {
      buildContext.mockResolvedValue({
        type: 'quiz',
        contextId: 'quiz123',
        title: 'Daily Quiz Review',
        snapshot: {
          score: 7,
          total: 10,
          accuracy: 70
        }
      });

      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: 'Greeting' } }],
        usage: { total_tokens: 50 }
      });

      await injectContext(userId, 'quiz', 'quiz123');

      const callArgs = mockOpenAICreate.mock.calls[0][0];
      const userPrompt = callArgs.messages.find(m => m.role === 'user').content;

      expect(userPrompt).toContain('7/10');
    });

    test('should generate analytics-specific greeting prompt', async () => {
      buildContext.mockResolvedValue({
        type: 'analytics',
        contextId: null,
        title: 'My Progress',
        snapshot: {
          overallPercentile: 75,
          subjectPerformance: []
        }
      });

      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: 'Greeting' } }],
        usage: { total_tokens: 50 }
      });

      await injectContext(userId, 'analytics', null);

      const callArgs = mockOpenAICreate.mock.calls[0][0];
      const userPrompt = callArgs.messages.find(m => m.role === 'user').content;

      expect(userPrompt).toContain('analytics');
    });

    test('should save greeting as assistant message', async () => {
      const greeting = 'Hello, welcome!';
      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: greeting } }],
        usage: { total_tokens: 50 }
      });

      await injectContext(userId, contextType, contextId);

      expect(addAssistantMessage).toHaveBeenCalledWith(userId, greeting);
    });
  });

  describe('getConversation', () => {
    const userId = 'user123';

    test('should return conversation with messages and context', async () => {
      const mockMessages = [
        { id: '1', type: 'assistant', content: 'Hello!' },
        { id: '2', type: 'user', content: 'Hi' }
      ];
      getConversationWithMessages.mockResolvedValue({
        messages: mockMessages,
        messageCount: 2
      });
      getMostRecentContext.mockResolvedValue({
        contextType: 'solution',
        contextId: 'snap123',
        contextTitle: 'Kinematics - Physics'
      });

      const result = await getConversation(userId);

      expect(result.messages).toEqual(mockMessages);
      expect(result.messageCount).toBe(2);
      expect(result.currentContext).toEqual({
        type: 'solution',
        id: 'snap123',
        title: 'Kinematics - Physics'
      });
    });

    test('should return null context if no recent context', async () => {
      getConversationWithMessages.mockResolvedValue({
        messages: [],
        messageCount: 0
      });
      getMostRecentContext.mockResolvedValue(null);

      const result = await getConversation(userId);

      expect(result.currentContext).toBeNull();
    });

    test('should respect limit parameter', async () => {
      getConversationWithMessages.mockResolvedValue({
        messages: [],
        messageCount: 0
      });
      getMostRecentContext.mockResolvedValue(null);

      await getConversation(userId, 100);

      expect(getConversationWithMessages).toHaveBeenCalledWith(userId, 100);
    });
  });

  describe('resetConversation', () => {
    const userId = 'user123';

    test('should clear conversation and log success', async () => {
      clearConversation.mockResolvedValue({});

      await resetConversation(userId);

      expect(clearConversation).toHaveBeenCalledWith(userId);
      expect(logger.info).toHaveBeenCalledWith(
        'Conversation reset',
        { userId }
      );
    });

    test('should throw error on failure', async () => {
      clearConversation.mockRejectedValue(new Error('Clear failed'));

      await expect(resetConversation(userId)).rejects.toThrow('Clear failed');
      expect(logger.error).toHaveBeenCalledWith(
        'Error resetting conversation',
        expect.objectContaining({ userId })
      );
    });
  });

  describe('generateWelcomeMessage', () => {
    const userId = 'user123';

    beforeEach(() => {
      getStudentProfile.mockResolvedValue({
        firstName: 'Rahul',
        overallPercentile: 70
      });
      addAssistantMessage.mockResolvedValue({});
    });

    test('should generate and save welcome message', async () => {
      const welcomeMsg = "Hello! I'm Priya Ma'am, your AI tutor...";
      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: welcomeMsg } }],
        usage: { total_tokens: 60 }
      });

      const result = await generateWelcomeMessage(userId);

      expect(result.message).toBe(welcomeMsg);
      expect(result.quickActions).toBeDefined();
      expect(result.tokensUsed).toBe(60);
      expect(addAssistantMessage).toHaveBeenCalledWith(userId, welcomeMsg);
    });

    test('should return fallback message on empty response', async () => {
      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: '' } }],
        usage: { total_tokens: 0 }
      });

      const result = await generateWelcomeMessage(userId);

      expect(result.message).toContain("Priya Ma'am");
    });

    test('should use general quick actions', async () => {
      mockOpenAICreate.mockResolvedValue({
        choices: [{ message: { content: 'Welcome!' } }],
        usage: { total_tokens: 30 }
      });

      await generateWelcomeMessage(userId);

      expect(getQuickActions).toHaveBeenCalledWith('general');
    });
  });
});
