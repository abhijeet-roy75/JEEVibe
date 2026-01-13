/// Analytics Service
/// API calls for analytics endpoints
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/analytics_data.dart';

class AnalyticsService {
  static const String baseUrl = 'https://jeevibe-thzi.onrender.com';
  static const Duration timeout = Duration(seconds: 30);

  /// Get analytics overview
  static Future<AnalyticsOverview> getOverview({
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics/overview'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics/mastery/$subject'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
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

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
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
}
