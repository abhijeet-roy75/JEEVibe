# JEEVibe IIDP Algorithm - Python Implementation
# Production-Ready Code for Firebase + Python Backend

import math
import random
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from scipy.stats import norm
import firebase_admin
from firebase_admin import credentials, firestore

# ============================================================================
# DATA STRUCTURES
# ============================================================================

@dataclass
class IRTParameters:
    """IRT parameters for a question"""
    difficulty_b: float  # [0.4, 2.6] - JEEVibe actual range (Easy: 0.4-0.7, Medium: 0.8-1.3, Hard: 1.4-2.6)
    discrimination_a: float  # Typically 1.0 to 2.0
    guessing_c: float  # 0.25 for MCQ, 0.0 for numerical
    calibration_status: str = "estimated"

@dataclass
class TopicTheta:
    """Theta estimate for a specific topic"""
    theta: float
    percentile: float
    confidence_SE: float
    attempts: int
    accuracy: Optional[float]
    last_updated: datetime

@dataclass
class Question:
    """Question object from Firebase"""
    question_id: str
    topic: str
    chapter: str
    subject: str
    irt_parameters: IRTParameters
    question_type: str  # "mcq_single" or "numerical"
    difficulty: str  # "easy", "medium", "hard"
    priority: str  # "HIGH", "MEDIUM", "LOW"
    time_estimate: int
    
@dataclass
class StudentResponse:
    """Student's response to a question"""
    response_id: str
    student_id: str
    question_id: str
    topic: str
    student_answer: str
    correct_answer: str
    is_correct: bool
    time_taken_seconds: int
    theta_before: float
    theta_after: float
    theta_delta: float
    answered_at: datetime

# ============================================================================
# CONFIGURATION CONSTANTS
# ============================================================================

# Theta bounds
THETA_MIN = -3.0
THETA_MAX = 3.0

# Learning parameters
BASE_LEARNING_RATE = 0.3
LEARNING_RATE_DECAY = 0.02
SE_REDUCTION_RATE = 0.95
SE_FLOOR = 0.1
SE_CEILING = 0.6

# Phase transition - QUIZ-BASED (not day-based)
EXPLORATION_END_QUIZ = 14  # Quizzes 0-13 = exploration, 14+ = exploitation
EXPLORATION_START_RATIO = 0.6
EXPLORATION_END_RATIO = 0.3

# Quiz composition
QUIZ_LENGTH = 10
WEAK_TOPIC_COUNT_EXPLOITATION = 7
MAINTENANCE_COUNT_EXPLOITATION = 2
REVIEW_COUNT = 1

# Difficulty matching
OPTIMAL_DIFFICULTY_RANGE = 0.5

# Difficulty ranges based on actual JEEVibe question bank analysis (275 questions analyzed)
# Overall range: [0.40, 2.60], Mean: 1.33
DIFFICULTY_EASY_MIN = 0.4
DIFFICULTY_EASY_MAX = 0.7
DIFFICULTY_MEDIUM_MIN = 0.8
DIFFICULTY_MEDIUM_MAX = 1.3
DIFFICULTY_HARD_MIN = 1.4
DIFFICULTY_HARD_MAX = 2.0
DIFFICULTY_VERY_HARD_MIN = 2.0
DIFFICULTY_VERY_HARD_MAX = 2.6

# For exploration (first attempt on topic), use neutral medium difficulty
EXPLORATION_TARGET_DIFFICULTY = 0.9

# Recency filtering
RECENT_QUESTIONS_WINDOW_DAYS = 30

# Circuit Breaker Configuration (Death Spiral Prevention)
CIRCUIT_BREAKER_THRESHOLD = 5           # Consecutive failures to trigger
CIRCUIT_BREAKER_REALTIME_THRESHOLD = 3  # Failures in current quiz
RECOVERY_QUIZ_EASY_COUNT = 7            # Easy questions in recovery
RECOVERY_QUIZ_MEDIUM_COUNT = 2          # Medium questions
RECOVERY_QUIZ_REVIEW_COUNT = 1          # Review questions
CIRCUIT_BREAKER_COOLDOWN = 2            # Quizzes before re-checking
RECOVERY_EASY_MIN = 0.4                 # Recovery quiz easy range
RECOVERY_EASY_MAX = 0.7
RECOVERY_MEDIUM_MIN = 0.8               # Recovery quiz medium range
RECOVERY_MEDIUM_MAX = 1.1

# JEE Topic Weights (High=1.0, Medium=0.6, Low=0.3)
JEE_TOPIC_WEIGHTS = {
    # Physics - Mechanics
    "physics_mechanics_newtons_laws": 1.0,
    "physics_mechanics_work_energy": 1.0,
    "physics_mechanics_kinematics": 1.0,
    "physics_mechanics_rotational": 1.0,
    "physics_mechanics_gravitation": 0.6,
    "physics_mechanics_shm": 0.6,
    
    # Physics - Electromagnetism
    "physics_electrostatics_coulomb": 1.0,
    "physics_current_electricity": 1.0,
    "physics_magnetism_emi": 1.0,
    "physics_ac_circuits": 0.6,
    
    # Physics - Modern
    "physics_modern_photoelectric": 0.3,
    "physics_modern_atoms": 0.3,
    
    # Chemistry - Physical
    "chemistry_physical_thermodynamics": 1.0,
    "chemistry_physical_equilibrium": 1.0,
    "chemistry_physical_kinetics": 1.0,
    "chemistry_physical_electrochemistry": 0.6,
    
    # Chemistry - Organic
    "chemistry_organic_nomenclature": 0.6,
    "chemistry_organic_reactions": 1.0,
    "chemistry_organic_mechanisms": 0.6,
    
    # Chemistry - Inorganic
    "chemistry_inorganic_coordination": 0.3,
    "chemistry_inorganic_periodicity": 0.6,
    
    # Mathematics - Calculus
    "mathematics_calculus_limits": 1.0,
    "mathematics_calculus_derivatives": 1.0,
    "mathematics_calculus_integrals": 1.0,
    "mathematics_calculus_differential_equations": 0.6,
    
    # Mathematics - Algebra
    "mathematics_algebra_quadratic": 0.6,
    "mathematics_algebra_sequences": 0.6,
    "mathematics_algebra_complex": 1.0,
    
    # Mathematics - Coordinate Geometry
    "mathematics_coord_geom_circle": 1.0,
    "mathematics_coord_geom_parabola": 0.6,
    
    # ... Add all 63 topics with their weights
}

# Topic prerequisite depths (0 = foundational, 3 = advanced)
TOPIC_PREREQUISITE_DEPTH = {
    "physics_mechanics_kinematics": 0,
    "physics_mechanics_newtons_laws": 1,
    "physics_mechanics_work_energy": 2,
    "physics_mechanics_rotational": 3,
    # ... Map all topics
}

# ============================================================================
# CORE IRT FUNCTIONS
# ============================================================================

def calculate_probability_3PL(theta: float, difficulty_b: float, 
                              discrimination_a: float, guessing_c: float) -> float:
    """
    Calculate probability of correct answer using 3-Parameter Logistic IRT model.
    
    P(θ) = c + (1 - c) / (1 + exp(-a(θ - b)))
    
    Args:
        theta: Student ability [-3, +3]
        difficulty_b: Question difficulty [0.4, 2.6] (JEEVibe range)
        discrimination_a: Discrimination parameter [1.0, 2.0]
        guessing_c: Guessing parameter [0.0, 0.25]
    
    Returns:
        Probability of correct answer [0, 1]
    """
    exponent = -discrimination_a * (theta - difficulty_b)
    
    # Prevent overflow
    if exponent > 20:
        return guessing_c
    elif exponent < -20:
        return 1.0
    
    probability = guessing_c + (1 - guessing_c) / (1 + math.exp(exponent))
    
    return max(0.0, min(1.0, probability))


def calculate_fisher_information(theta: float, difficulty_b: float,
                                 discrimination_a: float, guessing_c: float) -> float:
    """
    Calculate Fisher information I(θ) - how informative a question is.
    
    Higher information = better question for ability estimation.
    
    I(θ) = a² * [P'(θ)]² / [P(θ)(1 - P(θ))]
    
    Args:
        theta: Student ability
        difficulty_b: Question difficulty
        discrimination_a: Discrimination parameter
        guessing_c: Guessing parameter
    
    Returns:
        Fisher information value
    """
    # Calculate P(θ)
    P = calculate_probability_3PL(theta, difficulty_b, discrimination_a, guessing_c)
    
    # Calculate derivative P'(θ)
    exponent = -discrimination_a * (theta - difficulty_b)
    if abs(exponent) > 20:  # Prevent overflow
        return 0.0
    
    exp_val = math.exp(exponent)
    denominator = (1 + exp_val) ** 2
    
    P_prime = discrimination_a * (1 - guessing_c) * exp_val / denominator
    
    # Calculate Fisher information
    Q = 1 - P
    
    if P > 0.01 and P < 0.99:  # Avoid division by zero
        information = (discrimination_a ** 2) * (P_prime ** 2) / (P * Q)
    else:
        information = 0.0
    
    return information


def bound_theta(theta: float) -> float:
    """Enforce hard bounds at [-3.0, +3.0]"""
    return max(THETA_MIN, min(THETA_MAX, theta))


def theta_to_percentile(theta: float) -> float:
    """
    Convert theta to percentile using standard normal CDF.
    θ ~ N(0, 1) approximately.
    
    Args:
        theta: Ability estimate [-3, +3]
    
    Returns:
        Percentile [0, 100]
    """
    return norm.cdf(theta) * 100


def percentile_to_theta(percentile: float) -> float:
    """
    Convert percentile to theta (inverse of theta_to_percentile).
    
    Args:
        percentile: Percentile [0, 100]
    
    Returns:
        Theta estimate [-3, +3]
    """
    return norm.ppf(percentile / 100)

# ============================================================================
# INITIAL ASSESSMENT PROCESSING
# ============================================================================

def accuracy_to_theta_mapping(accuracy: float, num_questions: int = 1) -> float:
    """
    Convert raw accuracy to initial theta estimate.
    
    Args:
        accuracy: Proportion correct [0, 1]
        num_questions: Number of questions (affects confidence in extreme scores)
    
    Returns:
        Initial theta estimate [-3, +3]
    """
    # Handle extreme cases
    if accuracy == 1.0:
        return 2.0 if num_questions >= 5 else 1.5
    elif accuracy == 0.0:
        return -2.0 if num_questions >= 5 else -1.5
    
    # Standard mapping
    if accuracy < 0.20:
        return -2.5
    elif accuracy < 0.40:
        return -1.5
    elif accuracy < 0.60:
        return -0.5
    elif accuracy < 0.75:
        return 0.5
    elif accuracy < 0.90:
        return 1.5
    else:
        return 2.5


def calculate_initial_SE(num_questions: int, accuracy: float) -> float:
    """
    Calculate standard error (confidence interval) for theta estimate.
    
    Args:
        num_questions: Number of questions answered
        accuracy: Proportion correct [0, 1]
    
    Returns:
        Standard error [0.15, 0.6]
    """
    # Base SE decreases with sqrt(n)
    base_SE = 1.0 / math.sqrt(num_questions)
    
    # Adjust for informativeness: accuracy near 0.5 is most informative
    information_penalty = 1 + abs(accuracy - 0.5)
    
    SE = base_SE * information_penalty
    
    # Bound between floor and ceiling
    return min(SE_CEILING, max(SE_FLOOR, SE))


def process_initial_assessment(student_id: str, responses: List[Dict]) -> Dict:
    """
    Process the 30-question initial assessment to calculate initial theta per topic.
    
    Args:
        student_id: Unique student identifier
        responses: List of response dicts with {question_id, answer, is_correct, time_taken}
    
    Returns:
        student_profile: Dictionary with theta estimates per topic
    """
    # Get question details from Firebase (would be actual DB call)
    db = firestore.client()
    
    # Group responses by topic
    topic_responses = {}
    for response in responses:
        # Fetch question to get topic
        question_ref = db.collection('questions').document(response['question_id'])
        question_data = question_ref.get().to_dict()
        topic = question_data['topic']
        
        if topic not in topic_responses:
            topic_responses[topic] = []
        topic_responses[topic].append(response)
    
    # Calculate theta per topic
    theta_estimates = {}
    
    for topic, topic_questions in topic_responses.items():
        correct_count = sum(1 for q in topic_questions if q['is_correct'])
        total_count = len(topic_questions)
        accuracy = correct_count / total_count if total_count > 0 else 0.0
        
        # Map accuracy to theta
        initial_theta = accuracy_to_theta_mapping(accuracy, total_count)
        
        # Calculate standard error
        standard_error = calculate_initial_SE(total_count, accuracy)
        
        theta_estimates[topic] = {
            "theta": bound_theta(initial_theta),
            "percentile": theta_to_percentile(initial_theta),
            "confidence_SE": standard_error,
            "attempts": total_count,
            "accuracy": accuracy,
            "last_updated": datetime.utcnow().isoformat()
        }
    
    # Calculate overall theta (weighted by JEE importance)
    overall_theta = calculate_weighted_overall_theta(theta_estimates)
    
    # Build student profile
    student_profile = {
        "student_id": student_id,
        "theta_by_topic": theta_estimates,
        "overall_theta": overall_theta,
        "overall_percentile": theta_to_percentile(overall_theta),
        "assessment_completed_at": datetime.utcnow().isoformat(),
        "completed_quiz_count": 0,  # PRIMARY: Start at 0, increments with each quiz
        "current_day": 0,  # Analytics only: days since assessment
        "learning_phase": "exploration",
        "phase_switched_at_quiz": None,
        "total_questions_solved": len(responses),
        "topic_attempt_counts": {topic: len(qs) for topic, qs in topic_responses.items()},
        "subject_balance": calculate_subject_balance_initial(theta_estimates),
        "topics_explored": len(theta_estimates),
        "topics_confident": sum(1 for v in theta_estimates.values() if v["attempts"] >= 2)
    }
    
    # Save to Firebase
    db.collection('students').document(student_id).set(student_profile)
    
    return student_profile


def calculate_weighted_overall_theta(theta_estimates: Dict) -> float:
    """
    Calculate overall theta as weighted average by JEE topic importance.
    
    Args:
        theta_estimates: Dict of {topic: {theta, ...}}
    
    Returns:
        Weighted overall theta
    """
    total_weight = 0
    weighted_sum = 0
    
    for topic, data in theta_estimates.items():
        weight = JEE_TOPIC_WEIGHTS.get(topic, 0.5)  # Default to medium if not found
        weighted_sum += data["theta"] * weight
        total_weight += weight
    
    return weighted_sum / total_weight if total_weight > 0 else 0.0


def calculate_subject_balance_initial(theta_estimates: Dict) -> Dict:
    """
    Calculate current distribution of questions across Physics, Chemistry, Math.
    
    Args:
        theta_estimates: Dict of {topic: {attempts, ...}}
    
    Returns:
        Dict of {subject: proportion}
    """
    subject_counts = {"physics": 0, "chemistry": 0, "mathematics": 0}
    
    for topic, data in theta_estimates.items():
        subject = get_subject_from_topic(topic)
        subject_counts[subject] += data["attempts"]
    
    total = sum(subject_counts.values())
    
    if total == 0:
        return {"physics": 1/3, "chemistry": 1/3, "mathematics": 1/3}
    
    return {subject: count / total for subject, count in subject_counts.items()}


def get_subject_from_topic(topic: str) -> str:
    """Extract subject from topic string"""
    if topic.startswith("physics_"):
        return "physics"
    elif topic.startswith("chemistry_"):
        return "chemistry"
    elif topic.startswith("mathematics_"):
        return "mathematics"
    else:
        return "unknown"

# ============================================================================
# THETA UPDATE AFTER EACH QUESTION
# ============================================================================

def update_theta_after_response(student_id: str, question_id: str, 
                                is_correct: bool, time_taken: int) -> float:
    """
    Update student's theta for the relevant topic after answering a question.
    
    Args:
        student_id: Unique student identifier
        question_id: Question that was answered
        is_correct: Whether answer was correct
        time_taken: Time spent in seconds
    
    Returns:
        updated_theta: New theta value for the topic
    """
    db = firestore.client()
    
    # Load question metadata
    question_ref = db.collection('questions').document(question_id)
    question_data = question_ref.get().to_dict()
    
    topic = question_data['topic']
    irt_params = question_data['irt_parameters']
    difficulty_b = irt_params['difficulty_b']
    discrimination_a = irt_params['discrimination_a']
    guessing_c = irt_params['guessing_c']
    
    # Load current student theta
    student_ref = db.collection('students').document(student_id)
    student_data = student_ref.get().to_dict()
    
    # Get topic theta (or initialize if new)
    if topic not in student_data['theta_by_topic']:
        topic_theta = get_theta_for_untested_topic(student_id, topic, student_data)
    else:
        topic_theta = student_data['theta_by_topic'][topic]
    
    current_theta = topic_theta['theta']
    current_SE = topic_theta['confidence_SE']
    attempts = topic_theta['attempts']
    
    # Calculate expected probability
    P_correct = calculate_probability_3PL(current_theta, difficulty_b, 
                                         discrimination_a, guessing_c)
    
    # Learning rate (decreases with experience)
    learning_rate = BASE_LEARNING_RATE / (1 + LEARNING_RATE_DECAY * attempts)
    
    # Calculate theta update
    if is_correct:
        delta = learning_rate * (1 - P_correct)
    else:
        delta = -learning_rate * P_correct
    
    # Apply update with bounds
    new_theta = bound_theta(current_theta + delta)
    
    # Update standard error (decreases with more data)
    new_SE = current_SE * SE_REDUCTION_RATE
    new_SE = max(SE_FLOOR, new_SE)
    
    # Update in database
    updated_topic_theta = {
        "theta": new_theta,
        "percentile": theta_to_percentile(new_theta),
        "confidence_SE": new_SE,
        "attempts": attempts + 1,
        "last_updated": datetime.utcnow().isoformat()
    }
    
    # Update cumulative accuracy
    if 'accuracy' in topic_theta and topic_theta['accuracy'] is not None:
        old_accuracy = topic_theta['accuracy']
        new_accuracy = (old_accuracy * attempts + (1 if is_correct else 0)) / (attempts + 1)
        updated_topic_theta['accuracy'] = new_accuracy
    else:
        updated_topic_theta['accuracy'] = 1.0 if is_correct else 0.0
    
    student_ref.update({
        f'theta_by_topic.{topic}': updated_topic_theta,
        f'topic_attempt_counts.{topic}': firestore.Increment(1),
        'total_questions_solved': firestore.Increment(1)
    })
    
    # Log response
    response_data = {
        "response_id": f"resp_{student_id}_{question_id}_{int(datetime.utcnow().timestamp())}",
        "student_id": student_id,
        "question_id": question_id,
        "topic": topic,
        "is_correct": is_correct,
        "time_taken_seconds": time_taken,
        "theta_before": current_theta,
        "theta_after": new_theta,
        "theta_delta": delta,
        "confidence_SE_before": current_SE,
        "confidence_SE_after": new_SE,
        "answered_at": datetime.utcnow().isoformat()
    }
    
    db.collection('student_responses').document(student_id).collection('responses').add(response_data)
    
    return new_theta


def get_theta_for_untested_topic(student_id: str, topic: str, student_data: Dict) -> Dict:
    """
    Estimate theta for a topic the student hasn't attempted yet.
    Use subject-level average as prior.
    
    Args:
        student_id: Student identifier
        topic: Topic identifier
        student_data: Student profile data
    
    Returns:
        Estimated theta data for topic
    """
    # Get subject from topic
    subject = get_subject_from_topic(topic)
    
    # Find all tested topics in same subject
    subject_topics = [t for t in student_data['theta_by_topic'].keys()
                     if get_subject_from_topic(t) == subject]
    
    if len(subject_topics) > 0:
        # Use subject average
        subject_thetas = [student_data['theta_by_topic'][t]['theta']
                         for t in subject_topics]
        estimated_theta = sum(subject_thetas) / len(subject_thetas)
    else:
        # Use overall theta
        estimated_theta = student_data.get('overall_theta', 0.0)
    
    return {
        "theta": estimated_theta,
        "percentile": theta_to_percentile(estimated_theta),
        "confidence_SE": SE_CEILING,  # High uncertainty
        "attempts": 0,
        "accuracy": None,
        "last_updated": None
    }

# ============================================================================
# CIRCUIT BREAKER: DEATH SPIRAL PREVENTION
# ============================================================================

def check_circuit_breaker(student_id: str) -> bool:
    """
    Check if student needs intervention due to consecutive failures.
    
    Circuit breaker triggers if:
    - 5+ consecutive incorrect answers in recent session
    
    Args:
        student_id: Unique student identifier
    
    Returns:
        True if circuit breaker should activate (override normal quiz)
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
    
    if len(responses_list) < CIRCUIT_BREAKER_THRESHOLD:
        return False  # Not enough data
    
    # Count consecutive failures from most recent
    consecutive_failures = 0
    for response in responses_list:
        if not response['is_correct']:
            consecutive_failures += 1
        else:
            break  # Stop at first correct answer
    
    # Trigger: 5+ consecutive failures
    return consecutive_failures >= CIRCUIT_BREAKER_THRESHOLD


def generate_recovery_quiz(student_id: str, student_data: Dict) -> List[Dict]:
    """
    Generate confidence-building quiz after circuit breaker triggers.
    
    Strategy (based on actual JEEVibe question bank distribution):
    - 7 EASY questions (b = 0.4 to 0.7): 75-85% success
    - 2 MEDIUM questions (b = 0.8 to 1.1): 60-70% success  
    - 1 REVIEW question (previously correct): ~90% success
    
    Goal: 70-80% overall success rate to rebuild confidence
    
    Args:
        student_id: Unique student identifier
        student_data: Student profile data
    
    Returns:
        List of 10 recovery questions
    """
    db = firestore.client()
    
    theta_by_topic = student_data['theta_by_topic']
    recent_questions = get_recent_questions(student_id, days=RECENT_QUESTIONS_WINDOW_DAYS)
    
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
        # Select EASY: b = 0.4 to 0.7 (actual easy range in JEEVibe question bank)
        # This gives 75-85% success probability for struggling students
        easy_questions = select_questions_by_difficulty_range(
            topic=topic_name,
            difficulty_min=RECOVERY_EASY_MIN,
            difficulty_max=RECOVERY_EASY_MAX,
            count=2,
            recent_questions=recent_questions,
            discrimination_min=1.0  # Relaxed requirement
        )
        recovery_questions.extend(easy_questions)
    
    # ========================================
    # 2 MEDIUM questions (gentle challenge)
    # ========================================
    
    for topic_name, topic_data in weak_topics[:2]:
        # Select MEDIUM: b = 0.8 to 1.1 (actual medium range in JEEVibe question bank)
        medium_questions = select_questions_by_difficulty_range(
            topic=topic_name,
            difficulty_min=RECOVERY_MEDIUM_MIN,
            difficulty_max=RECOVERY_MEDIUM_MAX,
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
    
    # Save metadata
    quiz_id = f"recovery_quiz_{datetime.utcnow().strftime('%Y-%m-%d_%H-%M')}"
    completed_quiz_count = student_data.get('completed_quiz_count', 0)
    save_quiz_metadata(student_id, quiz_id, completed_quiz_count, "recovery", interleaved)
    
    return interleaved


def select_questions_by_difficulty_range(topic: str, difficulty_min: float,
                                        difficulty_max: float, count: int,
                                        recent_questions: List[str],
                                        discrimination_min: float) -> List[Dict]:
    """
    Select questions within specific difficulty range.
    Used for circuit breaker recovery quizzes.
    
    Args:
        topic: Topic identifier
        difficulty_min: Minimum difficulty (b parameter)
        difficulty_max: Maximum difficulty (b parameter)
        count: Number of questions to select
        recent_questions: Recently answered question IDs to exclude
        discrimination_min: Minimum discrimination threshold
    
    Returns:
        List of question dictionaries
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
    
    if len(candidates) == 0:
        # Fallback: relax constraints
        questions = db.collection('questions').where('topic', '==', topic).stream()
        candidates = [q.to_dict() for q in questions 
                     if q.to_dict()['question_id'] not in recent_questions]
    
    # Random selection (avoid always same "easy" questions)
    selected = random.sample(candidates, min(count, len(candidates)))
    
    return selected


def get_previously_correct_question(student_id: str, recent_questions: List[str],
                                   from_topics: List[str]) -> Optional[Dict]:
    """
    Get a question student answered correctly 7-14 days ago.
    High probability they still remember → confidence boost.
    
    Args:
        student_id: Student identifier
        recent_questions: Recently answered question IDs to exclude
        from_topics: Topics to select from
    
    Returns:
        Question dictionary or None
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
    
    q_ref = db.collection('questions').document(question_id)
    return q_ref.get().to_dict()


def log_circuit_breaker_event(student_id: str, trigger_reason: str, recovery_quiz: bool):
    """
    Log circuit breaker activation for analytics.
    
    Args:
        student_id: Student identifier
        trigger_reason: Why circuit breaker triggered
        recovery_quiz: Whether recovery quiz was generated
    """
    db = firestore.client()
    
    event_data = {
        "student_id": student_id,
        "event_type": "circuit_breaker_triggered",
        "trigger_reason": trigger_reason,
        "recovery_quiz_generated": recovery_quiz,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    db.collection('system_events').add(event_data)


# ============================================================================
# DAILY QUIZ GENERATION
# ============================================================================

def generate_daily_quiz(student_id: str, completed_quiz_count: int = None) -> List[Dict]:
    """
    Master function to generate personalized 10-question daily quiz.
    Implements hybrid Exploration → Exploitation strategy.
    
    Args:
        student_id: Unique student identifier
        completed_quiz_count: Number of quizzes completed (0-indexed). If None, fetches from DB.
                             Phase transition at quiz 14 (0-13 = exploration, 14+ = exploitation)
    
    Returns:
        quiz: List of 10 question dictionaries
    """
    db = firestore.client()
    
    # Load student profile
    student_ref = db.collection('students').document(student_id)
    student_data = student_ref.get().to_dict()
    
    # Get completed quiz count from DB if not provided
    if completed_quiz_count is None:
        completed_quiz_count = student_data.get('completed_quiz_count', 0)
    
    # ========================================
    # STEP 0: CIRCUIT BREAKER CHECK
    # ========================================
    
    if check_circuit_breaker(student_id):
        print(f"⚠️ Circuit breaker activated for {student_id}")
        # Override normal quiz with recovery quiz
        recovery_quiz = generate_recovery_quiz(student_id, student_data)
        
        # Still increment quiz count
        student_ref.update({
            'completed_quiz_count': firestore.Increment(1),
            'learning_phase': 'recovery',
            'last_quiz_completed_at': datetime.utcnow().isoformat()
        })
        
        return recovery_quiz
    
    # ========================================
    # STEP 1: Normal quiz generation
    # ========================================
    
    theta_by_topic = student_data['theta_by_topic']
    topic_attempts = student_data['topic_attempt_counts']
    
    # Get recent questions (last 30 days)
    recent_questions_30d = get_recent_questions(student_id, days=RECENT_QUESTIONS_WINDOW_DAYS)
    
    # Determine learning phase based on QUIZ COUNT (not days)
    if completed_quiz_count < EXPLORATION_END_QUIZ:
        learning_phase = "exploration"
        # Linear decay from 60% to 30% over 14 quizzes
        exploration_ratio = max(EXPLORATION_START_RATIO - (completed_quiz_count * 0.04), 
                               EXPLORATION_END_RATIO)
    else:
        learning_phase = "exploitation"
        exploration_ratio = 0.0
        
        # Mark phase transition if this is the first exploitation quiz
        if student_data.get('phase_switched_at_quiz') is None:
            student_ref.update({'phase_switched_at_quiz': completed_quiz_count})
    
    quiz_questions = []
    
    # ========================================
    # EXPLORATION PHASE (Quizzes 0-13)
    # ========================================
    
    if learning_phase == "exploration":
        num_exploration = int(QUIZ_LENGTH * exploration_ratio)
        num_deliberate = QUIZ_LENGTH - num_exploration - REVIEW_COUNT
        num_review = REVIEW_COUNT
        
        # 1. Get unexplored topics
        unexplored_topics = get_unexplored_topics(topic_attempts, min_attempts=2)
        
        # 2. Prioritize by strategic importance
        exploration_topics = prioritize_exploration_topics(
            unexplored_topics,
            student_data['subject_balance']
        )[:num_exploration]
        
        # 3. Select exploration questions
        for topic in exploration_topics:
            # For first attempt, use neutral medium difficulty from actual question bank
            # Question bank range: 0.4-2.6, with mean at 1.33
            # Use 0.9 (low-medium) for exploration to avoid frustrating new students
            if topic not in theta_by_topic or topic_attempts.get(topic, 0) == 0:
                target_difficulty = EXPLORATION_TARGET_DIFFICULTY  # 0.9
            else:
                target_difficulty = theta_by_topic[topic]['theta']
            
            question = select_optimal_question_IRT(
                topic, target_difficulty, recent_questions_30d, 
                discrimination_min=1.4
            )
            if question:
                quiz_questions.append(question)
        
        # 4. Select deliberate practice questions
        tested_topics = [t for t, count in topic_attempts.items() if count >= 2]
        weak_topics = rank_topics_by_weakness(tested_topics, theta_by_topic)
        
        for topic in weak_topics[:num_deliberate]:
            question = select_optimal_question_IRT(
                topic, theta_by_topic[topic]['theta'], 
                recent_questions_30d, discrimination_min=1.4
            )
            if question:
                quiz_questions.append(question)
        
        # 5. Add review question
        review_q = get_spaced_review_question(student_id, recent_questions_30d)
        if review_q:
            quiz_questions.append(review_q)
    
    # ========================================
    # EXPLOITATION PHASE (Quizzes 14+)
    # ========================================
    
    else:  # exploitation
        # 1. Rank all topics by priority
        all_topics = list(theta_by_topic.keys())
        ranked_topics = rank_topics_by_priority_formula(
            all_topics, theta_by_topic, topic_attempts, student_id
        )
        
        # 2. Select weak topics
        weak_topics = ranked_topics[:WEAK_TOPIC_COUNT_EXPLOITATION]
        
        for topic in weak_topics:
            question = select_optimal_question_IRT(
                topic, theta_by_topic[topic]['theta'],
                recent_questions_30d, discrimination_min=1.4
            )
            if question:
                quiz_questions.append(question)
        
        # 3. Select maintenance topics (strong topics)
        strong_topics = ranked_topics[-5:]  # Bottom 5 = strongest
        maintenance_topics = random.sample(strong_topics, 
                                          min(MAINTENANCE_COUNT_EXPLOITATION, len(strong_topics)))
        
        for topic in maintenance_topics:
            question = select_optimal_question_IRT(
                topic, theta_by_topic[topic]['theta'],
                recent_questions_30d, discrimination_min=1.0
            )
            if question:
                quiz_questions.append(question)
        
        # 4. Add review question
        review_q = get_spaced_review_question(student_id, recent_questions_30d)
        if review_q:
            quiz_questions.append(review_q)
    
    # ========================================
    # FINALIZE QUIZ
    # ========================================
    
    # Interleave to prevent topic clustering
    interleaved_quiz = interleave_questions_by_topic(quiz_questions)
    
    # Ensure exactly 10 questions
    final_quiz = interleaved_quiz[:QUIZ_LENGTH]
    
    # Save quiz metadata
    quiz_id = f"quiz_num{completed_quiz_count}_{datetime.utcnow().strftime('%Y-%m-%d_%H-%M')}"
    save_quiz_metadata(student_id, quiz_id, completed_quiz_count, learning_phase, final_quiz)
    
    # Increment completed_quiz_count in database
    student_ref.update({
        'completed_quiz_count': firestore.Increment(1),
        'learning_phase': learning_phase,
        'last_quiz_completed_at': datetime.utcnow().isoformat()
    })
    
    return final_quiz


# Helper functions for quiz generation

def get_recent_questions(student_id: str, days: int = 30) -> List[str]:
    """Get question IDs answered in last N days"""
    db = firestore.client()
    cutoff = datetime.utcnow() - timedelta(days=days)
    
    responses = db.collection('student_responses').document(student_id)\
                  .collection('responses')\
                  .where('answered_at', '>=', cutoff.isoformat())\
                  .stream()
    
    return [r.to_dict()['question_id'] for r in responses]


def get_unexplored_topics(topic_attempts: Dict, min_attempts: int = 2) -> List[str]:
    """Get topics with fewer than min_attempts"""
    all_topics = list(JEE_TOPIC_WEIGHTS.keys())
    return [topic for topic in all_topics 
            if topic_attempts.get(topic, 0) < min_attempts
            and JEE_TOPIC_WEIGHTS.get(topic, 0) >= 0.6]  # High/Medium only


def prioritize_exploration_topics(unexplored_topics: List[str], 
                                  subject_balance: Dict) -> List[str]:
    """
    Rank unexplored topics by strategic importance.
    Returns sorted list (highest priority first).
    """
    scored_topics = []
    
    for topic in unexplored_topics:
        # Component 1: JEE Weightage (50%)
        weightage_score = JEE_TOPIC_WEIGHTS.get(topic, 0.5) / 1.0
        
        # Component 2: Prerequisite Depth (30%)
        prereq_depth = TOPIC_PREREQUISITE_DEPTH.get(topic, 1)
        prereq_score = 1.0 - (prereq_depth / 3.0)
        
        # Component 3: Subject Balance (20%)
        subject = get_subject_from_topic(topic)
        current_coverage = subject_balance.get(subject, 0.33)
        target_coverage = 1/3
        balance_score = 1.0 - abs(current_coverage - target_coverage)
        
        # Combined priority
        priority = (
            weightage_score * 0.5 +
            prereq_score * 0.3 +
            balance_score * 0.2
        )
        
        scored_topics.append((topic, priority))
    
    return [topic for topic, _ in sorted(scored_topics, key=lambda x: x[1], reverse=True)]


def rank_topics_by_weakness(topics: List[str], theta_by_topic: Dict) -> List[str]:
    """Simple ranking by theta (ascending = weakest first)"""
    return sorted(topics, key=lambda t: theta_by_topic[t]['theta'])


def rank_topics_by_priority_formula(topics: List[str], theta_by_topic: Dict,
                                    topic_attempts: Dict, student_id: str) -> List[str]:
    """
    Rank topics by weakness priority for exploitation phase.
    Priority = weakness * 0.6 + recency * 0.2 + jee_weight * 0.2
    """
    scored_topics = []
    
    for topic in topics:
        theta = theta_by_topic[topic]['theta']
        
        # Component 1: Weakness (60%)
        normalized_theta = (theta + 3) / 6
        weakness_score = 1.0 - normalized_theta
        
        # Component 2: Recency (20%)
        days_since = days_since_last_attempt(topic, student_id)
        recency_score = min(1.0, days_since / 7)
        
        # Component 3: JEE Weight (20%)
        jee_weight = JEE_TOPIC_WEIGHTS.get(topic, 0.5)
        
        priority = (
            weakness_score * 0.6 +
            recency_score * 0.2 +
            jee_weight * 0.2
        )
        
        scored_topics.append((topic, priority))
    
    return [topic for topic, _ in sorted(scored_topics, key=lambda x: x[1], reverse=True)]


def days_since_last_attempt(topic: str, student_id: str) -> int:
    """Calculate days since last attempt of a topic"""
    db = firestore.client()
    
    responses = db.collection('student_responses').document(student_id)\
                  .collection('responses')\
                  .where('topic', '==', topic)\
                  .order_by('answered_at', direction=firestore.Query.DESCENDING)\
                  .limit(1)\
                  .stream()
    
    for r in responses:
        last_answered = datetime.fromisoformat(r.to_dict()['answered_at'])
        delta = datetime.utcnow() - last_answered
        return delta.days
    
    return 999  # Never attempted


def select_optimal_question_IRT(topic: str, target_theta: float, 
                               recent_questions: List[str],
                               discrimination_min: float) -> Optional[Dict]:
    """
    Select single best question using IRT optimization.
    
    Criteria:
    1. Difficulty matches ability: |b - θ| < 0.5
    2. High discrimination: a ≥ discrimination_min
    3. Not recently answered
    4. Maximizes Fisher information
    """
    db = firestore.client()
    
    # Query questions for topic
    questions_query = db.collection('questions')\
                       .where('topic', '==', topic)\
                       .stream()
    
    candidates = []
    for q_doc in questions_query:
        q_data = q_doc.to_dict()
        question_id = q_data['question_id']
        irt = q_data['irt_parameters']
        
        # Filter 1: Not recent
        if question_id in recent_questions:
            continue
        
        # Filter 2: Minimum discrimination
        if irt['discrimination_a'] < discrimination_min:
            continue
        
        # Filter 3: Difficulty within range
        if abs(irt['difficulty_b'] - target_theta) > OPTIMAL_DIFFICULTY_RANGE:
            continue
        
        candidates.append((q_data, irt))
    
    # If no candidates, relax constraints
    if len(candidates) == 0:
        candidates = [(q.to_dict(), q.to_dict()['irt_parameters']) 
                     for q in questions_query
                     if q.to_dict()['question_id'] not in recent_questions]
    
    if len(candidates) == 0:
        return None
    
    # Score by Fisher information
    scored = []
    for q_data, irt in candidates:
        info = calculate_fisher_information(
            target_theta, irt['difficulty_b'], 
            irt['discrimination_a'], irt['guessing_c']
        )
        scored.append((q_data, info))
    
    # Select highest information
    best = max(scored, key=lambda x: x[1])
    return best[0]


def interleave_questions_by_topic(questions: List[Dict]) -> List[Dict]:
    """
    Shuffle questions to prevent topic clustering.
    Ensures no two consecutive questions from same topic.
    """
    # Group by topic
    topic_groups = {}
    for q in questions:
        topic = q['topic']
        if topic not in topic_groups:
            topic_groups[topic] = []
        topic_groups[topic].append(q)
    
    # Interleave
    interleaved = []
    remaining_topics = list(topic_groups.keys())
    
    while remaining_topics:
        # Avoid same topic twice in a row
        if len(interleaved) > 0:
            last_topic = interleaved[-1]['topic']
            available = [t for t in remaining_topics if t != last_topic]
        else:
            available = remaining_topics
        
        if len(available) == 0:
            available = remaining_topics
        
        next_topic = random.choice(available)
        interleaved.append(topic_groups[next_topic].pop(0))
        
        if len(topic_groups[next_topic]) == 0:
            remaining_topics.remove(next_topic)
    
    return interleaved


def get_spaced_review_question(student_id: str, recent_questions: List[str]) -> Optional[Dict]:
    """
    Select one question for spaced repetition review.
    Intervals: 1, 3, 7, 14, 30 days
    """
    db = firestore.client()
    
    # Get past correct answers
    responses = db.collection('student_responses').document(student_id)\
                  .collection('responses')\
                  .where('is_correct', '==', True)\
                  .stream()
    
    reviewable = [r.to_dict() for r in responses 
                  if r.to_dict()['question_id'] not in recent_questions]
    
    if len(reviewable) == 0:
        return None
    
    # Score by review priority
    scored = []
    now = datetime.utcnow()
    
    for response in reviewable:
        answered_at = datetime.fromisoformat(response['answered_at'])
        days_since = (now - answered_at).days
        
        # Determine priority by interval
        if days_since >= 30:
            priority = 5
        elif days_since >= 14:
            priority = 4
        elif days_since >= 7:
            priority = 3
        elif days_since >= 3:
            priority = 2
        elif days_since >= 1:
            priority = 1
        else:
            continue
        
        scored.append((response['question_id'], priority, days_since))
    
    if len(scored) == 0:
        return None
    
    # Pick highest priority, longest time
    best = max(scored, key=lambda x: (x[1], x[2]))
    question_id = best[0]
    
    q_ref = db.collection('questions').document(question_id)
    return q_ref.get().to_dict()


def save_quiz_metadata(student_id: str, quiz_id: str, completed_quiz_count: int,
                      learning_phase: str, questions: List[Dict]):
    """Save quiz metadata to Firebase for analytics"""
    db = firestore.client()
    
    # Calculate current day for analytics
    student_ref = db.collection('students').document(student_id)
    student_data = student_ref.get().to_dict()
    assessment_date = datetime.fromisoformat(student_data['assessment_completed_at'])
    current_day = (datetime.utcnow() - assessment_date).days
    
    quiz_data = {
        "quiz_id": quiz_id,
        "student_id": student_id,
        "quiz_number": completed_quiz_count,  # PRIMARY: quiz count
        "current_day": current_day,  # Analytics: calendar days
        "learning_phase": learning_phase,
        "generated_at": datetime.utcnow().isoformat(),
        "questions": [
            {
                "question_id": q['question_id'],
                "topic": q['topic'],
                "difficulty_b": q['irt_parameters']['difficulty_b'],
                "position": i + 1
            }
            for i, q in enumerate(questions)
        ],
        "topics_covered": list(set(q['topic'] for q in questions))
    }
    
    db.collection('quizzes').document(student_id)\
      .collection('quizzes').document(quiz_id).set(quiz_data)


# ============================================================================
# MAIN EXECUTION FLOW
# ============================================================================

if __name__ == "__main__":
    # Example usage
    
    # Initialize Firebase (you'll need to provide credentials)
    # cred = credentials.Certificate('path/to/serviceAccountKey.json')
    # firebase_admin.initialize_app(cred)
    
    # Example 1: Process initial assessment
    sample_responses = [
        {"question_id": "ASSESS_PHY_MECH_001", "answer": "A", "is_correct": True, "time_taken": 95},
        {"question_id": "ASSESS_PHY_MECH_002", "answer": "C", "is_correct": False, "time_taken": 140},
        # ... 28 more
    ]
    
    # profile = process_initial_assessment("student_12345", sample_responses)
    # print(f"Initial theta: {profile['overall_theta']}")
    
    # Example 2: Generate daily quiz (quiz-based, not day-based)
    # completed_quiz_count = 0  # First quiz after assessment
    # quiz = generate_daily_quiz("student_12345", completed_quiz_count=0)
    # print(f"Generated {len(quiz)} questions for Quiz #{completed_quiz_count}")
    
    # Example 2b: Auto-fetch quiz count from DB
    # quiz = generate_daily_quiz("student_12345")  # Fetches completed_quiz_count from profile
    # print(f"Generated quiz")
    
    # Example 3: Update theta after response
    # new_theta = update_theta_after_response("student_12345", "MECH_045", is_correct=True, time_taken=120)
    # print(f"Updated theta: {new_theta}")
    
    pass
