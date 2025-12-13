/// Test data fixtures for mobile tests
import 'dart:convert';
import 'package:jeevibe_mobile/models/solution_model.dart';
import 'package:jeevibe_mobile/models/assessment_question.dart';
import 'package:jeevibe_mobile/models/user_profile.dart';

class TestData {
  /// Sample solution JSON
  static Map<String, dynamic> get sampleSolutionJson => {
    'recognizedQuestion': 'Find the derivative of f(x) = x^2 + 3x + 5',
    'subject': 'Mathematics',
    'topic': 'Differential Calculus',
    'difficulty': 'medium',
    'solution': {
      'approach': 'Use the power rule for differentiation',
      'steps': [
        'Step 1: Apply power rule to x^2',
        'Step 2: Apply power rule to 3x',
        'Step 3: Derivative of constant is 0',
      ],
      'finalAnswer': 'f\'(x) = 2x + 3',
      'priyaMaamTip': 'Remember the power rule: d/dx(x^n) = nx^(n-1)',
    },
  };

  /// Sample solution object
  static Solution get sampleSolution => Solution.fromJson(sampleSolutionJson);

  /// Sample follow-up question JSON
  static Map<String, dynamic> get sampleFollowUpQuestionJson => {
    'question': 'What is the derivative of f(x) = x^3?',
    'options': {
      'A': '3x^2',
      'B': 'x^2',
      'C': '3x',
      'D': 'x^3',
    },
    'correctAnswer': 'A',
    'explanation': {
      'approach': 'Apply power rule',
      'steps': [
        'Step 1: Use power rule d/dx(x^n) = nx^(n-1)',
        'Step 2: For x^3, n = 3',
        'Step 3: f\'(x) = 3x^(3-1) = 3x^2',
      ],
      'finalAnswer': '3x^2',
    },
    'priyaMaamNote': 'Great job! You\'re getting the hang of it!',
  };

  /// Sample assessment question JSON
  static Map<String, dynamic> get sampleAssessmentQuestionJson => {
    'question_id': 'test_q1',
    'question_text': 'What is 2 + 2?',
    'options': {
      'A': '3',
      'B': '4',
      'C': '5',
      'D': '6',
    },
    'subject': 'Mathematics',
    'chapter': 'Basic Arithmetic',
    'difficulty_irt': 0.5,
    'question_number': 1,
  };

  /// Sample assessment question object
  static AssessmentQuestion get sampleAssessmentQuestion =>
      AssessmentQuestion.fromJson(sampleAssessmentQuestionJson);

  /// Sample user profile JSON
  static Map<String, dynamic> get sampleUserProfileJson => {
    'uid': 'test_user_123',
    'firstName': 'Test',
    'lastName': 'User',
    'email': 'test@example.com',
    'phoneNumber': '+1234567890',
    'createdAt': '2024-01-01T00:00:00Z',
    'lastActive': '2024-01-01T00:00:00Z',
    'profileCompleted': true,
  };

  /// Sample user profile object
  static UserProfile get sampleUserProfile =>
      UserProfile.fromMap(sampleUserProfileJson, sampleUserProfileJson['uid'] as String);

  /// Sample API error response
  static Map<String, dynamic> get sampleErrorResponse => {
    'success': false,
    'error': 'Test error message',
    'requestId': 'test_request_123',
  };

  /// Sample API success response
  static Map<String, dynamic> get sampleSuccessResponse => {
    'success': true,
    'data': sampleSolutionJson,
    'requestId': 'test_request_123',
  };
}

