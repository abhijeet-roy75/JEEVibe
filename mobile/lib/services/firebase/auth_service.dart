import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthService() {
    _auth.authStateChanges().listen((user) {
      notifyListeners();
    });
  }
  
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

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

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
  
  // Get ID Token
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }
}
