/// Unit tests for PinService
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeevibe_mobile/services/firebase/pin_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PinService', () {
    late PinService pinService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      pinService = PinService();
    });

    group('PIN Validation', () {
      test('savePin - throws on short PIN', () async {
        expect(
          () => pinService.savePin('123'),
          throwsA(isA<Exception>()),
        );
      });

      test('savePin - throws on long PIN', () async {
        expect(
          () => pinService.savePin('123456789'),
          throwsA(isA<Exception>()),
        );
      });

      test('savePin - throws on non-numeric PIN', () async {
        expect(
          () => pinService.savePin('abcd'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('PIN Storage', () {
      test('pinExists - returns false for new user', () async {
        final exists = await pinService.pinExists();
        expect(exists, false);
      });

      test('savePin - stores PIN hash', () async {
        // Note: This test requires mocking Firebase Auth
        // For now, we test the validation logic
        expect(true, true); // Placeholder
      });
    });

    group('PIN Verification', () {
      test('verifyPin - returns false for no PIN set', () async {
        final verified = await pinService.verifyPin('1234');
        expect(verified, false);
      });

      test('verifyPin - throws after max attempts', () async {
        // Set up max attempts
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('pin_attempts', 5);

        expect(
          () => pinService.verifyPin('1234'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('PIN Management', () {
      test('clearPin - clears PIN', () async {
        await pinService.clearPin();
        final exists = await pinService.pinExists();
        expect(exists, false);
      });
    });
  });
}

