import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../firebase/auth_service.dart';

class FirestoreUserService {
  // Backend URL - same as ApiService
  static const String baseUrl = 'https://jeevibe.onrender.com';
  
  // Get authentication token from AuthService
  Future<String?> _getAuthToken() async {
    final authService = AuthService();
    return await authService.getIdToken();
  }

  // Create or Update User Profile
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

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
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('Failed to save user profile: ${e.toString()}');
    }
  }

  // Get User Profile
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
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
          
          return UserProfile.fromMap(profileData, data['uid'] ?? uid);
        }
        return null;
      } else if (response.statusCode == 404) {
        // Profile not found
        return null;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to fetch user profile');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('Failed to fetch user profile: ${e.toString()}');
    }
  }

  // Check if Profile Exists
  Future<bool> profileExists(String uid) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/profile/exists'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

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
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('Failed to check profile existence: ${e.toString()}');
    }
  }
  
  // Update Last Active
  Future<void> updateLastActive(String uid) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/api/users/profile/last-active'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to update last active');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('Failed to update last active: ${e.toString()}');
    }
  }
  
  // Complete Profile
  Future<void> markProfileCompleted(String uid) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/api/users/profile/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to mark profile as completed');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on http.ClientException {
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('Failed to mark profile as completed: ${e.toString()}');
    }
  }
}
