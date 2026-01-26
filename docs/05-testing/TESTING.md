# Testing Guide for JEEVibe Backend

## Overview

JEEVibe backend uses **Jest** (free and open source) for unit and integration testing. Tests run automatically on every build via GitHub Actions.

## Quick Start

### Run All Tests
```bash
npm test
```

### Run Tests in Watch Mode (Development)
```bash
npm run test:watch
```

### Run Only Unit Tests
```bash
npm run test:unit
```

### Run Only Integration Tests
```bash
npm run test:integration
```

### Generate Coverage Report
```bash
npm run test:coverage
```

View coverage report: Open `coverage/lcov-report/index.html` in your browser.

## Test Structure

```
backend/
├── tests/
│   ├── unit/              # Unit tests (isolated function testing)
│   │   └── services/     # Service layer tests
│   ├── integration/      # Integration tests (API endpoints)
│   │   └── api/          # API endpoint tests
│   ├── helpers/          # Test utilities
│   ├── fixtures/         # Test data
│   └── setup.js          # Jest configuration
├── jest.config.js        # Jest configuration
└── package.json          # Test scripts
```

## Automated Testing

### GitHub Actions (CI/CD)

Tests run automatically on:
- **Pull Requests**: When backend code changes
- **Push to main/develop**: Before deployment

Workflow file: `.github/workflows/backend-tests.yml`

### Render.com Integration

To run tests before deployment on Render.com:

1. **Option 1: Add Build Command**
   - In Render dashboard, set Build Command: `npm install && npm test`
   - Tests must pass before deployment

2. **Option 2: Pre-deploy Script**
   - Add to `package.json`:
   ```json
   "scripts": {
     "predeploy": "npm test"
   }
   ```

## Test Categories

### Unit Tests (`tests/unit/`)

Test individual functions and services in isolation:
- ✅ IRT calculations (Fisher Information, probability)
- ✅ Theta updates and bounding
- ✅ Spaced repetition intervals
- ✅ Business logic functions

**Example:**
```javascript
test('should calculate Fisher Information correctly', () => {
  const fi = calculateFisherInformation(0.0, 1.5, 0.0, 0.25);
  expect(fi).toBeGreaterThan(0);
});
```

### Integration Tests (`tests/integration/`)

Test full API endpoints and request/response cycles:
- ✅ Daily quiz generation
- ✅ Quiz completion and theta updates
- ✅ Progress tracking
- ✅ Error handling

**Example:**
```javascript
test('should generate quiz with valid structure', async () => {
  const response = await request(app)
    .get('/api/daily-quiz/generate')
    .set('Authorization', `Bearer ${token}`)
    .expect(200);
  
  expect(response.body).toHaveProperty('quiz_id');
});
```

## Writing New Tests

### Unit Test Template

```javascript
const service = require('../../src/services/myService');

describe('My Service', () => {
  describe('myFunction', () => {
    test('should handle normal case', () => {
      const result = service.myFunction(input);
      expect(result).toBe(expected);
    });

    test('should handle edge case', () => {
      const result = service.myFunction(edgeInput);
      expect(result).toBeDefined();
    });
  });
});
```

### Integration Test Template

```javascript
const request = require('supertest');
const app = require('../../src/index');

describe('My API Endpoint', () => {
  test('should return 200 with valid request', async () => {
    const response = await request(app)
      .get('/api/my-endpoint')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    
    expect(response.body).toHaveProperty('data');
  });
});
```

## Mocking Firebase

For unit tests, Firebase is automatically mocked. For integration tests:

### Option 1: Firebase Emulator (Recommended for Local)
```bash
# Install Firebase Emulator
npm install -g firebase-tools
firebase init emulators

# Run emulator
firebase emulators:start

# Set environment variable
export FIRESTORE_EMULATOR_HOST=localhost:8080
```

### Option 2: Test Firebase Project
- Create a separate Firebase project for testing
- Use test credentials in `.env.test`

### Option 3: Mock Everything (Current)
- All Firebase operations are mocked in tests
- See `tests/integration/api/dailyQuiz.test.js` for examples

## Coverage Goals

- **Unit Tests**: 80%+ coverage for services
- **Integration Tests**: All critical endpoints covered
- **Overall**: 70%+ code coverage

Current coverage can be viewed with:
```bash
npm run test:coverage
```

## Troubleshooting

### Tests Failing Locally

1. **Check Node version**: Requires Node 18+
   ```bash
   node --version
   ```

2. **Reinstall dependencies**:
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

3. **Clear Jest cache**:
   ```bash
   npm test -- --clearCache
   ```

### Tests Failing in CI/CD

1. **Check GitHub Actions logs**: `.github/workflows/backend-tests.yml`
2. **Verify environment variables**: Some tests may need Firebase credentials
3. **Check Node version**: CI uses Node 18.x and 20.x

### Firebase Connection Issues

- Unit tests: Firebase is mocked, no connection needed
- Integration tests: Use Firebase Emulator or test project

## Best Practices

1. **Write tests first** (TDD) for new features
2. **Test edge cases**: Empty inputs, null values, extreme values
3. **Keep tests isolated**: Each test should be independent
4. **Use descriptive names**: `test('should return error when user not found')`
5. **Mock external dependencies**: Firebase, APIs, file system
6. **Clean up after tests**: Use `afterEach` hooks

## Pre-Deployment Checklist

Before deploying to production:
- ✅ All tests pass locally: `npm test`
- ✅ All tests pass in CI: Check GitHub Actions
- ✅ Coverage > 70%: `npm run test:coverage`
- ✅ No critical test failures
- ✅ New features have tests

## Resources

- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Supertest Documentation](https://github.com/visionmedia/supertest)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)

