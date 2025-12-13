/// Quiz Storage Service
/// Handles local persistence of daily quiz state
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_quiz_question.dart';
import '../models/assessment_question.dart' show QuestionOption;

class QuizStorageService {
  static const String _keyPrefix = 'jeevibe_quiz_';
  static const String _keyCurrentQuiz = '${_keyPrefix}current_quiz';
  static const String _keyCurrentIndex = '${_keyPrefix}current_index';
  static const String _keyQuestionStates = '${_keyPrefix}question_states';
  static const String _keyQuizStartedAt = '${_keyPrefix}started_at';
  static const String _keyLastSavedAt = '${_keyPrefix}last_saved_at';
  
  // Quiz state expires after 24 hours
  static const Duration _stateExpiration = Duration(hours: 24);

  // Singleton pattern
  static final QuizStorageService _instance = QuizStorageService._internal();
  factory QuizStorageService() => _instance;
  QuizStorageService._internal();

  SharedPreferences? _prefs;

  /// Initialize the storage service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  /// Save current quiz state
  Future<void> saveQuizState({
    required DailyQuiz quiz,
    required int currentIndex,
    required Map<int, QuestionStateData> questionStates,
    DateTime? startedAt,
  }) async {
    try {
      final prefs = await _preferences;
      final now = DateTime.now();

      // Save quiz
      final quizJson = json.encode({
        'quiz_id': quiz.quizId,
        'quiz_number': quiz.quizNumber,
        'learning_phase': quiz.learningPhase,
        'is_recovery_quiz': quiz.isRecoveryQuiz,
        'generated_at': quiz.generatedAt,
        'questions': quiz.questions.map((q) => {
          'question_id': q.questionId,
          'position': q.position,
          'subject': q.subject,
          'chapter': q.chapter,
          'chapter_key': q.chapterKey,
          'question_type': q.questionType,
          'question_text': q.questionText,
          'question_text_html': q.questionTextHtml,
          'question_latex': q.questionLatex,
          'options': q.options?.map((opt) => {
            'option_id': opt.optionId,
            'text': opt.text,
            'html': opt.html,
          }).toList(),
          'image_url': q.imageUrl,
          'time_estimate': q.timeEstimate,
          'selection_reason': q.selectionReason,
          'answered': q.answered,
          'student_answer': q.studentAnswer,
          'is_correct': q.isCorrect,
          'time_taken_seconds': q.timeTakenSeconds,
        }).toList(),
      });

      await prefs.setString(_keyCurrentQuiz, quizJson);
      await prefs.setInt(_keyCurrentIndex, currentIndex);
      await prefs.setString(_keyQuizStartedAt, (startedAt ?? now).toIso8601String());
      await prefs.setString(_keyLastSavedAt, now.toIso8601String());

      // Save question states
      final questionStatesJson = json.encode(
        questionStates.map((key, value) => MapEntry(
          key.toString(),
          {
            'start_time': value.startTime.toIso8601String(),
            'elapsed_seconds': value.elapsedSeconds,
            'selected_answer': value.selectedAnswer,
            'is_answered': value.isAnswered,
            'show_detailed_explanation': value.showDetailedExplanation,
            'feedback': value.feedback != null ? {
              'question_id': value.feedback!.questionId,
              'is_correct': value.feedback!.isCorrect,
              'correct_answer': value.feedback!.correctAnswer,
              'correct_answer_text': value.feedback!.correctAnswerText,
              'student_answer': value.feedback!.studentAnswer,
              'explanation': value.feedback!.explanation,
              'solution_text': value.feedback!.solutionText,
              'time_taken_seconds': value.feedback!.timeTakenSeconds,
              'solution_steps': value.feedback!.solutionSteps?.map((step) => {
                'step_number': step.stepNumber,
                'description': step.description,
                'explanation': step.explanation,
                'formula': step.formula,
                'calculation': step.calculation,
              }).toList(),
            } : null,
          },
        )),
      );

      await prefs.setString(_keyQuestionStates, questionStatesJson);
    } catch (e) {
      debugPrint('Error saving quiz state: $e');
    }
  }

  /// Load saved quiz state
  Future<QuizStateData?> loadQuizState() async {
    try {
      final prefs = await _preferences;

      // Check if state exists
      if (!prefs.containsKey(_keyCurrentQuiz)) {
        return null;
      }

      // Check if state has expired
      final lastSavedAtStr = prefs.getString(_keyLastSavedAt);
      if (lastSavedAtStr != null) {
        final lastSavedAt = DateTime.parse(lastSavedAtStr);
        final now = DateTime.now();
        if (now.difference(lastSavedAt) > _stateExpiration) {
          // State expired, clear it
          await clearQuizState();
          return null;
        }
      }

      // Load quiz
      final quizJson = prefs.getString(_keyCurrentQuiz);
      if (quizJson == null) return null;

      final quizData = json.decode(quizJson) as Map<String, dynamic>;
      final questionsData = quizData['questions'] as List<dynamic>;

      final questions = questionsData.map((q) {
        return DailyQuizQuestion(
          questionId: q['question_id'] as String,
          position: q['position'] as int? ?? 0,
          subject: q['subject'] as String? ?? '',
          chapter: q['chapter'] as String? ?? '',
          chapterKey: q['chapter_key'] as String? ?? '',
          questionType: q['question_type'] as String? ?? 'mcq_single',
          questionText: q['question_text'] as String? ?? '',
          questionTextHtml: q['question_text_html'] as String?,
          questionLatex: q['question_latex'] as String?,
          options: q['options'] != null
              ? (q['options'] as List).map((opt) {
                  return QuestionOption(
                    optionId: opt['option_id'] as String,
                    text: opt['text'] as String,
                    html: opt['html'] as String?,
                  );
                }).toList()
              : null,
          imageUrl: q['image_url'] as String?,
          timeEstimate: q['time_estimate'] as int?,
          selectionReason: q['selection_reason'] as String?,
          answered: q['answered'] as bool? ?? false,
          studentAnswer: q['student_answer'] as String?,
          isCorrect: q['is_correct'] as bool?,
          timeTakenSeconds: q['time_taken_seconds'] as int?,
        );
      }).toList();

      final quiz = DailyQuiz(
        quizId: quizData['quiz_id'] as String,
        quizNumber: quizData['quiz_number'] as int? ?? 0,
        learningPhase: quizData['learning_phase'] as String? ?? 'exploration',
        questions: questions,
        generatedAt: quizData['generated_at'] as String?,
        isRecoveryQuiz: quizData['is_recovery_quiz'] as bool? ?? false,
      );

      // Load current index
      final currentIndex = prefs.getInt(_keyCurrentIndex) ?? 0;

      // Load question states
      final questionStatesJson = prefs.getString(_keyQuestionStates);
      Map<int, QuestionStateData> questionStates = {};
      
      if (questionStatesJson != null) {
        final statesData = json.decode(questionStatesJson) as Map<String, dynamic>;
        questionStates = statesData.map((key, value) {
          final index = int.parse(key);
          final stateData = value as Map<String, dynamic>;
          
          AnswerFeedback? feedback;
          if (stateData['feedback'] != null) {
            final feedbackData = stateData['feedback'] as Map<String, dynamic>;
            final solutionSteps = feedbackData['solution_steps'] != null
                ? (feedbackData['solution_steps'] as List).map((step) {
                    return SolutionStep(
                      stepNumber: step['step_number'] as int?,
                      description: step['description'] as String?,
                      explanation: step['explanation'] as String?,
                      formula: step['formula'] as String?,
                      calculation: step['calculation'] as String?,
                    );
                  }).toList()
                : null;

            feedback = AnswerFeedback(
              questionId: feedbackData['question_id'] as String,
              isCorrect: feedbackData['is_correct'] as bool,
              correctAnswer: feedbackData['correct_answer'] as String?,
              correctAnswerText: feedbackData['correct_answer_text'] as String?,
              studentAnswer: feedbackData['student_answer'] as String?,
              explanation: feedbackData['explanation'] as String?,
              solutionText: feedbackData['solution_text'] as String?,
              solutionSteps: solutionSteps,
              timeTakenSeconds: feedbackData['time_taken_seconds'] as int,
            );
          }

          return MapEntry(index, QuestionStateData(
            startTime: DateTime.parse(stateData['start_time'] as String),
            elapsedSeconds: stateData['elapsed_seconds'] as int? ?? 0,
            selectedAnswer: stateData['selected_answer'] as String?,
            isAnswered: stateData['is_answered'] as bool? ?? false,
            showDetailedExplanation: stateData['show_detailed_explanation'] as bool? ?? true,
            feedback: feedback,
          ));
        });
      }

      // Load started at
      final startedAtStr = prefs.getString(_keyQuizStartedAt);
      final startedAt = startedAtStr != null ? DateTime.parse(startedAtStr) : DateTime.now();

      return QuizStateData(
        quiz: quiz,
        currentIndex: currentIndex,
        questionStates: questionStates,
        startedAt: startedAt,
      );
    } catch (e) {
      debugPrint('Error loading quiz state: $e');
      return null;
    }
  }

  /// Clear saved quiz state
  Future<void> clearQuizState() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(_keyCurrentQuiz);
      await prefs.remove(_keyCurrentIndex);
      await prefs.remove(_keyQuestionStates);
      await prefs.remove(_keyQuizStartedAt);
      await prefs.remove(_keyLastSavedAt);
    } catch (e) {
      debugPrint('Error clearing quiz state: $e');
    }
  }

  /// Check if there's a saved quiz state
  Future<bool> hasSavedQuizState() async {
    try {
      final prefs = await _preferences;
      return prefs.containsKey(_keyCurrentQuiz);
    } catch (e) {
      return false;
    }
  }

  /// Check if saved state is expired
  Future<bool> isStateExpired() async {
    try {
      final prefs = await _preferences;
      final lastSavedAtStr = prefs.getString(_keyLastSavedAt);
      if (lastSavedAtStr == null) return true;

      final lastSavedAt = DateTime.parse(lastSavedAtStr);
      final now = DateTime.now();
      return now.difference(lastSavedAt) > _stateExpiration;
    } catch (e) {
      return true;
    }
  }

  void debugPrint(String message) {
    print('[QuizStorageService] $message');
  }
}

/// Quiz State Data Model
class QuizStateData {
  final DailyQuiz quiz;
  final int currentIndex;
  final Map<int, QuestionStateData> questionStates;
  final DateTime startedAt;

  QuizStateData({
    required this.quiz,
    required this.currentIndex,
    required this.questionStates,
    required this.startedAt,
  });
}

/// Question State Data Model (for storage)
class QuestionStateData {
  final DateTime startTime;
  final int elapsedSeconds;
  final String? selectedAnswer;
  final bool isAnswered;
  final bool showDetailedExplanation;
  final AnswerFeedback? feedback;

  QuestionStateData({
    required this.startTime,
    this.elapsedSeconds = 0,
    this.selectedAnswer,
    this.isAnswered = false,
    this.showDetailedExplanation = true,
    this.feedback,
  });
}

