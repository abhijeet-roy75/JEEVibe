import 'package:firebase_auth/firebase_auth.dart';

/// Helper class to convert Firebase Auth errors to user-friendly messages
class AuthErrorHelper {
  /// Get user-friendly error message from Firebase Auth exception
  static String getUserFriendlyMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _getFirebaseAuthErrorMessage(error);
    } else if (error is Exception) {
      final errorString = error.toString().toLowerCase();
      
      // Check for common Firebase error patterns in string
      if (errorString.contains('invalid-verification-code') || 
          errorString.contains('invalid verification code')) {
        return 'The code you entered is incorrect. Please check and try again.';
      }
      
      if (errorString.contains('session-expired') || 
          errorString.contains('session expired')) {
        return 'Your verification session has expired. Please request a new code.';
      }
      
      if (errorString.contains('too-many-requests') || 
          errorString.contains('too many requests')) {
        return 'Too many attempts. Please wait a moment and try again.';
      }
      
      if (errorString.contains('network') || 
          errorString.contains('connection')) {
        return 'Network error. Please check your internet connection and try again.';
      }
      
      // Generic error - try to extract meaningful part
      if (errorString.contains('firebase_auth/')) {
        return 'Authentication error. Please try again.';
      }
    }
    
    // Fallback for unknown errors
    return 'Something went wrong. Please try again.';
  }
  
  /// Get user-friendly message from FirebaseAuthException
  static String _getFirebaseAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-verification-code':
        return 'The code you entered is incorrect. Please check the code and try again.';
      
      case 'invalid-verification-id':
        return 'Your verification session has expired. Please request a new code.';
      
      case 'session-expired':
        return 'Your verification session has expired. Please request a new code.';
      
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment before trying again.';
      
      case 'quota-exceeded':
        return 'Too many verification requests. Please try again later.';
      
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      
      case 'invalid-phone-number':
        return 'Invalid phone number. Please check and try again.';
      
      case 'missing-verification-code':
        return 'Please enter the verification code.';
      
      case 'missing-verification-id':
        return 'Verification session expired. Please request a new code.';
      
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled. Please contact support.';
      
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      
      case 'credential-already-in-use':
        return 'This phone number is already registered with another account.';
      
      default:
        // For unknown errors, use the message if available, otherwise generic message
        if (error.message != null && error.message!.isNotEmpty) {
          // Try to extract user-friendly part from message
          final message = error.message!;
          if (message.contains('invalid') && message.contains('code')) {
            return 'The code you entered is incorrect. Please check and try again.';
          }
          if (message.contains('expired') || message.contains('timeout')) {
            return 'Your verification session has expired. Please request a new code.';
          }
        }
        return 'Authentication error. Please try again.';
    }
  }
  
  /// Get actionable suggestion based on error
  static String? getActionableSuggestion(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-verification-code':
          return 'Double-check each digit and make sure you entered all 6 numbers.';
        
        case 'session-expired':
        case 'invalid-verification-id':
          return 'Tap "Resend Code" to get a new verification code.';
        
        case 'too-many-requests':
          return 'Wait 30 seconds before trying again.';
        
        case 'network-request-failed':
          return 'Check your Wi-Fi or mobile data connection.';
        
        default:
          return null;
      }
    }
    return null;
  }
}

