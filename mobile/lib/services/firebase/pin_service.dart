import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing PIN storage and verification.
/// 
/// PINs are stored locally in encrypted storage (Keychain on iOS, Keystore on Android)
/// using flutter_secure_storage. The PIN is hashed before storage for additional security.
/// 
/// Why local-only storage?
/// - PIN is device-specific and only used for local app access
/// - No need to sync PIN across devices (user re-authenticates on new device)
/// - Better privacy - PIN never leaves the device
/// - Faster verification - no network calls needed
class PinService {
  static const String _pinHashKey = 'pin_hash_encrypted';
  static const String _pinAttemptsKey = 'pin_attempts';
  static const int _maxAttempts = 5;

  // Secure storage for encrypted PIN hash
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Hash a PIN using SHA-256
  /// Note: For production, consider using bcrypt for stronger security
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Save PIN hash to encrypted local storage
  /// 
  /// The PIN is validated for strength, hashed, and stored securely on the device.
  /// No network calls are made - PIN stays on the device.
  Future<void> savePin(String pin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    // Validate PIN strength
    _validatePinStrength(pin);

    // Hash the PIN before storing
    final hashedPin = _hashPin(pin);

    // Store hashed PIN in encrypted secure storage
    await _secureStorage.write(
      key: _pinHashKey,
      value: hashedPin,
    );
    
    // Reset attempts counter (stored in regular SharedPreferences - less sensitive)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pinAttemptsKey, 0);
  }

  /// Verify PIN against stored hash
  /// 
  /// Returns true if PIN matches, false otherwise.
  /// Tracks failed attempts and throws exception after max attempts.
  Future<bool> verifyPin(String pin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    // Check attempt limit
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt(_pinAttemptsKey) ?? 0;

    if (attempts >= _maxAttempts) {
      throw Exception('Too many failed attempts. Please re-authenticate with phone number.');
    }

    // Get stored hash from secure storage
    final storedHash = await _secureStorage.read(key: _pinHashKey);
    
    if (storedHash == null) {
      // No PIN set
      await prefs.setInt(_pinAttemptsKey, attempts + 1);
      return false;
    }

    // Hash the provided PIN and compare
    final hashedPin = _hashPin(pin);

    if (storedHash == hashedPin) {
      // Success - reset attempts
      await prefs.setInt(_pinAttemptsKey, 0);
      return true;
    } else {
      // Failed - increment attempts
      await prefs.setInt(_pinAttemptsKey, attempts + 1);
      return false;
    }
  }

  /// Check if PIN exists for current user
  /// 
  /// Returns true if a PIN has been set, false otherwise.
  Future<bool> pinExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    // Check if PIN hash exists in secure storage
    final storedHash = await _secureStorage.read(key: _pinHashKey);
    return storedHash != null && storedHash.isNotEmpty;
  }

  /// Validate PIN strength
  /// 
  /// Ensures PIN is 4 digits and not a weak/common pattern.
  void _validatePinStrength(String pin) {
    if (pin.length != 4) {
      throw Exception('PIN must be 4 digits');
    }

    // Check for weak PINs
    final weakPins = ['0000', '1111', '2222', '3333', '4444', '5555', 
                      '6666', '7777', '8888', '9999', '1234', '4321',
                      '0123', '3210', '1357', '2468'];
    
    if (weakPins.contains(pin)) {
      throw Exception('Please choose a stronger PIN. Avoid common patterns.');
    }

    // Check for sequential digits
    if (_isSequential(pin)) {
      throw Exception('Please choose a stronger PIN. Avoid sequential numbers.');
    }
  }

  /// Check if PIN is sequential (e.g., 1234, 4321)
  bool _isSequential(String pin) {
    final digits = pin.split('').map(int.parse).toList();
    
    // Check ascending
    bool ascending = true;
    for (int i = 1; i < digits.length; i++) {
      if (digits[i] != digits[i - 1] + 1) {
        ascending = false;
        break;
      }
    }
    
    // Check descending
    bool descending = true;
    for (int i = 1; i < digits.length; i++) {
      if (digits[i] != digits[i - 1] - 1) {
        descending = false;
        break;
      }
    }
    
    return ascending || descending;
  }

  /// Clear PIN (for logout or reset)
  /// 
  /// Removes the PIN from secure storage and resets attempt counter.
  Future<void> clearPin() async {
    await _secureStorage.delete(key: _pinHashKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinAttemptsKey);
  }

  /// Reset PIN attempts (after successful re-authentication)
  /// 
  /// Call this after user successfully re-authenticates with phone number
  /// to reset the failed attempt counter.
  Future<void> resetAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pinAttemptsKey, 0);
  }

  /// Get current failed attempt count
  /// 
  /// Useful for displaying warnings to users.
  Future<int> getAttemptCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pinAttemptsKey) ?? 0;
  }
}
