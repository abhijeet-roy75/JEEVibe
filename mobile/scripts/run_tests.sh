#!/bin/bash

# Mobile Test Runner Script
# Runs all tests before deployment

set -e  # Exit on error

echo "🧪 Running JEEVibe Mobile Test Suite..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run tests and capture results
run_test_suite() {
    local suite_name=$1
    local test_path=$2
    
    echo "📦 Running $suite_name tests..."
    
    if flutter test "$test_path" --reporter expanded; then
        echo -e "${GREEN}✅ $suite_name tests passed${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ $suite_name tests failed${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    exit 1
fi

# Get Flutter version
FLUTTER_VERSION=$(flutter --version | head -n 1)
echo "Flutter: $FLUTTER_VERSION"
echo ""

# Clean previous test results
echo "🧹 Cleaning previous test results..."
flutter clean
flutter pub get
echo ""

# Run unit tests
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "UNIT TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
run_test_suite "Unit" "test/unit/"

# Run widget tests
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "WIDGET TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
run_test_suite "Widget" "test/widget/"

# Run integration tests
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "INTEGRATION TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
run_test_suite "Integration" "test/integration/"

# Generate coverage report
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "COVERAGE REPORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Generating coverage report..."

if flutter test --coverage; then
    # Check if lcov is available for HTML report
    if command -v genhtml &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html
        echo -e "${GREEN}✅ Coverage report generated at coverage/html/index.html${NC}"
    else
        echo -e "${YELLOW}⚠️  genhtml not found. Install lcov for HTML coverage report${NC}"
        echo "Coverage data available at coverage/lcov.info"
    fi
else
    echo -e "${RED}❌ Failed to generate coverage report${NC}"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Tests Passed: $TESTS_PASSED"
echo "❌ Tests Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! Ready for deployment.${NC}"
    exit 0
else
    echo -e "${RED}💥 Some tests failed. Please fix before deploying.${NC}"
    exit 1
fi

