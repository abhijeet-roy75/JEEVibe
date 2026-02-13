import 'package:flutter/foundation.dart';
import '../models/chapter_practice_models.dart';
import '../models/daily_quiz_question.dart' show SolutionStep;
import '../services/api_service.dart';
import '../services/chapter_practice_storage_service.dart';

/// Chapter Practice Provider
///
/// Manages state for chapter practice sessions.
class ChapterPracticeProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final ChapterPracticeStorageService _storageService =
      ChapterPracticeStorageService();

  // Session state
  ChapterPracticeSession? _session;
  int _currentQuestionIndex = 0;
  final List<PracticeQuestionResult> _results = [];

  // Loading states
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Disposal flag to prevent notifyListeners after dispose
  bool _isDisposed = false;

  // Last answer result (for feedback)
  PracticeAnswerResult? _lastAnswerResult;

  // Getters
  ChapterPracticeSession? get session => _session;
  int get currentQuestionIndex => _currentQuestionIndex;
  List<PracticeQuestionResult> get results => List.unmodifiable(_results);
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  PracticeAnswerResult? get lastAnswerResult => _lastAnswerResult;

  PracticeQuestion? get currentQuestion {
    if (_session == null ||
        _currentQuestionIndex < 0 ||
        _currentQuestionIndex >= _session!.questions.length ||
        _session!.questions.isEmpty) {
      return null;
    }
    return _session!.questions[_currentQuestionIndex];
  }

  bool get hasMoreQuestions {
    if (_session == null) return false;
    return _currentQuestionIndex < _session!.questions.length - 1;
  }

  int get correctCount => _results.where((r) => r.isCorrect).length;
  int get totalAnswered => _results.length;

  double get accuracy {
    if (_results.isEmpty) return 0.0;
    return correctCount / totalAnswered;
  }

  /// Check if current question has been answered
  ///
  /// Returns true if either:
  /// - The question was answered in this session (lastAnswerResult exists), OR
  /// - The question was answered in a previous session (question.answered is true from backend)
  bool get currentQuestionIsAnswered {
    final question = currentQuestion;
    if (question == null) return false;
    return question.answered || _lastAnswerResult != null;
  }

  /// Check if full feedback (solution, steps, etc.) is available for display
  ///
  /// Returns true only if we have the lastAnswerResult, which contains
  /// the detailed solution steps, explanation, and distractor analysis.
  /// For resumed questions without this data, only basic correct/incorrect info is available.
  bool get hasFullFeedbackAvailable => _lastAnswerResult != null;

  /// Start a new practice session for a chapter
  Future<bool> startPractice(
    String chapterKey,
    String authToken, {
    int? questionCount,
  }) async {
    // Clear any previous state before starting a new session
    _session = null;
    _currentQuestionIndex = 0;
    _results.clear();
    _lastAnswerResult = null;
    _isLoading = true;
    _errorMessage = null;
    _notifyListeners();

    try {
      final response = await _apiService.generateChapterPractice(
        chapterKey,
        authToken,
        questionCount: questionCount,
      );

      if (response['success'] == true) {
        _session = ChapterPracticeSession.fromJson(response['session']);
        _currentQuestionIndex = 0;

        // If resuming existing session, restore progress and rebuild results
        if (_session!.isExistingSession && _session!.questionsAnswered > 0) {
          _currentQuestionIndex = _session!.questionsAnswered;

          // Rebuild results from answered questions for accurate stats
          for (final question in _session!.questions) {
            if (question.answered && question.studentAnswer != null) {
              _results.add(PracticeQuestionResult(
                questionId: question.questionId,
                position: question.position,
                questionText: question.questionText,
                questionTextHtml: question.questionTextHtml,
                options: question.options,
                studentAnswer: question.studentAnswer!,
                correctAnswer: question.correctAnswer ?? question.studentAnswer!,
                isCorrect: question.isCorrect ?? false,
                timeTakenSeconds: question.timeTakenSeconds ?? 0,
              ));
            }
          }
        }

        // Save to local storage
        await _storageService.saveSession(_session!);

        _isLoading = false;
        _notifyListeners();
        return true;
      } else {
        // Extract error message from response
        final errorData = response['error'];
        if (errorData is Map) {
          _errorMessage = errorData['message'] ?? 'Failed to start practice';
        } else {
          _errorMessage = errorData?.toString() ?? 'Failed to start practice';
        }
        _isLoading = false;
        _notifyListeners();
        return false;
      }
    } catch (e) {
      // Make error messages more user-friendly
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('no questions found')) {
        _errorMessage = 'No practice questions available for this chapter yet. Please try another chapter.';
      } else if (errorStr.contains('socketexception') || errorStr.contains('connection')) {
        _errorMessage = 'Network error. Please check your connection and try again.';
      } else {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      _isLoading = false;
      _notifyListeners();
      return false;
    }
  }

  /// Submit answer for current question
  Future<PracticeAnswerResult?> submitAnswer(
    String selectedOption,
    String authToken, {
    int timeTakenSeconds = 0,
  }) async {
    if (_session == null || currentQuestion == null) return null;

    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();

    try {
      final response = await _apiService.submitChapterPracticeAnswer(
        _session!.sessionId,
        currentQuestion!.questionId,
        selectedOption,
        authToken,
        timeTakenSeconds: timeTakenSeconds,
      );

      if (response['success'] == true) {
        _lastAnswerResult = PracticeAnswerResult.fromJson(response, submittedAnswer: selectedOption);

        // Update question state
        currentQuestion!.answered = true;
        currentQuestion!.studentAnswer = selectedOption;
        currentQuestion!.isCorrect = _lastAnswerResult!.isCorrect;
        currentQuestion!.timeTakenSeconds = timeTakenSeconds;

        // Add to results with full solution data
        _results.add(PracticeQuestionResult(
          questionId: currentQuestion!.questionId,
          position: currentQuestion!.position,
          questionText: currentQuestion!.questionText,
          questionTextHtml: currentQuestion!.questionTextHtml,
          options: currentQuestion!.options,
          studentAnswer: selectedOption,
          correctAnswer: _lastAnswerResult!.correctAnswer,
          isCorrect: _lastAnswerResult!.isCorrect,
          timeTakenSeconds: timeTakenSeconds,
          solutionText: _lastAnswerResult!.solutionText,
          solutionSteps: _lastAnswerResult!.solutionSteps,
          keyInsight: _lastAnswerResult!.keyInsight,
          distractorAnalysis: _lastAnswerResult!.distractorAnalysis,
          commonMistakes: _lastAnswerResult!.commonMistakes,
          explanation: _lastAnswerResult!.explanation,
        ));

        // Save progress locally
        await _storageService.saveProgress(
          _session!.sessionId,
          _currentQuestionIndex,
          _results,
        );

        _isSubmitting = false;
        _notifyListeners();
        return _lastAnswerResult;
      } else {
        _errorMessage = response['error'] ?? 'Failed to submit answer';
        _isSubmitting = false;
        _notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isSubmitting = false;
      _notifyListeners();
      return null;
    }
  }

  /// Move to next question
  void nextQuestion() {
    if (hasMoreQuestions) {
      _currentQuestionIndex++;
      _lastAnswerResult = null;
      _notifyListeners();
    }
  }

  /// Complete the session
  Future<PracticeSessionSummary?> completeSession(String authToken) async {
    if (_session == null) return null;

    _isLoading = true;
    _errorMessage = null;
    _notifyListeners();

    try {
      final response = await _apiService.completeChapterPractice(
        _session!.sessionId,
        authToken,
      );

      if (response['success'] == true) {
        final summary = PracticeSessionSummary.fromJson(response);

        // Clear local storage
        await _storageService.clearSession(_session!.sessionId);

        _isLoading = false;
        _notifyListeners();
        return summary;
      } else {
        _errorMessage = response['error'] ?? 'Failed to complete session';
        _isLoading = false;
        _notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _notifyListeners();
      return null;
    }
  }

  /// Reset provider state
  void reset() {
    _session = null;
    _currentQuestionIndex = 0;
    _results.clear();
    _lastAnswerResult = null;
    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;
    _notifyListeners();
  }

  /// Try to resume an existing session
  /// Validates with backend to ensure session is still active
  Future<bool> tryResumeSession(String authToken) async {
    final activeSessionId = await _storageService.getActiveSessionId();
    if (activeSessionId == null) return false;

    try {
      // Validate session with backend
      final response = await _apiService.getChapterPracticeSession(
        activeSessionId,
        authToken,
      );

      if (response['success'] != true) {
        // Session not found on backend, clear local storage
        await _storageService.clearSession(activeSessionId);
        return false;
      }

      final sessionData = response['session'];
      if (sessionData == null) {
        await _storageService.clearSession(activeSessionId);
        return false;
      }

      // Check if session is still in progress
      final status = sessionData['status'];
      if (status != 'in_progress') {
        // Session is completed or expired, clear local storage
        await _storageService.clearSession(activeSessionId);
        return false;
      }

      // Session is valid, restore it from backend response
      _session = ChapterPracticeSession.fromJson(sessionData);
      _currentQuestionIndex = sessionData['questions_answered'] ?? 0;
      _results.clear();
      _lastAnswerResult = null;
      _errorMessage = null;

      // Rebuild results from answered questions for accurate stats
      for (final question in _session!.questions) {
        if (question.answered && question.studentAnswer != null) {
          _results.add(PracticeQuestionResult(
            questionId: question.questionId,
            position: question.position,
            questionText: question.questionText,
            questionTextHtml: question.questionTextHtml,
            options: question.options,
            studentAnswer: question.studentAnswer!,
            correctAnswer: question.correctAnswer ?? question.studentAnswer!,
            isCorrect: question.isCorrect ?? false,
            timeTakenSeconds: question.timeTakenSeconds ?? 0,
          ));
        }
      }

      // Update local storage with backend data
      await _storageService.saveSession(_session!);

      _notifyListeners();
      return true;
    } catch (e) {
      // Network error or other issue - try loading from local storage as fallback
      // but mark that we couldn't validate
      final localSession = await _storageService.loadSession(activeSessionId);
      if (localSession == null) return false;

      final progress = await _storageService.loadProgress(activeSessionId);

      _session = localSession;
      _currentQuestionIndex = progress?['question_index'] ?? 0;
      _results.clear();
      _errorMessage = null;

      // Rebuild results from local progress data
      final savedResults = progress?['results'] as List<dynamic>?;
      if (savedResults != null) {
        for (final r in savedResults) {
          final questionId = r['question_id'] as String?;
          if (questionId == null) continue;

          // Find the question in the session to get full details
          final question = _session!.questions.firstWhere(
            (q) => q.questionId == questionId,
            orElse: () => _session!.questions.first,
          );

          // Parse solution steps from saved data
          List<SolutionStep> solutionSteps = [];
          if (r['solution_steps'] != null && r['solution_steps'] is List) {
            solutionSteps = (r['solution_steps'] as List)
                .map((step) => SolutionStep.fromJson(step))
                .toList();
          }

          // Parse distractor analysis
          Map<String, String>? distractorAnalysis;
          if (r['distractor_analysis'] != null && r['distractor_analysis'] is Map) {
            distractorAnalysis = Map<String, String>.from(
              (r['distractor_analysis'] as Map).map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ),
            );
          }

          // Parse common mistakes
          List<String>? commonMistakes;
          if (r['common_mistakes'] != null && r['common_mistakes'] is List) {
            commonMistakes = (r['common_mistakes'] as List)
                .map((m) => m.toString())
                .toList();
          }

          _results.add(PracticeQuestionResult(
            questionId: questionId,
            position: r['position'] ?? 0,
            questionText: question.questionText,
            questionTextHtml: question.questionTextHtml,
            options: question.options,
            studentAnswer: r['student_answer'] ?? '',
            correctAnswer: r['correct_answer'] ?? '',
            isCorrect: r['is_correct'] ?? false,
            timeTakenSeconds: r['time_taken_seconds'] ?? 0,
            solutionText: r['solution_text'] as String?,
            solutionSteps: solutionSteps,
            keyInsight: r['key_insight'] as String?,
            distractorAnalysis: distractorAnalysis,
            commonMistakes: commonMistakes,
            explanation: r['explanation'] as String?,
            difficulty: r['difficulty'] as String?,
          ));
        }
      }

      _notifyListeners();
      return true;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Safe wrapper for notifyListeners that checks disposal state
  void _notifyListeners() {
    if (!_isDisposed) {
      _notifyListeners();
    }
  }
}
