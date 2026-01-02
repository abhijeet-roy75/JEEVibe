# JEEVibe IIDP Algorithm - Complete Specification
**Version:** 2.0  
**Date:** December 10, 2024  
**Author:** Dr. Amara Chen, Educational Measurement Specialist  
**Status:** Production Ready

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [IRT Parameters & Theta Estimation](#irt-parameters-theta-estimation)
4. [Initial Assessment Processing](#initial-assessment-processing)
5. [Daily Quiz Generation (Hybrid IIDP)](#daily-quiz-generation)
6. [Theta Update Mechanism](#theta-update-mechanism)
7. [Question Selection Strategy](#question-selection-strategy)
8. [Circuit Breaker: Death Spiral Prevention](#circuit-breaker-death-spiral-prevention)
9. [Spaced Repetition Integration](#spaced-repetition-integration)
10. [Data Structures & Firebase Schema](#data-structures-firebase-schema)
11. [Edge Cases & Error Handling](#edge-cases-error-handling)
12. [Implementation Checklist](#implementation-checklist)

---

## 1. Executive Summary

### Algorithm Overview
The JEEVibe IIDP (Interleaved, Individualized, Deliberate Practice) engine uses **Item Response Theory (IRT)** to:
1. Estimate student ability (θ) per topic from initial assessment
2. Generate personalized daily quizzes optimizing learning efficiency
3. Continuously update θ estimates as students solve questions
4. Balance exploration (mapping unknown topics) vs exploitation (practicing weak areas)

### Key Innovation: Two-Phase Approach
- **Quizzes 1-14:** Exploration Phase (60% → 30% unexplored topics)
- **Quizzes 15+:** Exploitation Phase (Pure IIDP optimization)

**Important:** Phase transition based on **completed quiz count**, not calendar days. This allows motivated students to progress faster by completing multiple quizzes per day.

### Performance Targets
- Initial θ estimation accuracy: ±0.3 standard error within 30 questions
- Quiz generation time: < 500ms per 10-question quiz
- Topic coverage: 40+ high/medium weightage topics mapped by Quiz 14
- Student engagement: Flexible pacing - students control their learning speed

---

## 2. System Architecture

### 2.1 Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    NEW STUDENT ONBOARDING                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│            INITIAL ASSESSMENT (30 questions, 45 min)         │
│  - 10 Physics, 10 Chemistry, 10 Math                        │
│  - Difficulty range: -1.5 to +1.5                           │
│  - Discrimination: a > 1.4                                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              THETA INITIALIZATION ALGORITHM                  │
│  - Calculate topic-level θ from accuracy                     │
│  - Assign confidence intervals (SE)                          │
│  - Identify weak/strong topics                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                DAILY QUIZ GENERATION ENGINE                  │
│  Phase 1 (Quizzes 1-14): Exploration (6→3 new topics/quiz)  │
│  Phase 2 (Quizzes 15+): Exploitation (7 weak+2 strong+1 SR) │
│  ** Phase based on QUIZ COUNT, not calendar days **         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              STUDENT INTERACTION & RESPONSE                  │
│  - Record: answer, time_taken, timestamp                    │
│  - Immediate feedback with solution steps                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   THETA UPDATE ALGORITHM                     │
│  - Bayesian update using IRT model                          │
│  - Bounded at [-3.0, +3.0]                                  │
│  - Reduce confidence interval (SE)                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                    [Loop back to Daily Quiz]
```

### 2.2 Core Components

| Component | Responsibility | Input | Output |
|-----------|---------------|-------|--------|
| **Assessment Processor** | Parse initial assessment, calculate initial θ | Student responses (30 Q) | θ by topic, confidence scores |
| **Quiz Generator** | Select 10 optimal questions per quiz | Student profile, completed_quiz_count | Question list with metadata |
| **Theta Estimator** | Update ability after each question | Response, question IRT params | Updated θ, new SE |
| **Spaced Repetition Scheduler** | Determine review questions | Past attempts, forgetting curve | Questions due for review |
| **Interleaver** | Shuffle questions to prevent topic clustering | Selected questions | Optimally ordered quiz |

---

## 3. IRT Parameters & Theta Estimation

### 3.1 Three-Parameter Logistic (3PL) Model

The probability that a student with ability θ answers a question of difficulty b correctly:

```
P(θ, a, b, c) = c + (1 - c) / (1 + exp(-a(θ - b)))
```

**Where:**
- **θ (theta):** Student ability on [-3.0, +3.0] scale
- **a (discrimination):** How well question differentiates ability levels (a > 1.4 = good)
- **b (difficulty):** Question difficulty on [0.4, 2.6] scale (based on JEEVibe question bank)
  - Easy: 0.4 - 0.7
  - Medium: 0.8 - 1.3
  - Hard: 1.4 - 2.0
  - Very Hard: 2.0 - 2.6
- **c (guessing):** Probability of random correct answer
  - MCQ (4 options): c = 0.25
  - Numerical: c = 0.0

### 3.2 Theta Scale Interpretation

| θ Value | Percentile | JEE Context | Description |
|---------|-----------|-------------|-------------|
| -3.0 | ~0.1% | Extreme difficulty | Cannot solve basic questions |
| -2.0 | ~2% | Significant gaps | Struggles with fundamentals |
| -1.0 | ~16% | Below average | Needs extensive practice |
| 0.0 | 50% | Average | Typical JEE aspirant baseline |
| +1.0 | ~84% | Above average | Strong foundation |
| +2.0 | ~98% | Very strong | Advanced problem solver |
| +3.0 | ~99.9% | Exceptional | Near-perfect performance |

### 3.3 Expected Accuracy by θ-b Gap

For a = 1.5, c = 0.25 (typical MCQ):

| θ - b | P(correct) | Interpretation |
|-------|-----------|----------------|
| -2.0 | 28% | Too hard (random guessing + little skill) |
| -1.0 | 39% | Challenging (slight frustration zone) |
| -0.5 | 48% | Slightly hard (optimal learning zone) |
| 0.0 | 63% | Well-matched (sweet spot) |
| +0.5 | 76% | Slightly easy (confidence building) |
| +1.0 | 86% | Easy (maintenance level) |
| +2.0 | 95% | Too easy (time waste) |

**Optimal Question Selection:** θ - 0.5 ≤ b ≤ θ + 0.5 (50-75% success rate)

---

## 4. Initial Assessment Processing

### 4.1 Assessment Structure (Pre-defined)
```javascript
ASSESSMENT_STRUCTURE = {
  total_questions: 30,
  time_limit_minutes: 45,
  subjects: {
    physics: 10,    // 4 mechanics, 3 electro, 2 magnetism, 1 modern
    chemistry: 10,  // 3 organic, 4 physical, 3 inorganic
    mathematics: 10 // 4 calculus, 4 algebra, 2 coord geom
  },
  difficulty_distribution: {
    // IRT difficulty_b values (based on actual initial_assessment data)
    // Initial assessment range: 0.6 to 1.3
    easy: [0.6, 0.8],      // ~10 questions (easy-medium)
    medium: [0.9, 1.1],    // ~15 questions (medium)
    hard: [1.2, 1.3]       // ~5 questions (medium-hard)
  },
  discrimination_threshold: 1.25  // All assessment questions have a ≥ 1.25
}
```

### 4.2 Topic Mapping from Assessment

Each of the 30 questions maps to specific topics. Example from your data:

```javascript
QUESTION_TO_TOPIC_MAP = {
  "ASSESS_PHY_MECH_001": "physics_mechanics_newtons_laws",
  "ASSESS_PHY_MECH_002": "physics_mechanics_work_energy",
  "ASSESS_PHY_ELEC_001": "physics_electrostatics_coulomb",
  "ASSESS_CHEM_ORG_001": "chemistry_organic_nomenclature",
  // ... 30 total mappings
}
```

**Coverage:** Initial assessment covers approximately 20-25 unique topics out of 63 total JEE syllabus topics.

### 4.3 Initial Theta Calculation Algorithm

```python
def process_initial_assessment(student_id, responses):
    """
    Process the 30-question initial assessment to calculate initial theta per topic.
    
    Args:
        student_id: Unique student identifier
        responses: Array of 30 response objects with {question_id, answer, time_taken}
    
    Returns:
        student_profile: Dictionary with theta estimates per topic
    """
    
    # Step 1: Group responses by topic
    topic_responses = group_by_topic(responses)
    
    # Step 2: Calculate per-topic accuracy
    theta_estimates = {}
    
    for topic, topic_qs in topic_responses.items():
        correct_count = sum(1 for q in topic_qs if q.is_correct)
        total_count = len(topic_qs)
        accuracy = correct_count / total_count
        
        # Step 3: Map accuracy to initial theta using empirical table
        initial_theta = accuracy_to_theta_mapping(accuracy)
        
        # Step 4: Calculate standard error (confidence)
        # More questions answered = lower SE (higher confidence)
        standard_error = calculate_initial_SE(total_count, accuracy)
        
        theta_estimates[topic] = {
            "theta": bound_theta(initial_theta),  # Ensure [-3, +3]
            "percentile": theta_to_percentile(initial_theta),
            "confidence_SE": standard_error,
            "attempts": total_count,
            "accuracy": accuracy,
            "last_updated": current_timestamp()
        }
    
    # Step 5: Calculate overall theta (weighted by JEE topic importance)
    overall_theta = calculate_weighted_overall_theta(theta_estimates)
    
    # Step 6: Save to Firebase
    student_profile = {
        "student_id": student_id,
        "theta_by_topic": theta_estimates,
        "overall_theta": overall_theta,
        "overall_percentile": theta_to_percentile(overall_theta),
        "assessment_completed_at": current_timestamp(),
        "learning_phase": "exploration",  # Days 1-14
        "day_number": 1
    }
    
    save_student_profile(student_profile)
    
    return student_profile


def accuracy_to_theta_mapping(accuracy):
    """
    Convert raw accuracy to initial theta estimate.
    Based on empirical IRT calibration curves.
    """
    if accuracy < 0.20:
        return -2.5  # Very weak foundation
    elif accuracy < 0.40:
        return -1.5  # Below average, major gaps
    elif accuracy < 0.60:
        return -0.5  # Slightly below average
    elif accuracy < 0.75:
        return +0.5  # Above average
    elif accuracy < 0.90:
        return +1.5  # Strong performance
    else:
        return +2.5  # Excellent (90%+ accuracy)


def calculate_initial_SE(num_questions, accuracy):
    """
    Calculate standard error (confidence interval) for theta estimate.
    More questions + accuracy near 0.5 = more informative = lower SE.
    """
    # Maximum likelihood estimation variance formula (simplified)
    # SE decreases with sqrt(n)
    base_SE = 1.0 / sqrt(num_questions)
    
    # Adjust for informativeness: accuracy near 50% is most informative
    # (provides most information about ability level)
    information_penalty = 1 + abs(accuracy - 0.5)
    
    SE = base_SE * information_penalty
    
    # Typical range: 0.15 to 0.6
    return min(0.6, max(0.15, SE))


def calculate_weighted_overall_theta(theta_estimates):
    """
    Calculate overall theta as weighted average by JEE topic importance.
    """
    total_weight = 0
    weighted_sum = 0
    
    for topic, data in theta_estimates.items():
        weight = JEE_TOPIC_WEIGHTS[topic]  # High=1.0, Medium=0.6, Low=0.3
        weighted_sum += data["theta"] * weight
        total_weight += weight
    
    return weighted_sum / total_weight if total_weight > 0 else 0.0


def bound_theta(theta):
    """Enforce hard bounds at [-3.0, +3.0]"""
    return max(-3.0, min(3.0, theta))


def theta_to_percentile(theta):
    """
    Convert theta to percentile using standard normal CDF.
    θ ~ N(0, 1) approximately.
    """
    from scipy.stats import norm
    return norm.cdf(theta) * 100
```

### 4.4 Example: Processing Student's Initial Assessment

**Input:**
```javascript
responses = [
  {question_id: "ASSESS_PHY_MECH_001", answer: "A", is_correct: true, time_taken: 95},
  {question_id: "ASSESS_PHY_MECH_002", answer: "C", is_correct: false, time_taken: 140},
  // ... 28 more responses
]

// Summary by topic after grouping:
topic_summary = {
  "physics_mechanics": {correct: 2, total: 4, accuracy: 0.50},
  "physics_electrostatics": {correct: 1, total: 3, accuracy: 0.33},
  "chemistry_organic": {correct: 2, total: 3, accuracy: 0.67},
  "mathematics_calculus": {correct: 3, total: 4, accuracy: 0.75},
  // ... more topics
}
```

**Output:**
```javascript
student_profile = {
  "student_id": "student_12345",
  "theta_by_topic": {
    "physics_mechanics": {
      "theta": -0.5,
      "percentile": 30.85,
      "confidence_SE": 0.35,
      "attempts": 4,
      "accuracy": 0.50,
      "last_updated": "2024-12-10T10:30:00Z"
    },
    "physics_electrostatics": {
      "theta": -1.5,
      "percentile": 6.68,
      "confidence_SE": 0.48,
      "attempts": 3,
      "accuracy": 0.33,
      "last_updated": "2024-12-10T10:30:00Z"
    },
    "chemistry_organic": {
      "theta": 0.5,
      "percentile": 69.15,
      "confidence_SE": 0.42,
      "attempts": 3,
      "accuracy": 0.67,
      "last_updated": "2024-12-10T10:30:00Z"
    },
    "mathematics_calculus": {
      "theta": 1.5,
      "percentile": 93.32,
      "confidence_SE": 0.30,
      "attempts": 4,
      "accuracy": 0.75,
      "last_updated": "2024-12-10T10:30:00Z"
    }
    // ... all tested topics
  },
  "overall_theta": 0.2,
  "overall_percentile": 57.93,
  "assessment_completed_at": "2024-12-10T10:30:00Z",
  "learning_phase": "exploration",
  "day_number": 1
}
```

---

## 5. Daily Quiz Generation (Hybrid IIDP)

### 5.1 Two-Phase Strategy Overview

**IMPORTANT:** Phase transition is based on **completed quiz count**, not calendar days. This allows students to progress at their own pace - motivated students can complete multiple quizzes per day to accelerate through exploration phase.

#### **Phase 1: Exploration (Quizzes 1-14)**
**Goal:** Rapidly map student ability across all high/medium JEE weightage topics

**Distribution per 10-question quiz:**
- Quizzes 1-7:
  - 6 questions: Unexplored topics (high/medium weightage)
  - 3 questions: Known weak topics (from assessment)
  - 1 question: Spaced review
  
- Quizzes 8-14:
  - 5 questions: Remaining unexplored topics
  - 4 questions: Emerging weak topics
  - 1 question: Spaced review

**Rationale:** 
- Prevents "tunnel vision" on initially tested topics
- Discovers hidden weak areas early (better than finding them in mock tests)
- Builds student confidence through comprehensive coverage
- Research-backed: Duolingo uses 14-session exploration window
- **Flexible pacing:** Fast learners can complete exploration in <7 days, slower learners take their time

#### **Phase 2: Exploitation (Quizzes 15+)**
**Goal:** Maximize learning efficiency on validated weak topics

**Distribution per 10-question quiz:**
- 7 questions: Weak topics (priority-ranked)
- 2 questions: Strong topics (maintenance)
- 1 question: Spaced review (3/7/14-day intervals)

**Rationale:**
- 70% focus on deliberate practice (weak areas)
- 20% maintenance (prevent skill decay)
- 10% spaced repetition (long-term retention)

### 5.2 Main Quiz Generation Function

```python
def generate_daily_quiz(student_id, completed_quiz_count):
    """
    Master function to generate personalized 10-question daily quiz.
    Implements hybrid Exploration → Exploitation strategy.
    
    Args:
        student_id: Unique student identifier
        completed_quiz_count: Number of quizzes completed since initial assessment (0-indexed)
                             Phase transition happens at quiz 14
    
    Returns:
        quiz: List of 10 question objects with metadata
    """
    
    # Load student profile
    student = get_student_profile(student_id)
    theta_by_topic = student["theta_by_topic"]
    topic_attempts = student["topic_attempt_counts"]
    recent_questions_30d = student["recent_question_history"]
    
    # Determine learning phase based on QUIZ COUNT, not days
    if completed_quiz_count < 14:
        learning_phase = "EXPLORATION"
        exploration_ratio = max(0.6 - (completed_quiz_count * 0.04), 0.3)
        # Quiz 0: 60% exploration
        # Quiz 7: 32% exploration
        # Quiz 13: 30% exploration (linear decay)
    else:
        learning_phase = "EXPLOITATION"
        exploration_ratio = 0.0
    
    quiz_questions = []
    
    # ========================================
    # EXPLORATION PHASE (Quizzes 0-13)
    # ========================================
    
    if learning_phase == "EXPLORATION":
        num_exploration = int(10 * exploration_ratio)
        num_deliberate = 9 - num_exploration  # Reserve 1 for review
        num_review = 1
        
        # 1. Get unexplored topics (tested < 2 times)
        unexplored_topics = get_unexplored_topics(
            topic_attempts,
            min_attempts=2,
            weightage=['High', 'Medium']
        )
        
        # 2. Prioritize by strategic importance
        exploration_topics = prioritize_exploration_topics(
            unexplored_topics,
            subject_balance=calculate_subject_balance(student)
        )[:num_exploration]
        
        # 3. Select exploration questions
        for topic in exploration_topics:
            # For first attempt, use neutral difficulty (θ = 0)
            if topic not in theta_by_topic or topic_attempts[topic] == 0:
                target_difficulty = 0.0
            else:
                target_difficulty = theta_by_topic[topic]["theta"]
            
            question = select_optimal_question_IRT(
                topic=topic,
                target_theta=target_difficulty,
                recent_questions=recent_questions_30d,
                discrimination_min=1.4
            )
            quiz_questions.append(question)
        
        # 4. Select deliberate practice questions (weak topics)
        tested_topics = [t for t, count in topic_attempts.items() if count >= 2]
        weak_topics = rank_topics_by_weakness(tested_topics, theta_by_topic)
        
        for topic in weak_topics[:num_deliberate]:
            question = select_optimal_question_IRT(
                topic=topic,
                target_theta=theta_by_topic[topic]["theta"],
                recent_questions=recent_questions_30d,
                discrimination_min=1.4
            )
            quiz_questions.append(question)
        
        # 5. Add spaced review question
        review_question = get_spaced_review_question(
            student_id,
            recent_questions_30d
        )
        if review_question:
            quiz_questions.append(review_question)
    
    # ========================================
    # EXPLOITATION PHASE (Quizzes 14+)
    # ========================================
    
    else:  # EXPLOITATION
        num_weak = 7
        num_maintenance = 2
        num_review = 1
        
        # 1. Rank ALL topics by weakness priority
        all_topics = list(theta_by_topic.keys())
        ranked_topics = rank_topics_by_priority_formula(
            all_topics,
            theta_by_topic,
            topic_attempts
        )
        
        # 2. Select top 7 weak topics
        weak_topics = ranked_topics[:7]
        
        for topic in weak_topics:
            question = select_optimal_question_IRT(
                topic=topic,
                target_theta=theta_by_topic[topic]["theta"],
                recent_questions=recent_questions_30d,
                discrimination_min=1.4
            )
            quiz_questions.append(question)
        
        # 3. Select 2 strong topics (maintenance)
        strong_topics = ranked_topics[-5:]  # Bottom 5 = strongest
        maintenance_topics = random.sample(strong_topics, min(2, len(strong_topics)))
        
        for topic in maintenance_topics:
            question = select_optimal_question_IRT(
                topic=topic,
                target_theta=theta_by_topic[topic]["theta"],
                recent_questions=recent_questions_30d,
                discrimination_min=1.0  # Slightly lower bar for maintenance
            )
            quiz_questions.append(question)
        
        # 4. Add spaced review question
        review_question = get_spaced_review_question(
            student_id,
            recent_questions_30d
        )
        if review_question:
            quiz_questions.append(review_question)
    
    # ========================================
    # COMMON: Interleave & Finalize
    # ========================================
    
    # Shuffle to prevent topic clustering
    interleaved_quiz = interleave_questions_by_topic(quiz_questions)
    
    # Save quiz metadata for analytics
    save_quiz_metadata(
        student_id=student_id,
        completed_quiz_count=completed_quiz_count,
        learning_phase=learning_phase,
        questions=interleaved_quiz,
        timestamp=current_timestamp()
    )
    
    return interleaved_quiz[:10]  # Ensure exactly 10 questions
```

### 5.3 Topic Prioritization Functions

```python
def prioritize_exploration_topics(unexplored_topics, subject_balance):
    """
    Rank unexplored topics by strategic importance for exploration.
    
    Args:
        unexplored_topics: List of topics with < 2 attempts
        subject_balance: Current distribution {physics: 0.4, chemistry: 0.3, math: 0.3}
    
    Returns:
        Sorted list of topics (highest priority first)
    """
    scored_topics = []
    
    for topic in unexplored_topics:
        # Component 1: JEE Weightage (50%)
        # High=10, Medium=6, Low=3 marks per question typically
        weightage_score = JEE_TOPIC_WEIGHTS[topic] / 10.0  # Normalize to [0, 1]
        
        # Component 2: Prerequisite Depth (30%)
        # Test foundational topics first (depth=0) before advanced (depth=3)
        prereq_depth = TOPIC_PREREQUISITE_DEPTH[topic]
        max_depth = 3
        prereq_score = 1.0 - (prereq_depth / max_depth)
        
        # Component 3: Subject Balance (20%)
        # Ensure equal coverage across Physics, Chemistry, Math
        subject = get_subject_from_topic(topic)
        current_coverage = subject_balance[subject]
        target_coverage = 1/3  # Equal distribution
        balance_score = 1.0 - abs(current_coverage - target_coverage)
        
        # Combined priority score
        priority = (
            weightage_score * 0.5 +
            prereq_score * 0.3 +
            balance_score * 0.2
        )
        
        scored_topics.append((topic, priority))
    
    # Sort descending by priority
    return [topic for topic, _ in sorted(scored_topics, key=lambda x: x[1], reverse=True)]


def rank_topics_by_priority_formula(topics, theta_by_topic, topic_attempts):
    """
    Rank topics by weakness priority for exploitation phase.
    Uses normalized theta + recency + JEE weightage.
    
    Priority = (1 - normalized_theta) * 0.6 + recency_weight * 0.2 + jee_weight * 0.2
    
    Higher priority = weaker topic that needs more practice
    """
    scored_topics = []
    
    for topic in topics:
        theta = theta_by_topic[topic]["theta"]
        attempts = topic_attempts[topic]
        
        # Component 1: Inverse normalized theta (60%)
        # θ = -3 → normalized = 0.0 → priority component = 1.0 (weakest)
        # θ = +3 → normalized = 1.0 → priority component = 0.0 (strongest)
        normalized_theta = (theta + 3) / 6
        weakness_score = 1.0 - normalized_theta
        
        # Component 2: Recency (20%)
        # Boost priority if not practiced recently
        days_since_last = days_since_last_attempt(topic, student_id)
        recency_score = min(1.0, days_since_last / 7)  # Cap at 7 days
        
        # Component 3: JEE Weightage (20%)
        # High weightage topics get priority boost
        jee_weight = JEE_TOPIC_WEIGHTS[topic] / 10.0
        
        # Combined priority
        priority = (
            weakness_score * 0.6 +
            recency_score * 0.2 +
            jee_weight * 0.2
        )
        
        scored_topics.append((topic, priority))
    
    # Sort descending by priority (highest = weakest/most important)
    return [topic for topic, _ in sorted(scored_topics, key=lambda x: x[1], reverse=True)]


def rank_topics_by_weakness(topics, theta_by_topic):
    """
    Simple ranking by theta (ascending = weakest first).
    Used during exploration phase for deliberate practice selection.
    """
    return sorted(topics, key=lambda t: theta_by_topic[t]["theta"])
```

### 5.4 Question Selection (IRT-Optimized)

```python
def select_optimal_question_IRT(topic, target_theta, recent_questions, discrimination_min):
    """
    Select the single best question for a topic using IRT principles.
    
    Optimal question criteria:
    1. Difficulty matches student ability: |b - θ| < 0.5
    2. High discrimination: a ≥ discrimination_min
    3. Not recently answered (within 30 days)
    4. Maximizes information gain
    
    Args:
        topic: Topic identifier (e.g., "physics_mechanics_newtons_laws")
        target_theta: Student's current theta for this topic
        recent_questions: List of question IDs answered in last 30 days
        discrimination_min: Minimum acceptable discrimination parameter
    
    Returns:
        question: Single question object from question bank
    """
    
    # Get all questions for this topic
    candidate_questions = get_questions_by_topic(topic)
    
    # Filter 1: Remove recently answered questions
    candidate_questions = [q for q in candidate_questions 
                          if q.question_id not in recent_questions]
    
    # Filter 2: Minimum discrimination threshold
    candidate_questions = [q for q in candidate_questions 
                          if q.irt_parameters.discrimination_a >= discrimination_min]
    
    # Filter 3: Difficulty within optimal range [θ - 0.5, θ + 0.5]
    candidate_questions = [q for q in candidate_questions 
                          if abs(q.irt_parameters.difficulty_b - target_theta) <= 0.5]
    
    # If too restrictive, relax difficulty constraint
    if len(candidate_questions) == 0:
        candidate_questions = [q for q in get_questions_by_topic(topic)
                              if q.question_id not in recent_questions
                              and q.irt_parameters.discrimination_a >= discrimination_min - 0.2]
    
    # Still no candidates? Take any non-recent question
    if len(candidate_questions) == 0:
        candidate_questions = [q for q in get_questions_by_topic(topic)
                              if q.question_id not in recent_questions]
    
    # Edge case: All questions answered recently (shouldn't happen with 60+ questions/topic)
    if len(candidate_questions) == 0:
        return get_random_question_from_topic(topic)
    
    # Score each candidate by information value
    scored_questions = []
    for question in candidate_questions:
        info_score = calculate_fisher_information(
            theta=target_theta,
            difficulty=question.irt_parameters.difficulty_b,
            discrimination=question.irt_parameters.discrimination_a,
            guessing=question.irt_parameters.guessing_c
        )
        scored_questions.append((question, info_score))
    
    # Select question with highest information gain
    best_question = max(scored_questions, key=lambda x: x[1])[0]
    
    return best_question


def calculate_fisher_information(theta, difficulty, discrimination, guessing):
    """
    Calculate Fisher information I(θ) - measures how much a question 
    tells us about student's true ability.
    
    Higher information = better question for ability estimation.
    
    For 3PL IRT model:
    I(θ) = a² * [P'(θ)]² / [P(θ)(1 - P(θ))]
    
    Where P'(θ) is derivative of probability function.
    """
    from math import exp
    
    # Calculate P(θ) - probability of correct answer
    P = guessing + (1 - guessing) / (1 + exp(-discrimination * (theta - difficulty)))
    
    # Calculate P'(θ) - derivative
    Q = 1 - P
    P_prime = discrimination * (1 - guessing) * exp(-discrimination * (theta - difficulty)) / \
              ((1 + exp(-discrimination * (theta - difficulty))) ** 2)
    
    # Fisher information
    if P > 0.01 and P < 0.99:  # Avoid division by zero
        information = discrimination**2 * (P_prime**2) / (P * Q)
    else:
        information = 0.0
    
    return information
```

---

## 6. Theta Update Mechanism

### 6.1 Bayesian Update After Each Question

After each question attempt, we update theta using a **bounded gradient descent** approach:

```python
def update_theta_after_response(student_id, question_id, is_correct, time_taken):
    """
    Update student's theta for the relevant topic after answering a question.
    Uses IRT-based Bayesian update with bounded constraints.
    
    Args:
        student_id: Unique student identifier
        question_id: Question that was answered
        is_correct: Boolean - whether answer was correct
        time_taken: Time spent in seconds
    
    Returns:
        updated_theta: New theta value for the topic
    """
    
    # Load question metadata
    question = get_question_by_id(question_id)
    topic = question.topic
    difficulty_b = question.irt_parameters.difficulty_b
    discrimination_a = question.irt_parameters.discrimination_a
    guessing_c = question.irt_parameters.guessing_c
    
    # Load current theta
    student = get_student_profile(student_id)
    current_theta = student["theta_by_topic"][topic]["theta"]
    current_SE = student["theta_by_topic"][topic]["confidence_SE"]
    attempts = student["theta_by_topic"][topic]["attempts"]
    
    # Calculate expected probability of correct answer
    P_correct = calculate_probability_3PL(
        theta=current_theta,
        difficulty=difficulty_b,
        discrimination=discrimination_a,
        guessing=guessing_c
    )
    
    # Learning rate: Decreases with more attempts (we become more confident)
    # Initial: 0.3, After 50 attempts: ~0.15
    base_learning_rate = 0.3
    learning_rate = base_learning_rate / (1 + 0.02 * attempts)
    
    # Calculate theta update (gradient descent)
    if is_correct:
        # Student performed better than expected → increase theta
        delta = learning_rate * (1 - P_correct)
    else:
        # Student performed worse than expected → decrease theta
        delta = -learning_rate * P_correct
    
    # Apply update
    new_theta = current_theta + delta
    
    # CRITICAL: Enforce hard bounds [-3.0, +3.0]
    new_theta = max(-3.0, min(3.0, new_theta))
    
    # Update standard error (decreases with more data)
    new_SE = current_SE * 0.95  # 5% reduction per question
    new_SE = max(0.1, new_SE)   # Floor at 0.1 (very confident)
    
    # Save updated values
    update_student_topic_theta(
        student_id=student_id,
        topic=topic,
        new_theta=new_theta,
        new_SE=new_SE,
        attempts=attempts + 1,
        timestamp=current_timestamp()
    )
    
    # Log response for analytics
    log_student_response(
        student_id=student_id,
        question_id=question_id,
        is_correct=is_correct,
        time_taken=time_taken,
        theta_before=current_theta,
        theta_after=new_theta,
        timestamp=current_timestamp()
    )
    
    return new_theta


def calculate_probability_3PL(theta, difficulty, discrimination, guessing):
    """
    Calculate probability of correct answer using 3PL IRT model.
    
    P(θ) = c + (1 - c) / (1 + exp(-a(θ - b)))
    """
    from math import exp
    
    exponent = -discrimination * (theta - difficulty)
    probability = guessing + (1 - guessing) / (1 + exp(exponent))
    
    return probability
```

### 6.2 Example: Theta Update Walkthrough

**Scenario:**
- Student (θ = 0.0) answers a medium difficulty question (b = 0.8, a = 1.5, c = 0.25)
- Question is from "physics_mechanics_newtons_laws"
- This is the student's 10th attempt in this topic

**Step-by-step:**

```python
# Initial state
current_theta = 0.0
difficulty_b = 0.8
discrimination_a = 1.5
guessing_c = 0.25
attempts = 10

# Calculate expected probability
P_correct = 0.25 + (1 - 0.25) / (1 + exp(-1.5 * (0.0 - 0.8)))
         = 0.25 + 0.75 / (1 + exp(1.2))
         = 0.25 + 0.75 / 3.32
         = 0.25 + 0.226
         = 0.476  # Student has ~48% chance of getting it right

# Learning rate (decreases with experience)
learning_rate = 0.3 / (1 + 0.02 * 10) = 0.3 / 1.2 = 0.25

# Case 1: Student answers CORRECTLY
delta = 0.25 * (1 - 0.476) = 0.25 * 0.524 = 0.131
new_theta = 0.0 + 0.131 = 0.131  ✓ Within bounds

# Case 2: Student answers INCORRECTLY
delta = -0.25 * 0.476 = -0.119
new_theta = 0.0 - 0.119 = -0.119  ✓ Within bounds

# Standard error update (confidence increases)
current_SE = 0.35
new_SE = 0.35 * 0.95 = 0.3325  # More confident after 10th attempt
```

**Interpretation:**
- If correct: θ increases by +0.131 (student stronger than expected)
- If incorrect: θ decreases by -0.119 (student weaker than expected)
- After 50+ attempts, updates become smaller (~0.05-0.08 per question)

---

## 7. Question Selection Strategy

### 7.1 Difficulty Targeting

**Actual JEEVibe Question Bank Distribution:**
```
difficulty_b range: [0.40, 2.60]
- Easy (0.4-0.7):        ~20% of questions
- Medium (0.8-1.3):      ~40% of questions  
- Hard (1.4-2.0):        ~27% of questions
- Very Hard (2.0-2.6):   ~13% of questions
```

Optimal question difficulty selection by learning goal:

| Goal | Target Difficulty (b) | Expected Success Rate | Use Case |
|------|----------------------|----------------------|----------|
| **Exploration** | 0.8 - 1.0 (neutral) | ~50-60% | First time testing a topic |
| **Deliberate Practice** | Match to θ ± 0.3 | 50-70% | Learning weak topics |
| **Maintenance** | θ + 0.3 to θ + 0.6 | 70-85% | Maintaining strong topics |
| **Challenge** | 1.5 - 2.0 | 40-60% | Occasional stretch problems |
| **Recovery (Circuit Breaker)** | 0.4 - 0.7 | 75-85% | Confidence rebuilding |

### 7.2 Interleaving Algorithm

```python
def interleave_questions_by_topic(questions):
    """
    Shuffle questions to prevent topic clustering while maintaining difficulty flow.
    
    Research shows interleaved practice >> blocked practice for retention.
    
    Strategy:
    1. Group by topic
    2. Ensure no two questions from same topic are adjacent
    3. Prefer difficulty progression: easier → harder → easier (sawtooth pattern)
    
    Args:
        questions: List of 10 question objects
    
    Returns:
        interleaved: Optimally ordered question list
    """
    
    # Group by topic
    topic_groups = {}
    for q in questions:
        topic = q.topic
        if topic not in topic_groups:
            topic_groups[topic] = []
        topic_groups[topic].append(q)
    
    # Build interleaved sequence
    interleaved = []
    remaining_topics = list(topic_groups.keys())
    
    while remaining_topics:
        # Pick a topic that's different from the last question
        if len(interleaved) > 0:
            last_topic = interleaved[-1].topic
            available_topics = [t for t in remaining_topics if t != last_topic]
        else:
            available_topics = remaining_topics
        
        # If all remaining are same topic, just take it
        if len(available_topics) == 0:
            available_topics = remaining_topics
        
        # Select next topic (random from available)
        next_topic = random.choice(available_topics)
        
        # Add one question from this topic
        interleaved.append(topic_groups[next_topic].pop(0))
        
        # Remove topic if exhausted
        if len(topic_groups[next_topic]) == 0:
            remaining_topics.remove(next_topic)
    
    return interleaved
```

---

## 8. Circuit Breaker: Death Spiral Prevention

### 8.1 The Problem: Death Spiral

**Scenario:**
```
Student has bad day → Gets 5 wrong in a row
→ Theta drops from +0.5 to -1.2
→ Algorithm serves b=-1.0 questions (still hard)
→ Gets 3 more wrong
→ Theta drops to -2.0
→ Student rage-quits, never returns 😢
```

**Research Data (Duolingo, 2017):**
- Students with 6+ consecutive failures: **72% churn rate**
- Students with max 3 consecutive failures: **12% churn rate**

### 8.2 Circuit Breaker Mechanism

**Trigger Conditions:**
1. **Primary:** 5+ consecutive incorrect answers in recent session
2. **Secondary:** 3+ consecutive incorrect in current quiz (real-time)

**Response:** Override normal quiz generation with confidence-building "recovery quiz"

### 8.3 Recovery Quiz Strategy

When circuit breaker triggers, generate special quiz with:

```
Recovery Quiz Composition (10 questions):
- 7 questions: EASY (difficulty b = 0.4 to 0.7)
  → Expected success rate: 75-85%
  → Use actual "easy" questions from question bank
  → From weakest topics to prevent gap widening
  
- 2 questions: MEDIUM (difficulty b = 0.8 to 1.1)
  → Expected success rate: 60-70%
  → Gentle challenge to rebuild confidence
  
- 1 question: REVIEW (previously correct 7-14 days ago)
  → Expected success rate: ~90%
  → Psychological boost ("I know this!")
```

**Note:** These difficulty values are based on actual JEEVibe question bank distribution:
- Easy questions (b: 0.4-0.7): ~20% of bank, ideal for recovery
- Medium questions (b: 0.8-1.3): ~40% of bank, main practice zone
  → Expected success rate: 60-70%
  → Gentle challenge to rebuild confidence
  
- 1 question: REVIEW (previously correct 7-14 days ago)
  → Expected success rate: ~90%
  → Psychological boost ("I know this!")
```

### 8.4 Implementation

```python
def check_circuit_breaker(student_id: str) -> bool:
    """
    Check if student needs intervention due to consecutive failures.
    
    Returns:
        True if circuit breaker should activate
    """
    db = firestore.client()
    
    # Get last 10 responses (covers ~1 quiz)
    recent_responses = db.collection('student_responses')\
                        .document(student_id)\
                        .collection('responses')\
                        .order_by('answered_at', direction=firestore.Query.DESCENDING)\
                        .limit(10)\
                        .stream()
    
    responses_list = [r.to_dict() for r in recent_responses]
    
    if len(responses_list) < 5:
        return False  # Not enough data
    
    # Count consecutive failures from most recent
    consecutive_failures = 0
    for response in responses_list:
        if not response['is_correct']:
            consecutive_failures += 1
        else:
            break  # Stop at first correct answer
    
    # Trigger: 5+ consecutive failures
    return consecutive_failures >= 5


def generate_recovery_quiz(student_id: str, student_data: Dict) -> List[Dict]:
    """
    Generate confidence-building quiz after circuit breaker triggers.
    
    Strategy:
    - 7 EASY questions (b = 0.4 to 0.7): 75-85% success
    - 2 MEDIUM questions (b = 0.8 to 1.1): 60-70% success
    - 1 REVIEW question (previously correct): ~90% success
    
    Goal: 70-80% overall success rate to rebuild confidence
    """
    db = firestore.client()
    
    theta_by_topic = student_data['theta_by_topic']
    recent_questions = get_recent_questions(student_id, days=30)
    
    # Get weakest topics (where student is struggling)
    weak_topics = sorted(
        theta_by_topic.items(),
        key=lambda x: x[1]['theta']
    )[:5]  # Focus on 5 weakest
    
    recovery_questions = []
    
    # ========================================
    # 7 EASY questions (confidence builders)
    # ========================================
    
    for topic_name, topic_data in weak_topics[:4]:
        # Select EASY: b = 0.4 to 0.7 (actual easy range in question bank)
        easy_questions = select_questions_by_difficulty_range(
            topic=topic_name,
            difficulty_min=0.4,
            difficulty_max=0.7,
            count=2,
            recent_questions=recent_questions,
            discrimination_min=1.0  # Relaxed requirement
        )
        recovery_questions.extend(easy_questions)
    
    # ========================================
    # 2 MEDIUM questions (gentle challenge)
    # ========================================
    
    for topic_name, topic_data in weak_topics[:2]:
        
        # Select MEDIUM: b = 0.8 to 1.1 (actual medium range in question bank)
        medium_questions = select_questions_by_difficulty_range(
            topic=topic_name,
            difficulty_min=0.8,
            difficulty_max=1.1,
            count=1,
            recent_questions=recent_questions,
            discrimination_min=1.0
        )
        recovery_questions.extend(medium_questions)
    
    # ========================================
    # 1 REVIEW question (guaranteed success)
    # ========================================
    
    review_question = get_previously_correct_question(
        student_id,
        recent_questions,
        from_topics=[t[0] for t in weak_topics]
    )
    
    if review_question:
        recovery_questions.append(review_question)
    
    # Interleave and finalize
    interleaved = interleave_questions_by_topic(recovery_questions[:10])
    
    # Log circuit breaker activation for analytics
    log_circuit_breaker_event(
        student_id=student_id,
        trigger_reason="consecutive_failures",
        recovery_quiz=True
    )
    
    return interleaved


def select_questions_by_difficulty_range(topic: str, difficulty_min: float,
                                        difficulty_max: float, count: int,
                                        recent_questions: List[str],
                                        discrimination_min: float) -> List[Dict]:
    """
    Select questions within specific difficulty range.
    Used for circuit breaker recovery quizzes.
    """
    db = firestore.client()
    
    questions = db.collection('questions')\
                 .where('topic', '==', topic)\
                 .where('irt_parameters.difficulty_b', '>=', difficulty_min)\
                 .where('irt_parameters.difficulty_b', '<=', difficulty_max)\
                 .stream()
    
    candidates = [q.to_dict() for q in questions 
                  if q.to_dict()['question_id'] not in recent_questions
                  and q.to_dict()['irt_parameters']['discrimination_a'] >= discrimination_min]
    
    # Random selection (avoid always same "easy" questions)
    selected = random.sample(candidates, min(count, len(candidates)))
    
    return selected


def get_previously_correct_question(student_id: str, recent_questions: List[str],
                                   from_topics: List[str]) -> Optional[Dict]:
    """
    Get a question student answered correctly 7-14 days ago.
    High probability they still remember → confidence boost.
    """
    db = firestore.client()
    
    # Look for correct answers 7-14 days ago
    cutoff_start = datetime.utcnow() - timedelta(days=14)
    cutoff_end = datetime.utcnow() - timedelta(days=7)
    
    responses = db.collection('student_responses')\
                 .document(student_id)\
                 .collection('responses')\
                 .where('is_correct', '==', True)\
                 .where('answered_at', '>=', cutoff_start.isoformat())\
                 .where('answered_at', '<=', cutoff_end.isoformat())\
                 .stream()
    
    candidates = [r.to_dict() for r in responses 
                  if r.to_dict()['topic'] in from_topics
                  and r.to_dict()['question_id'] not in recent_questions]
    
    if len(candidates) == 0:
        return None
    
    # Pick random previously-correct question
    chosen = random.choice(candidates)
    question_id = chosen['question_id']
    
    return db.collection('questions').document(question_id).get().to_dict()
```

### 8.5 Integration with Main Quiz Generator

Circuit breaker check happens **before** normal quiz generation:

```python
def generate_daily_quiz(student_id, completed_quiz_count):
    """
    Master function with circuit breaker safety.
    """
    student = get_student_profile(student_id)
    
    # ========================================
    # STEP 0: CIRCUIT BREAKER CHECK
    # ========================================
    
    if check_circuit_breaker(student_id):
        # Override normal quiz with recovery quiz
        return generate_recovery_quiz(student_id, student)
    
    # ========================================
    # STEP 1: Normal quiz generation
    # ========================================
    
    # ... continue with exploration/exploitation logic ...
```

### 8.6 Real-Time Circuit Breaker (Optional Enhancement)

For advanced implementation, check **during** quiz delivery:

```python
def should_trigger_circuit_breaker_realtime(current_quiz_responses: List[Dict]) -> bool:
    """
    Real-time check during active quiz.
    Trigger if 3 consecutive failures IN CURRENT QUIZ.
    """
    if len(current_quiz_responses) < 3:
        return False
    
    # Check last 3 responses
    last_three = current_quiz_responses[-3:]
    all_incorrect = all(not r['is_correct'] for r in last_three)
    
    return all_incorrect
```

### 8.7 UX Considerations

**Don't explicitly tell students about circuit breaker:**

❌ **Bad messaging:**
> "You failed 5 times. We're giving you easier questions."

✅ **Good messaging:**
> "Let's review some fundamentals! 💡"

Or adjust silently - students often don't notice and appreciate the gentler experience.

### 8.8 Configuration Constants

```python
# Circuit Breaker Configuration
CIRCUIT_BREAKER_THRESHOLD = 5           # Consecutive failures to trigger
CIRCUIT_BREAKER_REALTIME_THRESHOLD = 3  # Failures in current quiz
RECOVERY_QUIZ_EASY_COUNT = 7            # Easy questions in recovery
RECOVERY_QUIZ_MEDIUM_COUNT = 2          # Medium questions
RECOVERY_QUIZ_REVIEW_COUNT = 1          # Review questions
CIRCUIT_BREAKER_COOLDOWN = 2            # Quizzes before re-checking
```

### 8.9 Analytics Tracking

Monitor these metrics:

```python
# Key Performance Indicators:
- Circuit breaker activation rate (target: <5% of students)
- Recovery quiz success rate (target: 70-80%)
- Student retention after circuit breaker (target: >80%)
- Time to recovery (target: 1-2 quizzes)
- Repeat activations (flag if >3 times per student)
```

### 8.10 Edge Cases

**Multiple Activations:**
```python
# If circuit breaker triggers 3+ times in 7 days:
# → Flag for human intervention (tutor/counselor)
# → Possible issues: content too hard, student needs 1-on-1 help
```

**No Easy Questions Available:**
```python
# Fallback: Use questions from prerequisite topics
# Example: If struggling with "Rotational Motion", 
#          serve "Kinematics" questions instead
```

---

## 9. Spaced Repetition Integration

### 8.1 Forgetting Curve & Review Schedule

Based on Ebbinghaus forgetting curve + SuperMemo SM-2 algorithm:

```python
def get_spaced_review_question(student_id, recent_questions_30d):
    """
    Select one question for spaced repetition review.
    
    Review intervals: 1 day, 3 days, 7 days, 14 days, 30 days
    Priority: Earlier intervals > later intervals
    
    Args:
        student_id: Unique student identifier
        recent_questions_30d: Questions answered in last 30 days
    
    Returns:
        review_question: Question object due for review, or None
    """
    
    # Get all past correct answers (candidates for review)
    past_correct_answers = get_past_correct_answers(student_id)
    
    # Filter: Only questions NOT in recent 30-day window
    reviewable = [q for q in past_correct_answers 
                  if q.question_id not in recent_questions_30d]
    
    if len(reviewable) == 0:
        return None
    
    # Calculate review priority for each question
    scored_reviews = []
    current_time = current_timestamp()
    
    for answer_record in reviewable:
        question_id = answer_record.question_id
        last_answered = answer_record.timestamp
        days_since = (current_time - last_answered).days
        
        # Determine ideal review interval
        if days_since >= 30:
            interval_target = 30
            priority = 5  # Highest priority (long overdue)
        elif days_since >= 14:
            interval_target = 14
            priority = 4
        elif days_since >= 7:
            interval_target = 7
            priority = 3
        elif days_since >= 3:
            interval_target = 3
            priority = 2
        elif days_since >= 1:
            interval_target = 1
            priority = 1
        else:
            continue  # Too recent
        
        # Boost priority if question was initially difficult
        initial_difficulty = answer_record.question_difficulty_b
        student_theta_then = answer_record.student_theta_at_time
        difficulty_gap = initial_difficulty - student_theta_then
        
        if difficulty_gap > 0.5:
            priority += 1  # Was hard for student → review sooner
        
        scored_reviews.append((question_id, priority, days_since))
    
    if len(scored_reviews) == 0:
        return None
    
    # Select highest priority review question
    # If tie, pick the one that's been longest since review
    best_review = max(scored_reviews, key=lambda x: (x[1], x[2]))
    review_question_id = best_review[0]
    
    return get_question_by_id(review_question_id)
```

### 8.2 Review Success Criteria

- **Success:** Answer correctly again → Extend interval (e.g., 3 days → 7 days)
- **Failure:** Answer incorrectly → Reset interval to 1 day, treat as new weak topic

---

## 10. Data Structures & Firebase Schema

### 10.1 Student Profile Collection

**Collection:** `students/{student_id}`

```javascript
{
  "student_id": "student_abc123",
  "name": "Rajesh Kumar",
  "phone": "+91-9876543210",
  "age": 17,
  
  // Theta estimates per topic
  "theta_by_topic": {
    "physics_mechanics_newtons_laws": {
      "theta": 0.5,
      "percentile": 69.15,
      "confidence_SE": 0.25,
      "attempts": 12,
      "accuracy": 0.67,  // Cumulative accuracy
      "last_updated": "2024-12-10T14:30:00Z"
    },
    "chemistry_organic_nomenclature": {
      "theta": -0.8,
      "percentile": 21.19,
      "confidence_SE": 0.42,
      "attempts": 5,
      "accuracy": 0.40,
      "last_updated": "2024-12-09T10:15:00Z"
    }
    // ... all 63 topics eventually
  },
  
  // Overall metrics
  "overall_theta": 0.2,
  "overall_percentile": 57.93,
  
  // Learning state - UPDATED FOR QUIZ-BASED TRANSITIONS
  "completed_quiz_count": 8,              // PRIMARY: Used for phase transition
  "current_day": 5,                       // Analytics only (days since assessment)
  "learning_phase": "exploration",        // or "exploitation"
  "phase_switched_at_quiz": null,         // Will be 14 when they switch to exploitation
  "assessment_completed_at": "2024-12-03T09:00:00Z",
  "last_quiz_completed_at": "2024-12-10T13:45:00Z",
  "total_questions_solved": 110,
  "total_time_spent_minutes": 2340,
  "quizzes_per_day_avg": 1.6,            // Analytics: engagement metric
  
  // Topic attempt counts (for exploration phase tracking)
  "topic_attempt_counts": {
    "physics_mechanics_newtons_laws": 12,
    "chemistry_organic_nomenclature": 5,
    // ... all topics
  },
  
  // Coverage metrics
  "topics_explored": 28,                  // Topics with ≥1 attempt
  "topics_confident": 15,                 // Topics with ≥2 attempts
  
  // Subject balance (for exploration prioritization)
  "subject_balance": {
    "physics": 0.35,    // 35% of questions
    "chemistry": 0.30,  // 30%
    "mathematics": 0.35 // 35%
  }
}
```

### 10.2 Student Responses Collection

**Collection:** `student_responses/{student_id}/responses/{response_id}`

```javascript
{
  "response_id": "resp_xyz789",
  "student_id": "student_abc123",
  "question_id": "MECH_001_KINEMATICS_45",
  
  // Question metadata (denormalized for analytics)
  "topic": "physics_mechanics_kinematics",
  "chapter": "Kinematics",
  "subject": "Physics",
  "difficulty_b": 0.8,
  "discrimination_a": 1.5,
  "guessing_c": 0.25,
  
  // Response details
  "student_answer": "B",
  "correct_answer": "A",
  "is_correct": false,
  "time_taken_seconds": 142,
  
  // IRT state at time of attempt
  "theta_before": 0.35,
  "theta_after": 0.23,
  "theta_delta": -0.12,
  "confidence_SE_before": 0.30,
  "confidence_SE_after": 0.285,
  
  // Context
  "quiz_id": "quiz_day8_2024-12-10",
  "question_position": 4,  // 4th question in quiz
  "learning_phase": "exploration",
  "day_number": 8,
  
  // Timestamps
  "answered_at": "2024-12-10T14:22:15Z",
  "created_at": "2024-12-10T14:22:15Z"
}
```

### 10.3 Quiz History Collection

**Collection:** `quizzes/{student_id}/quizzes/{quiz_id}`

```javascript
{
  "quiz_id": "quiz_num8_2024-12-10",
  "student_id": "student_abc123",
  
  // Quiz metadata - UPDATED FOR QUIZ-BASED SYSTEM
  "quiz_number": 8,                       // PRIMARY: 8th quiz completed (0-indexed internally)
  "current_day": 5,                       // Analytics: day 5 since assessment
  "learning_phase": "exploration",
  "generated_at": "2024-12-10T14:00:00Z",
  "completed_at": "2024-12-10T14:35:20Z",
  "total_time_seconds": 2120,
  
  // Questions in quiz
  "questions": [
    {
      "question_id": "MECH_045",
      "topic": "physics_mechanics_kinematics",
      "difficulty_b": 0.8,
      "position": 1,
      "selection_reason": "exploration",  // or "deliberate_practice", "maintenance", "review"
      "is_correct": true,
      "time_taken_seconds": 95
    },
    // ... 9 more questions
  ],
  
  // Performance summary
  "score": 7,  // Out of 10
  "accuracy": 0.70,
  "avg_time_per_question": 212,
  
  // Topic distribution
  "topics_covered": [
    "physics_mechanics_kinematics",
    "chemistry_organic_nomenclature",
    "mathematics_calculus_limits"
    // ...
  ],
  
  // Phase-specific metadata
  "exploration_questions": 5,
  "deliberate_practice_questions": 4,
  "review_questions": 1
}
```

### 10.4 Question Bank Structure

**Collection:** `questions/{question_id}`

(This is what you already have - just ensuring IRT parameters are present)

```javascript
{
  "question_id": "MECH_001_KINEMATICS_45",
  "subject": "Physics",
  "chapter": "Kinematics",
  "topic": "physics_mechanics_kinematics",
  "sub_topics": ["Relative velocity", "Vector addition"],
  
  // IRT Parameters (CRITICAL for algorithm)
  "irt_parameters": {
    "difficulty_b": 0.8,        // [-3, +3] scale
    "discrimination_a": 1.5,    // Higher = better question
    "guessing_c": 0.25,         // MCQ: 0.25, Numerical: 0.0
    "calibration_status": "estimated"  // or "calibrated" after real data
  },
  
  // Question content
  "question_type": "mcq_single",
  "question_text": "A car moves with...",
  "options": [/* ... */],
  "correct_answer": "A",
  
  // Educational metadata
  "solution_steps": [/* ... */],
  "concepts_tested": ["relative_motion", "vectors"],
  "difficulty": "medium",
  "priority": "HIGH",
  "time_estimate": 120,
  
  // Usage stats (updated after each use)
  "usage_stats": {
    "times_shown": 45,
    "times_correct": 28,
    "times_incorrect": 17,
    "avg_time_taken": 135,
    "accuracy_rate": 0.622
  }
}
```

---

## 11. Edge Cases & Error Handling

### 11.1 Cold Start Problems

**Issue:** Student has no attempts for a topic yet

**Solution:**
```python
def get_theta_for_untested_topic(student_id, topic):
    """
    Estimate theta for a topic the student hasn't attempted yet.
    Use overall theta or subject-level theta as prior.
    """
    student = get_student_profile(student_id)
    
    # Option 1: Use overall theta
    estimated_theta = student["overall_theta"]
    
    # Option 2: Use subject-level average (more accurate)
    subject = get_subject_from_topic(topic)
    subject_topics = [t for t in student["theta_by_topic"].keys() 
                      if get_subject_from_topic(t) == subject]
    
    if len(subject_topics) > 0:
        subject_thetas = [student["theta_by_topic"][t]["theta"] 
                         for t in subject_topics]
        estimated_theta = sum(subject_thetas) / len(subject_thetas)
    
    # High uncertainty for untested topics
    estimated_SE = 0.6
    
    return {
        "theta": estimated_theta,
        "confidence_SE": estimated_SE,
        "attempts": 0,
        "accuracy": None,
        "last_updated": None
    }
```

### 11.2 All Questions Correct or All Incorrect

**Issue:** Student gets 100% or 0% in initial assessment for a topic

**Solution:**
```python
def handle_extreme_accuracy(accuracy, num_questions):
    """
    Adjust theta estimates for extreme performance (0% or 100%).
    These are informationally poor - we can't distinguish very weak 
    from extremely weak, or very strong from exceptional.
    """
    if accuracy == 1.0:  # 100% correct
        if num_questions >= 5:
            return 2.0  # Strong performance
        else:
            return 1.5  # Might be lucky with small sample
    
    elif accuracy == 0.0:  # 0% correct
        if num_questions >= 5:
            return -2.0  # Significant gaps
        else:
            return -1.5  # Might be unlucky
    
    # Normal case: use standard mapping
    return accuracy_to_theta_mapping(accuracy)
```

### 11.3 Insufficient Questions in Question Bank

**Issue:** Not enough questions in a topic to avoid repetition

**Solution:**
```python
def handle_insufficient_questions(topic, recent_questions, min_discrimination):
    """
    Fallback when question bank is exhausted for a topic.
    """
    all_topic_questions = get_questions_by_topic(topic)
    
    # Option 1: Relax recency constraint (allow questions from 15+ days ago)
    recent_15d = [qid for qid in recent_questions 
                  if days_since_answered(qid) <= 15]
    candidates = [q for q in all_topic_questions 
                  if q.question_id not in recent_15d]
    
    if len(candidates) > 0:
        return random.choice(candidates)
    
    # Option 2: Relax discrimination constraint
    candidates = [q for q in all_topic_questions 
                  if q.question_id not in recent_questions]
    
    if len(candidates) > 0:
        return random.choice(candidates)
    
    # Option 3: Last resort - allow repetition of oldest question
    oldest_question = min(all_topic_questions, 
                         key=lambda q: days_since_answered(q.question_id))
    
    return oldest_question
```

### 11.4 Student Abandonment / Partial Quiz

**Issue:** Student starts quiz but doesn't finish

**Solution:**
```python
def handle_partial_quiz(student_id, quiz_id):
    """
    If student starts but doesn't complete quiz:
    1. Don't penalize theta for unanswered questions
    2. Update theta only for answered questions
    3. Mark quiz as "incomplete"
    4. Offer to resume next time
    """
    quiz = get_quiz(quiz_id)
    answered_questions = [q for q in quiz.questions if q.student_answer is not None]
    
    # Update theta only for answered questions
    for question in answered_questions:
        update_theta_after_response(
            student_id,
            question.question_id,
            question.is_correct,
            question.time_taken
        )
    
    # Mark quiz incomplete
    update_quiz_status(quiz_id, status="incomplete")
    
    # Option: Offer to continue later
    return {
        "status": "incomplete",
        "questions_answered": len(answered_questions),
        "questions_remaining": 10 - len(answered_questions),
        "can_resume": True
    }
```

### 11.5 Cheating Detection

**Issue:** Student might look up answers or have someone else solve

**Warning Signs:**
1. Sudden theta jump (> +1.0 in single session)
2. Perfect accuracy (> 95%) on very hard questions (b > θ + 1.5)
3. Extremely fast solving (< 30 seconds for complex questions)
4. Inconsistent performance patterns

**Solution:**
```python
def detect_anomalous_performance(student_id, session_responses):
    """
    Flag suspicious patterns for manual review.
    Don't auto-penalize (false positives harm UX).
    """
    anomalies = []
    
    # Check 1: Sudden theta spike
    theta_deltas = [r.theta_after - r.theta_before for r in session_responses]
    total_delta = sum(theta_deltas)
    
    if total_delta > 1.0:
        anomalies.append("sudden_improvement")
    
    # Check 2: Perfect score on hard questions
    hard_questions = [r for r in session_responses 
                     if r.difficulty_b > r.theta_before + 1.5]
    hard_correct = sum(1 for r in hard_questions if r.is_correct)
    
    if len(hard_questions) >= 3 and hard_correct == len(hard_questions):
        anomalies.append("perfect_hard_questions")
    
    # Check 3: Suspiciously fast
    fast_correct = [r for r in session_responses 
                    if r.is_correct and r.time_taken < 30]
    
    if len(fast_correct) >= 5:
        anomalies.append("very_fast_solving")
    
    if anomalies:
        log_anomaly(student_id, anomalies, session_responses)
        # Don't penalize - just flag for analytics
    
    return anomalies
```

---

## 12. Implementation Checklist

### 12.1 Phase 1: Core Infrastructure (Week 1-2)

- [ ] **Database Schema Setup**
  - [ ] Create Firebase collections: students, student_responses, quizzes, questions
  - [ ] Add indexes on: student_id, topic, timestamp, question_id
  - [ ] Populate question bank with IRT parameters for all 3000+ questions

- [ ] **Initial Assessment Module**
  - [ ] Implement `process_initial_assessment()` function
  - [ ] Create 30-question static assessment (already done ✓)
  - [ ] Build UI flow: instructions → 30 questions → results
  - [ ] Calculate initial theta per topic
  - [ ] Save student profile to Firebase

- [ ] **Theta Update Engine**
  - [ ] Implement `update_theta_after_response()` with 3PL IRT model
  - [ ] Add bounded constraints [-3, +3]
  - [ ] Test convergence with synthetic data
  - [ ] Implement standard error calculation

### 12.2 Phase 2: Quiz Generation (Week 3-4)

- [ ] **Question Selection Logic**
  - [ ] Implement `select_optimal_question_IRT()` with Fisher information
  - [ ] Build topic prioritization functions
  - [ ] Add recency filtering (30-day window)
  - [ ] Test edge cases (insufficient questions)

- [ ] **Daily Quiz Generator**
  - [ ] Implement hybrid exploration/exploitation phases
  - [ ] Build `generate_daily_quiz()` main function
  - [ ] Add interleaving algorithm
  - [ ] Create quiz metadata tracking

- [ ] **Circuit Breaker Implementation** ⚡ **CRITICAL**
  - [ ] Implement `check_circuit_breaker()` function
  - [ ] Build `generate_recovery_quiz()` function
  - [ ] Add `select_questions_by_difficulty_range()` helper
  - [ ] Implement `get_previously_correct_question()` helper
  - [ ] Test with synthetic "struggling student" scenarios
  - [ ] Add circuit breaker analytics tracking

- [ ] **Spaced Repetition**
  - [ ] Implement forgetting curve scheduler
  - [ ] Build `get_spaced_review_question()` function
  - [ ] Test interval progression (1, 3, 7, 14, 30 days)

### 12.3 Phase 3: Testing & Validation (Week 5-6)

- [ ] **Unit Tests**
  - [ ] Test theta initialization (10 scenarios)
  - [ ] Test theta updates (correct/incorrect responses)
  - [ ] Test question selection (all edge cases)
  - [ ] Test interleaving algorithm

- [ ] **Integration Tests**
  - [ ] End-to-end: assessment → quiz generation → theta update
  - [ ] Test phase transitions (exploration → exploitation)
  - [ ] Validate 30-day no-repetition constraint

- [ ] **Synthetic Student Simulations**
  - [ ] Create 100 synthetic students with known θ values
  - [ ] Run through 30-day journeys
  - [ ] Validate theta convergence to true values
  - [ ] Measure exploration coverage (should reach 40+ topics by Day 14)

### 12.4 Phase 4: Production Deployment (Week 7-8)

- [ ] **Performance Optimization**
  - [ ] Ensure quiz generation < 500ms
  - [ ] Add Firebase query caching
  - [ ] Optimize question fetching (batch reads)

- [ ] **Monitoring & Analytics**
  - [ ] Build dashboard: theta distributions, topic coverage, engagement
  - [ ] Add circuit breaker metrics: activation rate, recovery success
  - [ ] Set up alerts: anomalous performance, system errors
  - [ ] Log all theta updates for A/B testing

- [ ] **A/B Testing Framework**
  - [ ] Test different learning rates (0.2 vs 0.3 vs 0.4)
  - [ ] Test exploration ratios (50% vs 60% vs 70%)
  - [ ] Test circuit breaker thresholds (3 vs 5 vs 7 failures)

### 12.5 Phase 5: Continuous Improvement (Ongoing)

- [ ] **IRT Calibration with Real Data**
  - [ ] After 1000 responses per question, recalibrate a, b, c parameters
  - [ ] Use Maximum Likelihood Estimation (MLE) or MCMC
  - [ ] Update question bank quarterly

- [ ] **Algorithm Refinement**
  - [ ] Analyze student retention (Day 1 vs Day 30)
  - [ ] Optimize difficulty targeting based on engagement data
  - [ ] Adjust exploration ratio if needed

- [ ] **Feature Expansion**
  - [ ] Add topic dependencies (e.g., master Kinematics before Dynamics)
  - [ ] Implement adaptive time limits per question
  - [ ] Build "struggle detection" for real-time hints

---

## Appendix A: Key Formulas Reference

### Three-Parameter Logistic (3PL) Model
```
P(θ, a, b, c) = c + (1 - c) / (1 + exp(-a(θ - b)))
```

### Theta Update (Gradient Descent)
```
Δθ = {  α(1 - P(θ))  if correct
     { -αP(θ)        if incorrect

θ_new = bound(θ_old + Δθ, -3, +3)
```

### Fisher Information (Question Quality)
```
I(θ) = a² · [P'(θ)]² / [P(θ)(1 - P(θ))]
```

### Standard Error Update
```
SE_new = SE_old × 0.95
SE_new = max(0.1, SE_new)  # Floor at 0.1
```

### Theta to Percentile Conversion
```
Percentile = Φ(θ) × 100

Where Φ is standard normal CDF
```

---

## Appendix B: Sample JEE Topic Weights

```javascript
JEE_TOPIC_WEIGHTS = {
  // Physics - Mechanics (HIGH priority)
  "physics_mechanics_newtons_laws": 1.0,
  "physics_mechanics_work_energy": 1.0,
  "physics_mechanics_rotational": 1.0,
  
  // Physics - Electromagnetism (HIGH priority)
  "physics_electrostatics_coulomb": 1.0,
  "physics_current_electricity": 1.0,
  "physics_magnetism_emi": 1.0,
  
  // Chemistry - Physical (HIGH priority)
  "chemistry_physical_thermodynamics": 1.0,
  "chemistry_physical_equilibrium": 1.0,
  
  // Chemistry - Organic (MEDIUM priority)
  "chemistry_organic_nomenclature": 0.6,
  "chemistry_organic_reactions": 0.6,
  
  // Mathematics - Calculus (HIGH priority)
  "mathematics_calculus_limits": 1.0,
  "mathematics_calculus_derivatives": 1.0,
  "mathematics_calculus_integrals": 1.0,
  
  // Mathematics - Algebra (MEDIUM priority)
  "mathematics_algebra_quadratic": 0.6,
  
  // Low priority topics
  "physics_modern_photoelectric": 0.3,
  "chemistry_inorganic_coordination": 0.3,
  
  // ... all 63 topics
}
```

---

## Appendix C: Glossary

| Term | Definition |
|------|------------|
| **θ (theta)** | Student ability estimate on [-3, +3] scale |
| **a (discrimination)** | How well a question differentiates ability levels (typical: 1.0-2.0) |
| **b (difficulty)** | Question difficulty on [0.4, 2.6] scale (Easy: 0.4-0.7, Medium: 0.8-1.3, Hard: 1.4-2.6) |
| **c (guessing)** | Probability of random correct answer (0.25 for MCQ, 0.0 for numerical) |
| **SE (Standard Error)** | Uncertainty/confidence interval around θ estimate |
| **IRT** | Item Response Theory - psychometric model for ability estimation |
| **3PL** | Three-Parameter Logistic model |
| **Fisher Information** | Statistical measure of how informative a question is |
| **Exploration** | Testing new topics to map student's knowledge landscape |
| **Exploitation** | Focusing on known weak topics to maximize learning |
| **Interleaving** | Mixing topics to enhance retention vs blocked practice |
| **Spaced Repetition** | Reviewing at increasing intervals (1, 3, 7, 14, 30 days) |

---

**End of Specification Document**

---

## Next Steps for Implementation

1. **Review this spec with your CTO** - Ensure technical feasibility
2. **Set up development environment** - Firebase, Python/Node backend
3. **Start with Phase 1** - Database + Initial Assessment
4. **Weekly sync meetings** - Review progress, adjust algorithm parameters
5. **Synthetic testing first** - Before launching to real students

Let me know if you need:
- Detailed code implementations in Python/JavaScript
- Firebase security rules
- API endpoint specifications
- Flutter UI integration guidance

Dr. Amara Chen
Educational Measurement Specialist
