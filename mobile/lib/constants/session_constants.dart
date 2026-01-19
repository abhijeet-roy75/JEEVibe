/// Session Constants
///
/// Constants related to quiz and practice session management.
/// Extracted for maintainability and easier configuration.

/// Provider restoration timeout settings
class SessionTimeouts {
  /// Maximum number of polling attempts when waiting for provider restoration
  static const int maxRestorationAttempts = 20;

  /// Delay between polling attempts in milliseconds
  static const int restorationPollIntervalMs = 500;

  /// Maximum wait time for provider restoration (maxAttempts * pollInterval)
  /// Currently: 20 * 500ms = 10 seconds
  static Duration get maxRestorationWait => Duration(
        milliseconds: maxRestorationAttempts * restorationPollIntervalMs,
      );
}

/// Snackbar display durations
class SnackbarDurations {
  /// Duration for back navigation blocked message
  static const Duration backNavigationBlocked = Duration(seconds: 2);

  /// Duration for error messages
  static const Duration errorMessage = Duration(seconds: 3);

  /// Duration for success messages
  static const Duration successMessage = Duration(seconds: 2);
}

/// API retry settings
class ApiRetrySettings {
  /// Default number of retries for API calls
  static const int defaultMaxRetries = 3;

  /// Initial retry delay
  static const Duration initialRetryDelay = Duration(milliseconds: 500);
}
