# JEEVibe Documentation - Organization Guide

## 📂 Directory Structure

The documentation has been reorganized for easier navigation. Here's the new structure:

### **01-setup/** - Initial Setup & Configuration
Getting started guides, Firebase setup, environment configuration, and deployment keys.

**Key Files:**
- [FIREBASE_SETUP_GUIDE.md](01-setup/FIREBASE_SETUP_GUIDE.md) - Complete Firebase setup
- [ENV_FORMAT_GUIDE.md](01-setup/ENV_FORMAT_GUIDE.md) - Environment variable setup
- [GITHUB_SETUP.md](01-setup/GITHUB_SETUP.md) - Git repository configuration

---

### **02-architecture/** - System Architecture & Design
Database schemas, system architecture reviews, and design decisions.

**Key Files:**
- [DATABASE_DESIGN_V2.md](02-architecture/DATABASE_DESIGN_V2.md) - Current database schema
- [ARCHITECTURAL_REVIEW.md](02-architecture/ARCHITECTURAL_REVIEW.md) - System architecture overview
- [engine/JEEVibe_IIDP_Algorithm_Specification_v4_CALIBRATED.md](02-architecture/engine/JEEVibe_IIDP_Algorithm_Specification_v4_CALIBRATED.md) - IRT algorithm spec

---

### **03-features/** - Feature Implementation
Documentation for specific features, from design to implementation.

**Key Files:**
- [PAYWALL-SYSTEM-DESIGN.md](03-features/PAYWALL-SYSTEM-DESIGN.md) - Subscription/payment system design
- [FEATURE-GATING-SYSTEM.md](03-features/FEATURE-GATING-SYSTEM.md) - Free vs Pro feature control
- [FORGOT-PIN-IMPLEMENTATION.md](03-features/FORGOT-PIN-IMPLEMENTATION.md) - PIN reset flow
- [ONBOARDING-SIMPLIFICATION-COMPLETE.md](03-features/ONBOARDING-SIMPLIFICATION-COMPLETE.md) - Simplified user onboarding

---

### **04-deployment/** - Build & Deployment
Build processes, deployment guides, and platform-specific setup.

**Key Files:**
- [DEPLOYMENT_GUIDE.md](04-deployment/DEPLOYMENT_GUIDE.md) - Production deployment steps
- [QUICK_BUILD_GUIDE.md](04-deployment/QUICK_BUILD_GUIDE.md) - Fast local builds
- [TESTFLIGHT_DEPLOYMENT.md](04-deployment/TESTFLIGHT_DEPLOYMENT.md) - iOS TestFlight setup

---

### **05-testing/** - Testing Documentation
Testing strategies, guides, and test result summaries.

**Key Files:**
- [TESTING_GUIDE.md](05-testing/TESTING_GUIDE.md) - Comprehensive testing guide
- [MOBILE_TESTING_STRATEGY.md](05-testing/MOBILE_TESTING_STRATEGY.md) - Mobile app testing approach

---

### **06-fixes/** - Bug Fixes & Issues
Documentation for bugs fixed and ongoing issues.

**Key Files:**
- [CRITICAL_FIXES_APPLIED.md](06-fixes/CRITICAL_FIXES_APPLIED.md) - Critical bug fixes log
- [DAY1_FIXES_COMPLETE.md](06-fixes/DAY1_FIXES_COMPLETE.md) - Initial launch fixes

---

### **07-reviews/** - Code Reviews & Quality Assessments
Quality audits, code reviews, and improvement recommendations.

**Key Files:**
- [QUALITY_ENGINEERING_REVIEW.md](07-reviews/QUALITY_ENGINEERING_REVIEW.md) - Engineering quality audit
- [EXPERT_REVIEW_ANALYSIS.md](07-reviews/EXPERT_REVIEW_ANALYSIS.md) - External expert feedback

---

### **08-archive/** - Completed/Legacy Documentation
Older documents retained for reference but no longer actively maintained.

---

### **claude-assessment/** - External Assessment Reports
Independent architectural and code quality assessment (kept separate).

**Key Files:**
- [EXECUTIVE-SUMMARY.md](claude-assessment/EXECUTIVE-SUMMARY.md)
- [SUBCOLLECTION-REFACTORING-COMPLETE.md](claude-assessment/SUBCOLLECTION-REFACTORING-COMPLETE.md)

---

### **Root (Active Reference)** - Frequently Used Docs
Documents that need quick access remain in the root directory.

**Key Files:**
- [README.md](README.md) - Main documentation index
- [walkthrough.md](walkthrough.md) - Product walkthrough
- [API_ENDPOINTS_COMPLETE.md](API_ENDPOINTS_COMPLETE.md) - API reference
- [FIRESTORE_INDEXES.md](FIRESTORE_INDEXES.md) - Current Firestore indexes
- [FIRESTORE_SECURITY_RULES.md](FIRESTORE_SECURITY_RULES.md) - Security rules

---

## 🔍 Finding What You Need

### Common Tasks:

**"I need to set up Firebase for the first time"**
→ [01-setup/FIREBASE_SETUP_GUIDE.md](01-setup/FIREBASE_SETUP_GUIDE.md)

**"I need to understand the database schema"**
→ [02-architecture/DATABASE_DESIGN_V2.md](02-architecture/DATABASE_DESIGN_V2.md)

**"I need to implement the paywall"**
→ [03-features/PAYWALL-SYSTEM-DESIGN.md](03-features/PAYWALL-SYSTEM-DESIGN.md)

**"I need to deploy to production"**
→ [04-deployment/DEPLOYMENT_GUIDE.md](04-deployment/DEPLOYMENT_GUIDE.md)

**"I need to run tests"**
→ [05-testing/TESTING_GUIDE.md](05-testing/TESTING_GUIDE.md)

**"I need to check API endpoints"**
→ [API_ENDPOINTS_COMPLETE.md](API_ENDPOINTS_COMPLETE.md) (root)

**"I need to check Firestore indexes"**
→ [FIRESTORE_INDEXES.md](FIRESTORE_INDEXES.md) (root)

---

## 📋 Document Naming Conventions

- `*_GUIDE.md` - Step-by-step instructions
- `*_DESIGN.md` - Design documents and architecture
- `*_IMPLEMENTATION.md` - Implementation details
- `*_COMPLETE.md` - Completed work summaries
- `*_REVIEW.md` - Code/quality reviews
- `*_FIX.md` - Bug fix documentation

---

## 🗂️ Migration Note

All documents have been moved to organized subdirectories. If you have bookmarks or links to old paths, update them using this mapping:

**Old:** `/docs/FIREBASE_SETUP.md`
**New:** `/docs/01-setup/FIREBASE_SETUP.md`

**Old:** `/docs/DATABASE_DESIGN_V2.md`
**New:** `/docs/02-architecture/DATABASE_DESIGN_V2.md`

**Old:** `/docs/PAYWALL-SYSTEM-DESIGN.md`
**New:** `/docs/03-features/PAYWALL-SYSTEM-DESIGN.md`

---

## 📌 Quick Reference

| I want to... | Go to... |
|--------------|----------|
| Set up the project | [01-setup/](01-setup/) |
| Understand system design | [02-architecture/](02-architecture/) |
| Implement a feature | [03-features/](03-features/) |
| Deploy to production | [04-deployment/](04-deployment/) |
| Write/run tests | [05-testing/](05-testing/) |
| Fix a bug | [06-fixes/](06-fixes/) |
| Review code quality | [07-reviews/](07-reviews/) |
| Check API reference | [API_ENDPOINTS_COMPLETE.md](API_ENDPOINTS_COMPLETE.md) |

---

**Last Updated:** 2026-01-02
**Reorganization Status:** ✅ Complete
