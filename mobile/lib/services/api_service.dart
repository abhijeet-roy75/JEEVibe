import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../models/solution_model.dart';
import '../models/assessment_question.dart';
import '../models/assessment_response.dart';
import '../models/daily_quiz_question.dart';
import '../utils/performance_tracker.dart';
import 'firebase/auth_service.dart';

/// Callback type for session expiry notifications
typedef SessionExpiredCallback = void Function(String code, String message);

class ApiService {
  // Backend URL
  // For local development: http://localhost:3000 (iOS simulator) or http://YOUR_COMPUTER_IP:3000 (real device)
  // For production (Singapore region): https://jeevibe-thzi.onrender.com
  // Current IP: 192.168.5.81
  static const String baseUrl = 'https://jeevibe-thzi.onrender.com';
  // static const String baseUrl = 'http://localhost:3000'; // For local development
  // static const String baseUrl = 'http://192.168.5.81:3000'; // For real device testing

  // ============================================================================
  // SESSION MANAGEMENT
  // ============================================================================

  /// Callback to notify app when session expires (set from main.dart or app widget)
  static SessionExpiredCallback? onSessionExpired;

  /// Check if a response indicates session expiry and notify the app
  /// Returns true if session expired and was handled, false otherwise
  static bool _checkSessionExpiry(http.Response response) {
    if (response.statusCode == 401) {
      try {
        final jsonData = jsonDecode(response.body);
        final code = jsonData['code'] as String?;

        // Check for session-related error codes
        if (code == 'SESSION_EXPIRED' ||
            code == 'SESSION_TOKEN_MISSING' ||
            code == 'SESSION_EXPIRED_AGE' ||
            code == 'NO_ACTIVE_SESSION') {
          final message = jsonData['error'] as String? ?? 'Session expired';

          // Notify the app
          if (onSessionExpired != null) {
            onSessionExpired!(code!, message);
          }

          return true;
        }
      } catch (e) {
        // Not a JSON response or parsing failed - not a session error
      }
    }
    return false;
  }

  /// Get authentication headers including session token
  static Future<Map<String, String>> getAuthHeaders(String authToken) async {
    final sessionToken = await AuthService.getSessionToken();
    final deviceId = await AuthService.getDeviceId();

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
      if (sessionToken != null) 'x-session-token': sessionToken,
      'x-device-id': deviceId,
    };
  }

  /// Get valid authentication token with automatic refresh
  /// Handles token expiration and refresh automatically
  static Future<String> _getValidToken(dynamic authService) async {
    var token = await authService.getIdToken();

    // If token is null, try to refresh
    if (token == null) {
      final user = authService.currentUser;
      if (user != null) {
        // Force token refresh
        try {
          token = await user.getIdToken(true); // true = force refresh
        } catch (e) {
          throw Exception('Failed to refresh authentication token. Please sign in again.');
        }
      }
    }

    if (token == null) {
      throw Exception('Authentication required. Please sign in again.');
    }

    return token;
  }
  
  /// Retry request with exponential backoff for network errors
  static Future<T> _retryRequest<T>(Future<T> Function() request, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await request();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        
        // Only retry on network errors
        final errorStr = e.toString();
        if (errorStr.contains('SocketException') || 
            errorStr.contains('ClientException') ||
            errorStr.contains('timeout')) {
          // Exponential backoff: 2s, 4s, 8s
          await Future.delayed(Duration(seconds: 2 * attempts));
          continue;
        }
        rethrow; // Don't retry on other errors
      }
    }
    throw Exception('Max retries exceeded');
  }
  
  /// Upload image and get solution
  /// Requires Firebase ID token for authentication
  static Future<Solution> solveQuestion({
    required File imageFile,
    required String authToken,
  }) async {
    final tracker = PerformanceTracker('API Call - Solve Question');
    tracker.start();

    return _retryRequest(() async {
      try {
      tracker.step('Creating multipart request');
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/solve'),
      );

      // Add authentication headers including session token
      final authHeaders = await getAuthHeaders(authToken);
      request.headers.addAll(authHeaders);

      // Add image file with explicit content type
      tracker.step('Reading image file');
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      MediaType contentType;
      if (fileExtension == 'png') {
        contentType = MediaType('image', 'png');
      } else if (fileExtension == 'heic') {
        contentType = MediaType('image', 'heic');
      } else {
        contentType = MediaType('image', 'jpeg');
      }

      tracker.step('Attaching image to request');
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: contentType,
        ),
      );

      // Send request with 90 second timeout (some complex questions take time)
      tracker.step('Sending HTTP request to backend');
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          tracker.end();
          throw Exception('Request timed out. This question might be taking longer than usual to process. Please try again or try a clearer photo.');
        },
      );
      tracker.step('Backend response received');

      tracker.step('Reading response body');
      var response = await http.Response.fromStream(streamedResponse);
      tracker.step('Response body read complete');

      if (response.statusCode == 200) {
        try {
          tracker.step('Parsing JSON response');
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true && jsonData['data'] != null) {
            try {
              tracker.step('Creating Solution object from response');
              final solution = Solution.fromJson(jsonData['data']);
              tracker.end();
              return solution;
            } catch (e) {
              tracker.end();
              throw Exception('Failed to parse solution data: $e');
            }
          } else {
            // Handle new error format
            tracker.end();
            final errorMsg = jsonData['error'] ?? 'Unknown error';
            final requestId = jsonData['requestId'];
            throw Exception('$errorMsg${requestId != null ? ' (Request ID: $requestId)' : ''}');
          }
        } catch (e) {
          tracker.end();
          if (e is Exception) rethrow;
          throw Exception('Failed to decode response: $e');
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error'] ?? 'Failed to solve question';
          final requestId = errorData['requestId'];
          
          // Handle rate limiting specifically
          if (response.statusCode == 429) {
            throw Exception('Too many requests. Please wait a moment and try again.');
          }
          
          throw Exception('$errorMsg${requestId != null ? ' (Request ID: $requestId)' : ''}');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Server error (${response.statusCode}): ${response.body.substring(0, 200)}');
        }
      }
      } on TimeoutException {
        throw Exception('Request timed out after 90 seconds. This question might be taking longer than usual to process. Please try again or try a clearer photo.');
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        // Check if error message already contains timeout info
        if (e.toString().contains('timed out') || e.toString().contains('timeout')) {
          rethrow;
        }
        throw Exception('Failed to solve question: ${e.toString()}');
      }
    });
  }

  /// Generate a single practice question (for lazy loading)
  /// Requires Firebase ID token for authentication
  static Future<FollowUpQuestion> generateSingleQuestion({
    required String authToken,
    required String recognizedQuestion,
    required Map<String, dynamic> solution,
    required String topic,
    required String difficulty,
    required int questionNumber,
  }) async {
    return _retryRequest(() async {
      try {
      final headers = await getAuthHeaders(authToken);
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate-single-question'),
        headers: headers,
        body: json.encode({
          'recognizedQuestion': recognizedQuestion,
          'solution': solution,
          'topic': topic,
          'difficulty': difficulty,
          'questionNumber': questionNumber,
        }),
      ).timeout(const Duration(seconds: 60));

      // Check for session expiry
      if (_checkSessionExpiry(response)) {
        throw Exception('Session expired. Please sign in again.');
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          return FollowUpQuestion.fromJson(jsonData['data']['question'] as Map<String, dynamic>);
        } else {
          final errorMsg = jsonData['error'] ?? 'Invalid response format';
          final requestId = jsonData['requestId'];
          throw Exception('$errorMsg${requestId != null ? ' (Request ID: $requestId)' : ''}');
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMsg = errorData['error'] ?? 'Failed to generate question';
        final requestId = errorData['requestId'];
        
        // Handle rate limiting
        if (response.statusCode == 429) {
          throw Exception('Too many requests. Please wait a moment and try again.');
        }
        
        throw Exception('$errorMsg${requestId != null ? ' (Request ID: $requestId)' : ''}');
      }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to generate question: ${e.toString()}');
      }
    });
  }

  /// Generate follow-up practice questions on demand (deprecated - use generateSingleQuestion)
  /// Requires Firebase ID token for authentication
  static Future<List<FollowUpQuestion>> generatePracticeQuestions({
    required String authToken,
    required String recognizedQuestion,
    required Map<String, dynamic> solution,
    required String topic,
    required String difficulty,
  }) async {
    try {
      final headers = await getAuthHeaders(authToken);
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate-practice-questions'),
        headers: headers,
        body: json.encode({
          'recognizedQuestion': recognizedQuestion,
          'solution': solution,
          'topic': topic,
          'difficulty': difficulty,
        }),
      ).timeout(const Duration(seconds: 60));

      // Check for session expiry
      if (_checkSessionExpiry(response)) {
        throw Exception('Session expired. Please sign in again.');
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final questions = jsonData['data']['questions'] as List<dynamic>;
          return questions
              .map((q) => FollowUpQuestion.fromJson(q as Map<String, dynamic>))
              .toList();
        } else {
          final errorMsg = jsonData['error'] ?? 'Invalid response format';
          final requestId = jsonData['requestId'];
          throw Exception('$errorMsg${requestId != null ? ' (Request ID: $requestId)' : ''}');
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMsg = errorData['error'] ?? 'Failed to generate practice questions';
        final requestId = errorData['requestId'];
        
        // Handle rate limiting
        if (response.statusCode == 429) {
          throw Exception('Too many requests. Please wait a moment and try again.');
        }
        
        throw Exception('$errorMsg${requestId != null ? ' (Request ID: $requestId)' : ''}');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('Failed to generate practice questions: ${e.toString()}');
    }
  }

  /// Get snap practice questions from database with AI fallback
  /// Prioritizes database questions for faster response and consistency
  /// Falls back to AI generation if no matching questions in database
  ///
  /// Returns a map containing:
  /// - questions: List<FollowUpQuestion>
  /// - source: "database" | "ai" | "mixed"
  static Future<Map<String, dynamic>> getSnapPracticeQuestions({
    required String authToken,
    required String subject,
    required String topic,
    required String difficulty,
    int count = 3,
    String language = 'en',
    String? recognizedQuestion,
    Map<String, dynamic>? solution,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.post(
          Uri.parse('$baseUrl/api/snap-practice/questions'),
          headers: headers,
          body: json.encode({
            'subject': subject,
            'topic': topic,
            'difficulty': difficulty,
            'count': count,
            'language': language,
            if (recognizedQuestion != null) 'recognizedQuestion': recognizedQuestion,
            if (solution != null) 'solution': solution,
          }),
        ).timeout(const Duration(seconds: 30));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true && jsonData['data'] != null) {
            final data = jsonData['data'];
            final questions = (data['questions'] as List<dynamic>)
                .map((q) => FollowUpQuestion.fromJson(q as Map<String, dynamic>))
                .toList();
            return {
              'questions': questions,
              'source': data['source'] ?? 'unknown',
              'dbCount': data['dbCount'],
              'aiCount': data['aiCount'],
            };
          } else {
            final errorMsg = jsonData['error'] ?? 'Invalid response format';
            final requestId = jsonData['requestId'];
            throw Exception('$errorMsg${requestId != null ? ' (Request ID: $requestId)' : ''}');
          }
        } else if (response.statusCode == 404) {
          // No questions available - return empty list
          return {
            'questions': <FollowUpQuestion>[],
            'source': 'none',
          };
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error'] ?? 'Failed to get practice questions';
          final requestId = errorData['requestId'];

          if (response.statusCode == 429) {
            throw Exception('Too many requests. Please wait a moment and try again.');
          }

          throw Exception('$errorMsg${requestId != null ? ' (Request ID: $requestId)' : ''}');
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        if (e.toString().contains('Exception:')) {
          rethrow;
        }
        throw Exception('Failed to get practice questions: ${e.toString()}');
      }
    });
  }

  /// Complete a snap practice session and record results
  /// Updates total_questions_solved, cumulative_stats, and theta (with 0.4x multiplier if correct >= 1)
  /// Requires Firebase ID token for authentication
  static Future<Map<String, dynamic>> completeSnapPractice({
    required String authToken,
    required String subject,
    required String topic,
    String? chapterKey,
    required List<Map<String, dynamic>> results,
    required int totalTimeSeconds,
    String? source,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.post(
          Uri.parse('$baseUrl/api/snap-practice/complete'),
          headers: headers,
          body: json.encode({
            'subject': subject,
            'topic': topic,
            if (chapterKey != null) 'chapter_key': chapterKey,
            'results': results,
            'total_time_seconds': totalTimeSeconds,
            if (source != null) 'source': source,
          }),
        ).timeout(const Duration(seconds: 30));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to complete snap practice';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        if (e.toString().contains('Exception:')) {
          rethrow;
        }
        throw Exception('Failed to complete snap practice: ${e.toString()}');
      }
    });
  }

  /// Health check
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get snap limits and usage from backend (uses subscription status API)
  /// Requires Firebase ID token for authentication
  static Future<Map<String, dynamic>> getSnapLimit({
    required String authToken,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          Uri.parse('$baseUrl/api/subscriptions/status'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true && jsonData['data'] != null) {
            final data = jsonData['data'];
            final snapUsage = data['usage']?['snap_solve'] ?? {};

            // Extract snap data from subscription status
            // Handle unlimited (-1) case
            final int limit = snapUsage['limit'] ?? 5;
            final int used = snapUsage['used'] ?? 0;
            final bool isUnlimited = snapUsage['is_unlimited'] ?? false;

            return {
              'used': used,
              'limit': isUnlimited ? 999 : limit, // Use high number for unlimited
              'isUnlimited': isUnlimited,
              'resetsAt': snapUsage['resets_at'],
              'tier': data['subscription']?['tier'] ?? 'free',
            };
          } else {
            throw Exception(jsonData['error'] ?? 'Invalid response format');
          }
        } else {
          throw Exception('Failed to fetch snap limit (${response.statusCode})');
        }
      } catch (e) {
        throw Exception('Failed to fetch snap limit: ${e.toString()}');
      }
    });
  }

  /// Get snap history from backend
  /// Requires Firebase ID token for authentication
  static Future<List<dynamic>> getSnapHistory({
    required String authToken,
    int limit = 20,
    String? lastDocId,
  }) async {
    return _retryRequest(() async {
      try {
        String url = '$baseUrl/api/snap-history?limit=$limit';
        if (lastDocId != null) {
          url += '&lastDocId=$lastDocId';
        }

        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        ).timeout(const Duration(seconds: 30));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true && jsonData['data'] != null) {
            return jsonData['data']['history'] as List<dynamic>;
          } else {
            throw Exception(jsonData['error'] ?? 'Invalid response format');
          }
        } else {
          throw Exception('Failed to fetch snap history (${response.statusCode})');
        }
      } catch (e) {
        throw Exception('Failed to fetch snap history: ${e.toString()}');
      }
    });
  }

  /// Get assessment questions
  /// Requires Firebase ID token for authentication
  /// Note: Uses 60s timeout to handle Render.com cold starts (one-time operation)
  static Future<List<AssessmentQuestion>> getAssessmentQuestions({
    required String authToken,
  }) async {
    try {
      final headers = await getAuthHeaders(authToken);
      final response = await http.get(
        Uri.parse('$baseUrl/api/assessment/questions'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));

      // Check for session expiry
      if (_checkSessionExpiry(response)) {
        throw Exception('Session expired. Please sign in again.');
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['questions'] != null) {
          final questions = jsonData['questions'] as List<dynamic>;
          return questions
              .map((q) => AssessmentQuestion.fromJson(q as Map<String, dynamic>))
              .toList();
        } else {
          throw Exception(jsonData['error'] ?? 'Invalid response format');
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMsg = errorData['error'] ?? 'Failed to fetch assessment questions';
        final requestId = errorData['requestId'];
        
        // Handle rate limiting
        if (response.statusCode == 429) {
          throw Exception('Too many requests. Please wait a moment and try again.');
        }
        
        throw Exception('$errorMsg${requestId != null ? ' (Request ID: $requestId)' : ''}');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('Failed to fetch assessment questions: ${e.toString()}');
    }
  }

  /// Submit assessment responses
  /// Requires Firebase ID token for authentication
  /// Returns immediately with processing status (async backend processing)
  static Future<AssessmentResult> submitAssessment({
    required String authToken,
    required List<AssessmentResponse> responses,
  }) async {
    try {
      final headers = await getAuthHeaders(authToken);
      final response = await http.post(
        Uri.parse('$baseUrl/api/assessment/submit'),
        headers: headers,
        body: json.encode({
          'responses': responses.map((r) => r.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 30));

      // Check for session expiry
      if (_checkSessionExpiry(response)) {
        throw Exception('Session expired. Please sign in again.');
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        // Backend now returns processing status immediately
        if (jsonData['status'] == 'processing') {
          return AssessmentResult(
            success: true,
            data: AssessmentData(
              assessment: {'status': 'processing'},
              thetaByChapter: {},
              thetaBySubject: {},
              subjectAccuracy: {
                'physics': {'accuracy': null, 'correct': 0, 'total': 0},
                'chemistry': {'accuracy': null, 'correct': 0, 'total': 0},
                'mathematics': {'accuracy': null, 'correct': 0, 'total': 0},
              },
              overallTheta: 0,
              overallPercentile: 0,
              chaptersExplored: 0,
              chaptersConfident: 0,
              subjectBalance: {},
            ),
          );
        }
        return AssessmentResult.fromJson(jsonData);
      } else {
        final errorData = json.decode(response.body);
        final errorMsg = errorData['error'] ?? 'Failed to submit assessment';
        final requestId = errorData['requestId'];
        
        // Handle rate limiting
        if (response.statusCode == 429) {
          return AssessmentResult(
            success: false,
            error: 'Too many requests. Please wait a moment and try again.',
          );
        }
        
        return AssessmentResult(
          success: false,
          error: errorMsg,
        );
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('Failed to submit assessment: ${e.toString()}');
    }
  }

  /// Get assessment results (for polling)
  /// Requires Firebase ID token for authentication
  static Future<AssessmentResult> getAssessmentResults({
    required String authToken,
    required String userId,
  }) async {
    try {
      final headers = await getAuthHeaders(authToken);
      final response = await http.get(
        Uri.parse('$baseUrl/api/assessment/results/$userId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      // Check for session expiry
      if (_checkSessionExpiry(response)) {
        throw Exception('Session expired. Please sign in again.');
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        // Handle processing status
        if (jsonData['status'] == 'processing') {
          return AssessmentResult(
            success: true,
            data: AssessmentData(
              assessment: {'status': 'processing'},
              thetaByChapter: {},
              thetaBySubject: {},
              subjectAccuracy: {
                'physics': {'accuracy': null, 'correct': 0, 'total': 0},
                'chemistry': {'accuracy': null, 'correct': 0, 'total': 0},
                'mathematics': {'accuracy': null, 'correct': 0, 'total': 0},
              },
              overallTheta: 0,
              overallPercentile: 0,
              chaptersExplored: 0,
              chaptersConfident: 0,
              subjectBalance: {},
            ),
          );
        }
        
        return AssessmentResult.fromJson(jsonData);
      } else {
        final errorData = json.decode(response.body);
        final errorMsg = errorData['error'] ?? 'Failed to fetch assessment results';
        final requestId = errorData['requestId'];
        
        // Handle rate limiting
        if (response.statusCode == 429) {
          return AssessmentResult(
            success: false,
            error: 'Too many requests. Please wait a moment and try again.',
          );
        }
        
        return AssessmentResult(
          success: false,
          error: errorMsg,
        );
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('Failed to fetch assessment results: ${e.toString()}');
    }
  }

  // ============================================================================
  // DAILY QUIZ API METHODS
  // ============================================================================

  /// Generate a new daily quiz or get existing active quiz
  /// Requires Firebase ID token for authentication
  static Future<DailyQuiz> generateDailyQuiz({
    required String authToken,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          Uri.parse('$baseUrl/api/daily-quiz/generate'),
          headers: headers,
        ).timeout(const Duration(seconds: 60));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true && jsonData['quiz'] != null) {
            return DailyQuiz.fromJson(jsonData['quiz'] as Map<String, dynamic>);
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          try {
            final errorData = json.decode(response.body);
            final errorMsg = errorData['error']?['message'] ?? 
                           errorData['error'] ?? 
                           'Failed to generate quiz';
            final requestId = errorData['requestId'];
            print('API Error: $errorMsg (Status: ${response.statusCode}, Request ID: $requestId)');
            throw Exception('$errorMsg${requestId != null ? ' (Request ID: $requestId)' : ''}');
          } catch (e) {
            if (e is Exception) rethrow;
            throw Exception('Server error (${response.statusCode}): ${response.body.substring(0, 200)}');
          }
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to generate quiz: ${e.toString()}');
      }
    });
  }

  /// Start a quiz (marks quiz as started, starts timer)
  /// Requires Firebase ID token for authentication
  static Future<void> startDailyQuiz({
    required String authToken,
    required String quizId,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.post(
          Uri.parse('$baseUrl/api/daily-quiz/start'),
          headers: headers,
          body: json.encode({
            'quiz_id': quizId,
          }),
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode != 200) {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to start quiz';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to start quiz: ${e.toString()}');
      }
    });
  }

  /// Submit answer for a question and get immediate feedback
  /// Requires Firebase ID token for authentication
  static Future<AnswerFeedback> submitAnswer({
    required String authToken,
    required String quizId,
    required String questionId,
    required String studentAnswer,
    required int timeTakenSeconds,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.post(
          Uri.parse('$baseUrl/api/daily-quiz/submit-answer'),
          headers: headers,
          body: json.encode({
            'quiz_id': quizId,
            'question_id': questionId,
            'student_answer': studentAnswer,
            'time_taken_seconds': timeTakenSeconds,
          }),
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            // Add student_answer to the response
            final feedbackData = Map<String, dynamic>.from(jsonData);
            feedbackData['student_answer'] = studentAnswer;
            return AnswerFeedback.fromJson(feedbackData);
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to submit answer';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to submit answer: ${e.toString()}');
      }
    });
  }

  /// Complete a quiz and update theta values
  /// Requires Firebase ID token for authentication
  static Future<Map<String, dynamic>> completeDailyQuiz({
    required String authToken,
    required String quizId,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.post(
          Uri.parse('$baseUrl/api/daily-quiz/complete'),
          headers: headers,
          body: json.encode({
            'quiz_id': quizId,
          }),
        ).timeout(const Duration(seconds: 30));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to complete quiz';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to complete quiz: ${e.toString()}');
      }
    });
  }

  /// Get detailed quiz result
  /// Requires Firebase ID token for authentication
  static Future<Map<String, dynamic>> getDailyQuizResult({
    required String authToken,
    required String quizId,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          Uri.parse('$baseUrl/api/daily-quiz/result/$quizId'),
          headers: headers,
        ).timeout(const Duration(seconds: 30));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to get quiz result';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to get quiz result: ${e.toString()}');
      }
    });
  }

  /// Get daily quiz summary for dashboard
  /// Requires Firebase ID token for authentication
  static Future<Map<String, dynamic>> getDailyQuizSummary({
    required String authToken,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          Uri.parse('$baseUrl/api/daily-quiz/summary'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData['summary'] as Map<String, dynamic>;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          // Check if response is HTML (server error page) vs JSON
          if (response.body.trimLeft().startsWith('<!DOCTYPE') ||
              response.body.trimLeft().startsWith('<html')) {
            throw Exception('Server temporarily unavailable (${response.statusCode}). Please try again.');
          }
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to get summary';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } on FormatException {
        throw Exception('Server returned invalid response. Please try again.');
      } catch (e) {
        throw Exception('Failed to get summary: ${e.toString()}');
      }
    });
  }

  /// Get daily quiz progress data
  /// Requires Firebase ID token for authentication
  static Future<Map<String, dynamic>> getDailyQuizProgress({
    required String authToken,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          Uri.parse('$baseUrl/api/daily-quiz/progress'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData['progress'] as Map<String, dynamic>;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          // Check if response is HTML (server error page) vs JSON
          if (response.body.trimLeft().startsWith('<!DOCTYPE') ||
              response.body.trimLeft().startsWith('<html')) {
            throw Exception('Server temporarily unavailable (${response.statusCode}). Please try again.');
          }
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to get progress';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } on FormatException {
        throw Exception('Server returned invalid response. Please try again.');
      } catch (e) {
        throw Exception('Failed to get progress: ${e.toString()}');
      }
    });
  }

  /// Get daily quiz history for the History screen
  /// Returns list of completed quizzes with pagination
  /// Requires Firebase ID token for authentication
  static Future<Map<String, dynamic>> getDailyQuizHistory({
    required String authToken,
    int limit = 20,
    int offset = 0,
    int? days,
  }) async {
    return _retryRequest(() async {
      try {
        final queryParams = <String, String>{
          'limit': limit.toString(),
          'offset': offset.toString(),
        };

        // Add days filter if provided (for tier-based filtering)
        if (days != null && days > 0) {
          final startDate = DateTime.now().subtract(Duration(days: days));
          queryParams['start_date'] = startDate.toIso8601String();
        }

        final uri = Uri.parse('$baseUrl/api/daily-quiz/history')
            .replace(queryParameters: queryParams);

        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          uri,
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData as Map<String, dynamic>;
          } else {
            final errorMsg = jsonData['error']?['message'] ??
                jsonData['error'] ??
                'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          if (response.body.trimLeft().startsWith('<!DOCTYPE') ||
              response.body.trimLeft().startsWith('<html')) {
            throw Exception(
                'Server temporarily unavailable (${response.statusCode}). Please try again.');
          }
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ??
              errorData['error'] ??
              'Failed to get quiz history';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception(
            'No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } on FormatException {
        throw Exception('Server returned invalid response. Please try again.');
      } catch (e) {
        throw Exception('Failed to get quiz history: ${e.toString()}');
      }
    });
  }

  /// Submit user feedback
  /// Requires Firebase ID token for authentication
  static Future<void> submitFeedback({
    required String authToken,
    required Map<String, dynamic> feedbackData,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.post(
          Uri.parse('$baseUrl/api/feedback'),
          headers: headers,
          body: json.encode(feedbackData),
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Failed to submit feedback';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to submit feedback';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to submit feedback: ${e.toString()}');
      }
    });
  }

  // ============================================================================
  // CHAPTER PRACTICE API METHODS
  // ============================================================================

  /// Generate a new chapter practice session or get existing active session
  /// Requires Firebase ID token for authentication
  Future<Map<String, dynamic>> generateChapterPractice(
    String chapterKey,
    String authToken, {
    int? questionCount,
  }) async {
    return _retryRequest(() async {
      try {
        final body = {
          'chapter_key': chapterKey,
          if (questionCount != null) 'question_count': questionCount,
        };

        final headers = await getAuthHeaders(authToken);
        final response = await http.post(
          Uri.parse('$baseUrl/api/chapter-practice/generate'),
          headers: headers,
          body: json.encode(body),
        ).timeout(const Duration(seconds: 60));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to generate practice';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to generate practice: ${e.toString()}');
      }
    });
  }

  /// Submit answer for a chapter practice question
  /// Requires Firebase ID token for authentication
  Future<Map<String, dynamic>> submitChapterPracticeAnswer(
    String sessionId,
    String questionId,
    String studentAnswer,
    String authToken, {
    int timeTakenSeconds = 0,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.post(
          Uri.parse('$baseUrl/api/chapter-practice/submit-answer'),
          headers: headers,
          body: json.encode({
            'session_id': sessionId,
            'question_id': questionId,
            'student_answer': studentAnswer,
            'time_taken_seconds': timeTakenSeconds,
          }),
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to submit answer';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to submit answer: ${e.toString()}');
      }
    });
  }

  /// Complete a chapter practice session
  /// Requires Firebase ID token for authentication
  Future<Map<String, dynamic>> completeChapterPractice(
    String sessionId,
    String authToken,
  ) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.post(
          Uri.parse('$baseUrl/api/chapter-practice/complete'),
          headers: headers,
          body: json.encode({
            'session_id': sessionId,
          }),
        ).timeout(const Duration(seconds: 30));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to complete practice';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to complete practice: ${e.toString()}');
      }
    });
  }

  /// Get chapter practice session details
  /// Requires Firebase ID token for authentication
  Future<Map<String, dynamic>> getChapterPracticeSession(
    String sessionId,
    String authToken,
  ) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          Uri.parse('$baseUrl/api/chapter-practice/session/$sessionId'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to get session';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to get session: ${e.toString()}');
      }
    });
  }

  /// Get active chapter practice session (if any)
  /// Requires Firebase ID token for authentication
  Future<Map<String, dynamic>> getActiveChapterPractice(
    String authToken, {
    String? chapterKey,
  }) async {
    return _retryRequest(() async {
      try {
        String url = '$baseUrl/api/chapter-practice/active';
        if (chapterKey != null) {
          url += '?chapter_key=$chapterKey';
        }

        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to get active session';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to get active session: ${e.toString()}');
      }
    });
  }

  /// Get Chapter Practice Stats
  /// Returns aggregated practice statistics
  Future<Map<String, dynamic>> getChapterPracticeStats(
    String authToken, {
    String? chapterKey,
  }) async {
    return _retryRequest(() async {
      try {
        String url = '$baseUrl/api/chapter-practice/stats';
        if (chapterKey != null) {
          url += '?chapter_key=$chapterKey';
        }

        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to get practice stats';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to get practice stats: ${e.toString()}');
      }
    });
  }

  /// Get Chapter Practice History for the History screen
  /// Returns list of completed practice sessions with pagination
  /// Requires Firebase ID token for authentication
  Future<Map<String, dynamic>> getChapterPracticeHistory(
    String authToken, {
    int limit = 20,
    int offset = 0,
    int? days,
    String? subject,
  }) async {
    return _retryRequest(() async {
      try {
        final queryParams = <String, String>{
          'limit': limit.toString(),
          'offset': offset.toString(),
        };

        // Add days filter if provided (for tier-based filtering)
        if (days != null && days > 0) {
          queryParams['days'] = days.toString();
        }

        // Add subject filter if provided
        if (subject != null && subject.isNotEmpty) {
          queryParams['subject'] = subject.toLowerCase();
        }

        final uri = Uri.parse('$baseUrl/api/chapter-practice/history')
            .replace(queryParameters: queryParams);

        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          uri,
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData as Map<String, dynamic>;
          } else {
            final errorMsg = jsonData['error']?['message'] ??
                jsonData['error'] ??
                'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          if (response.body.trimLeft().startsWith('<!DOCTYPE') ||
              response.body.trimLeft().startsWith('<html')) {
            throw Exception(
                'Server temporarily unavailable (${response.statusCode}). Please try again.');
          }
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ??
              errorData['error'] ??
              'Failed to get practice history';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception(
            'No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } on FormatException {
        throw Exception('Server returned invalid response. Please try again.');
      } catch (e) {
        throw Exception('Failed to get practice history: ${e.toString()}');
      }
    });
  }

  // ==========================================================================
  // AI TUTOR (Priya Ma'am) APIs
  // ==========================================================================

  /// Get AI Tutor conversation history
  /// Returns messages, current context, and quick actions
  static Future<Map<String, dynamic>> getAiTutorConversation({
    required String authToken,
    int limit = 50,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.get(
          Uri.parse('$baseUrl/api/ai-tutor/conversation?limit=$limit'),
          headers: headers,
        ).timeout(const Duration(seconds: 30));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else if (response.statusCode == 403) {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'AI Tutor requires Ultra subscription');
        } else {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to load conversation');
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } on TimeoutException {
        throw Exception('Request timed out. Please try again.');
      }
    });
  }

  /// Inject context into AI Tutor conversation
  /// Called when opening chat from solution/quiz/analytics screen
  static Future<Map<String, dynamic>> injectAiTutorContext({
    required String authToken,
    required String contextType,
    String? contextId,
  }) async {
    return _retryRequest(() async {
      try {
        final body = {
          'contextType': contextType,
          if (contextId != null) 'contextId': contextId,
        };

        final headers = await getAuthHeaders(authToken);
        final response = await http.post(
          Uri.parse('$baseUrl/api/ai-tutor/inject-context'),
          headers: headers,
          body: json.encode(body),
        ).timeout(const Duration(seconds: 60));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else if (response.statusCode == 403) {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'AI Tutor requires Ultra subscription');
        } else {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to inject context');
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } on TimeoutException {
        throw Exception('Request timed out. Please try again.');
      }
    });
  }

  /// Send a message to AI Tutor
  static Future<Map<String, dynamic>> sendAiTutorMessage({
    required String authToken,
    required String message,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.post(
          Uri.parse('$baseUrl/api/ai-tutor/message'),
          headers: headers,
          body: json.encode({'message': message}),
        ).timeout(const Duration(seconds: 90));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else if (response.statusCode == 403) {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'AI Tutor requires Ultra subscription');
        } else if (response.statusCode == 429) {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'Daily message limit reached');
        } else {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to send message');
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } on TimeoutException {
        throw Exception('Priya Ma\'am is thinking... please wait a moment and try again.');
      }
    });
  }

  /// Clear AI Tutor conversation
  static Future<void> clearAiTutorConversation({
    required String authToken,
  }) async {
    return _retryRequest(() async {
      try {
        final headers = await getAuthHeaders(authToken);
        final response = await http.delete(
          Uri.parse('$baseUrl/api/ai-tutor/conversation'),
          headers: headers,
        ).timeout(const Duration(seconds: 30));

        // Check for session expiry
        if (_checkSessionExpiry(response)) {
          throw Exception('Session expired. Please sign in again.');
        }

        if (response.statusCode == 200) {
          return;
        } else if (response.statusCode == 403) {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'AI Tutor requires Ultra subscription');
        } else {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to clear conversation');
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      }
    });
  }

  // ==========================================================================
  // SHARING APIs
  // ==========================================================================

  /// Log a share event to analytics
  /// Fire-and-forget: failures are logged but don't throw
  static Future<void> logShareEvent({
    required String authToken,
    required String solutionId,
    required String shareType,
    required String subject,
    required String topic,
  }) async {
    try {
      final headers = await getAuthHeaders(authToken);
      final response = await http.post(
        Uri.parse('$baseUrl/api/share/log'),
        headers: headers,
        body: json.encode({
          'solutionId': solutionId,
          'shareType': shareType,
          'subject': subject,
          'topic': topic,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      // Note: Don't check session expiry for fire-and-forget operations
      if (response.statusCode != 200 && response.statusCode != 201) {
        print('Share log failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Share log error: $e');
      // Don't rethrow - this is a fire-and-forget operation
    }
  }
}

