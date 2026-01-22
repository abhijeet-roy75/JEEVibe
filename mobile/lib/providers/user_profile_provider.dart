/// User Profile Provider
/// Centralized state management for user profile data.
/// All screens that need user info should consume from this provider.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/firebase/firestore_user_service.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfile => _profile != null;

  // Convenience getters for common fields
  String get firstName => _profile?.firstName ?? 'Student';
  String get lastName => _profile?.lastName ?? '';
  String get fullName {
    if (_profile == null) return 'Student';
    final first = _profile!.firstName ?? '';
    final last = _profile!.lastName ?? '';
    if (first.isEmpty && last.isEmpty) return 'Student';
    return '$first $last'.trim();
  }

  /// Load user profile from Firestore
  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _profile = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final firestoreService = FirestoreUserService();
      final profile = await firestoreService.getUserProfile(user.uid);
      _profile = profile;
      _error = null;
    } catch (e) {
      _error = 'Failed to load profile: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update profile after user edits it
  /// Call this from Profile screen after saving changes
  void updateProfile(UserProfile newProfile) {
    _profile = newProfile;
    notifyListeners();
  }

  /// Refresh profile from Firestore (e.g., after profile edit)
  Future<void> refreshProfile() async {
    await loadProfile();
  }

  /// Clear profile data (on logout)
  void clearProfile() {
    _profile = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
