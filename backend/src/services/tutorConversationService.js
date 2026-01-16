/**
 * Tutor Conversation Service
 * Manages persistent conversation storage for AI Tutor (Priya Ma'am)
 * Uses Firestore for conversation and message persistence
 *
 * REQUIRED FIRESTORE INDEXES:
 * ===========================
 * Collection: users/{userId}/tutor_conversation/active/messages
 *
 * 1. Composite index for getRecentMessagesForLLM():
 *    - Fields: type (Ascending), timestamp (Descending)
 *    - Query scope: Collection
 *
 * 2. Single-field index for getMostRecentContext():
 *    - Fields: type (Ascending), timestamp (Descending)
 *    - Query scope: Collection
 *
 * 3. Single-field index for getConversationWithMessages():
 *    - Field: timestamp (Descending)
 *    - Query scope: Collection
 *
 * Create these indexes in Firebase Console or via firebase.indexes.json
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { v4: uuidv4 } = require('uuid');

// Collection paths
const CONVERSATION_DOC = 'active'; // Single active conversation per user

// Configuration constants
const MAX_CONVERSATION_MESSAGES = parseInt(process.env.AI_TUTOR_MAX_MESSAGES, 10) || 1000;
const CLEANUP_BATCH_SIZE = 100; // Number of old messages to delete when limit is reached
const MAX_SNAPSHOT_SIZE_BYTES = 50000; // ~50KB limit for context snapshots

/**
 * Get conversation reference for a user
 * @param {string} userId - User ID
 * @returns {DocumentReference}
 */
function getConversationRef(userId) {
  return db.collection('users').doc(userId)
    .collection('tutor_conversation').doc(CONVERSATION_DOC);
}

/**
 * Get messages collection reference for a user
 * @param {string} userId - User ID
 * @returns {CollectionReference}
 */
function getMessagesRef(userId) {
  return getConversationRef(userId).collection('messages');
}

/**
 * Truncate context snapshot to prevent exceeding Firestore document limits
 * @param {Object} snapshot - The context snapshot object
 * @returns {Object} Truncated snapshot
 */
function truncateSnapshot(snapshot) {
  if (!snapshot) return null;

  const truncated = { ...snapshot };

  // Truncate question text if too long
  if (truncated.question && truncated.question.length > 2000) {
    truncated.question = truncated.question.substring(0, 2000) + '... [truncated]';
  }

  // Limit steps array
  if (truncated.steps && Array.isArray(truncated.steps)) {
    truncated.steps = truncated.steps.slice(0, 10).map(step =>
      step.length > 500 ? step.substring(0, 500) + '...' : step
    );
  }

  // Limit incorrect questions for quiz context
  if (truncated.incorrectQuestions && Array.isArray(truncated.incorrectQuestions)) {
    truncated.incorrectQuestions = truncated.incorrectQuestions.slice(0, 5);
  }

  // Remove large fields that aren't essential for context
  delete truncated.imageUrl; // Don't store image URLs in context markers

  // Final size check - if still too large, remove detailed content
  const estimatedSize = JSON.stringify(truncated).length;
  if (estimatedSize > MAX_SNAPSHOT_SIZE_BYTES) {
    logger.warn('Context snapshot exceeds size limit, further truncating', {
      originalSize: estimatedSize,
      maxSize: MAX_SNAPSHOT_SIZE_BYTES
    });
    // Keep only essential metadata
    return {
      subject: truncated.subject,
      topic: truncated.topic,
      score: truncated.score,
      total: truncated.total,
      _truncated: true
    };
  }

  return truncated;
}

/**
 * Cleanup old messages when conversation exceeds limit
 * @param {string} userId - User ID
 * @param {number} currentCount - Current message count
 */
async function cleanupOldMessages(userId, currentCount) {
  if (currentCount < MAX_CONVERSATION_MESSAGES) return;

  const messagesRef = getMessagesRef(userId);
  const conversationRef = getConversationRef(userId);

  try {
    // Get oldest messages to delete
    const oldestMessages = await messagesRef
      .orderBy('timestamp', 'asc')
      .limit(CLEANUP_BATCH_SIZE)
      .get();

    if (oldestMessages.empty) return;

    // Delete in batch
    const batch = db.batch();
    let deleteCount = 0;

    oldestMessages.docs.forEach(doc => {
      batch.delete(doc.ref);
      deleteCount++;
    });

    // Update message count
    batch.update(conversationRef, {
      messageCount: admin.firestore.FieldValue.increment(-deleteCount)
    });

    await batch.commit();

    logger.info('Cleaned up old conversation messages', {
      userId,
      deletedCount: deleteCount,
      previousCount: currentCount
    });
  } catch (error) {
    // Log but don't fail the main operation
    logger.error('Error cleaning up old messages', { userId, error: error.message });
  }
}

/**
 * Get or create conversation for a user
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Conversation data
 */
async function getOrCreateConversation(userId) {
  const conversationRef = getConversationRef(userId);

  return await retryFirestoreOperation(async () => {
    const doc = await conversationRef.get();

    if (doc.exists) {
      return {
        ...doc.data(),
        id: doc.id
      };
    }

    // Create new conversation
    const newConversation = {
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      messageCount: 0,
      currentContext: null
    };

    await conversationRef.set(newConversation);

    return {
      ...newConversation,
      id: CONVERSATION_DOC,
      createdAt: new Date(),
      updatedAt: new Date()
    };
  });
}

/**
 * Get conversation with recent messages
 * @param {string} userId - User ID
 * @param {number} limit - Max messages to return (default: 50)
 * @returns {Promise<Object>} Conversation with messages
 */
async function getConversationWithMessages(userId, limit = 50) {
  try {
    const conversation = await getOrCreateConversation(userId);
    const messagesRef = getMessagesRef(userId);

    const messagesSnapshot = await retryFirestoreOperation(() =>
      messagesRef
        .orderBy('timestamp', 'desc')
        .limit(limit)
        .get()
    );

    const messages = messagesSnapshot.docs
      .map(doc => ({
        id: doc.id,
        ...doc.data(),
        timestamp: doc.data().timestamp?.toDate?.() || new Date()
      }))
      .reverse(); // Chronological order

    return {
      ...conversation,
      messages
    };
  } catch (error) {
    logger.error('Error getting conversation with messages', { userId, error: error.message });
    throw error;
  }
}

/**
 * Add a user message to the conversation
 * @param {string} userId - User ID
 * @param {string} content - Message content
 * @returns {Promise<Object>} Created message
 */
async function addUserMessage(userId, content) {
  const messagesRef = getMessagesRef(userId);
  const conversationRef = getConversationRef(userId);
  const messageId = uuidv4();

  const message = {
    id: messageId,
    type: 'user',
    content: content,
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  };

  await retryFirestoreOperation(async () => {
    const batch = db.batch();

    // Add message
    batch.set(messagesRef.doc(messageId), message);

    // Update conversation metadata
    batch.update(conversationRef, {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      messageCount: admin.firestore.FieldValue.increment(1)
    });

    await batch.commit();
  });

  return {
    ...message,
    timestamp: new Date()
  };
}

/**
 * Add an assistant message to the conversation
 * @param {string} userId - User ID
 * @param {string} content - Message content
 * @returns {Promise<Object>} Created message
 */
async function addAssistantMessage(userId, content) {
  const messagesRef = getMessagesRef(userId);
  const conversationRef = getConversationRef(userId);
  const messageId = uuidv4();

  const message = {
    id: messageId,
    type: 'assistant',
    content: content,
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  };

  await retryFirestoreOperation(async () => {
    const batch = db.batch();

    // Add message
    batch.set(messagesRef.doc(messageId), message);

    // Update conversation metadata
    batch.update(conversationRef, {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      messageCount: admin.firestore.FieldValue.increment(1)
    });

    await batch.commit();
  });

  return {
    ...message,
    timestamp: new Date()
  };
}

/**
 * Add a context marker to the conversation
 * Context markers indicate topic/context switches (e.g., starting to discuss a new solution)
 * @param {string} userId - User ID
 * @param {Object} context - Context object from aiTutorContextService
 * @returns {Promise<Object>} Created context marker
 */
async function addContextMarker(userId, context) {
  const messagesRef = getMessagesRef(userId);
  const conversationRef = getConversationRef(userId);
  const messageId = uuidv4();

  // Truncate snapshot to prevent document size issues
  const truncatedSnapshot = truncateSnapshot(context.snapshot);

  const contextMarker = {
    id: messageId,
    type: 'context_marker',
    contextType: context.type,
    contextId: context.contextId,
    contextTitle: context.title,
    contextSnapshot: truncatedSnapshot,
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  };

  await retryFirestoreOperation(async () => {
    const batch = db.batch();

    // Add context marker as a message
    batch.set(messagesRef.doc(messageId), contextMarker);

    // Update conversation with current context
    batch.update(conversationRef, {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      messageCount: admin.firestore.FieldValue.increment(1),
      currentContext: {
        type: context.type,
        contextId: context.contextId,
        title: context.title,
        injectedAt: admin.firestore.FieldValue.serverTimestamp()
      }
    });

    await batch.commit();
  });

  // Trigger cleanup if needed (non-blocking)
  const conversation = await getOrCreateConversation(userId);
  cleanupOldMessages(userId, conversation.messageCount).catch(() => {});

  return {
    ...contextMarker,
    timestamp: new Date()
  };
}

/**
 * Get recent messages for LLM context (rolling window)
 * Only returns user and assistant messages (not context markers)
 * @param {string} userId - User ID
 * @param {number} limit - Max messages (default: 20)
 * @returns {Promise<Array>} Recent messages formatted for LLM
 */
async function getRecentMessagesForLLM(userId, limit = 20) {
  const messagesRef = getMessagesRef(userId);

  const snapshot = await retryFirestoreOperation(() =>
    messagesRef
      .where('type', 'in', ['user', 'assistant'])
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .get()
  );

  return snapshot.docs
    .map(doc => ({
      role: doc.data().type === 'user' ? 'user' : 'assistant',
      content: doc.data().content
    }))
    .reverse(); // Chronological order for LLM
}

/**
 * Get the most recent context marker (for current context)
 * @param {string} userId - User ID
 * @returns {Promise<Object|null>} Most recent context marker or null
 */
async function getMostRecentContext(userId) {
  const messagesRef = getMessagesRef(userId);

  const snapshot = await retryFirestoreOperation(() =>
    messagesRef
      .where('type', '==', 'context_marker')
      .orderBy('timestamp', 'desc')
      .limit(1)
      .get()
  );

  if (snapshot.empty) {
    return null;
  }

  const doc = snapshot.docs[0];
  return {
    id: doc.id,
    ...doc.data(),
    timestamp: doc.data().timestamp?.toDate?.() || new Date()
  };
}

/**
 * Clear conversation (delete all messages and reset)
 * Used when user wants a fresh start
 * @param {string} userId - User ID
 * @returns {Promise<void>}
 */
async function clearConversation(userId) {
  const conversationRef = getConversationRef(userId);
  const messagesRef = getMessagesRef(userId);

  await retryFirestoreOperation(async () => {
    // Get all message documents
    const messagesSnapshot = await messagesRef.get();

    // Delete in batches (Firestore limit is 500 per batch)
    const batchSize = 450;
    const batches = [];
    let currentBatch = db.batch();
    let operationCount = 0;

    messagesSnapshot.docs.forEach(doc => {
      currentBatch.delete(doc.ref);
      operationCount++;

      if (operationCount >= batchSize) {
        batches.push(currentBatch);
        currentBatch = db.batch();
        operationCount = 0;
      }
    });

    // Add remaining operations
    if (operationCount > 0) {
      batches.push(currentBatch);
    }

    // Execute all batches
    await Promise.all(batches.map(batch => batch.commit()));

    // Reset conversation metadata
    await conversationRef.set({
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      messageCount: 0,
      currentContext: null
    });
  });

  logger.info('Conversation cleared', { userId });
}

/**
 * Get conversation message count
 * @param {string} userId - User ID
 * @returns {Promise<number>} Message count
 */
async function getMessageCount(userId) {
  const conversation = await getOrCreateConversation(userId);
  return conversation.messageCount || 0;
}

/**
 * Check if conversation has any messages
 * @param {string} userId - User ID
 * @returns {Promise<boolean>}
 */
async function hasConversation(userId) {
  const count = await getMessageCount(userId);
  return count > 0;
}

/**
 * Update token usage statistics for a user
 * Tracks AI token consumption for billing/analytics
 * @param {string} userId - User ID
 * @param {number} tokensUsed - Number of tokens consumed
 * @param {string} model - Model name used
 * @returns {Promise<void>}
 */
async function updateTokenUsage(userId, tokensUsed, model = 'gpt-4o-mini') {
  if (!tokensUsed || tokensUsed <= 0) return;

  const userRef = db.collection('users').doc(userId);

  try {
    await retryFirestoreOperation(async () => {
      await userRef.set({
        tutor_stats: {
          total_tokens_used: admin.firestore.FieldValue.increment(tokensUsed),
          last_interaction: admin.firestore.FieldValue.serverTimestamp(),
          interaction_count: admin.firestore.FieldValue.increment(1),
          // Track by model for cost analysis
          [`tokens_by_model.${model.replace(/[.-]/g, '_')}`]: admin.firestore.FieldValue.increment(tokensUsed)
        }
      }, { merge: true });
    });
  } catch (error) {
    // Log but don't fail the main operation - token tracking is non-critical
    logger.warn('Failed to update token usage', { userId, tokensUsed, error: error.message });
  }
}

module.exports = {
  getOrCreateConversation,
  getConversationWithMessages,
  addUserMessage,
  addAssistantMessage,
  addContextMarker,
  getRecentMessagesForLLM,
  getMostRecentContext,
  clearConversation,
  getMessageCount,
  hasConversation,
  updateTokenUsage
};
