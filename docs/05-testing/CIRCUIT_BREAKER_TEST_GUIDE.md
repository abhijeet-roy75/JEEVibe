# Circuit Breaker Test Guide

## Overview

The **Circuit Breaker** is a safety mechanism that prevents student "death spirals" - situations where students get multiple questions wrong in a row, causing their theta to drop dramatically and potentially leading to demotivation and churn.

## How It Works

### Trigger Conditions

1. **Primary Trigger:** 5+ consecutive incorrect answers in recent session
2. **Secondary Trigger (Real-time):** 3+ consecutive incorrect in current quiz

### Response

When triggered, the system should:
- Override normal quiz generation
- Generate a "recovery quiz" with easier questions
- Help rebuild student confidence

### Recovery Quiz Structure

When circuit breaker triggers, generate special quiz with:
- **7 questions: EASY** (difficulty b = 0.4 to 0.7)
  - Expected success rate: 75-85%
  - From weakest topics to prevent gap widening
- **2 questions: MEDIUM** (difficulty b = 0.8 to 1.1)
  - Expected success rate: 60-70%
  - Gentle challenge to rebuild confidence
- **1 question: REVIEW** (previously correct 7-14 days ago)
  - Expected success rate: ~90%
  - Psychological boost ("I know this!")

**Total:** 10 questions  
**Expected overall success:** ~75-80%

## Testing the Circuit Breaker

### Test Script

Location: `backend/scripts/test-circuit-breaker.js`

### Running the Test

```bash
cd backend
TOKEN="your-firebase-token" npm run test:circuit-breaker
```

### What the Test Does

1. **Scenario 1: Check Current Status**
   - Checks if circuit breaker is currently triggered for the user
   - Shows recent response history
   - Displays consecutive failure count

2. **Scenario 2: Simulate Trigger**
   - Creates 5 consecutive wrong answers
   - Verifies circuit breaker triggers correctly
   - Shows recovery quiz structure

3. **Scenario 3: Below Threshold Test**
   - Creates only 3 consecutive wrong answers
   - Verifies circuit breaker does NOT trigger
   - Confirms threshold logic works

### Test Results Interpretation

**✅ Circuit Breaker Working Correctly:**
- 5+ consecutive failures → 🔴 TRIGGERED
- < 5 consecutive failures → 🟢 Not Triggered

**Example Output:**
```
🔍 Circuit Breaker Check Result:
   Status: 🔴 TRIGGERED
   Consecutive Failures: 5
   Reason: Circuit breaker triggered: 5 consecutive failures
```

## Current Implementation Status

**Status:** ⚠️ **NOT YET IMPLEMENTED**

The circuit breaker logic is:
- ✅ **Designed** - Algorithm specification complete
- ✅ **Tested** - Test script validates logic
- ❌ **Not Integrated** - Not yet part of quiz generation

### What's Needed

1. **Implement `checkCircuitBreaker()` function** in quiz generation service
2. **Implement `generateRecoveryQuiz()` function** for confidence-building quizzes
3. **Integrate into daily quiz flow** - Check before normal quiz generation
4. **Add analytics tracking** - Monitor activation rate and recovery success
5. **Add cooldown mechanism** - Prevent repeated triggers

## Research Background

**Data from Duolingo (2017):**
- Students with 6+ consecutive failures: **72% churn rate**
- Students with max 3 consecutive failures: **12% churn rate**

**Target Metrics:**
- Circuit breaker activation rate: <5% of students
- Student retention after circuit breaker: >80%

## Next Steps

1. **Implement circuit breaker check** in quiz generation service
2. **Create recovery quiz generator** with easy questions
3. **Add to daily quiz API** - Check before generating normal quiz
4. **Add analytics** - Track when and why circuit breaker triggers
5. **Test with real students** - Monitor effectiveness

## Files

- **Test Script:** `backend/scripts/test-circuit-breaker.js`
- **Algorithm Spec:** `docs/engine/JEEVibe_IIDP_Algorithm_Specification_v4_CALIBRATED.md` (Section 8)
- **Reference Implementation:** `docs/engine/iidp_implementation_v4_CALIBRATED.py` (Lines 628-900)
