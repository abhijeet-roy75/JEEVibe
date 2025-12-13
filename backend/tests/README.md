# Backend Test Suite

Comprehensive test suite for JEEVibe backend API using Jest.

## Test Structure

```
tests/
├── unit/              # Unit tests for services, utilities
│   ├── services/      # Service layer tests
│   └── utils/         # Utility function tests
├── integration/       # Integration tests for API endpoints
│   └── api/           # API endpoint tests
├── helpers/           # Test utilities and helpers
├── fixtures/          # Test data and fixtures
├── mocks/             # Mock implementations
└── setup.js           # Jest setup file
```

## Running Tests

### Run All Tests
```bash
npm test
```

### Run Tests in Watch Mode (for development)
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

### Run Tests with Coverage Report
```bash
npm run test:coverage
```

Coverage report will be generated in `coverage/` directory. Open `coverage/lcov-report/index.html` in a browser to view detailed coverage.

## Test Categories

### 1. Unit Tests
Test individual functions and services in isolation:
- **Services**: `questionSelectionService`, `thetaUpdateService`, `spacedRepetitionService`, etc.
- **Utils**: Validation, retry logic, caching, etc.
- **Business Logic**: IRT calculations, theta updates, streak tracking

**Location**: `tests/unit/`

### 2. Integration Tests
Test API endpoints and full request/response cycles:
- **API Endpoints**: Daily quiz endpoints, progress endpoints, stats endpoints
- **Database Operations**: Firestore reads/writes (with mocks or test DB)
- **External Services**: Firebase Storage, Auth (mocked)

**Location**: `tests/integration/`

## Writing Tests

### Unit Test Example
```javascript
const { calculateFisherInformation } = require('../../src/services/questionSelectionService');

describe('Question Selection Service', () => {
  describe('calculateFisherInformation', () => {
    test('should calculate Fisher Information correctly', () => {
      const theta = 0.5;
      const question = {
        a: 1.5, // discrimination
        b: 0.0, // difficulty
        c: 0.25 // guessing
      };
      
      const info = calculateFisherInformation(theta, question);
      expect(info).toBeGreaterThan(0);
      expect(typeof info).toBe('number');
    });
  });
});
```

### Integration Test Example
```javascript
const request = require('supertest');
const app = require('../../src/index');

describe('Daily Quiz API', () => {
  test('GET /api/daily-quiz/generate should return quiz', async () => {
    const response = await request(app)
      .get('/api/daily-quiz/generate')
      .set('Authorization', `Bearer ${testToken}`)
      .expect(200);
    
    expect(response.body).toHaveProperty('quiz_id');
    expect(response.body).toHaveProperty('questions');
    expect(Array.isArray(response.body.questions)).toBe(true);
  });
});
```

## Mocking Firebase

For unit tests, mock Firebase operations:

```javascript
jest.mock('../../src/config/firebase', () => ({
  db: {
    collection: jest.fn(),
  },
  storage: {
    bucket: jest.fn(),
  },
}));
```

For integration tests, you can:
1. Use Firebase Emulator Suite (recommended for local testing)
2. Use a test Firebase project
3. Mock all Firebase operations

## Test Coverage Goals

- **Unit Tests**: 80%+ coverage for services and utilities
- **Integration Tests**: All critical API endpoints covered
- **Overall**: 70%+ code coverage

## CI/CD Integration

Tests run automatically on:
- **Pull Requests**: When backend code changes
- **Push to main/develop**: Before deployment
- **GitHub Actions**: See `.github/workflows/backend-tests.yml`

## Pre-Deployment Checklist

Before deploying, ensure:
- ✅ All unit tests pass
- ✅ All integration tests pass
- ✅ Code coverage > 70%
- ✅ No critical test failures
- ✅ All new features have tests

## Troubleshooting

### Tests failing with Firebase errors
- Ensure Firebase credentials are set up in test environment
- Use Firebase Emulator for local testing
- Mock Firebase operations in unit tests

### Tests timing out
- Increase timeout in `jest.config.js` or individual tests
- Check for hanging async operations
- Ensure proper cleanup in `afterEach` hooks

### Coverage not generating
- Run `npm run test:coverage` explicitly
- Check `coverage/` directory permissions
- Ensure `collectCoverage: true` in jest.config.js (or use --coverage flag)

