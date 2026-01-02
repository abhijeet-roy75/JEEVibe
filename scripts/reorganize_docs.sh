#!/bin/bash

# JEEVibe Documentation Reorganization Script
# This script moves documentation files into organized subdirectories

set -e  # Exit on error

DOCS_DIR="/Users/abhijeetroy/Documents/JEEVibe/docs"

cd "$DOCS_DIR"

echo "📂 Starting documentation reorganization..."

# Create directory structure
echo "Creating directories..."
mkdir -p 01-setup 02-architecture 03-features 04-deployment 05-testing 06-fixes 07-reviews 08-archive
mkdir -p 02-architecture/engine

# 01-setup/ - Initial Setup & Configuration
echo "Moving setup files..."
mv FIREBASE_SETUP.md 01-setup/ 2>/dev/null || true
mv FIREBASE_SETUP_COMPLETE.md 01-setup/ 2>/dev/null || true
mv FIREBASE_SETUP_GUIDE.md 01-setup/ 2>/dev/null || true
mv FIREBASE_PHONE_AUTH_SETUP.md 01-setup/ 2>/dev/null || true
mv ANDROID_FIREBASE_SHA_FIX.md 01-setup/ 2>/dev/null || true
mv PRODUCTION_PHONE_AUTH_SETUP.md 01-setup/ 2>/dev/null || true
mv ENV_FORMAT_GUIDE.md 01-setup/ 2>/dev/null || true
mv GET_TOKEN_GUIDE.md 01-setup/ 2>/dev/null || true
mv GITHUB_SETUP.md 01-setup/ 2>/dev/null || true
mv GITHUB_MULTIPLE_ACCOUNTS_SETUP.md 01-setup/ 2>/dev/null || true
mv ENABLE_GITHUB_PAGES.md 01-setup/ 2>/dev/null || true
mv iOS_APP_ICON_SETUP.md 01-setup/ 2>/dev/null || true

# 02-architecture/ - Architecture & Design
echo "Moving architecture files..."
mv DATABASE_DESIGN.md 02-architecture/ 2>/dev/null || true
mv DATABASE_DESIGN_V2.md 02-architecture/ 2>/dev/null || true
mv database-schema.md 02-architecture/ 2>/dev/null || true
mv ARCHITECTURAL_REVIEW.md 02-architecture/ 2>/dev/null || true
mv COMPREHENSIVE_ENGINEERING_REVIEW.md 02-architecture/ 2>/dev/null || true
mv UI_ARCHITECTURE_REVIEW.md 02-architecture/ 2>/dev/null || true
mv ARCHITECTURE_REVIEW_INITIAL_ASSESSMENT.md 02-architecture/ 2>/dev/null || true
mv DATABASE_SCHEMA_INITIAL_ASSESSMENT.md 02-architecture/ 2>/dev/null || true
mv AUTH_FLOW_DESIGN.md 02-architecture/ 2>/dev/null || true
mv scalability-analysis.md 02-architecture/ 2>/dev/null || true
mv theta-storage-strategy.md 02-architecture/ 2>/dev/null || true
mv DESIGN_REBUILD_PLAN.md 02-architecture/ 2>/dev/null || true
mv JEE_EXAM_FORMAT_ANALYSIS.md 02-architecture/ 2>/dev/null || true
mv JEE_SYLLABUS_INTEGRATION.md 02-architecture/ 2>/dev/null || true
mv FIREBASE_RECOMMENDATIONS.md 02-architecture/ 2>/dev/null || true
mv engine/JEEVibe_IIDP_Algorithm_Specification_v4_CALIBRATED.md 02-architecture/engine/ 2>/dev/null || true

# 03-features/ - Feature Implementation
echo "Moving feature files..."
mv FEATURE-GATING-SYSTEM.md 03-features/ 2>/dev/null || true
mv PAYWALL-SYSTEM-DESIGN.md 03-features/ 2>/dev/null || true
mv FORGOT-PIN-IMPLEMENTATION.md 03-features/ 2>/dev/null || true
mv ONBOARDING-SIMPLIFICATION-COMPLETE.md 03-features/ 2>/dev/null || true
mv AUTH_IMPLEMENTATION_TASKS.md 03-features/ 2>/dev/null || true
mv PIN_STORAGE_MIGRATION.md 03-features/ 2>/dev/null || true
mv STATE_PERSISTENCE_IMPLEMENTATION.md 03-features/ 2>/dev/null || true
mv Snap_Solve_POC_Implementation_Plan.md 03-features/ 2>/dev/null || true
mv SNAP_SOLVE_REVIEW.md 03-features/ 2>/dev/null || true
mv DAILY_QUIZ_UI_READINESS.md 03-features/ 2>/dev/null || true

# 04-deployment/ - Build & Deployment
echo "Moving deployment files..."
mv BUILD_AND_DEPLOY.md 04-deployment/ 2>/dev/null || true
mv BUILD_STATUS.md 04-deployment/ 2>/dev/null || true
mv DEPLOYMENT_GUIDE.md 04-deployment/ 2>/dev/null || true
mv QUICK_BUILD_GUIDE.md 04-deployment/ 2>/dev/null || true
mv ANDROID_BUILD_SETUP.md 04-deployment/ 2>/dev/null || true
mv IOS_BUILD_FIX_GUIDE.md 04-deployment/ 2>/dev/null || true
mv IOS_BUILD_METHODS.md 04-deployment/ 2>/dev/null || true
mv TESTFLIGHT_DEPLOYMENT.md 04-deployment/ 2>/dev/null || true
mv ACCEPT_PLA_STEPS.md 04-deployment/ 2>/dev/null || true
mv FIX_CODE_SIGNING.md 04-deployment/ 2>/dev/null || true
mv FIX_PODS_ERROR.md 04-deployment/ 2>/dev/null || true
mv XCODE_CLEAN_REBUILD.md 04-deployment/ 2>/dev/null || true
mv render-cron-setup.md 04-deployment/ 2>/dev/null || true
mv GOOGLE_PLAY_PRIVACY_POLICY.md 04-deployment/ 2>/dev/null || true
mv PRIVACY_POLICY.md 04-deployment/ 2>/dev/null || true

# 05-testing/ - Testing
echo "Moving testing files..."
mv TESTING_GUIDE.md 05-testing/ 2>/dev/null || true
mv MOBILE_TESTING_STRATEGY.md 05-testing/ 2>/dev/null || true
mv MOBILE_TESTING_IMPLEMENTATION.md 05-testing/ 2>/dev/null || true
mv TEST_STATUS.md 05-testing/ 2>/dev/null || true
mv TEST_RUN_SUMMARY.md 05-testing/ 2>/dev/null || true
mv ANDROID_EMULATOR_TESTING.md 05-testing/ 2>/dev/null || true
mv CIRCUIT_BREAKER_TEST_GUIDE.md 05-testing/ 2>/dev/null || true
mv LATEX_FIXES_TESTING_GUIDE.md 05-testing/ 2>/dev/null || true

# 06-fixes/ - Bug Fixes
echo "Moving fix files..."
mv CRITICAL_FIXES_APPLIED.md 06-fixes/ 2>/dev/null || true
mv CRITICAL_FIXES_IMPLEMENTED.md 06-fixes/ 2>/dev/null || true
mv HIGH_PRIORITY_FIXES_APPLIED.md 06-fixes/ 2>/dev/null || true
mv DAY1_FIXES_COMPLETE.md 06-fixes/ 2>/dev/null || true
mv FIXES_APPLIED.md 06-fixes/ 2>/dev/null || true
mv FIXES_APPLIED_QA.md 06-fixes/ 2>/dev/null || true
mv BUGFIX_NULL_TYPE_CAST.md 06-fixes/ 2>/dev/null || true
mv FIX_BUILD_ERRORS.md 06-fixes/ 2>/dev/null || true
mv ANDROID_BUILD_WARNINGS.md 06-fixes/ 2>/dev/null || true
mv HOME_SCREEN_PREVIEW_FIX.md 06-fixes/ 2>/dev/null || true
mv LATEX_OVERFLOW_FIX.md 06-fixes/ 2>/dev/null || true
mv LATEX_TEXT_WRAPPING_FIX.md 06-fixes/ 2>/dev/null || true
mv LATEX_FIXES_IMPLEMENTATION.md 06-fixes/ 2>/dev/null || true
mv LATEX_FIXES_ADDITIONAL_UPDATES.md 06-fixes/ 2>/dev/null || true
mv INDEX_FIX_PLAN.md 06-fixes/ 2>/dev/null || true
mv MOBILE_APP_UPDATE_REQUIRED.md 06-fixes/ 2>/dev/null || true
mv MOBILE_APP_UPDATES_COMPLETE.md 06-fixes/ 2>/dev/null || true
mv API_QUALITY_FIXES_APPLIED.md 06-fixes/ 2>/dev/null || true

# 07-reviews/ - Code Reviews & Quality
echo "Moving review files..."
mv QUALITY_REVIEW.md 07-reviews/ 2>/dev/null || true
mv QUALITY_ENGINEERING_REVIEW.md 07-reviews/ 2>/dev/null || true
mv QUALITY_ISSUES_REPORT.md 07-reviews/ 2>/dev/null || true
mv QUALITY_FIXES_IMPLEMENTED.md 07-reviews/ 2>/dev/null || true
mv UI_QUALITY_ASSESSMENT_REPORT.md 07-reviews/ 2>/dev/null || true
mv API_QUALITY_REVIEW.md 07-reviews/ 2>/dev/null || true
mv EXPERT_REVIEW_ANALYSIS.md 07-reviews/ 2>/dev/null || true
mv ARCHITECTURAL_REVIEW_THETA_CHANGES.md 07-reviews/ 2>/dev/null || true

# 08-archive/ - Completed/Legacy
echo "Moving archive files..."
mv SETUP_COMPLETE.md 08-archive/ 2>/dev/null || true
mv IMPLEMENTATION_COMPLETE.md 08-archive/ 2>/dev/null || true
mv IMPLEMENTATION_STATUS.md 08-archive/ 2>/dev/null || true
mv IMPLEMENTATION_SUMMARY.md 08-archive/ 2>/dev/null || true
mv IMPLEMENTATION_PLAN.md 08-archive/ 2>/dev/null || true
mv DATABASE_READY_CHECKLIST.md 08-archive/ 2>/dev/null || true
mv SCREEN_INTEGRATION_COMPLETE.md 08-archive/ 2>/dev/null || true
mv DESIGN_REBUILD_STATUS.md 08-archive/ 2>/dev/null || true
mv REBUILD_COMPLETE_SUMMARY.md 08-archive/ 2>/dev/null || true
mv UI_READINESS_FINAL.md 08-archive/ 2>/dev/null || true
mv FIRESTORE_INDEXES_COMPLETE.md 08-archive/ 2>/dev/null || true
mv NEXT_STEPS_AFTER_DAY1_FIXES.md 08-archive/ 2>/dev/null || true
mv PHASED_IMPLEMENTATION.md 08-archive/ 2>/dev/null || true
mv PHASE_1.1_REVIEW_AND_IMPROVEMENTS.md 08-archive/ 2>/dev/null || true
mv MVP_PRIORITIZATION.md 08-archive/ 2>/dev/null || true
mv MVP_FIX_PRIORITIES.md 08-archive/ 2>/dev/null || true
mv PRODUCT_CHANGES_SUMMARY.md 08-archive/ 2>/dev/null || true
mv database-migration-notes.md 08-archive/ 2>/dev/null || true
mv plan-review-summary.md 08-archive/ 2>/dev/null || true
mv MIGRATION_AND_TOOLS_DISCUSSION.md 08-archive/ 2>/dev/null || true

# Remove empty engine directory if it exists
rmdir engine 2>/dev/null || true

echo ""
echo "✅ Documentation reorganization complete!"
echo ""
echo "📂 New structure:"
echo "   01-setup/         - Setup & configuration guides"
echo "   02-architecture/  - System architecture & design"
echo "   03-features/      - Feature implementation docs"
echo "   04-deployment/    - Build & deployment guides"
echo "   05-testing/       - Testing documentation"
echo "   06-fixes/         - Bug fixes & issues"
echo "   07-reviews/       - Code reviews & quality"
echo "   08-archive/       - Completed/legacy docs"
echo "   claude-assessment/ - External assessment (unchanged)"
echo ""
echo "📖 See REORGANIZATION_README.md for navigation guide"
echo ""
echo "Files kept in root (active reference):"
ls -1 *.md 2>/dev/null | grep -v REORGANIZATION_README || echo "   (only REORGANIZATION_README.md)"
