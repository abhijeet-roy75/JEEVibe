# Quiz Document Size Analysis - 1MB Limit Risk Assessment

**Date**: January 1, 2026
**Status**: ⚠️ **MONITORING RECOMMENDED**
**Priority**: MEDIUM (Safe now, but growth vectors identified)
**Current Risk**: LOW (20-30 KB / 1MB = 2-3%)

---

## Executive Summary

Quiz documents currently use **20-30 KB** per quiz (2-3% of Firestore's 1MB limit), which is **safe**. However, several growth vectors could push documents toward the 1MB limit over time. This document analyzes what could cause size issues and provides mitigation strategies.

---

## Current Quiz Document Structure

### What's Stored in Quiz Documents

**Location**: `daily_quizzes/{userId}/quizzes/{quizId}`

**Structure**:
```javascript
{
  quiz_id: string,
  quiz_number: number,
  status: 'in_progress' | 'completed',
  learning_phase: 'foundation' | 'intermediate' | 'advanced',
  total_time_seconds: number,
  score: number,
  accuracy: number,

  questions: [  // ← THIS IS THE LARGE PART
    {
      // Metadata (small)
      question_id: string,
      subject: string,
      chapter: string,
      question_type: 'mcq_single' | 'numerical',

      // Question content (MEDIUM-LARGE)
      question_text: string,          // Plain text (~200-500 chars)
      question_text_html: string,     // HTML with LaTeX (~1-3 KB)
      question_latex: string,         // LaTeX source (~500-1000 chars)
      image_url: string,              // URL only (small)

      // Options (MEDIUM)
      options: [
        {
          option_id: 'A',
          text: string,      // ~50-200 chars each
          html: string       // ~100-500 chars each with LaTeX
        }
      ],  // 4 options = ~400-2000 chars total

      // IRT parameters (small)
      irt_parameters: {
        discrimination_a: number,
        difficulty_b: number,
        guessing_c: number
      },

      // Response data (REMOVED during quiz, added on completion)
      answered: boolean,
      student_answer: string,
      is_correct: boolean,
      time_taken_seconds: number,

      // ⚠️ LARGE FIELDS (CURRENTLY REMOVED)
      // These are stripped before storing quiz:
      // correct_answer: string,
      // correct_answer_text: string,
      // solution_text: string,          // NOT STORED (~1-5 KB)
      // solution_steps: array,           // NOT STORED (~2-10 KB)
    }
  ]  // 10 questions per quiz
}
```

### Size Breakdown Per Question

| Field Category | Current Size | Growth Potential |
|---------------|-------------|------------------|
| **Metadata** (IDs, subject, chapter) | ~100-200 bytes | ✅ Fixed |
| **Question text (plain)** | ~200-500 chars | ⚠️ Could grow to 1-2 KB |
| **Question text (HTML)** | ~1-3 KB | ⚠️ Could grow to 5-10 KB |
| **Question LaTeX** | ~500-1000 chars | ⚠️ Could grow to 2-3 KB |
| **Options (4 choices)** | ~400-2000 chars | ⚠️ Could grow to 3-5 KB |
| **IRT parameters** | ~50 bytes | ✅ Fixed |
| **Response data** | ~100 bytes | ✅ Fixed |
| **Image URL** | ~100 bytes | ✅ Fixed |
| ~~**Solution text**~~ | ~~1-5 KB~~ | ❌ **NOT STORED** |
| ~~**Solution steps**~~ | ~~2-10 KB~~ | ❌ **NOT STORED** |
| **TOTAL PER QUESTION** | **2-3 KB** | **Could grow to 10-15 KB** |

**Current Quiz Size**: 10 questions × 2-3 KB = **20-30 KB** (2-3% of 1MB limit) ✅ **SAFE**

**Maximum Potential**: 10 questions × 15 KB = **150 KB** (15% of 1MB limit) ⚠️ **Still safe but concerning**

---

## What Could Cause This To Become an Issue?

### 1. ⚠️ More Complex Questions (LIKELY)

**Scenario**: JEE Advanced-style questions with multi-part scenarios

**Examples**:
- **Passage-based questions**: Physics passages with 500-1000 words + diagram descriptions
- **Comprehension questions**: Chemistry reaction mechanisms with multiple steps
- **Data interpretation**: Tables, graphs described in HTML (can be 2-5 KB per question)

**Current**: Simple MCQs with ~200-500 char question text
**Future**: Complex multi-part questions with 1-2 KB question text

**Impact**:
```javascript
// Before (current)
question_text: "A particle moves with velocity v = 2t. Find acceleration at t=3."
question_text_html: "<p>A particle moves with velocity <span>\\(v = 2t\\)</span>...</p>"
// Size: ~200 chars text + ~500 chars HTML = 700 chars

// After (complex JEE Advanced)
question_text: "A cylindrical container of radius R=10cm and height H=20cm is filled with an ideal gas..."
question_text_html: "<p>A cylindrical container...</p><div>Diagram...</div><p>Given data:...</p><ul>...</ul>"
// Size: ~1000 chars text + ~3000 chars HTML = 4000 chars (5.7x growth)
```

**Time to Issue**: 1-2 years if question complexity increases gradually

---

### 2. ⚠️ Richer HTML/LaTeX Formatting (LIKELY)

**Scenario**: Better educational content with more detailed formatting

**Examples**:
- **Chemical equations**: Complex organic chemistry structures in LaTeX
  ```latex
  \\ce{CH3-CH2-CH(OH)-CH3 + H2SO4 ->[\Delta] CH3-CH=CH-CH3 + H2O}
  ```
- **Mathematical derivations**: Multi-step proofs embedded in questions
- **Diagrams in SVG**: Inline SVG diagrams (can be 5-10 KB each)
- **Color-coded explanations**: Syntax highlighting, annotations

**Current**: Basic LaTeX for equations (~500 chars)
**Future**: Rich LaTeX with diagrams, color, complex formatting (2-3 KB)

**Impact**:
```javascript
// Before
question_latex: "\\int_{0}^{\\pi} \\sin(x) dx"
// Size: ~30 chars

// After (JEE Advanced with derivation)
question_latex: "\\begin{align} ... \\end{align} \\text{with diagram} \\begin{tikz} ... \\end{tikz}"
// Size: ~1500 chars (50x growth for complex questions)
```

**Time to Issue**: 6-12 months if content team adds richer formatting

---

### 3. 🔴 Re-Adding Solution Fields (CRITICAL RISK)

**Scenario**: Developer accidentally re-adds `solution_text` and `solution_steps` to quiz documents

**Current Code (CORRECT)**:
```javascript
// backend/src/routes/dailyQuiz.js:125
const { correct_answer, correct_answer_text, solution_text, solution_steps, ...sanitized } = q;
return sanitized;  // ✅ Solution fields stripped
```

**Potential Bug** (if someone "fixes" this thinking it's a bug):
```javascript
// WRONG - if someone removes the destructuring
questions: quizData.questions.map(q => {
  return q;  // ❌ Includes solution_text (~2-5 KB) and solution_steps (~3-10 KB)
});
```

**Impact**:
- **Solution text**: 1-5 KB per question (detailed explanations)
- **Solution steps**: 2-10 KB per question (array of step-by-step explanations)
- **Total**: +3-15 KB per question = +30-150 KB per quiz

**Result**:
- **Before**: 20-30 KB per quiz
- **After bug**: 50-180 KB per quiz (still safe but 6x growth)
- **With complex questions**: Could reach 300-400 KB (30-40% of limit) ⚠️

**Time to Issue**: IMMEDIATE if code is changed

**Mitigation**: Add unit tests to verify solution fields are stripped

---

### 4. ⚠️ More Questions Per Quiz (POSSIBLE)

**Scenario**: Increase quiz length for better assessment

**Current**: 10 questions per quiz
**Future**: 15-20 questions (for practice mode or full-length tests)

**Impact**:
- **15 questions**: 30-45 KB (still safe)
- **20 questions**: 40-60 KB (still safe)
- **20 questions + complex content**: 200-300 KB (20-30% of limit) ⚠️

**Time to Issue**: Depends on product decisions (could be 3-6 months)

---

### 5. 🟡 Image Metadata Bloat (UNLIKELY)

**Scenario**: Storing base64-encoded images instead of URLs

**Current**: `image_url: "https://storage.googleapis.com/..."` (~100 bytes)
**Wrong**: `image_data: "data:image/png;base64,iVBORw0KGgo..."` (can be 50-200 KB!)

**Impact**:
- Single base64 image: 50-200 KB
- 10 questions with images: 500 KB - 2 MB ❌ **EXCEEDS LIMIT**

**Time to Issue**: IMMEDIATE if someone changes image handling

**Mitigation**: Code review + storage validation

---

### 6. 🟡 Unnecessary Field Addition (UNLIKELY)

**Scenario**: Adding redundant data to quiz documents

**Examples**:
- Full user profile embedded in quiz
- Complete question bank metadata
- Large analytics arrays

**Impact**: Depends on what's added (could be 10-100 KB)

**Time to Issue**: Only if someone adds fields without review

---

## Size Growth Projection

### Conservative Scenario (Likely in 1-2 years)
| Factor | Growth | New Size |
|--------|--------|----------|
| Baseline | 1x | 30 KB |
| Complex questions (+50% text) | 1.5x | 45 KB |
| Richer HTML/LaTeX (+100%) | 2x | 60 KB |
| **TOTAL** | **3x** | **90 KB** |

**Result**: Still safe (9% of limit) ✅

---

### Aggressive Scenario (If multiple factors combine)
| Factor | Growth | New Size |
|--------|--------|----------|
| Baseline | 1x | 30 KB |
| Complex questions (+200% text) | 3x | 90 KB |
| Richer HTML/LaTeX (+300%) | 4x | 120 KB |
| More questions (15 instead of 10) | 1.5x | 180 KB |
| Accidentally include solutions | 3x | 540 KB |
| **TOTAL** | **18x** | **540 KB** |

**Result**: Approaching limit (54% of 1MB) ⚠️ **NEEDS ATTENTION**

---

### Worst-Case Scenario (Coding error + aggressive growth)
| Factor | Growth | New Size |
|--------|--------|----------|
| Baseline | 1x | 30 KB |
| Solution fields re-added | 5x | 150 KB |
| Complex questions | 2x | 300 KB |
| 20 questions instead of 10 | 2x | 600 KB |
| Base64 images by mistake | 10x | **6 MB** |

**Result**: ❌ **EXCEEDS 1MB LIMIT** - Firestore writes would **FAIL**

---

## When Would This Become Critical?

### Timeline to Potential Issues

| Risk Factor | Time to Issue | Probability | Impact |
|------------|--------------|-------------|--------|
| **Complex questions** | 1-2 years | 70% | Medium (3x growth) |
| **Richer HTML/LaTeX** | 6-12 months | 60% | Medium (2x growth) |
| **Solution fields bug** | Any time | 20% | **HIGH** (5x growth) |
| **More questions** | 3-6 months | 40% | Low (1.5x growth) |
| **Base64 images** | Any time | 5% | **CRITICAL** (10x+ growth) |

### Critical Thresholds

| Threshold | Size | Action |
|-----------|------|--------|
| **Yellow** | 100 KB (10%) | Monitor size in logs |
| **Orange** | 500 KB (50%) | Investigate optimization |
| **Red** | 800 KB (80%) | **IMMEDIATE ACTION** - refactor required |
| **Firestore Hard Limit** | 1 MB (100%) | ❌ **WRITES FAIL** |

**Current**: 30 KB = **3%** of limit ✅ **SAFE**

---

## Mitigation Strategies

### Quick Win #1: Add Document Size Monitoring (15 minutes)

**File**: `backend/src/routes/dailyQuiz.js`

**Add logging after quiz creation**:
```javascript
// After creating quiz document
const quizSize = Buffer.byteLength(JSON.stringify(quizData));
const sizeMB = (quizSize / (1024 * 1024)).toFixed(3);

logger.info('Quiz document created', {
  userId,
  quizId: quizData.quiz_id,
  size_bytes: quizSize,
  size_mb: sizeMB,
  size_percent_of_limit: ((quizSize / (1024 * 1024)) * 100).toFixed(1)
});

// Alert if approaching limits
if (quizSize > 500000) {  // 500 KB = 50% of limit
  logger.warn('Quiz document size approaching 1MB limit', {
    userId,
    quizId: quizData.quiz_id,
    size_bytes: quizSize,
    size_mb: sizeMB
  });
}
```

**Benefits**:
- Real-time monitoring of document sizes
- Early warning if sizes grow unexpectedly
- Data for optimization decisions

---

### Quick Win #2: Add Unit Tests for Solution Stripping (15 minutes)

**File**: `backend/tests/unit/routes/dailyQuiz.test.js` (NEW)

**Test to prevent solution field regression**:
```javascript
describe('Quiz Generation - Document Size Safety', () => {
  test('should NOT include solution fields in quiz document', () => {
    const mockQuestion = {
      question_id: 'q1',
      question_text: 'Test question',
      correct_answer: 'A',
      solution_text: 'This is the solution', // Should be stripped
      solution_steps: ['Step 1', 'Step 2'],  // Should be stripped
    };

    const sanitized = sanitizeQuestionForQuiz(mockQuestion);

    expect(sanitized.solution_text).toBeUndefined();
    expect(sanitized.solution_steps).toBeUndefined();
    expect(sanitized.correct_answer).toBeUndefined();
  });

  test('should keep quiz document under 100KB for 10 standard questions', () => {
    const quiz = generateMockQuiz(10);
    const quizSize = Buffer.byteLength(JSON.stringify(quiz));

    expect(quizSize).toBeLessThan(100 * 1024); // 100 KB
  });
});
```

---

### Medium-Term Solution: Implement Question Subcollection (2-3 hours)

**Current Structure** (all in one document):
```
daily_quizzes/{userId}/quizzes/{quizId}
  - questions: [array of 10 question objects]  // 20-30 KB
```

**Refactored Structure** (split into subcollection):
```
daily_quizzes/{userId}/quizzes/{quizId}
  - quiz metadata only  // 1-2 KB
  └── questions/{position}  // subcollection
      - question data  // 2-3 KB each
```

**Benefits**:
- No document size limits (each question is separate document)
- Faster metadata queries (don't load all questions)
- Update single question without rewriting entire quiz
- Parallel question loading possible

**Drawbacks**:
- More Firestore reads (1 + 10 = 11 reads vs 1 read)
- More complex query logic
- Migration required for existing quizzes

**When to Implement**: If quiz sizes consistently exceed **200 KB** (20% of limit)

---

### Long-Term Solution: CDN for Rich Content (1-2 days)

**Scenario**: Store rich HTML/LaTeX content in Cloud Storage, reference by URL

**Current**:
```javascript
question_text_html: "<div>...</div><p>...</p>"  // 3 KB in Firestore
```

**Optimized**:
```javascript
question_text_html_url: "https://cdn.jeevibe.com/questions/q123.html"  // 100 bytes
// HTML served from CDN (cached, fast)
```

**Benefits**:
- Massive size reduction (3 KB → 100 bytes = 97% reduction)
- Faster page loads (CDN caching)
- No Firestore document size concerns

**Drawbacks**:
- Additional infrastructure (Cloud Storage, CDN)
- More complex deployment (upload HTML to storage)
- Network latency for HTML fetch

**When to Implement**: If quiz sizes consistently exceed **500 KB** (50% of limit)

---

## Recommended Actions

### Immediate (Next Sprint)
1. ✅ **Add document size monitoring** (15 minutes)
   - Log quiz document sizes on creation
   - Alert if >500 KB (50% of limit)

2. ✅ **Add unit tests for solution stripping** (15 minutes)
   - Prevent accidental regression
   - Test document size limits

### Short-Term (1-3 months)
3. ⏳ **Monitor size trends** (ongoing)
   - Review logs weekly
   - Track average quiz size
   - Identify growth patterns

4. ⏳ **Establish size budget** (1 hour)
   - Document: "Quiz documents must stay under 200 KB"
   - Code review checklist: Check document sizes

### Medium-Term (3-6 months)
5. ⏳ **Implement subcollection if needed** (2-3 hours)
   - Only if sizes consistently exceed 200 KB
   - Migrate existing quizzes gradually

### Long-Term (6-12 months)
6. ⏳ **CDN for rich content if needed** (1-2 days)
   - Only if sizes consistently exceed 500 KB
   - Requires infrastructure planning

---

## Summary

### Current Status
- **Current Size**: 20-30 KB per quiz (2-3% of limit)
- **Risk Level**: ✅ **LOW** (safe for now)
- **Growth Vectors**: 5 identified (complex questions, rich formatting, coding errors, more questions, image bloat)

### What Could Cause Issues?
| Factor | Time | Probability | Impact |
|--------|------|-------------|--------|
| Complex questions | 1-2 years | 70% | 3x growth |
| Rich HTML/LaTeX | 6-12 months | 60% | 2x growth |
| **Solution fields bug** | Any time | 20% | **5x growth** |
| More questions | 3-6 months | 40% | 1.5x growth |
| **Base64 images** | Any time | 5% | **10x+ growth** |

### Critical Scenarios
- **Conservative growth**: 90 KB in 1-2 years (still safe ✅)
- **Aggressive growth**: 540 KB if multiple factors combine (needs attention ⚠️)
- **Worst-case bug**: 6 MB if coding errors occur (exceeds limit ❌)

### Recommended Actions
1. ✅ **NOW**: Add monitoring + tests (30 minutes)
2. ⏳ **1-3 months**: Monitor trends, establish size budget
3. ⏳ **3-6 months**: Implement subcollection if >200 KB
4. ⏳ **6-12 months**: CDN solution if >500 KB

**Next Step**: Implement document size monitoring to track actual growth patterns.

---

**Date**: January 1, 2026
**Status**: Analysis complete, monitoring recommended
**Risk Level**: LOW (safe for 6-12 months with current trajectory)
