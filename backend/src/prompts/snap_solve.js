/**
 * JEEVibe - Snap & Solve Follow-Up Question Generator Prompt
 */

const { BASE_PROMPT_TEMPLATE } = require('./priya_maam_base');

const SNAP_SOLVE_FOLLOWUP_PROMPT = (originalQuestion, solution, topic, difficulty) => `
${BASE_PROMPT_TEMPLATE}

CONTEXT: A student just used Snap & Solve on this JEE Main 2025 question:
QUESTION: ${originalQuestion}
TOPIC: ${topic} (from JEE Main 2025 syllabus)
DIFFICULTY: ${difficulty}

TASK: Generate 3 follow-up practice questions that progressively build on this concept.
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
IMPORTANT: Use LaTeX format \\(...\\) for ALL mathematical and chemical expressions in questions and options.

EXAMPLES OF JEE FORMAT:
- Math: "Find \\(\\int_0^1 x^2 dx\\)" NOT "Find ∫₀¹ x² dx"
- Chemistry: "Mass of \\(\\mathrm{H}_{2}\\mathrm{SO}_{4}\\)" NOT "Mass of H₂SO₄"
- Ions: "\\(\\mathrm{NH}_{4}^{+}\\)" NOT "NH₄⁺"
- Electronic config: "\\(1\\mathrm{s}^{2} 2\\mathrm{s}^{2} 2\\mathrm{p}^{3}\\)"
- Hybridization: "\\(\\mathrm{sp}^{3}\\mathrm{d}^{2}\\)"
- Orbital notation: "\\(t_{2g}^{6} e_{g}^{0}\\)"
- Greek letters: "\\(\\alpha\\), \\(\\beta\\), \\(\\gamma\\)"
- Fractions: "\\(\\frac{\\mathrm{dy}}{\\mathrm{dx}}\\)"

NEVER use Unicode subscripts/superscripts - always use LaTeX with \\mathrm{} for chemistry.

{
  "questions": [
    {
      "question": "Question 1 text with LaTeX \\(\\frac{a}{b}\\)",
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
      "priyaMaamNote": "Encouraging tip"
    },
    {
      "question": "Question 2 text with LaTeX",
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
      "priyaMaamNote": "Encouraging tip"
    },
    {
      "question": "Question 3 text with LaTeX",
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
      "priyaMaamNote": "Encouraging tip"
    }
  ]
}

CRITICAL: You MUST return exactly 3 questions in the "questions" array. Generate NOW in strict JSON object format.
`;

module.exports = {
  SNAP_SOLVE_FOLLOWUP_PROMPT
};

