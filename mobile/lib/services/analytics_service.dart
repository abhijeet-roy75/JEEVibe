/// Analytics Service
/// API calls for analytics endpoints
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/analytics_data.dart';
import '../models/user_profile.dart';
import '../models/subscription_models.dart';
import 'api_service.dart';

class AnalyticsService {
  static const String baseUrl = 'https://jeevibe-thzi.onrender.com';
  static const Duration timeout = Duration(seconds: 30);

  /// Get analytics dashboard (BATCHED - replaces 4 separate API calls)
  ///
  /// Returns all data needed for analytics screen in a single call:
  /// - User profile
  /// - Subscription status
  /// - Analytics overview
  /// - Weekly activity
  ///
  /// This reduces API calls from 4 to 1, improving performance and reducing rate limiting issues.
  static Future<AnalyticsDashboard> getDashboard({
    required String authToken,
  }) async {
    try {
      final headers = await ApiService.getAuthHeaders(authToken);
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics/dashboard'),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return AnalyticsDashboard.fromJson(json['data']);
        }
        throw Exception(json['error'] ?? 'Failed to load analytics dashboard');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required');
      } else if (response.statusCode == 429) {
        throw Exception('Too many requests. Please try again later.');
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load dashboard (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error fetching analytics dashboard: $e');
      rethrow;
    }
  }

  /// Get analytics overview
  static Future<AnalyticsOverview> getOverview({
    required String authToken,
  }) async {
    try {
      final headers = await ApiService.getAuthHeaders(authToken);
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics/overview'),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return AnalyticsOverview.fromJson(json['data']);
        }
        throw Exception(json['error'] ?? 'Failed to load analytics overview');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required');
      } else if (response.statusCode == 429) {
        throw Exception('Too many requests. Please try again later.');
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load analytics (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error fetching analytics overview: $e');
      rethrow;
    }
  }

  /// Get subject mastery details
  static Future<SubjectMasteryDetails> getSubjectMastery({
    required String authToken,
    required String subject,
  }) async {
    try {
      final headers = await ApiService.getAuthHeaders(authToken);
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics/mastery/$subject'),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return SubjectMasteryDetails.fromJson(json['data']);
        }
        throw Exception(json['error'] ?? 'Failed to load mastery details');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required');
      } else if (response.statusCode == 400) {
        throw Exception('Invalid subject');
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load mastery (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error fetching subject mastery: $e');
      rethrow;
    }
  }

  /// Get mastery timeline for charts
  static Future<MasteryTimeline> getMasteryTimeline({
    required String authToken,
    String? subject,
    String? chapter,
    int limit = 30,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (subject != null) queryParams['subject'] = subject;
      if (chapter != null) queryParams['chapter'] = chapter;

      final uri = Uri.parse('$baseUrl/api/analytics/mastery-timeline')
          .replace(queryParameters: queryParams);

      final headers = await ApiService.getAuthHeaders(authToken);
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return MasteryTimeline.fromJson(json['data']);
        }
        throw Exception(json['error'] ?? 'Failed to load timeline');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required');
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load timeline (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error fetching mastery timeline: $e');
      rethrow;
    }
  }

  /// Get accuracy timeline for charts (subject-level accuracy over time)
  static Future<AccuracyTimeline> getAccuracyTimeline({
    required String authToken,
    required String subject,
    int days = 30,
  }) async {
    try {
      final queryParams = <String, String>{
        'subject': subject,
        'days': days.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/analytics/accuracy-timeline')
          .replace(queryParameters: queryParams);

      final headers = await ApiService.getAuthHeaders(authToken);
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return AccuracyTimeline.fromJson(json['data']);
        }
        throw Exception(json['error'] ?? 'Failed to load accuracy timeline');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required');
      } else if (response.statusCode == 400) {
        throw Exception('Invalid subject parameter');
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load accuracy timeline (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error fetching accuracy timeline: $e');
      rethrow;
    }
  }

  /// Get weekly activity (questions answered per day for 7 days)
  static Future<WeeklyActivity> getWeeklyActivity({
    required String authToken,
  }) async {
    try {
      final headers = await ApiService.getAuthHeaders(authToken);
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics/weekly-activity'),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return WeeklyActivity.fromJson(json['data']);
        }
        throw Exception(json['error'] ?? 'Failed to load weekly activity');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required');
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load weekly activity (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error fetching weekly activity: $e');
      rethrow;
    }
  }

  /// Get all chapters for a subject (including unpracticed ones)
  /// Used by the Chapter Picker feature for Pro/Ultra users
  static Future<List<ChapterMastery>> getChaptersBySubject({
    required String authToken,
    required String subject,
  }) async {
    try {
      final headers = await ApiService.getAuthHeaders(authToken);
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics/chapters-by-subject/$subject'),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final chaptersJson = json['data']['chapters'] as List<dynamic>? ?? [];
          return chaptersJson
              .whereType<Map<String, dynamic>>()
              .map((e) => ChapterMastery.fromJson(e))
              .toList();
        }
        throw Exception(json['error'] ?? 'Failed to load chapters');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required');
      } else if (response.statusCode == 400) {
        throw Exception('Invalid subject');
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to load chapters (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error fetching chapters by subject: $e');
      rethrow;
    }
  }
}
