/// Assessment Question Screen
/// Displays questions one at a time with forward-only navigation
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/assessment_question.dart';
import '../models/assessment_response.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/assessment_storage_service.dart';
import '../services/offline/connectivity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/latex_widget.dart';
import '../widgets/app_header.dart';
import '../widgets/safe_svg_widget.dart';
import 'package:flutter_html/flutter_html.dart';
import 'assessment_loading_screen.dart';

class AssessmentQuestionScreen extends StatefulWidget {
  const AssessmentQuestionScreen({super.key});

  @override
  State<AssessmentQuestionScreen> createState() => _AssessmentQuestionScreenState();
}

class _AssessmentQuestionScreenState extends State<AssessmentQuestionScreen> with WidgetsBindingObserver {
  List<AssessmentQuestion>? _questions;
  int _currentQuestionIndex = 0;
  Map<int, AssessmentResponse> _responses = {};
  Map<int, DateTime> _questionStartTimes = {};
  Map<int, TextEditingController> _numericalControllers = {}; // Store controllers per question
  Timer? _timer;
  Timer? _autoSaveTimer;
  int _remainingSeconds = 45 * 60; // 45 minutes in seconds
  static const int _totalAssessmentSeconds = 45 * 60; // 45 minutes - constant duration
  DateTime? _assessmentStartTime;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  bool _isOffline = false; // Track if error is due to being offline
  final AssessmentStorageService _storageService = AssessmentStorageService();

  // Flag to track if widget is disposed
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAssessment();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _autoSaveTimer?.cancel();
    // Dispose all controllers
    for (var controller in _numericalControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && !_isDisposed) {
      // App came back from background - recalculate timer based on wall clock
      if (mounted) {
        _recalculateRemainingTime();
      }
    } else if (state == AppLifecycleState.paused && !_isDisposed) {
      // App going to background - save state immediately
      if (mounted) {
        _saveState();
      }
    }
  }

  /// Recalculate remaining time based on wall clock time
  /// This ensures timer continues even when app is backgrounded or device sleeps
  void _recalculateRemainingTime() {
    if (_assessmentStartTime == null || _isDisposed) return;

    final now = DateTime.now();
    final elapsedSeconds = now.difference(_assessmentStartTime!).inSeconds;
    final newRemainingSeconds = _totalAssessmentSeconds - elapsedSeconds;

    if (!_isDisposed && mounted) {
      setState(() {
        _remainingSeconds = newRemainingSeconds;
      });
    }

    print('[Timer] Recalculated: elapsed=${elapsedSeconds}s, remaining=${newRemainingSeconds}s');
  }

  Future<void> _initializeAssessment() async {
    // Try to restore saved state first
    final savedState = await _storageService.loadAssessmentState();

    if (_isDisposed || !mounted) return; // Check after async operation

    if (savedState != null) {
      // Validate saved state has required data
      if (savedState.startTime == null) {
        print('[Assessment] WARNING: Saved state has null startTime, discarding saved state');
        await _storageService.clearAssessmentState();
        // Will fall through to load questions normally below
      } else {
        // Restore from saved state
        if (!_isDisposed && mounted) {
          setState(() {
          _currentQuestionIndex = savedState.currentIndex;
          _assessmentStartTime = savedState.startTime;
          _questionStartTimes = savedState.questionStartTimes;

          // Convert saved responses back to AssessmentResponse objects
          // We'll fill in the questionId after loading questions
          _responses = savedState.responses.map((key, value) => MapEntry(
            key,
            AssessmentResponse(
              questionId: '', // Will be filled after loading questions
              studentAnswer: value,
              timeTakenSeconds: 0, // Will be recalculated
            ),
          ));
          });

          // Recalculate remaining time based on elapsed wall clock time
          // This ensures timer is accurate even if app was killed/backgrounded
          _recalculateRemainingTime();
        }
      }

      print('[Timer] Restored state: startTime=${savedState.startTime}, savedRemaining=${savedState.remainingSeconds}s, recalculated=${_remainingSeconds}s');
    } else {
      // New assessment
      _assessmentStartTime = DateTime.now();
    }

    await _loadQuestions();
    if (_isDisposed || !mounted) return; // Check before starting timers

    _startTimer();
    if (_isDisposed || !mounted) return; // Check before starting auto-save

    _startAutoSave();
  }

  Future<void> _loadQuestions() async {
    try {
      // Check connectivity first
      final connectivityService = ConnectivityService();
      final isOnline = await connectivityService.checkRealConnectivity();

      if (!isOnline) {
        if (!_isDisposed && mounted) {
          setState(() {
            _isOffline = true;
            _error = 'No internet connection';
            _isLoading = false;
          });
        }
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) {
        if (!_isDisposed && mounted) {
          setState(() {
            _error = 'Authentication required. Please log in again.';
            _isLoading = false;
          });
        }
        return;
      }

      final questions = await ApiService.getAssessmentQuestions(authToken: token);

      if (!_isDisposed && mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
          _isOffline = false;

          // Update response objects with correct question IDs
          if (_responses.isNotEmpty) {
            final updatedResponses = <int, AssessmentResponse>{};
            for (var entry in _responses.entries) {
              if (entry.key < questions.length) {
                updatedResponses[entry.key] = AssessmentResponse(
                  questionId: questions[entry.key].questionId,
                  studentAnswer: entry.value.studentAnswer,
                  timeTakenSeconds: entry.value.timeTakenSeconds,
                );
              }
            }
            _responses = updatedResponses;
          }

          if (questions.isNotEmpty && !_questionStartTimes.containsKey(0)) {
            _questionStartTimes[0] = DateTime.now();
          }
        });
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        // Check if error is due to network issue
        final errorMsg = e.toString().toLowerCase();
        final isNetworkError = errorMsg.contains('socketexception') ||
            errorMsg.contains('connection') ||
            errorMsg.contains('network') ||
            errorMsg.contains('timeout') ||
            errorMsg.contains('host');

        setState(() {
          _isOffline = isNetworkError;
          _error = isNetworkError
              ? 'No internet connection'
              : e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (mounted && _assessmentStartTime != null) {
        // Recalculate based on wall clock time to ensure accuracy
        // This way the timer continues correctly even if app was paused/resumed
        final now = DateTime.now();
        final elapsedSeconds = now.difference(_assessmentStartTime!).inSeconds;
        final newRemainingSeconds = _totalAssessmentSeconds - elapsedSeconds;

        setState(() {
          _remainingSeconds = newRemainingSeconds;
          // Note: We no longer auto-submit when timer expires
          // User can continue past 45 minutes
        });
      }
    });
  }

  void _startAutoSave() {
    // Auto-save every 10 seconds
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _saveState();
    });
  }

  Future<void> _saveState() async {
    if (_questions == null || _assessmentStartTime == null) return;

    // Convert responses to simple map for storage
    final responsesMap = _responses.map(
      (key, value) => MapEntry(key, value.studentAnswer),
    );

    await _storageService.saveAssessmentState(
      responses: responsesMap,
      currentIndex: _currentQuestionIndex,
      remainingSeconds: _remainingSeconds,
      startTime: _assessmentStartTime!,
      questionStartTimes: _questionStartTimes,
    );
  }

  String _formatTime(int seconds) {
    final isNegative = seconds < 0;
    final absSeconds = seconds.abs();
    final minutes = absSeconds ~/ 60;
    final secs = absSeconds % 60;
    final formatted = '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return isNegative ? '+$formatted' : formatted;
  }

  Color _getTimerColor() {
    if (_remainingSeconds < 0) {
      // Overtime - red
      return AppColors.errorRed;
    } else if (_remainingSeconds < 300) {
      // Less than 5 minutes remaining - orange
      return Colors.orange;
    } else {
      // Normal - white
      return Colors.white;
    }
  }

  bool get _isTimerWarning => _remainingSeconds < 300 && _remainingSeconds >= 0;
  bool get _isTimerOvertime => _remainingSeconds < 0;

  AssessmentQuestion? get _currentQuestion {
    if (_questions == null || _currentQuestionIndex >= _questions!.length) {
      return null;
    }
    return _questions![_currentQuestionIndex];
  }

  bool get _isLastQuestion => _currentQuestionIndex == (_questions?.length ?? 0) - 1;
  bool get _hasAnswer {
    if (!_responses.containsKey(_currentQuestionIndex)) return false;
    final answer = _responses[_currentQuestionIndex]?.studentAnswer ?? '';
    return answer.trim().isNotEmpty;
  }

  void _recordAnswer(String answer) {
    final question = _currentQuestion;
    if (question == null) return;

    final startTime = _questionStartTimes[_currentQuestionIndex] ?? DateTime.now();
    final timeTaken = DateTime.now().difference(startTime).inSeconds;

    // Update response and trigger UI rebuild for instant feedback
    setState(() {
      _responses[_currentQuestionIndex] = AssessmentResponse(
        questionId: question.questionId,
        studentAnswer: answer,
        timeTakenSeconds: timeTaken,
      );
    });

    // Save state after recording answer
    _saveState();
  }

  void _nextQuestion() {
    if (_isLastQuestion) {
      _submitAssessment();
    } else {
      // Dispose controller for current question if it exists (memory leak fix)
      // We're moving away from this question, so we don't need its controller anymore
      final oldController = _numericalControllers.remove(_currentQuestionIndex);
      oldController?.dispose();

      setState(() {
        _currentQuestionIndex++;
        _questionStartTimes[_currentQuestionIndex] = DateTime.now();
      });
      // Save state after moving to next question
      _saveState();
    }
  }

  Future<void> _submitAssessment() async {
    if (_isSubmitting) return;
    
    final question = _currentQuestion;
    if (question != null && !_hasAnswer) {
      // Record current question if not answered
      _recordAnswer('');
    }

    if (_responses.length != _questions?.length) {
      // Show error - not all questions answered
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please answer all questions before submitting.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return;
    }

    if (!_isDisposed && mounted) {
      setState(() {
        _isSubmitting = true;
      });
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) {
        throw Exception('Authentication required');
      }

      final responsesList = List.generate(
        _questions!.length,
        (index) => _responses[index]!,
      );

      final result = await ApiService.submitAssessment(
        authToken: token,
        responses: responsesList,
      );

      if (_isDisposed || !mounted) return;

      if (mounted) {
        if (result.success && result.data != null) {
          // Clear saved state after successful submission
          await _storageService.clearAssessmentState();

          // Get userId from auth service
          final currentUser = authService.currentUser;
          final userId = currentUser?.uid;

          if (userId == null) {
            throw Exception('User not authenticated');
          }

          // Calculate total time taken
          final totalSeconds = _assessmentStartTime != null
              ? DateTime.now().difference(_assessmentStartTime!).inSeconds
              : 0;

          // Navigate to loading screen (will poll for results)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AssessmentLoadingScreen(
                assessmentData: result.data!,
                userId: userId, // Pass userId for polling
                authToken: token, // Pass token for polling
                totalTimeSeconds: totalSeconds, // Pass total time
              ),
            ),
          );
        } else {
          throw Exception(result.error ?? 'Failed to submit assessment');
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.errorRed,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _submitAssessment();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    if (_error != null) {
      // Show user-friendly offline screen
      if (_isOffline) {
        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Offline icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: 40,
                      color: AppColors.errorRed,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'You\'re Offline',
                    style: AppTextStyles.headerMedium.copyWith(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Initial Assessment requires an internet connection to load questions.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Go Back button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Retry button (secondary)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isOffline = false;
                          _isLoading = true;
                        });
                        _loadQuestions();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryPurple,
                        side: const BorderSide(color: AppColors.primaryPurple),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Show generic error screen with back button
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 40,
                    color: AppColors.errorRed,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Something Went Wrong',
                  style: AppTextStyles.headerMedium.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Go Back button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Retry button (secondary)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isLoading = true;
                      });
                      _loadQuestions();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryPurple,
                      side: const BorderSide(color: AppColors.primaryPurple),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions == null || _currentQuestion == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    return PopScope(
      canPop: false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(
          children: [
            // Combined header with timer, progress, question count, and subject
            _buildHeader(),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentQuestion!.hasImage) ...[
                      _buildQuestionImage(),
                      const SizedBox(height: 16),
                    ],
                    _buildQuestionText(),
                    const SizedBox(height: 24),
                    _buildAnswerInput(),
                  ],
                ),
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final progress = (_currentQuestionIndex + 1) / (_questions?.length ?? 30);
    final question = _currentQuestion!;
    
    return Container(
      decoration: const BoxDecoration(
        // Purple to pink gradient matching design
        gradient: LinearGradient(
          colors: [Color(0xFF9333EA), Color(0xFFEC4899)], // primaryPurple to secondaryPink
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: Logo (left), Title (center), and Timer (right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // JEEVibe logo on the left
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          'assets/images/JEEVibeLogo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                  ),
                  // Title centered
                  Expanded(
                    child: Text(
                      'Initial Assessment',
                      style: AppTextStyles.headerWhite.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Timer on the right
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isTimerOvertime
                          ? AppColors.errorRed
                          : _isTimerWarning
                              ? Colors.orange
                              : Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(_remainingSeconds),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Bottom row: Question count (left) and Subject (right)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Question count
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${_questions?.length ?? 30}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Subject
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      question.subject,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionImage() {
    final imageUrl = _currentQuestion!.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SafeSvgWidget(
          url: imageUrl,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => Container(
            height: 200,
            color: AppColors.borderGray,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
          ),
          errorBuilder: (context, error, stackTrace) => Container(
            height: 200,
            color: AppColors.borderGray,
            child: const Center(
              child: Icon(Icons.broken_image, color: AppColors.textLight),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionText() {
    final question = _currentQuestion!;
    
    // Show question_text/html which already contains formatted LaTeX
    // No need to show question_latex separately as it's already embedded in question_text
    final textContent = question.questionTextHtml ?? question.questionText;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Html(
        data: textContent,
        style: {
          "body": Style(
            fontSize: FontSize(AppTextStyles.bodyLarge.fontSize ?? 16),
            color: AppTextStyles.bodyLarge.color,
            lineHeight: LineHeight(AppTextStyles.bodyLarge.height ?? 1.6),
          ),
          "p": Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          "strong": Style(
            fontWeight: FontWeight.bold,
          ),
          "b": Style(
            fontWeight: FontWeight.bold,
          ),
          "i": Style(
            fontStyle: FontStyle.italic,
          ),
          "em": Style(
            fontStyle: FontStyle.italic,
          ),
          "u": Style(
            textDecoration: TextDecoration.underline,
          ),
          "sub": Style(
            fontSize: FontSize((AppTextStyles.bodyLarge.fontSize ?? 16) * 0.75),
            verticalAlign: VerticalAlign.sub,
          ),
          "sup": Style(
            fontSize: FontSize((AppTextStyles.bodyLarge.fontSize ?? 16) * 0.75),
            verticalAlign: VerticalAlign.sup,
          ),
        },
      ),
    );
  }

  Widget _buildAnswerInput() {
    final question = _currentQuestion!;
    final currentAnswer = _responses[_currentQuestionIndex]?.studentAnswer ?? '';

    if (question.isMcq) {
      return _buildMcqOptions(currentAnswer);
    } else {
      return _buildNumericalInput(currentAnswer);
    }
  }

  Widget _buildMcqOptions(String selectedAnswer) {
    final question = _currentQuestion!;
    final options = question.options ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your answer:',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...options.map((option) {
          final isSelected = selectedAnswer == option.optionId;
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                _recordAnswer(option.optionId);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.cardLightPurple 
                      : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryPurple
                        : AppColors.borderGray,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryPurple.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    // Option ID badge (A, B, C, D)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryPurple
                            : AppColors.borderGray,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          option.optionId,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected ? Colors.white : AppColors.textMedium,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Option text (use HTML version if available for proper formatting)
                    Expanded(
                      child: Html(
                        data: option.html ?? option.text,
                        style: {
                          "body": Style(
                            fontSize: FontSize(AppTextStyles.bodyMedium.fontSize ?? 14),
                            color: AppTextStyles.bodyMedium.color,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            lineHeight: LineHeight(AppTextStyles.bodyMedium.height ?? 1.5),
                          ),
                          "p": Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                          ),
                          "strong": Style(
                            fontWeight: FontWeight.bold,
                          ),
                          "b": Style(
                            fontWeight: FontWeight.bold,
                          ),
                          "i": Style(
                            fontStyle: FontStyle.italic,
                          ),
                          "em": Style(
                            fontStyle: FontStyle.italic,
                          ),
                          "u": Style(
                            textDecoration: TextDecoration.underline,
                          ),
                          "sub": Style(
                            fontSize: FontSize((AppTextStyles.bodyMedium.fontSize ?? 14) * 0.75),
                            verticalAlign: VerticalAlign.sub,
                          ),
                          "sup": Style(
                            fontSize: FontSize((AppTextStyles.bodyMedium.fontSize ?? 14) * 0.75),
                            verticalAlign: VerticalAlign.sup,
                          ),
                        },
                      ),
                    ),
                    // Checkmark icon when selected
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle,
                        color: AppColors.primaryPurple,
                        size: 24,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNumericalInput(String currentAnswer) {
    // Get or create controller for this question
    // Controller persists across rebuilds and is only created once per question
    if (!_numericalControllers.containsKey(_currentQuestionIndex)) {
      _numericalControllers[_currentQuestionIndex] = TextEditingController(text: currentAnswer);
    }
    
    final controller = _numericalControllers[_currentQuestionIndex]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your answer:',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(
            hintText: 'Enter numerical value',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: AppTextStyles.bodyLarge,
          onChanged: (value) {
            // ALWAYS update answer, even if empty, to properly handle deletion
            _recordAnswer(value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Enter decimal values (e.g., 2.5, -1.23)',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    final canProceed = _hasAnswer && !_isSubmitting;
    
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canProceed ? _nextQuestion : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: canProceed
                      ? const LinearGradient(
                          colors: [Color(0xFF9333EA), Color(0xFFEC4899)], // Purple to pink
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : LinearGradient(
                          colors: [
                            Colors.grey.shade400,
                            Colors.grey.shade500,
                          ], // Gray when disabled
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLastQuestion ? 'Submit Assessment' : 'Next Question',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!_isLastQuestion) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
