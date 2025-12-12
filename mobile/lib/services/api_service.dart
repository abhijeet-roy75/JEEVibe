import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../models/solution_model.dart';
import '../models/assessment_question.dart';
import '../models/assessment_response.dart';

class ApiService {
  // Backend URL
  // For iOS simulator: http://localhost:3000
  // For real device: http://YOUR_COMPUTER_IP:3000 (ensure same WiFi)
  // Current IP: 192.168.5.81
  // static const String baseUrl = 'http://192.168.5.81:3000';
  static const String baseUrl = 'https://jeevibe.onrender.com';
  
  /// Upload image and get solution
  static Future<Solution> solveQuestion(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/solve'),
      );

      // Add image file with explicit content type
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      MediaType contentType;
      if (fileExtension == 'png') {
        contentType = MediaType('image', 'png');
      } else if (fileExtension == 'heic') {
        contentType = MediaType('image', 'heic');
      } else {
        contentType = MediaType('image', 'jpeg');
      }
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', 
          imageFile.path,
          contentType: contentType,
        ),
      );

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] == true && jsonData['data'] != null) {
            try {
              return Solution.fromJson(jsonData['data']);
            } catch (e) {
              throw Exception('Failed to parse solution data: $e');
            }
          } else {
            throw Exception('Invalid response format: ${jsonData['error'] ?? 'Unknown error'}');
          }
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Failed to decode response: $e');
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to solve question');
        } catch (e) {
          throw Exception('Server error (${response.statusCode}): ${response.body.substring(0, 200)}');
        }
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('Failed to solve question: ${e.toString()}');
    }
  }

  /// Generate a single practice question (for lazy loading)
  static Future<FollowUpQuestion> generateSingleQuestion({
    required String recognizedQuestion,
    required Map<String, dynamic> solution,
    required String topic,
    required String difficulty,
    required int questionNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate-single-question'),
        headers: {'Content-Type': 'application/json'},
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
          throw Exception('Invalid response format');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to generate question');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('Failed to generate question: ${e.toString()}');
    }
  }

  /// Generate follow-up practice questions on demand (deprecated - use generateSingleQuestion)
  static Future<List<FollowUpQuestion>> generatePracticeQuestions({
    required String recognizedQuestion,
    required Map<String, dynamic> solution,
    required String topic,
    required String difficulty,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate-practice-questions'),
        headers: {'Content-Type': 'application/json'},
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
          throw Exception('Invalid response format');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to generate practice questions');
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
        throw Exception(errorData['error'] ?? 'Failed to fetch assessment questions');
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
        return AssessmentResult(
          success: false,
          error: errorData['error'] ?? 'Failed to submit assessment',
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
        return AssessmentResult(
          success: false,
          error: errorData['error'] ?? 'Failed to fetch assessment results',
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
}

