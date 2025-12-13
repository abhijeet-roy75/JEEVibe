/**
 * Jest Setup File
 * Runs before all tests
 * 
 * Use this file to:
 * - Set up test environment variables
 * - Configure global mocks
 * - Set up test database connections
 * - Initialize test fixtures
 */

// Set test environment
process.env.NODE_ENV = 'test';

// Mock console methods to reduce noise in tests (optional)
// Uncomment if you want cleaner test output
// global.console = {
//   ...console,
//   log: jest.fn(),
//   debug: jest.fn(),
//   info: jest.fn(),
//   warn: jest.fn(),
//   error: jest.fn(),
// };

// Increase timeout for async operations
jest.setTimeout(10000);

// Global test utilities can be added here
// Example: global.testUtils = require('./helpers/testUtils');

