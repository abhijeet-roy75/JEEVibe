/// Logging Configuration
/// Controls verbosity of debug logs throughout the app

class LoggingConfig {
  /// Enable verbose provider logs (AppStateProvider, MockTestProvider, etc.)
  static const bool verboseProviderLogs = false;

  /// Enable verbose service logs (SnapCounterService, SyncService, etc.)
  static const bool verboseServiceLogs = false;

  /// Enable API response payload logging (can be very large)
  static const bool logApiPayloads = false;

  /// Always log errors (should stay true)
  static const bool logErrors = true;

  /// Always log timeouts (should stay true)
  static const bool logTimeouts = true;
}
