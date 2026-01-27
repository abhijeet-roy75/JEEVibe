import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../firebase/auth_service.dart';

/// Exception for when server returns HTML instead of JSON (server waking up/unavailable)
class ServerUnavailableException implements Exception {
  const ServerUnavailableException();
}

class FirestoreUserService {
  // Backend URL - same as ApiService (Singapore region)
  static const String baseUrl = 'https://jeevibe-thzi.onrender.com';

  // Get authentication token from AuthService (with force refresh on failure)
  Future<String> _getAuthToken() async {
    final authService = AuthService();
    final token = await authService.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please sign in again to continue.');
    }

    return token;
  }

  // Check if response is HTML instead of JSON (indicates server unavailable/waking up)
  void _checkForHtmlResponse(http.Response response) {
    final body = response.body.trim();
    if (body.startsWith('<!DOCTYPE') || body.startsWith('<html') || body.startsWith('<HTML')) {
      throw const ServerUnavailableException();
    }
  }

  // Create or Update User Profile
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      final token = await _getAuthToken();

      // Convert UserProfile to map, handling Timestamps
      final profileMap = profile.toMap();

      // Convert Firestore Timestamps to ISO strings for JSON
      final jsonData = <String, dynamic>{};
      profileMap.forEach((key, value) {
        if (value == null) {
          // Skip null values - don't include in JSON
          return;
        }

        if (value is Timestamp) {
          jsonData[key] = value.toDate().toIso8601String();
        } else if (value is String && value.isEmpty && key == 'phoneNumber') {
          // Skip empty phoneNumber - backend will use authenticated user's phone
          return;
        } else {
          jsonData[key] = value;
        }
      });

      // Remove uid from body (backend uses authenticated userId)
      jsonData.remove('uid');

      final response = await http.post(
        Uri.parse('$baseUrl/api/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(jsonData),
      ).timeout(const Duration(seconds: 30));

      // Check if response is HTML instead of JSON (server unavailable/waking up)
      _checkForHtmlResponse(response);

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        String errorMessage = errorData['error'] ?? 'Failed to save user profile';

        // Include validation details if available
        if (errorData['details'] != null) {
          if (errorData['details'] is List) {
            final details = errorData['details'] as List;
            if (details.isNotEmpty) {
              final detailMessages = details.map((d) {
                if (d is Map && d['msg'] != null) {
                  return d['msg'];
                } else if (d is String) {
                  return d;
                }
                return d.toString();
              }).join(', ');
              errorMessage = '$errorMessage: $detailMessages';
            }
          } else if (errorData['details'] is String) {
            errorMessage = '$errorMessage: ${errorData['details']}';
          }
        }

        throw Exception(errorMessage);
      }
    } on ServerUnavailableException {
      throw Exception('Server is temporarily unavailable. Please try again in a moment.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } on FormatException {
      // JSON parsing failed - likely got HTML response
      throw Exception('Server is temporarily unavailable. Please try again in a moment.');
    } catch (e) {
      if (e is Exception && e.toString().contains('Server is temporarily')) {
        rethrow;
      }
      throw Exception('Failed to save user profile: ${e.toString()}');
    }
  }

  // Get User Profile
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      print('FirestoreUserService: Fetching profile for UID: $uid');
      final token = await _getAuthToken();
      print('FirestoreUserService: Got auth token: ${token.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      print('FirestoreUserService: Response status: ${response.statusCode}');
      print('FirestoreUserService: Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      // Check if response is HTML instead of JSON (server unavailable/waking up)
      _checkForHtmlResponse(response);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          print('FirestoreUserService: Profile data found, parsing...');
          final data = jsonData['data'] as Map<String, dynamic>;

          // Convert ISO date strings back to DateTime for UserProfile
          final profileData = <String, dynamic>{};
          data.forEach((key, value) {
            if (key == 'createdAt' || key == 'lastActive' || key == 'dateOfBirth') {
              if (value != null) {
                profileData[key] = Timestamp.fromDate(DateTime.parse(value));
              } else {
                profileData[key] = null;
              }
            } else {
              profileData[key] = value;
            }
          });

          print('FirestoreUserService: Profile parsed successfully');
          return UserProfile.fromMap(profileData, data['uid'] ?? uid);
        }
        print('FirestoreUserService: No profile data in response');
        return null;
      } else if (response.statusCode == 404) {
        print('FirestoreUserService: Profile not found (404)');
        // Profile not found
        return null;
      } else {
        final errorData = json.decode(response.body);
        print('FirestoreUserService: Error response: ${errorData['error']}');
        throw Exception(errorData['error'] ?? 'Failed to fetch user profile');
      }
    } on ServerUnavailableException {
      print('FirestoreUserService: Server unavailable');
      throw Exception('Server is temporarily unavailable. Please try again in a moment.');
    } on SocketException catch (e) {
      print('FirestoreUserService: Network error: $e');
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException catch (e) {
      print('FirestoreUserService: Client error: $e');
      throw Exception('Network error. Please try again.');
    } on FormatException catch (e) {
      print('FirestoreUserService: Format error: $e');
      throw Exception('Server is temporarily unavailable. Please try again in a moment.');
    } catch (e) {
      print('FirestoreUserService: Unexpected error: $e');
      if (e is Exception && e.toString().contains('Server is temporarily')) {
        rethrow;
      }
      throw Exception('Failed to fetch user profile: ${e.toString()}');
    }
  }

  // Check if Profile Exists
  Future<bool> profileExists(String uid) async {
    try {
      final token = await _getAuthToken();

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/profile/exists'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      // Check if response is HTML instead of JSON (server unavailable/waking up)
      _checkForHtmlResponse(response);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          return jsonData['exists'] == true;
        }
        return false;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to check profile existence');
      }
    } on ServerUnavailableException {
      throw Exception('Server is temporarily unavailable. Please try again in a moment.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } on FormatException {
      throw Exception('Server is temporarily unavailable. Please try again in a moment.');
    } catch (e) {
      if (e is Exception && e.toString().contains('Server is temporarily')) {
        rethrow;
      }
      throw Exception('Failed to check profile existence: ${e.toString()}');
    }
  }

  // Update Last Active
  Future<void> updateLastActive(String uid) async {
    try {
      final token = await _getAuthToken();

      final response = await http.patch(
        Uri.parse('$baseUrl/api/users/profile/last-active'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      // Check if response is HTML instead of JSON (server unavailable/waking up)
      _checkForHtmlResponse(response);

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to update last active');
      }
    } on ServerUnavailableException {
      throw Exception('Server is temporarily unavailable. Please try again in a moment.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } on FormatException {
      throw Exception('Server is temporarily unavailable. Please try again in a moment.');
    } catch (e) {
      if (e is Exception && e.toString().contains('Server is temporarily')) {
        rethrow;
      }
      throw Exception('Failed to update last active: ${e.toString()}');
    }
  }

  // Complete Profile
  Future<void> markProfileCompleted(String uid) async {
    try {
      final token = await _getAuthToken();

      final response = await http.patch(
        Uri.parse('$baseUrl/api/users/profile/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      // Check if response is HTML instead of JSON (server unavailable/waking up)
      _checkForHtmlResponse(response);

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to mark profile as completed');
      }
    } on ServerUnavailableException {
      throw Exception('Server is temporarily unavailable. Please try again in a moment.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } on FormatException {
      throw Exception('Server is temporarily unavailable. Please try again in a moment.');
    } catch (e) {
      if (e is Exception && e.toString().contains('Server is temporarily')) {
        rethrow;
      }
      throw Exception('Failed to mark profile as completed: ${e.toString()}');
    }
  }
}
