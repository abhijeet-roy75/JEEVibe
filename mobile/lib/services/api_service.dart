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

class ApiService {
  // Backend URL
  // For local development: http://localhost:3000 (iOS simulator) or http://YOUR_COMPUTER_IP:3000 (real device)
  // For production (Singapore region): https://jeevibe-thzi.onrender.com
  // Current IP: 192.168.5.81
  static const String baseUrl = 'https://jeevibe-thzi.onrender.com';
  // static const String baseUrl = 'http://localhost:3000'; // For local development
  // static const String baseUrl = 'http://192.168.5.81:3000'; // For real device testing
  
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

      // Add authentication header
      request.headers['Authorization'] = 'Bearer $authToken';

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
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate-single-question'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({
          'recognizedQuestion': recognizedQuestion,
          'solution': solution,
          'topic': topic,
          'difficulty': difficulty,
          'questionNumber': questionNumber,
        }),
      ).timeout(const Duration(seconds: 60));

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
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate-practice-questions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({
          'recognizedQuestion': recognizedQuestion,
          'solution': solution,
          'topic': topic,
          'difficulty': difficulty,
        }),
      ).timeout(const Duration(seconds: 60));

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

  /// Get snap limits and usage from backend
  /// Requires Firebase ID token for authentication
  static Future<Map<String, dynamic>> getSnapLimit({
    required String authToken,
  }) async {
    return _retryRequest(() async {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/snap-limit'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true && jsonData['data'] != null) {
            return jsonData['data'] as Map<String, dynamic>;
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

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        ).timeout(const Duration(seconds: 30));

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
  static Future<List<AssessmentQuestion>> getAssessmentQuestions({
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/assessment/questions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 30));

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
      final response = await http.post(
        Uri.parse('$baseUrl/api/assessment/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({
          'responses': responses.map((r) => r.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 30));

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
      final response = await http.get(
        Uri.parse('$baseUrl/api/assessment/results/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

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
        final response = await http.get(
          Uri.parse('$baseUrl/api/daily-quiz/generate'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        ).timeout(const Duration(seconds: 60));

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
        final response = await http.post(
          Uri.parse('$baseUrl/api/daily-quiz/start'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: json.encode({
            'quiz_id': quizId,
          }),
        ).timeout(const Duration(seconds: 15));

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
        final response = await http.post(
          Uri.parse('$baseUrl/api/daily-quiz/submit-answer'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: json.encode({
            'quiz_id': quizId,
            'question_id': questionId,
            'student_answer': studentAnswer,
            'time_taken_seconds': timeTakenSeconds,
          }),
        ).timeout(const Duration(seconds: 15));

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
        final response = await http.post(
          Uri.parse('$baseUrl/api/daily-quiz/complete'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: json.encode({
            'quiz_id': quizId,
          }),
        ).timeout(const Duration(seconds: 30));

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
        final response = await http.get(
          Uri.parse('$baseUrl/api/daily-quiz/result/$quizId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        ).timeout(const Duration(seconds: 30));

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
        final response = await http.get(
          Uri.parse('$baseUrl/api/daily-quiz/summary'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData['summary'] as Map<String, dynamic>;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to get summary';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
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
        final response = await http.get(
          Uri.parse('$baseUrl/api/daily-quiz/progress'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true) {
            return jsonData['progress'] as Map<String, dynamic>;
          } else {
            final errorMsg = jsonData['error']?['message'] ?? jsonData['error'] ?? 'Invalid response format';
            throw Exception(errorMsg);
          }
        } else {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to get progress';
          throw Exception(errorMsg);
        }
      } on SocketException {
        throw Exception('No internet connection. Please check your network and try again.');
      } on http.ClientException {
        throw Exception('Network error. Please try again.');
      } catch (e) {
        throw Exception('Failed to get progress: ${e.toString()}');
      }
    });
  }
}

