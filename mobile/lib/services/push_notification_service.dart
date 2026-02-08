import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Push Notification Service
///
/// Handles Firebase Cloud Messaging (FCM) integration:
/// - Requesting notification permissions
/// - Collecting and saving FCM tokens
/// - Handling foreground and background notifications
/// - Displaying in-app banners/dialogs for trial notifications
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _currentToken;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Get current FCM token (if available)
  String? get currentToken => _currentToken;

  /// Initialize push notifications
  /// Call this after user logs in
  Future<void> initialize(String authToken, {GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey;
    try {
      debugPrint('PushNotificationService: Initializing...');

      // Request permission (iOS will show dialog, Android auto-grants)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('PushNotificationService: Permission status = ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages (when app is in background but not terminated)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          debugPrint('PushNotificationService: Token refreshed = ${newToken.substring(0, 20)}...');
          _saveFcmToken(newToken, authToken);
          _currentToken = newToken;
        });

        // Try to get FCM token (non-blocking)
        _messaging.getToken().then((token) {
          if (token != null) {
            debugPrint('PushNotificationService: Got FCM token = ${token.substring(0, 20)}...');
            _saveFcmToken(token, authToken);
            _currentToken = token;
          } else {
            debugPrint('PushNotificationService: Token not available yet, will retry when APNs ready');
          }
        }).catchError((e) {
          debugPrint('PushNotificationService: Error getting token (will retry on refresh): $e');
        });

        debugPrint('PushNotificationService: Initialized successfully (token collection in progress)');
      } else {
        debugPrint('PushNotificationService: Permission denied');
      }
    } catch (e) {
      debugPrint('PushNotificationService: Error during initialization = $e');
    }
  }

  /// Save FCM token to backend
  Future<void> _saveFcmToken(String token, String authToken) async {
    try {
      debugPrint('PushNotificationService: Saving FCM token to backend...');

      final headers = await ApiService.getAuthHeaders(authToken);
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/users/fcm-token'),
        headers: headers,
        body: jsonEncode({'fcm_token': token}),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          debugPrint('PushNotificationService: FCM token saved successfully');
        } else {
          debugPrint('PushNotificationService: Failed to save FCM token = ${jsonData['error']}');
        }
      } else {
        debugPrint('PushNotificationService: Failed to save FCM token (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('PushNotificationService: Error saving FCM token = $e');
    }
  }

  /// Handle foreground message (when app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('PushNotificationService: Foreground message received');
    debugPrint('  Title: ${message.notification?.title}');
    debugPrint('  Body: ${message.notification?.body}');
    debugPrint('  Data: ${message.data}');

    // Check message type
    final messageType = message.data['type'] as String?;

    if (messageType == 'session_expired') {
      // User logged in on another device - force logout
      _handleSessionExpiredNotification(message);
    } else if (messageType == 'trial_notification') {
      final daysRemaining = int.tryParse(message.data['days_remaining'] ?? '0') ?? 0;
      _showTrialNotificationBanner(message.notification, daysRemaining);
    } else {
      // Generic notification
      _showGenericNotificationBanner(message.notification);
    }
  }

  /// Handle background message tap (when user taps notification)
  void _handleBackgroundMessageTap(RemoteMessage message) {
    debugPrint('PushNotificationService: Background message tapped');
    debugPrint('  Data: ${message.data}');

    // Navigate based on message type
    final messageType = message.data['type'] as String?;

    if (messageType == 'session_expired') {
      // User logged in on another device - force logout
      _handleSessionExpiredNotification(message);
    } else if (messageType == 'trial_notification') {
      // Navigate to paywall screen
      // This will be handled by the app's navigation logic
      debugPrint('PushNotificationService: Should navigate to paywall');
    }
  }

  /// Handle session expired notification
  /// Shows dialog and triggers session expiry callback (same as API-based expiry)
  void _handleSessionExpiredNotification(RemoteMessage message) {
    debugPrint('PushNotificationService: Session expired notification received');

    final newDevice = message.data['new_device'] as String? ?? 'another device';

    // Trigger the same session expiry callback that ApiService uses
    // This will show the session expired dialog and force logout
    if (ApiService.onSessionExpired != null) {
      ApiService.onSessionExpired!(
        'SESSION_EXPIRED',
        'You have been logged in on $newDevice. Tap OK to continue.',
      );
    }
  }

  /// Show trial notification banner (in-app)
  void _showTrialNotificationBanner(RemoteNotification? notification, int daysRemaining) {
    if (notification == null) return;

    debugPrint('PushNotificationService: Showing in-app trial banner = ${notification.title}');

    // Get scaffold messenger context
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('PushNotificationService: No context available for snackbar');
      return;
    }

    // Show in-app snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            if (notification.body != null) ...[
              const SizedBox(height: 4),
              Text(
                notification.body!,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
          ],
        ),
        backgroundColor: daysRemaining <= 2 ? Colors.red : Colors.orange,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Upgrade',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to paywall
            // Navigator.push(context, MaterialPageRoute(builder: (_) => PaywallScreen()));
          },
        ),
      ),
    );
  }

  /// Show generic notification banner (in-app)
  void _showGenericNotificationBanner(RemoteNotification? notification) {
    if (notification == null) return;

    debugPrint('PushNotificationService: Showing in-app generic banner = ${notification.title}');

    // Get scaffold messenger context
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('PushNotificationService: No context available for snackbar');
      return;
    }

    // Show in-app snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            if (notification.body != null) ...[
              const SizedBox(height: 4),
              Text(
                notification.body!,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Clear FCM token (on logout)
  Future<void> clearToken(String authToken) async {
    try {
      debugPrint('PushNotificationService: Clearing FCM token...');

      final headers = await ApiService.getAuthHeaders(authToken);
      await http.post(
        Uri.parse('${ApiService.baseUrl}/api/users/fcm-token'),
        headers: headers,
        body: jsonEncode({'fcm_token': null}),
      );

      _currentToken = null;
      await _messaging.deleteToken();

      debugPrint('PushNotificationService: FCM token cleared');
    } catch (e) {
      debugPrint('PushNotificationService: Error clearing FCM token = $e');
    }
  }
}

/// Top-level function for handling background messages (terminated state)
/// This must be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('PushNotificationService: Background message received (terminated state)');
  debugPrint('  Title: ${message.notification?.title}');
  debugPrint('  Body: ${message.notification?.body}');
  debugPrint('  Data: ${message.data}');
}
