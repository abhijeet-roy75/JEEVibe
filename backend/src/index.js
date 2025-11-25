/**
 * JEEVibe - Snap & Solve Backend Server
 * Express server for handling image uploads and OpenAI API calls
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const solveRouter = require('./routes/solve');

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  // Don't exit, just log the error
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  // Don't exit immediately, log and continue
});

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors()); // Enable CORS for Flutter app
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Routes
app.use('/api', solveRouter);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'JEEVibe Snap & Solve API',
    version: '1.0.0',
    endpoints: {
      health: '/api/health',
      solve: 'POST /api/solve'
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 JEEVibe backend server running on port ${PORT}`);
  console.log(`📝 API endpoint: http://localhost:${PORT}/api/solve`);
  console.log(`💚 Health check: http://localhost:${PORT}/api/health`);
  
  // Check for required environment variables
  if (!process.env.OPENAI_API_KEY) {
    console.warn('⚠️  WARNING: OPENAI_API_KEY not set in .env file');
  }
});

module.exports = app;

