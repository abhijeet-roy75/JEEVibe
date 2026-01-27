/**
 * JEEVibe - Snap & Solve Follow-Up Question Generator Prompt
 */

const { BASE_PROMPT_TEMPLATE } = require('./priya_maam_base');

const SNAP_SOLVE_FOLLOWUP_PROMPT = (originalQuestion, solution, topic, difficulty, language = 'en') => `
${BASE_PROMPT_TEMPLATE}

CONTEXT: A student just used Snap & Solve on this JEE Main 2025 question:
QUESTION: ${originalQuestion}
TOPIC: ${topic} (from JEE Main 2025 syllabus)
DIFFICULTY: ${difficulty}
LANGUAGE: ${language === 'hi' ? 'Hindi' : 'English'}

TASK: Generate 3 follow-up practice questions that progressively build on this concept.
IMPORTANT: Generate questions and explanations in ${language === 'hi' ? 'Hindi (or Hinglish if appropriate for technical terms)' : 'English'}.
IMPORTANT: Questions must align with JEE Main 2025 syllabus and difficulty standards.

EXPLANATION REQUIREMENTS (CRITICAL):
- Each question MUST include a comprehensive, detailed explanation that helps students understand the concept deeply
- "approach": Provide 3-5 sentences explaining the overall strategy, key concepts involved, why this method works, and common pitfalls to avoid
- "steps": Each step should be 2-3 sentences with clear calculations, reasoning, and explanations. Include ALL necessary steps to reach the solution
- "finalAnswer": Provide the final answer with proper units and a brief verification or check
- Explanations should be educational and thorough, especially helpful when students get questions wrong
- Use Priya Ma'am's encouraging tone throughout explanations
- Include conceptual insights, not just procedural steps

REQUIREMENTS:
1. Question 1: SIMILAR difficulty, same core concept, different numbers/scenario
2. Question 2: SLIGHTLY HARDER, add one complexity layer
3. Question 3: HARDER, combine with related concept or multi-step

PROGRESSION EXAMPLE:
Original: "Find integral of x²"
Q1: "Find integral of 3x² + 2x" (same technique, different numbers)
Q2: "Find integral of x²e^x" (requires integration by parts now)
Q3: "Find area between y = x² and y = 2x from x=0 to x=2" (application)

MAINTAIN:
- Same topic domain
- Priya Ma'am's encouraging tone
- Clear difficulty progression
- Each question standalone (don't reference previous)

OUTPUT FORMAT (strict JSON object - required for API):
IMPORTANT: Use UNICODE characters for ALL mathematical and chemical expressions (NOT LaTeX).
This ensures clean JSON output without escaping issues.

UNICODE CONVERSION RULES:
- Fractions: Use (a)/(b) format, e.g., (1)/(2) for one-half
- Superscripts: Use ⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻ⁿˣʸ, e.g., x² for x squared, aⁿ for a to the n
- Subscripts: Use ₀₁₂₃₄₅₆₇₈₉ₐₑᵢₒᵣᵤₓₙ, e.g., H₂O, CO₂, a₁
- Common symbols: × (times), ÷ (divide), ± (plus-minus), √ (sqrt), ∞ (infinity)
- Comparisons: ≤ ≥ ≠ ≈
- Set notation: ∈ ∪ ∩ ⊂ ⊃
- Arrows: → ⇒ ⇔ ↔
- Number sets: ℝ ℕ ℤ ℚ ℂ
- Greek: α β γ δ θ λ μ π σ ω Δ Σ Ω
- Calculus: ∫ ∂ ∑ ∏ ∇
- Angles: ° (degree)

CORRECT EXAMPLES (Unicode):
- Math: "Find ∫₀¹ x² dx"
- Chemistry: "Mass of H₂SO₄"
- Ions: "NH₄⁺", "SO₄²⁻"
- Fractions: "(dy)/(dx)", "(1)/(π²)"
- Intervals: "[1/10¹⁰, ∞)", "(1/π², 1/π)"
- Functions: "f(x) = x² sin(π/x²)"
- Limits: "lim x→0"
- Sets: "x ∈ ℝ", "A ∪ B"

DO NOT USE:
- ❌ LaTeX backslashes: \\frac, \\int, \\mathrm (causes JSON escaping issues)
- ❌ Plain text for math: "x^2" (use x² instead)
- ❌ Plain text subscripts: "H2O" (use H₂O instead)

{
  "questions": [
    {
      "question": "Question 1 text with Unicode like x² + (a)/(b) = 0",
      "options": {
        "A": "Option A",
        "B": "Option B",
        "C": "Option C",
        "D": "Option D"
      },
      "correctAnswer": "A",
      "explanation": {
        "approach": "Comprehensive strategy explanation (3-5 sentences explaining the overall approach, key concepts involved, and why this method works)",
        "steps": ["Detailed step 1 with calculations and reasoning (2-3 sentences)", "Detailed step 2 with calculations and reasoning (2-3 sentences)", "Continue with all necessary steps, each with clear explanations"],
        "finalAnswer": "Final answer with units and brief verification"
      },
      "priyaMaamNote": "Encouraging tip",
      "commonMistakes": [
        "Common mistake 1 students make in this type of problem",
        "Common mistake 2 that leads to wrong answers",
        "Common mistake 3 to avoid"
      ],
      "keyTakeaway": "One-sentence key insight or formula to remember for similar problems"
    },
    {
      "question": "Question 2 text with Unicode like ∫₀¹ f(x) dx",
      "options": {
        "A": "Option A",
        "B": "Option B",
        "C": "Option C",
        "D": "Option D"
      },
      "correctAnswer": "B",
      "explanation": {
        "approach": "Comprehensive strategy explanation (3-5 sentences explaining the overall approach, key concepts involved, and why this method works)",
        "steps": ["Detailed step 1 with calculations and reasoning (2-3 sentences)", "Detailed step 2 with calculations and reasoning (2-3 sentences)", "Continue with all necessary steps, each with clear explanations"],
        "finalAnswer": "Final answer with units and brief verification"
      },
      "priyaMaamNote": "Encouraging tip",
      "commonMistakes": [
        "Common mistake 1 students make in this type of problem",
        "Common mistake 2 that leads to wrong answers",
        "Common mistake 3 to avoid"
      ],
      "keyTakeaway": "One-sentence key insight or formula to remember for similar problems"
    },
    {
      "question": "Question 3 text with Unicode like H₂SO₄ + 2NaOH → Na₂SO₄ + 2H₂O",
      "options": {
        "A": "Option A",
        "B": "Option B",
        "C": "Option C",
        "D": "Option D"
      },
      "correctAnswer": "C",
      "explanation": {
        "approach": "Comprehensive strategy explanation (3-5 sentences explaining the overall approach, key concepts involved, and why this method works)",
        "steps": ["Detailed step 1 with calculations and reasoning (2-3 sentences)", "Detailed step 2 with calculations and reasoning (2-3 sentences)", "Continue with all necessary steps, each with clear explanations"],
        "finalAnswer": "Final answer with units and brief verification"
      },
      "priyaMaamNote": "Encouraging tip",
      "commonMistakes": [
        "Common mistake 1 students make in this type of problem",
        "Common mistake 2 that leads to wrong answers",
        "Common mistake 3 to avoid"
      ],
      "keyTakeaway": "One-sentence key insight or formula to remember for similar problems"
    }
  ]
}

CRITICAL: You MUST return exactly 3 questions in the "questions" array. Generate NOW in strict JSON object format.
`;

module.exports = {
  SNAP_SOLVE_FOLLOWUP_PROMPT
};

