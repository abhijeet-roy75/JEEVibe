/// Daily Quiz State Provider
/// Centralized state management for daily quiz feature
import 'package:flutter/foundation.dart';
import '../models/daily_quiz_question.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/quiz_storage_service.dart';

class DailyQuizProvider extends ChangeNotifier {
  final AuthService _authService;
  final QuizStorageService _storageService = QuizStorageService();

  // Quiz State
  DailyQuiz? _currentQuiz;
  Map<String, dynamic>? _quizResult;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _progress;
  
  // Question State
  int _currentQuestionIndex = 0;
  final Map<int, QuestionState> _questionStates = {};
  DateTime? _quizStartedAt;
  
  // Loading States
  bool _isGeneratingQuiz = false;
  bool _isLoadingResult = false;
  bool _isSubmittingAnswer = false;
  bool _isCompletingQuiz = false;
  bool _isLoadingSummary = false;
  bool _isLoadingProgress = false;
  bool _isRestoringState = false;
  
  // Error States
  String? _error;
  
  DailyQuizProvider(this._authService) {
    _initializeStorage();
  }

  /// Initialize storage and restore state if available
  Future<void> _initializeStorage() async {
    await _storageService.initialize();
    await _restoreQuizState();
  }

  // Getters
  DailyQuiz? get currentQuiz => _currentQuiz;
  Map<String, dynamic>? get quizResult => _quizResult;
  Map<String, dynamic>? get summary => _summary;
  Map<String, dynamic>? get progress => _progress;
  int get currentQuestionIndex => _currentQuestionIndex;
  QuestionState? getQuestionState(int index) => _questionStates[index];
  bool get isGeneratingQuiz => _isGeneratingQuiz;
  bool get isLoadingResult => _isLoadingResult;
  bool get isSubmittingAnswer => _isSubmittingAnswer;
  bool get isCompletingQuiz => _isCompletingQuiz;
  bool get isLoadingSummary => _isLoadingSummary;
  bool get isLoadingProgress => _isLoadingProgress;
  String? get error => _error;
  bool get hasError => _error != null;
  
  // Computed Properties
  bool get hasActiveQuiz => _currentQuiz != null;
  int get totalQuestions => _currentQuiz?.totalQuestions ?? 0;
  int get answeredCount => _currentQuiz?.answeredCount ?? 0;
  bool get isQuizComplete => answeredCount == totalQuestions && totalQuestions > 0;

  /// Set quiz (used when quiz is passed from loading screen)
  void setQuiz(DailyQuiz quiz) {
    _currentQuiz = quiz;
    _currentQuestionIndex = 0;
    _questionStates.clear();
    _quizStartedAt = DateTime.now();
    _error = null;
    _saveQuizState();
    notifyListeners();
  }

  /// Generate a new daily quiz
  Future<DailyQuiz> generateQuiz() async {
    _isGeneratingQuiz = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final quiz = await ApiService.generateDailyQuiz(authToken: token);
      
      _currentQuiz = quiz;
      _currentQuestionIndex = 0;
      _questionStates.clear();
      _quizStartedAt = DateTime.now();
      _isGeneratingQuiz = false;
      _error = null;
      _saveQuizState();
      notifyListeners();
      
      return quiz;
    } catch (e) {
      _isGeneratingQuiz = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Start the quiz (mark as started on backend)
  Future<void> startQuiz() async {
    if (_currentQuiz == null) {
      throw Exception('No quiz available');
    }

    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      await ApiService.startDailyQuiz(
        authToken: token,
        quizId: _currentQuiz!.quizId,
      );

      // Initialize first question state
      _questionStates[0] = QuestionState(
        startTime: DateTime.now(),
        elapsedSeconds: 0,
      );
      _quizStartedAt = DateTime.now();
      _saveQuizState();
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Submit answer for current question
  Future<AnswerFeedback> submitAnswer(String answer) async {
    if (_currentQuiz == null) {
      throw Exception('No quiz available');
    }

    final question = _currentQuiz!.questions[_currentQuestionIndex];
    final questionState = _questionStates[_currentQuestionIndex];
    
    if (questionState == null) {
      throw Exception('Question state not initialized');
    }

    _isSubmittingAnswer = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final timeTaken = questionState.elapsedSeconds;
      final feedback = await ApiService.submitAnswer(
        authToken: token,
        quizId: _currentQuiz!.quizId,
        questionId: question.questionId,
        studentAnswer: answer,
        timeTakenSeconds: timeTaken,
      );

      // Update question state
      _questionStates[_currentQuestionIndex] = questionState.copyWith(
        selectedAnswer: answer,
        feedback: feedback,
        isAnswered: true,
      );

      // Update quiz question
      final updatedQuestions = List<DailyQuizQuestion>.from(_currentQuiz!.questions);
      updatedQuestions[_currentQuestionIndex] = DailyQuizQuestion(
        questionId: question.questionId,
        position: question.position,
        subject: question.subject,
        chapter: question.chapter,
        chapterKey: question.chapterKey,
        questionType: question.questionType,
        questionText: question.questionText,
        questionTextHtml: question.questionTextHtml,
        questionLatex: question.questionLatex,
        options: question.options,
        imageUrl: question.imageUrl,
        timeEstimate: question.timeEstimate,
        selectionReason: question.selectionReason,
        answered: true,
        studentAnswer: answer,
        isCorrect: feedback.isCorrect,
        timeTakenSeconds: timeTaken,
      );

      _currentQuiz = DailyQuiz(
        quizId: _currentQuiz!.quizId,
        quizNumber: _currentQuiz!.quizNumber,
        learningPhase: _currentQuiz!.learningPhase,
        questions: updatedQuestions,
        generatedAt: _currentQuiz!.generatedAt,
        isRecoveryQuiz: _currentQuiz!.isRecoveryQuiz,
      );

      _isSubmittingAnswer = false;
      _error = null;
      _saveQuizState();
      notifyListeners();

      return feedback;
    } catch (e) {
      _isSubmittingAnswer = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Move to next question
  void nextQuestion() {
    if (_currentQuestionIndex < totalQuestions - 1) {
      _currentQuestionIndex++;
      
      // Initialize question state if not exists
      if (!_questionStates.containsKey(_currentQuestionIndex)) {
        _questionStates[_currentQuestionIndex] = QuestionState(
          startTime: DateTime.now(),
          elapsedSeconds: 0,
        );
      }
      
      notifyListeners();
    }
  }

  /// Move to previous question
  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  /// Jump to specific question
  void goToQuestion(int index) {
    if (index >= 0 && index < totalQuestions) {
      _currentQuestionIndex = index;
      
      // Initialize question state if not exists
      if (!_questionStates.containsKey(_currentQuestionIndex)) {
        _questionStates[_currentQuestionIndex] = QuestionState(
          startTime: DateTime.now(),
          elapsedSeconds: 0,
        );
      }
      
      notifyListeners();
    }
  }

  /// Update question timer
  void updateQuestionTimer(int index, int elapsedSeconds) {
    final state = _questionStates[index];
    if (state != null && !state.isAnswered) {
      _questionStates[index] = state.copyWith(elapsedSeconds: elapsedSeconds);
      // Save state periodically (every 5 seconds to avoid too frequent writes)
      if (elapsedSeconds % 5 == 0) {
        _saveQuizState();
      }
      notifyListeners();
    }
  }

  /// Complete the quiz
  Future<Map<String, dynamic>> completeQuiz() async {
    if (_currentQuiz == null) {
      throw Exception('No quiz available');
    }

    _isCompletingQuiz = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final result = await ApiService.completeDailyQuiz(
        authToken: token,
        quizId: _currentQuiz!.quizId,
      );

      _isCompletingQuiz = false;
      _error = null;
      await _storageService.clearQuizState(); // Clear saved state on completion
      notifyListeners();

      return result;
    } catch (e) {
      _isCompletingQuiz = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Load quiz result
  Future<void> loadQuizResult(String quizId) async {
    _isLoadingResult = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final result = await ApiService.getDailyQuizResult(
        authToken: token,
        quizId: quizId,
      );

      _quizResult = result;
      _isLoadingResult = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _isLoadingResult = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Load summary (for home screen)
  Future<void> loadSummary() async {
    _isLoadingSummary = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final summary = await ApiService.getDailyQuizSummary(authToken: token);
      _summary = summary;
      _isLoadingSummary = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _isLoadingSummary = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Load progress (for home screen)
  Future<void> loadProgress() async {
    _isLoadingProgress = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final progress = await ApiService.getDailyQuizProgress(authToken: token);
      _progress = progress;
      _isLoadingProgress = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _isLoadingProgress = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider state
  void reset() {
    _currentQuiz = null;
    _quizResult = null;
    _currentQuestionIndex = 0;
    _questionStates.clear();
    _quizStartedAt = null;
    _error = null;
    _storageService.clearQuizState();
    notifyListeners();
  }

  /// Restore quiz state from storage
  Future<void> _restoreQuizState() async {
    try {
      _isRestoringState = true;
      notifyListeners();

      // Check if state exists and is not expired
      if (!await _storageService.hasSavedQuizState()) {
        _isRestoringState = false;
        notifyListeners();
        return;
      }

      if (await _storageService.isStateExpired()) {
        await _storageService.clearQuizState();
        _isRestoringState = false;
        notifyListeners();
        return;
      }

      final savedState = await _storageService.loadQuizState();
      if (savedState == null) {
        _isRestoringState = false;
        notifyListeners();
        return;
      }

      // Restore quiz
      _currentQuiz = savedState.quiz;
      _currentQuestionIndex = savedState.currentIndex;
      _quizStartedAt = savedState.startedAt;

      // Restore question states
      _questionStates.clear();
      for (final entry in savedState.questionStates.entries) {
        final stateData = entry.value;
        _questionStates[entry.key] = QuestionState(
          startTime: stateData.startTime,
          elapsedSeconds: stateData.elapsedSeconds,
          selectedAnswer: stateData.selectedAnswer,
          feedback: stateData.feedback,
          isAnswered: stateData.isAnswered,
          showDetailedExplanation: stateData.showDetailedExplanation,
        );
      }

      _isRestoringState = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error restoring quiz state: $e');
      _isRestoringState = false;
      notifyListeners();
    }
  }

  /// Save current quiz state to storage
  Future<void> _saveQuizState() async {
    if (_currentQuiz == null) return;

    try {
      // Convert QuestionState to QuestionStateData for storage
      final questionStatesData = _questionStates.map((key, value) {
        return MapEntry(key, QuestionStateData(
          startTime: value.startTime,
          elapsedSeconds: value.elapsedSeconds,
          selectedAnswer: value.selectedAnswer,
          isAnswered: value.isAnswered,
          showDetailedExplanation: value.showDetailedExplanation,
          feedback: value.feedback,
        ));
      });

      await _storageService.saveQuizState(
        quiz: _currentQuiz!,
        currentIndex: _currentQuestionIndex,
        questionStates: questionStatesData,
        startedAt: _quizStartedAt,
      );
    } catch (e) {
      debugPrint('Error saving quiz state: $e');
    }
  }

  /// Check if there's a saved quiz state to restore
  Future<bool> hasSavedState() async {
    if (!await _storageService.hasSavedQuizState()) {
      return false;
    }
    return !await _storageService.isStateExpired();
  }

  bool get isRestoringState => _isRestoringState;

  void debugPrint(String message) {
    print('[DailyQuizProvider] $message');
  }
}

/// Question State Model
class QuestionState {
  final DateTime startTime;
  final int elapsedSeconds;
  final String? selectedAnswer;
  final AnswerFeedback? feedback;
  final bool isAnswered;
  final bool showDetailedExplanation;

  QuestionState({
    required this.startTime,
    this.elapsedSeconds = 0,
    this.selectedAnswer,
    this.feedback,
    this.isAnswered = false,
    this.showDetailedExplanation = true,
  });

  QuestionState copyWith({
    DateTime? startTime,
    int? elapsedSeconds,
    String? selectedAnswer,
    AnswerFeedback? feedback,
    bool? isAnswered,
    bool? showDetailedExplanation,
  }) {
    return QuestionState(
      startTime: startTime ?? this.startTime,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      selectedAnswer: selectedAnswer ?? this.selectedAnswer,
      feedback: feedback ?? this.feedback,
      isAnswered: isAnswered ?? this.isAnswered,
      showDetailedExplanation: showDetailedExplanation ?? this.showDetailedExplanation,
    );
  }
}

