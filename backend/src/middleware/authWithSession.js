/**
 * Combined Authentication and Session Validation Middleware
 *
 * This middleware combines authenticateUser and validateSessionMiddleware
 * to simplify route definitions. Use this for most authenticated routes.
 *
 * For routes that need auth but NOT session validation (e.g., profile GET during login),
 * use authenticateUser alone.
 */

const { authenticateUser } = require('./auth');
const { validateSessionMiddleware } = require('./sessionValidator');

/**
 * Authenticate user AND validate session
 * Use this for most authenticated routes to enforce single-device login
 */
async function authenticateWithSession(req, res, next) {
  // First authenticate the user (sets req.userId)
  await authenticateUser(req, res, (error) => {
    if (error) {
      return next(error);
    }

    // Then validate the session (requires req.userId)
    validateSessionMiddleware(req, res, next);
  });
}

module.exports = {
  authenticateWithSession
};
