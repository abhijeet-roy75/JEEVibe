# JEEVibe Weekly MPA Report - Development Specification

**Document Version:** 1.0  
**Date:** February 7, 2026  
**Owner:** Satish Shetty  
**Purpose:** Complete specification for implementing weekly Mistake Pattern Analytics (MPA) reports

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Report Structure](#report-structure)
3. [Data Requirements](#data-requirements)
4. [Content Generation Logic](#content-generation-logic)
5. [Report Examples](#report-examples)
6. [Technical Implementation](#technical-implementation)
7. [Delivery Mechanism](#delivery-mechanism)
8. [Success Metrics](#success-metrics)

---

## 1. Overview

### 1.1 Purpose

The Weekly MPA Report provides students with:
- **Personalized wins** - What they're doing well
- **Top 3 priority issues** - What's holding them back (ranked by ROI)
- **Actionable study guidance** - How to improve
- **No timeline prescription** - Students manage their own schedule

### 1.2 Design Principles

✅ **Wins first** - Start positive, build psychological safety  
✅ **Balanced feedback** - 30% wins, 60% fixes, 10% other  
✅ **ROI-driven** - Prioritize issues by impact  
✅ **Student autonomy** - Show priorities, not timelines  
✅ **Adaptive** - Calibrate to student level (strong vs struggling)  
✅ **Actionable** - Specific guidance, not generic advice  

### 1.3 When to Send

- **Frequency:** Weekly (Sunday 7 PM IST)
- **Minimum data:** 40+ questions completed in the week
- **Sources:** Initial Assessment + Daily Quizzes + Chapter Practice + Snap & Solve

### 1.4 Length & Format

- **Word count:** ~750 words
- **Read time:** 3-4 minutes
- **Format:** Email (text-based, mobile-optimized)
- **Tone:** Priya Ma'am's encouraging, analytical voice

---

## 2. Report Structure

### 2.1 Complete Template

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
JEEVIBE WEEKLY REPORT
Week of [Date Range]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

👩‍🏫 Hi [Name],

Great week of practice! You completed [N] questions and 
I found some clear wins and areas to focus on.

Let me show you what's working and where to improve.

- Priya Ma'am

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 YOUR WINS THIS WEEK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[WIN 1: Primary strength - Mastery/Improvement/Milestone]

[Details with specific metrics and encouragement]

─────────────────────────────────────────────────────────────

[WIN 2: Secondary achievement]

[Details with specific metrics]

─────────────────────────────────────────────────────────────

[WIN 3: Tertiary win - often consistency/effort]

[Details with encouragement]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 OVERALL PERFORMANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[N] questions | [X]% accuracy ([Y] correct, [Z] incorrect)

By Subject:
• [Subject 1]: [X]% [status icon] ([correct/total])
• [Subject 2]: [X]% [status icon] ([correct/total])
• [Subject 3]: [X]% [status icon] ([correct/total])

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 YOUR TOP 3 ISSUES TO FIX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Fix these in priority order for maximum improvement:

─────────────────────────────────────────────────────────────
🥇 PRIORITY 1: [Issue Name]

Impact: [N] out of [M] mistakes ([X]%)
Potential gain: +[Y]% accuracy

What's wrong:
[Specific description of the problem]

Root cause:
[One-sentence explanation of why this is happening]

What to study:
• [Topic 1 - specific guidance]
• [Topic 2 - specific guidance]
• [Topic 3 - specific guidance]
• [Topic 4 - specific guidance]

Suggested practice:
[Specific number of problems and what to focus on]

─────────────────────────────────────────────────────────────
🥈 PRIORITY 2: [Issue Name]

Impact: [N] out of [M] mistakes ([X]%)
Potential gain: +[Y]% accuracy

What's wrong:
[Specific description]

Root cause:
[One-sentence explanation]

What to study:
• [Topic 1]
• [Topic 2]
• [Topic 3]

Suggested practice:
[Specific guidance]

─────────────────────────────────────────────────────────────
🥉 PRIORITY 3: [Issue Name]

Impact: [N] out of [M] mistakes ([X]%)
Potential gain: +[Y]% accuracy

What's wrong:
[Specific description]

Root cause:
[One-sentence explanation]

What to study:
• [Topic 1]
• [Topic 2]
• [Topic 3]

Suggested practice:
[Specific guidance]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 HOW TO USE THIS REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You have 3 options:

Option 1: Fix Priority 1 first (recommended)
Focus all your study time on Priority 1 until you see 
improvement, then move to Priority 2.

Option 2: Work on all 3 simultaneously
Spend 60% time on Priority 1, 25% on Priority 2, 
15% on Priority 3.

Option 3: Pick what feels right
You know your strengths. Start where you feel most 
motivated or where you have upcoming tests.

No matter which approach you choose, these 3 areas 
give you the clearest path to improvement.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 POTENTIAL IMPROVEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

If you address these 3 issues:

Current accuracy:     [X]% [progress bar]
Potential accuracy:   [Y]% [progress bar]

This would put you in the top [Z]% of JEEVibe students.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Three priorities. Your timeline. Real improvement.

[Start Today's Quiz] [Practice Physics] [View Dashboard]

Questions? Reply anytime.
- Priya Ma'am

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

JEEVibe - Honest EdTech for JEE Preparation
support@jeevibe.app | jeevibe.app

Update preferences | Unsubscribe
```

---

## 3. Data Requirements

### 3.1 Complete JSON Schema

```json
{
  "user_id": "string",
  "report_period": {
    "start_date": "YYYY-MM-DD",
    "end_date": "YYYY-MM-DD",
    "week_number": "number"
  },
  
  "questions": [
    {
      // ═══════════════════════════════════════════════════════
      // TIER 1: BASIC FIELDS (Currently Available)
      // ═══════════════════════════════════════════════════════
      "question_id": "string",
      "subject": "Physics|Chemistry|Mathematics",
      "chapter": "string",
      "is_correct": "boolean",
      "correct_answer": "string",
      "time_spent_seconds": "number",
      "answered_at": "ISO 8601 timestamp",
      "source": "initial_assessment|daily_quiz|chapter_practice|snap_solve",
      
      // ═══════════════════════════════════════════════════════
      // TIER 2: CRITICAL FOR MPA (Must Add)
      // ═══════════════════════════════════════════════════════
      
      "user_answer": "string",  // ⭐ CRITICAL - Store when student submits
      
      // Following fields: JOIN from Question Bank at report generation
      "sub_topics": ["string"],
      "concepts_tested": ["string"],
      "difficulty_irt": "number",
      "distractor_analysis": {
        "A": "string - why this wrong answer is tempting",
        "B": "string",
        "C": "string",
        "D": "string"
      },
      
      // ═══════════════════════════════════════════════════════
      // TIER 3: ENHANCED METADATA (from Question Bank)
      // ═══════════════════════════════════════════════════════
      "metadata": {
        "common_mistakes": ["string"],
        "key_insight": "string",
        "hint": "string",
        "formula_used": "string",
        "prerequisite_concepts": ["string"]
      }
    }
  ],
  
  // ═══════════════════════════════════════════════════════
  // COMPUTED AT REPORT GENERATION
  // ═══════════════════════════════════════════════════════
  "analytics": {
    "summary": {
      "total_questions": "number",
      "correct": "number",
      "incorrect": "number",
      "accuracy": "number",
      "days_practiced": "number",
      "total_time_seconds": "number"
    },
    
    "by_subject": {
      "[subject_name]": {
        "total": "number",
        "correct": "number",
        "accuracy": "number",
        "status": "strength|needs_attention|priority"
      }
    },
    
    "baseline_comparison": {
      "assessment_accuracy": "number",
      "current_accuracy": "number",
      "improvement": "number"
    },
    
    "wins": [
      {
        "rank": "1|2|3",
        "type": "mastery|improvement|consistency|milestone|tough_questions|recovery",
        "title": "string",
        "metric": "string",
        "details": "string",
        "insight": "string"
      }
    ],
    
    "top_issues": [
      {
        "rank": "1|2|3",
        "priority": "highest|medium|low",
        "title": "string",
        "frequency": "number",
        "percentage": "number",
        "potential_gain": "number",
        "roi_score": "number (0-1)",
        
        "what_wrong": "string",
        "root_cause": "string",
        "what_to_study": ["string"],
        "suggested_practice": "string",
        
        "affected_chapters": ["string"]
      }
    ]
  }
}
```

### 3.2 Minimum Data Requirements

**To send weekly report:**
- ✅ At least 40 questions completed in the week
- ✅ Questions from at least 2 different sources
- ✅ At least 3 days of practice activity

**If not met:**
- Send encouragement message instead of full report
- "Keep practicing! We'll send your first weekly report after 40+ questions."

### 3.3 Critical Field: user_answer

**Implementation:**

```javascript
// When student submits answer
await firestore.collection('users').doc(userId)
  .collection('responses').add({
    question_id: 'PHY_ELEC_001',
    user_answer: 'B',              // ⭐ ADD THIS
    correct_answer: 'C',
    is_correct: false,
    time_spent_seconds: 127,
    answered_at: new Date(),
    source: 'daily_quiz',
    subject: 'Physics',            // Can also store these
    chapter: 'Electrostatics'      // or join later
  });
```

### 3.4 Question Bank Join

**At report generation time:**

```javascript
async function enrichResponsesWithMetadata(responses) {
  return await Promise.all(
    responses.map(async (response) => {
      // Fetch question metadata from question bank
      const question = await getQuestionById(response.question_id);
      
      return {
        ...response,
        sub_topics: question.sub_topics,
        concepts_tested: question.concepts_tested,
        difficulty_irt: question.difficulty_irt,
        distractor_analysis: question.distractor_analysis,
        metadata: question.metadata
      };
    })
  );
}
```

---

## 4. Content Generation Logic

### 4.1 Wins Detection Algorithm

```python
def generate_wins(student_data):
    """
    Generate 2-3 wins for the student.
    Every student gets wins, calibrated to their level.
    """
    wins = []
    
    # WIN TYPE 1: Subject/Chapter Mastery (60%+ in subject or 80%+ in chapter)
    for subject, stats in student_data.subjects.items():
        if stats.accuracy >= 60:
            perfect_chapters = get_perfect_chapters(subject, min_accuracy=80)
            wins.append({
                'rank': len(wins) + 1,
                'type': 'mastery',
                'icon': '✨',
                'title': f'{subject} Mastery',
                'metric': f'{stats.accuracy}% accuracy',
                'details': f"You're crushing {subject}! {stats.correct} out of {stats.total} correct.",
                'top_chapters': perfect_chapters[:3],
                'insight': generate_mastery_insight(subject, stats)
            })
    
    # WIN TYPE 2: Improvement (10%+ from baseline)
    if student_data.improvement_from_baseline >= 10:
        wins.append({
            'rank': len(wins) + 1,
            'type': 'improvement',
            'icon': '📈',
            'title': 'Visible Improvement',
            'metric': f'+{student_data.improvement_from_baseline}% from assessment',
            'baseline': {
                'label': 'Assessment',
                'accuracy': student_data.baseline_accuracy,
                'visual': generate_progress_bar(student_data.baseline_accuracy)
            },
            'current': {
                'label': 'This week',
                'accuracy': student_data.current_accuracy,
                'visual': generate_progress_bar(student_data.current_accuracy)
            },
            'insight': f"You improved {student_data.improvement_from_baseline}% - practice is working!"
        })
    
    # WIN TYPE 3: Consistency (3+ days practiced)
    if student_data.days_practiced >= 3:
        wins.append({
            'rank': len(wins) + 1,
            'type': 'consistency',
            'icon': '🔥',
            'title': 'Practice Consistency',
            'metric': f'{student_data.days_practiced}/7 days',
            'details': f"You showed up {student_data.days_practiced} days this week.",
            'streak': {
                'current': student_data.current_streak,
                'best_this_month': student_data.best_streak_this_month
            },
            'insight': "Building this daily habit is how you'll reach your JEE goals."
        })
    
    # WIN TYPE 4: Milestones
    milestones = check_milestones(student_data)
    if milestones:
        wins.append({
            'rank': len(wins) + 1,
            'type': 'milestone',
            'icon': '🏆',
            'title': 'Milestone Unlocked!',
            'achievements': milestones
        })
    
    # WIN TYPE 5: Hard Questions (2+ correct with IRT > 2.0)
    hard_correct = [q for q in student_data.questions 
                    if q.is_correct and q.difficulty_irt > 2.0]
    if len(hard_correct) >= 2:
        wins.append({
            'rank': len(wins) + 1,
            'type': 'tough_questions',
            'icon': '⚡',
            'title': 'Tough Questions Mastered',
            'count': len(hard_correct),
            'insight': f"You got {len(hard_correct)} advanced questions right - only top 30% manage this!"
        })
    
    # WIN TYPE 6: Recovery Pattern
    if detect_recovery_pattern(student_data.daily_accuracy):
        wins.append({
            'rank': len(wins) + 1,
            'type': 'recovery',
            'icon': '💪',
            'title': 'Strong Recovery',
            'pattern': student_data.daily_accuracy,
            'insight': "This resilience separates JEE qualifiers from others!"
        })
    
    # FALLBACK: If no wins detected (rare), create encouragement win
    if len(wins) == 0:
        wins.append({
            'rank': 1,
            'type': 'effort',
            'icon': '💪',
            'title': 'You Showed Up',
            'metric': f'{student_data.total_questions} questions',
            'insight': "Consistency beats perfection. You're building the habit!"
        })
    
    # Return top 2-3 wins
    return wins[:3]
```

### 4.2 Issue Detection Algorithm

```python
def identify_top_3_issues(incorrect_questions):
    """
    Identify top 3 issues using ROI-based prioritization.
    """
    all_patterns = []
    
    # PATTERN GROUP 1: Chapter Clusters
    # Group mistakes by related chapters (e.g., all mechanics chapters)
    chapter_clusters = group_by_related_chapters(incorrect_questions)
    for cluster in chapter_clusters:
        if len(cluster.questions) >= 2:  # Min 2 mistakes
            all_patterns.append({
                'type': 'chapter_cluster',
                'title': f"{cluster.subject} {cluster.concept_group}",
                'frequency': len(cluster.questions),
                'questions': cluster.questions,
                'affected_chapters': cluster.chapters,
                'fix_difficulty': estimate_difficulty(cluster)
            })
    
    # PATTERN GROUP 2: Concept Gaps
    # Group by specific concepts tested
    concept_groups = group_by_concepts_tested(incorrect_questions)
    for concept, questions in concept_groups.items():
        if len(questions) >= 2:
            all_patterns.append({
                'type': 'concept_gap',
                'title': concept,
                'frequency': len(questions),
                'questions': questions,
                'fix_difficulty': 'medium'
            })
    
    # PATTERN GROUP 3: Error Types (from distractor_analysis)
    # Group by common mistake types
    error_groups = group_by_error_type(incorrect_questions)
    for error_type, questions in error_groups.items():
        if len(questions) >= 3:  # Higher threshold for error patterns
            all_patterns.append({
                'type': 'error_pattern',
                'title': error_type,
                'frequency': len(questions),
                'questions': questions,
                'fix_difficulty': 'easy'
            })
    
    # CALCULATE ROI SCORE FOR EACH PATTERN
    for pattern in all_patterns:
        pattern['roi_score'] = calculate_roi_score(pattern)
        pattern['percentage'] = (pattern['frequency'] / len(incorrect_questions)) * 100
        pattern['potential_gain'] = estimate_improvement(pattern)
    
    # SORT BY ROI AND RETURN TOP 3
    all_patterns.sort(key=lambda p: p['roi_score'], reverse=True)
    return all_patterns[:3]


def calculate_roi_score(pattern):
    """
    Calculate ROI score: Higher = Higher Priority
    
    Formula: 
    ROI = (frequency * 0.4) + (impact * 0.3) + (ease_of_fix * 0.3)
    """
    total_mistakes = get_total_mistakes()  # From context
    
    # Frequency score (0-1): How common is this pattern?
    frequency_score = min(pattern['frequency'] / total_mistakes, 1.0)
    
    # Impact score (0-1): How much improvement if fixed?
    expected_improvement = estimate_improvement(pattern)
    impact_score = min(expected_improvement / 20, 1.0)
    
    # Difficulty score (0-1): How easy to fix? (easier = higher score)
    difficulty_map = {
        'easy': 1.0,    # Quick wins
        'medium': 0.7,  # Moderate effort
        'hard': 0.4     # Long-term work
    }
    difficulty_score = difficulty_map.get(pattern['fix_difficulty'], 0.5)
    
    # Weighted combination
    roi_score = (
        frequency_score * 0.4 +
        impact_score * 0.3 +
        difficulty_score * 0.3
    )
    
    return roi_score


def estimate_improvement(pattern):
    """
    Estimate % accuracy improvement if pattern is fixed.
    """
    total_questions = get_total_questions()
    mistakes_in_pattern = pattern['frequency']
    
    # If student fixes all mistakes in this pattern
    potential_improvement = (mistakes_in_pattern / total_questions) * 100
    
    # Conservative estimate (assume 70% success rate in fixing)
    return potential_improvement * 0.7
```

### 4.3 Priority Assignment Logic

```python
def assign_priority_labels(issues):
    """
    Assign priority labels to top 3 issues.
    """
    if len(issues) == 0:
        return []
    
    # Issue 1: Always highest priority
    issues[0]['priority'] = 'highest'
    issues[0]['icon'] = '🥇'
    
    if len(issues) >= 2:
        # Issue 2: Medium priority
        issues[1]['priority'] = 'medium'
        issues[1]['icon'] = '🥈'
    
    if len(issues) >= 3:
        # Issue 3: Low priority (but still worth fixing)
        issues[2]['priority'] = 'low'
        issues[2]['icon'] = '🥉'
    
    return issues
```

### 4.4 Content Generation for Issues

```python
def generate_issue_content(issue, student_data):
    """
    Generate the detailed content for each issue.
    """
    return {
        'rank': issue['rank'],
        'priority': issue['priority'],
        'icon': issue['icon'],
        'title': issue['title'],
        'frequency': issue['frequency'],
        'percentage': round(issue['percentage'], 1),
        'potential_gain': round(issue['potential_gain'], 1),
        
        # What's wrong section
        'what_wrong': generate_what_wrong(issue),
        
        # Root cause section
        'root_cause': generate_root_cause(issue, student_data),
        
        # What to study section
        'what_to_study': generate_study_topics(issue),
        
        # Suggested practice section
        'suggested_practice': generate_practice_suggestion(issue),
        
        # Affected chapters
        'affected_chapters': format_affected_chapters(issue)
    }


def generate_what_wrong(issue):
    """
    Describe what's wrong in student-friendly language.
    """
    if issue['type'] == 'chapter_cluster':
        chapters = ', '.join(issue['affected_chapters'][:3])
        return f"You got {issue['frequency']} questions wrong across {chapters}."
    
    elif issue['type'] == 'concept_gap':
        return f"You struggled with {issue['title']} across {len(issue['affected_chapters'])} chapters."
    
    elif issue['type'] == 'error_pattern':
        return f"You made {issue['title']} errors {issue['frequency']} times."


def generate_root_cause(issue, student_data):
    """
    Explain WHY this pattern is happening.
    Use contrast with strong areas to give insight.
    """
    # Find student's strongest subject for contrast
    strong_subject = max(student_data.subjects.items(), 
                        key=lambda x: x[1]['accuracy'])
    
    if issue['type'] == 'chapter_cluster':
        return f"Missing fundamental {issue['concept_group']} concepts. Your {strong_subject[0]} score ({strong_subject[1]['accuracy']}%) proves you can solve problems - you just need to build {issue['subject']} foundations."
    
    elif issue['type'] == 'concept_gap':
        return f"You know the basics, but struggle applying {issue['title']} to different problem types."
    
    elif issue['type'] == 'error_pattern':
        return f"Systematic error in {issue['title']} - this is a skill gap, not knowledge gap."


def generate_study_topics(issue):
    """
    Generate 3-4 specific study topics.
    """
    topics = []
    
    # Extract from concepts_tested in the questions
    all_concepts = []
    for q in issue['questions']:
        all_concepts.extend(q.get('concepts_tested', []))
    
    # Get most frequent concepts
    concept_freq = Counter(all_concepts)
    top_concepts = concept_freq.most_common(4)
    
    for concept, freq in top_concepts:
        # Get prerequisite or related guidance
        guidance = get_study_guidance_for_concept(concept)
        topics.append(f"{concept} - {guidance}")
    
    return topics


def generate_practice_suggestion(issue):
    """
    Suggest specific practice with quantity.
    """
    difficulty_map = {
        'easy': '10-12 problems',
        'medium': '15-20 problems',
        'hard': '8-10 multi-step problems'
    }
    
    num_problems = difficulty_map.get(issue['fix_difficulty'], '12-15 problems')
    
    if issue['type'] == 'chapter_cluster':
        return f"{num_problems} on {issue['concept_group']} fundamentals, then retry JEEVibe chapter practice on {issue['affected_chapters'][0]}."
    
    elif issue['type'] == 'concept_gap':
        return f"{num_problems} specifically on {issue['title']} applications across different scenarios."
    
    elif issue['type'] == 'error_pattern':
        return f"Practice {num_problems} with focus on {issue['title']} - check your work at each step."
```

### 4.5 Adaptive Content by Student Level

```python
def adapt_content_to_student_level(student_data, content):
    """
    Adjust tone and messaging based on student performance.
    """
    overall_accuracy = student_data['accuracy']
    
    if overall_accuracy >= 75:
        # High performer
        content['greeting'] = "Excellent week of practice!"
        content['tone'] = "challenging"
        content['encouragement_level'] = "moderate"
        
    elif overall_accuracy >= 55:
        # Average performer
        content['greeting'] = "Great week of practice!"
        content['tone'] = "balanced"
        content['encouragement_level'] = "high"
        
    else:
        # Struggling student
        content['greeting'] = "Good effort this week!"
        content['tone'] = "supportive"
        content['encouragement_level'] = "very_high"
        
        # Add extra encouragement
        content['extra_message'] = "Every question you practice is progress. Keep showing up!"
    
    return content
```

---

## 5. Report Examples

### 5.1 Example 1: Average Student (52% accuracy - Janhvi)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
JEEVIBE WEEKLY REPORT
Week of February 3-9, 2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

👩‍🏫 Hi Janhvi,

Great week of practice! You completed 60 questions and 
I found some clear wins and areas to focus on.

Let me show you what's working and where to improve.

- Priya Ma'am

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 YOUR WINS THIS WEEK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ Chemistry Mastery (68% accuracy)
You're crushing Chemistry! 13 out of 19 questions correct.

Top chapters:
• Chemical Bonding: 100% (1/1)
• General Organic Chemistry: 100% (3/3)
• Coordination Compounds: 100% (1/1)

What this means: Your conceptual understanding and 
problem-solving skills are strong. This is your superpower!

─────────────────────────────────────────────────────────────

📈 Visible Improvement (+17% from assessment)
Assessment (Feb 3):  43% ████████░░░░░░░░░░
Daily Quizzes:       60% ████████████░░░░░░

You improved 17% in just 2 days! This shows consistent 
practice is working. Keep this momentum.

─────────────────────────────────────────────────────────────

🔥 Practice Consistency (3/7 days)
You showed up 3 days this week. Building this daily 
habit is how you'll reach your JEE goals.

Current streak: 2 days
Best this month: 3 days

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 OVERALL PERFORMANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

60 questions | 52% accuracy (31 correct, 29 incorrect)

By Subject:
• Chemistry: 68% ✓ (13/19) — Your strength
• Mathematics: 47% (9/19) — Needs attention
• Physics: 41% ⚠️ (9/22) — Priority focus area

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 YOUR TOP 3 ISSUES TO FIX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Fix these in priority order for maximum improvement:

─────────────────────────────────────────────────────────────
🥇 PRIORITY 1: Physics Mechanics Fundamentals

Impact: 8 out of 29 mistakes (28%)
Potential gain: +15% accuracy

What's wrong:
You got 0 out of 8 mechanics questions correct across 
Electrostatics (0/2), Laws of Motion (0/2), Rotational 
Motion (0/1), and Work-Energy (0/1).

Root cause:
Missing fundamental force analysis skills. Your 68% 
Chemistry score proves you can solve problems well - 
you just need to build mechanics foundations.

What to study:
• Newton's Laws - when to apply each law
• Free Body Diagrams - identifying all forces
• Force Analysis - choosing Coulomb vs Gauss's Law
• Multi-Body Systems - constraint forces

Suggested practice:
15-20 problems on force analysis and free body diagrams, 
then retry JEEVibe chapter practice on Laws of Motion.

─────────────────────────────────────────────────────────────
🥈 PRIORITY 2: Calculus Applications

Impact: 4 out of 29 mistakes (14%)
Potential gain: +8% accuracy

What's wrong:
You got 0 out of 4 calculus application problems correct 
in Differential Calculus (0/2) and Limits & Continuity (0/1).

Root cause:
You know derivative rules, but struggle applying them to 
word problems - rate of change, optimization, tangent/normal.

What to study:
• Derivative Interpretation - connecting formula to meaning
• Rate of Change - setting up equations from word problems
• Optimization - identifying constraints, critical points
• Problem-Type Recognition - max/min vs rate vs tangent

Suggested practice:
10-15 word problems on derivative applications, focusing 
on translating English to math.

─────────────────────────────────────────────────────────────
🥉 PRIORITY 3: Advanced Problem-Solving

Impact: 3 out of 29 mistakes (10%)
Potential gain: +5% accuracy

What's wrong:
Single difficult questions in Probability (0/1), Chemical 
Kinetics (0/1), Equilibrium (0/1).

Root cause:
These are harder questions requiring multiple concepts. 
Likely difficulty-related rather than specific concept gaps.

What to study:
• Probability - conditional probability, combinations
• Chemical Kinetics - rate laws, reaction order
• Equilibrium - Le Chatelier's principle, Kc/Kp

Suggested practice:
Work through 8-10 multi-step problems in these topics. 
These will get easier as you strengthen fundamentals 
from Priority 1 and 2.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 HOW TO USE THIS REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You have 3 options:

Option 1: Fix Priority 1 first (recommended)
Focus all your study time on Physics Mechanics until 
you see improvement, then move to Priority 2.

Option 2: Work on all 3 simultaneously
Spend 60% time on Priority 1, 25% on Priority 2, 
15% on Priority 3.

Option 3: Pick what feels right
You know your strengths. Start where you feel most 
motivated or where you have upcoming tests.

No matter which approach you choose, these 3 areas 
give you the clearest path to improvement.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 POTENTIAL IMPROVEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

If you address these 3 issues:

Current accuracy:     52% ████████████░░░░░░░░
Potential accuracy:   80% ████████████████████

This would put you in the top 15% of JEEVibe students.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Three priorities. Your timeline. Real improvement.

[Start Today's Quiz] [Practice Physics] [View Dashboard]

Questions? Reply anytime.
- Priya Ma'am

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

JEEVibe - Honest EdTech for JEE Preparation
support@jeevibe.app | jeevibe.app

Update preferences | Unsubscribe
```

### 5.2 Example 2: High Performer (78% accuracy)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
JEEVIBE WEEKLY REPORT
Week of February 3-9, 2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

👩‍🏫 Hi Arjun,

Excellent week of practice! You completed 85 questions 
and I found some impressive wins and a few areas to 
polish for even better results.

- Priya Ma'am

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 YOUR WINS THIS WEEK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏆 Outstanding Performance (78% accuracy)
You're in the top 12% of JEEVibe students!

Perfect chapters this week:
• Electrostatics: 6/6 (100%)
• Chemical Bonding: 5/5 (100%)
• Parabola: 4/4 (100%)
• Rotational Motion: 3/3 (100%)

You mastered 4 chapters this week - exceptional work!

─────────────────────────────────────────────────────────────

⚡ Advanced Questions Mastered
You got 8 hard-level questions correct this week (IRT > 2.0).

These are questions that only top 20% of students get 
right. You're ready for JEE Main advanced difficulty.

─────────────────────────────────────────────────────────────

🔥 Perfect Week Streak (7/7 days)
You practiced every single day this week!

This consistency is what separates JEE qualifiers from 
the rest. Keep this discipline.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 OVERALL PERFORMANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

85 questions | 78% accuracy (66 correct, 19 incorrect)

By Subject:
• Physics: 82% ✓ (28/34) — Excellent
• Chemistry: 80% ✓ (24/30) — Excellent
• Mathematics: 67% (14/21) — Room for improvement

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 YOUR TOP 3 ISSUES TO FIX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Even at 78%, there's room to reach 85%+ by fixing these:

─────────────────────────────────────────────────────────────
🥇 PRIORITY 1: Coordinate Geometry - Difficult Problems

Impact: 5 out of 19 mistakes (26%)
Potential gain: +5% accuracy

What's wrong:
You struggled with advanced coordinate geometry problems 
in Circles (1/3) and Parabola variants (1/2).

Root cause:
You're getting conceptual questions right but making 
calculation errors in multi-step coordinate problems.

What to study:
• Multi-variable substitution techniques
• Distance formula applications in complex scenarios
• Parametric equation manipulation
• Avoiding sign errors in coordinate transformations

Suggested practice:
10-12 JEE Advanced level coordinate geometry problems 
with focus on accuracy in multi-step calculations.

─────────────────────────────────────────────────────────────
🥈 PRIORITY 2: Time Management Under Pressure

Impact: 4 out of 19 mistakes (21%)
Potential gain: +4% accuracy

What's wrong:
You're getting questions wrong that you should get right. 
Analysis shows these are in topics where you have 80%+ 
accuracy otherwise.

Root cause:
Speed-induced errors. You solved these in <60 seconds 
when they needed 90-120 seconds for accuracy.

What to study:
• Identifying high-value questions (spend more time)
• Double-checking final answers in calculation-heavy problems
• Strategic time allocation in practice

Suggested practice:
Take 2-3 timed chapter practices this week. Track which 
question types take you longest and budget time accordingly.

─────────────────────────────────────────────────────────────
🥉 PRIORITY 3: Organic Reaction Mechanisms

Impact: 3 out of 19 mistakes (16%)
Potential gain: +3% accuracy

What's wrong:
Missed 3 questions on reaction mechanism prediction and 
product identification.

Root cause:
You know individual reactions but struggle with multi-step 
mechanisms and choosing between competing pathways.

What to study:
• Reagent-based mechanism prediction
• Stability-based product prediction
• Competing mechanism identification

Suggested practice:
8-10 mechanism problems focusing on "why this pathway, 
not that one" reasoning.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 HOW TO USE THIS REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

At your level, focus on eliminating careless mistakes:

Option 1: Polish Priority 1 first
Master coordinate geometry calculations - this alone 
gets you to 83%.

Option 2: Time management focus
Fix Priority 2 (speed errors) - this could impact 
all subjects positively.

Option 3: Work all 3 in parallel
You have the discipline for it.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 POTENTIAL IMPROVEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

If you address these 3 issues:

Current accuracy:     78% ███████████████░░░░░
Potential accuracy:   90% ██████████████████░░

This would put you in the top 5% of JEE aspirants 
nationally - that's AIR <10,000 territory.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You're already strong. Let's make you unstoppable.

[Start Advanced Quiz] [Practice Coordinate Geometry]

- Priya Ma'am
```

### 5.3 Example 3: Struggling Student (38% accuracy)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
JEEVIBE WEEKLY REPORT
Week of February 3-9, 2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

👩‍🏫 Hi Priya,

Good effort this week! You completed 45 questions and 
showed up to practice. That takes commitment.

Let me show you what's working and where small changes 
can make big improvements.

- Priya Ma'am

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 YOUR WINS THIS WEEK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💪 You Showed Up (45 questions, 4 days practice)
You practiced 4 days this week and completed 45 questions. 
That's building the habit!

Every question you practice is progress. Consistency 
beats perfection every time.

─────────────────────────────────────────────────────────────

📈 Chemistry Improvement (30% → 45%)
Your Chemistry accuracy jumped 15% this week!

Best chapter:
• Basic Concepts: 4/5 correct (80%)

This shows you CAN improve with focused practice.

─────────────────────────────────────────────────────────────

🎯 Daily Improvement Trend
Your scores improved each practice day:
Mon: 30% → Wed: 35% → Fri: 45%

This upward trend is exactly what we want to see!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 OVERALL PERFORMANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

45 questions | 38% accuracy (17 correct, 28 incorrect)

By Subject:
• Chemistry: 45% (7/16) — Improving!
• Mathematics: 35% (5/14) — Needs work
• Physics: 33% (5/15) — Focus area

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 YOUR TOP 3 ISSUES TO FIX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Let's focus on foundations first:

─────────────────────────────────────────────────────────────
🥇 PRIORITY 1: Basic Formula Application

Impact: 12 out of 28 mistakes (43%)
Potential gain: +20% accuracy

What's wrong:
You're struggling to apply formulas correctly across 
multiple chapters - not remembering which formula applies 
when, or making substitution errors.

Root cause:
Formula memorization and application needs work. This 
isn't about problem-solving yet - first we need to get 
comfortable with the basic formulas.

What to study:
• Create formula flashcards for each chapter
• Practice identifying "which formula for which problem type"
• Work through formula sheet systematically
• Master substitution (putting numbers into formulas correctly)

Suggested practice:
Start with 5-8 EASY problems per chapter. Focus on getting 
the formula RIGHT before worrying about speed. Quality 
over quantity this week.

─────────────────────────────────────────────────────────────
🥈 PRIORITY 2: Reading Questions Carefully

Impact: 6 out of 28 mistakes (21%)
Potential gain: +12% accuracy

What's wrong:
You're missing key information in question stems - using 
wrong units, missing negative signs, not reading "which 
of the following is FALSE" type questions.

Root cause:
Reading too quickly. Understandable when you're nervous 
about time, but accuracy comes first.

What to study:
• Underline key words in question (NOT, FALSE, EXCEPT)
• Circle all given values and their units
• Read question twice before starting
• Check: "What am I being asked?"

Suggested practice:
On your next 10 questions, spend 30 seconds just READING 
the question before attempting. Notice how this changes 
your accuracy.

─────────────────────────────────────────────────────────────
🥉 PRIORITY 3: Mathematics Fundamentals

Impact: 5 out of 28 mistakes (18%)
Potential gain: +8% accuracy

What's wrong:
Basic algebra and arithmetic errors in Physics and 
Chemistry calculations.

Root cause:
Calculation speed and accuracy needs practice. This 
gets better with time!

What to study:
• Practice mental math daily (5 mins)
• Use scratch paper for all calculations
• Double-check arithmetic in final answers
• Review basic algebra rules

Suggested practice:
Work 8-10 calculation-heavy problems with focus on 
getting math RIGHT, not fast.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 HOW TO USE THIS REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

My recommendation: Start with Priority 1 only

Focus all your energy on formula application this week. 
Get comfortable with the basics before adding more.

This isn't about doing 100 problems. It's about doing 
30-40 problems CORRECTLY.

When you see your accuracy jump to 50%+, then we'll 
tackle Priority 2 and 3.

Small, steady progress builds confidence!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 POTENTIAL IMPROVEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

If you fix just Priority 1:

Current accuracy:     38% ████████░░░░░░░░░░░░
Potential accuracy:   58% ████████████░░░░░░░░

That's a 20% jump! This is absolutely achievable.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You're on the right path. Keep showing up every day.

[Start Easy Practice] [Review Formulas] [Daily Quiz]

I believe in you!
- Priya Ma'am
```

---

## 6. Technical Implementation

### 6.1 Report Generation Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. TRIGGER (Sunday 7 PM IST)                           │
│    Cron job or scheduled function                       │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 2. FETCH USER DATA                                      │
│    - Get all users who practiced this week              │
│    - Filter: 40+ questions in last 7 days               │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 3. FETCH QUESTION RESPONSES                             │
│    - Get last 7 days of responses                       │
│    - Include: assessment, daily quiz, chapter practice  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 4. ENRICH WITH METADATA                                 │
│    - Join with question bank on question_id             │
│    - Add: sub_topics, concepts_tested,                  │
│           distractor_analysis, metadata                 │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 5. COMPUTE ANALYTICS                                    │
│    - Calculate accuracy by subject/chapter              │
│    - Detect wins (mastery, improvement, consistency)    │
│    - Identify top 3 issues (ROI-based)                  │
│    - Generate study recommendations                     │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 6. GENERATE REPORT CONTENT                              │
│    - Adapt tone to student level                        │
│    - Format wins section (2-3 wins)                     │
│    - Format issues section (top 3)                      │
│    - Generate personalized messaging                    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 7. SEND EMAIL                                           │
│    - Subject: "Your JEEVibe Weekly Report - [Date]"     │
│    - From: Priya Ma'am <reports@jeevibe.app>            │
│    - Plain text + HTML version                          │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 8. LOG & TRACK                                          │
│    - Store generated report in Firestore                │
│    - Track: sent, opened, clicked                       │
│    - Monitor: bounce rate, unsubscribes                 │
└─────────────────────────────────────────────────────────┘
```

### 6.2 Firebase Structure

```javascript
// Firestore collections

// User responses (already exists)
/users/{userId}/responses/{responseId}
{
  question_id: "PHY_ELEC_001",
  user_answer: "B",              // ⭐ ADD THIS
  correct_answer: "C",
  is_correct: false,
  subject: "Physics",
  chapter: "Electrostatics",
  time_spent_seconds: 127,
  answered_at: Timestamp,
  source: "daily_quiz"
}

// Weekly reports (new collection)
/users/{userId}/weekly_reports/{weekId}
{
  week_start: "2026-02-03",
  week_end: "2026-02-09",
  generated_at: Timestamp,
  
  summary: {
    total_questions: 60,
    accuracy: 51.7,
    days_practiced: 3
  },
  
  wins: [...],
  issues: [...],
  
  email_sent: true,
  email_sent_at: Timestamp,
  email_opened: false,
  email_clicked: false
}
```

### 6.3 Cloud Function Pseudocode

```javascript
// Cloud Function: Generate Weekly Reports
exports.generateWeeklyReports = functions.pubsub
  .schedule('0 19 * * 0')  // Every Sunday 7 PM IST
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    
    // 1. Get eligible users
    const eligibleUsers = await getEligibleUsers();
    
    for (const user of eligibleUsers) {
      try {
        // 2. Fetch user's weekly data
        const weekData = await fetchWeekData(user.id);
        
        // Skip if insufficient data
        if (weekData.total_questions < 40) {
          console.log(`Skipping ${user.id}: insufficient data`);
          continue;
        }
        
        // 3. Enrich with question metadata
        const enrichedData = await enrichWithMetadata(weekData);
        
        // 4. Generate report
        const report = await generateReport(user, enrichedData);
        
        // 5. Send email
        await sendReportEmail(user, report);
        
        // 6. Store report
        await storeReport(user.id, report);
        
        console.log(`Report sent to ${user.email}`);
        
      } catch (error) {
        console.error(`Error for user ${user.id}:`, error);
      }
    }
  });


async function fetchWeekData(userId) {
  const weekStart = getWeekStart();  // Last Sunday
  const weekEnd = getWeekEnd();      // This Sunday
  
  const responsesSnapshot = await db
    .collection('users').doc(userId)
    .collection('responses')
    .where('answered_at', '>=', weekStart)
    .where('answered_at', '<=', weekEnd)
    .get();
  
  return {
    user_id: userId,
    week_start: weekStart,
    week_end: weekEnd,
    questions: responsesSnapshot.docs.map(doc => doc.data())
  };
}


async function enrichWithMetadata(weekData) {
  const enrichedQuestions = await Promise.all(
    weekData.questions.map(async (response) => {
      // Fetch question from question bank
      const questionDoc = await db
        .collection('questions')
        .doc(response.question_id)
        .get();
      
      if (!questionDoc.exists) {
        console.warn(`Question not found: ${response.question_id}`);
        return response;
      }
      
      const question = questionDoc.data();
      
      return {
        ...response,
        sub_topics: question.sub_topics,
        concepts_tested: question.concepts_tested,
        difficulty_irt: question.difficulty_irt,
        distractor_analysis: question.distractor_analysis,
        metadata: question.metadata
      };
    })
  );
  
  return {
    ...weekData,
    questions: enrichedQuestions
  };
}


async function generateReport(user, enrichedData) {
  // Compute analytics
  const analytics = computeAnalytics(enrichedData);
  
  // Generate wins
  const wins = generateWins(user, analytics);
  
  // Identify top 3 issues
  const issues = identifyTop3Issues(enrichedData.questions.filter(q => !q.is_correct));
  
  // Adapt content to student level
  const content = adaptContentToLevel(user, analytics);
  
  // Format report
  const report = {
    user_id: user.id,
    week_start: enrichedData.week_start,
    week_end: enrichedData.week_end,
    generated_at: new Date(),
    
    summary: analytics.summary,
    wins: wins,
    issues: issues,
    
    content: content,
    
    email_subject: `Your JEEVibe Weekly Report - ${formatDateRange(enrichedData.week_start, enrichedData.week_end)}`,
    email_body: formatEmailBody(user, wins, issues, analytics)
  };
  
  return report;
}


async function sendReportEmail(user, report) {
  const emailData = {
    to: user.email,
    from: {
      email: 'reports@jeevibe.app',
      name: 'Priya Ma\'am - JEEVibe'
    },
    subject: report.email_subject,
    text: report.email_body,  // Plain text version
    html: formatEmailHTML(report.email_body),  // HTML version
    
    // For tracking
    custom_args: {
      user_id: user.id,
      report_type: 'weekly_mpa',
      week_start: report.week_start
    }
  };
  
  await sendgrid.send(emailData);
}
```

### 6.4 Question Bank Query Optimization

```javascript
// Pre-compute and cache question metadata for fast joins

// Option 1: Store metadata in response at submission time
async function submitAnswer(userId, questionId, userAnswer) {
  // Fetch question once
  const question = await getQuestionById(questionId);
  
  // Store response with embedded metadata
  await db.collection('users').doc(userId)
    .collection('responses').add({
      question_id: questionId,
      user_answer: userAnswer,
      correct_answer: question.correct_answer,
      is_correct: userAnswer === question.correct_answer,
      
      // Embed key metadata to avoid future joins
      subject: question.subject,
      chapter: question.chapter,
      sub_topics: question.sub_topics,
      difficulty_irt: question.difficulty_irt,
      
      answered_at: new Date(),
      source: 'daily_quiz'
    });
}

// Option 2: Batch fetch during report generation
async function batchFetchQuestionMetadata(questionIds) {
  // Use Firestore 'in' query (max 10 at a time)
  const batches = chunk(questionIds, 10);
  const results = [];
  
  for (const batch of batches) {
    const snapshot = await db.collection('questions')
      .where(firebase.firestore.FieldPath.documentId(), 'in', batch)
      .get();
    
    results.push(...snapshot.docs.map(doc => ({
      question_id: doc.id,
      ...doc.data()
    })));
  }
  
  // Create lookup map
  return results.reduce((map, q) => {
    map[q.question_id] = q;
    return map;
  }, {});
}
```

---

## 7. Delivery Mechanism

### 7.1 Email Configuration

```javascript
// Email metadata
{
  from: {
    email: 'reports@jeevibe.app',
    name: 'Priya Ma\'am'
  },
  reply_to: 'support@jeevibe.app',
  
  subject: 'Your JEEVibe Weekly Report - [Week of Date]',
  
  preview_text: 'Great progress this week! Here are your wins and top 3 issues to fix...',
  
  // Tracking
  track_opens: true,
  track_clicks: true,
  
  // Unsubscribe
  unsubscribe_group: 'weekly_reports',
  
  // Categories for analytics
  categories: ['weekly_report', 'mpa', 'student_communication']
}
```

### 7.2 Send Time Optimization

**Recommended:** Sunday 7 PM IST

**Why:**
- Students winding down weekend
- Planning week ahead
- Not during study hours (morning/afternoon)
- Not too late (still awake and engaged)

**A/B test alternatives:**
- Sunday 8 AM (fresh start to day)
- Monday 6 AM (fresh start to week)

### 7.3 Subject Line Variations (A/B Test)

**Variant A (Personal):**
`Your JEEVibe Report - You improved 17% this week! 🎉`

**Variant B (Curiosity):**
`Janhvi, I found 3 patterns in your practice...`

**Variant C (Direct):**
`Your Weekly Report - Feb 3-9, 2026`

**Variant D (Action):**
`Fix these 3 issues → Jump to 70% accuracy`

### 7.4 Email Deliverability

```javascript
// SPF, DKIM, DMARC setup required
{
  SPF: 'v=spf1 include:sendgrid.net ~all',
  DKIM: 'enabled',
  DMARC: 'v=DMARC1; p=quarantine; rua=mailto:dmarc@jeevibe.app'
}

// Content guidelines for high deliverability
{
  text_to_image_ratio: '60:40',  // More text than images
  spam_trigger_words: 'avoid',    // No "free", "guaranteed", etc.
  unsubscribe_link: 'visible',    // Clear and easy
  authentication: 'passed'        // SPF/DKIM/DMARC
}
```

---

## 8. Success Metrics

### 8.1 Email Performance Metrics

```javascript
// Track these metrics for each weekly report

const metrics = {
  // Delivery metrics
  sent: 0,
  delivered: 0,
  bounced: 0,
  delivery_rate: 0,  // Target: >98%
  
  // Engagement metrics
  opened: 0,
  open_rate: 0,      // Target: >40%
  clicked: 0,
  click_rate: 0,     // Target: >15%
  replied: 0,
  reply_rate: 0,     // Target: >5%
  
  // Negative metrics
  unsubscribed: 0,
  unsubscribe_rate: 0,  // Target: <1%
  spam_complaints: 0,    // Target: <0.1%
  
  // Time metrics
  avg_time_to_open: 0,   // How long until they open
  avg_read_time: 0       // How long they spend reading
};
```

### 8.2 Student Behavior Metrics

```javascript
// Track student behavior after receiving report

const behaviorMetrics = {
  // Immediate actions (within 24 hours)
  started_daily_quiz: 0,
  practiced_priority_chapter: 0,
  visited_dashboard: 0,
  
  // Week-ahead behavior (7 days after report)
  daily_quiz_completion: 0,      // Target: +20% vs baseline
  chapter_practice_attempts: 0,   // Target: +30% on priority chapters
  overall_accuracy_improvement: 0, // Target: +5-10%
  
  // Retention
  retention_7_day: 0,    // Still active after 7 days
  retention_14_day: 0,   // Still active after 14 days
  
  // Engagement with specific priorities
  practiced_priority_1: 0,  // % who practiced Priority 1 issue
  practiced_priority_2: 0,
  practiced_priority_3: 0
};
```

### 8.3 Learning Impact Metrics

```javascript
// Measure actual learning improvement

const learningMetrics = {
  // Accuracy improvement
  week_1_accuracy: 52,
  week_2_accuracy: 60,
  improvement: 8,       // Target: +5-10% per week
  
  // Priority issue resolution
  priority_1_accuracy_before: 0,
  priority_1_accuracy_after: 0,
  priority_1_improvement: 0,  // Target: +15%
  
  priority_2_accuracy_before: 0,
  priority_2_accuracy_after: 0,
  priority_2_improvement: 0,  // Target: +8%
  
  priority_3_accuracy_before: 0,
  priority_3_accuracy_after: 0,
  priority_3_improvement: 0,  // Target: +5%
  
  // Overall trajectory
  students_improving: 0,      // % showing improvement
  students_stagnant: 0,       // % staying same
  students_declining: 0       // % getting worse
};
```

### 8.4 Dashboard for Monitoring

```javascript
// Real-time dashboard showing:

const dashboard = {
  reports_sent_this_week: 1247,
  avg_open_rate: 42.3,
  avg_click_rate: 18.7,
  avg_accuracy_improvement: 7.2,
  
  // Segment performance
  segments: {
    high_performers: {
      count: 187,
      open_rate: 38.2,  // Lower (already confident)
      improvement: 4.1   // Smaller gains
    },
    average_performers: {
      count: 856,
      open_rate: 44.1,  // Higher (need guidance)
      improvement: 8.3   // Bigger gains
    },
    struggling_students: {
      count: 204,
      open_rate: 47.8,  // Highest (desperate for help)
      improvement: 12.4  // Largest gains
    }
  },
  
  // Top performing issues (which ones students fix most)
  top_fixed_issues: [
    { issue: 'Formula Application', fix_rate: 68 },
    { issue: 'Calculus Applications', fix_rate: 54 },
    { issue: 'Reading Carefully', fix_rate: 71 }
  ]
};
```

### 8.5 Success Criteria

```javascript
// Report is successful if:

const successCriteria = {
  // Engagement
  open_rate: '>40%',
  click_rate: '>15%',
  reply_rate: '>5%',
  
  // Student behavior
  next_day_practice: '>60%',  // Practice within 24 hours
  priority_chapter_practice: '>40%',  // Practice priority 1 issue
  
  // Learning outcomes
  avg_improvement: '>5%',  // Week-over-week accuracy
  students_improving: '>70%',  // Majority show improvement
  
  // Retention
  retention_7_day: '>75%',
  retention_30_day: '>60%',
  
  // Negative metrics
  unsubscribe_rate: '<1%',
  spam_rate: '<0.1%'
};
```

---

## 9. Implementation Checklist

### Phase 1: Data Foundation (Week 1)
- [ ] Add `user_answer` field to response logging
- [ ] Update answer submission code to store `user_answer`
- [ ] Test on dev environment with sample data
- [ ] Verify data is being stored correctly

### Phase 2: Metadata Join (Week 1-2)
- [ ] Create question bank join function
- [ ] Test metadata enrichment with sample questions
- [ ] Optimize for batch queries (10 questions at a time)
- [ ] Add error handling for missing questions

### Phase 3: Analytics Engine (Week 2-3)
- [ ] Implement wins detection algorithm
- [ ] Implement issue detection algorithm
- [ ] Implement ROI scoring
- [ ] Test with real student data (Janhvi's 60 questions)

### Phase 4: Content Generation (Week 3-4)
- [ ] Build report template system
- [ ] Implement adaptive content by student level
- [ ] Create email HTML/text templates
- [ ] Test with multiple student profiles

### Phase 5: Email Infrastructure (Week 4)
- [ ] Set up SendGrid/email service
- [ ] Configure SPF, DKIM, DMARC
- [ ] Create email templates
- [ ] Set up tracking (opens, clicks)
- [ ] Implement unsubscribe handling

### Phase 6: Cloud Function (Week 4-5)
- [ ] Create scheduled Cloud Function
- [ ] Implement report generation flow
- [ ] Add error handling and logging
- [ ] Test with small user cohort (10-20 users)

### Phase 7: Testing (Week 5-6)
- [ ] Test with various student profiles
- [ ] Verify email deliverability
- [ ] Check mobile rendering
- [ ] Test unsubscribe flow
- [ ] Load test with 1000+ users

### Phase 8: Beta Launch (Week 6)
- [ ] Launch to 100 users
- [ ] Monitor metrics daily
- [ ] Collect feedback
- [ ] Fix bugs

### Phase 9: Full Launch (Week 7)
- [ ] Roll out to all active users
- [ ] Monitor at scale
- [ ] A/B test subject lines
- [ ] Optimize send times

### Phase 10: Iterate (Ongoing)
- [ ] Analyze metrics weekly
- [ ] Refine algorithms based on feedback
- [ ] Add new win types
- [ ] Improve issue detection
- [ ] Test content variations

---

## 10. Additional Notes

### 10.1 Privacy & Compliance

- Student data is private and confidential
- Reports are personalized and should not be shared publicly
- Students can opt out of weekly reports in settings
- Comply with DPDP Act (India) for data handling
- Provide clear unsubscribe option in every email

### 10.2 Localization

Currently: English only

Future: Hindi support
- Translate report templates
- Maintain same structure and logic
- Use Hindi name fields from user profile
- Test readability with target audience

### 10.3 Edge Cases

**Case 1: Student with 0 mistakes**
- Show celebration wins only
- Encourage trying harder questions
- No issues section

**Case 2: Student with 100% mistakes**
- Show effort/consistency wins
- Focus on one foundational issue
- Very supportive tone
- Suggest starting with easier questions

**Case 3: New student (first week)**
- Compare to assessment baseline only
- Focus on building habit
- Simplified report

**Case 4: Inactive student (didn't practice)**
- Send encouragement email instead of report
- Remind of streak potential
- Motivate to restart

### 10.4 Future Enhancements

**Phase 2 features (after MVP):**
- Daily micro-reports (condensed version)
- Monthly progress summaries
- Comparison to peer performance
- Historical trend charts
- Shareable report cards (social proof)
- WhatsApp report delivery
- Voice message from Priya Ma'am
- Video explanations for top issues

---

## 11. Contact & Support

**For questions about this spec:**
- **Owner:** Satish Shetty
- **Email:** satish@jeevibe.app

**Development team:**
- Backend: [Name] - Firestore, Cloud Functions
- Frontend: [Name] - Email templates, dashboard
- ML/Analytics: [Name] - Pattern detection, ROI scoring

**Timeline:**
- **Spec Review:** Feb 8, 2026
- **Dev Start:** Feb 10, 2026
- **Beta Launch:** Mar 17, 2026 (Week 6)
- **Full Launch:** Mar 24, 2026 (Week 7)

---

**End of Specification Document**

Version 1.0 | February 7, 2026
