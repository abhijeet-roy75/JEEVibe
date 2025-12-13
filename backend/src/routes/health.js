/**
 * Health Check Endpoint
 * 
 * Checks status of all dependencies
 * Used for monitoring and load balancer health checks
 */

const { db, admin } = require('../config/firebase');
const logger = require('../utils/logger');

/**
 * Check Firestore connectivity
 */
async function checkFirestore() {
  const startTime = Date.now();
  try {
    // Just read from an existing collection (don't create documents)
    // Use a collection that should exist (users) with limit 1 for minimal cost
    const usersRef = db.collection('users').limit(1);
    await usersRef.get();
    
    const latency = Date.now() - startTime;
    return { status: 'ok', latency };
  } catch (error) {
    logger.error('Firestore health check failed', { error: error.message });
    return { status: 'error', error: error.message };
  }
}

/**
 * Check Firebase Auth connectivity
 */
async function checkFirebaseAuth() {
  try {
    // Just check if admin SDK is initialized
    const apps = admin.apps;
    if (apps.length > 0) {
      return { status: 'ok' };
    }
    return { status: 'error', error: 'Firebase Admin not initialized' };
  } catch (error) {
    logger.error('Firebase Auth health check failed', { error: error.message });
    return { status: 'error', error: error.message };
  }
}

/**
 * GET /api/health
 * 
 * Returns health status of the API and all dependencies
 */
async function healthCheck(req, res) {
  const startTime = Date.now();
  
  try {
    // Check all dependencies in parallel
    const [firestore, firebaseAuth] = await Promise.all([
      checkFirestore(),
      checkFirebaseAuth(),
    ]);

    const health = {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development',
      version: '1.0.0',
      services: {
        firestore,
        firebaseAuth,
      },
      responseTime: Date.now() - startTime,
    };

    // Determine overall health
    const allHealthy = Object.values(health.services).every(
      service => service.status === 'ok'
    );

    if (!allHealthy) {
      health.status = 'degraded';
      logger.warn('Health check: Degraded service', health);
    }

    // Return 200 if healthy, 503 if degraded
    const statusCode = allHealthy ? 200 : 503;
    res.status(statusCode).json(health);
  } catch (error) {
    logger.error('Health check failed', {
      error: error.message,
      stack: error.stack,
    });

    res.status(503).json({
      status: 'error',
      timestamp: new Date().toISOString(),
      error: 'Health check failed',
      responseTime: Date.now() - startTime,
    });
  }
}

module.exports = healthCheck;

