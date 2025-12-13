# Mobile Test Suite

Comprehensive test suite for JEEVibe mobile app that runs before deployments.

## Test Structure

```
test/
├── unit/              # Unit tests for services, models, utilities
├── widget/            # Widget tests for UI components
├── integration/       # Integration tests for user flows
├── fixtures/          # Test data and fixtures
├── mocks/             # Mock implementations
└── helpers/           # Test utilities and helpers
```

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test Suites
```bash
# Unit tests only
flutter test test/unit/

# Widget tests only
flutter test test/widget/

# Integration tests only
flutter test test/integration/
```

### Run Before Deployment
```bash
# Run full test suite with coverage
./scripts/run_tests.sh

# Run tests and generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Test Coverage Goals

- **Unit Tests:** 80%+ coverage for services, models, utilities
- **Widget Tests:** 70%+ coverage for critical UI components
- **Integration Tests:** All critical user flows covered

## Test Categories

### 1. Unit Tests
- Service layer (API, Storage, Auth)
- Model parsing and validation
- Utility functions
- Business logic

### 2. Widget Tests
- Screen rendering
- User interactions
- State management
- Navigation

### 3. Integration Tests
- Authentication flow
- Assessment flow
- Snap & Solve flow
- Profile management
- Error handling

## Pre-Deployment Checklist

Before deploying, ensure:
- ✅ All unit tests pass
- ✅ All widget tests pass
- ✅ All integration tests pass
- ✅ Code coverage > 70%
- ✅ No critical test failures
- ✅ Performance tests pass

