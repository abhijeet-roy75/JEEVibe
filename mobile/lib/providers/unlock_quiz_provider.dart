import 'package:flutter/foundation.dart';
import 'package:jeevibe/models/unlock_quiz_models.dart';
import 'package:jeevibe/services/api_service.dart';

/// Unlock Quiz Provider
/// Manages state for the chapter unlock quiz feature
class UnlockQuizProvider with ChangeNotifier {
  UnlockQuizSession? _session;
  int _currentQuestionIndex = 0;
  UnlockQuizAnswerResult? _lastAnswerResult;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Getters
  UnlockQuizSession? get session => _session;
  int get currentQuestionIndex => _currentQuestionIndex;
  UnlockQuizQuestion? get currentQuestion =>
      _session?.questions.elementAtOrNull(_currentQuestionIndex);
  UnlockQuizAnswerResult? get lastAnswerResult => _lastAnswerResult;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  bool get currentQuestionIsAnswered =>
      currentQuestion?.answered ?? false || _lastAnswerResult != null;
  bool get hasMoreQuestions =>
      _currentQuestionIndex < (_session?.totalQuestions ?? 0) - 1;

  /// Start unlock quiz
  Future<void> startUnlockQuiz(String chapterKey, String authToken) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        '/unlock-quiz/generate',
        {'chapterKey': chapterKey},
        authToken,
      );

      if (response['success']) {
        _session = UnlockQuizSession.fromJson(response['data']);
        _currentQuestionIndex = 0;
        _lastAnswerResult = null;
      } else {
        throw Exception(response['error'] ?? 'Failed to generate unlock quiz');
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit answer
  Future<UnlockQuizAnswerResult> submitAnswer(
    String selectedOption,
    String authToken,
    int timeTakenSeconds,
  ) async {
    if (_session == null || currentQuestion == null) {
      throw Exception('No active session or question');
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        '/unlock-quiz/submit-answer',
        {
          'sessionId': _session!.sessionId,
          'questionId': currentQuestion!.questionId,
          'selectedOption': selectedOption,
          'timeTakenSeconds': timeTakenSeconds,
        },
        authToken,
      );

      if (response['success']) {
        final result = UnlockQuizAnswerResult.fromJson(response['data']);
        _lastAnswerResult = result;

        // Update question state
        currentQuestion!.answered = true;
        currentQuestion!.studentAnswer = selectedOption;
        currentQuestion!.correctAnswer = result.correctAnswer;
        currentQuestion!.isCorrect = result.isCorrect;
        currentQuestion!.timeTakenSeconds = timeTakenSeconds;

        notifyListeners();
        return result;
      } else {
        throw Exception(response['error'] ?? 'Failed to submit answer');
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Navigate to next question
  void goToNextQuestion() {
    if (hasMoreQuestions) {
      _currentQuestionIndex++;
      _lastAnswerResult = null;
      notifyListeners();
    }
  }

  /// Complete unlock quiz
  Future<UnlockQuizResult> completeQuiz(String authToken) async {
    if (_session == null) {
      throw Exception('No active session');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        '/unlock-quiz/complete',
        {'sessionId': _session!.sessionId},
        authToken,
      );

      if (response['success']) {
        final result = UnlockQuizResult.fromJson(response['data']);
        _session = null; // Clear session
        notifyListeners();
        return result;
      } else {
        throw Exception(response['error'] ?? 'Failed to complete quiz');
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset provider state
  void reset() {
    _session = null;
    _currentQuestionIndex = 0;
    _lastAnswerResult = null;
    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;
    notifyListeners();
  }
}
