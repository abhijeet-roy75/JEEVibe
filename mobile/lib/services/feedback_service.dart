/// Service for submitting user feedback
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_user_service.dart';
import '../models/user_profile.dart';

class FeedbackService {
  /// Submit feedback to backend
  /// Auto-captures context: screen, user ID, profile, app version, device, OS, timestamp
  static Future<void> submitFeedback({
    required String authToken,
    required int rating,
    required String description,
    required String currentScreen,
    List<Map<String, dynamic>>? recentActivity,
  }) async {
    try {
      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';

      // Get device info
      final deviceInfo = DeviceInfoPlugin();
      String deviceModel = 'Unknown';
      String osVersion = 'Unknown';

      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.model;
        osVersion = 'iOS ${iosInfo.systemVersion}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = androidInfo.model;
        osVersion = 'Android ${androidInfo.version.release}';
      }

      // Get user profile (if available)
      String? userId;
      Map<String, dynamic>? userProfile;
      try {
        final authService = AuthService();
        if (authService.currentUser != null) {
          userId = authService.currentUser!.uid;
          final firestoreService = FirestoreUserService();
          final profile = await firestoreService.getUserProfile(userId);
          if (profile != null) {
            userProfile = {
              'firstName': profile.firstName,
              'lastName': profile.lastName,
              'email': profile.email,
              'phoneNumber': profile.phoneNumber,
              'isEnrolledInCoaching': profile.isEnrolledInCoaching,
              'targetExam': profile.targetExam,
            };
          }
        }
      } catch (e) {
        debugPrint('Error fetching user profile for feedback: $e');
      }

      // Prepare feedback payload
      final feedbackData = {
        'rating': rating,
        'description': description,
        'context': {
          'currentScreen': currentScreen,
          'userId': userId,
          'userProfile': userProfile,
          'appVersion': appVersion,
          'deviceModel': deviceModel,
          'osVersion': osVersion,
          'timestamp': DateTime.now().toIso8601String(),
          'recentActivity': recentActivity ?? [],
        },
      };

      // Submit to backend
      await ApiService.submitFeedback(
        authToken: authToken,
        feedbackData: feedbackData,
      );

      debugPrint('Feedback submitted successfully');
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      rethrow;
    }
  }
}
