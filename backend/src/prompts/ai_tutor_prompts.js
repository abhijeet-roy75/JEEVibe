/**
 * JEEVibe - AI Tutor (Priya Ma'am) Prompt Templates
 * Extended prompts for conversational tutoring sessions
 */

const { BASE_PROMPT_TEMPLATE } = require('./priya_maam_base');

/**
 * System prompt for AI Tutor conversations
 * Extends base Priya Ma'am persona with tutoring-specific guidelines
 */
const AI_TUTOR_SYSTEM_PROMPT = `${BASE_PROMPT_TEMPLATE}

## AI TUTOR CONVERSATION MODE

You are now in a tutoring conversation with a JEE aspirant. This is an ongoing dialogue where the student may:
- Ask follow-up questions about concepts
- Request clarification on previous explanations
- Change topics mid-conversation
- Share their confusion or struggles
- Ask for practice problems or study tips

### Conversation Guidelines:

1. **Contextual Awareness**: Reference what the student is discussing if relevant.

2. **Socratic Teaching**: Ask guiding questions occasionally.

3. **Acknowledge Confusion**: Be empathetic but brief when students struggle.

### RESPONSE FORMATTING (CRITICAL - MUST FOLLOW):

1. **BE CONCISE - THIS IS MANDATORY**:
   - Maximum 100-150 words for general tips/advice/motivation
   - Maximum 150-250 words for concept explanations
   - For "tips" questions: Give 3-5 SHORT bullet points only
   - NEVER write lengthy paragraphs - students read on mobile phones

2. **FORMAT FOR MOBILE READABILITY**:
   - Use numbered lists (1. 2. 3.) with EACH item on its own line
   - Use bullet points (•) for non-sequential items, EACH on its own line
   - Use <strong>bold text</strong> for key terms (NOT ** markdown syntax)
   - Keep each bullet/numbered point to 1 sentence maximum
   - Add a blank line between list items for readability

3. **CORRECT FORMAT EXAMPLE**:
   "Here are my top JEE tips:

   1. <strong>Practice daily</strong> - Even 30 mins of focused practice beats hours of passive reading.

   2. <strong>Solve PYQs</strong> - Master the last 10 years' papers.

   3. <strong>Target weak areas</strong> - Growth happens outside your comfort zone!

   Which topic should we work on?"

4. **WRONG FORMAT (NEVER DO THIS)**:
   "Here are my tips: 1. Practice daily because consistency is important and you should aim for at least 2-3 hours 2. Solve previous year questions 3. Focus on weak areas..."
   (Too dense, no line breaks, too wordy)

5. **End with ONE short question** to keep conversation going.

### Student Profile:
{{STUDENT_CONTEXT}}

### Current Discussion Context:
{{CURRENT_CONTEXT}}
`;

/**
 * Greeting templates for different context types
 */
const CONTEXT_GREETINGS = {
  solution: [
    "I see you're looking at a {{subject}} problem on {{topic}}! What would you like to discuss about this solution?",
    "Let's talk about this {{topic}} problem! Is there a specific step that's confusing, or would you like me to explain the overall approach?",
    "Nice work getting to the solution! I'm here to help you understand it better. What questions do you have about this {{topic}} problem?"
  ],
  quiz: [
    "I see you've completed a quiz with {{score}}/{{total}}! Let's review together. Would you like to go through the questions you missed?",
    "Good effort on the quiz! Let me help you understand where things went wrong so you can ace it next time.",
    "Let's analyze your quiz performance! I noticed some patterns in the questions you found challenging. Want me to explain?"
  ],
  chapterPractice: [
    "Great job practicing {{chapterName}}! You got {{score}}/{{totalAnswered}}. Let's review the questions together. What would you like to focus on?",
    "I see you've been working on {{chapterName}}! Let me help you understand the concepts better. Which questions were tricky?",
    "Nice work on {{chapterName}} practice! Let's go through the challenging questions and strengthen your understanding."
  ],
  analytics: [
    "I've been looking at your progress! You've been doing well in {{strongSubject}}, and I think we should focus on strengthening {{weakArea}}. What do you think?",
    "Your analytics show interesting patterns! Let's talk about how to improve your weaker areas while maintaining your strengths.",
    "Based on your performance data, I have some suggestions for your study plan. Ready to discuss?"
  ],
  general: [
    "Hello! Ready to study? What would you like to work on today?",
    "Good to see you! How can I help with your JEE preparation today?",
    "Hey there! What's on your mind? Whether it's doubts, concepts, or study tips - I'm here to help!"
  ]
};

/**
 * Quick action definitions by context type
 */
const QUICK_ACTIONS = {
  solution: [
    { id: 'explain_steps', label: 'Explain step by step', prompt: 'Can you explain the solution step by step in simpler terms?' },
    { id: 'why_approach', label: 'Why this approach?', prompt: 'Why did we use this particular approach? Are there other methods?' },
    { id: 'similar_practice', label: 'Similar practice', prompt: 'Can you give me a similar practice problem to try?' },
    { id: 'common_mistakes', label: 'Common mistakes', prompt: 'What are common mistakes students make with this type of problem?' }
  ],
  quiz: [
    { id: 'review_mistakes', label: 'Review mistakes', prompt: 'Help me understand where I went wrong in the questions I missed.' },
    { id: 'concept_gaps', label: 'Concept gaps', prompt: 'What concepts should I revise based on my quiz performance?' },
    { id: 'practice_weak', label: 'Practice weak areas', prompt: 'Can you suggest practice problems for my weak areas?' },
    { id: 'study_tips', label: 'Study tips', prompt: 'What study tips do you have for improving in these topics?' }
  ],
  chapterPractice: [
    { id: 'review_mistakes', label: 'Review mistakes', prompt: 'Help me understand where I went wrong in this chapter practice.' },
    { id: 'chapter_concepts', label: 'Key concepts', prompt: 'What are the key concepts I should focus on for this chapter?' },
    { id: 'more_practice', label: 'More practice', prompt: 'Can you suggest how to practice this chapter more effectively?' },
    { id: 'common_errors', label: 'Common errors', prompt: 'What are common mistakes students make in this chapter?' }
  ],
  analytics: [
    { id: 'improvement_plan', label: 'Improvement plan', prompt: 'Based on my analytics, what should I focus on to improve?' },
    { id: 'weak_chapters', label: 'Weak chapters', prompt: 'Help me understand my weak chapters and how to tackle them.' },
    { id: 'study_schedule', label: 'Study schedule', prompt: 'Can you suggest a study schedule based on my performance?' },
    { id: 'strong_areas', label: 'Strong areas', prompt: 'What are my strongest areas and how can I maintain them?' }
  ],
  general: [
    { id: 'jee_tips', label: 'JEE tips', prompt: 'What are your top tips for JEE Main preparation?' },
    { id: 'doubt_clearing', label: 'Doubt clearing', prompt: 'I have a doubt about a concept. Can you help?' },
    { id: 'motivation', label: 'Motivation', prompt: "I'm feeling overwhelmed with preparation. Can you help me stay motivated?" },
    { id: 'study_plan', label: 'Study plan', prompt: 'Help me create a study plan for the next week.' }
  ]
};

/**
 * Build the student context string for injection into system prompt
 * @param {Object} studentData - Student profile and performance data
 * @returns {string} Formatted student context
 */
function buildStudentContext(studentData) {
  if (!studentData) {
    return 'No student data available. Treat as a new student.';
  }

  const parts = [];

  if (studentData.firstName) {
    parts.push(`Name: ${studentData.firstName}`);
  }

  if (studentData.overallPercentile !== undefined) {
    parts.push(`Overall JEE readiness: ${Math.round(studentData.overallPercentile)}th percentile`);
  }

  if (studentData.thetaBySubject) {
    const subjects = Object.entries(studentData.thetaBySubject)
      .map(([subject, data]) => `${subject}: ${Math.round(data.percentile || 50)}th percentile`)
      .join(', ');
    parts.push(`Subject performance: ${subjects}`);
  }

  if (studentData.strengths && studentData.strengths.length > 0) {
    parts.push(`Strengths: ${studentData.strengths.slice(0, 3).join(', ')}`);
  }

  if (studentData.weaknesses && studentData.weaknesses.length > 0) {
    parts.push(`Areas to improve: ${studentData.weaknesses.slice(0, 3).join(', ')}`);
  }

  if (studentData.streak) {
    parts.push(`Current study streak: ${studentData.streak} days`);
  }

  return parts.length > 0 ? parts.join('\n') : 'New student - no performance data yet.';
}

/**
 * Build the current context string for injection into system prompt
 * @param {Object} context - Current discussion context (solution, quiz, etc.)
 * @returns {string} Formatted context
 */
function buildCurrentContext(context) {
  if (!context || context.type === 'general') {
    return 'General conversation - no specific problem or quiz context.';
  }

  const parts = [];

  parts.push(`Discussion type: ${context.type}`);

  if (context.title) {
    parts.push(`Topic: ${context.title}`);
  }

  if (context.type === 'solution' && context.snapshot) {
    const s = context.snapshot;
    if (s.question) {
      parts.push(`\nQuestion being discussed:\n${s.question}`);
    }
    if (s.approach) {
      parts.push(`\nSolution approach: ${s.approach}`);
    }
    if (s.steps && s.steps.length > 0) {
      parts.push(`\nSolution steps:\n${s.steps.map((step, i) => `${i + 1}. ${step}`).join('\n')}`);
    }
    if (s.finalAnswer) {
      parts.push(`\nFinal answer: ${s.finalAnswer}`);
    }
  }

  if (context.type === 'quiz' && context.snapshot) {
    const q = context.snapshot;
    if (q.score !== undefined && q.total !== undefined) {
      parts.push(`Quiz score: ${q.score}/${q.total}`);
    }
    if (q.incorrectQuestions && q.incorrectQuestions.length > 0) {
      parts.push(`\nQuestions the student got wrong:`);
      q.incorrectQuestions.forEach((iq, i) => {
        parts.push(`${i + 1}. ${iq.question || 'Question ' + (i + 1)}`);
        if (iq.studentAnswer) parts.push(`   Student answered: ${iq.studentAnswer}`);
        if (iq.correctAnswer) parts.push(`   Correct answer: ${iq.correctAnswer}`);
      });
    }
  }

  if (context.type === 'analytics' && context.snapshot) {
    const a = context.snapshot;
    if (a.focusAreas && a.focusAreas.length > 0) {
      parts.push(`\nFocus areas (need improvement):`);
      a.focusAreas.forEach(area => {
        parts.push(`- ${area.chapter}: ${Math.round(area.percentile)}th percentile`);
      });
    }
  }

  return parts.join('\n');
}

/**
 * Get a random greeting for the given context type
 * @param {string} contextType - Type of context (solution, quiz, analytics, general)
 * @param {Object} contextData - Data to interpolate into greeting
 * @returns {string} Formatted greeting
 */
function getContextGreeting(contextType, contextData = {}) {
  const greetings = CONTEXT_GREETINGS[contextType] || CONTEXT_GREETINGS.general;
  const template = greetings[Math.floor(Math.random() * greetings.length)];

  // Simple template interpolation
  return template.replace(/\{\{(\w+)\}\}/g, (match, key) => {
    return contextData[key] !== undefined ? contextData[key] : match;
  });
}

/**
 * Get quick actions for the given context type
 * @param {string} contextType - Type of context
 * @returns {Array} Quick action definitions
 */
function getQuickActions(contextType) {
  return QUICK_ACTIONS[contextType] || QUICK_ACTIONS.general;
}

module.exports = {
  AI_TUTOR_SYSTEM_PROMPT,
  CONTEXT_GREETINGS,
  QUICK_ACTIONS,
  buildStudentContext,
  buildCurrentContext,
  getContextGreeting,
  getQuickActions
};
