/**
 * Tutor Conversation Service
 * Manages persistent conversation storage for AI Tutor (Priya Ma'am)
 * Uses Firestore for conversation and message persistence
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { v4: uuidv4 } = require('uuid');

// Collection paths
const CONVERSATION_DOC = 'active'; // Single active conversation per user

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

  const contextMarker = {
    id: messageId,
    type: 'context_marker',
    contextType: context.type,
    contextId: context.contextId,
    contextTitle: context.title,
    contextSnapshot: context.snapshot,
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
  hasConversation
};
