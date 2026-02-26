/// Mock Test State Provider
/// Centralized state management for JEE Main mock test feature

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/mock_test_models.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../config/logging_config.dart';

class MockTestProvider extends ChangeNotifier {
  final AuthService _authService;

  // Templates & Usage
  List<MockTestTemplate> _templates = [];
  MockTestUsage? _usage;

  // Active Test State
  MockTestSession? _activeSession;
  int _currentQuestionIndex = 0;
  Timer? _timer;
  int _elapsedOnCurrentQuestion = 0;

  // History
  List<MockTestHistoryItem> _history = [];

  // Loading States
  bool _isLoadingTemplates = false;
  bool _isLoadingActiveTest = false;
  bool _isStartingTest = false;
  bool _isSavingAnswer = false;
  bool _isSubmitting = false;
  bool _isLoadingHistory = false;

  // Error State
  String? _error;

  // Disposal State
  bool _disposed = false;

  MockTestProvider(this._authService);

  // Getters
  List<MockTestTemplate> get templates => _templates;
  MockTestUsage? get usage => _usage;
  MockTestSession? get activeSession => _activeSession;
  int get currentQuestionIndex => _currentQuestionIndex;
  List<MockTestHistoryItem> get history => _history;

  bool get isLoadingTemplates => _isLoadingTemplates;
  bool get isLoadingActiveTest => _isLoadingActiveTest;
  bool get isStartingTest => _isStartingTest;
  bool get isSavingAnswer => _isSavingAnswer;
  bool get isSubmitting => _isSubmitting;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoading => _isLoadingTemplates || _isLoadingActiveTest || _isStartingTest;

  String? get error => _error;
  bool get hasError => _error != null;

  // Computed properties
  bool get hasActiveTest => _activeSession != null;
  MockTestQuestion? get currentQuestion =>
      _activeSession != null && _currentQuestionIndex < _activeSession!.questions.length
          ? _activeSession!.questions[_currentQuestionIndex]
          : null;
  int get totalQuestions => _activeSession?.totalQuestions ?? 0;
  int get answeredCount => _activeSession?.answeredCount ?? 0;
  int get timeRemainingSeconds => _activeSession?.timeRemainingSeconds ?? 0;

  bool get canStartNewTest =>
      _usage?.hasRemaining ?? false;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // =========================================================================
  // TEMPLATE & USAGE LOADING
  // =========================================================================

  /// Load available templates and usage info
  Future<void> loadTemplates() async {
    if (_disposed) return;

    _isLoadingTemplates = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) throw Exception('Authentication required');

      final data = await ApiService.getMockTestsAvailable(authToken: token);
      if (LoggingConfig.logApiPayloads) {
        debugPrint('[MockTest] loadTemplates raw response: $data');
      }

      if (_disposed) return;

      _templates = (data['templates'] as List? ?? [])
          .map((t) => MockTestTemplate.fromJson(t as Map<String, dynamic>))
          .toList();

      if (data['usage'] != null) {
        _usage = MockTestUsage.fromJson(data['usage'] as Map<String, dynamic>);
        if (LoggingConfig.verboseProviderLogs) {
          debugPrint('[MockTest] usage: used=${_usage!.used}, limit=${_usage!.limit}, remaining=${_usage!.remaining}');
        }
      }

      _isLoadingTemplates = false;
      _safeNotifyListeners();
    } catch (e) {
      if (_disposed) return;
      _isLoadingTemplates = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      _safeNotifyListeners();
    }
  }

  // =========================================================================
  // ACTIVE TEST MANAGEMENT
  // =========================================================================

  /// Check for and load active test
  Future<void> checkForActiveTest() async {
    if (_disposed) return;

    _isLoadingActiveTest = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) throw Exception('Authentication required');

      final data = await ApiService.getActiveMockTest(authToken: token);

      if (_disposed) return;

      if (data != null && data.isNotEmpty) {
        try {
          _activeSession = MockTestSession.fromJson(data);
          _currentQuestionIndex = 0;
          _startTimer();
        } catch (parseError) {
          debugPrint('Error parsing active session: $parseError');
          _activeSession = null;
        }
      } else {
        _activeSession = null;
      }

      _isLoadingActiveTest = false;
      _safeNotifyListeners();
    } catch (e) {
      if (_disposed) return;
      _isLoadingActiveTest = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      _safeNotifyListeners();
    }
  }

  /// Start a new mock test
  Future<MockTestSession> startTest({String? templateId}) async {
    if (_disposed) throw Exception('Provider disposed');

    _isStartingTest = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) throw Exception('Authentication required');

      final data = await ApiService.startMockTest(
        authToken: token,
        templateId: templateId,
      );

      if (_disposed) throw Exception('Provider disposed');

      _activeSession = MockTestSession.fromJson(data);
      _currentQuestionIndex = 0;
      _elapsedOnCurrentQuestion = 0;

      // Start the timer
      _startTimer();

      // Refresh usage
      _loadUsageInBackground();

      _isStartingTest = false;
      _safeNotifyListeners();

      return _activeSession!;
    } catch (e) {
      if (_disposed) rethrow;
      _isStartingTest = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      _safeNotifyListeners();
      rethrow;
    }
  }

  void _loadUsageInBackground() async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) return;

      final data = await ApiService.getMockTestsAvailable(authToken: token);
      if (data['usage'] != null && !_disposed) {
        _usage = MockTestUsage.fromJson(data['usage'] as Map<String, dynamic>);
        _safeNotifyListeners();
      }
    } catch (e) {
      // Ignore background refresh errors
    }
  }

  // =========================================================================
  // TIMER MANAGEMENT
  // =========================================================================

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || _activeSession == null) {
        timer.cancel();
        return;
      }

      // Decrement remaining time
      if (_activeSession!.timeRemainingSeconds > 0) {
        _activeSession!.timeRemainingSeconds--;
        _elapsedOnCurrentQuestion++;
        _safeNotifyListeners();
      } else {
        // Time's up - auto submit
        timer.cancel();
        _autoSubmit();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _autoSubmit() async {
    if (_activeSession == null) return;

    try {
      await submitTest();
    } catch (e) {
      debugPrint('Auto-submit failed: $e');
    }
  }

  // =========================================================================
  // NAVIGATION
  // =========================================================================

  /// Go to a specific question
  void goToQuestion(int index) {
    if (_activeSession == null) return;
    if (index < 0 || index >= _activeSession!.questions.length) return;

    // Save time spent on current question
    _saveTimeSpent();

    _currentQuestionIndex = index;
    _elapsedOnCurrentQuestion = 0;

    // Update question state if not visited
    final qNum = index + 1;
    if (_activeSession!.questionStates[qNum] == QuestionState.notVisited) {
      _activeSession!.questionStates[qNum] = QuestionState.notAnswered;
    }

    _safeNotifyListeners();
  }

  /// Go to next question
  void nextQuestion() {
    if (_currentQuestionIndex < totalQuestions - 1) {
      goToQuestion(_currentQuestionIndex + 1);
    }
  }

  /// Go to previous question
  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      goToQuestion(_currentQuestionIndex - 1);
    }
  }

  /// Go to next section
  void goToNextSection() {
    if (_activeSession == null) return;

    final currentQ = currentQuestion;
    if (currentQ == null) return;

    final currentSection = currentQ.sectionIndex;
    for (int i = _currentQuestionIndex + 1; i < _activeSession!.questions.length; i++) {
      if (_activeSession!.questions[i].sectionIndex > currentSection) {
        goToQuestion(i);
        return;
      }
    }
  }

  /// Go to previous section
  void goToPreviousSection() {
    if (_activeSession == null) return;

    final currentQ = currentQuestion;
    if (currentQ == null) return;

    final currentSection = currentQ.sectionIndex;
    for (int i = _currentQuestionIndex - 1; i >= 0; i--) {
      if (_activeSession!.questions[i].sectionIndex < currentSection) {
        // Find the first question of that section
        final targetSection = _activeSession!.questions[i].sectionIndex;
        for (int j = 0; j <= i; j++) {
          if (_activeSession!.questions[j].sectionIndex == targetSection) {
            goToQuestion(j);
            return;
          }
        }
      }
    }
  }

  void _saveTimeSpent() {
    if (_activeSession == null) return;

    final qNum = _currentQuestionIndex + 1;
    final existing = _activeSession!.responses[qNum];

    _activeSession!.responses[qNum] = MockTestResponse(
      answer: existing?.answer,
      markedForReview: existing?.markedForReview ?? false,
      timeSpentSeconds: (existing?.timeSpentSeconds ?? 0) + _elapsedOnCurrentQuestion,
    );
  }

  // =========================================================================
  // ANSWER MANAGEMENT
  // =========================================================================

  /// Save answer for current question
  Future<void> saveAnswer(String? answer, {bool markedForReview = false}) async {
    if (_activeSession == null || _disposed) return;

    final qNum = _currentQuestionIndex + 1;

    // Update local state immediately
    final existingResponse = _activeSession!.responses[qNum];
    _activeSession!.responses[qNum] = MockTestResponse(
      answer: answer,
      markedForReview: markedForReview,
      timeSpentSeconds: (existingResponse?.timeSpentSeconds ?? 0) + _elapsedOnCurrentQuestion,
    );
    _elapsedOnCurrentQuestion = 0;

    // Update question state
    if (answer != null && answer.isNotEmpty && markedForReview) {
      _activeSession!.questionStates[qNum] = QuestionState.answeredMarked;
    } else if (answer != null && answer.isNotEmpty) {
      _activeSession!.questionStates[qNum] = QuestionState.answered;
    } else if (markedForReview) {
      _activeSession!.questionStates[qNum] = QuestionState.markedForReview;
    } else {
      _activeSession!.questionStates[qNum] = QuestionState.notAnswered;
    }

    _safeNotifyListeners();

    // Sync to server in background
    _syncAnswerToServer(qNum, answer, markedForReview);
  }

  Future<void> _syncAnswerToServer(int qNum, String? answer, bool markedForReview) async {
    if (_activeSession == null) return;

    try {
      final token = await _authService.getIdToken();
      if (token == null) return;

      final response = _activeSession!.responses[qNum];
      await ApiService.saveMockTestAnswer(
        authToken: token,
        testId: _activeSession!.testId,
        questionNumber: qNum,
        answer: answer,
        markedForReview: markedForReview,
        timeSpentSeconds: response?.timeSpentSeconds ?? 0,
      );
    } catch (e) {
      debugPrint('Failed to sync answer to server: $e');
      // Don't show error to user - will retry on next save or submit
    }
  }

  /// Clear answer for current question
  Future<void> clearAnswer() async {
    if (_activeSession == null || _disposed) return;

    final qNum = _currentQuestionIndex + 1;

    // Update local state
    _activeSession!.responses[qNum] = MockTestResponse(
      answer: null,
      markedForReview: false,
      timeSpentSeconds: _activeSession!.responses[qNum]?.timeSpentSeconds ?? 0,
    );
    _activeSession!.questionStates[qNum] = QuestionState.notAnswered;

    _safeNotifyListeners();

    // Sync to server
    try {
      final token = await _authService.getIdToken();
      if (token == null) return;

      await ApiService.clearMockTestAnswer(
        authToken: token,
        testId: _activeSession!.testId,
        questionNumber: qNum,
      );
    } catch (e) {
      debugPrint('Failed to clear answer on server: $e');
    }
  }

  /// Toggle mark for review
  Future<void> toggleMarkForReview() async {
    if (_activeSession == null) return;

    final qNum = _currentQuestionIndex + 1;
    final existing = _activeSession!.responses[qNum];
    final currentMarked = existing?.markedForReview ?? false;

    await saveAnswer(existing?.answer, markedForReview: !currentMarked);
  }

  /// Get current answer
  String? getCurrentAnswer() {
    if (_activeSession == null) return null;
    final qNum = _currentQuestionIndex + 1;
    return _activeSession!.responses[qNum]?.answer;
  }

  /// Check if current question is marked for review
  bool isCurrentMarkedForReview() {
    if (_activeSession == null) return false;
    final qNum = _currentQuestionIndex + 1;
    return _activeSession!.responses[qNum]?.markedForReview ?? false;
  }

  /// Get question state for a question number
  QuestionState getQuestionState(int questionNumber) {
    return _activeSession?.questionStates[questionNumber] ?? QuestionState.notVisited;
  }

  // =========================================================================
  // SUBMISSION
  // =========================================================================

  /// Submit the test
  Future<MockTestResult> submitTest() async {
    if (_activeSession == null || _disposed) {
      throw Exception('No active test');
    }

    _isSubmitting = true;
    _error = null;
    _safeNotifyListeners();

    try {
      // Stop timer
      _stopTimer();

      // Save time spent on current question
      _saveTimeSpent();

      final token = await _authService.getIdToken();
      if (token == null) throw Exception('Authentication required');

      final data = await ApiService.submitMockTest(
        authToken: token,
        testId: _activeSession!.testId,
      );

      if (_disposed) throw Exception('Provider disposed');

      final result = MockTestResult.fromJson(data);

      // Clear active session
      _activeSession = null;
      _currentQuestionIndex = 0;

      // Refresh history and usage
      _loadHistoryInBackground();
      _loadUsageInBackground();

      _isSubmitting = false;
      _safeNotifyListeners();

      return result;
    } catch (e) {
      if (_disposed) rethrow;
      _isSubmitting = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      _safeNotifyListeners();
      rethrow;
    }
  }

  /// Abandon the test
  Future<void> abandonTest() async {
    if (_activeSession == null) return;

    try {
      _stopTimer();

      final token = await _authService.getIdToken();
      if (token == null) return;

      await ApiService.abandonMockTest(
        authToken: token,
        testId: _activeSession!.testId,
      );

      _activeSession = null;
      _currentQuestionIndex = 0;

      _safeNotifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _safeNotifyListeners();
    }
  }

  // =========================================================================
  // HISTORY
  // =========================================================================

  /// Load test history
  Future<void> loadHistory() async {
    if (_disposed) return;

    _isLoadingHistory = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) throw Exception('Authentication required');

      final data = await ApiService.getMockTestHistory(authToken: token);

      if (_disposed) return;

      _history = (data['tests'] as List? ?? [])
          .map((t) => MockTestHistoryItem.fromJson(t as Map<String, dynamic>))
          .toList();

      _isLoadingHistory = false;
      _safeNotifyListeners();
    } catch (e) {
      if (_disposed) return;
      _isLoadingHistory = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      _safeNotifyListeners();
    }
  }

  void _loadHistoryInBackground() async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) return;

      final data = await ApiService.getMockTestHistory(authToken: token);
      if (!_disposed) {
        _history = (data['tests'] as List? ?? [])
            .map((t) => MockTestHistoryItem.fromJson(t as Map<String, dynamic>))
            .toList();
        _safeNotifyListeners();
      }
    } catch (e) {
      // Ignore background refresh errors
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    _safeNotifyListeners();
  }

  /// Reset provider state (called after navigating away from mock test)
  /// This ensures clean state for next test session
  void reset() {
    if (_disposed) return;

    _stopTimer();
    _activeSession = null;
    _currentQuestionIndex = 0;
    _error = null;

    if (LoggingConfig.verboseProviderLogs) {
      debugPrint('[MockTestProvider] State reset');
    }
    _safeNotifyListeners();
  }
}
