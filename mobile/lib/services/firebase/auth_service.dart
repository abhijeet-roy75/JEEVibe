import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../push_notification_service.dart';
import 'pin_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Secure storage for session token and device ID
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Storage keys
  static const _sessionTokenKey = 'jeevibe_session_token';
  static const _deviceIdKey = 'jeevibe_device_id';

  // Backend URL (must match api_service.dart)
  static const String _baseUrl = 'https://jeevibe-thzi.onrender.com';

  AuthService() {
    _auth.authStateChanges().listen((user) {
      notifyListeners();
    });
  }

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  // ============================================================================
  // SESSION TOKEN MANAGEMENT
  // ============================================================================

  /// Get stored session token
  static Future<String?> getSessionToken() async {
    try {
      return await _storage.read(key: _sessionTokenKey);
    } catch (e) {
      debugPrint('Error reading session token: $e');
      return null;
    }
  }

  /// Store session token
  static Future<void> setSessionToken(String token) async {
    try {
      await _storage.write(key: _sessionTokenKey, value: token);
    } catch (e) {
      debugPrint('Error storing session token: $e');
    }
  }

  /// Clear session token (on logout or session expiry)
  static Future<void> clearSessionToken() async {
    try {
      await _storage.delete(key: _sessionTokenKey);
    } catch (e) {
      debugPrint('Error clearing session token: $e');
    }
  }

  // ============================================================================
  // DEVICE ID MANAGEMENT
  // ============================================================================

  /// Get or create a persistent device ID
  static Future<String> getDeviceId() async {
    try {
      // Try to read existing device ID
      String? deviceId = await _storage.read(key: _deviceIdKey);
      if (deviceId != null) {
        return deviceId;
      }

      // Generate new device ID based on device info
      final deviceInfo = DeviceInfoPlugin();
      String newDeviceId;

      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use identifierForVendor which persists across app reinstalls (until device reset)
        newDeviceId = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use androidId which persists across app reinstalls
        newDeviceId = androidInfo.id;
      } else {
        newDeviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Store for future use
      await _storage.write(key: _deviceIdKey, value: newDeviceId);
      return newDeviceId;
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      // Fallback to timestamp-based ID
      final fallbackId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: _deviceIdKey, value: fallbackId);
      return fallbackId;
    }
  }

  /// Get human-readable device name
  static Future<String> getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name; // e.g., "John's iPhone"
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}'; // e.g., "Samsung Galaxy S23"
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  // ============================================================================
  // SESSION API CALLS
  // ============================================================================

  /// Create a new session after OTP verification
  /// Returns the session token on success, throws on failure
  Future<String> createSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get auth token');
    }

    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'deviceId': deviceId,
          'deviceName': deviceName,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data']?['sessionToken'] != null) {
          final sessionToken = jsonData['data']['sessionToken'] as String;
          await setSessionToken(sessionToken);
          debugPrint('Session created successfully');
          return sessionToken;
        } else {
          throw Exception(jsonData['error'] ?? 'Failed to create session');
        }
      } else if (response.statusCode == 404) {
        // User profile not found - this is OK for new users
        // Session will be created after profile setup
        debugPrint('User profile not found, session will be created after profile setup');
        throw Exception('PROFILE_NOT_FOUND');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to create session');
      }
    } catch (e) {
      debugPrint('Error creating session: $e');
      rethrow;
    }
  }

  /// Call backend logout endpoint to clear server-side session
  Future<void> logoutSession() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await user.getIdToken();
      if (token == null) return;

      await http.post(
        Uri.parse('$_baseUrl/api/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('Server session cleared');
    } catch (e) {
      // Log but don't fail - user can still sign out locally
      debugPrint('Error clearing server session: $e');
    }
  }

  // Verify Phone Number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  // Sign in with OTP
  Future<UserCredential> signInWithSMSCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // Sign out - clears both server session and local data
  Future<void> signOut() async {
    // Get auth token before signing out (for API calls)
    String? authToken;
    try {
      authToken = await currentUser?.getIdToken();
    } catch (e) {
      debugPrint('Error getting auth token for logout: $e');
    }

    // Clear server-side session first (fire and forget)
    await logoutSession();

    // Clear FCM token (fire and forget)
    if (authToken != null) {
      try {
        final pushService = PushNotificationService();
        await pushService.clearToken(authToken);
      } catch (e) {
        debugPrint('Error clearing FCM token: $e');
      }
    }

    // Clear PIN (fire and forget)
    try {
      final pinService = PinService();
      await pinService.clearPin();
      debugPrint('PIN cleared on sign out');
    } catch (e) {
      debugPrint('Error clearing PIN: $e');
    }

    // Clear local session token
    await clearSessionToken();

    // Sign out from Firebase
    await _auth.signOut();
    notifyListeners();
  }
  
  // Get ID Token (with optional force refresh)
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      // If token fetch fails, try force refresh once
      if (!forceRefresh) {
        try {
          return await user.getIdToken(true);
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }
}
