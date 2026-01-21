# Previous Year Questions (PYQ) Feature - Implementation Plan

## Overview

Implement a PYQ practice feature allowing students to practice actual JEE Main and JEE Advanced questions from previous years. This feature shares significant architecture with Mock Tests (see `MOCK-TESTS-FEATURE-PLAN.md`) but has unique requirements around question sourcing and authenticity.

## Prerequisites & Sequencing

**Dependency**: Mock Tests feature should be implemented first.

**Rationale**:
- PYQ reuses 80%+ of Mock Test infrastructure (see Section 14 of Mock Tests plan)
- `BaseTestService`, `base_test_session.dart`, common UI components built for Mock Tests
- PYQ is primarily a data sourcing challenge, not an architecture challenge

**Implementation Order**:
1. ✅ Complete question bank reload
2. ✅ Implement Mock Tests (builds shared infrastructure)
3. Source and curate PYQ data (this document)
4. Implement PYQ-specific features (year selection, paper selection)
5. Launch PYQ feature

---

## Key Question: How Do We Get PYQs?

### Option 1: Manual Curation from Official NTA Papers (Recommended Start)

**Source**: NTA releases official JEE Main papers after each session on [nta.ac.in](https://nta.ac.in) and [jeemain.nta.nic.in](https://jeemain.nta.nic.in).

**Process**:
```
NTA Official PDF → Manual Entry by Content Team → Validation → Firestore
```

**Pros**:
- 100% authentic and accurate
- No legal/copyright concerns (official public releases)
- Quality guaranteed (actual JEE questions)
- Includes official answer keys

**Cons**:
- Labor-intensive (90 questions × multiple sessions × multiple years)
- Time to populate initial dataset
- Requires content team with JEE expertise

**Estimated Effort**:
| Year Range | Sessions | Questions | Entry Time (est.) |
|------------|----------|-----------|-------------------|
| 2024 | 4 sessions × 2 shifts | ~720 questions | 2 weeks |
| 2023 | 4 sessions × 2 shifts | ~720 questions | 2 weeks |
| 2022 | 4 sessions × 2 shifts | ~720 questions | 2 weeks |
| 2021 | 4 sessions × 2 shifts | ~720 questions | 2 weeks |
| 2020 | 2 sessions | ~360 questions | 1 week |
| **Total** | | **~3,240 questions** | **9 weeks** |

**Recommendation**: Start with 2024 and 2023 (most relevant), expand backward.

---

### Option 2: Third-Party Data Providers / Purchase Options

#### Category A: Ed-Tech Platforms (May License Data)

| Company | Contact | What They Have | Estimated Cost | Notes |
|---------|---------|----------------|----------------|-------|
| **Embibe** | partnerships@embibe.com | Full PYQ bank with solutions, IRT-calibrated | $$$$ (likely $10K+) | Acquired by Adani, very comprehensive |
| **Toppr** (now BYJU'S) | enterprise@byjus.com | PYQ with video solutions | $$$ | May not license to competitors |
| **Vedantu** | business@vedantu.com | PYQ with teacher explanations | $$$ | Open to partnerships |
| **Unacademy** | partnerships@unacademy.com | Extensive PYQ from coaching partners | $$$$ | Largest content library |
| **PhysicsWallah** | business@pw.live | Growing PYQ collection | $$ | More flexible, newer player |

**Approach**: Email partnerships team, explain B2B licensing interest for PYQ dataset.

#### Category B: Coaching Institutes (Direct Licensing)

| Institute | What They Have | Approach |
|-----------|----------------|----------|
| **Allen** | 20+ years of curated PYQs, detailed solutions | Contact Kota HQ, ask for content licensing |
| **FIITJEE** | Comprehensive question bank, IIT-focused | Approach via their digital wing |
| **Resonance** | Strong Advanced coverage | Digital partnerships team |
| **Aakash** (BYJU'S) | Medical + JEE combined | Enterprise licensing |
| **VMC (Vidyamandir)** | Delhi-based, strong Math coverage | Direct approach |

**Note**: Coaching institutes may be reluctant to license to a potential competitor. Position as "complementary tool for their students" if possible.

#### Category C: Content Aggregators / Marketplaces

| Provider | URL | What They Offer | Cost |
|----------|-----|-----------------|------|
| **Testbook** | testbook.com | PYQ datasets (primarily govt exams, some JEE) | API access ~$500-2000/year |
| **Gradeup** (BYJU'S Exam Prep) | byjusexamprep.com | Question banks | Licensing TBD |
| **Careers360** | careers360.com | PYQ PDFs, some structured data | May partner |
| **Shiksha** | shiksha.com | Aggregated exam content | Content partnerships |

#### Category D: Open/Semi-Open Sources

| Source | URL | What's Available | Format |
|--------|-----|------------------|--------|
| **NTA Official** | jeemain.nta.nic.in | Papers + Answer Keys (2019+) | PDF (free) |
| **JEE Advanced Official** | jeeadv.ac.in | Papers + Solutions (2013+) | PDF (free) |
| **Wikimedia Commons** | commons.wikimedia.org | Some older papers | Various |
| **Internet Archive** | archive.org | Historical AIEEE/IIT-JEE | PDF |
| **GitHub Projects** | github.com/search?q=jee+questions | Community datasets (quality varies) | JSON/CSV |

#### Category E: Freelance/Agency Content Creation

| Option | Platform | Cost Estimate | Quality |
|--------|----------|---------------|---------|
| **Hire JEE tutors** | Upwork, Fiverr | ₹500-1000/question with solution | High (if vetted) |
| **Content agencies** | Evelyn Learning, iNurture | ₹50-100/question (bulk) | Medium |
| **College students** | IIT/NIT campus hiring | ₹200-500/question | Variable |

**Recommended Freelance Approach**:
1. Post on LinkedIn: "Hiring JEE content creators for PYQ solutions"
2. Target: IIT students, coaching institute teachers (part-time)
3. Rate: ₹300/question with detailed solution
4. Validation: Cross-check 20% of submissions

---

#### Purchase Decision Matrix

| Factor | AI Extraction | Content Agency | Ed-Tech License | Coaching License |
|--------|---------------|----------------|-----------------|------------------|
| **Cost** | $50-100 | ₹50K-1L | $5K-20K | $2K-10K |
| **Time to Launch** | 2 weeks | 4-6 weeks | 2-4 weeks (negotiation) | 4-8 weeks |
| **Quality** | 90-95% (needs review) | 85-95% | 95%+ | 98%+ |
| **Solutions Included** | No (generate separately) | Yes | Yes | Yes |
| **Maintenance** | Self-managed | Agency retainer | License renewal | One-time |
| **JEE Advanced** | Harder (complex formats) | Yes | Yes | Yes |
| **Legal Risk** | None (public PDFs) | Low | None | None |

**Recommendation**:

1. **Immediate (MVP)**: AI extraction from official NTA PDFs (free, fast)
2. **Solutions**: AI-generate with Claude, human review top 20%
3. **JEE Advanced**: Approach 1-2 coaching institutes for licensing
4. **Long-term**: Build in-house content team or agency partnership

---

### Option 3: AI-Assisted Extraction from PDFs (Recommended for Scale)

**Process**:
```
Official NTA PDF → PDF to Images → Claude Vision API → Structured JSON → Validation → Firestore
```

#### Where to Get Official PDFs

| Source | URL | Papers Available |
|--------|-----|------------------|
| **NTA Official** | [jeemain.nta.nic.in](https://jeemain.nta.nic.in) | JEE Main 2019-2024 |
| **NTA Archive** | [nta.ac.in/Download](https://nta.ac.in/Download) | All NTA exams |
| **JEE Advanced Official** | [jeeadv.ac.in](https://jeeadv.ac.in) | JEE Advanced 2013-2024 |
| **NCERT/CBSE Archive** | Various | Older AIEEE papers (pre-2013) |

**Note**: NTA releases question papers + answer keys after each session. These are public domain.

#### Detailed Extraction Pipeline

```javascript
// backend/scripts/extractPYQFromPDF.js

const { callClaude } = require('../src/services/claude');
const pdf = require('pdf-poppler'); // or pdf-lib + sharp
const fs = require('fs');

/**
 * Full extraction pipeline for a JEE paper PDF
 */
async function extractPaperFromPDF(pdfPath, metadata) {
  const { year, examType, session, shift } = metadata;

  console.log(`Extracting: ${examType} ${year} ${session} ${shift}`);

  // Step 1: Convert PDF pages to high-resolution images
  const outputDir = `/tmp/pyq_extraction/${year}_${session}_${shift}`;
  await pdf.convert(pdfPath, {
    format: 'png',
    out_dir: outputDir,
    out_prefix: 'page',
    scale: 2048  // High resolution for better OCR
  });

  const pageFiles = fs.readdirSync(outputDir).filter(f => f.endsWith('.png'));
  const questions = [];

  // Step 2: Extract questions from each page
  for (const pageFile of pageFiles) {
    const pageNum = parseInt(pageFile.match(/page-(\d+)/)[1]);
    const imagePath = `${outputDir}/${pageFile}`;
    const imageBase64 = fs.readFileSync(imagePath).toString('base64');

    const extractedQuestions = await extractQuestionsFromPage(imageBase64, pageNum, metadata);
    questions.push(...extractedQuestions);
  }

  // Step 3: Merge with answer key
  const answersPath = pdfPath.replace('.pdf', '_answer_key.pdf');
  if (fs.existsSync(answersPath)) {
    await mergeAnswerKey(questions, answersPath);
  }

  // Step 4: Validate and store
  const validated = await validateExtractedQuestions(questions);

  console.log(`Extracted: ${questions.length} questions, ${validated.length} valid`);
  return validated;
}

/**
 * Extract questions from a single page image
 */
async function extractQuestionsFromPage(imageBase64, pageNum, metadata) {
  const response = await callClaude({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 4000,
    messages: [{
      role: 'user',
      content: [
        {
          type: 'image',
          source: { type: 'base64', media_type: 'image/png', data: imageBase64 }
        },
        {
          type: 'text',
          text: buildExtractionPrompt(metadata)
        }
      ]
    }]
  });

  return parseExtractionResponse(response.content[0].text, pageNum, metadata);
}

/**
 * Detailed extraction prompt for Claude Vision
 */
function buildExtractionPrompt(metadata) {
  return `You are extracting JEE ${metadata.examType === 'jee_main' ? 'Main' : 'Advanced'} ${metadata.year} questions from this exam paper page.

Extract ALL questions visible on this page. For each question, return a JSON object.

CRITICAL RULES:
1. Preserve ALL mathematical notation as LaTeX (e.g., \\frac{1}{2}, \\sqrt{x}, \\alpha)
2. For diagrams/figures, describe them in [DIAGRAM: description] format
3. Include the exact question number as shown in the paper
4. Identify the subject from context (Physics/Chemistry/Mathematics)
5. Identify question type: "mcq_single", "mcq_multi" (multiple correct), "numerical", "integer", "matrix_match"
6. For MCQs, extract ALL 4 options exactly as written
7. Do NOT include the answer (we'll merge from answer key separately)

Return JSON array:
[
  {
    "question_number": 1,
    "subject": "Physics",
    "section": "A",
    "question_type": "mcq_single",
    "question_text": "A particle moves in a straight line with velocity given by \\( v = 3t^2 - 6t \\) m/s...",
    "has_diagram": false,
    "diagram_description": null,
    "options": [
      {"id": "A", "text": "10 m"},
      {"id": "B", "text": "20 m"},
      {"id": "C", "text": "30 m"},
      {"id": "D", "text": "40 m"}
    ]
  },
  {
    "question_number": 2,
    "subject": "Physics",
    "section": "B",
    "question_type": "numerical",
    "question_text": "A block of mass 5 kg slides down...",
    "has_diagram": true,
    "diagram_description": "Inclined plane at 30 degrees with block at top, friction coefficient μ marked",
    "options": null,
    "answer_unit": "m/s"
  }
]

If no questions are visible (e.g., instructions page), return empty array: []`;
}

/**
 * Extract answers from answer key PDF
 */
async function mergeAnswerKey(questions, answerKeyPath) {
  // Similar extraction but focused on answer key format
  // NTA answer keys are typically tables with Q.No and Answer columns

  const answerKeyImages = await convertPdfToImages(answerKeyPath);

  for (const imageBase64 of answerKeyImages) {
    const response = await callClaude({
      model: 'claude-sonnet-4-20250514',
      messages: [{
        role: 'user',
        content: [
          { type: 'image', source: { type: 'base64', media_type: 'image/png', data: imageBase64 } },
          { type: 'text', text: `Extract the answer key from this image. Return JSON:
{
  "answers": [
    {"question_number": 1, "correct_answer": "B"},
    {"question_number": 2, "correct_answer": 42.5},
    ...
  ]
}
For MCQs, answer is A/B/C/D. For numerical, answer is the number.
For "Dropped" or "Bonus" questions, use: {"question_number": X, "status": "dropped"}` }
        ]
      }]
    });

    const answerData = JSON.parse(response.content[0].text);

    // Merge answers into questions
    for (const answer of answerData.answers) {
      const question = questions.find(q => q.question_number === answer.question_number);
      if (question) {
        if (answer.status === 'dropped') {
          question.status = 'dropped';
        } else {
          question.correct_answer = answer.correct_answer;
        }
      }
    }
  }
}

/**
 * Validate extracted questions
 */
async function validateExtractedQuestions(questions) {
  const validated = [];

  for (const q of questions) {
    // Schema validation
    if (!q.question_text || !q.subject || !q.question_type) {
      console.warn(`Skipping Q${q.question_number}: Missing required fields`);
      continue;
    }

    // MCQ must have 4 options
    if (q.question_type.startsWith('mcq') && (!q.options || q.options.length !== 4)) {
      console.warn(`Skipping Q${q.question_number}: Invalid options`);
      continue;
    }

    // Answer verification (if answer key merged)
    if (q.correct_answer) {
      const verification = await verifyAnswer(q);
      if (!verification.valid) {
        q.validation_status = 'needs_review';
        q.validation_notes = verification.reason;
      }
    }

    validated.push(q);
  }

  return validated;
}

module.exports = { extractPaperFromPDF };
```

#### Handling Diagrams

JEE papers often have diagrams. Strategy:

```javascript
// For questions with diagrams:
// 1. Extract diagram region as separate image
// 2. Store in Cloud Storage
// 3. Reference in question

async function handleDiagram(imageBase64, questionNumber, metadata) {
  // Use Claude to identify diagram boundaries
  const response = await callClaude({
    model: 'claude-sonnet-4-20250514',
    messages: [{
      role: 'user',
      content: [
        { type: 'image', source: { type: 'base64', media_type: 'image/png', data: imageBase64 } },
        { type: 'text', text: `Identify the diagram for question ${questionNumber}. Return bounding box coordinates: {"x": 0, "y": 0, "width": 100, "height": 100} as percentage of image dimensions.` }
      ]
    }]
  });

  const bbox = JSON.parse(response.content[0].text);

  // Crop diagram region
  const croppedImage = await cropImage(imageBase64, bbox);

  // Upload to Cloud Storage
  const diagramUrl = await uploadToStorage(
    croppedImage,
    `pyq_diagrams/${metadata.year}/${metadata.session}/q${questionNumber}.png`
  );

  return diagramUrl;
}
```

#### Cost Estimate for AI Extraction

| Item | Per Paper | 20 Papers (2020-2024 Main) |
|------|-----------|---------------------------|
| PDF to Image conversion | $0 (local) | $0 |
| Claude Vision (90 questions × ~10 pages) | $0.50-1.00 | $10-20 |
| Answer key extraction | $0.10-0.20 | $2-4 |
| Answer verification (Claude Haiku) | $0.10 | $2 |
| **Total** | **~$0.80-1.50** | **~$15-30** |

**For comprehensive extraction (Main + Advanced, 2015-2024)**:
- ~50 papers × $1.00 = ~$50-75 total API cost
- Plus human validation time

#### Extraction Script Usage

```bash
# Extract a single paper
node scripts/extractPYQFromPDF.js \
  --pdf ./papers/JEE_Main_2024_Jan_S1_Shift1.pdf \
  --answer-key ./papers/JEE_Main_2024_Jan_S1_Shift1_AnswerKey.pdf \
  --year 2024 \
  --exam-type jee_main \
  --session january \
  --shift shift1

# Batch extract all papers in a directory
node scripts/extractPYQFromPDF.js --batch ./papers/jee_main_2024/

# Dry run (extract but don't save to Firestore)
node scripts/extractPYQFromPDF.js --pdf ... --dry-run
```

**Pros**:
- Very fast: ~5-10 minutes per paper (vs hours for manual)
- Scalable to 50+ papers
- Handles LaTeX/math notation well
- Cost-effective: ~$1 per paper

**Cons**:
- Requires validation (AI may misread ~5-10%)
- Complex diagrams need manual review
- Answer key format varies by year
- JEE Advanced papers are more complex (matrix match, multi-correct)

**Recommendation**: Use AI extraction for bulk import, then human validation pass.

---

---

## MVP Plan: AI Extraction Pipeline

**Decision**: AI extraction from official NTA PDFs as primary approach. Enhance later with partnerships if needed.

### MVP Scope

| Item | Included | Count |
|------|----------|-------|
| JEE Main 2024 | ✅ | 4 sessions × 2 shifts = ~720 Qs |
| JEE Main 2023 | ✅ | 4 sessions × 2 shifts = ~720 Qs |
| JEE Main 2022 | ✅ | 4 sessions × 2 shifts = ~720 Qs |
| JEE Advanced 2024 | ❌ (Phase 2) | Complex formats |
| JEE Advanced 2023 | ❌ (Phase 2) | Complex formats |
| **Total MVP** | | **~2,160 questions** |

**Estimated Cost**: ~$25-40 (API) + validation time
**Timeline**: 2-3 weeks

---

### Quality Check Options After Extraction

#### Option 1: Automated Validation Pipeline (Recommended for Scale)

```
Extracted JSON → Schema Check → LaTeX Validation → AI Quality Check → AI Answer Verification → Store
```

**Stage 1: Schema Validation** (Automated, instant)
```javascript
function validateSchema(question) {
  const errors = [];

  // Required fields
  if (!question.question_text) errors.push('Missing question_text');
  if (!question.subject) errors.push('Missing subject');
  if (!['Physics', 'Chemistry', 'Mathematics'].includes(question.subject)) {
    errors.push('Invalid subject');
  }
  if (!question.question_type) errors.push('Missing question_type');

  // MCQ validation
  if (question.question_type.startsWith('mcq')) {
    if (!question.options || question.options.length !== 4) {
      errors.push('MCQ must have exactly 4 options');
    }
    if (question.correct_answer && !['A', 'B', 'C', 'D'].includes(question.correct_answer)) {
      errors.push('Invalid MCQ answer');
    }
  }

  // Numerical validation
  if (question.question_type === 'numerical') {
    if (question.correct_answer !== null && typeof question.correct_answer !== 'number') {
      errors.push('Numerical answer must be a number');
    }
  }

  return { valid: errors.length === 0, errors };
}
```

**Stage 2: LaTeX Validation** (Automated, instant)
```javascript
// Reuse existing latex-validator.js
const { validateAndNormalizeLaTeX } = require('./latex-validator');

function validateLatex(question) {
  const fields = [
    question.question_text,
    ...question.options?.map(o => o.text) || []
  ];

  for (const field of fields) {
    const result = validateAndNormalizeLaTeX(field);
    if (!result.valid) {
      return { valid: false, field, error: result.error };
    }
  }
  return { valid: true };
}
```

**Stage 3: AI Quality Check** (Claude Haiku - fast/cheap)
```javascript
async function aiQualityCheck(question) {
  const response = await callClaude({
    model: 'claude-haiku',
    max_tokens: 500,
    messages: [{
      role: 'user',
      content: `Review this JEE ${question.subject} question for quality issues.

Question: ${question.question_text}
${question.options ? `Options:\nA) ${question.options[0].text}\nB) ${question.options[1].text}\nC) ${question.options[2].text}\nD) ${question.options[3].text}` : ''}
Type: ${question.question_type}

Check for:
1. Is the question text complete and readable?
2. Are there any obvious OCR/extraction errors?
3. Is the mathematical notation valid?
4. For MCQ: Are all 4 options distinct and plausible?
5. Does this look like a real JEE question?

Return JSON:
{
  "valid": true/false,
  "confidence": 0.0-1.0,
  "issues": ["issue1", "issue2"],
  "suggested_fixes": {"field": "corrected_value"}
}`
    }]
  });

  return JSON.parse(response.content[0].text);
}
```

**Stage 4: AI Answer Verification** (Claude Haiku)
```javascript
async function verifyAnswer(question) {
  const response = await callClaude({
    model: 'claude-haiku',
    max_tokens: 1000,
    messages: [{
      role: 'user',
      content: `Solve this JEE ${question.subject} question step-by-step.

Question: ${question.question_text}
${question.options ? `Options:\nA) ${question.options[0].text}\nB) ${question.options[1].text}\nC) ${question.options[2].text}\nD) ${question.options[3].text}` : ''}

Solve completely and give your final answer. Return JSON:
{
  "solution_steps": ["step1", "step2", ...],
  "final_answer": "B" or 42.5,
  "confidence": 0.0-1.0
}`
    }]
  });

  const result = JSON.parse(response.content[0].text);

  // Compare with provided answer
  const providedAnswer = question.correct_answer;
  const aiAnswer = result.final_answer;

  let match = false;
  if (question.question_type === 'numerical') {
    // Allow 1% tolerance for numerical
    match = Math.abs(aiAnswer - providedAnswer) / Math.abs(providedAnswer) < 0.01;
  } else {
    match = aiAnswer === providedAnswer;
  }

  return {
    match,
    ai_answer: aiAnswer,
    provided_answer: providedAnswer,
    confidence: result.confidence,
    solution: result.solution_steps
  };
}
```

**Cost Estimate for Automated Validation**:
| Stage | Cost per Question | 2,160 Questions |
|-------|-------------------|-----------------|
| Schema | $0 | $0 |
| LaTeX | $0 | $0 |
| AI Quality (Haiku) | ~$0.001 | ~$2-3 |
| AI Answer Verify (Haiku) | ~$0.002 | ~$4-5 |
| **Total** | ~$0.003 | **~$6-8** |

---

#### Option 2: Human Review Dashboard (For Flagged Questions)

Build a simple admin UI for reviewing questions that fail automated checks.

```
┌─────────────────────────────────────────────────────────────────┐
│  PYQ Validation Dashboard                    [2024 Jan Shift 1] │
├─────────────────────────────────────────────────────────────────┤
│  Progress: 87/90 validated  │  ⚠️ 3 need review  │  ✗ 0 rejected │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ⚠️ Question 23 (Physics) - NEEDS REVIEW                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Issue: AI answer (C) ≠ Answer key (B)                   │    │
│  │ AI Confidence: 0.72                                      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Original Extraction:                                            │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ A particle of mass m is projected with velocity v...    │    │
│  │ A) √(2gh)  B) √(gh)  C) √(3gh)  D) √(gh/2)             │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  AI Solution:                                                    │
│  "Using conservation of energy: mgh = ½mv²..."                  │
│                                                                  │
│  Actions:                                                        │
│  [✓ Approve as-is] [✎ Edit Question] [🔄 Re-extract] [✗ Reject] │
│                                                                  │
│  Correct Answer: [A] [B] [C] [D] [___ Numerical]                │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  [← Previous]           Question 23 of 90           [Next →]    │
└─────────────────────────────────────────────────────────────────┘
```

**Human Review Triggers**:
| Trigger | Expected % | Action |
|---------|------------|--------|
| AI answer ≠ provided answer | ~5-10% | Manual verification |
| AI confidence < 0.7 | ~5-8% | Review extraction |
| LaTeX validation failed | ~2-5% | Fix LaTeX manually |
| Schema validation failed | ~1-2% | Re-extract or reject |
| Question marked "has_diagram" | ~20-30% | Verify diagram uploaded |

**Estimated Human Review**: ~15-20% of questions = 320-430 questions
**Time**: ~1-2 minutes per question = 5-15 hours total

---

#### Option 3: Crowdsourced Validation (Future Enhancement)

For scaling beyond MVP, allow trusted users to validate.

```javascript
// Gamified validation for Pro/Ultra users
{
  feature: "PYQ Validator",
  eligibility: "Pro/Ultra tier + completed 10 mock tests",
  rewards: [
    "5 XP per question validated",
    "Badge: 'PYQ Guardian' after 100 validations",
    "1 free mock test after 50 validations"
  ],
  validation_rules: {
    questions_per_session: 10,
    require_agreement: 2,  // 2 validators must agree
    escalate_if_disagree: true
  }
}
```

---

#### Option 4: Spot-Check Sampling (Lightweight)

For quick launch, validate a sample and trust AI for the rest.

```javascript
const SAMPLING_STRATEGY = {
  // Validate 100% of these
  always_validate: [
    "AI answer mismatch",
    "AI confidence < 0.6",
    "has_diagram: true",
    "LaTeX errors"
  ],

  // Random sample of rest
  random_sample: {
    percentage: 10,  // 10% random sample
    stratified_by: "subject"  // Equal across Physics/Chemistry/Math
  }
};

// Expected: ~30-40% human review instead of 100%
```

---

### Recommended MVP Validation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     EXTRACTION PHASE                             │
│  PDF → Images → Claude Vision → JSON                             │
│  + Answer Key PDF → Merge Answers                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 1: AUTOMATED VALIDATION (instant, $0)                    │
│  ✓ Schema validation                                             │
│  ✓ LaTeX validation                                              │
│  → Pass: 95%  |  Fail: 5% → Queue for review                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2: AI QUALITY CHECK (Claude Haiku, ~$3)                  │
│  ✓ Check completeness                                            │
│  ✓ Check for OCR errors                                          │
│  ✓ Validate math notation                                        │
│  → High confidence (>0.8): 85% → Auto-approve                   │
│  → Low confidence (<0.8): 15% → Queue for review                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 3: AI ANSWER VERIFICATION (Claude Haiku, ~$5)            │
│  ✓ Solve question independently                                  │
│  ✓ Compare with answer key                                       │
│  → Match: 90% → Auto-approve                                     │
│  → Mismatch: 10% → Queue for review                              │
│  → Also store AI solution for later use                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 4: HUMAN REVIEW (Admin Dashboard)                        │
│  Questions flagged: ~15-20% (~350 questions)                    │
│  Time: ~10 hours of human review                                │
│  Actions: Approve / Edit / Re-extract / Reject                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  FINAL: STORE IN FIRESTORE                                      │
│  Collection: pyq_questions                                       │
│  With: validation_status, validation_notes, ai_solution          │
└─────────────────────────────────────────────────────────────────┘
```

**Expected Results**:
| Metric | Value |
|--------|-------|
| Total questions | 2,160 |
| Auto-approved | ~1,800 (83%) |
| Human review needed | ~360 (17%) |
| Likely rejections | ~20-50 (1-2%) |
| Final usable | ~2,100+ |

---

### MVP Implementation Checklist

#### Week 1: Extraction Infrastructure
- [ ] Download all JEE Main PDFs (2022-2024) + answer keys from NTA
- [ ] Set up `backend/scripts/extractPYQFromPDF.js`
- [ ] Test extraction on 1 paper (2024 Jan Shift 1)
- [ ] Validate extraction accuracy manually
- [ ] Refine prompts based on results

#### Week 2: Validation Pipeline
- [ ] Implement 4-stage validation pipeline
- [ ] Build simple admin dashboard for human review
- [ ] Run extraction on all 24 papers (2022-2024 Main)
- [ ] Process through validation pipeline
- [ ] Complete human review of flagged questions

#### Week 3: Integration & Polish
- [ ] Store validated questions in `pyq_questions` collection
- [ ] Generate AI solutions for all questions
- [ ] Create `pyq_papers` collection with paper metadata
- [ ] Test PYQ feature end-to-end
- [ ] Launch PYQ MVP

---

### Future Enhancement: Hybrid Approach

**Phase 2 (Expansion)**: AI-assisted extraction for 2020-2022
- Use Claude Vision API for initial extraction
- Human validation pass
- ~2,000 questions, 2 weeks (with AI assist)

**Phase 3 (JEE Advanced)**: Partner or purchase
- JEE Advanced papers are harder to source (not always publicly released)
- Partner with coaching institute or purchase dataset
- ~500 questions (2020-2024)

**Phase 4 (Historical)**: Community contribution (optional)
- Allow verified tutors/teachers to contribute older papers
- Moderation and validation workflow
- Could go back to 2010+

---

## PYQ Data Schema

```javascript
// Collection: pyq_questions/{questionId}
{
  // Identifiers
  question_id: "PYQ_2024_MAIN_JAN_S1_SHIFT1_PHY_001",

  // PYQ-specific metadata
  pyq_metadata: {
    exam_type: "jee_main" | "jee_advanced",
    year: 2024,
    session: "january" | "april" | "paper1" | "paper2", // Main vs Advanced naming
    shift: "shift1" | "shift2" | "morning" | "evening",
    paper_date: "2024-01-27",
    question_number_in_paper: 1,
    section: "A" | "B",  // JEE Main Section A (MCQ) vs B (Numerical)

    // Source tracking
    source: "nta_official" | "manual_entry" | "ai_extracted" | "third_party",
    source_url: "https://jeemain.nta.nic.in/...",
    extracted_by: "system:claude_vision" | "user:admin123",
    validated_by: "user:content_reviewer_456",
    validation_date: Timestamp
  },

  // Classification (same as questions collection)
  subject: "Physics",
  chapter: "Mechanics",
  chapter_key: "physics_mechanics",
  sub_topics: ["Projectile Motion"],

  // Question type
  question_type: "mcq_single" | "mcq_multi" | "numerical" | "integer" | "matrix_match",
  difficulty: "easy" | "medium" | "hard",  // Assessed post-hoc

  // IRT Parameters (calibrated from actual student responses)
  irt_parameters: {
    difficulty_b: null,  // Calibrate after 100+ responses
    discrimination_a: null,
    guessing_c: 0.25,
    calibration_status: "uncalibrated" | "calibrated",
    calibration_sample_size: 0
  },

  // Question Content (same as questions collection)
  question_text: "A projectile is fired...",
  question_text_html: "<p>A projectile is fired...</p>",
  question_latex: "\\( v = \\sqrt{2gh} \\)",
  has_diagram: true,
  diagram_url: "gs://jeevibe-pyq/diagrams/2024_main_jan_s1_phy_001.png",

  options: [
    { option_id: "A", text: "10 m/s", html: "<p>10 m/s</p>" },
    { option_id: "B", text: "20 m/s", html: "<p>20 m/s</p>" },
    { option_id: "C", text: "30 m/s", html: "<p>30 m/s</p>" },
    { option_id: "D", text: "40 m/s", html: "<p>40 m/s</p>" }
  ],

  // Answer
  correct_answer: "B",
  correct_answer_text: "20 m/s",
  official_answer_key_ref: "NTA Answer Key 2024 Jan Session 1",

  // Solution (may be added later)
  solution_text: null,  // Initially null, add over time
  solution_steps: null,
  solution_source: null,  // "nta_official" | "jeevibe_content" | "ai_generated"

  // Usage Statistics
  usage_stats: {
    times_presented: 0,
    times_correct: 0,
    times_incorrect: 0,
    avg_time_seconds: null
  },

  // Audit
  created_at: Timestamp,
  updated_at: Timestamp,
  validation_status: "approved" | "pending_review" | "flagged",
  validation_notes: ""
}
```

---

## PYQ Paper Schema

```javascript
// Collection: pyq_papers/{paperId}
// Represents a complete JEE paper (for "Full Paper Mode")
{
  paper_id: "JEE_MAIN_2024_JAN_S1_SHIFT1",

  // Paper metadata
  exam_type: "jee_main" | "jee_advanced",
  year: 2024,
  session: "january",
  shift: "shift1",
  paper_date: "2024-01-27",

  // Paper structure
  duration_minutes: 180,
  total_questions: 90,
  total_marks: 300,

  sections: [
    {
      section_id: "A",
      section_name: "Section A - MCQ",
      question_count: 60,  // 20 per subject
      marks_per_correct: 4,
      marks_per_incorrect: -1,
      marks_per_unattempted: 0
    },
    {
      section_id: "B",
      section_name: "Section B - Numerical",
      question_count: 30,  // 10 per subject, attempt 5
      marks_per_correct: 4,
      marks_per_incorrect: 0,  // No negative for numerical
      marks_per_unattempted: 0,
      max_attempts: 15  // Only 5 per subject from 10
    }
  ],

  // Question references
  question_ids: [
    "PYQ_2024_MAIN_JAN_S1_SHIFT1_PHY_001",
    "PYQ_2024_MAIN_JAN_S1_SHIFT1_PHY_002",
    // ... all 90 questions
  ],

  // Availability
  status: "complete" | "partial" | "solutions_pending",
  questions_entered: 90,
  questions_with_solutions: 45,

  // Statistics (from JEEVibe users)
  stats: {
    times_attempted: 0,
    avg_score: null,
    avg_completion_time_minutes: null,
    percentile_data: []  // Populated as users complete
  },

  // Audit
  created_at: Timestamp,
  updated_at: Timestamp,
  source: "nta_official",
  source_url: "https://..."
}
```

---

## Feature Modes

### Mode 1: Full Paper Practice (Timed)

Simulates actual exam experience with a complete paper.

**Flow**:
```
PYQ Selection → Choose Year/Session → Start Full Paper → 3hr Timer → Submit → Results
```

**Features**:
- Exact JEE paper structure (90 questions, 3 hours)
- Original marking scheme for that year
- Percentile comparison with JEEVibe users who took same paper
- Optional: Compare with official cutoffs

**Reuses from Mock Tests**:
- `mock_test_question_screen.dart` → rename to `test_question_screen.dart`
- `mock_test_results_screen.dart` → rename to `test_results_screen.dart`
- Timer, navigation, auto-save, pause functionality

### Mode 2: Topic-wise PYQ Practice (Untimed)

Practice PYQs filtered by chapter/topic.

**Flow**:
```
PYQ Selection → Choose Chapter → Filter by Year Range → Practice Mode → Review
```

**Features**:
- Filter by subject, chapter, sub-topic
- Filter by year range (e.g., "Last 5 years")
- Untimed practice (no pressure)
- Immediate feedback after each question
- Track which PYQs completed per chapter

**Similar to**: Daily Quiz practice mode

### Mode 3: Year-wise Question Bank (Browse)

Browse and search all PYQs.

**Flow**:
```
PYQ Bank → Search/Filter → View Question → Attempt → See Solution
```

**Features**:
- Search by keyword, topic, difficulty
- Bookmark questions for later
- Mark as "mastered" or "needs review"
- View solution without attempting

---

## Tier-Based Gating

| Tier | Full Paper Mode | Topic-wise Practice | Question Bank |
|------|-----------------|---------------------|---------------|
| **Free** | 1 paper/month | Last 2 years only | Last 2 years only |
| **Pro** | 5 papers/month | Last 5 years | All years |
| **Ultra** | Unlimited | All years | All years + bookmarks |

**Additional Pro/Ultra Benefits**:
- Detailed analytics per paper
- Chapter-wise PYQ performance tracking
- "PYQ Mastery" badges

---

## Solution Strategy

### Where Do Solutions Come From?

**Option A: AI-Generated Solutions (Recommended Start)**

```javascript
async function generatePYQSolution(question) {
  const response = await callClaude({
    model: 'claude-sonnet-4-20250514',
    messages: [{
      role: 'user',
      content: `
You are a JEE expert tutor. Solve this JEE ${question.pyq_metadata.year} question step-by-step.

Question: ${question.question_text}
Options: ${JSON.stringify(question.options)}
Correct Answer: ${question.correct_answer}

Provide:
1. Quick explanation (1-2 sentences)
2. Detailed step-by-step solution
3. Key concept tested
4. Common mistakes to avoid
5. Related topics to review

Format as JSON matching JEEVibe solution_steps schema.
`
    }]
  });

  return parseSolutionResponse(response);
}
```

**Validation**: Human review for accuracy, especially for complex problems.

**Option B: Content Team Written Solutions**

- Higher quality, JEEVibe voice/style
- More expensive and time-consuming
- Reserve for most important/difficult questions

**Option C: Hybrid**

- AI-generate all solutions initially
- Human review and enhance top 20% (most attempted, most failed)
- Community flagging for incorrect solutions

---

## Implementation Phases

### Phase 1: Data Infrastructure & Sourcing

- [ ] Create `pyq_questions` and `pyq_papers` Firestore collections
- [ ] Build admin interface for PYQ entry (or use existing CMS)
- [ ] Manual entry: 2024 JEE Main (all sessions) - ~720 questions
- [ ] Manual entry: 2023 JEE Main (all sessions) - ~720 questions
- [ ] Generate AI solutions for entered questions
- [ ] Validate solutions (human review)

### Phase 2: Full Paper Mode

- [ ] Extend Mock Test UI to support PYQ (rename shared components)
- [ ] `PYQService` extends `BaseTestService`
- [ ] `pyq_provider.dart` extends `base_test_provider.dart`
- [ ] `pyq_selection_screen.dart` - Year/session picker
- [ ] Scoring with year-specific marking schemes
- [ ] Results with percentile (JEEVibe users)

### Phase 3: Topic-wise Practice

- [ ] Topic filter UI on PYQ selection
- [ ] Untimed practice mode
- [ ] Per-question feedback (same as daily quiz)
- [ ] Track PYQ completion per chapter

### Phase 4: Expansion

- [ ] AI-assisted extraction for 2020-2022 papers
- [ ] Human validation workflow
- [ ] JEE Advanced papers (partner or purchase)
- [ ] Historical papers (2015-2019)

### Phase 5: Analytics & Insights

- [ ] "PYQ Mastery" per chapter
- [ ] Year-over-year difficulty trends
- [ ] "Questions like this appear every year" insights
- [ ] Prediction: "Based on patterns, expect X topic in 2025"

---

## Differentiation from Competitors

| Feature | JEEVibe PYQ | Competitors |
|---------|-------------|-------------|
| **IRT Integration** | PYQ performance updates theta | Static practice |
| **Priya Ma'am Feedback** | AI tutor explains mistakes | Just show solution |
| **Adaptive Recommendations** | "You struggle with PYQ mechanics" | Manual filtering |
| **Full Paper Simulation** | Realistic timer, navigation | Often untimed only |
| **Cross-Reference** | "This concept also tested in 2022, 2023" | Isolated questions |

---

## Open Questions for Discussion

1. **Solution Quality**: AI-generated vs human-written vs hybrid?
   - Recommendation: AI-generated with human review for flagged/complex questions

2. **JEE Advanced Sourcing**: Partner, purchase, or skip initially?
   - Recommendation: Skip initially, focus on JEE Main (larger audience)

3. **Historical Depth**: How far back should we go?
   - Recommendation: Start with 2020-2024 (5 years), expand based on demand

4. **Community Contributions**: Allow users to submit solutions?
   - Recommendation: Not initially (quality control), consider for v2

5. **Diagrams**: How to handle questions with diagrams?
   - Recommendation: Store as images in Cloud Storage, render in app

6. **Answer Key Disputes**: NTA sometimes revises answer keys. How to handle?
   - Recommendation: Track `answer_key_version`, update if NTA revises

---

## Success Metrics

1. **Data Coverage**: 90%+ of JEE Main papers from 2020-2024 entered
2. **Solution Quality**: < 1% of solutions flagged as incorrect
3. **User Engagement**: 40%+ of active users try PYQ within first month
4. **Completion Rate**: 60%+ of started full papers completed
5. **Learning Efficacy**: PYQ practice correlates with mock test improvement

---

## Files to Create/Modify

### Backend

**New Services**:
- `backend/src/services/pyqService.js` - Extends BaseTestService
- `backend/src/services/pyqQuestionService.js` - CRUD for PYQ questions
- `backend/src/services/pyqSolutionService.js` - AI solution generation

**New Routes**:
- `backend/src/routes/pyq.js` - PYQ endpoints

**Scripts**:
- `backend/scripts/extractPYQFromPDF.js` - AI-assisted extraction
- `backend/scripts/generatePYQSolutions.js` - Batch solution generation

### Mobile

**New Screens**:
- `mobile/lib/screens/pyq/pyq_selection_screen.dart` - Year/session picker
- `mobile/lib/screens/pyq/pyq_topic_practice_screen.dart` - Topic filter
- `mobile/lib/screens/pyq/pyq_question_bank_screen.dart` - Browse all

**New Providers**:
- `mobile/lib/providers/pyq_provider.dart` - Extends base_test_provider

**New Services**:
- `mobile/lib/services/pyq_api_service.dart` - API client

### Shared (Renamed from Mock Test)

- `test_question_screen.dart` (was `mock_test_question_screen.dart`)
- `test_results_screen.dart` (was `mock_test_results_screen.dart`)
- `base_test_provider.dart` (abstract base)

---

## Cost Analysis

### Data Entry (Manual)

| Item | Cost Estimate |
|------|---------------|
| Content writer (JEE expertise) | ₹30,000-50,000/month |
| 720 questions/month throughput | ~₹50-70 per question |
| 2024 + 2023 papers (1,440 questions) | ₹70,000-100,000 |

### AI-Assisted Extraction

| Item | Cost Estimate |
|------|---------------|
| Claude Vision API per paper | ~$1-2 |
| 20 papers (2020-2022) | ~$30-40 |
| Human validation (review) | ₹20-30 per question |

### Solution Generation

| Item | Cost Estimate |
|------|---------------|
| Claude Sonnet per solution | ~$0.02-0.03 |
| 3,000 solutions | ~$60-90 |
| Human review (20% sample) | ₹10,000-15,000 |

**Total Estimated Cost for MVP (2020-2024 JEE Main)**:
- Manual entry + AI solutions + validation: ₹1,50,000-2,00,000 (~$1,800-2,400)
- Timeline: 8-10 weeks

---

## Appendix: NTA Paper Release Schedule

JEE Main papers are typically released:
- **January Session**: February (after session ends)
- **April Session**: May (after session ends)

JEE Advanced papers:
- Released after exam (June/July)
- Answer keys released within 1-2 weeks
- Final answer keys after challenges resolved

**Automation Opportunity**: Set up alerts for NTA paper releases, trigger extraction pipeline.
