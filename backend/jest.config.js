/**
 * Jest Configuration for JEEVibe Backend
 * 
 * Test Structure:
 * - Unit tests: tests/unit/ (all .test.js files)
 * - Integration tests: tests/integration/ (all .test.js files)
 */

module.exports = {
  // Test environment
  testEnvironment: 'node',
  
  // Root directory for tests
  roots: ['<rootDir>/tests'],
  
  // Test file patterns
  testMatch: [
    '**/__tests__/**/*.js',
    '**/?(*.)+(spec|test).js'
  ],
  
  // Coverage configuration
  collectCoverage: false, // Set to true when running coverage
  coverageDirectory: 'coverage',
  coveragePathIgnorePatterns: [
    '/node_modules/',
    '/tests/',
    '/scripts/',
    '/coverage/',
    'jest.config.js'
  ],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/index.js', // Exclude entry point
    '!src/config/**', // Exclude config (has secrets)
  ],
  
  // Coverage thresholds (optional - uncomment when ready)
  // coverageThresholds: {
  //   global: {
  //     branches: 70,
  //     functions: 70,
  //     lines: 70,
  //     statements: 70
  //   }
  // },
  
  // Setup files
  setupFilesAfterEnv: ['<rootDir>/tests/setup.js'],
  
  // Module paths
  moduleDirectories: ['node_modules', '<rootDir>/src'],
  
  // Clear mocks between tests
  clearMocks: true,
  
  // Verbose output
  verbose: true,
  
  // Test timeout (5 seconds default, increase for integration tests)
  testTimeout: 10000,
  
  // Ignore patterns
  testPathIgnorePatterns: [
    '/node_modules/',
    '/coverage/'
  ],
  
  // Transform (if needed for TypeScript or other)
  // transform: {},
  
  // Global variables available in tests
  globals: {
    'NODE_ENV': 'test'
  }
};

