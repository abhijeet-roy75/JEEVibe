/// Mock AuthService for testing
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeevibe_mobile/services/firebase/auth_service.dart';

class MockAuthService extends AuthService {
  User? _mockUser;
  bool _isAuthenticated = false;
  String? _mockToken;

  MockAuthService({User? mockUser, bool isAuthenticated = false, String? mockToken}) {
    _mockUser = mockUser;
    _isAuthenticated = isAuthenticated;
    _mockToken = mockToken;
  }

  @override
  User? get currentUser => _mockUser;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return _mockToken;
  }

  @override
  Future<void> signOut() async {
    _isAuthenticated = false;
    _mockUser = null;
    _mockToken = null;
    notifyListeners();
  }

  // Test helpers
  void setMockUser(User? user) {
    _mockUser = user;
    _isAuthenticated = user != null;
    notifyListeners();
  }

  void setMockToken(String? token) {
    _mockToken = token;
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    notifyListeners();
  }
}

