import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../models/solution_model.dart';

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
}

