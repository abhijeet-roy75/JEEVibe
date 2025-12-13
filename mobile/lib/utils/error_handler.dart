/// Error Handler Utility
/// Provides centralized error handling with retry mechanisms
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ErrorHandler {
  /// Handle error with retry mechanism
  static Future<T> withRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    String? errorMessage,
  }) async {
    int attempts = 0;
    Exception? lastError;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        attempts++;

        if (attempts < maxRetries) {
          await Future.delayed(delay * attempts); // Exponential backoff
        }
      }
    }

    throw lastError ?? Exception(errorMessage ?? 'Operation failed after $maxRetries attempts');
  }

  /// Get user-friendly error message
  static String getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection error. Please check your internet and try again.';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorString.contains('authentication') || errorString.contains('unauthorized')) {
      return 'Authentication required. Please log in again.';
    } else if (errorString.contains('not found')) {
      return 'Resource not found. Please try again.';
    } else if (errorString.contains('server')) {
      return 'Server error. Please try again later.';
    } else {
      return error.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Show error dialog with retry option
  static Future<bool> showErrorDialog(
    BuildContext context, {
    required String message,
    String title = 'Error',
    String retryText = 'Retry',
    String cancelText = 'Cancel',
    VoidCallback? onRetry,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: AppTextStyles.headerMedium),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              onRetry?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: Text(retryText),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show error snackbar
  static void showErrorSnackBar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.successGreen,
        duration: duration,
      ),
    );
  }

  /// Handle API error with appropriate recovery
  static Future<T> handleApiError<T>(
    BuildContext context,
    Future<T> Function() operation, {
    int maxRetries = 3,
    bool showDialog = false,
  }) async {
    try {
      return await withRetry(
        operation: operation,
        maxRetries: maxRetries,
      );
    } catch (e) {
      final errorMessage = getErrorMessage(e);

      if (showDialog) {
        await showErrorDialog(
          context,
          message: errorMessage,
          onRetry: () {
            // Retry the operation
            handleApiError(context, operation, maxRetries: maxRetries, showDialog: showDialog);
          },
        );
      } else {
        showErrorSnackBar(
          context,
          message: errorMessage,
          onRetry: () {
            // Retry the operation
            handleApiError(context, operation, maxRetries: maxRetries, showDialog: showDialog);
          },
        );
      }

      rethrow;
    }
  }
}

